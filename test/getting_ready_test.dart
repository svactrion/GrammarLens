import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';

import 'package:grammar_lens/screens/getting_ready_screen.dart';
import 'package:grammar_lens/services/getting_ready.dart';

/// SPEC §1.6 / §1.16 (V05b): the bar never passes a stop before its task
/// completes, each stop takes at least 1.2 s (fix round 2: 4 s or more on
/// screen with the celebration), and it turns to an error past 8 s.
void main() {
  const frame = Duration(milliseconds: 16);

  /// Runs [model] for [length], finishing tasks at the given times.
  void run(GettingReadyModel model, Duration length,
      {List<Duration> doneAt = const [], void Function(Duration t)? check}) {
    var t = Duration.zero;
    var next = 0;
    while (t < length) {
      while (next < doneAt.length && doneAt[next] <= t) {
        model.taskDone();
        next++;
      }
      model.advance(frame);
      t += frame;
      check?.call(t);
    }
  }

  test('never passes a stop while that task is still running', () {
    final model = GettingReadyModel();
    run(model, const Duration(seconds: 7), doneAt: const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 6),
    ], check: (t) {
      final done = model.done;
      if (done < 3) {
        expect(model.value, lessThan(GettingReadyModel.stops[done]),
            reason: 'at $t with $done done');
      }
    });
    expect(model.complete, isTrue);
  });

  test(
      'instant work: each stop takes at least 1.2 s, 100 % at 3.6 s at the '
      'earliest, and no more than a beat after', () {
    final model = GettingReadyModel();
    model
      ..taskDone()
      ..taskDone()
      ..taskDone();
    final reachedAt = <Duration>[];
    Duration? completeAt;
    run(model, const Duration(seconds: 5), check: (t) {
      while (reachedAt.length < model.stopsReached) {
        reachedAt.add(t);
      }
      if (model.complete && completeAt == null) completeAt = t;
    });
    expect(reachedAt, hasLength(3));
    for (var i = 0; i < 3; i++) {
      final since = i == 0 ? Duration.zero : reachedAt[i - 1];
      expect(
          reachedAt[i] - since, greaterThanOrEqualTo(GettingReadyModel.perStop),
          reason: 'stop ${i + 1}');
    }
    expect(completeAt!, greaterThanOrEqualTo(GettingReadyModel.minimum));
    expect(completeAt!, lessThan(const Duration(milliseconds: 3900)));
    // With the 0.6 s celebration the screen shows for at least 4 s.
    expect(GettingReadyModel.minimum + GettingReadyScreen.doneHold,
        greaterThanOrEqualTo(const Duration(seconds: 4)));
  });

  test(
      'a slow first task does not let the next stop rush: 1.2 s from stop '
      'to stop; the bar waits (the companion thinks) while a task runs', () {
    final model = GettingReadyModel();
    final reachedAt = <Duration>[];
    var waited = false;
    run(model, const Duration(seconds: 7),
        doneAt: const [Duration(milliseconds: 3000)], check: (t) {
      while (reachedAt.length < model.stopsReached) {
        reachedAt.add(t);
      }
      if (t > const Duration(milliseconds: 1500) &&
          t < const Duration(milliseconds: 2900)) {
        waited = waited || model.waiting;
      }
      if (model.done == 1 && model.stopsReached == 1) {
        // Tasks 2 and 3 finish at once after the first.
        model
          ..taskDone()
          ..taskDone();
      }
    });
    expect(waited, isTrue);
    expect(reachedAt, hasLength(3));
    expect(reachedAt[1] - reachedAt[0],
        greaterThanOrEqualTo(GettingReadyModel.perStop));
    expect(reachedAt[2] - reachedAt[1],
        greaterThanOrEqualTo(GettingReadyModel.perStop));
  });

  test('a stop is reached soon after its task, not before', () {
    final model = GettingReadyModel();
    run(model, const Duration(milliseconds: 1000));
    expect(model.stopsReached, 0);
    model.taskDone();
    run(model, const Duration(milliseconds: 800));
    // 1.2 s from the start at the earliest (fix round 2), then soon after.
    expect(model.stopsReached, 1);
    expect(model.value, lessThan(GettingReadyModel.stops[1]));
  });

  test('past 8 s without every task done: timed out', () {
    final model = GettingReadyModel();
    run(model, const Duration(milliseconds: 7900),
        doneAt: const [Duration(seconds: 1)]);
    expect(model.timedOut, isFalse);
    run(model, const Duration(milliseconds: 200));
    expect(model.timedOut, isTrue);
    expect(model.value, lessThan(GettingReadyModel.stops[1]));
  });

  test('a retry restarts the timeout and keeps the bar', () {
    final model = GettingReadyModel();
    run(model, const Duration(seconds: 9),
        doneAt: const [Duration(seconds: 1)]);
    expect(model.timedOut, isTrue);
    final before = model.value;
    model.retry();
    expect(model.timedOut, isFalse);
    expect(model.value, before);
    model
      ..taskDone()
      ..taskDone();
    run(model, const Duration(seconds: 3));
    expect(model.complete, isTrue);
  });

  test('every task done: the bar ends exactly at 100 %', () {
    final model = GettingReadyModel();
    run(model, const Duration(seconds: 4), doneAt: const [
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 300),
    ]);
    expect(model.value, 1);
    expect(model.stopsReached, 3);
  });

  testWidgets(
      'the screen: instant work shows it for at least 4 s (3.6 s to 100 %, '
      'then the 0.6 s celebration) before it moves on', (tester) async {
    var doneAt = Duration.zero;
    var elapsed = Duration.zero;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GettingReadyScreen(
        name: 'Ada',
        hero: Avatar.fox,
        goal: LearningGoal.school,
        monthName: 'November',
        mountainName: 'Green Slope',
        steps: 30,
        questionsPerDay: 5,
        tasks: [() async {}, () async {}, () async {}],
        onDone: () => doneAt = elapsed,
      ),
    ));
    while (doneAt == Duration.zero && elapsed < const Duration(seconds: 6)) {
      await tester.pump(const Duration(milliseconds: 50));
      elapsed += const Duration(milliseconds: 50);
    }
    expect(doneAt, greaterThanOrEqualTo(const Duration(seconds: 4)));
    expect(doneAt, lessThan(const Duration(milliseconds: 4600)));
    expect(find.text('School & university'), findsWidgets);
  });
}
