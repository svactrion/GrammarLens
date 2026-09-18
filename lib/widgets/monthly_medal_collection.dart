import 'package:flutter/material.dart';

import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';

class MonthlyMedalCollection extends StatelessWidget {
  final MonthlyMedalProgress? currentProgress;
  final List<MonthlyMedalResult> results;

  const MonthlyMedalCollection({
    super.key,
    this.currentProgress,
    this.results = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earnedTiers =
        results.map((result) => result.tier).whereType<MedalTier>().toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          earnedTiers.isEmpty
              ? 'Your monthly medals will appear here once earned.'
              : 'Your monthly achievements.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < MedalTier.values.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              Expanded(
                child: _MedalSpecimen(
                  tier: MedalTier.values[i],
                  earned: earnedTiers.contains(MedalTier.values[i]),
                ),
              ),
            ],
          ],
        ),
        if (currentProgress case final progress?) ...[
          const SizedBox(height: 20),
          _CurrentMonthProgress(progress: progress),
        ],
        if (results.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'History',
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final result in results) ...[
            _MedalHistoryRow(result: result),
            if (result != results.last) const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _CurrentMonthProgress extends StatelessWidget {
  final MonthlyMedalProgress progress;

  const _CurrentMonthProgress({required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final value = (progress.score / progress.maxScore).clamp(0.0, 1.0);
    return Semantics(
      label: 'This month, ${progress.score} of ${progress.maxScore} points, '
          '${progress.activeDays} active days, in progress.',
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
                        'This month',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      'In progress',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: value),
                const SizedBox(height: 8),
                Text(
                  '${progress.score} / ${progress.maxScore} points · '
                  '${progress.activeDays} active days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

class _MedalHistoryRow extends StatelessWidget {
  final MonthlyMedalResult result;

  const _MedalHistoryRow({required this.result});

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outcome =
        result.tier == null ? 'No medal' : '${result.tier!.label} medal';
    return Semantics(
      label: '${_months[result.month - 1]} ${result.year}, $outcome, '
          '${result.score} of ${result.maxScore} points.',
      container: true,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(
              result.tier == null
                  ? Icons.lock_outline_rounded
                  : Icons.workspace_premium_rounded,
              color: result.tier == null
                  ? scheme.onSurfaceVariant
                  : scheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_months[result.month - 1]} ${result.year}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${result.score} / ${result.maxScore} points',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Text(outcome, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _MedalSpecimen extends StatelessWidget {
  final MedalTier tier;
  final bool earned;

  const _MedalSpecimen({required this.tier, required this.earned});

  Color get _tierColor => switch (tier) {
        MedalTier.bronze => const Color(0xFFB56A3B),
        MedalTier.silver => const Color(0xFF8A95A3),
        MedalTier.gold => const Color(0xFFD39B21),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tint = earned ? _tierColor : _tierColor.withValues(alpha: 0.42);
    final fill = Color.alphaBlend(
      tint.withValues(alpha: earned ? 0.20 : 0.10),
      scheme.surfaceContainerHigh,
    );

    return Semantics(
      label: '${tier.label} medal, ${earned ? 'earned' : 'locked'}.',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: Border.all(color: tint, width: 2),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.landscape_rounded, color: tint, size: 34),
                    if (!earned)
                      Align(
                        alignment: const Alignment(0.72, 0.72),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.surface,
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.lock_rounded,
                              size: 13,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tier.label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              earned ? 'Earned' : 'Not earned',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
