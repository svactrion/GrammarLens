import 'dart:math' as math;

/// The onboarding "Getting ready" bar (V05b, SPEC §1.6): a 0 → 100 % bar
/// whose three stops are real work — name and buddy saved (⅓), today's
/// Daily Test ready (⅔), this month's mountain opened (1). Each task owns
/// one third; while a task runs the bar eases towards its stop and never
/// passes it until that task has finished. In-between values are smoothing
/// only.
///
/// Timing (SPEC §1.16, fix round 2): each stop takes at least [perStop]
/// (1.2 s) from the previous one, so the bar reaches 100 % at [minimum]
/// (3.6 s) at the earliest and, with the screen's 0.6 s celebration, the
/// screen shows for at least 4 s. A slower task keeps the bar waiting
/// short of its stop ([waiting]: the companion thinks). Past [timeout]
/// without every task done, [timedOut] is true (the screen shows the R11
/// pattern with "Try again").
///
/// Driven by [advance] (a ticker in the screen, a loop in tests), so it is
/// deterministic.
class GettingReadyModel {
  /// The least time from one stop to the next (and from the start to the
  /// first).
  static const Duration perStop = Duration(milliseconds: 1200);

  /// The earliest the bar can reach 100 %: three stops of [perStop].
  static const Duration minimum = Duration(milliseconds: 3600);
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

  /// Time since the bar reached its last stop (or since the start).
  Duration _sinceStop = Duration.zero;

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

  /// The cap the running task puts on the bar: short of its stop while it
  /// runs, the stop once it is done.
  double get _taskCap {
    final next = stopsReached;
    if (next >= stops.length) return 1;
    final from = next == 0 ? 0.0 : stops[next - 1];
    return _done > next
        ? stops[next]
        : from + (stops[next] - from) * runningShare;
  }

  /// The bar is parked short of its stop because that stop's task is
  /// still running (the companion thinks).
  bool get waiting =>
      stopsReached < stops.length &&
      _done <= stopsReached &&
      _value >= _taskCap - .002;

  /// The highest the bar may show now: below the running task's stop, and
  /// within the current third no further than [perStop] since the last
  /// stop allows.
  double get ceiling {
    final next = stopsReached;
    if (next >= stops.length) return 1;
    final from = next == 0 ? 0.0 : stops[next - 1];
    final share =
        math.min(1.0, _sinceStop.inMicroseconds / perStop.inMicroseconds);
    final timeCap = from + (stops[next] - from) * share;
    return math.min(_taskCap, timeCap).clamp(0.0, 1.0);
  }

  /// Moves time on by [dt]: the bar eases towards [ceiling] (a third of the
  /// gap per 25 ms: close behind the 1.2 s ramp, so a stop lands right
  /// after its 1.2 s; a late task's jump still eases) and never passes it.
  void advance(Duration dt) {
    _elapsed += dt;
    _sinceStop += dt;
    final before = stopsReached;
    final target = ceiling;
    final k = 1 - math.pow(1 - 1 / 3, dt.inMicroseconds / 25000);
    var next = _value + (target - _value) * k;
    if (target - next < .004) next = target;
    _value = next > target ? target : math.max(_value, next);
    if (stopsReached > before) _sinceStop = Duration.zero;
  }
}
