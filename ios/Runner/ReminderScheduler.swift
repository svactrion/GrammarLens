import Foundation
import UIKit
import UserNotifications

/// The daily reminders (TASK-widgets fixed decision 4, W4) on
/// `UNUserNotificationCenter`: permission, one non-repeating calendar
/// trigger per planned day (the plan is Dart's, `reminder_plan.dart`),
/// nothing shown while the app is in front, and a tap handed to the bridge
/// as a `grammarlens://` link.
final class ReminderScheduler: NSObject, UNUserNotificationCenterDelegate {
  static let shared = ReminderScheduler()
  static let idPrefix = "gl.reminder."

  private var center: UNUserNotificationCenter { .current() }

  /// Set in `didFinishLaunching`, before the first frame, so a tap that
  /// launched the app is seen.
  func install() {
    center.delegate = self
  }

  // MARK: Permission

  static func statusName(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown"
    }
  }

  func status(_ completion: @escaping (String) -> Void) {
    center.getNotificationSettings { settings in
      DispatchQueue.main.async { completion(Self.statusName(settings.authorizationStatus)) }
    }
  }

  func requestPermission(_ completion: @escaping (Bool) -> Void) {
    center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
      DispatchQueue.main.async { completion(granted) }
    }
  }

  // MARK: Scheduling

  /// One request from the bridge's map, or nil when a field is missing.
  static func request(from item: [String: Any], attachmentFolder: URL?) -> UNNotificationRequest? {
    guard let id = item["id"] as? String, id.hasPrefix(idPrefix),
      let year = item["year"] as? Int, let month = item["month"] as? Int,
      let day = item["day"] as? Int, let hour = item["hour"] as? Int,
      let minute = item["minute"] as? Int,
      let title = item["title"] as? String, let body = item["body"] as? String,
      let link = item["link"] as? String
    else { return nil }
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    content.threadIdentifier = "gl.reminder"
    content.userInfo = ["link": link]
    if let image = item["image"] as? String, let attachment = attachment(image, id: id, folder: attachmentFolder) {
      content.attachments = [attachment]
    }
    // Local wall-clock time, non-repeating: a reminder keeps its hour when
    // the time zone changes.
    let components = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
  }

  /// The companion's picture (N02). iOS moves an attachment's file into its
  /// own store when the request is added, so every request gets its own
  /// copy of the App Group file. Nil when the file is missing or iOS
  /// refuses it (then the reminder goes without a picture).
  static func attachment(_ name: String, id: String, folder: URL?) -> UNNotificationAttachment? {
    guard let data = AppGroupStore.read(name) else { return nil }
    let base = folder ?? FileManager.default.temporaryDirectory.appendingPathComponent("gl-reminders", isDirectory: true)
    try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
    let url = base.appendingPathComponent("\(id)-\(UUID().uuidString).png")
    guard (try? data.write(to: url)) != nil else { return nil }
    return try? UNNotificationAttachment(identifier: "companion", url: url, options: nil)
  }

  /// Replaces every pending reminder with [items]; answers how many were
  /// added.
  func schedule(_ items: [[String: Any]], completion: @escaping (Int) -> Void) {
    let requests = items.compactMap { Self.request(from: $0, attachmentFolder: nil) }
    removePending {
      let group = DispatchGroup()
      var added = 0
      let lock = NSLock()
      for request in requests {
        group.enter()
        self.center.add(request) { error in
          if error == nil {
            lock.lock()
            added += 1
            lock.unlock()
          }
          group.leave()
        }
      }
      group.notify(queue: .main) { completion(added) }
    }
  }

  private func removePending(then next: @escaping () -> Void) {
    center.getPendingNotificationRequests { pending in
      let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }
      self.center.removePendingNotificationRequests(withIdentifiers: ours)
      next()
    }
  }

  func cancelAll(_ completion: @escaping () -> Void) {
    removePending {
      self.center.getDeliveredNotifications { delivered in
        let ours = delivered.map(\.request.identifier).filter { $0.hasPrefix(Self.idPrefix) }
        self.center.removeDeliveredNotifications(withIdentifiers: ours)
        DispatchQueue.main.async { completion() }
      }
    }
  }

  func pending(_ completion: @escaping ([String]) -> Void) {
    center.getPendingNotificationRequests { pending in
      let ours = pending.map(\.identifier).filter { $0.hasPrefix(Self.idPrefix) }.sorted()
      DispatchQueue.main.async { completion(ours) }
    }
  }

  // MARK: Settings

  static func openSettings() -> Bool {
    let name: String
    if #available(iOS 16.0, *) {
      name = UIApplication.openNotificationSettingsURLString
    } else {
      name = UIApplication.openSettingsURLString
    }
    guard let url = URL(string: name) else { return false }
    UIApplication.shared.open(url)
    return true
  }

  // MARK: UNUserNotificationCenterDelegate

  /// The app is in front: show nothing (fixed decision 4).
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([])
  }

  /// A tap: the reminder's link opens the right screen.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let link = response.notification.request.content.userInfo["link"] as? String,
      let url = URL(string: link)
    {
      DispatchQueue.main.async { GrammarLensBridge.shared.receive(link: url) }
    }
    completionHandler()
  }
}
