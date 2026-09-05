import 'package:flutter/material.dart';

/// Every transient status message in the app (errors, and short
/// confirmations like "Profile saved.") goes through this single helper
/// instead of calling `ScaffoldMessenger` directly, so the guarantees below
/// hold everywhere at once instead of being reimplemented — or forgotten —
/// at each call site.
///
/// Root cause this exists to fix: `MaterialApp` provides exactly one
/// `ScaffoldMessenger` for the whole app (every `Scaffold` below it shares
/// that same one — a `Scaffold` has no way to create its own), so a
/// SnackBar shown from any screen visually persists after navigating to
/// another screen, and calling `showSnackBar` again just enqueues a second
/// message behind the first instead of replacing it. This exact failure
/// mode already forced one call site off SnackBar entirely (the
/// Streak/Voice "coming soon" message, moved to a dialog — see
/// docs/build-log.md, 2026-08-24); this fixes it generally, for every
/// message, instead of moving each offending call site one at a time.
class AppMessenger {
  const AppMessenger._();

  /// Attach to `MaterialApp.scaffoldMessengerKey` so [show]/[clear] can
  /// reach the messenger without needing a `BuildContext` at every call
  /// site.
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static const Duration _duration = Duration(seconds: 6);

  /// Shows [message] for a fixed duration with a Dismiss action that
  /// actually closes it. Always clears whatever's currently showing (and
  /// anything queued behind it) first, so calling this again — even with
  /// the same message — replaces rather than stacks. A no-op if the
  /// messenger isn't attached yet (shouldn't happen once wired into
  /// `MaterialApp`, but avoids a crash if called before the first frame).
  static void show(String message) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: _duration,
        // A SnackBar with an action defaults `persist` to true — it would
        // otherwise never auto-dismiss on its own no matter what
        // [_duration] says, which was the original bug: a Dismiss action
        // was added to fix "can't read it in 4s" without realizing it
        // silently disabled the duration entirely.
        persist: false,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: messenger.hideCurrentSnackBar,
        ),
      ),
    );
  }

  /// Clears any message currently showing or queued. Called by
  /// [navigatorObserver] on every Navigator route change; app.dart also
  /// calls this directly on a bottom-nav tab switch, since that's an
  /// `IndexedStack` swap, not a Navigator route change the observer below
  /// would ever see.
  static void clear() {
    key.currentState?.clearSnackBars();
  }

  /// Attach to `MaterialApp.navigatorObservers` so any Navigator-based
  /// screen change (push/pop/replace/remove) clears a lingering message —
  /// otherwise it stays visible, unrelated to whatever screen it's now
  /// sitting on top of.
  static final NavigatorObserver navigatorObserver =
      _ClearingNavigatorObserver();
}

class _ClearingNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppMessenger.clear();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppMessenger.clear();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      AppMessenger.clear();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      AppMessenger.clear();
}
