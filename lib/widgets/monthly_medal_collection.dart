import 'package:flutter/material.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../services/monthly_medal_rules.dart';
import 'medal_badge.dart';
import 'medal_tier_color.dart';
import '../theme.dart';

/// Profile's medals (Batch 5, N10, N33; 1.2.0 Batch 7, Q7): a horizontal
/// strip, the medals side by side with no card or disc behind them. The
/// running month first, then the finalized months newest to oldest, one
/// medal each (the highest tier reached, in that month's theme), and the
/// Welcome badge last (Q7, which replaced N34's Welcome-first, oldest-first
/// order). The running month is marked in progress; with no tier yet it
/// shows its theme's Bronze at [runningFade]. A past month without a medal
/// is not on the strip. Tapping a medal brings it forward, larger, with its
/// month, theme, tier, steps and points; a tap anywhere closes it
/// ([showMedalDetail], unchanged since Batch 5: the owner kept it, 1.2.0
/// Batch 8).
///
/// The running month's progress is a separate card under the strip,
/// [MonthlyProgressCard] (N9). Profile heads the section "Medal collection"
/// with [earnedCount].
class MonthlyMedalCollection extends StatelessWidget {
  /// A separate, one-time achievement — not a fourth tier
  /// (docs/prd-gamification.md §M6.5): last on the strip, faded until
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

  /// A medal's disc on the strip (the mockup's 86 pt art box, whose circle
  /// crop shows a disc of about 92 % of it) and in its detail (the
  /// celebration's, N28; the detail is as before 1.2.0 Batch 7).
  static const shelfDisc = 78.0;
  static const detailDisc = 144.0;

  /// A slot's width (the mockup's 92 pt) and the gap between slots.
  static const slotWidth = 92.0;
  static const slotGap = 16.0;

  /// The running month's medal while it has no tier yet (Q7, the
  /// mockup's .38); other unearned medals keep [MedalBadge.unearnedOpacity].
  static const runningFade = .38;

  static const stripKey = ValueKey('medal_strip');
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

  /// The strip's months, newest first (Q7): the running month, with or
  /// without a tier, then every finalized month with a medal.
  List<ShelfMonth> shelf() {
    final current = currentProgress;
    final past = [
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
    ]..sort((a, b) => (b.year * 12 + b.month).compareTo(a.year * 12 + a.month));
    return [
      if (current != null)
        ShelfMonth(
          year: current.year,
          month: current.month,
          theme: themeFor(current.year, current.month, themeIds, running: true),
          tier: MonthlyMedalRules.tierFor(
              year: current.year, month: current.month, score: current.score),
          steps: current.activeDays,
          score: current.score,
          running: true,
        ),
      ...past,
    ];
  }

  /// "N earned" beside the section title: the medals on the strip that are
  /// earned, the Welcome badge included and the running month once it has
  /// a tier.
  int get earnedCount =>
      (welcomeBadge != null ? 1 : 0) +
      shelf().where((m) => m.tier != null).length;

  @override
  Widget build(BuildContext context) {
    final months = shelf();
    return SingleChildScrollView(
      key: stripKey,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in months) ...[
            _MonthSlot(month: m),
            const SizedBox(width: slotGap),
          ],
          _WelcomeSlot(badge: welcomeBadge),
        ],
      ),
    );
  }
}

/// One month on the strip.
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

  /// The strip's label: "Sep 2026".
  String get label =>
      '${MonthlyMedalCollection.months[month - 1].substring(0, 3)} $year';

  String get outcome => tier == null ? 'No medal yet' : '${tier!.label} medal';

  /// The medal shown: the tier reached, or the theme's Bronze faded (on
  /// the strip to [MonthlyMedalCollection.runningFade], in the detail to
  /// [MedalBadge.unearnedOpacity], as before 1.2.0 Batch 7).
  MedalBadge medal(double disc,
          {double fadedOpacity = MedalBadge.unearnedOpacity}) =>
      MedalBadge.monthly(
        themeId: theme.id,
        tier: tier ?? MedalTier.bronze,
        disc: disc,
        earned: tier != null,
        fadedOpacity: fadedOpacity,
      );

  /// The detail's lines under the medal (N34).
  List<String> get details => [
        name,
        theme.name,
        running ? '$outcome · in progress' : outcome,
        '$steps / $days steps · $score points',
      ];
}

/// "1 point", "7 points".
String _points(int n) => n == 1 ? '1 point' : '$n points';

/// A strip slot: the medal, its disc on a common baseline, the label under
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
          width: MonthlyMedalCollection.slotWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: box.height,
                child: Align(alignment: Alignment.bottomCenter, child: medal),
              ),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.withWeight(FontWeight.w800)
                      .copyWith(color: theme.colorScheme.onSurface)),
              if (mark != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(mark!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
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
      medal: m.medal(MonthlyMedalCollection.shelfDisc,
          fadedOpacity: MonthlyMedalCollection.runningFade),
      label: m.label,
      mark: m.running ? MonthlyMedalCollection.inProgress : null,
      semantics: '${m.name}, ${m.theme.name}, ${m.outcome}'
          '${m.running ? ', in progress' : ''}.',
      onTap: () => showMedalDetail(context,
          medal: m.medal(MonthlyMedalCollection.detailDisc), lines: m.details),
    );
  }
}

/// N10 / N34 (as before 1.2.0 Batch 7; the owner kept this detail): the
/// medal brought forward, larger, over a darkened screen, with
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
                              ? theme.textTheme.titleLarge
                                  ?.withWeight(FontWeight.w800)
                                  .copyWith(color: Colors.white)
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

/// N9: the running month's progress, a card of its own under the strip.
/// The month's points in an orange label; the next medal, the points
/// towards it and its bar; how many points are left (never negative: the
/// next tier comes from `MonthlyMedalRules.nextTier`, which is always above
/// the score); the three thresholds; the month's total. Every number from
/// `MonthlyMedalRules` and the progress, so no month's thresholds are
/// assumed. Four states: before Bronze, Bronze reached (next Silver), Silver
/// reached (next Gold), Gold reached (a completion line).
class MonthlyProgressCard extends StatelessWidget {
  final MonthlyMedalProgress progress;
  final ClimbTheme theme;

  const MonthlyProgressCard(
      {super.key, required this.progress, required this.theme});

  static const cardKey = ValueKey('medal_progress_card');
  static const pointsKey = ValueKey('medal_progress_points');
  static const goalKey = ValueKey('medal_progress_goal');
  static const toGoKey = ValueKey('medal_progress_to_go');
  static const totalKey = ValueKey('medal_progress_total');
  static ValueKey<String> thresholdKey(MedalTier tier) =>
      ValueKey('medal_threshold_${tier.name}');

  /// The bar's height.
  static const barHeight = 9.0;

  /// The line under the bar for [progress].
  static String toGoLine(MonthlyMedalProgress progress) {
    final reached = MonthlyMedalRules.tierFor(
        year: progress.year, month: progress.month, score: progress.score);
    final next = MonthlyMedalRules.nextTier(
        progress.year, progress.month, progress.score);
    if (next == null) {
      return "Gold earned. That's this month's top medal.";
    }
    final (tier, gap) = next;
    if (reached == null) {
      return '${_points(gap)} to your first monthly medal';
    }
    return '${reached.label} earned · ${_points(gap)} to ${tier.label}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final p = progress;
    final monthName = MonthlyMedalCollection.months[p.month - 1];
    final next = MonthlyMedalRules.nextTier(p.year, p.month, p.score);
    final thresholds = {
      for (final tier in MedalTier.values)
        tier: MonthlyMedalRules.threshold(p.year, p.month, tier),
    };
    // The goal: the next medal's threshold; past Gold, the month's maximum.
    final goal = next == null ? p.maxScore : thresholds[next.$1]!;
    final value = next == null ? 1.0 : (p.score / goal).clamp(0.0, 1.0);
    final muted = scheme.onSurfaceVariant;
    final small = t.textTheme.labelSmall?.withWeight(FontWeight.w400);
    final days =
        p.activeDays == 1 ? '1 active day' : '${p.activeDays} active days';
    final toGo = toGoLine(p);
    final goalLine = next == null
        ? 'Gold reached, ${p.score} of ${p.maxScore} points'
        : 'Next medal ${next.$1.label}, ${p.score} of $goal points';

    return Card(
      key: cardKey,
      margin: EdgeInsets.zero,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: '$monthName progress, ${theme.name}, $days. '
            '$goalLine. $toGo. ${[
          for (final MapEntry(key: tier, value: v) in thresholds.entries)
            '${tier.label} at $v points'
        ].join(', ')}. Monthly total ${p.score} of ${p.maxScore} points.',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$monthName progress',
                          style: t.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface, letterSpacing: -.3)),
                      const SizedBox(height: 4),
                      Text('${theme.name} · $days',
                          style: small?.copyWith(color: muted)),
                    ]),
              ),
              const SizedBox(width: 12),
              Container(
                key: pointsKey,
                constraints: const BoxConstraints(minWidth: 54),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${p.score}',
                      style: t.textTheme.headlineMedium
                          ?.copyWith(color: scheme.onPrimary, height: 1)),
                  const SizedBox(height: 3),
                  Text(p.score == 1 ? 'point' : 'points',
                      style: t.textTheme.labelSmall
                          ?.withWeight(FontWeight.w800)
                          .copyWith(color: scheme.onPrimary)),
                ]),
              ),
            ]),
            const SizedBox(height: 18),
            Wrap(
              key: goalKey,
              alignment: WrapAlignment.spaceBetween,
              spacing: 10,
              runSpacing: 4,
              children: [
                Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: next == null ? 'Top medal ' : 'Next medal '),
                      TextSpan(
                          text: next == null ? 'Gold' : next.$1.label,
                          style: TextStyle(color: scheme.onSurface)
                              .withWeight(FontWeight.w800)),
                    ]),
                    style: t.textTheme.labelMedium
                        ?.withWeight(FontWeight.w400)
                        .copyWith(color: muted)),
                Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '${p.score}',
                          style: TextStyle(color: scheme.onSurface)
                              .withWeight(FontWeight.w800)),
                      TextSpan(text: ' / $goal pts'),
                    ]),
                    style: t.textTheme.labelMedium
                        ?.withWeight(FontWeight.w400)
                        .copyWith(color: muted)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(barHeight / 2),
              child: LinearProgressIndicator(
                value: value,
                minHeight: barHeight,
                color: scheme.primary,
                backgroundColor: scheme.outlineVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(toGo,
                key: toGoKey,
                style: t.textTheme.labelMedium
                    ?.withWeight(FontWeight.w400)
                    .copyWith(color: muted)),
            const SizedBox(height: 17),
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: tier, value: v) in thresholds.entries)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: tier.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tier.label,
                              style: t.textTheme.labelSmall
                                  ?.withWeight(FontWeight.w800)
                                  .copyWith(color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text('$v pts',
                              key: thresholdKey(tier),
                              style: small?.copyWith(color: muted)),
                        ]),
                  ]),
              ],
            ),
            const SizedBox(height: 14),
            Text('Monthly total: ${p.score} / ${p.maxScore} points',
                key: totalKey, style: small?.copyWith(color: muted)),
          ]),
        ),
      ),
    );
  }
}
