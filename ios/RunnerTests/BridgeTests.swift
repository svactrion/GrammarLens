import Flutter
import XCTest

@testable import Runner

/// W1: the App Group store and the bridge's link buffering.
final class AppGroupStoreTests: XCTestCase {
  private var folder: URL!

  override func setUp() {
    super.setUp()
    folder = FileManager.default.temporaryDirectory
      .appendingPathComponent("appgroup-\(UUID().uuidString)", isDirectory: true)
    AppGroupStore.baseDirectoryOverride = folder
  }

  override func tearDown() {
    AppGroupStore.baseDirectoryOverride = nil
    try? FileManager.default.removeItem(at: folder)
    super.tearDown()
  }

  func testWriteReadListDelete() {
    XCTAssertTrue(AppGroupStore.write(Data([1, 2, 3]), name: "payload.json"))
    XCTAssertEqual(AppGroupStore.read("payload.json"), Data([1, 2, 3]))
    XCTAssertTrue(AppGroupStore.write(Data([4]), name: "avatar.png"))
    XCTAssertEqual(AppGroupStore.list(), ["avatar.png", "payload.json"])
    XCTAssertTrue(AppGroupStore.delete("avatar.png"))
    XCTAssertEqual(AppGroupStore.list(), ["payload.json"])
    XCTAssertTrue(AppGroupStore.delete("missing.png"), "deleting nothing is fine")
  }

  func testFilesLiveInTheWidgetFolder() {
    AppGroupStore.write(Data([9]), name: "a.png")
    let expected = folder.appendingPathComponent("widget/a.png")
    XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))
  }

  func testUnsafeNamesNeverReachTheDisk() {
    for name in ["../escape", "a/b", ".hidden", "UPPER.png", "", "a b", String(repeating: "a", count: 97)] {
      XCTAssertFalse(AppGroupStore.isValidName(name), name)
      XCTAssertFalse(AppGroupStore.write(Data([1]), name: name), name)
      XCTAssertNil(AppGroupStore.read(name), name)
    }
    XCTAssertTrue(AppGroupStore.list().isEmpty)
  }

  func testBridgeKeepsAColdStartLinkUntilDartAsks() {
    let bridge = GrammarLensBridge()
    XCTAssertTrue(bridge.receive(link: URL(string: "grammarlens://home")!))
    XCTAssertTrue(bridge.receive(link: URL(string: "grammarlens://daily-test")!))
    XCTAssertFalse(bridge.receive(link: URL(string: "https://example.com")!))
    let first = expectation(description: "initial")
    bridge.handle(FlutterMethodCall(methodName: "links.initial", arguments: nil)) { value in
      XCTAssertEqual(value as? String, "grammarlens://daily-test", "the latest wins")
      first.fulfill()
    }
    let second = expectation(description: "read once")
    bridge.handle(FlutterMethodCall(methodName: "links.initial", arguments: nil)) { value in
      XCTAssertNil(value)
      second.fulfill()
    }
    wait(for: [first, second], timeout: 1)
  }

  func testBridgeWritesAndReadsThroughTheChannelShape() {
    let bridge = GrammarLensBridge()
    let wrote = expectation(description: "write")
    bridge.handle(
      FlutterMethodCall(
        methodName: "appGroup.write",
        arguments: ["name": "payload.json", "bytes": FlutterStandardTypedData(bytes: Data([5]))])
    ) { value in
      XCTAssertEqual(value as? Bool, true)
      wrote.fulfill()
    }
    let read = expectation(description: "read")
    bridge.handle(FlutterMethodCall(methodName: "appGroup.read", arguments: ["name": "payload.json"])) {
      value in
      XCTAssertEqual((value as? FlutterStandardTypedData)?.data, Data([5]))
      read.fulfill()
    }
    wait(for: [wrote, read], timeout: 1)
  }
}
