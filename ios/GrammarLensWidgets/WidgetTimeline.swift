import SwiftUI
import WidgetKit

/// One moment of a widget: the payload entry and, when today's test is
/// done, the countdown's whole hours.
struct GrammarLensEntry: TimelineEntry {
  let date: Date
  /// Nil before the app has written anything (a fresh install).
  let payload: WidgetPayload?
  let entry: WidgetPayload.Entry?
  /// Done state: the countdown line's hours (1…24).
  let hoursLeft: Int

  static let empty = GrammarLensEntry(date: Date(), payload: nil, entry: nil, hoursLeft: 0)
}

/// Builds the timeline from the app's payload (TASK-widgets fixed decision
/// 3, DW0-4): the current entry; when today's test is done, one entry at
/// every top of the hour until the next test (the countdown); then the
/// precomputed waiting entry from the next local midnight.
enum GrammarLensTimeline {
  static func loadPayload() -> WidgetPayload? {
    guard let data = AppGroupStore.read(WidgetPayload.fileName) else { return nil }
    return WidgetPayload.decode(data)
  }

  static func entries(
    payload: WidgetPayload?, now: Date, calendar: Calendar = .current
  ) -> [GrammarLensEntry] {
    guard let payload else { return [.init(date: now, payload: nil, entry: nil, hoursLeft: 0)] }
    let current = payload.entry(at: now)
    let later = payload.entries.filter { $0.date > now }
    var result: [GrammarLensEntry] = []
    // The next test starts with the next entry, or at the next midnight.
    let nextTest = later.first?.date ?? calendar.startOfDay(for: now.addingTimeInterval(86_400))
    if current.climb.isDone {
      var moment = now
      while moment < nextTest {
        result.append(
          .init(
            date: moment, payload: payload, entry: current,
            hoursLeft: WidgetPayload.Climb.hoursLeft(from: moment, to: nextTest)))
        guard
          let nextHour = calendar.nextDate(
            after: moment, matching: DateComponents(minute: 0, second: 0),
            matchingPolicy: .nextTime)
        else { break }
        moment = nextHour
      }
    } else {
      result.append(.init(date: now, payload: payload, entry: current, hoursLeft: 0))
    }
    for entry in later {
      let hours = entry.climb.isDone ? 24 : 0
      result.append(.init(date: entry.date, payload: payload, entry: entry, hoursLeft: hours))
    }
    return result
  }
}

struct GrammarLensProvider: TimelineProvider {
  func placeholder(in context: Context) -> GrammarLensEntry {
    GrammarLensTimeline.entries(payload: GrammarLensTimeline.loadPayload(), now: Date()).first
      ?? .empty
  }

  func getSnapshot(in context: Context, completion: @escaping (GrammarLensEntry) -> Void) {
    completion(placeholder(in: context))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GrammarLensEntry>) -> Void) {
    let entries = GrammarLensTimeline.entries(
      payload: GrammarLensTimeline.loadPayload(), now: Date())
    // The app reloads the timelines whenever its state changes; after the
    // last entry the widget keeps showing it (the waiting state).
    completion(Timeline(entries: entries, policy: .never))
  }
}
