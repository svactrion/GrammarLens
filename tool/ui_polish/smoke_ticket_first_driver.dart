// Fix round 6, Checks: the host side of the walk in the order the owner
// used on his phone, on the seeded app (`smoke_app.dart` without
// SEED_SKIP: a learner with weak spots, today's Daily Test not taken).
// Review, the free ticket on a practice (the first question has two blanks
// on a line with an instruction and cues in brackets: item 3's shape),
// back to Review (the new weak spot's card), Home, the Daily Test, "See
// your climb": the step must walk, the pawn rest, and only then the rest
// scene come (item 1). That last part is filmed (`xcrun simctl io <udid>
// recordVideo`) into SMOKE_OUT, so the frames can be read afterwards.
//
//   flutter drive -d <simulator> --target tool/ui_polish/smoke_app.dart \
//     --driver tool/ui_polish/smoke_ticket_first_driver.dart \
//     --dart-define=SEED_LANGUAGE=tr --dart-define=SEED_RESET_ASK=true \
//     --dart-define=PROXY_BASE_URL=http://localhost:8787 \
//     --dart-define=APP_TOKEN=local-smoke
//
// With SMOKE_UDID, SMOKE_OUT and SMOKE_LANG as for `smoke_driver.dart`, and
// a local stand-in for the practice proxy on port 8787 (canned JSON, no AI
// call).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const _timeout = Duration(seconds: 20);

Future<void> main() async {
  late FlutterDriver d;
  final udid = Platform.environment['SMOKE_UDID']!;
  final out = Platform.environment['SMOKE_OUT']!;
  final lang = Platform.environment['SMOKE_LANG'] ?? 'en';
  final arb = jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
      as Map<String, dynamic>;
  String t(String key) => arb[key] as String;
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
    // The debug start plus the launch splash.
    await wait(6000);
    await shot('home-before-the-test');

    // The free ticket first: Review, a practice of three questions.
    await tap(find.text(t('featureReview')));
    await wait(1500);
    await shot('review-before');
    await tap(find.byValueKey('review_practice_ticket'));
    await wait(1500);
    if (await present(find.text(t('aiConsentAgree')))) {
      await tap(find.text(t('aiConsentAgree')));
    }
    await wait(4000);
    // The first question: two blanks on the instruction's line, one wrong.
    await shot('practice-q1-two-blanks');
    await type(find.byValueKey('question_blank_box_0'), 'can speaks');
    await wait(300);
    await type(find.byValueKey('question_blank_box_1'), 'must work');
    await wait(300);
    await shot('practice-q1-filled');
    await tap(find.byValueKey('practice_step_primary'));
    await wait(1200);
    for (var i = 1; i < 3; i++) {
      await type(find.byValueKey('question_answer_field'), 'a');
      await wait(300);
      await tap(find.byValueKey('practice_step_primary'));
      await wait(i == 2 ? 6000 : 1200);
    }
    await shot('practice-results');
    await tap(find.text(t('resultsBackToTopics')));
    await wait(1500);
    // Item 3: the new weak spot's card, the wrong word struck in place.
    await shot('review-after-the-practice');
    await tap(find.text(t('navHome')));
    await wait(1500);
    stdout.writeln('rest scene before the test: '
        '${await present(find.byValueKey('home_rest_scene'), ms: 800)}');
    await shot('home-ticket-used-test-waiting');

    // The Daily Test: the first answer wrong, the rest as the set expects.
    await tap(find.text(t('homeDailyStartToday')));
    await wait(1500);
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
      await tap(find.byValueKey('daily_test_continue'));
      await wait(1200);
    }
    await wait(2500);
    await shot('V10-results');

    // "See your climb", filmed: the step, the pawn at rest, the rest scene.
    final film = await Process.start('xcrun', [
      'simctl',
      'io',
      udid,
      'recordVideo',
      '--codec',
      'h264',
      '--force',
      '$out/see-your-climb.mp4'
    ]);
    await wait(1500);
    final tapped = DateTime.now();
    await tap(find.byValueKey('resultPrimary'));
    stdout.writeln('tapped See your climb');
    var sceneAt = -1;
    for (var i = 0; i < 60; i++) {
      await wait(250);
      if (await present(find.byValueKey('home_rest_scene'), ms: 100)) {
        sceneAt = DateTime.now().difference(tapped).inMilliseconds;
        break;
      }
    }
    stdout.writeln('rest scene in the tree after: $sceneAt ms');
    await wait(3500);
    film.kill(ProcessSignal.sigint);
    await film.exitCode;
    await shot('rest-scene-after-the-step');
    if (await present(find.text(t('softAskNotNow')))) {
      stdout.writeln('N01 opened over the rest scene: true');
      await tap(find.text(t('softAskNotNow')));
      await wait(1500);
    } else {
      stdout.writeln('N01 opened over the rest scene: false');
    }
    await shot('V24f-after-the-step');
    // Leaving and coming back: the scene stays, the step is not replayed.
    await tap(find.text(t('featureReview')));
    await wait(1200);
    await tap(find.text(t('navHome')));
    await wait(1200);
    stdout.writeln('rest scene on return: '
        '${await present(find.byValueKey('home_rest_scene'), ms: 800)}');
    await shot('V24f-on-return');
  } catch (e) {
    stdout.writeln('smoke stopped: $e');
    await shot('stopped-here');
    exitCode = 1;
  } finally {
    await d.close();
  }
}
