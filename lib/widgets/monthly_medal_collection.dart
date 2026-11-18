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
/// Fix round 5 (SPEC V23 "Month progress card (v13)", board V23p; on the
/// device "Bronze 75" said nothing about where 75 is on the bar): "<Month>
/// progress" and "<mountain> · N active days" on the left; on the right the
/// points large with "/ 300" and the distance to the next medal ("66 to
/// Bronze", orange; "Gold reached", green). The bar runs 0–300, split into
/// four parts by gaps at the thresholds (75 / 150 / 225), the unfilled
/// parts tinted toward their medal (the last neutral), the orange fill
/// running through them. Over each gap stands that medal's image (the
/// shelf's) in a ring with a stem down to the gap — earned: full colour, a
/// green ring and a tick; not yet: muted, a grey ring — with its name and
/// points under the bar (an earned or the next medal's name darker). A navy
/// dot (light blue in dark) marks the points. The fill runs part by part
/// (200 ms each) and a medal passed pops and gets its tick; at once under
/// Reduce Motion. Every number comes from `MonthlyMedalRules` and the
/// progress, so no month's thresholds are assumed.
class MonthlyProgressCard extends StatefulWidget {
  final MonthlyMedalProgress progress;
  final ClimbTheme theme;

  const MonthlyProgressCard(
      {super.key, required this.progress, required this.theme});

  static const cardKey = ValueKey('medal_progress_card');

  /// The points and "/ 300" (top right), and the distance under them.
  static const pointsKey = ValueKey('medal_progress_points');
  static const distanceKey = ValueKey('medal_progress_distance');
  static const barKey = ValueKey('medal_progress_bar');
  static const dotKey = ValueKey('medal_progress_dot');
  static ValueKey<String> partKey(int i) => ValueKey('medal_progress_part_$i');
  static ValueKey<String> partFillKey(int i) =>
      ValueKey('medal_progress_part_fill_$i');
  static ValueKey<String> medalKey(MedalTier tier) =>
      ValueKey('medal_progress_medal_${tier.name}');
  static ValueKey<String> tickKey(MedalTier tier) =>
      ValueKey('medal_progress_tick_${tier.name}');
  static ValueKey<String> labelKey(MedalTier tier) =>
      ValueKey('medal_progress_label_${tier.name}');

  /// The board's bar: four parts, [barHeight] tall, [gap] apart at the
  /// thresholds; the medal rings ([ring] + [ringWidth]) on stems of
  /// [stem] over the gaps; the dot [dot] wide.
  static const parts = 4;
  static const barHeight = 14.0;
  static const gap = 4.0;
  static const ring = 34.0;
  static const ringWidth = 3.0;
  static const medal = 30.0;
  static const stem = 8.0;
  static const dot = 22.0;

  /// The fill's time per part (SPEC: 200 ms each).
  static const partDuration = Duration(milliseconds: 200);

  /// The thresholds of [progress]'s month, then its top score: the four
  /// parts' ends.
  static List<int> bounds(MonthlyMedalProgress progress) => [
        for (final tier in MedalTier.values)
          MonthlyMedalRules.threshold(progress.year, progress.month, tier),
        progress.maxScore,
      ];

  /// How full part [i] (0-based) is, 0–1, for [score].
  static double partFill(int i, int score, List<int> bounds) {
    final from = i == 0 ? 0 : bounds[i - 1];
    final to = bounds[i];
    if (to <= from) return score >= to ? 1 : 0;
    return ((score - from) / (to - from)).clamp(0.0, 1.0).toDouble();
  }

  /// The unfilled part's tint: toward its medal (bronze, silver, gold),
  /// the last neutral (board V23p).
  static Color tint(int part, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (part) {
      0 => dark ? AppColors.tintBronzeDark : AppColors.tintBronze,
      1 => dark ? AppColors.tintSilverDark : AppColors.tintSilver,
      2 => dark ? AppColors.tintGoldDark : AppColors.tintGold,
      _ => dark ? AppColors.tintRestDark : AppColors.tintRest,
    };
  }

  /// The distance line: "66 to Bronze", or "Gold reached" past the top
  /// medal.
  static String distance(MonthlyMedalProgress p, AppLocalizations l10n) {
    final next = MonthlyMedalRules.nextTier(p.year, p.month, p.score);
    if (next == null) return l10n.capsuleTopTier;
    final (tier, gap) = next;
    return l10n.capsuleToTier(gap, tier.label(l10n));
  }

  /// The bar's label for VoiceOver: "9 of 300 points; Bronze at 75,
  /// Silver at 150, Gold at 225".
  static String barSemantics(MonthlyMedalProgress p, AppLocalizations l10n) =>
      l10n.medalBarSemantics(
          p.score,
          p.maxScore,
          [
            for (final tier in MedalTier.values)
              l10n.medalBarThreshold(tier.label(l10n),
                  MonthlyMedalRules.threshold(p.year, p.month, tier)),
          ].join(l10n.listSeparator));

  @override
  State<MonthlyProgressCard> createState() => _MonthlyProgressCardState();
}

class _MonthlyProgressCardState extends State<MonthlyProgressCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fill = AnimationController(vsync: this);
  bool _started = false;

  /// The parts the fill runs through, plus one beat for the last medal's
  /// pop.
  int get _slots {
    final b = MonthlyProgressCard.bounds(widget.progress);
    var filled = 0;
    for (var i = 0; i < MonthlyProgressCard.parts; i++) {
      if (MonthlyProgressCard.partFill(i, widget.progress.score, b) > 0) {
        filled = i + 1;
      }
    }
    return filled + 1;
  }

  void _run({bool fromStart = true}) {
    if (AppMotion.reduced(context)) {
      _fill.value = 1;
      return;
    }
    _fill.duration = MonthlyProgressCard.partDuration * _slots;
    _fill.forward(from: fromStart ? 0 : _fill.value);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void didUpdateWidget(MonthlyProgressCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress.score != widget.progress.score) _run();
  }

  @override
  void dispose() {
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final c = AppColors.of(context);
    final p = widget.progress;
    final l10n = context.l10n;
    final month = monthName(p.month, l10n);
    final days = l10n.medalActiveDays(p.activeDays);
    final reached =
        MonthlyMedalRules.nextTier(p.year, p.month, p.score) == null;
    return Card(
      key: MonthlyProgressCard.cardKey,
      margin: EdgeInsets.zero,
      // VoiceOver reads the title, the line, the distance and the bar's
      // own label one by one (the points are in the bar's label).
      semanticContainer: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.medalProgressTitle(month),
                        style: t.textTheme.titleMedium!
                            .withWeight(FontWeight.w900)
                            .copyWith(color: c.text)),
                    const SizedBox(height: 2),
                    Text(l10n.medalThemeDays(widget.theme.title(l10n), days),
                        style: t.textTheme.labelMedium!
                            .withWeight(FontWeight.w600)
                            .copyWith(color: c.muted)),
                  ]),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              ExcludeSemantics(
                child: Text.rich(
                  key: MonthlyProgressCard.pointsKey,
                  TextSpan(children: [
                    TextSpan(
                        text: '${p.score}', // l10n-guard: a number
                        style: t.textTheme.headlineSmall!
                            .withWeight(FontWeight.w900)
                            .copyWith(
                                color: c.text,
                                height: 1,
                                fontFeatures: const [
                              FontFeature.tabularFigures()
                            ])),
                    TextSpan(
                        text: ' / ${p.maxScore}', // l10n-guard: numbers
                        style: t.textTheme.labelMedium!
                            .withWeight(FontWeight.w800)
                            .copyWith(color: c.muted)),
                  ]),
                  textDirection: TextDirection.ltr,
                ),
              ),
              const SizedBox(height: 2),
              Text(MonthlyProgressCard.distance(p, l10n),
                  key: MonthlyProgressCard.distanceKey,
                  textAlign: TextAlign.end,
                  style: t.textTheme.labelMedium!
                      .withWeight(FontWeight.w800)
                      .copyWith(color: reached ? c.greenText : c.orangeText)),
            ]),
          ]),
          const SizedBox(height: 4),
          Semantics(
            key: MonthlyProgressCard.barKey,
            image: true,
            label: MonthlyProgressCard.barSemantics(p, l10n),
            excludeSemantics: true,
            child: AnimatedBuilder(
              animation: _fill,
              builder: (context, _) => _MedalBar(
                  progress: p,
                  theme: widget.theme,
                  t: _fill.value,
                  slots: _slots),
            ),
          ),
        ]),
      ),
    );
  }
}

/// The bar with its medals, names and the dot ([MonthlyProgressCard]) at
/// the fill's time [t] (0–1 over [slots] beats of 200 ms).
class _MedalBar extends StatelessWidget {
  final MonthlyMedalProgress progress;
  final ClimbTheme theme;
  final double t;
  final int slots;
  const _MedalBar(
      {required this.progress,
      required this.theme,
      required this.t,
      required this.slots});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final p = progress;
    final bounds = MonthlyProgressCard.bounds(p);
    final max = p.maxScore <= 0 ? 1 : p.maxScore;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final brightness = th.brightness;
    final nameStyle = th.textTheme.labelMedium!.withWeight(FontWeight.w900);
    final pointsStyle = th.textTheme.labelSmall!.withWeight(FontWeight.w700);
    final scaler = MediaQuery.textScalerOf(context);
    final labelHeight = (scaler.scale(nameStyle.fontSize ?? 12) +
            scaler.scale(pointsStyle.fontSize ?? 11)) *
        1.2;
    // Rows: the medal rings (their outer edge at 0), the stems into the
    // gaps, the bar, then the names.
    const ringOuter =
        MonthlyProgressCard.ring + 2 * MonthlyProgressCard.ringWidth;
    const ringTop = MonthlyProgressCard.ringWidth;
    const barTop = ringTop +
        MonthlyProgressCard.ring +
        MonthlyProgressCard.stem -
        MonthlyProgressCard.ringWidth;
    const barMid = barTop + MonthlyProgressCard.barHeight / 2;
    const labelTop = barTop + MonthlyProgressCard.barHeight + 9;
    final next = MonthlyMedalRules.nextTier(p.year, p.month, p.score)?.$1;
    // The fill's beat: part i runs from beat i to beat i + 1.
    final beat = t * slots;
    double shownFill(int i) =>
        MonthlyProgressCard.partFill(i, p.score, bounds) *
        (beat - i).clamp(0.0, 1.0);
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth;
      double x(num score) {
        final v = score / max * width;
        return rtl ? width - v : v;
      }

      final children = <Widget>[];
      // The four parts: laid out left to right, then mirrored in Arabic.
      for (var i = 0; i < MonthlyProgressCard.parts; i++) {
        final first = i == 0;
        final last = i == MonthlyProgressCard.parts - 1;
        final from = first ? 0.0 : bounds[i - 1] / max * width;
        final to = last ? width : bounds[i] / max * width;
        final left = from + (first ? 0 : MonthlyProgressCard.gap / 2);
        final w =
            math.max(0.0, to - (last ? 0 : MonthlyProgressCard.gap / 2) - left);
        final start = rtl ? width - left - w : left;
        const outer = Radius.circular(MonthlyProgressCard.barHeight / 2);
        const inner = Radius.circular(2);
        final radius = BorderRadiusDirectional.horizontal(
          start: first ? outer : inner,
          end: last ? outer : inner,
        );
        children.add(Positioned(
          key: MonthlyProgressCard.partKey(i),
          left: start,
          top: barTop,
          width: w,
          height: MonthlyProgressCard.barHeight,
          child: ClipRRect(
            borderRadius: radius,
            child: ColoredBox(
              color: MonthlyProgressCard.tint(i, brightness),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  key: MonthlyProgressCard.partFillKey(i),
                  widthFactor: shownFill(i),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [c.orange, AppColors.fillLight],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
      }
      // The medals over the gaps, with their names and points under the
      // bar.
      for (final (i, tier) in MedalTier.values.indexed) {
        final at = x(bounds[i]);
        final earned = p.score >= bounds[i];
        // Passed by the fill: its part full on screen.
        final passed = earned && shownFill(i) >= 1;
        final pop = passed ? (beat - (i + 1)).clamp(0.0, 1.0) : 0.0;
        final scale = 1 + .18 * math.sin(math.pi * pop);
        final ringColor = passed ? c.green : c.line;
        children.add(Positioned(
          key: MonthlyProgressCard.medalKey(tier),
          left: at - ringOuter / 2,
          top: 0,
          width: ringOuter,
          height: barTop + MonthlyProgressCard.barHeight / 2,
          child: Column(children: [
            Transform.scale(
              scale: scale,
              child: Container(
                width: ringOuter,
                height: ringOuter,
                decoration: BoxDecoration(
                  color: c.card,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: ringColor, width: MonthlyProgressCard.ringWidth),
                ),
                child: Stack(clipBehavior: Clip.none, children: [
                  Center(
                    child: _MedalImage(
                        asset: MedalArt.monthly(theme.id, tier),
                        muted: !passed),
                  ),
                  if (passed)
                    PositionedDirectional(
                      key: MonthlyProgressCard.tickKey(tier),
                      end: -4 - MonthlyProgressCard.ringWidth,
                      bottom: -4 - MonthlyProgressCard.ringWidth,
                      child: Container(
                        width: 15,
                        height: 15,
                        decoration: BoxDecoration(
                          color: c.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.card, width: 2),
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 9, color: Colors.white),
                      ),
                    ),
                ]),
              ),
            ),
            Container(
                width: 2, height: MonthlyProgressCard.stem, color: ringColor),
          ]),
        ));
        final name = earned || tier == next;
        children.add(Positioned(
          key: MonthlyProgressCard.labelKey(tier),
          left: at - 40,
          top: labelTop,
          width: 80,
          child: Column(children: [
            Text(tier.label(l10n),
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: nameStyle.copyWith(
                    color: name ? c.text : c.muted, height: 1.15)),
            Text('${bounds[i]}', // l10n-guard: a number
                maxLines: 1,
                textAlign: TextAlign.center,
                style: pointsStyle.copyWith(color: c.muted, height: 1.15)),
          ]),
        ));
      }
      // The dot at the points (with the fill's front while it runs).
      var shown = 0.0;
      for (var i = 0; i < MonthlyProgressCard.parts; i++) {
        final from = i == 0 ? 0 : bounds[i - 1];
        shown += shownFill(i) * (bounds[i] - from);
      }
      final dotAt = x(shown.clamp(0, max));
      children.add(Positioned(
        key: MonthlyProgressCard.dotKey,
        left: dotAt - MonthlyProgressCard.dot / 2,
        top: barMid - MonthlyProgressCard.dot / 2,
        width: MonthlyProgressCard.dot,
        height: MonthlyProgressCard.dot,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: brightness == Brightness.dark ? c.navyText : c.navy,
            shape: BoxShape.circle,
            border: Border.all(color: c.card, width: 3),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x33000000), offset: Offset(0, 2), blurRadius: 4)
            ],
          ),
        ),
      ));
      return SizedBox(
        height: labelTop + labelHeight,
        child: Stack(clipBehavior: Clip.none, children: children),
      );
    });
  }
}

/// A medal's image in the progress card's ring: full colour once earned,
/// muted (less saturated, faded) before.
class _MedalImage extends StatelessWidget {
  final String asset;
  final bool muted;
  const _MedalImage({required this.asset, required this.muted});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(asset,
        width: MonthlyProgressCard.medal,
        height: MonthlyProgressCard.medal,
        fit: BoxFit.contain,
        excludeFromSemantics: true);
    if (!muted) return image;
    return Opacity(
      opacity: .55,
      child: ColorFiltered(colorFilter: _saturation(.6), child: image),
    );
  }

  /// A saturation matrix (CSS `saturate(s)`).
  static ColorFilter _saturation(double s) {
    const r = .2126, g = .7152, b = .0722;
    return ColorFilter.matrix([
      r + (1 - r) * s, g - g * s, b - b * s, 0, 0, //
      r - r * s, g + (1 - g) * s, b - b * s, 0, 0, //
      r - r * s, g - g * s, b + (1 - b) * s, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }
}
