import Foundation

/// The files the app shares with the widget extension, in the App Group
/// container (`<group>/widget/<name>`). The app writes them through the
/// bridge (`GrammarLensBridge`); the extension only reads them.
///
/// Compiled into Runner and the widget extension.
enum AppGroupStore {
  static let groupIdentifier = "group.com.ahmettayfur.grammarlens"
  static let folderName = "widget"

  /// Tests point the store at a temporary folder.
  static var baseDirectoryOverride: URL?

  /// The shared folder, or nil when the App Group is not available (the
  /// entitlement is missing, e.g. an unsigned build).
  static func directory(create: Bool = false) -> URL? {
    let base =
      baseDirectoryOverride
      ?? FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: groupIdentifier)
    guard let base else { return nil }
    let directory = base.appendingPathComponent(folderName, isDirectory: true)
    if create {
      try? FileManager.default.createDirectory(
        at: directory, withIntermediateDirectories: true)
    }
    return directory
  }

  /// A plain file name: lower-case letters, digits, `_`, `-` and `.`, at most
  /// 96 characters, not starting with a dot. Nothing else reaches the disk,
  /// so a name can never leave the folder.
  static func isValidName(_ name: String) -> Bool {
    guard !name.isEmpty, name.count <= 96, !name.hasPrefix(".") else {
      return false
    }
    let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789_-.")
    return name.allSatisfy { allowed.contains($0) }
  }

  static func fileURL(_ name: String, create: Bool = false) -> URL? {
    guard isValidName(name), let directory = directory(create: create) else {
      return nil
    }
    return directory.appendingPathComponent(name, isDirectory: false)
  }

  @discardableResult
  static func write(_ data: Data, name: String) -> Bool {
    guard let url = fileURL(name, create: true) else { return false }
    do {
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      return false
    }
  }

  static func read(_ name: String) -> Data? {
    guard let url = fileURL(name) else { return nil }
    return try? Data(contentsOf: url)
  }

  @discardableResult
  static func delete(_ name: String) -> Bool {
    guard let url = fileURL(name) else { return false }
    do {
      try FileManager.default.removeItem(at: url)
      return true
    } catch {
      return !FileManager.default.fileExists(atPath: url.path)
    }
  }

  static func list() -> [String] {
    guard let directory = directory(),
      let names = try? FileManager.default.contentsOfDirectory(
        atPath: directory.path)
    else { return [] }
    return names.filter(isValidName).sorted()
  }
}
