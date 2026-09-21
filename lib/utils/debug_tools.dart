/// The one switch behind every developer/debug tool in the app (Settings'
/// "Developer" section, the entitlement override, the pricing fixture, the
/// first-launch reset, the theme preview, raw error detail on screen).
///
/// The real guarantee is [kDebugMode], a compile-time constant that is
/// `false` in a release build: every gate is written at its use site as
/// `kDebugMode && DebugTools.enabledForTesting`, which the compiler folds to
/// `false` there, so the guarded UI and code are removed from the release
/// binary rather than merely hidden. [enabledForTesting] exists only because
/// `flutter test` always runs with `kDebugMode == true`: a test sets it to
/// `false` to see the app exactly as a release build would present it. Nothing
/// outside a test ever assigns it.
abstract final class DebugTools {
  static bool enabledForTesting = true;
}
