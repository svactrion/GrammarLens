// App Store screenshots (1.1.0 release, P4, P5): the host side of
// `flutter drive`. Steers the real app (`capture_app.dart`) through the
// nine frames by tapping it like a person would, using the debug panel for
// the states a fresh month cannot reach (the Gold celebration, the month
// card, the sample collection), and saves each frame with
// `xcrun simctl io <device> screenshot`, so the image is the simulator's
// own: the real status bar (fixed by capture.sh at 9:41, full battery and
// signal) and the real text rendering.
//
// Environment (set by capture.sh): SCREENSHOT_UDID, the simulator;
// SCREENSHOT_OUT, the folder for the raw PNGs.
//
// P4's order and names: 01 result, 02 home, 03 question, 04 gold,
// 05 review, 06 weak spot, 07 month card, 08 collection, 09 welcome. They
// are taken in the order the app reaches them; 09 in a second, unseeded
// run (`mode` 'welcome').
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

late FlutterDriver _driver;
final _udid = Platform.environment['SCREENSHOT_UDID']!;
final _out = Platform.environment['SCREENSHOT_OUT']!;

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

Future<void> _shot(String name) async {
  // Let the frame settle: animations (hops, fades) end within this.
  await _wait(1500);
  final file = '$_out/$name.png';
  final r = await Process.run(
      'xcrun', ['simctl', 'io', _udid, 'screenshot', '--type=png', file]);
  if (r.exitCode != 0) throw StateError('screenshot failed: ${r.stderr}');
  stdout.writeln('captured $file');
}

Future<void> _tap(SerializableFinder f, {int timeoutS = 20}) async {
  await _driver.waitFor(f, timeout: Duration(seconds: timeoutS));
  await _driver.tap(f);
}

SerializableFinder _tab(String label) => find.descendant(
    of: find.byType('_FloatingNavBar'),
    matching: find.text(label),
    firstMatchOnly: true);

/// The scrolling list of the screen [type] (Home, Profile).
SerializableFinder _list(String type) => find.descendant(
    of: find.byType(type),
    matching: find.byType('ListView'),
    firstMatchOnly: true);

/// Back to the top of [type]'s list.
Future<void> _toTop(String type) =>
    _driver.scroll(_list(type), 0, 4000, const Duration(milliseconds: 400));

/// Opens Settings' debug panel from the Profile tab.
Future<void> _openDebugPanel() async {
  await _tap(_tab('Profile'));
  await _wait(800);
  final row = find.byValueKey('settings_debug_row');
  await _driver.scrollUntilVisible(_list('SettingsScreen'), row,
      dyScroll: -400, timeout: const Duration(seconds: 20));
  await _tap(row);
  await _wait(800);
}

/// Scrolls the debug panel to [item] and taps it.
Future<void> _panelTap(SerializableFinder item) async {
  await _driver.scrollUntilVisible(_list('DebugPanelScreen'), item,
      dyScroll: -300, timeout: const Duration(seconds: 20));
  await _tap(item);
}

Future<void> main() async {
  Directory(_out).createSync(recursive: true);
  _driver = await FlutterDriver.connect();
  // The app seeds its data before runApp: no finder works until then.
  await _driver.waitUntilFirstFrameRasterized();
  if (await _driver.requestData('mode') == 'welcome') {
    // 09: Welcome, on a fresh install (capture.sh's second run). Welcome
    // never stops animating, so the driver must not wait for the app to
    // settle.
    await _driver.runUnsynchronized(() => _driver.waitFor(
        find.text('Get started'),
        timeout: const Duration(seconds: 60)));
    await _wait(3000);
    await _shot('09-welcome');
    await _driver.close();
    return;
  }
  final answers =
      (jsonDecode(await _driver.requestData('answers')) as List).cast<String>();

  // The launch splash, then Home.
  await _driver.waitFor(find.text('Daily Test'),
      timeout: const Duration(seconds: 60));
  await _wait(2500);

  // 03: today's Daily Test, first question.
  await _tap(find.text('Daily Test'));
  await _driver.waitFor(find.byType('TextField'));
  await _shot('03-question');

  // 01: answer all five (the first wrong), then the result screen.
  for (final (i, answer) in answers.indexed) {
    await _tap(find.byType('TextField'));
    await _driver.enterText(answer);
    await _tap(find.text(i == answers.length - 1 ? 'Finish' : 'Next'));
    await _wait(700);
  }
  await _driver.waitFor(find.text('See your climb'),
      timeout: const Duration(seconds: 30));
  await _shot('01-result');

  // 02: back on Home the avatar hops onto Halfway Hut; the frame is taken
  // once the hop and its label have finished.
  await _tap(find.text('See your climb'));
  await _wait(7000);
  // Home scrolled to the mountain for the hop; the frame shows it from
  // the top, greeting included, as 1.0.0's did.
  await _toTop('HomeScreen');
  await _shot('02-home');

  // 04: the Gold celebration, replayed from the debug panel.
  await _openDebugPanel();
  await _panelTap(find.byValueKey('debug_milestone_gold'));
  await _driver.waitFor(find.text('Tap to continue'),
      timeout: const Duration(seconds: 20));
  await _wait(1500);
  await _shot('04-gold');
  await _tap(find.text('Tap to continue'));
  await _wait(1500);

  // 07: the month card's summary, Gold, replayed from the debug panel.
  await _openDebugPanel();
  await _panelTap(find.byValueKey('debug_month_card_summary_gold'));
  await _driver.waitFor(find.text('See the mountain'),
      timeout: const Duration(seconds: 20));
  await _shot('07-month-card');
  await _tap(find.text('See the mountain'));
  await _wait(3500);

  // 08: Profile with the sample collection (P6).
  await _openDebugPanel();
  await _panelTap(find.byValueKey('debug_sample_collection'));
  await _driver.tap(find.pageBack());
  await _wait(1200);
  // What a release build shows: no Developer section (debug builds only).
  await _driver.requestData('release_look');
  await _wait(1200);
  // Back to the top of Profile (the panel's row was at its bottom).
  await _toTop('SettingsScreen');
  // The shelf and the bar above the nav bar.
  await _driver.scrollIntoView(find.text('Medal collection'), alignment: 0.02);
  await _shot('08-collection');

  // 05 and 06: Review, then its first weak spot.
  await _tap(_tab('Review'));
  await _wait(1200);
  await _shot('05-review');
  await _tap(find.descendant(
      of: find.byType('ReviewScreen'),
      matching: find.byType('WeakSpotCard'),
      firstMatchOnly: true));
  await _wait(1200);
  await _shot('06-weak-spot');

  await _driver.close();
}
