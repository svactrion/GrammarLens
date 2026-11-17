import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/medal_tier.dart';
import '../motion.dart';
import '../services/month_transition.dart';
import '../services/monthly_medal_rules.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'companion_view.dart';
import 'medal_badge.dart';
import 'monthly_climb/climb_route.dart';
import 'monthly_climb/climb_trail_table.dart' show climbImageAspect;
import 'monthly_climb/mountain_scene.dart';
import 'pressable_button.dart';

/// How the month card was closed (Batch 6, M6). The names are
/// `month_card_dismissed`'s `method` values (M19).
enum MonthCardDismissal {
  button('button'),

  /// A swipe down on the sheet. (The UI polish's full-screen recap has no
  /// sheet to swipe; kept for the event's vocabulary.)
  drag('drag'),

  /// Closed without the button: a tap outside the old sheet, or the
  /// system back on the full-screen recap.
  barrier('barrier');

  final String wireName;
  const MonthCardDismissal(this.wireName);
}

/// The month change (Batch 6, M3–M5, M12, M13, M15), as the UI polish's two
/// full-screen pages (SPEC §5.2): the finished month's recap (R04: its
/// mountain edge to edge with the trail's gold dots, steps, points and the
/// gap to the next medal, then a points bar that fills stop by stop through
/// the medal lines of [MonthlyMedalRules]) and the new month's mountain
/// (R04b: it rises into view, the flag pops, the companion drops onto the
/// start). A user with no finished climb last month (the fresh variant)
/// sees R04b only. Content only; [showMonthCard] opens it.
class MonthCardSheet extends StatefulWidget {
  final MonthCardData data;

  /// The user's avatar.
  final Avatar avatar;

  /// "Start climbing" on R04b: it only closes the card (M12).
  final VoidCallback onClose;

  const MonthCardSheet({
    super.key,
    required this.data,
    required this.avatar,
    required this.onClose,
  });

  static const contentKey = ValueKey('month_card_content');
  static const scrollKey = ValueKey('month_card_scroll');
  static const nearMissKey = ValueKey('month_card_near_miss');
  static const medalKey = ValueKey('month_card_medal');
  static const pointsBarKey = ValueKey('month_card_points_bar');
  static const seeNewMountainKey = ValueKey('month_card_see_new_mountain');
  static const newMountainKey = ValueKey('month_card_new_mountain');
  static const startClimbingKey = ValueKey('month_card_start_climbing');

  /// N30, N37 (the sheet's medal sizes, kept for the measuring tools): 112
  /// pt on screens 740 pt tall and up, 70 pt on 640–739 pt screens, 48 pt
  /// below. R04's medal sits beside the title at [headerMedal].
  static const medalDiscRegular = 112.0;
  static const medalDiscCompact = 70.0;
  static const medalDiscSmall = 48.0;
  static const headerMedal = 72.0;

  /// The screen heights where the disc steps down.
  static const compactBelow = 740.0;
  static const smallBelow = 640.0;

  static double? _discForTesting;

  /// Debug builds only: stands in for the chosen disc in measuring tools.
  /// Ignored in profile and release builds.
  static set debugMedalDiscOverride(double? value) => _discForTesting = value;

  /// The medal's disc on a screen [height] points tall.
  static double medalDiscFor(double height) {
    if (kDebugMode && _discForTesting != null) return _discForTesting!;
    if (height < smallBelow) return medalDiscSmall;
    if (height < compactBelow) return medalDiscCompact;
    return medalDiscRegular;
  }

  /// The near-miss line (M15): the gap as a number, no promise of days.
  static String nearMissText(int gap, String tier, AppLocalizations l10n) =>
      l10n.monthCardNearMiss(gap, tier);

  /// The bar's stops (R04): each medal line the month's score passed, then
  /// the score itself.
  static List<int> barStops(int year, int month, int score) => [
        for (final tier in MedalTier.values)
          if (score >= MonthlyMedalRules.threshold(year, month, tier) &&
              MonthlyMedalRules.threshold(year, month, tier) < score)
            MonthlyMedalRules.threshold(year, month, tier),
        score,
      ];

  @override
  State<MonthCardSheet> createState() => _MonthCardSheetState();
}

class _MonthCardSheetState extends State<MonthCardSheet> {
  late bool _newMountain = widget.data.variant == MonthCardVariant.fresh;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.orInstant(context, AppMotion.slow),
      child: _newMountain
          ? _NewMountain(
              key: MonthCardSheet.newMountainKey,
              data: widget.data,
              avatar: widget.avatar,
              onStart: widget.onClose,
            )
          : _Recap(
              key: MonthCardSheet.contentKey,
              data: widget.data,
              avatar: widget.avatar,
              onNext: () => setState(() => _newMountain = true),
            ),
    );
  }
}

/// R04: the finished month's recap.
class _Recap extends StatefulWidget {
  final MonthCardData data;
  final Avatar avatar;
  final VoidCallback onNext;
  const _Recap(
      {super.key,
      required this.data,
      required this.avatar,
      required this.onNext});

  @override
  State<_Recap> createState() => _RecapState();
}

class _RecapState extends State<_Recap> with TickerProviderStateMixin {
  /// One controller for the whole bar: a fill to each stop (500 ms) and a
  /// 250 ms pause with a jiggle after it.
  static const _fill = 500;
  static const _pause = 250;
  late final List<int> _stops = MonthCardSheet.barStops(
      widget.data.previousYear, widget.data.previousMonth, widget.data.score);
  late final AnimationController _bar = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_fill + _pause) * _stops.length));
  late final AnimationController _dots = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 60 * math.max(1, widget.data.steps)));
  int _stopsReached = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _bar.addListener(_onBar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _bar.value = 1;
      _dots.value = 1;
      _stopsReached = _stops.length;
    } else {
      _dots.forward();
      _bar.forward();
    }
  }

  int get _year => widget.data.previousYear;
  int get _month => widget.data.previousMonth;

  void _onBar() {
    final per = 1 / _stops.length;
    const share = _fill / (_fill + _pause);
    var n = 0;
    for (var i = 0; i < _stops.length; i++) {
      if (_bar.value >= per * i + per * share - 1e-9) n = i + 1;
    }
    if (n <= _stopsReached) return;
    final before = _stopsReached == 0 ? 0 : _stops[_stopsReached - 1];
    setState(() => _stopsReached = n);
    // Light at each stop; success where the month's own medal is reached.
    MedalTier? tierAt(int v) =>
        MonthlyMedalRules.tierFor(year: _year, month: _month, score: v);
    final highest = widget.data.tier;
    if (highest != null &&
        tierAt(_stops[n - 1]) == highest &&
        tierAt(before) != highest) {
      HapticMap.success();
    } else {
      HapticMap.light();
    }
  }

  @override
  void dispose() {
    _bar.dispose();
    _dots.dispose();
    super.dispose();
  }

  /// The bar's value (points) now, and the jiggle (0..1) at the stop.
  (double, double) _barNow() {
    final per = 1 / _stops.length;
    final t = _bar.value;
    final i = math.min((t / per).floor(), _stops.length - 1);
    final local = ((t - per * i) / per).clamp(0.0, 1.0);
    const fillShare = _fill / (_fill + _pause);
    final from = i == 0 ? 0.0 : _stops[i - 1].toDouble();
    final to = _stops[i].toDouble();
    if (local < fillShare) {
      return (
        from + (to - from) * AppMotion.enter.transform(local / fillShare),
        0
      );
    }
    final pause = (local - fillShare) / (1 - fillShare);
    return (to, math.sin(pause * math.pi));
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final data = widget.data;
    final shownValue = _stopsReached == 0 ? 0 : _stops[_stopsReached - 1];
    final shownTier = _stopsReached == 0
        ? null
        : MonthlyMedalRules.tierFor(
            year: _year, month: _month, score: shownValue);
    final month = monthName(data.previousMonth, l10n);
    final next = MonthlyMedalRules.nextTier(_year, _month, data.score);
    final height = MediaQuery.sizeOf(context).height;
    final sceneHeight = (height * .44).clamp(220.0, 392.0);
    final arrow = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    Widget stat(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(children: [
              Text(value,
                  style: theme.textTheme.titleLarge!
                      .withWeight(FontWeight.w900)
                      .copyWith(color: c.onNavy)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium!
                      .withWeight(FontWeight.w700)
                      .copyWith(color: c.onNavyMuted)),
            ]),
          ),
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.4,
          colors: [c.navy, c.navyDeep],
          stops: const [0, .6],
        ),
      ),
      child: SafeArea(
        child: Column(children: [
          Expanded(
            child: SingleChildScrollView(
              key: MonthCardSheet.scrollKey,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    SizedBox(
                      key: MonthCardSheet.medalKey,
                      width: MonthCardSheet.headerMedal,
                      height: MonthCardSheet.headerMedal,
                      child: shownTier == null
                          ? Icon(Icons.flag_rounded,
                              size: 40, color: c.onNavyMuted)
                          : AnimatedSwitcher(
                              duration:
                                  AppMotion.orInstant(context, AppMotion.base),
                              transitionBuilder: (child, a) => ScaleTransition(
                                  scale: CurvedAnimation(
                                      parent: a, curve: AppMotion.pop),
                                  child: child),
                              child: MedalBadge.monthly(
                                key: ValueKey(shownTier),
                                themeId: data.previousTheme.id,
                                tier: shownTier,
                                disc: MonthCardSheet.headerMedal,
                              ),
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.monthCardTitle(month).toUpperCase(),
                              style: theme.textTheme.labelMedium!
                                  .withWeight(FontWeight.w900)
                                  .copyWith(color: c.gold, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Semantics(
                            header: true,
                            child: Text(
                              data.tier == null
                                  ? l10n.monthRecapClimbed(
                                      data.previousTheme.title(l10n))
                                  : l10n.monthRecapTitle(data.tier!.label(l10n),
                                      data.previousTheme.title(l10n)),
                              style: theme.textTheme.headlineSmall!
                                  .withWeight(FontWeight.w900)
                                  .copyWith(color: c.onNavy, height: 1.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: sceneHeight,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(fit: StackFit.expand, children: [
                        AnimatedBuilder(
                          animation: _dots,
                          builder: (context, _) => MountainScene(
                            theme: data.previousTheme,
                            days: data.days,
                            avatar: widget.avatar,
                            avatarDay: data.steps.toDouble(),
                            avatarSize: 48,
                            avatarMood: CompanionMood.cheer,
                            trailPaint: 1,
                            overlay: (context, map) => CustomPaint(
                              painter: _StepDots(
                                map: map,
                                days: data.days,
                                steps: data.steps,
                                lit: _dots.value,
                                color: c.gold,
                                rim: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: 12,
                          top: 12,
                          child: _Chip(
                            text: l10n.monthRecapDays(data.steps, data.days),
                            background: Colors.white.withValues(alpha: .92),
                            foreground: c.text,
                          ),
                        ),
                        PositionedDirectional(
                          end: 12,
                          top: 12,
                          child: _Chip(
                            text: data.previousTheme.title(l10n),
                            background: c.navy.withValues(alpha: .85),
                            foreground: c.onNavy,
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    stat(
                        '${data.steps}', // l10n-guard: a count
                        l10n.monthCardSteps(data.steps)),
                    const SizedBox(width: 8),
                    stat(
                        '${data.score}', // l10n-guard: a count
                        l10n.medalPointsUnit(data.score)),
                    const SizedBox(width: 8),
                    next == null
                        ? stat(
                            '★', // l10n-guard: a symbol
                            l10n.capsuleTopTier)
                        : stat(
                            '${next.$2}', // l10n-guard: a count
                            l10n.monthRecapToTier(next.$1.label(l10n))),
                  ]),
                  const SizedBox(height: 18),
                  AnimatedBuilder(
                    animation: _bar,
                    builder: (context, _) {
                      final (value, jiggle) = _barNow();
                      return _PointsBar(
                        key: MonthCardSheet.pointsBarKey,
                        year: _year,
                        month: _month,
                        value: value,
                        score: data.score,
                        jiggle: jiggle,
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  if (data.nearMiss case (final tier, final gap))
                    Row(children: [
                      Image.asset('assets/ui/points_star.webp',
                          width: 22, height: 22, excludeFromSemantics: true),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            MonthCardSheet.nearMissText(
                                gap, tier.label(l10n), l10n),
                            key: MonthCardSheet.nearMissKey,
                            style: theme.textTheme.bodyMedium!
                                .withWeight(FontWeight.w800)
                                .copyWith(color: c.onNavy)),
                      ),
                    ]),
                  const SizedBox(height: 6),
                  Text(
                      l10n.monthCardNext(
                          monthName(data.month, l10n), data.theme.title(l10n)),
                      style: theme.textTheme.bodyMedium!
                          .copyWith(color: c.onNavyMuted)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: PressableButton(
              key: MonthCardSheet.seeNewMountainKey,
              label: l10n.monthRecapSeeNew,
              tone: ButtonTone.orange,
              trailingIcon: arrow,
              haptic: ButtonHaptic.medium,
              shine: true,
              onPressed: widget.onNext,
            ),
          ),
        ]),
      ),
    );
  }
}

/// The trail's gold dots, one per climbed step, lit [lit] of the way.
class _StepDots extends CustomPainter {
  final SceneMap map;
  final int days, steps;
  final double lit;
  final Color color, rim;
  _StepDots({
    required this.map,
    required this.days,
    required this.steps,
    required this.lit,
    required this.color,
    required this.rim,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final route = ClimbRoute(days.clamp(28, 31));
    final shown = (steps * lit).ceil();
    final r = map.scale * .012;
    for (var i = 1; i <= math.min(shown, steps); i++) {
      final p = map.toBox(route.pointAt(i.toDouble()));
      canvas.drawCircle(p, r + 1.5, Paint()..color = rim);
      canvas.drawCircle(p, r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_StepDots old) => old.lit != lit || old.map.box != map.box;
}

/// R04's points bar: the medal lines of [MonthlyMedalRules] with their
/// labels; the fill at [value]; a line glows (1.5×) once passed; the bar
/// jiggles (±3 px, ±1.2°) by [jiggle] at a stop.
class _PointsBar extends StatelessWidget {
  final int year, month;
  final double value;
  final int score;
  final double jiggle;
  const _PointsBar({
    super.key,
    required this.year,
    required this.month,
    required this.value,
    required this.score,
    required this.jiggle,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gold = MonthlyMedalRules.threshold(year, month, MedalTier.gold);
    // The bar runs a little past Gold so its line is not at the very end.
    final max = gold * 1.06;
    final label = theme.textTheme.labelSmall!
        .withWeight(FontWeight.w800)
        .copyWith(color: c.onNavyMuted);
    return Semantics(
      label: l10n.monthRecapBarSemantics(
          score,
          MonthlyMedalRules.threshold(year, month, MedalTier.bronze),
          MonthlyMedalRules.threshold(year, month, MedalTier.silver),
          gold),
      excludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, -3 * jiggle),
        child: Transform.rotate(
          angle: -1.2 * math.pi / 180 * jiggle,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            double x(num v) => (v / max).clamp(0.0, 1.0) * w;
            return SizedBox(
              height: 64,
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  left: 0,
                  right: 0,
                  top: 22,
                  height: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 22,
                  height: 12,
                  width: x(value),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [c.orange, c.gold]),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                for (final tier in MedalTier.values) ...[
                  Positioned(
                    left:
                        x(MonthlyMedalRules.threshold(year, month, tier)) - 1.5,
                    top: 17,
                    width: 3,
                    height: 22,
                    child: Transform.scale(
                      scaleY: value >=
                              MonthlyMedalRules.threshold(year, month, tier)
                          ? 1.5
                          : 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: value >=
                                  MonthlyMedalRules.threshold(year, month, tier)
                              ? c.gold
                              : Colors.white.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left:
                        x(MonthlyMedalRules.threshold(year, month, tier)) - 40,
                    width: 80,
                    top: 42,
                    child: Text(
                      l10n.monthRecapLine(tier.label(l10n),
                          MonthlyMedalRules.threshold(year, month, tier)),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: label,
                    ),
                  ),
                ],
                Positioned(
                  left: x(value) - 24,
                  width: 48,
                  top: 0,
                  child: Text(
                    '${value.round()}', // l10n-guard: a count
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelLarge!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.gold),
                  ),
                ),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

/// R04b: the new month's mountain rises into view (40 px + fade, 900 ms),
/// the flag pops 400 ms later, the companion drops onto the start and hops
/// twice.
class _NewMountain extends StatefulWidget {
  final MonthCardData data;
  final Avatar avatar;
  final VoidCallback onStart;
  const _NewMountain(
      {super.key,
      required this.data,
      required this.avatar,
      required this.onStart});

  @override
  State<_NewMountain> createState() => _NewMountainState();
}

class _NewMountainState extends State<_NewMountain>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2300);
  late final AnimationController _t =
      AnimationController(vsync: this, duration: _total);
  bool _started = false;
  bool _landed = false;

  double _at(int ms) => ms / _total.inMilliseconds;

  @override
  void initState() {
    super.initState();
    _t.addListener(() {
      if (!_landed && _t.value >= _at(1700)) {
        _landed = true;
        HapticMap.light();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      _landed = true;
      _t.value = 1;
    } else {
      _t.forward();
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  double _phase(double from, double to) =>
      ((_t.value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final data = widget.data;
    final days = DateTime(data.year, data.month + 1, 0).day;
    final arrow = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;
    final top = MediaQuery.paddingOf(context).top + 8;
    final width = MediaQuery.sizeOf(context).width;
    return ColoredBox(
      // The mountain's own sky behind it (the board), whole at the
      // screen's width.
      color: data.theme.paletteFor(theme.brightness).sky,
      child: Stack(fit: StackFit.expand, children: [
        Positioned(
          top: top,
          left: 0,
          width: width,
          height: width / climbImageAspect,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final rise = AppMotion.enter.transform(_phase(0, _at(900)));
              final flag = _phase(_at(1300), _at(1700));
              // The drop (1300–1700 ms), then two hops (1700–2300 ms).
              final drop = _phase(_at(1300), _at(1700));
              final hops = _phase(_at(1700), 1);
              final lift = drop < 1
                  ? (1 - Curves.easeIn.transform(drop)) * 160
                  : (math.sin(hops * 2 * math.pi).abs()) * 14 * (1 - hops * .4);
              return Opacity(
                opacity: rise,
                child: Transform.translate(
                  offset: Offset(0, 40 * (1 - rise)),
                  child: MountainScene(
                    theme: data.theme,
                    days: days,
                    avatar: _t.value >= _at(1300) ? widget.avatar : null,
                    avatarDay: 0,
                    avatarSize: 70,
                    avatarLift: lift,
                    avatarMood: CompanionMood.cheer,
                    flagPop: flag,
                  ),
                ),
              );
            },
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: lipCard(c, radius: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n
                        .monthNewEyebrow(
                            monthName(data.month, l10n), data.theme.title(l10n))
                        .toUpperCase(),
                    style: theme.textTheme.labelMedium!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.orangeDeep, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Semantics(
                    header: true,
                    child: Text(l10n.monthNewTitle,
                        style: theme.textTheme.headlineMedium!
                            .withWeight(FontWeight.w900)
                            .copyWith(color: c.text, height: 1.1)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.monthNewBody(
                      days,
                      MonthlyMedalRules.threshold(
                          data.year, data.month, MedalTier.bronze),
                      MonthlyMedalRules.threshold(
                          data.year, data.month, MedalTier.silver),
                      MonthlyMedalRules.threshold(
                          data.year, data.month, MedalTier.gold),
                    ),
                    style: theme.textTheme.bodyMedium!.copyWith(color: c.muted),
                  ),
                  const SizedBox(height: 16),
                  PressableButton(
                    key: MonthCardSheet.startClimbingKey,
                    label: l10n.monthNewStart,
                    tone: ButtonTone.navy,
                    trailingIcon: arrow,
                    haptic: ButtonHaptic.medium,
                    onPressed: widget.onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color background, foreground;
  const _Chip(
      {required this.text, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelMedium!
                .withWeight(FontWeight.w800)
                .copyWith(color: foreground)),
      );
}

/// Opens the month change full screen (R04, then R04b; R04b only for the
/// fresh variant) and completes with how it was closed: "Start climbing"
/// ([MonthCardDismissal.button]) or the system back
/// ([MonthCardDismissal.barrier]).
Future<MonthCardDismissal> showMonthCard(
  BuildContext context, {
  required MonthCardData data,
  required Avatar avatar,
}) async {
  final reduced = AppMotion.reduced(context);
  final result = await Navigator.of(context).push<MonthCardDismissal>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration:
          reduced ? AppMotion.fast : const Duration(milliseconds: 400),
      reverseTransitionDuration: AppMotion.base,
      pageBuilder: (routeContext, _, __) => Material(
        type: MaterialType.transparency,
        child: MonthCardSheet(
          data: data,
          avatar: avatar,
          onClose: () =>
              Navigator.of(routeContext).pop(MonthCardDismissal.button),
        ),
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
  return result ?? MonthCardDismissal.barrier;
}
