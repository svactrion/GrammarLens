import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets/buddy_picker.dart';
import '../widgets/monthly_climb/monthly_mountain.dart';
import '../widgets/pressable_button.dart';

/// This month's mountain (V06): the month's mountain with the summit flag
/// and the avatar at the start; below, "<MONTH> · <MOUNTAIN>", the title, a
/// line, and "Take my first step" (→ the Day-0 Daily Test).
///
/// Motion: the mountain scales 0.9 → 1 (600 ms, easeOutCubic); the bottom
/// panel slides up 24 px (300 ms). The CTA plays a medium haptic.
class MountainIntroScreen extends StatelessWidget {
  final ClimbTheme theme;
  final Avatar hero;
  final int days;
  final String monthName;
  final VoidCallback onStart;

  const MountainIntroScreen({
    super.key,
    required this.theme,
    required this.hero,
    required this.days,
    required this.monthName,
    required this.onStart,
  });

  static const startKey = ValueKey('mountain_intro_start');

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final reduced = AppMotion.reduced(context);
    return Scaffold(
      backgroundColor: c.page,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: c.orangeSoft),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : .9, end: 1),
                  duration: AppMotion.entrance(
                      context, const Duration(milliseconds: 600)),
                  curve: AppMotion.enter,
                  builder: (context, s, child) =>
                      Transform.scale(scale: s, child: child),
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width,
                        child: MonthlyMountain(
                          days: days,
                          completedDays: 0,
                          avatar: hero,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
                ),
                const SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: OnboardingStepDots(step: 4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration:
                AppMotion.entrance(context, const Duration(milliseconds: 300)),
            curve: AppMotion.enter,
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                  offset: Offset(0, reduced ? 0 : 24 * (1 - t)), child: child),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: c.page,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.mountainIntroEyebrow(monthName.toUpperCase(),
                          theme.title(l10n).toUpperCase()),
                      style: text.labelMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.orangeDeep, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.mountainIntroTitle,
                      style: text.headlineMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.text, letterSpacing: -.8),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.mountainIntroBody,
                      style: text.bodyMedium!.copyWith(color: c.muted),
                    ),
                    const SizedBox(height: 22),
                    PressableButton(
                      key: startKey,
                      label: l10n.mountainIntroStart,
                      tone: ButtonTone.orange,
                      shine: true,
                      trailingIcon:
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                      onPressed: onStart,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
