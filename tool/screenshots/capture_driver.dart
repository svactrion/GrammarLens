// App Store screenshots (1.2.0): the host side of `flutter drive`. Steers
// the real app (`capture_app.dart`) through the frames by tapping it like
// a person would, and saves each frame with `xcrun simctl io <device>
// screenshot`, so the image is the simulator's own: the real status bar
// (fixed by capture.sh at 9:41, full battery and signal) and the real text
// rendering. The debug panel is used for one moment only: replaying the
// Halfway Hut label on Home (frame 02).
//
// Environment (set by capture.sh): SCREENSHOT_UDID, the simulator;
// SCREENSHOT_OUT, the folder for the raw PNGs; SCREENSHOT_DEVICE, `iphone`
// or `ipad` (the iPad takes the free store frames only).
//
// The app's `mode` and `access` (capture_app.dart's defines) pick the run:
//
//   free     01-result, 02-home (Home's top, Halfway Hut label), 03-question
//            ("to eat" typed, as 01 shows),
//            04-review, 05-weak-spot (free: "Start free practice"),
//            07-collection (iPhone: the shelf at the top); for the case study home-free (the mountain
//            card at the top);
//            iPhone only: paywall-annual, paywall-monthly (subscription
//            review, before `release_look`, which ends the price fixture).
//   premium  06-review-premium (Suggested Focus), 05-weak-spot-premium
//            ("Practice this"), home-premium (as home-free); all before
//            `release_look`,
//            which ends Premium. Profile is not taken here.
//   welcome  08-goal: onboarding's goal step, Sam and the Fox, Exam prep
//            chosen (an unseeded install).
//
// Frame numbers follow the owner's 1.2.0 order: 1 result, 2 Home,
// 3 question, 4 Review (free), 5 weak spot, 6 Review (premium), 7 Profile,
// 8 onboarding's goal step.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

late FlutterDriver _driver;
final _udid = Platform.environment['SCREENSHOT_UDID']!;
final _out = Platform.environment['SCREENSHOT_OUT']!;
final _iphone = Platform.environment['SCREENSHOT_DEVICE'] != 'ipad';

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

/// Every driver call that can wait gets a timeout, so a stuck step fails
/// the run instead of hanging it (a tap on an off-screen plan card once
/// waited for 20 minutes).
const _timeout = Duration(seconds: 20);

Future<void> _tap(SerializableFinder f, {int timeoutS = 20}) async {
  await _driver.waitFor(f, timeout: Duration(seconds: timeoutS));
  await _driver.tap(f, timeout: Duration(seconds: timeoutS));
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
    _driver.scroll(_list(type), 0, 4000, const Duration(milliseconds: 400),
        timeout: _timeout);

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
      top: (await _driver.getTopLeft(f, timeout: _timeout)).dy,
      bottom: (await _driver.getBottomRight(f, timeout: _timeout)).dy,
    );

/// Home with the mountain card's top at the top of the screen.
Future<void> _homeCardTop() async {
  await _driver.scrollIntoView(
      find.descendant(
          of: find.byType('HomeScreen'),
          matching: find.byType('ClimbCard'),
          firstMatchOnly: true),
      alignment: 0.0,
      timeout: _timeout);
}

/// 02's scroll (owner, Batch 3): Home at its top, unless a heading
/// then falls across the screen's bottom edge, under the nav bar ("Topic
/// practice" on the iPhone): then scrolled just far enough for the whole
/// heading to show between the nav bar and the edge. Measured with Home at
/// its top; returns the heading and the `scrollIntoView` alignment that
/// lands on that scroll from anywhere, or null for no scroll.
Future<(SerializableFinder, double)?> _homeTopScroll() async {
  await _toTop('HomeScreen');
  await _wait(800);
  final list = await _box(_list('HomeScreen'));
  final heading = find.descendant(
      of: find.byType('HomeScreen'),
      matching: find.text('Topic practice'),
      firstMatchOnly: true);
  final h = await _box(heading);
  final navBottom = (await _driver
          .getBottomRight(find.byType('_FloatingNavBar'), timeout: _timeout))
      .dy;
  final edge = list.bottom;
  String f1(double v) => v.toStringAsFixed(1);
  if (h.top >= edge || h.bottom <= edge) {
    stdout.writeln('02: heading ${f1(h.top)}-${f1(h.bottom)}, edge '
        '${f1(edge)}: no scroll');
    return null;
  }
  final scroll = h.bottom + 4 - edge;
  stdout.writeln('02: heading ${f1(h.top)}-${f1(h.bottom)}, nav bar bottom '
      '${f1(navBottom)}, edge ${f1(edge)}: scrolled ${f1(scroll)} pt');
  if (h.top - scroll < navBottom) {
    stdout.writeln('02: the heading still reaches under the nav bar');
  }
  final viewport = list.bottom - list.top, height = h.bottom - h.top;
  return (heading, (h.top - list.top - scroll) / (viewport - height));
}

/// Takes today's Daily Test from Home: [answers] typed through the
/// text-entry emulation (no keyboard). With [questionShot], first saves
/// 03-question: the first question with the answer the result frame shows
/// ("to eat", wrong) typed and the real keyboard up.
Future<void> _takeDailyTest(List<String> answers,
    {String? questionShot}) async {
  await _tap(find.text('Start daily test'));
  await _driver.waitFor(find.byType('TextField'), timeout: _timeout);
  if (questionShot != null) {
    await _tap(find.byType('TextField'));
    await _driver.enterText(answers.first, timeout: _timeout);
    // flutter_driver types through its own text-entry emulation, which
    // stands in for iOS's text input, so no keyboard opens. With it off,
    // the field is unfocused and tapped again: it opens a new connection,
    // now to iOS, and the real keyboard comes up on the text already
    // typed. Then the same the other way, back to the emulation.
    await _driver.requestData('unfocus', timeout: _timeout);
    await _driver.setTextEntryEmulation(enabled: false, timeout: _timeout);
    await _wait(500);
    await _tap(find.byType('TextField'));
    await _shot(questionShot, settleMs: 2500);
    await _driver.requestData('unfocus', timeout: _timeout);
    await _driver.setTextEntryEmulation(enabled: true, timeout: _timeout);
    await _wait(800);
  }
  for (final (i, answer) in answers.indexed) {
    await _tap(find.byType('TextField'));
    await _driver.enterText(answer, timeout: _timeout);
    await _tap(find.text(i == answers.length - 1 ? 'Finish' : 'Next'));
    await _wait(700);
  }
  await _driver.waitFor(find.text('See your climb'),
      timeout: const Duration(seconds: 30));
}

/// From the result screen back to Home, after the avatar's hop.
Future<void> _backToHome() async {
  await _tap(find.text('See your climb'));
  await _wait(7000);
}

Future<void> _welcomeRun() async {
  // 08: Welcome, then onboarding's first step (Sam, the Fox), then its
  // goal step with Exam prep chosen. Welcome never stops animating, so
  // the driver must not wait for the app to settle there.
  await _driver.runUnsynchronized(() async {
    await _driver.waitFor(find.text('Get started'),
        timeout: const Duration(seconds: 60));
    await _wait(1500);
    await _driver.tap(find.text('Get started'), timeout: _timeout);
  });
  await _wait(1500);
  final name = find.byValueKey('onboarding_name');
  await _tap(name);
  await _driver.enterText('Sam', timeout: _timeout);
  await _driver.requestData('unfocus', timeout: _timeout);
  // The companion is random on mount: step to the Fox.
  final caption = find.byValueKey('avatar_carousel_caption');
  for (var i = 0; i < 20; i++) {
    if (await _driver.getText(caption, timeout: _timeout) == 'Fox') break;
    await _tap(find.byValueKey('avatar_carousel_next'));
    await _wait(700);
  }
  if (await _driver.getText(caption, timeout: _timeout) != 'Fox') {
    throw StateError('The carousel never settled on the Fox.');
  }
  await _tap(find.byValueKey('onboarding_continue'));
  await _wait(800);
  await _tap(find.byValueKey('onboarding_goal_examPrep'));
  await _shot('08-goal');
}

Future<void> _premiumRun(List<String> answers) async {
  // Today's test as in the free run, so Home matches it for the case study.
  await _takeDailyTest(answers);
  await _backToHome();
  await _homeCardTop();
  await _shot('home-premium', settleMs: 1200);

  // 06: Review with Suggested Focus (Modal Verbs, three times).
  await _tap(_tab('Review'));
  await _driver.waitFor(find.byType('SuggestedFocusCard'),
      timeout: const Duration(seconds: 20));
  await _shot('06-review-premium');

  // The weak spot detail with "Practice this", from the first card.
  await _tap(find.descendant(
      of: find.byType('ReviewScreen'),
      matching: find.byType('WeakSpotCard'),
      firstMatchOnly: true));
  await _wait(1200);
  await _shot('05-weak-spot-premium');
}

Future<void> _freeRun(List<String> answers) async {
  // 03 and 01: today's test, then its result.
  await _takeDailyTest(answers, questionShot: '03-question');
  await _shot('01-result');

  // Home with the mountain card at the top (case study), then 02 at the
  // top of Home (owner, Batch 2: the wordmark, the greeting, the Fox and
  // the Glacier scene together): the hop onto Halfway Hut replayed from
  // the debug panel, taken while its label shows (about 2.7 s). The
  // replay scrolls Home to the avatar, so Home goes back to its top once
  // the label is up.
  await _backToHome();
  await _homeCardTop();
  await _shot('home-free', settleMs: 1200);
  final top = await _homeTopScroll();
  await _openDebugPanel();
  await _panelTap(find.byValueKey('debug_milestone_halfway_hut'));
  await _driver.runUnsynchronized(() async {
    await _driver.waitFor(find.byValueKey('climb_save_point_label'),
        timeout: const Duration(seconds: 20));
    if (top == null) {
      await _driver.scroll(
          _list('HomeScreen'), 0, 4000, const Duration(milliseconds: 250),
          timeout: _timeout);
    } else {
      await _driver.scrollIntoView(top.$1,
          alignment: top.$2, timeout: _timeout);
    }
    await _shot('02-home', settleMs: 700);
  });
  await _wait(3000);

  // Subscription review: the paywall with the price fixture, from Topic
  // practice's lock (free), annual (the default) and then monthly.
  if (_iphone) {
    await _toTop('HomeScreen');
    await _driver.scrollUntilVisible(
        _list('HomeScreen'), find.text('Explore all topics'),
        dyScroll: -200, timeout: const Duration(seconds: 20));
    await _tap(find.text('Explore all topics'));
    await _driver.waitFor(find.byValueKey('premium_cta'),
        timeout: const Duration(seconds: 20));
    // The plan cards scrolled up under their heading, so the prices, the
    // trial wording (the footer) and the purchase button share the frame.
    await _wait(1500);
    await _driver.scrollIntoView(find.text('Choose your plan'),
        alignment: 0.0, timeout: _timeout);
    await _shot('paywall-annual', settleMs: 1500);
    await _tap(find.byValueKey('planCard_Monthly'));
    await _shot('paywall-monthly');
    await _tap(find.byTooltip('Close'));
    await _wait(1200);
  }

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
  await _tap(find.pageBack());
  await _wait(1200);

  // 07: Profile as a release build shows it (no Developer section). The
  // iPhone: "Medal collection" at the top, the Fox card out of frame (the
  // notch cut the Fox's head; owner, Batch 3). The iPad: from the top,
  // where all of it fits (owner, Batch 2).
  await _tap(_tab('Profile'));
  await _wait(1200);
  await _driver.requestData('release_look', timeout: _timeout);
  await _wait(1200);
  await _toTop('SettingsScreen');
  await _wait(800);
  if (_iphone) {
    await _driver.scrollIntoView(find.text('Medal collection'),
        alignment: 0.02, timeout: _timeout);
  }
  await _shot('07-collection');
}

Future<void> main() async {
  Directory(_out).createSync(recursive: true);
  _driver = await FlutterDriver.connect(timeout: const Duration(minutes: 2));
  // The app seeds its data before runApp: no finder works until then.
  await _driver
      .waitUntilFirstFrameRasterized()
      .timeout(const Duration(minutes: 2));
  if (await _driver.requestData('mode', timeout: _timeout) == 'welcome') {
    await _welcomeRun();
    await _driver.close();
    return;
  }
  final answers =
      (jsonDecode(await _driver.requestData('answers', timeout: _timeout))
              as List)
          .cast<String>();

  // The launch splash, then Home.
  await _driver.waitFor(find.text('Start daily test'),
      timeout: const Duration(seconds: 60));
  await _wait(2500);

  if (await _driver.requestData('access', timeout: _timeout) == 'premium') {
    await _premiumRun(answers);
  } else {
    await _freeRun(answers);
  }
  await _driver.close();
}
