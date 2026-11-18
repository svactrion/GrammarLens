import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../widgets/companion_view.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/pressable_button.dart';
import '../widgets/rays.dart';

/// The wheel's pick (SPEC §1.3): a random hero that is never [current] and
/// never [previous] (the last spin's result). [random] is injectable for
/// tests.
Avatar pickLuckyHero({
  required Avatar current,
  Avatar? previous,
  math.Random? random,
}) {
  final pool = [
    for (final hero in Avatar.values)
      if (hero != current && hero != previous) hero,
  ];
  return pool[(random ?? math.Random()).nextInt(pool.length)];
}

/// What the wheel screen hands back: the landed hero, and whether the
/// primary button confirmed it ("Climb with …" / "Save …") or the user went
/// back to the turntable ("All buddies", the landed hero in front).
typedef LuckyWheelResult = ({Avatar hero, bool confirmed});

/// Opens the wheel from the bottom (400 ms).
Future<LuckyWheelResult?> openLuckyWheel(
  BuildContext context, {
  required Avatar current,
  required String Function(Avatar hero) primaryLabel,
  math.Random? random,
}) {
  final reduced = AppMotion.reduced(context);
  return Navigator.of(context).push<LuckyWheelResult>(PageRouteBuilder(
    transitionDuration: reduced ? AppMotion.fast : AppMotion.slow,
    reverseTransitionDuration: reduced ? AppMotion.fast : AppMotion.base,
    pageBuilder: (_, __, ___) => LuckyWheelScreen(
        current: current, primaryLabel: primaryLabel, random: random),
    transitionsBuilder: (context, animation, _, child) => reduced
        ? FadeTransition(opacity: animation, child: child)
        : SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.enter,
                    reverseCurve: AppMotion.exit)),
            child: child,
          ),
  ));
}

enum _Phase { ready, spinning, landed }

/// The wheel of fortune (V03b): nine slices in hero order with each base
/// image, a navy rim with 18 bulbs, a gold-ringed hub, an orange pointer.
/// Ready → Spin (2.4 s, 2–3 turns, easeOutCubic; the pointer ticks per
/// slice) → landed (the slice glows, the hero's cheer pose in the hub,
/// confetti, the hero's colour). Nothing is saved until the primary button.
class LuckyWheelScreen extends StatefulWidget {
  final Avatar current;
  final String Function(Avatar hero) primaryLabel;
  final math.Random? random;

  const LuckyWheelScreen({
    super.key,
    required this.current,
    required this.primaryLabel,
    this.random,
  });

  static const spinKey = ValueKey('wheel_spin');
  static const confirmKey = ValueKey('wheel_confirm');
  static const allBuddiesKey = ValueKey('wheel_all_buddies');
  static const spinDuration = Duration(milliseconds: 2400);

  @override
  State<LuckyWheelScreen> createState() => _LuckyWheelScreenState();
}

class _LuckyWheelScreenState extends State<LuckyWheelScreen>
    with TickerProviderStateMixin {
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: LuckyWheelScreen.spinDuration);
  late final AnimationController _open = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
  late final AnimationController _land = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
  _Phase _phase = _Phase.ready;
  Avatar? _result;
  Avatar? _previous;
  double _from = 0;
  double _to = 0;
  int _lastSlice = 0;
  int _confetti = 0;

  static const int _n = 9;
  static const double _slice = 2 * math.pi / _n;

  /// The wheel's angle (radians) right now.
  double get _angle =>
      _from + (_to - _from) * Curves.easeOutCubic.transform(_spin.value);

  @override
  void initState() {
    super.initState();
    _spin.addListener(_onSpinTick);
    _spin.addStatusListener((s) {
      if (s == AnimationStatus.completed) _onLanded();
    });
    // The wheel starts with the current buddy under the pointer.
    _from = _to = _angleFor(widget.current);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_open.value == 0) {
      if (AppMotion.reduced(context)) {
        _open.value = 1;
      } else {
        _open.forward();
      }
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _open.dispose();
    _land.dispose();
    super.dispose();
  }

  /// The wheel angle that puts [hero]'s slice centre under the top pointer.
  static double _angleFor(Avatar hero) => -hero.order * _slice;

  void _onSpinTick() {
    final slice = (-_angle / _slice).round();
    if (slice != _lastSlice) {
      _lastSlice = slice;
      HapticMap.selection();
    }
    setState(() {});
  }

  void _start() {
    final result = pickLuckyHero(
        current: widget.current, previous: _previous, random: widget.random);
    _previous = result;
    HapticMap.medium();
    final turns = 2 + (widget.random ?? math.Random()).nextInt(2);
    var target = _angleFor(result);
    // Always clockwise, 2–3 full turns.
    while (target < _angle + turns * 2 * math.pi) {
      target += 2 * math.pi;
    }
    setState(() {
      _phase = _Phase.spinning;
      _result = result;
      _from = _angle;
      _to = target;
      _lastSlice = (-_from / _slice).round();
    });
    if (AppMotion.reduced(context)) {
      _spin.value = 1;
      _onLanded();
    } else {
      _spin.forward(from: 0);
    }
  }

  void _onLanded() {
    if (_phase == _Phase.landed) return;
    HapticMap.success();
    setState(() {
      _phase = _Phase.landed;
      _confetti++;
    });
    if (AppMotion.reduced(context)) {
      _land.value = 1;
    } else {
      _land.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final landed = _phase == _Phase.landed ? _result : null;
    final bg =
        landed == null ? c.page : AppColors.stageFor(landed.order, brightness);
    final onBg = c.text;
    final title = switch (_phase) {
      _Phase.landed => l10n.wheelPicked(landed!.name(l10n)),
      _Phase.spinning => l10n.wheelSpinning,
      _Phase.ready => l10n.wheelReadyTitle,
    };
    final subtitle = switch (_phase) {
      _Phase.landed => l10n.wheelLandedSubtitle,
      _Phase.spinning => l10n.wheelSpinningSubtitle,
      _Phase.ready => l10n.wheelReadySubtitle,
    };
    final foot = switch (_phase) {
      _Phase.ready => l10n.wheelFootReady,
      _Phase.spinning => l10n.wheelFootSpinning,
      _Phase.landed => null,
    };

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedContainer(
        duration:
            AppMotion.orInstant(context, const Duration(milliseconds: 300)),
        color: bg,
        child: Stack(
          children: [
            if (landed != null)
              Positioned.fill(
                child: Center(
                  child: Rays(
                      color: Colors.white.withValues(alpha: .9), size: 640),
                ),
              ),
            SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.only(start: 16, top: 8),
                      child: _AllBuddies(
                        onTap: _phase == _Phase.spinning
                            ? null
                            : () => Navigator.of(context).pop<LuckyWheelResult>(
                                landed == null
                                    ? null
                                    : (hero: landed, confirmed: false)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: [
                      AnimatedSwitcher(
                        duration: AppMotion.orInstant(context, AppMotion.base),
                        child: Text(
                          title,
                          key: ValueKey(title),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium!
                              .withWeight(FontWeight.w900)
                              .copyWith(color: onBg, letterSpacing: -.8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium!
                            .withWeight(FontWeight.w700)
                            .copyWith(color: onBg.withValues(alpha: .6)),
                      ),
                    ]),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final size = math
                            .min(box.maxWidth - 34, box.maxHeight - 16)
                            .clamp(220.0, 400.0);
                        return Center(
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_open, _land]),
                            builder: (context, child) => Transform.scale(
                              scale: .9 +
                                  .1 * AppMotion.pop.transform(_open.value),
                              child: child,
                            ),
                            child: SizedBox.square(
                              dimension: size,
                              child: _Wheel(
                                angle: _angle,
                                spinning: _phase == _Phase.spinning,
                                landed: landed,
                                land: _land,
                                open: _open,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                    height: 40,
                    child: landed == null
                        ? null
                        : Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 6,
                            children: [
                              for (final t in landed.traits(l10n))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 11, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: c.card.withValues(alpha: .8),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(t,
                                      style: theme.textTheme.labelMedium!
                                          .withWeight(FontWeight.w800)
                                          .copyWith(
                                              color: c.text, fontSize: 13)),
                                ),
                            ],
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: landed == null
                        ? Column(children: [
                            PressableButton(
                              key: LuckyWheelScreen.spinKey,
                              label: _phase == _Phase.spinning
                                  ? l10n.wheelSpinning
                                  : l10n.wheelSpin,
                              tone: ButtonTone.orange,
                              haptic: ButtonHaptic.none,
                              onPressed:
                                  _phase == _Phase.spinning ? null : _start,
                            ),
                            if (foot != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  foot,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.labelMedium!
                                      .withWeight(FontWeight.w700)
                                      .copyWith(color: c.muted),
                                ),
                              ),
                          ])
                        : Column(children: [
                            PressableButton(
                              key: LuckyWheelScreen.confirmKey,
                              label: widget.primaryLabel(landed),
                              tone: ButtonTone.navy,
                              shine: true,
                              trailingIcon: Directionality.of(context) ==
                                      TextDirection.rtl
                                  ? Icons.arrow_back_rounded
                                  : Icons.arrow_forward_rounded,
                              onPressed: () => Navigator.of(context)
                                  .pop<LuckyWheelResult>(
                                      (hero: landed, confirmed: true)),
                            ),
                            const SizedBox(height: 6),
                            PressableButton(
                              key: LuckyWheelScreen.spinKey,
                              label: l10n.wheelSpinAgain,
                              tone: ButtonTone.outline,
                              height: 52,
                              haptic: ButtonHaptic.none,
                              leading: const _WheelGlyph(),
                              onPressed: _start,
                            ),
                          ]),
                  ),
                ],
              ),
            ),
            if (_confetti > 0 && !AppMotion.reduced(context))
              ConfettiBurst(
                key: ValueKey(_confetti),
                origin: Offset(MediaQuery.sizeOf(context).width / 2,
                    MediaQuery.sizeOf(context).height * .42),
                colors: AppColors.wheelSlices,
                length: const Duration(milliseconds: 1500),
                count: 30,
              ),
          ],
        ),
      ),
    );
  }
}

class _WheelGlyph extends StatelessWidget {
  const _WheelGlyph();

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: 26,
        child: CustomPaint(
            painter: _SlicesPainter(rim: AppColors.of(context).card)),
      );
}

class _SlicesPainter extends CustomPainter {
  final Color rim;
  _SlicesPainter({required this.rim});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final centre = size.center(Offset.zero);
    for (var i = 0; i < 9; i++) {
      canvas.drawArc(
          Rect.fromCircle(center: centre, radius: r),
          -math.pi / 2 + i * 2 * math.pi / 9,
          2 * math.pi / 9,
          true,
          Paint()..color = AppColors.wheelSlices[i]);
    }
    canvas.drawCircle(centre, r * .28, Paint()..color = rim);
  }

  @override
  bool shouldRepaint(_SlicesPainter old) => old.rim != rim;
}

class _AllBuddies extends StatelessWidget {
  final VoidCallback? onTap;
  const _AllBuddies({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      button: true,
      label: context.l10n.wheelAllBuddies,
      excludeSemantics: true,
      child: GestureDetector(
        key: LuckyWheelScreen.allBuddiesKey,
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 14, 0),
          decoration: BoxDecoration(
            color: c.card.withValues(alpha: .8),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: c.text),
            const SizedBox(width: 2),
            Text(context.l10n.wheelAllBuddies,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge!
                    .withWeight(FontWeight.w800)
                    .copyWith(color: c.text)),
          ]),
        ),
      ),
    );
  }
}

/// The wheel: rim with bulbs, slices with each hero, the hub, the pointer.
class _Wheel extends StatelessWidget {
  final double angle;
  final bool spinning;
  final Avatar? landed;
  final Animation<double> land;
  final Animation<double> open;

  const _Wheel({
    required this.angle,
    required this.spinning,
    required this.landed,
    required this.land,
    required this.open,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(builder: (context, box) {
      final size = box.maxWidth;
      final k = size / 356;
      final centre = size / 2;
      const n = 9;
      const slice = 2 * math.pi / n;
      final heroes = <Widget>[];
      for (var i = 0; i < n; i++) {
        final a = angle + i * slice - math.pi / 2;
        final r = 110 * k;
        final s = 52 * k;
        heroes.add(Positioned(
          left: centre + r * math.cos(a) - s / 2,
          top: centre + r * math.sin(a) - s / 2,
          width: s,
          height: s,
          child: Container(
            decoration: BoxDecoration(
              color: c.card.withValues(alpha: .9),
              shape: BoxShape.circle,
            ),
            padding: EdgeInsets.all(3 * k),
            child: Image.asset(Avatar.values[i].assetPath,
                excludeFromSemantics: true, cacheWidth: 160),
          ),
        ));
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: Listenable.merge([land, open]),
              builder: (context, _) => CustomPaint(
                painter: _WheelPainter(
                  angle: angle,
                  rim: c.navy,
                  rimLip: c.navyDeep,
                  bulb: c.gold,
                  bulbOff: c.card,
                  stroke: c.card,
                  winner: landed?.order,
                  glow: land.value,
                  blink: spinning,
                  lights: open.value,
                ),
              ),
            ),
          ),
          // The slices' heroes, blurred while the wheel spins fast.
          ...spinning
              ? [
                  Positioned.fill(
                    child: ImageFiltered(
                      imageFilter: _blur,
                      child: Stack(clipBehavior: Clip.none, children: heroes),
                    ),
                  ),
                ]
              : heroes,
          // The hub.
          Center(
            child: Container(
              width: 112 * k,
              height: 112 * k,
              decoration: BoxDecoration(
                color: c.card,
                shape: BoxShape.circle,
                border: Border.all(color: c.gold, width: 7 * k),
              ),
              alignment: Alignment.center,
              child: landed == null
                  ? Text('?', // l10n-guard: the hub's mark
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.navy, fontSize: 44 * k))
                  : AnimatedBuilder(
                      animation: land,
                      builder: (context, child) => Transform.scale(
                        scale: AppMotion.pop.transform(land.value),
                        child: child,
                      ),
                      child: CompanionView(
                        hero: landed!,
                        mood: CompanionMood.cheer,
                        size: 92 * k,
                      ),
                    ),
            ),
          ),
          // The pointer at the top.
          Positioned(
            top: -14 * k,
            left: centre - 20 * k,
            width: 40 * k,
            height: 48 * k,
            child: CustomPaint(
              painter: _PointerPainter(
                fill: c.orange,
                ring: c.card,
                // Ticks back a little as each slice passes.
                tick: spinning ? ((angle / slice) % 1.0) : 0,
              ),
            ),
          ),
        ],
      );
    });
  }

  static final _blur = ui.ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6);
}

class _WheelPainter extends CustomPainter {
  final double angle;
  final Color rim;
  final Color rimLip;
  final Color bulb;
  final Color bulbOff;
  final Color stroke;
  final int? winner;
  final double glow;
  final bool blink;
  final double lights;

  _WheelPainter({
    required this.angle,
    required this.rim,
    required this.rimLip,
    required this.bulb,
    required this.bulbOff,
    required this.stroke,
    required this.winner,
    required this.glow,
    required this.blink,
    required this.lights,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 356;
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    canvas.drawCircle(c.translate(0, 8 * k), outer, Paint()..color = rimLip);
    canvas.drawCircle(c, outer, Paint()..color = rim);
    final r = 158 * k;
    const n = 9;
    const slice = 2 * math.pi / n;
    final rect = Rect.fromCircle(center: c, radius: r);
    for (var i = 0; i < n; i++) {
      final start = angle + i * slice - math.pi / 2 - slice / 2;
      final isWinner = winner == i;
      final base = AppColors.wheelSlices[i];
      final color =
          winner == null || isWinner ? base : base.withValues(alpha: .7);
      canvas.drawArc(rect, start, slice, true, Paint()..color = color);
      canvas.drawArc(
          rect,
          start,
          slice,
          true,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * k);
      if (isWinner && glow > 0) {
        canvas.drawArc(
            rect.inflate(2 * k),
            start,
            slice,
            true,
            Paint()
              ..color = Colors.white.withValues(alpha: .35 * glow)
              ..maskFilter = MaskFilter.blur(BlurStyle.outer, 10 * k));
      }
    }
    // 18 bulbs on the rim; while spinning every other one blinks.
    for (var i = 0; i < 18; i++) {
      final a = i * 2 * math.pi / 18 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * (outer - 10 * k);
      final lit =
          (i / 18) <= lights && (!blink || ((angle * 3).floor() + i).isEven);
      canvas.drawCircle(p, 5 * k, Paint()..color = lit ? bulb : bulbOff);
    }
  }

  @override
  bool shouldRepaint(_WheelPainter old) => true;
}

class _PointerPainter extends CustomPainter {
  final Color fill;
  final Color ring;
  final double tick;
  _PointerPainter({required this.fill, required this.ring, required this.tick});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.save();
    canvas.translate(w / 2, h * .3);
    canvas.rotate(-.25 * (1 - tick) * (tick > 0 ? 1 : 0));
    canvas.translate(-w / 2, -h * .3);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w / 2, h)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawCircle(Offset(w / 2, h * .3), w * .14, Paint()..color = ring);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PointerPainter old) =>
      old.tick != tick || old.fill != fill;
}
