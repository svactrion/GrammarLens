import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';
import 'confetti_burst.dart';
import 'medal_badge.dart';
import '../theme.dart';

/// The medal celebration (Batch 5, N15, N28): a layer over the Daily Test
/// result screen, opened the moment the test is saved, for a tier just
/// earned or the Welcome badge.
///
/// The screen darkens; the medal stands large in the middle, a soft glow
/// and slowly turning rays behind it in the tier's colour ([glowFor]); the
/// text sits under it in a light colour. It looks the same in light and
/// dark mode and uses no image but the medal. The confetti comes at the
/// opening; one tap anywhere closes it with a short shrink and fade, and
/// the results show. Under Reduce Motion: no confetti, no turning, no fade
/// in, and the close is a fade only.
///
/// The rays turn for [raysTurn] and then rest: an endless animation would
/// never let the screen settle (the idle-sway rejection, side tracks
/// "Trail and scene").
class MedalCelebration extends StatefulWidget {
  /// The medal (`MedalBadge`, a [disc]-point disc).
  final Widget medal;

  /// The glow's and the rays' colour ([glowFor]).
  final Color glow;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const MedalCelebration({
    super.key,
    required this.medal,
    required this.glow,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  /// The medal's disc in the layer (N28: large in the middle). Its canvas
  /// is 162 pt, 486 px at 3x, inside the 512 px assets (N23).
  static const disc = 144.0;

  static const closeHint = 'Tap to continue';

  /// The layer's fade (in and out) and its shrink on closing.
  static const fadeKey = ValueKey('medal_celebration_fade');
  static const scaleKey = ValueKey('medal_celebration_scale');

  /// N28: the glow and the rays: Gold gold, Silver silver, Bronze copper,
  /// Welcome orange (the brand's).
  static const gold = Color(0xFFFFC94A);
  static const silver = Color(0xFFDDE4EE);
  static const copper = Color(0xFFE08A52);
  static const welcomeOrange = Color(0xFFF0843A);

  static Color glowFor(MedalTier? tier) => switch (tier) {
        MedalTier.gold => gold,
        MedalTier.silver => silver,
        MedalTier.bronze => copper,
        null => welcomeOrange,
      };

  /// The darkened screen, the same in light and dark mode.
  static const scrim = Color(0xEB080A10);

  static const fadeIn = Duration(milliseconds: 200);
  static const close = Duration(milliseconds: 220);

  /// How long the rays turn, and how far (a sixth of a turn): slow, then
  /// still.
  static const raysTurn = Duration(seconds: 12);
  static const raysAngle = math.pi / 3;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  /// A tier's celebration (N15, N29): "{Tier} medal earned",
  /// "{Month} · {Theme}".
  static MedalCelebration tier({
    Key? key,
    required MedalTier tier,
    required ClimbTheme theme,
    required int month,
    required VoidCallback onClose,
  }) =>
      MedalCelebration(
        key: key,
        medal: MedalBadge.monthly(themeId: theme.id, tier: tier, disc: disc),
        glow: glowFor(tier),
        title: '${tier.label} medal earned',
        subtitle: '${_months[month - 1]} · ${theme.name}',
        onClose: onClose,
      );

  /// The Welcome badge's celebration, with the copy of the card it
  /// replaced, word for word: audience-neutral (no "first test" language),
  /// since a pre-existing v2 user earns the same badge on their first Daily
  /// Test after updating.
  static MedalCelebration welcome({Key? key, required VoidCallback onClose}) =>
      MedalCelebration(
        key: key,
        medal: const MedalBadge.welcome(disc: disc),
        glow: glowFor(null),
        title: 'Welcome to the climb',
        subtitle: "Answer at least one question a day to keep moving "
            "up this month's mountain.",
        onClose: onClose,
      );

  @override
  State<MedalCelebration> createState() => _MedalCelebrationState();
}

class _MedalCelebrationState extends State<MedalCelebration>
    with TickerProviderStateMixin {
  late final AnimationController _fade =
      AnimationController(vsync: this, duration: MedalCelebration.fadeIn);
  late final AnimationController _rays =
      AnimationController(vsync: this, duration: MedalCelebration.raysTurn);

  /// The close: 1 shown, 0 gone (a shrink and a fade; a fade only under
  /// Reduce Motion).
  ///
  /// Preserved under Reduce Motion: a fade is not motion, and Flutter would
  /// otherwise cut it to 5 % of its length there.
  late final AnimationController _out = AnimationController(
      vsync: this,
      duration: MedalCelebration.close,
      value: 1,
      animationBehavior: AnimationBehavior.preserve);
  final _medalKey = GlobalKey();
  Offset? _confettiFrom;
  bool _closed = false;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _fade.value = 1;
      _rays.stop();
    } else if (!_fade.isAnimating && _fade.value == 0) {
      _fade.forward();
      _rays.forward();
      // The confetti from the medal's centre, once it is laid out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = _medalKey.currentContext?.findRenderObject();
        final layer = context.findRenderObject();
        if (box is! RenderBox || layer is! RenderBox || !box.hasSize) return;
        setState(() => _confettiFrom = layer
            .globalToLocal(box.localToGlobal(box.size.center(Offset.zero))));
      });
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    _rays.dispose();
    _out.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _rays.stop();
    try {
      await _out.reverse().orCancel;
    } on TickerCanceled {
      return;
    }
    if (mounted) widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = _confettiFrom;
    final glow = widget.glow;
    return AnimatedBuilder(
      animation: Listenable.merge([_fade, _out]),
      builder: (context, child) {
        // The shrink: to 0.9 as it goes, none under Reduce Motion.
        final scale = _reduceMotion ? 1.0 : .9 + .1 * _out.value;
        return Opacity(
          key: MedalCelebration.fadeKey,
          opacity: _fade.value * _out.value,
          child: Transform.scale(
              key: MedalCelebration.scaleKey, scale: scale, child: child),
        );
      },
      child: Semantics(
        container: true,
        liveRegion: true,
        button: true,
        label: '${widget.title}. ${widget.subtitle}. '
            '${MedalCelebration.closeHint}.',
        onTap: _close,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: Material(
            color: MedalCelebration.scrim,
            child: Stack(children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  // On a short screen, or with very large system text, the
                  // whole group scales down rather than overflowing.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: MedalCelebration.disc * 2,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: MedalCelebration.disc * 2,
                            child:
                                Stack(alignment: Alignment.center, children: [
                              // The glow and the rays behind the medal.
                              Positioned.fill(
                                child: AnimatedBuilder(
                                  animation: _rays,
                                  builder: (context, _) => CustomPaint(
                                    painter: CelebrationRays(
                                        colour: glow,
                                        turn: Curves.easeOut
                                                .transform(_rays.value) *
                                            MedalCelebration.raysAngle),
                                  ),
                                ),
                              ),
                              KeyedSubtree(key: _medalKey, child: widget.medal),
                            ]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge
                                ?.withWeight(FontWeight.w800)
                                .copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.subtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.white.withValues(alpha: .86)),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            MedalCelebration.closeHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium
                                ?.withWeight(FontWeight.w700)
                                .copyWith(
                                    color: Colors.white.withValues(alpha: .6)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (from != null)
                ConfettiBurst(
                  origin: from,
                  colors: [glow, theme.colorScheme.primary, Colors.white],
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// N28: a soft glow and [rays] light wedges in [colour], turned by [turn]
/// radians, fading toward the edge. Painted, not an image.
class CelebrationRays extends CustomPainter {
  final Color colour;
  final double turn;
  static const rays = 12;

  const CelebrationRays({required this.colour, required this.turn});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: centre, radius: radius);
    canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            colour.withValues(alpha: .55),
            colour.withValues(alpha: .18),
            colour.withValues(alpha: 0),
          ], stops: const [
            0,
            .45,
            1
          ]).createShader(rect));
    final ray = Paint()
      ..shader = RadialGradient(colors: [
        colour.withValues(alpha: .38),
        colour.withValues(alpha: 0),
      ]).createShader(rect);
    const half = math.pi / rays / 2.4;
    for (var i = 0; i < rays; i++) {
      final a = turn + i * 2 * math.pi / rays;
      canvas.drawPath(
          Path()
            ..moveTo(centre.dx, centre.dy)
            ..lineTo(centre.dx + radius * math.cos(a - half),
                centre.dy + radius * math.sin(a - half))
            ..lineTo(centre.dx + radius * math.cos(a + half),
                centre.dy + radius * math.sin(a + half))
            ..close(),
          ray);
    }
  }

  @override
  bool shouldRepaint(CelebrationRays old) =>
      old.colour != colour || old.turn != turn;
}
