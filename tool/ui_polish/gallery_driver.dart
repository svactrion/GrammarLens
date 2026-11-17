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
  'V12-Climb': 2500,
  'R04-MonthCard': 3500,
  'V11-Badge': 2200,
  'R05-Medal': 2200,
  'PW05-PremiumOn': 2200,
  'V16b-TicketTear': 420,
};

/// Long system boards: extra captures scrolled down by these offsets.
const _scrollShots = <String, List<int>>{
  'X04-Ticket': [420],
  'X05-DailyCard': [560],
  'V00-CompanionSystem': [500],
  'X03-HeroSet': [400],
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
    await _wait(1300);
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
/// ambient loops never let the app go idle.
extension on FlutterDriver {
  Future<void> tapNow(String key) =>
      runUnsynchronized(() => tap(find.byValueKey(key)));
  Future<void> typeNow(String text) => runUnsynchronized(() => enterText(text));
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
        await script(driver, shot);
        continue;
      }
      await Future<void>.delayed(Duration(milliseconds: _settleMs[id] ?? 1600));
      await shot('');
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
