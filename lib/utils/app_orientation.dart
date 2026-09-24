import 'package:flutter/services.dart';

/// The app is portrait-only on every device: every screen is a single
/// vertical column, and none was designed or checked in landscape.
///
/// `portraitDown` is listed for iPad, where upside-down portrait is an
/// ordinary way to hold the device. iOS intersects this list with
/// Info.plist, whose iPhone list has portrait only, so an iPhone stays in
/// `portraitUp`. The Info.plist lists (`UISupportedInterfaceOrientations`
/// and its `~ipad` variant) must agree with this; a test checks both.
const appOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
];

/// Applies [appOrientations]. Called once in `main()`, before `runApp`.
Future<void> lockAppOrientation() =>
    SystemChrome.setPreferredOrientations(appOrientations);
