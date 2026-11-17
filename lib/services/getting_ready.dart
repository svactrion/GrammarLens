import 'dart:math' as math;

/// The onboarding "Getting ready" bar (V05b, SPEC §1.6): a 0 → 100 % bar
/// whose three stops are real work — name and buddy saved (⅓), today's
/// Daily Test ready (⅔), this month's mountain opened (1). Each task owns
/// one third; while a task runs the bar eases towards its stop and never
/// passes it until that task has finished. In-between values are smoothing
/// only.
///
/// Timing: the bar cannot reach 100 % before [minimum] (so it can be read);
/// when the work is fast it finishes right after that, with no other wait;
/// past [timeout] without every task done, [timedOut] is true (the screen
/// shows the R11 pattern with "Try again").
///
/// Driven by [advance] (a ticker in the screen, a loop in tests), so it is
/// deterministic.
class GettingReadyModel {
  static const Duration minimum = Duration(milliseconds: 1800);
  static const Duration timeout = Duration(seconds: 8);

  /// The three stops.
  static const List<double> stops = [1 / 3, 2 / 3, 1.0];

  /// How far into its own third a running task's bar may go (it stays
  /// visibly short of the stop).
  static const double runningShare = .7;

  /// Tasks finished so far, 0–3.
  int get done => _done;
  int _done = 0;

  /// Time since the start (or the last [retry]).
  Duration get elapsed => _elapsed;
  Duration _elapsed = Duration.zero;

  /// The bar's shown value, 0–1.
  double get value => _value;
  double _value = 0;

  /// Time spent on the whole run, across retries (the 1.8 s minimum counts
  /// from the first start).
  Duration _total = Duration.zero;

  /// A task finished; tasks finish in order.
  void taskDone() {
    if (_done < stops.length) _done++;
  }

  /// Every task done and the bar at 100 %.
  bool get complete => _done == stops.length && _value >= 1;

  /// Past [timeout] since the start (or the last retry) with work left.
  bool get timedOut => _done < stops.length && _elapsed >= timeout;

  /// Starts the timeout again (after "Try again"); the bar keeps its value.
  void retry() => _elapsed = Duration.zero;

  /// How many stops the bar has reached (for the rows' checks).
  int get stopsReached => stops.where((s) => _value >= s - 1e-9).length;

  /// The highest the bar may show now: below the running task's stop, and
  /// no further than the time since the start allows.
  double get ceiling {
    final double taskCap;
    if (_done >= stops.length) {
      taskCap = 1;
    } else {
      final from = _done == 0 ? 0.0 : stops[_done - 1];
      taskCap = from + (stops[_done] - from) * runningShare;
    }
    final timeCap = _total.inMicroseconds / minimum.inMicroseconds;
    return math.min(taskCap, timeCap).clamp(0.0, 1.0);
  }

  /// Moves time on by [dt]: the bar eases towards [ceiling] (a third of the
  /// gap per 60 ms) and never passes it.
  void advance(Duration dt) {
    _elapsed += dt;
    _total += dt;
    final target = ceiling;
    final k = 1 - math.pow(1 - 1 / 3, dt.inMicroseconds / 60000);
    var next = _value + (target - _value) * k;
    if (target - next < .004) next = target;
    _value = next > target ? target : math.max(_value, next);
  }
}
