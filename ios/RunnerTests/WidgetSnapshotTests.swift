import SwiftUI
import UIKit
import XCTest

@testable import Runner

/// W2: renders every widget × state × appearance to PNG with `ImageRenderer`
/// (iOS 16+) for the comparison with the W01 board. The images go to
/// `$SNAPSHOT_DIR` (passed as `TEST_RUNNER_SNAPSHOT_DIR`, normally
/// `build/widget-snapshots/`), else to the temporary folder. The sample
/// payload is `WidgetSamples`, or `test/fixtures/widget_payload_*.json`
/// written by the Dart payload builder when `REPO_ROOT` is given.
@MainActor
final class WidgetSnapshotTests: XCTestCase {
  static let small = CGSize(width: 170, height: 170)
  static let medium = CGSize(width: 364, height: 170)

  private var appGroup: URL!
  private var outDir: URL!

  override func setUp() async throws {
    try await super.setUp()
    appGroup = FileManager.default.temporaryDirectory
      .appendingPathComponent("widget-snapshots-group-\(UUID().uuidString)", isDirectory: true)
    AppGroupStore.baseDirectoryOverride = appGroup
    WidgetRendering.plainBackground = true
    let env = ProcessInfo.processInfo.environment
    outDir = URL(fileURLWithPath: env["SNAPSHOT_DIR"] ?? NSTemporaryDirectory())
      .appendingPathComponent(env["SNAPSHOT_DIR"] == nil ? "widget-snapshots" : "", isDirectory: true)
    try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    try WidgetSamples.writeImages(repoRoot: env["REPO_ROOT"])
  }

  override func tearDown() async throws {
    AppGroupStore.baseDirectoryOverride = nil
    WidgetRendering.plainBackground = false
    try? FileManager.default.removeItem(at: appGroup)
    try await super.tearDown()
  }

  private func render<V: View>(
    _ view: V, size: CGSize, scheme: ColorScheme, rtl: Bool = false, name: String
  ) throws {
    guard #available(iOS 16.0, *) else { throw XCTSkip("ImageRenderer needs iOS 16") }
    let framed =
      view
      .frame(width: size.width, height: size.height)
      .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
      .environment(\.colorScheme, scheme)
      .environment(\.layoutDirection, rtl ? .rightToLeft : .leftToRight)
      .padding(10)
      .background(scheme == .dark ? Color(hex: 0x15141A) : Color(hex: 0x223156))
    let renderer = ImageRenderer(content: framed)
    renderer.scale = 3
    let image = try XCTUnwrap(renderer.uiImage, name)
    let data = try XCTUnwrap(image.pngData(), name)
    XCTAssertEqual(image.size.width, size.width + 20, accuracy: 0.5, name)
    XCTAssertGreaterThan(data.count, 5_000, "\(name) looks empty")
    try data.write(to: outDir.appendingPathComponent("\(name).png"))
  }

  private func renderAll(payload: WidgetPayload, suffix: String) throws {
    let now = payload.entries[0]
    let hours = 10
    for scheme in [ColorScheme.light, .dark] {
      let tag = "\(suffix)-\(scheme == .dark ? "dark" : "light")"
      let state = now.climb.isDone ? "done" : "waiting"
      try render(
        ClimbSmallView(climb: now.climb, hoursLeft: hours), size: Self.small, scheme: scheme,
        rtl: payload.rtl, name: "climb-small-\(state)-\(tag)")
      try render(
        ClimbMediumView(climb: now.climb, hoursLeft: hours), size: Self.medium, scheme: scheme,
        rtl: payload.rtl, name: "climb-medium-\(state)-\(tag)")
      try render(
        TipMediumView(tip: now.tip, avatar: now.climb.images.avatar), size: Self.medium,
        scheme: scheme, rtl: payload.rtl, name: "tip-medium-\(state)-\(tag)")
    }
  }

  func testWaiting() throws {
    try renderAll(payload: WidgetSamples.payload(done: false), suffix: "sample")
  }

  func testDone() throws {
    try renderAll(payload: WidgetSamples.payload(done: true), suffix: "sample")
  }

  func testGeneralTip() throws {
    var payload = WidgetSamples.payload(done: false)
    payload.entries[0].tip = WidgetSamples.generalTip
    let now = payload.entries[0]
    try render(
      TipMediumView(tip: now.tip, avatar: now.climb.images.avatar), size: Self.medium,
      scheme: .light, name: "tip-medium-general-sample-light")
  }

  func testEmpty() throws {
    try render(EmptyWidgetView(), size: Self.small, scheme: .light, name: "empty-small")
  }

  /// The payloads the Dart builder wrote (W3), when the repository is known.
  func testDartFixtures() throws {
    guard let root = ProcessInfo.processInfo.environment["REPO_ROOT"] else {
      throw XCTSkip("REPO_ROOT not set")
    }
    let folder = URL(fileURLWithPath: root).appendingPathComponent("test/fixtures/widget_payloads")
    let names =
      (try? FileManager.default.contentsOfDirectory(atPath: folder.path))?
      .filter { $0.hasSuffix(".json") }.sorted() ?? []
    if names.isEmpty { throw XCTSkip("no Dart fixtures yet") }
    for name in names {
      let data = try Data(contentsOf: folder.appendingPathComponent(name))
      let payload = try XCTUnwrap(WidgetPayload.decode(data), name)
      try renderAll(payload: payload, suffix: (name as NSString).deletingPathExtension)
    }
  }
}

/// A hand-written payload in the board's sample data (W01: Ada, Fox,
/// November on Ember Peak, step 2 of 30).
enum WidgetSamples {
  static let avatar = "avatar.png"
  static let light = "mountain_sample_light.png"
  static let dark = "mountain_sample_dark.png"
  /// Where the crop puts step 1 (fractions of the medium widget).
  static let point = [0.36, 0.72]

  static let generalTip = WidgetPayload.Tip(
    url: "grammarlens://daily-test", label: "TIP OF THE DAY · ARTICLES", rule: "an",
    example: "before a vowel sound: an hour", footer: "A new tip every day",
    boxLabel: "DAILY TEST", button: "Start", done: false)

  static func payload(done: Bool) -> WidgetPayload {
    let countdown = Dictionary(uniqueKeysWithValues: (1...24).map { ("\($0)", "Next test in \($0) h") })
    let countdownMedium = Dictionary(
      uniqueKeysWithValues: (1...24).map { ("\($0)", "Next test in \($0) h · 1/30") })
    let climb = WidgetPayload.Climb(
      state: done ? "done" : "waiting",
      url: done ? "grammarlens://home" : "grammarlens://daily-test",
      step: 2, steps: 30,
      label: done ? "Done today" : "DAILY TEST",
      title: done ? "Step 2 of 30" : "Step 2 is waiting",
      subtitle: "5 questions · 2 min", stepBadge: "1/30", points: "18",
      mediumTitle: done ? "See you tomorrow, Ada" : "Step 2 is one test away",
      mediumSubtitle: "Ember Peak · November · 1/30",
      chip: done ? "Done today" : "Test waiting", button: "Start",
      countdown: done ? countdown : [:], countdownMedium: done ? countdownMedium : [:],
      images: .init(avatar: avatar, mountainLight: light, mountainDark: dark),
      avatarPoint: point)
    let tip = WidgetPayload.Tip(
      url: done ? "grammarlens://home" : "grammarlens://daily-test",
      label: "TIP FOR YOU · ARTICLES", rule: "the",
      example: "specific, known, or the only one",
      footer: "From your weak spots · new tip daily", boxLabel: "DAILY TEST",
      button: done ? "Done today" : "Start", done: done)
    let now = Date().timeIntervalSince1970
    return WidgetPayload(
      schema: 1, writtenAt: now, rtl: false,
      entries: [.init(validFrom: now, climb: climb, tip: tip)])
  }

  /// The avatar and two mountain crops from the app's assets (W3 writes the
  /// real ones from the app). Without the repository, plain colour images.
  static func writeImages(repoRoot: String?) throws {
    func source(_ path: String) -> UIImage? {
      guard let repoRoot else { return nil }
      return UIImage(contentsOfFile: repoRoot + "/" + path)
    }
    let avatarImage =
      source("assets/avatars/avatar_14.webp") ?? solid(.orange, CGSize(width: 240, height: 240))
    AppGroupStore.write(try XCTUnwrap(avatarImage.pngData()), name: avatar)
    for (name, path) in [
      (light, "assets/climb/ember_peak/background_light.webp"),
      (dark, "assets/climb/ember_peak/background_dark.webp"),
    ] {
      let image = source(path).map { crop($0) } ?? solid(.darkGray, CGSize(width: 1092, height: 510))
      AppGroupStore.write(try XCTUnwrap(image.pngData()), name: name)
    }
  }

  /// A medium-widget-shaped slice of the lower trail, like the app's crop.
  static func crop(_ image: UIImage) -> UIImage {
    guard let cg = image.cgImage else { return image }
    let width = CGFloat(cg.width)
    let height = width * 170 / 364
    let rect = CGRect(x: 0, y: CGFloat(cg.height) * 0.86 - height * 0.72, width: width, height: height)
    guard let cropped = cg.cropping(to: rect.integral) else { return image }
    return UIImage(cgImage: cropped)
  }

  static func solid(_ color: UIColor, _ size: CGSize) -> UIImage {
    UIGraphicsImageRenderer(size: size).image { context in
      color.setFill()
      context.fill(CGRect(origin: .zero, size: size))
    }
  }
}
