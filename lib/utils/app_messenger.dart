import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/floating_nav_shell.dart';
import 'haptics.dart';

/// A message's status (SY02): the icon on the left of the capsule.
enum MessageKind { info, success, warning, error }

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

  /// SY02: a message stays 3 s, then slides away.
  static const Duration _duration = Duration(seconds: 3);

  /// Shows [message] in the one snackbar of the app (SY02): a dark capsule
  /// with the [kind]'s status icon on the left and at most one action
  /// ([actionLabel] / [onAction]); 3 s, then it slides down; a swipe down
  /// dismisses it at once. Success plays a light haptic, an error a
  /// warning. Always clears whatever's currently showing (and
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
  static void show(
    String message, {
    MessageKind kind = MessageKind.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    switch (kind) {
      case MessageKind.success:
        HapticMap.light();
      case MessageKind.error:
        HapticMap.warning();
      case MessageKind.info:
      case MessageKind.warning:
        break;
    }
    void go() => _show(message, kind, actionLabel, onAction);
    if (MediaQuery.viewInsetsOf(messenger.context).bottom > 0) {
      final generation = _generation;
      SchedulerBinding.instance
        ..addPostFrameCallback((_) {
          if (generation == _generation) go();
        })
        ..ensureVisualUpdate();
    } else {
      go();
    }
  }

  /// Bumped by [clear], so a message waiting for its frame is dropped when
  /// the screen changes before it shows.
  static int _generation = 0;

  static void _show(String message, MessageKind kind, String? actionLabel,
      VoidCallback? onAction) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    final context = messenger.context;
    final c = AppColors.of(context);
    final bottom = _bottomMargin(context);
    final reduced = AppMotion.reduced(context);
    messenger.showSnackBar(
      SnackBar(
        content: _SnackContent(
          message: message,
          kind: kind,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  messenger.hideCurrentSnackBar();
                  onAction();
                },
        ),
        backgroundColor: c.toast,
        elevation: 0,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 10, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        duration: _duration,
        dismissDirection: DismissDirection.down,
        margin: bottom == null
            ? null
            : EdgeInsets.fromLTRB(
                _inset.left, _inset.top, _inset.right, bottom),
        // The action is inside the content (one action at most, SY02), so
        // the bar keeps its own timeout.
        persist: false,
      ),
      snackBarAnimationStyle: AnimationStyle(
        duration: reduced ? AppMotion.fast : AppMotion.base,
        curve: AppMotion.enter,
        reverseDuration: reduced ? AppMotion.fast : AppMotion.base,
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

/// The capsule's content: the status icon, the message, the action.
class _SnackContent extends StatelessWidget {
  final String message;
  final MessageKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SnackContent({
    required this.message,
    required this.kind,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final (IconData icon, Color color) = switch (kind) {
      MessageKind.success => (Icons.check_rounded, c.green),
      MessageKind.warning => (Icons.priority_high_rounded, c.orange),
      MessageKind.error => (Icons.close_rounded, c.red),
      MessageKind.info => (Icons.info_outline_rounded, c.navy),
    };
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 17, color: c.onNavy),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodyMedium!
                .withWeight(FontWeight.w800)
                .copyWith(color: c.onToast),
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: c.gold,
              minimumSize: const Size(44, 44),
            ),
            child: Text(
              actionLabel!,
              style: theme.textTheme.labelLarge!
                  .withWeight(FontWeight.w900)
                  .copyWith(
                      color: c.gold,
                      decoration: TextDecoration.underline,
                      decorationColor: c.gold),
            ),
          ),
        ],
      ],
    );
  }
}
