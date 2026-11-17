import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // The reminders' delegate: nothing shown in front, taps open their link.
    ReminderScheduler.shared.install()
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // The app's own bridge (widgets, links, reminders): not a package.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "GrammarLensBridge") {
      GrammarLensBridge.register(with: registrar)
    }
  }
}
