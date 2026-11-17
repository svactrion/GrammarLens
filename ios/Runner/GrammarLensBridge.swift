import Flutter
import UIKit
import WidgetKit

/// The app's own Flutter ↔ iOS bridge (no package): App Group files for the
/// widgets, widget reloads, the `grammarlens://` links and, from W4, the
/// reminder notifications. One channel; every method answers with a plain
/// value, never throws to Dart for an expected failure.
final class GrammarLensBridge: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static let channelName = "com.ahmettayfur.grammarlens/bridge"
  static let linkScheme = "grammarlens"

  /// One instance for the process: a link (scene or notification tap) can
  /// arrive before the Flutter engine exists.
  static let shared = GrammarLensBridge()

  private var channel: FlutterMethodChannel?

  /// A link that arrived before Dart asked for it (`links.initial`); the
  /// latest one wins.
  private var pendingLink: String?

  /// Dart has read the initial link and listens for `links.open`.
  private var dartListening = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = shared
    let channel = FlutterMethodChannel(
      name: channelName, binaryMessenger: registrar.messenger())
    instance.channel = channel
    instance.dartListening = false
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addSceneDelegate(instance)
  }

  // MARK: Links

  /// Takes a `grammarlens://` URL from a widget, a notification or another
  /// app. Anything else is ignored.
  @discardableResult
  func receive(link url: URL) -> Bool {
    guard url.scheme?.lowercased() == Self.linkScheme else { return false }
    let link = url.absoluteString
    if dartListening, let channel {
      channel.invokeMethod("links.open", arguments: ["url": link])
    } else {
      pendingLink = link
    }
    return true
  }

  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    guard let contexts = connectionOptions?.urlContexts else { return false }
    var handled = false
    for context in contexts where receive(link: context.url) { handled = true }
    return handled
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    var handled = false
    for context in URLContexts where receive(link: context.url) { handled = true }
    return handled
  }

  // MARK: Method calls

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "appGroup.write":
      guard let name = args["name"] as? String,
        let bytes = args["bytes"] as? FlutterStandardTypedData
      else {
        result(false)
        return
      }
      result(AppGroupStore.write(bytes.data, name: name))
    case "appGroup.read":
      guard let name = args["name"] as? String, let data = AppGroupStore.read(name) else {
        result(nil)
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    case "appGroup.delete":
      result(AppGroupStore.delete(args["name"] as? String ?? ""))
    case "appGroup.list":
      result(AppGroupStore.list())
    case "appGroup.available":
      result(AppGroupStore.directory() != nil)
    case "widgets.reload":
      WidgetCenter.shared.reloadAllTimelines()
      result(true)
    case "links.initial":
      let link = pendingLink
      pendingLink = nil
      dartListening = true
      result(link)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
