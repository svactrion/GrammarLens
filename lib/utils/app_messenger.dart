import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/floating_nav_shell.dart';

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
  ///
  /// Where it appears ([_bottomMargin]): on a tab screen, above the floating
  /// nav bar; elsewhere where Flutter puts it (above a `BrandScaffold`'s
  /// bottom bar, above the keyboard). While the keyboard is up the message
  /// waits one frame, so a Save that closes the editor (Profile's name)
  /// places it for the keyboard that is going away, not the one still
  /// on screen.
  static void show(String message) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    if (MediaQuery.viewInsetsOf(messenger.context).bottom > 0) {
      final generation = _generation;
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (generation == _generation) _show(message);
        })
        ..ensureVisualUpdate();
    } else {
      _show(message);
    }
  }

  /// Bumped by [clear], so a message waiting for its frame is dropped when
  /// the screen changes before it shows.
  static int _generation = 0;

  static void _show(String message) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    final bottom = _bottomMargin(messenger.context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: _duration,
        margin: bottom == null
            ? null
            : EdgeInsets.fromLTRB(_inset.left, _inset.top, _inset.right, bottom),
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

  /// Flutter's own margin for a floating Material 3 SnackBar.
  static const EdgeInsets _inset = EdgeInsets.fromLTRB(15, 5, 15, 10);

  /// The message's bottom margin, or null for Flutter's own placement.
  ///
  /// The tab screens sit in the nav shell's root Scaffold, which shows the
  /// app's messages. Its bar is a `Stack` overlay, not a Scaffold slot, so
  /// Flutter does not know it is there and puts a message on top of it;
  /// and the Scaffold does not resize for the keyboard (Batch 8), so
  /// Flutter does not lift a message above the keyboard either. Here the
  /// message's bottom edge goes [NavBarClearance.gap] above the bar's
  /// measured top ([FloatingNavShell.visibleClearance]), or the same gap
  /// above the keyboard while a text field has the focus. The margin is
  /// counted from the safe area's bottom edge, where the Scaffold places a
  /// floating SnackBar.
  ///
  /// A screen without the bar (a pushed route) gets null: its own Scaffold
  /// already places the message above its bottom bar and the keyboard.
  static double? _bottomMargin(BuildContext context) {
    final clearance = FloatingNavShell.visibleClearance;
    if (clearance == null) return null;
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final aboveKeyboard = keyboard > 0 && _textFieldHasFocus()
        ? keyboard + NavBarClearance.gap
        : 0.0;
    final fromBottom = clearance > aboveKeyboard ? clearance : aboveKeyboard;
    return (fromBottom - safeBottom).clamp(_inset.bottom, double.infinity);
  }

  static bool _textFieldHasFocus() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context != null &&
        context.mounted &&
        (context.widget is EditableText ||
            context.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  /// Clears any message currently showing or queued. Called by
  /// [navigatorObserver] on every Navigator route change; app.dart also
  /// calls this directly on a bottom-nav tab switch, since that's an
  /// `TabSwitcher` swap, not a Navigator route change the observer below
  /// would ever see.
  static void clear() {
    _generation++;
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
