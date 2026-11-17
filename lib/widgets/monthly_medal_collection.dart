import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/welcome_badge.dart';
import '../motion.dart';
import '../services/monthly_medal_rules.dart';
import '../utils/haptics.dart';
import 'medal_badge.dart';
import 'medal_tier_color.dart';
import '../theme.dart';
import '../l10n/l10n.dart';

/// Profile's medals (V23, UI polish fix round 1): the thick shelf
/// (`medal_shelf_v2`) with at most [shelfMax] medals standing on its top
/// surface, newest first (the start of the line). The running month comes
/// first, a locked slot (a dashed ring with a lock) until it reaches a
/// tier and then its medal; then the finalized months with a medal and the
/// earned Welcome badge, newest to oldest. Each slot has a title and a
/// line under the shelf. A past month without a medal and an unearned
/// Welcome badge are not on the shelf. Tapping a medal brings it forward,
/// larger, with its month, theme, tier, steps and points ([showMedalDetail]);
/// "See all" (Profile) opens every medal (PF02, `showAllMedals`), which
/// reads [shelf] and [welcomeBadge].
///
/// The running month's progress is a separate card under the shelf,
/// [MonthlyProgressCard] (N9).
class MonthlyMedalCollection extends StatelessWidget {
  /// A separate, one-time achievement — not a fourth tier
  /// (docs/prd-gamification.md §M6.5): on the shelf by the month it was
  /// earned, last in PF02, never a month.
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

  /// A medal's disc on the shelf (the board's 78 pt) and in its detail
  /// (the celebration's, N28).
  static const shelfDisc = 78.0;
  static const detailDisc = 144.0;

  /// The most medals on the shelf (V23); the rest are in PF02.
  static const shelfMax = 3;

  /// The shelf image's size (ASSETS.md: 1170 × 240).
  static const shelfAsset = 'assets/ui/medal_shelf_v2.webp';
  static const shelfAspect = 1170 / 240;

  /// Where a medal's bottom stands on the shelf image, and where the slot's
  /// labels start, as shares of the image's height (the board: the medals
  /// overlap the 65 pt image by 26 pt; the labels start 14 pt above its
  /// bottom, under the shelf's front face).
  static const standAt = 26 / 65;
  static const labelsAt = 51 / 65;

  /// The medals settle on the shelf one after another (V23).
  static const settleStagger = Duration(milliseconds: 80);

  /// The running month's medal while it has no tier yet in PF02 (Q7, the
  /// mockup's .38); other unearned medals keep [MedalBadge.unearnedOpacity].
  static const runningFade = .38;

  static const stripKey = ValueKey('medal_strip');
  static const welcomeSlotKey = ValueKey('medal_shelf_welcome');
  static ValueKey<String> slotKey(int year, int month) =>
      ValueKey('medal_shelf_$year-$month');
  static const detailKey = ValueKey('medal_shelf_detail');

  /// The running month's locked slot (no tier yet).
  static const lockedKey = ValueKey('medal_shelf_locked');

  /// The Hero tag a medal flies under between the shelf, PF02 and PF03.
  static String heroTag(int year, int month) => 'medal_hero_$year-$month';
  static const welcomeHeroTag = 'medal_hero_welcome';

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

  /// Every month with a place in the collection, newest first (Q7): the
  /// running month, with or without a tier, then every finalized month
  /// with a medal.
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

  /// The shelf's slots (V23), newest first, at most [shelfMax]: the
  /// running month, then the past medals and the earned Welcome badge (a
  /// null slot) by month. A month's medal is finalized at the month's end, so in the
  /// month the badge was earned it comes before the badge.
  List<ShelfMonth?> shelfSlots() => allSlots().take(shelfMax).toList();

  /// Every slot of the collection, newest first (PF02, and the shelf's
  /// first [shelfMax]): the running month, then the past medals and the
  /// earned Welcome badge (a null slot) at the month it was earned.
  List<ShelfMonth?> allSlots() {
    final months = shelf();
    final badge = welcomeBadge;
    final slots = <ShelfMonth?>[...months];
    if (badge != null) {
      final at = badge.earnedAt.year * 12 + badge.earnedAt.month;
      final i =
          months.indexWhere((m) => !m.running && m.year * 12 + m.month < at);
      slots.insert(i < 0 ? slots.length : i, null);
    }
    return slots;
  }

  /// PF02's counters: finalized medals of [tier] (the running month's
  /// tier is not final yet, so it is not counted).
  int countOf(MedalTier tier) =>
      shelf().where((m) => !m.running && m.tier == tier).length;

  /// The medals earned: the Welcome badge and every month on [shelf] with
  /// a tier (the running month once it has one). PF02's header.
  int get earnedCount =>
      (welcomeBadge != null ? 1 : 0) +
      shelf().where((m) => m.tier != null).length;

  @override
  Widget build(BuildContext context) {
    final slots = shelfSlots();
    return LayoutBuilder(builder: (context, constraints) {
      final shelfHeight = constraints.maxWidth / shelfAspect;
      final box = MedalBadge.boxFor(shelfDisc);
      final gap = shelfHeight * (labelsAt - standAt);
      return Material(
        type: MaterialType.transparency,
        child: Stack(key: stripKey, clipBehavior: Clip.none, children: [
          Positioned(
            top: box.height - shelfHeight * standAt,
            left: 0,
            right: 0,
            height: shelfHeight,
            child: ExcludeSemantics(
              child: Image.asset(shelfAsset, fit: BoxFit.fill),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, slot) in slots.indexed)
                Expanded(
                  child: slot == null
                      ? _WelcomeSlot(index: i, gap: gap, badge: welcomeBadge!)
                      : _MonthSlot(index: i, gap: gap, month: slot),
                ),
            ],
          ),
        ]),
      );
    });
  }
}

/// One month in the collection.
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

  /// "October 2026".
  String name(AppLocalizations l10n) => monthYear(year, month, l10n);

  /// The shelf's label: "Sep 2026".
  String label(AppLocalizations l10n) => monthYearShort(year, month, l10n);

  String outcome(AppLocalizations l10n) =>
      tier == null ? l10n.medalNone : l10n.medalTierMedal(tier!.label(l10n));

  /// The shelf's line under the label: a past month's tier; the running
  /// month's way to its next medal ("66 pts to Bronze"), or "In progress"
  /// once it has Gold.
  String shelfLine(AppLocalizations l10n) {
    if (!running) return tier!.label(l10n);
    final next = MonthlyMedalRules.nextTier(year, month, score);
    if (next == null) return l10n.medalInProgress;
    return l10n.profileShelfToNext(
        l10n.medalThresholdPoints(next.$2), next.$1.label(l10n));
  }

  /// The medal shown: the tier reached, or the theme's Bronze faded (in
  /// PF02 to [MonthlyMedalCollection.runningFade], in the detail to
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

  /// The detail's lines under the medal (N34). [t] counts the steps and
  /// points up from 0 (PF03); 1 is the final value.
  List<String> details(AppLocalizations l10n, {double t = 1}) => [
        name(l10n),
        theme.title(l10n),
        running ? l10n.medalOutcomeInProgress(outcome(l10n)) : outcome(l10n),
        l10n.medalStepsPoints((steps * t).round(), days, (score * t).round()),
      ];

  /// Opens this month's detail (PF03); its medal flies from [heroTag]'s
  /// place.
  Future<void> showDetail(BuildContext context) {
    final l10n = context.l10n;
    return showMedalDetail(context,
        medal: medal(MonthlyMedalCollection.detailDisc),
        heroTag: MonthlyMedalCollection.heroTag(year, month),
        linesAt: (t) => details(l10n, t: t));
  }
}

/// Opens the Welcome badge's detail (PF03).
Future<void> showWelcomeDetail(BuildContext context, WelcomeBadge? badge) {
  final l10n = context.l10n;
  final at = badge?.earnedAt;
  return showMedalDetail(
    context,
    medal: MedalBadge.welcome(
        disc: MonthlyMedalCollection.detailDisc, earned: badge != null),
    heroTag: MonthlyMedalCollection.welcomeHeroTag,
    lines: [
      l10n.medalWelcomeTitle,
      at == null
          ? l10n.medalWelcomeNotEarned
          : l10n.medalWelcomeEarnedIn(monthYear(at.year, at.month, l10n)),
    ],
  );
}

/// A medal that flies between the shelf, PF02 and PF03 under [tag]; no
/// flight under Reduce Motion.
class MedalHero extends StatelessWidget {
  final Object tag;
  final Widget child;
  const MedalHero({super.key, required this.tag, required this.child});

  @override
  Widget build(BuildContext context) => HeroMode(
        enabled: !AppMotion.reduced(context),
        child: Hero(tag: tag, child: child),
      );
}

/// A shelf slot (V23): the medal standing on the shelf (it settles from
/// above, [MonthlyMedalCollection.settleStagger] after the slot before
/// it), then, under the shelf's front face, the title and a line.
/// Tappable.
class _ShelfSlot extends StatelessWidget {
  final int index;

  /// From the medal's bottom to the labels: the shelf's front face.
  final double gap;
  final Widget medal;
  final String title;
  final String line;
  final String semantics;
  final VoidCallback onTap;

  const _ShelfSlot({
    super.key,
    required this.index,
    required this.gap,
    required this.medal,
    required this.title,
    required this.line,
    required this.semantics,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final box = MedalBadge.boxFor(MonthlyMedalCollection.shelfDisc);
    final reduced = AppMotion.reduced(context);
    final delay = MonthlyMedalCollection.settleStagger * index;
    final total = AppMotion.slow + delay;
    return Semantics(
      button: true,
      label: semantics,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticMap.light();
          onTap();
        },
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: box.height,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: reduced ? 1 : 0, end: 1),
                duration: reduced ? Duration.zero : total,
                curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1,
                    curve: AppMotion.pop),
                builder: (context, t, child) => Opacity(
                  opacity: t.clamp(0.0, 1.0),
                  child: Transform.translate(
                      offset: Offset(0, -14 * (1 - t)), child: child),
                ),
                child: medal,
              ),
            ),
          ),
          SizedBox(height: gap),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(children: [
              Text(title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.bodySmall!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.text)),
              const SizedBox(height: 1),
              Text(line,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: theme.textTheme.labelSmall!
                      .withWeight(FontWeight.w700)
                      .copyWith(color: c.muted)),
            ]),
          ),
          const SizedBox(height: 6),
        ]),
      ),
    );
  }
}

class _WelcomeSlot extends StatelessWidget {
  final int index;
  final double gap;
  final WelcomeBadge badge;
  const _WelcomeSlot(
      {required this.index, required this.gap, required this.badge});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final at = badge.earnedAt;
    return _ShelfSlot(
      key: MonthlyMedalCollection.welcomeSlotKey,
      index: index,
      gap: gap,
      medal: const MedalHero(
        tag: MonthlyMedalCollection.welcomeHeroTag,
        child: MedalBadge.welcome(disc: MonthlyMedalCollection.shelfDisc),
      ),
      title: l10n.medalWelcomeSlot,
      line: monthYearShort(at.year, at.month, l10n),
      semantics: l10n.medalWelcomeEarned,
      onTap: () => showWelcomeDetail(context, badge),
    );
  }
}

class _MonthSlot extends StatelessWidget {
  final int index;
  final double gap;
  final ShelfMonth month;
  const _MonthSlot(
      {required this.index, required this.gap, required this.month});

  @override
  Widget build(BuildContext context) {
    final m = month;
    final l10n = context.l10n;
    final locked = m.running && m.tier == null;
    return _ShelfSlot(
      key: MonthlyMedalCollection.slotKey(m.year, m.month),
      index: index,
      gap: gap,
      medal: MedalHero(
        tag: MonthlyMedalCollection.heroTag(m.year, m.month),
        child: locked
            ? const _LockedSlot(key: MonthlyMedalCollection.lockedKey)
            : m.medal(MonthlyMedalCollection.shelfDisc),
      ),
      title: m.label(l10n),
      line: m.shelfLine(l10n),
      semantics: m.running
          ? l10n.medalSlotSemanticsRunning(
              m.name(l10n), m.theme.title(l10n), m.outcome(l10n))
          : l10n.medalSlotSemantics(
              m.name(l10n), m.theme.title(l10n), m.outcome(l10n)),
      onTap: () => m.showDetail(context),
    );
  }
}

/// The running month's place before it has a medal (V23): a dashed ring
/// with a lock, the size of a medal's disc.
class _LockedSlot extends StatelessWidget {
  const _LockedSlot({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    const disc = MonthlyMedalCollection.shelfDisc;
    return SizedBox.square(
      dimension: disc,
      child: CustomPaint(
        painter: _DashedRingPainter(color: c.line),
        child: Icon(Icons.lock_outline_rounded, size: 22, color: c.muted),
      ),
    );
  }
}

class _DashedRingPainter extends CustomPainter {
  final Color color;
  const _DashedRingPainter({required this.color});

  static const _dashes = 18;
  static const _stroke = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & size;
    final ring = rect.deflate(_stroke / 2);
    const step = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(ring, i * step, step * .55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRingPainter old) => old.color != color;
}

/// N10 / N34 / PF03 (the owner kept this detail): the medal brought
/// forward, larger, over a darkened screen, with its lines under it (the
/// first as its title); a tap anywhere closes it. The medal flies from
/// [heroTag]'s place (the shelf or PF02, 350 ms) and [linesAt] counts its
/// numbers up ([lines] when they do not count). Under Reduce Motion it
/// only fades, nothing flies or counts.
Future<void> showMedalDetail(BuildContext context,
    {required Widget medal,
    List<String> lines = const [],
    List<String> Function(double t)? linesAt,
    Object? heroTag}) {
  final reduceMotion = AppMotion.reduced(context);
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: true,
    barrierLabel: context.l10n.commonClose,
    barrierColor: const Color(0xD9080A10),
    transitionDuration: reduceMotion ? AppMotion.fast : _detailFlight,
    reverseTransitionDuration: reduceMotion ? AppMotion.fast : _detailFlight,
    pageBuilder: (dialogContext, _, __) {
      final theme = Theme.of(dialogContext);
      Widget body(List<String> lines) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
            ],
          );
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
                  heroTag == null
                      ? medal
                      : MedalHero(tag: heroTag, child: medal),
                  const SizedBox(height: 16),
                  if (linesAt == null)
                    body(lines)
                  else
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
                      duration:
                          reduceMotion ? Duration.zero : AppMotion.celebrate,
                      curve: AppMotion.enter,
                      builder: (context, t, _) => body(linesAt(t)),
                    ),
                ]),
              ),
            ),
          ),
        ),
      );
    },
    transitionsBuilder: (context, animation, _, child) {
      final faded = FadeTransition(opacity: animation, child: child);
      if (reduceMotion) return faded;
      return ScaleTransition(
        scale: Tween(begin: .8, end: 1.0)
            .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: faded,
      );
    },
  ));
}

/// PF02 / PF03's Hero flight (SPEC: 350 ms).
const _detailFlight = Duration(milliseconds: 350);

/// N9: the running month's progress, a card of its own under the shelf.
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
  static String toGoLine(MonthlyMedalProgress progress, AppLocalizations l10n) {
    final reached = MonthlyMedalRules.tierFor(
        year: progress.year, month: progress.month, score: progress.score);
    final next = MonthlyMedalRules.nextTier(
        progress.year, progress.month, progress.score);
    if (next == null) return l10n.medalTopReached;
    final (tier, gap) = next;
    if (reached == null) return l10n.medalToFirst(l10n.medalPoints(gap));
    return l10n.medalToNext(
        reached.label(l10n), l10n.medalPoints(gap), tier.label(l10n));
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final scheme = t.colorScheme;
    final p = progress;
    final l10n = context.l10n;
    final month = monthName(p.month, l10n);
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
    final days = l10n.medalActiveDays(p.activeDays);
    final toGo = toGoLine(p, l10n);
    final goalLine = next == null
        ? l10n.medalGoldReachedSemantics(p.score, p.maxScore)
        : l10n.medalNextSemantics(next.$1.label(l10n), p.score, goal);

    return Card(
      key: cardKey,
      margin: EdgeInsets.zero,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        label: l10n.medalProgressSemantics(
            month,
            theme.title(l10n),
            days,
            goalLine,
            toGo,
            [
              for (final MapEntry(key: tier, value: v) in thresholds.entries)
                l10n.medalThresholdSemantics(tier.label(l10n), v)
            ].join(l10n.listSeparator),
            p.score,
            p.maxScore),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(17, 18, 17, 15),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.medalProgressTitle(month),
                          style: t.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface, letterSpacing: -.3)),
                      const SizedBox(height: 4),
                      Text(l10n.medalThemeDays(theme.title(l10n), days),
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
                  Text(l10n.medalPointsUnit(p.score),
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
                          text: next == null
                              ? l10n.medalTopLabel
                              : l10n.medalNextLabel),
                      TextSpan(
                          text: next == null
                              ? MedalTier.gold.label(l10n)
                              : next.$1.label(l10n),
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
                      TextSpan(text: l10n.medalGoalPoints(goal)),
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
                          Text(tier.label(l10n),
                              style: t.textTheme.labelSmall
                                  ?.withWeight(FontWeight.w800)
                                  .copyWith(color: scheme.onSurface)),
                          const SizedBox(height: 2),
                          Text(l10n.medalThresholdPoints(v),
                              key: thresholdKey(tier),
                              style: small?.copyWith(color: muted)),
                        ]),
                  ]),
              ],
            ),
            const SizedBox(height: 14),
            Text(l10n.medalMonthlyTotal(p.score, p.maxScore),
                key: totalKey, style: small?.copyWith(color: muted)),
          ]),
        ),
      ),
    );
  }
}
