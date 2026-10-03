import 'package:flutter/material.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../services/monthly_medal_rules.dart';
import 'medal_badge.dart';

/// Profile's medals (Batch 5, N10, N17): the Welcome badge, then one row per
/// month, each with its own theme's three medals. The running month is on
/// top, marked in progress, a tier lit the moment the score crosses it
/// (N8: it is certain from then on); finalized months follow, newest first,
/// with their frozen tier. A month's tier lights every tier below it too
/// (docs/prd-gamification.md §M6.2: a Gold month cleared Bronze and Silver);
/// the rest are faded, not hidden.
class MonthlyMedalCollection extends StatelessWidget {
  /// A separate, one-time achievement — not a fourth tier. Rendered above
  /// the months per docs/prd-gamification.md §M6.5/
  /// docs/gamification-handoff.md §12.4: unlike the monthly tiers, this is
  /// permanent and never re-earned, so mixing it into the months would
  /// misrepresent it as something to renew monthly.
  final WelcomeBadge? welcomeBadge;
  final MonthlyMedalProgress? currentProgress;

  /// Finalized months, as stored (newest first is drawn either way).
  final List<MonthlyMedalResult> results;

  /// The stored theme of each month (`StorageService.getClimbMonthThemes`).
  final Map<(int, int), String> themeIds;

  const MonthlyMedalCollection({
    super.key,
    this.welcomeBadge,
    this.currentProgress,
    this.results = const [],
    this.themeIds = const {},
  });

  /// The running month's medals' disc, a finalized month's, and the
  /// Welcome badge's in its row (Batch 5 Batch 0 §1: the stars read from
  /// 48 pt, N20).
  static const currentDisc = 72.0;
  static const historyDisc = 48.0;
  static const welcomeDisc = 64.0;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  /// The theme [year]/[month] is drawn in: its stored theme; otherwise
  /// the running month's calendar theme (Home records it on its first
  /// view), and Green Slope for a past month (themes were not stored
  /// before 1.1.0, when Green Slope was the only one).
  static ClimbTheme themeFor(
      int year, int month, Map<(int, int), String> themeIds,
      {bool running = false}) {
    final stored = themeIds[(year, month)];
    if (stored != null) return ClimbThemes.byId(stored);
    return running
        ? ClimbThemeRotation.shownFor(year, month)
        : ClimbThemes.greenSlope;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = currentProgress;
    final currentTier = current == null
        ? null
        : MonthlyMedalRules.tierFor(
            year: current.year, month: current.month, score: current.score);
    final finalized = [
      for (final r in results)
        if (current == null ||
            (r.year, r.month) != (current.year, current.month))
          r
    ]..sort((a, b) => (b.year * 12 + b.month).compareTo(a.year * 12 + a.month));
    final anyEarned =
        currentTier != null || finalized.any((r) => r.tier != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _WelcomeBadgeRow(badge: welcomeBadge),
        const SizedBox(height: 20),
        Text(
          anyEarned
              ? 'Your monthly achievements.'
              : 'Your monthly medals will appear here once earned.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (current != null) ...[
          const SizedBox(height: 16),
          _CurrentMonth(
            progress: current,
            tier: currentTier,
            theme:
                themeFor(current.year, current.month, themeIds, running: true),
          ),
        ],
        if (finalized.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'History',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final (i, result) in finalized.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            _MedalHistoryRow(
              result: result,
              theme: themeFor(result.year, result.month, themeIds),
            ),
          ],
        ],
      ],
    );
  }
}

/// A month's three medals in its theme: those up to [tier] earned, the
/// rest faded (N10).
class MonthMedals extends StatelessWidget {
  final ClimbTheme theme;
  final MedalTier? tier;
  final double disc;

  const MonthMedals(
      {super.key, required this.theme, required this.tier, required this.disc});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final t in MedalTier.values) ...[
            if (t != MedalTier.bronze) SizedBox(width: disc * .12),
            MedalBadge.monthly(
              themeId: theme.id,
              tier: t,
              disc: disc,
              earned: tier != null && t.index <= tier!.index,
            ),
          ],
        ],
      );
}

/// The one-time Welcome badge (docs/prd-gamification.md §M6.5), always
/// rendered: faded and "Not earned" when [badge] is null. A horizontal
/// row, so it reads as its own category of thing rather than a month.
class _WelcomeBadgeRow extends StatelessWidget {
  final WelcomeBadge? badge;

  const _WelcomeBadgeRow({required this.badge});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final earned = badge != null;
    return Semantics(
      label: 'Welcome badge, ${earned ? 'earned' : 'locked'}.',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                MedalBadge.welcome(
                    disc: MonthlyMedalCollection.welcomeDisc, earned: earned),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome to the climb',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        earned ? 'Earned' : 'Not earned',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The running month (N17): on top, marked in progress, its tiers lit as
/// they become certain.
class _CurrentMonth extends StatelessWidget {
  final MonthlyMedalProgress progress;
  final MedalTier? tier;
  final ClimbTheme theme;

  const _CurrentMonth(
      {required this.progress, required this.tier, required this.theme});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final value = (progress.score / progress.maxScore).clamp(0.0, 1.0);
    return Semantics(
      label: 'This month, ${theme.name}, in progress. '
          '${progress.score} of ${progress.maxScore} points, '
          '${progress.activeDays} active days. '
          '${tier == null ? 'No medal yet.' : '${tier!.label} medal earned.'}',
      container: true,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'This month · ${theme.name}',
                        style: textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'In progress',
                      style: textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Center(
                  child: MonthMedals(
                      theme: theme,
                      tier: tier,
                      disc: MonthlyMedalCollection.currentDisc),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(value: value),
                const SizedBox(height: 8),
                Text(
                  '${progress.score} / ${progress.maxScore} points · '
                  '${progress.activeDays} active days',
                  style: textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A finalized month: its frozen tier, never recomputed (a later rule
/// change cannot touch it).
class _MedalHistoryRow extends StatelessWidget {
  final MonthlyMedalResult result;
  final ClimbTheme theme;

  const _MedalHistoryRow({required this.result, required this.theme});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final muted = textTheme.labelSmall
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final month = MonthlyMedalCollection._months[result.month - 1];
    final outcome =
        result.tier == null ? 'No medal' : '${result.tier!.label} medal';
    return Semantics(
      label: '$month ${result.year}, ${theme.name}, $outcome, '
          '${result.score} of ${result.maxScore} points.',
      container: true,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$month ${result.year}',
                      style: textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(outcome, style: muted),
                  Text(
                      '${theme.name} · ${result.score} / ${result.maxScore} '
                      'points',
                      style: muted),
                ],
              ),
            ),
            const SizedBox(width: 8),
            MonthMedals(
                theme: theme,
                tier: result.tier,
                disc: MonthlyMedalCollection.historyDisc),
          ],
        ),
      ),
    );
  }
}
