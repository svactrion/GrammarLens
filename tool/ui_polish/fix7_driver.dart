// Fix round 7, Checks (docs/design/ui-polish/handoff/FIX7.md): the host
// side of a short walk on the seeded app (`smoke_app.dart`: a learner with
// earlier days, so today's Daily Test is a second day or later). The Daily
// Test, "See your climb", then a capture every 400 ms while the step walks,
// the pawn lands and the beat passes, noting when N01 first shows; then,
// with N01 open, the simulator's appearance switched to dark and back
// (item 2), each captured.
//
//   flutter drive -d <iPhone simulator> --target tool/ui_polish/smoke_app.dart \
//     --driver tool/ui_polish/fix7_driver.dart \
//     --dart-define=SEED_LANGUAGE=tr --dart-define=SEED_RESET_ASK=true
//
// With SMOKE_UDID and SMOKE_OUT. No practice, so no proxy and no AI call:
// the Daily Test falls back to the bundled pool.
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

  Future<void> appearance(String mode) =>
      Process.run('xcrun', ['simctl', 'ui', udid, 'appearance', mode]);

  Future<void> wait(int ms) => Future<void>.delayed(Duration(milliseconds: ms));

  Future<void> tap(SerializableFinder f) =>
      d.runUnsynchronized(() => d.tap(f, timeout: _timeout));

  Future<bool> present(SerializableFinder f, {int ms = 1500}) async {
    try {
      await d.runUnsynchronized(
          () => d.waitFor(f, timeout: Duration(milliseconds: ms)));
      return true;
    } catch (_) {
      return false;
    }
  }

  final ask = find.byValueKey('reminder_soft_ask_not_now');
  await appearance('light');
  d = await FlutterDriver.connect();
  try {
    await wait(5000);
    await shot('home-before-test');
    await tap(find.byValueKey('daily_test_card_button'));
    await wait(2500);
    for (var i = 0; i < 10; i++) {
      if (await present(find.byValueKey('resultPrimary'), ms: 300)) break;
      await d.runUnsynchronized(() =>
          d.tap(find.byValueKey('question_answer_field'), timeout: _timeout));
      await d.runUnsynchronized(() => d.enterText('a', timeout: _timeout));
      await wait(300);
      await tap(find.byValueKey('daily_test_check'));
      await wait(900);
      await tap(find.byValueKey('daily_test_continue'));
      await wait(1200);
    }
    await wait(2500);
    await shot('results');
    final start = DateTime.now();
    await tap(find.byValueKey('resultPrimary'));
    Duration? askedAt;
    for (var i = 0; i < 25; i++) {
      await wait(250);
      final elapsed = DateTime.now().difference(start);
      final open = await present(ask, ms: 100);
      await shot('after-${elapsed.inMilliseconds}ms${open ? '-N01' : ''}');
      if (open) {
        askedAt = elapsed;
        break;
      }
    }
    stdout.writeln('N01 first seen after ${askedAt?.inMilliseconds} ms');
    if (askedAt != null) {
      await wait(1000);
      await shot('N01-light');
      await appearance('dark');
      await wait(1500);
      await shot('N01-switched-to-dark');
      await appearance('light');
      await wait(1500);
      await shot('N01-switched-back-to-light');
      await tap(ask);
      await wait(1500);
      await shot('after-not-now');
    }
  } catch (e) {
    stdout.writeln('walk stopped: $e');
    await shot('stopped-here');
    exitCode = 1;
  } finally {
    await appearance('light');
    await d.close();
  }
}
