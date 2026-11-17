import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/medal_tier.dart';
import '../motion.dart';
import '../services/monthly_medal_rules.dart';
import '../theme.dart';
import 'pressable_button.dart';
import 'score_ring.dart';

/// The score capsule at the top right of Home (V14, SPEC §3.6): a ring
/// towards the next medal tier around the clay star, this month's points,
/// "N to Bronze" (or the tier reached), and a "+N" badge after today's
/// points. Tap → Profile's month progress.
///
/// Thresholds come from [MonthlyMedalRules] for [year] / [month].
class ScoreCapsule extends StatelessWidget {
  final int points;
  final int year;
  final int month;

  /// Today's points, or null before today's Daily Test (no badge).
  final int? today;
  final VoidCallback? onTap;

  const ScoreCapsule({
    super.key,
    required this.points,
    required this.year,
    required this.month,
    this.today,
    this.onTap,
  });

  /// The next tier above [points] this month, or null at Gold.
  static MedalTier? nextTier(int points, int year, int month) {
    for (final tier in MedalTier.values) {
      if (points < MonthlyMedalRules.threshold(year, month, tier)) return tier;
    }
    return null;
  }

  /// Progress (0–1) from the previous tier's line to the next one's.
  static double progress(int points, int year, int month) {
    final next = nextTier(points, year, month);
    if (next == null) return 1;
    final to = MonthlyMedalRules.threshold(year, month, next);
    final from = next.index == 0
        ? 0
        : MonthlyMedalRules.threshold(
            year, month, MedalTier.values[next.index - 1]);
    if (to <= from) return 1;
    return ((points - from) / (to - from)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final next = nextTier(points, year, month);
    final line = next == null
        ? l10n.capsuleTopTier
        : l10n.capsuleToTier(
            MonthlyMedalRules.threshold(year, month, next) - points,
            next.label(l10n));
    final semantics = '${l10n.capsulePoints(points)}. $line';
    final capsule = MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Container(
        height: 60,
        padding: const EdgeInsetsDirectional.fromSTEB(6, 6, 14, 6),
        decoration: lipCard(c, radius: 30, lipHeight: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScoreRing(
              value: progress(points, year, month),
              size: 46,
              stroke: 4,
              color: c.gold,
              track: c.track,
              center: Image.asset('assets/ui/points_star.webp',
                  width: 30, height: 30, excludeFromSemantics: true),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: points - (today ?? 0), end: points),
                  duration: AppMotion.orInstant(
                      context, const Duration(milliseconds: 600)),
                  builder: (context, v, _) => Text(
                    '$v', // l10n-guard: a number
                    style: theme.textTheme.titleLarge!
                        .withWeight(FontWeight.w900)
                        .copyWith(
                            color: c.text,
                            fontSize: 20,
                            height: 1.05,
                            fontFeatures: const [FontFeature.tabularFigures()]),
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: Text(
                    line,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall!
                        .withWeight(FontWeight.w800)
                        .copyWith(color: c.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return Semantics(
      button: onTap != null,
      label: semantics,
      excludeSemantics: true,
      child: PressableCard(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            capsule,
            if (today != null && today! > 0)
              PositionedDirectional(
                top: -10,
                end: -4,
                child: _TodayBadge(points: today!),
              ),
          ],
        ),
      ),
    );
  }
}

/// "+9": pops in (easeOutBack) after today's points.
class _TodayBadge extends StatelessWidget {
  final int points;
  const _TodayBadge({required this.points});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.entrance(context, AppMotion.slow),
      curve: AppMotion.pop,
      builder: (context, t, child) =>
          Transform.scale(scale: t.clamp(0.0, 1.2), child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: c.green,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.card, width: 2),
        ),
        child: Text(
          '+$points', // l10n-guard: a signed number
          textScaler: TextScaler.noScaling,
          style: Theme.of(context)
              .textTheme
              .labelMedium!
              .withWeight(FontWeight.w900)
              .copyWith(color: c.onNavy, fontSize: 12),
        ),
      ),
    );
  }
}
