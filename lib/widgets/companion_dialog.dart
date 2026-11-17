import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'companion_view.dart';
import 'pressable_button.dart';

/// Which button closed a [showCompanionDialog].
enum CompanionDialogResult { primary, secondary }

/// The companion dialog (SPEC §3.6: R10 leave, 13b paywall exit, R08 reset):
/// a card with the companion on top in [mood], a title, a line, a dominant
/// [primaryLabel] and a [secondaryLabel] (red text when [destructive]).
/// The background dims in 200 ms; the card pops 0.9 → 1 in 250 ms; the
/// secondary action slides the card down as it closes.
///
/// [openHaptic] plays once when it opens (R10: warning, 13b: light).
/// Returns null when dismissed by tapping outside.
Future<CompanionDialogResult?> showCompanionDialog({
  required BuildContext context,
  required Avatar hero,
  required String title,
  required String body,
  required String primaryLabel,
  required String secondaryLabel,
  CompanionMood mood = CompanionMood.sad,
  bool destructive = true,
  ButtonTone primaryTone = ButtonTone.orange,
  void Function()? openHaptic,
  void Function()? secondaryHaptic,
  void Function()? primaryHaptic,
  bool barrierDismissible = true,
  Key? primaryKey,
  Key? secondaryKey,
}) {
  final c = AppColors.of(context);
  final reduced = AppMotion.reduced(context);
  (openHaptic ?? HapticMap.warning)();
  return showGeneralDialog<CompanionDialogResult>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: c.scrim,
    transitionDuration: reduced ? AppMotion.fast : AppMotion.base,
    pageBuilder: (context, _, __) => _CompanionDialog(
      hero: hero,
      mood: mood,
      title: title,
      body: body,
      primaryLabel: primaryLabel,
      secondaryLabel: secondaryLabel,
      destructive: destructive,
      primaryTone: primaryTone,
      secondaryHaptic: secondaryHaptic ?? HapticMap.medium,
      primaryHaptic: primaryHaptic,
      primaryKey: primaryKey,
      secondaryKey: secondaryKey,
    ),
    transitionBuilder: (context, animation, _, child) {
      if (reduced) return FadeTransition(opacity: animation, child: child);
      final pop = CurvedAnimation(
          parent: animation, curve: AppMotion.pop, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween<double>(begin: .9, end: 1).animate(pop),
          child: child,
        ),
      );
    },
  );
}

class _CompanionDialog extends StatefulWidget {
  final Avatar hero;
  final CompanionMood mood;
  final String title;
  final String body;
  final String primaryLabel;
  final String secondaryLabel;
  final bool destructive;
  final ButtonTone primaryTone;
  final void Function() secondaryHaptic;
  final void Function()? primaryHaptic;
  final Key? primaryKey;
  final Key? secondaryKey;

  const _CompanionDialog({
    required this.hero,
    required this.mood,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.destructive,
    required this.primaryTone,
    required this.secondaryHaptic,
    required this.primaryHaptic,
    required this.primaryKey,
    required this.secondaryKey,
  });

  @override
  State<_CompanionDialog> createState() => _CompanionDialogState();
}

class _CompanionDialogState extends State<_CompanionDialog> {
  bool _leaving = false;

  Future<void> _secondary() async {
    widget.secondaryHaptic();
    if (!AppMotion.reduced(context)) {
      setState(() => _leaving = true);
      await Future<void>.delayed(AppMotion.base);
    }
    if (mounted) Navigator.of(context).pop(CompanionDialogResult.secondary);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AnimatedSlide(
              offset: _leaving ? const Offset(0, .35) : Offset.zero,
              duration: AppMotion.base,
              curve: AppMotion.exit,
              child: AnimatedOpacity(
                opacity: _leaving ? 0 : 1,
                duration: AppMotion.base,
                child: Material(
                  type: MaterialType.transparency,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 56),
                        padding: const EdgeInsets.fromLTRB(22, 64, 22, 14),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall!
                                  .withWeight(FontWeight.w900)
                                  .copyWith(color: c.text, letterSpacing: -.6),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              widget.body,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium!
                                  .copyWith(color: c.muted, height: 1.45),
                            ),
                            const SizedBox(height: 18),
                            PressableButton(
                              key: widget.primaryKey,
                              label: widget.primaryLabel,
                              tone: widget.primaryTone,
                              haptic: widget.primaryHaptic == null
                                  ? ButtonHaptic.light
                                  : ButtonHaptic.none,
                              onPressed: () {
                                widget.primaryHaptic?.call();
                                Navigator.of(context)
                                    .pop(CompanionDialogResult.primary);
                              },
                            ),
                            const SizedBox(height: 4),
                            PressableButton(
                              key: widget.secondaryKey,
                              label: widget.secondaryLabel,
                              tone: widget.destructive
                                  ? ButtonTone.danger
                                  : ButtonTone.text,
                              height: 48,
                              haptic: ButtonHaptic.none,
                              onPressed: _secondary,
                            ),
                          ],
                        ),
                      ),
                      CompanionView(
                        hero: widget.hero,
                        mood: widget.mood,
                        size: 112,
                        showProp: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
