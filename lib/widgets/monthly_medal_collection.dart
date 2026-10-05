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
/// is not on the strip. Tapping a medal opens its detail
/// ([showMedalDetail]).
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

  /// A medal's disc on the strip and in its detail (the mockup's 86 pt and
  /// 170 pt art boxes, whose circle crop shows a disc of about 92 % of the
  /// box).
  static const shelfDisc = 78.0;
  static const detailDisc = 156.0;

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

  /// The medal shown: the tier reached, or the theme's Bronze faded to
  /// [MonthlyMedalCollection.runningFade].
  MedalBadge medal(double disc) => MedalBadge.monthly(
        themeId: theme.id,
        tier: tier ?? MedalTier.bronze,
        disc: disc,
        earned: tier != null,
        fadedOpacity: MonthlyMedalCollection.runningFade,
      );

  /// The detail's lines under the title and the status; for the running
  /// month below Gold, the next medal's threshold too.
  List<String> get details => [
        // The status line above already says "Not earned yet".
        [
          theme.name,
          if (tier != null) outcome,
          if (running) 'in progress',
        ].join(' · '),
        '$steps / $days steps · ${_points(score)}',
        if (_next case (final tier, _))
          'Reach ${MonthlyMedalRules.threshold(year, month, tier)} points to '
              'earn ${tier.label}.',
      ];

  /// The detail's bold last line: the points still missing to the next
  /// medal, for the running month below Gold; otherwise null.
  String? get toGo => switch (_next) {
        (_, final gap) => '${_points(gap)} to go.',
        null => null,
      };

  (MedalTier, int)? get _next =>
      running ? MonthlyMedalRules.nextTier(year, month, score) : null;
}

/// "1 point", "7 points".
String _points(int n) => n == 1 ? '1 point' : '$n points';

/// A strip slot: the medal, its disc on a common baseline, the label under
/// it and, for the running month, the in-progress mark. Tappable; it takes
/// the focus while its detail is open, so the focus comes back to it.
class _Slot extends StatefulWidget {
  final Widget medal;
  final String label;
  final String? mark;
  final String semantics;
  final void Function(FocusNode opener) onTap;

  const _Slot({
    super.key,
    required this.medal,
    required this.label,
    required this.semantics,
    required this.onTap,
    this.mark,
  });

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> {
  final _focus = FocusNode(debugLabel: 'medal slot');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = MedalBadge.boxFor(MonthlyMedalCollection.shelfDisc);
    return Semantics(
      button: true,
      label: widget.semantics,
      excludeSemantics: true,
      child: InkWell(
        focusNode: _focus,
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onTap(_focus),
        child: SizedBox(
          width: MonthlyMedalCollection.slotWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 5),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                height: box.height,
                child: Align(
                    alignment: Alignment.bottomCenter, child: widget.medal),
              ),
              const SizedBox(height: 8),
              Text(widget.label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.withWeight(FontWeight.w800)
                      .copyWith(color: theme.colorScheme.onSurface)),
              if (widget.mark != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(widget.mark!,
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
      onTap: (opener) => showMedalDetail(
        context,
        opener: opener,
        medal: MedalBadge.welcome(
            disc: MonthlyMedalCollection.detailDisc, earned: earned),
        title: 'Welcome',
        earned: earned,
        lines: [
          'The beginning of your journey.',
          if (at != null)
            'Earned in ${MonthlyMedalCollection.months[at.month - 1]} '
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
      onTap: (opener) => showMedalDetail(context,
          opener: opener,
          medal: m.medal(MonthlyMedalCollection.detailDisc),
          title: m.name,
          earned: m.tier != null,
          lines: m.details,
          emphasis: m.toGo),
    );
  }
}

/// N10: a medal's detail, a card over the dimmed screen (the 1.2.0
/// mockup's layout): the medal large, [title] (the month, or "Welcome"),
/// whether it is earned, [lines] (the theme and tier, steps and points,
/// and for the running month the next medal) and [emphasis] in bold (the
/// points still to go). A tap outside it or its close button closes it.
///
/// The medal grows in over 240 ms ease-out while the card fades in; under
/// Reduce Motion it only fades. The focus moves to the close button inside
/// and, when it closes, back to [opener] (the slot that opened it).
Future<void> showMedalDetail(
  BuildContext context, {
  required Widget medal,
  required String title,
  required bool earned,
  List<String> lines = const [],
  String? emphasis,
  FocusNode? opener,
}) async {
  final reduceMotion = MediaQuery.disableAnimationsOf(context);
  opener?.requestFocus();
  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: const Color(0x8010121B),
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, __) => _MedalDetail(
      animation: reduceMotion ? null : animation,
      medal: medal,
      title: title,
      earned: earned,
      lines: lines,
      emphasis: emphasis,
    ),
    transitionBuilder: (context, animation, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child),
  );
  if (opener != null && opener.context != null && opener.context!.mounted) {
    opener.requestFocus();
  }
}

class _MedalDetail extends StatelessWidget {
  /// The route's animation, driving the medal's growth; null under Reduce
  /// Motion.
  final Animation<double>? animation;
  final Widget medal;
  final String title;
  final bool earned;
  final List<String> lines;
  final String? emphasis;

  const _MedalDetail({
    required this.animation,
    required this.medal,
    required this.title,
    required this.earned,
    required this.lines,
    required this.emphasis,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final grow = animation;
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(appCardRadius),
                boxShadow: palette.cardShadow,
              ),
              child: Material(
                key: MonthlyMedalCollection.detailKey,
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(appCardRadius),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        autofocus: true,
                        tooltip: 'Close',
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.surfaceContainerHighest,
                          foregroundColor: scheme.onSurface,
                          minimumSize: const Size(44, 44),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    ExcludeSemantics(
                      child: grow == null
                          ? medal
                          : ScaleTransition(
                              scale: Tween(begin: .5, end: 1.0).animate(
                                  CurvedAnimation(
                                      parent: grow, curve: Curves.easeOut)),
                              child: medal,
                            ),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      header: true,
                      child: Text(title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(color: scheme.onSurface)),
                    ),
                    const SizedBox(height: 8),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          earned
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_empty_rounded,
                          size: 15,
                          color: scheme.secondary),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(earned ? 'Earned' : 'Not earned yet',
                            style: theme.textTheme.labelMedium
                                ?.withWeight(FontWeight.w800)
                                .copyWith(color: scheme.secondary)),
                      ),
                    ]),
                    const SizedBox(height: 8),
                    for (final line in lines)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(line,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ),
                    if (emphasis != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(emphasis!,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.withWeight(FontWeight.w800)
                                .copyWith(color: scheme.onSurface)),
                      ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
