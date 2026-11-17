import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/services/getting_ready.dart';

/// SPEC §1.6 (V05b): the bar never passes a stop before its task completes,
/// respects the 1.8 s minimum, and turns to an error past 8 s.
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

  test('instant work still takes the 1.8 s minimum, and no more than a beat',
      () {
    final model = GettingReadyModel();
    model
      ..taskDone()
      ..taskDone()
      ..taskDone();
    Duration? completeAt;
    run(model, const Duration(seconds: 3), check: (t) {
      if (model.complete && completeAt == null) completeAt = t;
      if (t < GettingReadyModel.minimum) expect(model.value, lessThan(1));
    });
    expect(completeAt, isNotNull);
    expect(completeAt!, greaterThanOrEqualTo(GettingReadyModel.minimum));
    expect(completeAt!, lessThan(const Duration(milliseconds: 2300)));
  });

  test('a stop is reached soon after its task, not before', () {
    final model = GettingReadyModel();
    run(model, const Duration(milliseconds: 1000));
    expect(model.stopsReached, 0);
    model.taskDone();
    run(model, const Duration(milliseconds: 800));
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
    run(model, const Duration(seconds: 2));
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
}
