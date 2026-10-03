import 'package:flutter/material.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../services/monthly_medal_rules.dart';
import 'medal_badge.dart';
import 'medal_tier_color.dart';

/// Profile's medals (Batch 5, N10, N33, N34): a shelf, the medals side by
/// side. The Welcome badge first, then the months oldest to newest, one
/// medal each: the highest tier reached, in that month's theme. The running
/// month is on the shelf too, marked in progress; with no tier yet it shows
/// its theme's Bronze faded. A past month without a medal is not on the
/// shelf. Tapping a medal brings it forward, larger, with its month, theme,
/// tier, steps and points; a tap anywhere closes it ([showMedalDetail]).
///
/// Under the shelf, the running month's bar (N33, [MedalProgressBar]):
/// each tier's threshold written under its mark and the current score, all
/// from `MonthlyMedalRules`.
class MonthlyMedalCollection extends StatelessWidget {
  /// A separate, one-time achievement — not a fourth tier
  /// (docs/prd-gamification.md §M6.5): first on the shelf, faded until
  /// earned, never a month.
  final WelcomeBadge? welcomeBadge;
  final MonthlyMedalProgress? currentProgress;

  /// Finalized months, as stored (any order).
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

  /// A medal's disc on the shelf (the stars read from 48 pt, N20) and in
  /// its detail (the celebration's, N28).
  static const shelfDisc = 56.0;
  static const detailDisc = 144.0;

  static const welcomeSlotKey = ValueKey('medal_shelf_welcome');
  static ValueKey<String> slotKey(int year, int month) =>
      ValueKey('medal_shelf_$year-$month');
  static const detailKey = ValueKey('medal_shelf_detail');

  static const inProgress = 'In progress';

  static const months = [
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

  /// The shelf's months, oldest to newest (N34): every finalized month
  /// with a medal, then the running month, with or without one.
  List<ShelfMonth> shelf() {
    final current = currentProgress;
    final out = [
      for (final r in results)
        if (r.tier != null &&
            (current == null ||
                (r.year, r.month) != (current.year, current.month)))
          ShelfMonth(
            year: r.year,
            month: r.month,
            theme: themeFor(r.year, r.month, themeIds),
            tier: r.tier,
            steps: r.activeDays,
            score: r.score,
            running: false,
          ),
    ]..sort((a, b) => (a.year * 12 + a.month).compareTo(b.year * 12 + b.month));
    if (current != null) {
      out.add(ShelfMonth(
        year: current.year,
        month: current.month,
        theme: themeFor(current.year, current.month, themeIds, running: true),
        tier: MonthlyMedalRules.tierFor(
            year: current.year, month: current.month, score: current.score),
        steps: current.activeDays,
        score: current.score,
        running: true,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = shelf();
    final current = currentProgress;
    final anyEarned = welcomeBadge != null || months.any((m) => m.tier != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          anyEarned
              ? 'Your medals. Tap one to see its month.'
              : 'Your medals will appear here once earned.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 4,
          runSpacing: 12,
          children: [
            _WelcomeSlot(badge: welcomeBadge),
            for (final m in months) _MonthSlot(month: m),
          ],
        ),
        if (current != null) ...[
          const SizedBox(height: 20),
          MedalProgressBar(
            progress: current,
            theme:
                themeFor(current.year, current.month, themeIds, running: true),
          ),
        ],
      ],
    );
  }
}

/// One month on the shelf (N34).
@immutable
class ShelfMonth {
  final int year, month;
  final ClimbTheme theme;

  /// The highest tier reached; null only for the running month.
  final MedalTier? tier;

  /// The month's active days: the steps climbed.
  final int steps;
  final int score;
  final bool running;

  const ShelfMonth({
    required this.year,
    required this.month,
    required this.theme,
    required this.tier,
    required this.steps,
    required this.score,
    required this.running,
  });

  /// The month's days: the steps to the top.
  int get days => DateTime(year, month + 1, 0).day;

  String get name => '${MonthlyMedalCollection.months[month - 1]} $year';

  /// The shelf's label: "Sep 2026".
  String get label =>
      '${MonthlyMedalCollection.months[month - 1].substring(0, 3)} $year';

  String get outcome => tier == null ? 'No medal yet' : '${tier!.label} medal';

  /// The medal shown: the tier reached, or the theme's Bronze faded.
  MedalBadge medal(double disc) => MedalBadge.monthly(
        themeId: theme.id,
        tier: tier ?? MedalTier.bronze,
        disc: disc,
        earned: tier != null,
      );

  /// The detail's lines under the medal (N34).
  List<String> get details => [
        name,
        theme.name,
        running ? '$outcome · in progress' : outcome,
        '$steps / $days steps · $score points',
      ];
}

/// A shelf slot: the medal, its disc on a common baseline, the label under
/// it and, for the running month, the in-progress mark. Tappable.
class _Slot extends StatelessWidget {
  final Widget medal;
  final String label;
  final String? mark;
  final String semantics;
  final VoidCallback onTap;

  const _Slot({
    super.key,
    required this.medal,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.mark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = MedalBadge.boxFor(MonthlyMedalCollection.shelfDisc);
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: box.width + 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: box.height,
                child: Align(alignment: Alignment.bottomCenter, child: medal),
              ),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              if (mark != null)
                Text(mark!,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _WelcomeSlot extends StatelessWidget {
  final WelcomeBadge? badge;
  const _WelcomeSlot({required this.badge});

  @override
  Widget build(BuildContext context) {
    final earned = badge != null;
    final at = badge?.earnedAt;
    return _Slot(
      key: MonthlyMedalCollection.welcomeSlotKey,
      medal: MedalBadge.welcome(
          disc: MonthlyMedalCollection.shelfDisc, earned: earned),
      label: 'Welcome',
      semantics: 'Welcome badge, ${earned ? 'earned' : 'locked'}.',
      onTap: () => showMedalDetail(
        context,
        medal: MedalBadge.welcome(
            disc: MonthlyMedalCollection.detailDisc, earned: earned),
        lines: [
          'Welcome to the climb',
          at == null
              ? 'Not earned yet'
              : 'Earned in ${MonthlyMedalCollection.months[at.month - 1]} '
                  '${at.year}',
        ],
      ),
    );
  }
}

class _MonthSlot extends StatelessWidget {
  final ShelfMonth month;
  const _MonthSlot({required this.month});

  @override
  Widget build(BuildContext context) {
    final m = month;
    return _Slot(
      key: MonthlyMedalCollection.slotKey(m.year, m.month),
      medal: m.medal(MonthlyMedalCollection.shelfDisc),
      label: m.label,
      mark: m.running ? MonthlyMedalCollection.inProgress : null,
      semantics: '${m.name}, ${m.theme.name}, ${m.outcome}'
          '${m.running ? ', in progress' : ''}.',
      onTap: () => showMedalDetail(context,
          medal: m.medal(MonthlyMedalCollection.detailDisc), lines: m.details),
    );
  }
}

/// N34: the medal brought forward, larger, over a darkened screen, with
/// [lines] under it (the first as its title); a tap anywhere closes it. It
/// grows in and out with a fade; under Reduce Motion it only fades.
Future<void> showMedalDetail(BuildContext context,
    {required Widget medal, required List<String> lines}) {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0xD9080A10),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) {
      final theme = Theme.of(dialogContext);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                key: MonthlyMedalCollection.detailKey,
                width: MonthlyMedalCollection.detailDisc * 2,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  medal,
                  const SizedBox(height: 16),
                  for (final (i, line) in lines.indexed)
                    Padding(
                      padding: EdgeInsets.only(top: i == 0 ? 0 : 4),
                      child: Text(line,
                          textAlign: TextAlign.center,
                          style: i == 0
                              ? theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)
                              : theme.textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: .86))),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final faded = FadeTransition(opacity: animation, child: child);
      if (reduceMotion) return faded;
      return ScaleTransition(
        scale: Tween(begin: .8, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: faded,
      );
    },
  );
}

/// N33: the running month's score against the tier thresholds: the bar,
/// a mark in each tier's colour at its threshold, the tier and its
/// threshold written under the mark, and the current score. Every value
/// from `MonthlyMedalRules`.
class MedalProgressBar extends StatelessWidget {
  final MonthlyMedalProgress progress;
  final ClimbTheme theme;

  const MedalProgressBar(
      {super.key, required this.progress, required this.theme});

  static const barKey = ValueKey('medal_progress_bar');
  static ValueKey<String> thresholdKey(MedalTier tier) =>
      ValueKey('medal_threshold_${tier.name}');
  static const scoreKey = ValueKey('medal_progress_score');

  /// The bar's height and the marks'.
  static const barHeight = 8.0;
  static const markHeight = 16.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final max = progress.maxScore;
    final thresholds = {
      for (final tier in MedalTier.values)
        tier: MonthlyMedalRules.threshold(progress.year, progress.month, tier),
    };
    final reached = MonthlyMedalRules.tierFor(
        year: progress.year, month: progress.month, score: progress.score);
    final labelStyle = t.textTheme.labelSmall;
    return Semantics(
      key: barKey,
      container: true,
      excludeSemantics: true,
      label: 'This month, ${theme.name}: ${progress.score} of $max points, '
          '${progress.activeDays} active days. ${[
        for (final MapEntry(key: tier, value: v) in thresholds.entries)
          '${tier.label} at $v points'
      ].join(', ')}.'
          '${reached == null ? ' No medal yet.' : ' ${reached.label} reached.'}',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text('This month · ${theme.name}',
                    style: t.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text('${progress.score} points',
                  key: scoreKey,
                  style: t.textTheme.titleSmall?.copyWith(
                      color: scheme.primary, fontWeight: FontWeight.w800)),
            ]),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          double at(int v) => width * (v / max).clamp(0.0, 1.0);
          // Room for each label: the gap to its neighbours, no wider.
          const labelWidth = 64.0;
          double labelLeft(int v) =>
              (at(v) - labelWidth / 2).clamp(0.0, width - labelWidth);
          final fontSize = labelStyle?.fontSize ?? 11;
          final height = (labelStyle?.height ?? 1.4) * fontSize;
          return SizedBox(
            height: markHeight + 4 + height * 2,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: (markHeight - barHeight) / 2,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(barHeight / 2),
                  child: LinearProgressIndicator(
                      value: (progress.score / max).clamp(0.0, 1.0),
                      minHeight: barHeight),
                ),
              ),
              for (final MapEntry(key: tier, value: v)
                  in thresholds.entries) ...[
                Positioned(
                  left: (at(v) - 1.5).clamp(0.0, width - 3),
                  top: 0,
                  child: Container(
                      width: 3, height: markHeight, color: tier.color),
                ),
                Positioned(
                  left: labelLeft(v),
                  width: labelWidth,
                  top: markHeight + 4,
                  child: Column(children: [
                    Text(tier.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: labelStyle?.copyWith(
                            fontWeight:
                                reached != null && tier.index <= reached.index
                                    ? FontWeight.w800
                                    : FontWeight.w500)),
                    Text('$v',
                        key: thresholdKey(tier),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: labelStyle?.copyWith(
                            color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ],
            ]),
          );
        }),
        const SizedBox(height: 6),
        Text(
          '${progress.score} / $max points · '
          '${progress.activeDays} active days',
          style:
              t.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
