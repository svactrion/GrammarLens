import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import 'companion_view.dart';
import 'pressable_button.dart';

/// The buddy picker (V03 in onboarding, R06 from Profile; SPEC §1.3): the
/// B1 turntable — all nine heroes stand on a round stage; the front one
/// stands on the podium in its wave pose, full size; the others shrink with
/// depth. Dragging turns the whole ring (one hero = 40°), the ring follows
/// the finger and snaps to the nearest hero with a spring on release. The
/// background is the front hero's stage colour (300 ms).
///
/// Below: the name with ‹ › steps, three personality chips, a speech line,
/// dots and "n / 9"; the primary button ([primaryLabel] for the front hero)
/// and the secondary "Try my luck" with a small turning wheel.
class BuddyPicker extends StatefulWidget {
  final Avatar initial;
  final String title;
  final String subtitle;
  final String Function(Avatar hero) primaryLabel;
  final ValueChanged<Avatar> onConfirm;

  /// Opens the wheel; resolves to the hero to put in front (the wheel's
  /// result after "All buddies"), or null to leave the ring as it is.
  final Future<Avatar?> Function(Avatar front) onTryLuck;

  /// Onboarding's step dots (1 of [stepCount]), or null for none.
  final int? step;
  final int stepCount;

  /// A widget at the top start (R06's back button).
  final Widget? leading;

  const BuddyPicker({
    super.key,
    required this.initial,
    required this.title,
    required this.subtitle,
    required this.primaryLabel,
    required this.onConfirm,
    required this.onTryLuck,
    this.step,
    this.stepCount = 4,
    this.leading,
  });

  static const confirmKey = ValueKey('buddy_confirm');
  static const tryLuckKey = ValueKey('buddy_try_luck');
  static const previousKey = ValueKey('buddy_previous');
  static const nextKey = ValueKey('buddy_next');
  static const ringKey = ValueKey('buddy_ring');

  /// One hero's share of the ring.
  static const double stepDegrees = 40;

  @override
  State<BuddyPicker> createState() => _BuddyPickerState();
}

class _BuddyPickerState extends State<BuddyPicker>
    with TickerProviderStateMixin {
  /// The ring's turn, in heroes (0 = Fox in front, 1 = Panda in front, …);
  /// fractional while dragging or snapping.
  late double _turn = widget.initial.order.toDouble();
  late final AnimationController _snap = AnimationController(vsync: this);
  late final AnimationController _arrive = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420));
  Animation<double>? _snapAnimation;
  int _lastTick = 0;

  int get _count => Avatar.values.length;

  Avatar get _front => Avatar.values[_frontIndex];

  int get _frontIndex => _turn.round() % _count;

  @override
  void initState() {
    super.initState();
    _lastTick = _turn.round();
    _snap.addListener(() {
      final a = _snapAnimation;
      if (a != null) _setTurn(a.value);
    });
    _arrive.value = 1;
  }

  @override
  void dispose() {
    _snap.dispose();
    _arrive.dispose();
    super.dispose();
  }

  void _setTurn(double value) {
    final before = _frontIndex;
    setState(() => _turn = value);
    final tick = value.round();
    if (tick != _lastTick) {
      _lastTick = tick;
      HapticMap.selection();
    }
    if (_frontIndex != before) {
      if (AppMotion.reduced(context)) {
        _arrive.value = 1;
      } else {
        _arrive.forward(from: 0);
      }
    }
  }

  void _snapTo(double target) {
    if (AppMotion.reduced(context)) {
      _setTurn(target);
      return;
    }
    _snapAnimation = Tween<double>(begin: _turn, end: target)
        .animate(CurvedAnimation(parent: _snap, curve: AppMotion.spring));
    _snap.duration = const Duration(milliseconds: 420);
    _snap.forward(from: 0);
  }

  void _step(int delta) {
    HapticMap.light();
    _snapTo(_turn.roundToDouble() + delta);
  }

  /// Puts [hero] in front by the shortest way round.
  void _bringToFront(Avatar hero) {
    final current = _turn.round();
    var diff = (hero.order - current) % _count;
    if (diff > _count / 2) diff -= _count;
    _snapTo((current + diff).toDouble());
  }

  double _dragFactor(BuildContext context) =>
      Directionality.of(context) == TextDirection.rtl ? -1 : 1;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final front = _front;
    final stage = AppColors.stageFor(front.order, brightness);
    final onStage = brightness == Brightness.dark ? c.text : c.onOrange;

    return AnimatedContainer(
      duration: AppMotion.orInstant(context, const Duration(milliseconds: 300)),
      color: stage,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (widget.step != null)
                    OnboardingStepDots(
                        step: widget.step!, count: widget.stepCount),
                  if (widget.leading != null)
                    PositionedDirectional(
                        start: 8, top: 0, bottom: 0, child: widget.leading!),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: onStage, letterSpacing: -.8),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium!
                        .withWeight(FontWeight.w700)
                        .copyWith(color: onStage.withValues(alpha: .6)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  key: BuddyPicker.ringKey,
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _snap.stop(),
                  onHorizontalDragUpdate: (d) => _setTurn(_turn +
                      _dragFactor(context) *
                          d.delta.dx /
                          (constraints.maxWidth * .28)),
                  onHorizontalDragEnd: (d) {
                    HapticMap.light();
                    final v = _dragFactor(context) *
                        (d.primaryVelocity ?? 0) /
                        (constraints.maxWidth * .28);
                    // A fling carries on to the next hero.
                    final target = (_turn + (v.abs() > 2 ? v.sign * .6 : 0))
                        .roundToDouble();
                    _snapTo(target);
                  },
                  child: _Turntable(
                    turn: _turn,
                    arrive: _arrive,
                    size: constraints.biggest,
                  ),
                ),
              ),
            ),
            _Identity(
              hero: front,
              color: onStage,
              onPrevious: () => _step(-1),
              onNext: () => _step(1),
            ),
            const SizedBox(height: 8),
            _Dots(index: front.order, count: _count, color: onStage),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Column(
                children: [
                  PressableButton(
                    key: BuddyPicker.confirmKey,
                    label: widget.primaryLabel(front),
                    tone: ButtonTone.navy,
                    shine: true,
                    trailingIcon:
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.arrow_back_rounded
                            : Icons.arrow_forward_rounded,
                    onPressed: () => widget.onConfirm(front),
                  ),
                  const SizedBox(height: 6),
                  PressableButton(
                    key: BuddyPicker.tryLuckKey,
                    label: l10n.buddyTryLuck,
                    tone: ButtonTone.outline,
                    height: 52,
                    haptic: ButtonHaptic.light,
                    leading: const MiniWheel(size: 26),
                    onPressed: () async {
                      final hero = await widget.onTryLuck(front);
                      if (hero != null && mounted) _bringToFront(hero);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The ring itself: every hero placed on an ellipse by its angle from the
/// front, sized by depth, drawn back to front; the podium and a soft ring.
class _Turntable extends StatelessWidget {
  final double turn;
  final Animation<double> arrive;
  final Size size;

  const _Turntable({
    required this.turn,
    required this.arrive,
    required this.size,
  });

  /// The size of a hero at [deg] degrees from the front (V03: 250 in
  /// front, 90 at 40°, 56 from 80° back), relative to a 390 pt board.
  static double sizeAt(double deg) {
    final a = deg.abs();
    if (a <= 40) return 250 - (250 - 90) * (a / 40);
    if (a <= 80) return 90 - (90 - 56) * ((a - 40) / 40);
    return 56;
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The board's geometry (390 × ~380 for this area) scaled to fit.
    final k = math.min(size.width / 390, size.height / 330).clamp(.6, 1.3);
    final cx = size.width / 2;
    // Feet on an ellipse: centre, radii (V03: 182 × 76 around y = 360 of the
    // board, the stage top at 268).
    final cy = size.height * .5 + 20 * k;
    final rx = 182 * k;
    final ry = 70 * k;
    final count = Avatar.values.length;
    final front = turn.round() % count;

    final entries = <({double depth, Widget child})>[];
    for (var i = 0; i < count; i++) {
      var deg = (i - turn) * BuddyPicker.stepDegrees;
      deg = ((deg + 180) % 360 + 360) % 360 - 180;
      final rad = deg * math.pi / 180;
      final side = rtl ? -1 : 1;
      final x = cx - side * rx * math.sin(rad);
      final feet = cy + ry * math.cos(rad);
      final s = sizeAt(deg) * k;
      final isFront = i == front && deg.abs() < 20;
      final hero = Avatar.values[i];
      entries.add((
        depth: math.cos(rad),
        child: Positioned(
          left: x - s / 2,
          top: feet - s * (isFront ? .9 : .97),
          width: s,
          height: s,
          child: isFront
              ? AnimatedBuilder(
                  animation: arrive,
                  builder: (context, child) => Transform.translate(
                    // Drops 8 px onto the podium.
                    offset: Offset(0,
                        -8 * k * (1 - Curves.easeOut.transform(arrive.value))),
                    child: child,
                  ),
                  child: CompanionView(
                    hero: hero,
                    mood: CompanionMood.wave,
                    size: s,
                    replay: front,
                  ),
                )
              : Opacity(
                  opacity: .9,
                  child: Image.asset(
                    hero.assetPath,
                    fit: BoxFit.contain,
                    semanticLabel: hero.name(context.l10n),
                    cacheWidth: 300,
                  ),
                ),
        ),
      ));
    }
    entries.sort((a, b) => a.depth.compareTo(b.depth));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The stage's rays.
        Positioned(
          left: cx - 240 * k,
          top: cy - 300 * k,
          width: 480 * k,
          height: 480 * k,
          child: const IgnorePointer(child: CustomPaint(painter: _StageRays())),
        ),
        // The round stage (an ellipse with a light rim).
        Positioned(
          left: cx - 192 * k,
          top: cy - 88 * k,
          width: 384 * k,
          height: 176 * k,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius:
                  BorderRadius.all(Radius.elliptical(192 * k, 88 * k)),
              gradient: RadialGradient(colors: [
                Colors.white.withValues(alpha: .65),
                Colors.white.withValues(alpha: .25),
              ]),
              border: Border.all(
                  color: Colors.white.withValues(alpha: .85), width: 3),
            ),
          ),
        ),
        for (final e in entries.where((e) => e.depth < .5)) e.child,
        // The podium under the front hero.
        Positioned(
          left: cx - 135 * k,
          top: cy + 24 * k,
          width: 270 * k,
          height: 101 * k,
          child: Image.asset('assets/ui/hero_podium.webp',
              fit: BoxFit.contain, excludeFromSemantics: true),
        ),
        for (final e in entries.where((e) => e.depth >= .5)) e.child,
      ],
    );
  }
}

class _StageRays extends CustomPainter {
  const _StageRays();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height * .62);
    final r = size.width / 2;
    final paint = Paint()
      ..shader = RadialGradient(colors: [
        Colors.white.withValues(alpha: .5),
        Colors.white.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: centre, radius: r));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      const w = .06;
      canvas.drawPath(
        Path()
          ..moveTo(centre.dx + 10 * math.cos(a - w),
              centre.dy + 10 * math.sin(a - w))
          ..lineTo(
              centre.dx + r * math.cos(a - w), centre.dy + r * math.sin(a - w))
          ..lineTo(
              centre.dx + r * math.cos(a + w), centre.dy + r * math.sin(a + w))
          ..lineTo(centre.dx + 10 * math.cos(a + w),
              centre.dy + 10 * math.sin(a + w))
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_StageRays old) => false;
}

/// The front hero's name with ‹ ›, its chips and its line.
class _Identity extends StatelessWidget {
  final Avatar hero;
  final Color color;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _Identity({
    required this.hero,
    required this.color,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final fade = AppMotion.orInstant(context, AppMotion.base);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: BuddyPicker.previousKey,
                tooltip: l10n.buddyPrevious,
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left_rounded,
                    color: color.withValues(alpha: .7)),
              ),
              Flexible(
                child: AnimatedSwitcher(
                  duration: fade,
                  child: Text(
                    hero.name(l10n),
                    key: ValueKey(hero),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.displaySmall!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: color, fontSize: 40, height: 1),
                  ),
                ),
              ),
              IconButton(
                key: BuddyPicker.nextKey,
                tooltip: l10n.buddyNext,
                onPressed: onNext,
                icon: Icon(Icons.chevron_right_rounded,
                    color: color.withValues(alpha: .7)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedSwitcher(
            duration: fade,
            child: Wrap(
              key: ValueKey(hero),
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final trait in hero.traits(l10n))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: c.card.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      trait,
                      style: theme.textTheme.labelMedium!
                          .withWeight(FontWeight.w800)
                          .copyWith(color: c.text, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.buddySpeech,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!
                .withWeight(FontWeight.w700)
                .copyWith(color: color.withValues(alpha: .85)),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int index;
  final int count;
  final Color color;
  const _Dots({required this.index, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.buddyPosition(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AppMotion.orInstant(context, AppMotion.fast),
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? color : color.withValues(alpha: .25),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            '${index + 1} / $count', // l10n-guard: a position in numbers
            style: Theme.of(context)
                .textTheme
                .labelMedium!
                .withWeight(FontWeight.w800)
                .copyWith(color: color.withValues(alpha: .7)),
          ),
        ],
      ),
    );
  }
}

/// Onboarding's step dots: [count] dots, the [step]th (1-based) a wide
/// orange pill.
class OnboardingStepDots extends StatelessWidget {
  final int step;
  final int count;
  const OnboardingStepDots({super.key, required this.step, this.count = 4});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Semantics(
      label: context.l10n.onboardingStep(step, count),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= count; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == step ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == step ? c.orange : c.track,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// The nine-colour wheel icon of "Try my luck"; turns slowly (6 s) as an
/// ambient loop.
class MiniWheel extends StatefulWidget {
  final double size;
  const MiniWheel({super.key, this.size = 26});

  @override
  State<MiniWheel> createState() => _MiniWheelState();
}

class _MiniWheelState extends State<MiniWheel>
    with SingleTickerProviderStateMixin {
  AnimationController? _turn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _turn == null) {
      _turn =
          AnimationController(vsync: this, duration: const Duration(seconds: 6))
            ..repeat();
    }
  }

  @override
  void dispose() {
    _turn?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget wheel(double t) => Transform.rotate(
          angle: t * 2 * math.pi,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _MiniWheelPainter(rim: AppColors.of(context).card),
          ),
        );
    final turn = _turn;
    return ExcludeSemantics(
      child: turn == null
          ? wheel(0)
          : AnimatedBuilder(
              animation: turn, builder: (context, _) => wheel(turn.value)),
    );
  }
}

class _MiniWheelPainter extends CustomPainter {
  final Color rim;
  _MiniWheelPainter({required this.rim});

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: c, radius: r);
    const n = 9;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * 2 * math.pi / n, 2 * math.pi / n,
          true, Paint()..color = AppColors.wheelSlices[i]);
    }
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = rim);
    canvas.drawCircle(c, r * .28, Paint()..color = rim);
  }

  @override
  bool shouldRepaint(_MiniWheelPainter old) => old.rim != rim;
}
