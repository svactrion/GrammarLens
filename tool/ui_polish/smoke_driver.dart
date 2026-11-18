// Fix round 3, §4: the host side of the smoke walk (`smoke_app.dart`). A
// fresh install from Welcome through the Day 0 test (one answer wrong),
// the results, the badge, the first climb and the paywall to Home; then
// the A2 path: Review, the free ticket on a practice, back to Home, where
// the rest scene and N01 must be on screen at once. Each step saves the
// simulator's screen (`xcrun simctl io <udid> screenshot`) to SMOKE_OUT.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const _timeout = Duration(seconds: 20);

Future<void> main() async {
  late FlutterDriver d;
  final udid = Platform.environment['SMOKE_UDID']!;
  final out = Platform.environment['SMOKE_OUT']!;
  var n = 0;

  Future<void> shot(String name) async {
    n++;
    final file = '$out/${n.toString().padLeft(2, '0')}-$name.png';
    await Process.run(
        'xcrun', ['simctl', 'io', udid, 'screenshot', '--type=png', file]);
    stdout.writeln('shot $file');
  }

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> tap(SerializableFinder f) =>
      d.runUnsynchronized(() => d.tap(f, timeout: _timeout));

  Future<void> type(SerializableFinder f, String text) async {
    await tap(f);
    await d.runUnsynchronized(() => d.enterText(text, timeout: _timeout));
  }

  Future<bool> present(SerializableFinder f, {int ms = 1500}) async {
    try {
      await d.runUnsynchronized(
          () => d.waitFor(f, timeout: Duration(milliseconds: ms)));
      return true;
    } catch (_) {
      return false;
    }
  }

  d = await FlutterDriver.connect();
  try {
    // The debug start plus the first launch's 2.2 s splash.
    await wait(5000);
    await shot('welcome');
    await tap(find.byValueKey('welcome_get_started'));
    await wait(1200);
    await tap(find.byValueKey('buddy_confirm'));
    await wait(1200);
    await shot('name-asks');
    await type(find.byValueKey('onboarding_name'), 'Ada');
    await wait(1200);
    await shot('name-greets');
    await tap(find.byValueKey('onboarding_continue'));
    await wait(1000);
    await tap(find.byValueKey('onboarding_goal_work'));
    await wait(700);
    await shot('goal-work');
    await tap(find.byValueKey('onboarding_start'));
    await wait(2000);
    await shot('getting-ready');
    await wait(4000);
    await shot('mountain-intro');
    await tap(find.byValueKey('mountain_intro_start'));
    await wait(1500);

    // Day 0: the first answer wrong, the rest as the fixed set expects.
    const answers = [
      'eat',
      'She is the best student in our class',
      'She can speak three languages',
      'would',
      'saw',
    ];
    for (var i = 0; i < answers.length; i++) {
      await type(find.byValueKey('question_answer_field'), answers[i]);
      await wait(400);
      await tap(find.byValueKey('daily_test_check'));
      await wait(900);
      if (i == 0) await shot('q1-wrong-oops');
      await tap(find.byValueKey('daily_test_continue'));
      await wait(1200);
    }
    await wait(2500);
    await shot('V10-results-first');
    await tap(find.byValueKey('resultPrimary'));
    await wait(2500);
    await shot('V11-badge-after');
    await tap(find.byValueKey('medal_celebration_continue'));
    await wait(5500);
    await shot('V12-first-climb');
    await tap(find.byValueKey('first_climb_continue'));
    await wait(2000);
    await shot('V13-paywall');
    await tap(find.byValueKey('premium_close'));
    await wait(1200);
    if (await present(find.byValueKey('premium_exit_continue_free'))) {
      await shot('V13b-exit');
      await tap(find.byValueKey('premium_exit_continue_free'));
    }
    await wait(2500);
    await shot('home-after-day0');

    // A2: Review, the free ticket on a practice, back to Home.
    await tap(find.text('Review'));
    await wait(1500);
    await shot('review');
    await tap(find.byValueKey('review_practice_ticket'));
    await wait(1500);
    if (await present(find.text('Agree and continue'))) {
      await shot('consent');
      await tap(find.text('Agree and continue'));
    }
    await wait(800);
    await shot('V18-preparing');
    await wait(2500);
    for (var i = 0; i < 3; i++) {
      await shot('practice-q${i + 1}');
      await type(find.byValueKey('question_answer_field'), 'a');
      await wait(300);
      await tap(find.byValueKey('practice_step_primary'));
      await wait(1200);
    }
    await wait(3500);
    await shot('V21-results');
    // The results are a route over the tabs: back to Review, then Home
    // through the nav bar.
    await tap(find.text('Back to topics'));
    await wait(1500);
    await shot('back-on-review');
    await tap(find.text('Climb'));
    await wait(1200);
    await shot('A2-home-rest-and-N01');
    await wait(1500);
    await shot('A2-home-rest-and-N01-later');
  } catch (e) {
    stdout.writeln('smoke stopped: $e');
    await shot('stopped-here');
    exitCode = 1;
  } finally {
    await d.close();
  }
}
