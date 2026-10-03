// App Store screenshots (1.1.0 release, P4, P5, P7): the host side of
// `flutter drive`. Steers the real app (`capture_app.dart`) through the
// nine frames by tapping it like a person would, using the debug panel for
// the states a fresh month cannot reach (the save point label's moment, the
// Gold celebration, the month card, the sample collection), and saves each
// frame with `xcrun simctl io <device> screenshot`, so the image is the
// simulator's own: the real status bar (fixed by capture.sh at 9:41, full
// battery and signal) and the real text rendering.
//
// Environment (set by capture.sh): SCREENSHOT_UDID, the simulator;
// SCREENSHOT_OUT, the folder for the raw PNGs.
//
// P7's order and names: 01 result, 02 home, 03 gold, 04 review, 05 weak
// spot, 06 question, 07 month card, 08 collection, 09 welcome. They are
// taken in the order the app reaches them; 09 in a second, unseeded run
// (`mode` 'welcome').
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_driver/flutter_driver.dart';

late FlutterDriver _driver;
final _udid = Platform.environment['SCREENSHOT_UDID']!;
final _out = Platform.environment['SCREENSHOT_OUT']!;

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

/// Saves the simulator's screen as [name] after [settleMs] (animations such
/// as hops and fades end within the default).
Future<void> _shot(String name, {int settleMs = 1500}) async {
  await _wait(settleMs);
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

/// A box on screen, in logical points.
typedef _Box = ({SerializableFinder finder, double top, double bottom});

Future<_Box> _box(SerializableFinder f) async => (
      finder: f,
      top: (await _driver.getTopLeft(f)).dy,
      bottom: (await _driver.getBottomRight(f)).dy,
    );

/// Frame 02's scroll (P7: no half-cut text or card at the bottom edge):
/// measured on Home at its top, the smallest scroll at which the screen's
/// bottom edge falls in a gap between two items (or past the last one),
/// with the whole mountain card between the band and the nav bar. Returns
/// the item to align and its `scrollIntoView` alignment, which lands on
/// that scroll exactly whatever Home's scroll is at the time.
Future<(SerializableFinder, double)> _cleanHomeScroll() async {
  await _toTop('HomeScreen');
  await _wait(800);
  final list = await _box(_list('HomeScreen'));
  final navTop = (await _driver.getTopLeft(find.byType('_FloatingNavBar'))).dy;
  SerializableFinder inHome(SerializableFinder f) => find.descendant(
      of: find.byType('HomeScreen'), matching: f, firstMatchOnly: true);
  final card = await _box(inHome(find.byType('ClimbCard')));
  final items = <_Box>[card];
  for (final f in [
    inHome(find.byType('_PracticeModeCard')),
    inHome(find.text('Your weak spots')),
    for (final title in [
      'Gerund vs. Infinitive',
      'Modal Verbs',
      'Tense Selection'
    ])
      find.ancestor(
          of: inHome(find.text(title)),
          matching: find.byType('WeakSpotCard'),
          firstMatchOnly: true),
    inHome(find.byType('_PremiumRow')),
  ]) {
    items.add(await _box(f));
  }
  final viewport = list.bottom - list.top;
  final cardRoom = navTop - list.top; // the card must end above the nav bar
  const margin = 3.0; // Home's smallest gap is 8 pt
  // Bottom-edge positions (content coordinates, Home at its top) that fall
  // clear of every item: each gap's middle, and just past the last item.
  final edges = <double>[
    for (var i = 0; i + 1 < items.length; i++)
      if (items[i + 1].top - items[i].bottom >= 2 * margin)
        (items[i].bottom + items[i + 1].top) / 2 - list.top,
    items.last.bottom + margin - list.top,
  ];
  final contentEnd = items.last.bottom - list.top;
  String f1(double v) => v.toStringAsFixed(1);
  stdout.writeln('frame 02 layout: viewport ${f1(viewport)}, nav bar top '
      '${f1(cardRoom)}, items ${[
    for (final it in items)
      '${f1(it.top - list.top)}-${f1(it.bottom - list.top)}'
  ].join(' ')}, '
      'edges ${edges.map(f1).join(' ')}');
  final cardTop = card.top - list.top, cardBottom = card.bottom - list.top;
  double? best;
  for (final edge in edges) {
    final s = math.max(0.0, edge - viewport);
    // At s = 0 the bottom edge is the viewport's own: clean only if it is
    // past the last item or in a gap.
    final bottomEdge = viewport + s;
    final clean = bottomEdge >= contentEnd + margin ||
        edges.any((e) => (e - bottomEdge).abs() < 0.5);
    if (clean && cardTop - s >= 0 && cardBottom - s <= cardRoom) {
      if (best == null || s < best) best = s;
    }
  }
  if (best == null) {
    throw StateError('No scroll gives Home a clean bottom edge with the '
        'whole mountain card in view.');
  }
  stdout.writeln('frame 02: Home scrolled ${best.toStringAsFixed(1)} pt');
  // scrollIntoView aligns an item: its top at alignment × (viewport −
  // height) from the viewport's top. Any item that lands the scroll on
  // [best] with an alignment in [0, 1] will do.
  for (final it in items) {
    final top = it.top - list.top, h = it.bottom - it.top;
    if (h >= viewport) continue;
    final a = (top - best) / (viewport - h);
    if (a >= 0 && a <= 1) return (it.finder, a);
  }
  throw StateError('No item can align Home at ${best.toStringAsFixed(1)} pt.');
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
  final correctFirst = await _driver.requestData('first_correct');

  // The launch splash, then Home.
  await _driver.waitFor(find.text('Daily Test'),
      timeout: const Duration(seconds: 60));
  await _wait(2500);

  // 06: today's Daily Test, the first question with its right answer typed
  // and the on-screen keyboard up.
  await _tap(find.text('Daily Test'));
  await _driver.waitFor(find.byType('TextField'));
  await _tap(find.byType('TextField'));
  await _driver.enterText(correctFirst);
  // flutter_driver types through its own text-entry emulation, which
  // stands in for iOS's text input, so no keyboard opens. With it off, the
  // field is unfocused and tapped again: it opens a new connection, now to
  // iOS, and the real keyboard comes up on the text already typed. Then
  // the same the other way, back to the emulation for the answers.
  await _driver.requestData('unfocus');
  await _driver.setTextEntryEmulation(enabled: false);
  await _wait(500);
  await _tap(find.byType('TextField'));
  await _shot('06-question', settleMs: 2500);
  await _driver.requestData('unfocus');
  await _driver.setTextEntryEmulation(enabled: true);
  await _wait(800);

  // 01: answer all five (the first wrong, replacing what 06 typed), then
  // the result screen.
  for (final (i, answer) in answers.indexed) {
    await _tap(find.byType('TextField'));
    await _driver.enterText(answer);
    await _tap(find.text(i == answers.length - 1 ? 'Finish' : 'Next'));
    await _wait(700);
  }
  await _driver.waitFor(find.text('See your climb'),
      timeout: const Duration(seconds: 30));
  await _shot('01-result');

  // 02: back on Home the avatar hops onto Halfway Hut. That moment is
  // replayed from the debug panel once Home's clean scroll is known, and
  // the frame is taken while the "Halfway Hut" label shows (about 2.7 s).
  await _tap(find.text('See your climb'));
  await _wait(7000);
  final (align, alignment) = await _cleanHomeScroll();
  await _openDebugPanel();
  await _panelTap(find.byValueKey('debug_milestone_halfway_hut'));
  // The label fades in and out: the driver must not wait for the app to
  // settle here.
  await _driver.runUnsynchronized(() async {
    await _driver.waitFor(find.byValueKey('climb_save_point_label'),
        timeout: const Duration(seconds: 20));
    await _driver.scrollIntoView(align, alignment: alignment);
    await _shot('02-home', settleMs: 350);
  });
  await _wait(3000);

  // 03: the Gold celebration, replayed from the debug panel.
  await _openDebugPanel();
  await _panelTap(find.byValueKey('debug_milestone_gold'));
  await _driver.waitFor(find.text('Tap to continue'),
      timeout: const Duration(seconds: 20));
  await _wait(1500);
  await _shot('03-gold');
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
  // Back to the top of Profile (the panel's row was at its bottom), then
  // the shelf and the bar above the nav bar. On a screen where the whole
  // of Profile fits, there is nothing to scroll.
  await _toTop('SettingsScreen');
  await _driver.scrollIntoView(find.text('Medal collection'), alignment: 0.02);
  await _shot('08-collection');

  // 04 and 05: Review, then its first weak spot.
  await _tap(_tab('Review'));
  await _wait(1200);
  await _shot('04-review');
  await _tap(find.descendant(
      of: find.byType('ReviewScreen'),
      matching: find.byType('WeakSpotCard'),
      firstMatchOnly: true));
  await _wait(1200);
  await _shot('05-weak-spot');

  await _driver.close();
}
