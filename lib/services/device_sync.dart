import 'dart:async';

/// Keeps what lives outside the app in step with it (TASK-widgets W3, W4):
/// the home-screen widgets' payload and the reminder plan. Anything that
/// changes their inputs calls [requestUpdate]; requests that arrive while a
/// run is going coalesce into one more run. No timers, so a widget test
/// never sees one pending.
class DeviceSync {
  DeviceSync(this._jobs);

  /// The app's instance while it runs; null otherwise (tests, before launch).
  static DeviceSync? current;

  /// Asks [current] to run its jobs; a no-op without one.
  static void requestUpdate() => current?.request();

  final List<Future<void> Function()> _jobs;
  Future<void>? _running;
  bool _busy = false;
  bool _again = false;

  void request() {
    // [_busy], not [_running]: a job may request synchronously, before
    // [_runAll] has returned its future.
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    _running = _runAll();
  }

  /// Completes when no run is going (tests).
  Future<void> get idle => _running ?? Future<void>.value();

  Future<void> _runAll() async {
    try {
      do {
        _again = false;
        for (final job in _jobs) {
          try {
            await job();
          } catch (_) {
            // Best effort, like analytics: a failing job never reaches the
            // user and the next request tries again.
          }
        }
      } while (_again);
    } finally {
      _busy = false;
      _running = null;
    }
  }
}
