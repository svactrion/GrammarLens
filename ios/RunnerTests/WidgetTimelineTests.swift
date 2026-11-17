import SwiftUI
import XCTest

@testable import Runner

/// W2: payload decoding and the timeline's entries.
final class WidgetTimelineTests: XCTestCase {
  private var calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return calendar
  }()

  private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
  }

  private func payload(doneNow: Bool, now: Date, midnight: Date) -> WidgetPayload {
    var first = WidgetSamples.payload(done: doneNow)
    first.entries[0].validFrom = now.timeIntervalSince1970
    var next = WidgetSamples.payload(done: false).entries[0]
    next.validFrom = midnight.timeIntervalSince1970
    next.climb.step = 3
    first.entries.append(next)
    return first
  }

  func testDecodeRejectsOtherSchemasAndEmptyPayloads() throws {
    let good = try JSONEncoder().encode(WidgetSamples.payload(done: false))
    XCTAssertNotNil(WidgetPayload.decode(good))
    var other = WidgetSamples.payload(done: false)
    other.schema = 2
    XCTAssertNil(WidgetPayload.decode(try JSONEncoder().encode(other)))
    other.schema = 1
    other.entries = []
    XCTAssertNil(WidgetPayload.decode(try JSONEncoder().encode(other)))
    XCTAssertNil(WidgetPayload.decode(Data("{}".utf8)))
  }

  func testWaitingNowThenWaitingAtMidnight() {
    let now = date(18, 9, 12)
    let midnight = date(19, 0)
    let entries = GrammarLensTimeline.entries(
      payload: payload(doneNow: false, now: now, midnight: midnight), now: now, calendar: calendar)
    XCTAssertEqual(entries.map(\.date), [now, midnight])
    XCTAssertEqual(entries.map { $0.entry?.climb.step }, [2, 3])
  }

  func testDoneCountsDownEveryHourUntilMidnight() {
    let now = date(18, 14, 30)
    let midnight = date(19, 0)
    let entries = GrammarLensTimeline.entries(
      payload: payload(doneNow: true, now: now, midnight: midnight), now: now, calendar: calendar)
    // 14:30, 15:00 … 23:00, then midnight.
    XCTAssertEqual(entries.count, 1 + 9 + 1)
    XCTAssertEqual(entries.first?.hoursLeft, 10)
    XCTAssertEqual(entries[1].date, date(18, 15))
    XCTAssertEqual(entries[1].hoursLeft, 9)
    XCTAssertEqual(entries[entries.count - 2].hoursLeft, 1)
    XCTAssertEqual(entries.last?.date, midnight)
    XCTAssertEqual(entries.last?.entry?.climb.isDone, false)
    let line = entries[1].entry!.climb.countdownLine(hours: entries[1].hoursLeft, medium: false)
    XCTAssertEqual(line, "Next test in 9 h")
  }

  func testAfterMidnightTheWaitingEntryIsCurrent() {
    let now = date(18, 20)
    let midnight = date(19, 0)
    let late = date(19, 7)
    let entries = GrammarLensTimeline.entries(
      payload: payload(doneNow: true, now: now, midnight: midnight), now: late, calendar: calendar)
    XCTAssertEqual(entries.count, 1)
    XCTAssertEqual(entries[0].entry?.climb.step, 3)
    XCTAssertEqual(entries[0].entry?.climb.isDone, false)
  }

  func testNoPayloadGivesTheEmptyEntry() {
    let entries = GrammarLensTimeline.entries(payload: nil, now: date(18, 9), calendar: calendar)
    XCTAssertEqual(entries.count, 1)
    XCTAssertNil(entries[0].payload)
  }

  func testHoursLeftIsClamped() {
    XCTAssertEqual(WidgetPayload.Climb.hoursLeft(from: date(18, 23, 59), to: date(19, 0)), 1)
    XCTAssertEqual(WidgetPayload.Climb.hoursLeft(from: date(18, 0), to: date(19, 0)), 24)
  }
}
