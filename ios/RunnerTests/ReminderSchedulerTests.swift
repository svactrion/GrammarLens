import UserNotifications
import XCTest

@testable import Runner

/// W4: building the reminder requests from the bridge's maps.
final class ReminderSchedulerTests: XCTestCase {
  private var folder: URL!

  override func setUp() {
    super.setUp()
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("reminders-\(UUID().uuidString)", isDirectory: true)
    AppGroupStore.baseDirectoryOverride = folder.appendingPathComponent("group")
  }

  override func tearDown() {
    AppGroupStore.baseDirectoryOverride = nil
    try? FileManager.default.removeItem(at: folder)
    super.tearDown()
  }

  private func item(image: String? = nil) -> [String: Any] {
    var item: [String: Any] = [
      "id": "gl.reminder.2026-11-18", "year": 2026, "month": 11, "day": 18, "hour": 20,
      "minute": 0, "title": "Fox is waiting at First Camp",
      "body": "Today’s 5 questions take about 2 minutes. Step 2 is one test away.",
      "link": "grammarlens://daily-test",
    ]
    if let image { item["image"] = image }
    return item
  }

  func testARequestFiresOnceAtTheLocalTime() throws {
    let request = try XCTUnwrap(ReminderScheduler.request(from: item(), attachmentFolder: folder))
    XCTAssertEqual(request.identifier, "gl.reminder.2026-11-18")
    XCTAssertEqual(request.content.title, "Fox is waiting at First Camp")
    XCTAssertEqual(request.content.userInfo["link"] as? String, "grammarlens://daily-test")
    let trigger = try XCTUnwrap(request.trigger as? UNCalendarNotificationTrigger)
    XCTAssertFalse(trigger.repeats)
    XCTAssertEqual(trigger.dateComponents.year, 2026)
    XCTAssertEqual(trigger.dateComponents.day, 18)
    XCTAssertEqual(trigger.dateComponents.hour, 20)
    XCTAssertEqual(trigger.dateComponents.minute, 0)
    XCTAssertNil(trigger.dateComponents.timeZone, "local wall-clock time")
    XCTAssertTrue(request.content.attachments.isEmpty)
  }

  func testTheCompanionPictureIsAttachedFromTheAppGroup() throws {
    let png = WidgetSamples.solid(.orange, CGSize(width: 60, height: 60)).pngData()!
    XCTAssertTrue(AppGroupStore.write(png, name: "avatar_14.png"))
    let request = try XCTUnwrap(
      ReminderScheduler.request(from: item(image: "avatar_14.png"), attachmentFolder: folder))
    XCTAssertEqual(request.content.attachments.map(\.identifier), ["companion"])
    // A missing file: the reminder still goes, without a picture.
    let without = try XCTUnwrap(
      ReminderScheduler.request(from: item(image: "missing.png"), attachmentFolder: folder))
    XCTAssertTrue(without.content.attachments.isEmpty)
  }

  func testAnIncompleteOrForeignItemIsDropped() {
    var noTitle = item()
    noTitle.removeValue(forKey: "title")
    XCTAssertNil(ReminderScheduler.request(from: noTitle, attachmentFolder: folder))
    var foreign = item()
    foreign["id"] = "someone.else"
    XCTAssertNil(ReminderScheduler.request(from: foreign, attachmentFolder: folder))
  }

  func testStatusNames() {
    XCTAssertEqual(ReminderScheduler.statusName(.notDetermined), "notDetermined")
    XCTAssertEqual(ReminderScheduler.statusName(.authorized), "authorized")
    XCTAssertEqual(ReminderScheduler.statusName(.denied), "denied")
  }
}
