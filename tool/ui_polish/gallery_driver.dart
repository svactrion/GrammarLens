// UI polish board gallery: the host side of `flutter drive`. Asks the
// gallery app (`gallery_app.dart`) for each board and saves the simulator's
// screen with `xcrun simctl io <udid> screenshot`.
//
// Environment (set by capture.sh): CAPTURE_UDID, the simulator;
// CAPTURE_OUT, the folder for the PNGs; CAPTURE_BOARDS, a comma-separated
// list of board ids (default: every board the app lists). An id may end in
// ":dark" for the dark theme.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

/// Boards that need longer than the default to reach the frame worth
/// comparing (an entrance, a fill, a count-up).
const _settleMs = <String, int>{
  'V05b-GettingReady': 2600,
  'V10-Results': 3200,
  'V12-Climb': 5400,
  'R04-MonthCard': 3500,
  'V13a-PaywallPlans': 2600,
  'V13c-PaywallCompare': 2600,
  'R04b-NewMountain': 2800,
  'V14-Home': 2200,
  'V15-HomeNextDay': 2200,
  'H04-HomePremium': 2200,
  'V24-DayComplete': 2000,
  'V24f-RestFree': 2000,
  'N01-OverRest': 2600,
  'V13r-PaywallRest': 1800,
  'PW05r-PremiumOnRest': 2200,
  'V11-Badge': 2200,
  'R05-Medal': 2200,
  'PW05-PremiumOn': 2200,
};

/// Long system boards: extra captures scrolled down by these offsets.
const _scrollShots = <String, List<int>>{
  'V23-Profile': [420],
  'V14-Home': [520],
  // Fix round 1: the pawn and the next step's gold ring (under the nav bar
  // in the first frame).
  'V15-HomeNextDay': [360],
  'H04-HomePremium': [520],
  'X04-Ticket': [420],
  'X05-DailyCard': [560],
  'V00-CompanionSystem': [500],
  'X03-HeroSet': [400],
  // INTEGRATE 3a: "Remind me tomorrow" under the Premium card, scrolled
  // into view where it is below the first view.
  'V24f-RestFree': [400],
  'V24-DayComplete': [400],
};

/// Fix round 2, item 1: a second capture this long after the first, to
/// show the companions' loops at another moment (`-t2`).
const _motionShots = <String, int>{
  'V02-Welcome': 1100,
  'V15-HomeNextDay': 550,
  'V13-Paywall': 600,
  'V23-Profile': 1500,
  'V24f-RestFree': 1200,
};

/// Boards captured through real taps: the steps after the board is shown,
/// and the captures to take (a suffix per extra capture; '' is the board's
/// own capture).
typedef Shot = Future<void> Function(String suffix);
typedef Script = Future<void> Function(FlutterDriver d, Shot shot);

Future<void> _wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

final _scripts = <String, Script>{
  'V01-Splash': (d, shot) async {
    await _wait(650);
    await shot('-mid');
    await _wait(1100);
    await shot('');
  },
  // V12: the camera's key frames (V12b: wide, close, wide again) and the
  // end with the bubble and Continue.
  'V12b-ClimbStoryboard': (d, shot) async {
    await _wait(150);
    await shot('-1-wide');
    await _wait(1950);
    await shot('-2-close');
    await _wait(2700);
    await shot('-3-wide');
  },
  'V16b-TicketTear': (d, shot) async {
    await _wait(1400);
    await d.tapNow('review_practice_ticket');
    await _wait(250);
    await shot('');
    await _wait(900);
    await shot('-2-practice-starts');
  },
  'RV06-ReviewSort': (d, shot) async {
    await _wait(1200);
    await d.tapNow('review_sort');
    await _wait(900);
    await shot('');
  },
  // V24s: the wake-up (the companion awake, "I'm awake!") and the paywall
  // risen (V13r over the scene).
  'V24s-RestToPremium': (d, shot) async {
    await _wait(1800);
    await d.runUnsynchronized(() => d.requestData('scroll:420'));
    await _wait(600);
    await shot('-1-rest');
    await d.tapNow('rest_wake');
    await _wait(250);
    await shot('-2-awake');
    await _wait(1600);
    await shot('-3-paywall');
  },
  'V13b-ExitReminder': (d, shot) async {
    await _wait(1400);
    await d.tapNow('premium_close');
    await _wait(1000);
    await shot('');
  },
  'PF02-Medals': (d, shot) async {
    await _wait(1400);
    await d.runUnsynchronized(() => d.requestData('scroll:420'));
    await _wait(700);
    await d.tapNow('settings_medals_see_all');
    await _wait(900);
    await shot('');
  },
  'PF03-MedalDetail': (d, shot) async {
    await _wait(1400);
    await d.runUnsynchronized(() => d.requestData('scroll:420'));
    await _wait(700);
    await d.tapNow('settings_medals_see_all');
    await _wait(900);
    await d.tapNow('medal_shelf_2026-10');
    await _wait(900);
    await shot('');
  },
  'PF04-EditName': (d, shot) async {
    await _wait(1400);
    await d.tapNow('profile_edit_name');
    await _wait(1200);
    await shot('');
  },
  'H03-HomeLoading': (d, shot) async {
    await _wait(900);
    await shot('');
  },
  'V03b-LuckyWheel': (d, shot) async {
    await _wait(900);
    await shot('-ready');
    await d.tapNow('wheel_spin');
    await _wait(3600);
    await shot('');
  },
  'R06s-D-Wheel': (d, shot) async {
    await _wait(900);
    await shot('-1-ready');
    await d.tapNow('wheel_spin');
    await _wait(700);
    await shot('-2-spinning');
    await _wait(2800);
    await shot('-3-landed');
  },
  'V04-Name': (d, shot) async {
    await _wait(600);
    await d.tapNow('buddy_confirm');
    await _wait(500);
    await d.tapNow('onboarding_name');
    await d.typeNow('Ada');
    await _wait(1200);
    await shot('');
  },
  'V05-Goal': (d, shot) async {
    await _wait(600);
    await d.tapNow('buddy_confirm');
    await _wait(500);
    await d.tapNow('onboarding_name');
    await d.typeNow('Ada');
    // Fix round 1: Continue is enabled only once the typed name has been
    // built; tapped at once (unsynchronized), the tap hit the disabled
    // button, the goal step never came and the next tap waited forever.
    await _wait(600);
    await d.tapNow('onboarding_continue');
    await _wait(900);
    await d.tapNow('onboarding_goal_work');
    await _wait(1400);
    await shot('');
  },
  'V05b-GettingReady': (d, shot) async {
    await _wait(2500);
    await shot('');
    await _wait(5500);
    await shot('-100');
  },
  'V07-Question': (d, shot) async {
    await _wait(900);
    await d.tapNow('question_answer_field');
    await d.typeNow('eating');
    await _wait(900);
    await shot('');
  },
  'V08-Correct': (d, shot) async {
    await _wait(900);
    await d.tapNow('question_answer_field');
    await d.typeNow('eating');
    await _wait(400);
    await d.tapNow('daily_test_check');
    await _wait(1300);
    await shot('');
  },
  'V09-Wrong': (d, shot) async {
    await _wait(900);
    await d.tapNow('question_answer_field');
    await d.typeNow('eating');
    await _wait(400);
    await d.tapNow('daily_test_check');
    await _wait(900);
    await d.tapNow('daily_test_continue');
    await _wait(700);
    await d.tapNow('question_answer_field');
    await d.typeNow('She don\'t like it.');
    await _wait(400);
    await d.tapNow('daily_test_check');
    // The book on its way to the Review tab (it flies 600–1100 ms after
    // Check; a simulator screenshot lands some 200–300 ms after it is
    // asked for).
    await _wait(560);
    await shot('-book');
    await _wait(700);
    await shot('');
  },
  'Q04-MultiBlank': (d, shot) async {
    await _wait(900);
    await d.tapNow('question_no_article_0');
    await d.tapNow('question_blank_box_1');
    await d.typeNow('the');
    await d.tapNow('question_blank_box_2');
    await d.typeNow('the');
    await _wait(600);
    await shot('-typed');
    await _wait(300);
    await d.tapNow('daily_test_check');
    await _wait(1400);
    await shot('');
  },
  'Q05-ErrorCorrection': (d, shot) async {
    await _wait(900);
    for (var i = 0; i < 4; i++) {
      await d.tapNow('daily_test_skip');
      await _wait(500);
    }
    await d.tapNow('question_answer_field');
    await d.typeNow('She has lived here since 2019.');
    await _wait(900);
    await shot('');
  },
  'R10-Leave': (d, shot) async {
    await _wait(900);
    await d.tapNow('daily_test_close');
    await _wait(900);
    await shot('');
  },
  'R06s-B1-Turntable': (d, shot) async {
    await _wait(900);
    await shot('-1-resting');
    await d.tapNow('buddy_next');
    await _wait(120);
    await shot('-2-turning');
    await _wait(1200);
    await shot('-3-panda');
  },
};

/// Taps and text entry without waiting for frames to stop: the boards'
/// ambient loops never let the app go idle. Each step gives up after
/// [_stepTimeout] (flutter_driver waits forever for a widget that never
/// comes, which is how V05-Goal "hung" in B11); the board is then reported
/// as failed and the run goes on.
const _stepTimeout = Duration(seconds: 15);

extension on FlutterDriver {
  Future<void> tapNow(String key) =>
      runUnsynchronized(() => tap(find.byValueKey(key), timeout: _stepTimeout));
  Future<void> typeNow(String text) =>
      runUnsynchronized(() => enterText(text, timeout: _stepTimeout));
}

Future<void> main() async {
  final udid = Platform.environment['CAPTURE_UDID']!;
  final out = Platform.environment['CAPTURE_OUT']!;
  Directory(out).createSync(recursive: true);
  final driver = await FlutterDriver.connect();
  try {
    final listed =
        (await driver.runUnsynchronized(() => driver.requestData('boards')))
            .split(',');
    final wanted = Platform.environment['CAPTURE_BOARDS'];
    final boards = wanted == null || wanted.isEmpty
        ? listed
        : wanted.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);
    for (final board in boards) {
      final reply = await driver
          .runUnsynchronized(() => driver.requestData('board:$board'));
      if (reply != 'ok') {
        stdout.writeln('unknown board $board');
        continue;
      }
      final id = board.split(':').first;
      Future<void> shot(String suffix) async {
        final file = '$out/${board.replaceAll(':', '-')}$suffix.png';
        final r = await Process.run(
            'xcrun', ['simctl', 'io', udid, 'screenshot', '--type=png', file]);
        stdout.writeln(r.exitCode == 0
            ? 'captured $file'
            : 'screenshot failed for $board: ${r.stderr}');
      }

      final script = _scripts[id];
      if (script != null) {
        try {
          await script(driver, shot);
        } on DriverError catch (e) {
          stdout.writeln('board $board failed: ${e.message}');
        }
        continue;
      }
      await Future<void>.delayed(Duration(milliseconds: _settleMs[id] ?? 1600));
      await shot('');
      if (_motionShots[id] case final later?) {
        await Future<void>.delayed(Duration(milliseconds: later));
        await shot('-t2');
      }
      for (final offset in _scrollShots[id] ?? const <int>[]) {
        await driver
            .runUnsynchronized(() => driver.requestData('scroll:$offset'));
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final more = '$out/${board.replaceAll(':', '-')}-$offset.png';
        await Process.run(
            'xcrun', ['simctl', 'io', udid, 'screenshot', '--type=png', more]);
        stdout.writeln('captured $more');
      }
    }
  } finally {
    await driver.close();
  }
}
