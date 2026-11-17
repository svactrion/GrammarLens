import 'dart:async';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'companion_view.dart';
import 'pressable_button.dart';

/// What went wrong (R11): each kind has its own calm copy; the pattern is
/// the same.
enum ErrorKind { offline, server, quota }

/// The one pattern for every network / quota / server error (R11, SPEC
/// §3.6): the sad companion, a calm title and line, "Try again" (dots
/// inside the button while retrying, back when the result comes) and a
/// reassurance that progress is safe.
///
/// Haptics: a warning when it opens (once), a light tap when a retry
/// succeeds ([onRetry] completes with true).
class ErrorState extends StatefulWidget {
  final Avatar hero;
  final ErrorKind kind;

  /// Retries; completes with whether it worked. Null hides the button
  /// (a quota error that only time resolves).
  final Future<bool> Function()? onRetry;

  /// Replaces the kind's own title / line (a screen-specific message).
  final String? title;
  final String? message;

  /// Plays the opening haptic (off where the screen already played one).
  final bool openHaptic;

  const ErrorState({
    super.key,
    required this.hero,
    this.kind = ErrorKind.offline,
    this.onRetry,
    this.title,
    this.message,
    this.openHaptic = true,
  });

  static const retryKey = ValueKey('error_state_retry');

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.openHaptic) HapticMap.warning();
  }

  Future<void> _retry() async {
    final retry = widget.onRetry;
    if (retry == null || _busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await retry();
    } catch (_) {
      ok = false;
    }
    if (ok) HapticMap.light();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (title, message) = switch (widget.kind) {
      ErrorKind.offline => (l10n.errorOfflineTitle, l10n.errorOfflineBody),
      ErrorKind.server => (l10n.errorServerTitle, l10n.errorServerBody),
      ErrorKind.quota => (l10n.errorQuotaTitle, l10n.errorQuotaBody),
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    width: 90,
                    height: 14,
                    margin: const EdgeInsets.only(bottom: 2),
                    decoration: BoxDecoration(
                      color: c.lip.withValues(alpha: .7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CompanionView(
                        hero: widget.hero,
                        mood: CompanionMood.sad,
                        size: 132,
                        showProp: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              widget.title ?? title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.text, letterSpacing: -.6),
            ),
            const SizedBox(height: 10),
            Text(
              widget.message ?? message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge!
                  .copyWith(color: c.muted, height: 1.45),
            ),
            const SizedBox(height: 22),
            if (widget.onRetry != null)
              PressableButton(
                key: ErrorState.retryKey,
                label: l10n.errorTryAgain,
                leadingIcon: Icons.refresh_rounded,
                busy: _busy,
                haptic: ButtonHaptic.medium,
                onPressed: () => unawaited(_retry()),
              ),
            const SizedBox(height: 8),
            Text(
              l10n.errorProgressSafe,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium!
                  .withWeight(FontWeight.w700)
                  .copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
