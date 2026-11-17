import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../utils/haptics.dart';
import 'companion_view.dart';
import 'pressable_button.dart';
import 'rays.dart';
import '../models/medal_tier.dart';
import 'confetti_burst.dart';
import 'medal_badge.dart';
import '../theme.dart';
import '../l10n/l10n.dart';

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

  /// The small line above the title (V11 "BADGE EARNED", R05 "BRONZE
  /// MEDAL"), in the tier's colour.
  final String? eyebrow;

  /// The companion that lifts the medal (V11, R05), in its cheer pose.
  final Avatar? hero;

  const MedalCelebration({
    super.key,
    required this.medal,
    required this.glow,
    required this.title,
    required this.subtitle,
    required this.onClose,
    this.eyebrow,
    this.hero,
  });

  static const continueKey = ValueKey('medal_celebration_continue');

  /// The medal's disc in the layer (N28: large in the middle). Its canvas
  /// is 162 pt, 486 px at 3x, inside the 512 px assets (N23).
  static const disc = 144.0;

  // The close hint under the medal: `medalTapToContinue`.

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

  /// A tier's celebration (N15, N29): "{Tier} medal earned",
  /// "{Month} · {Theme}".
  /// R05: the month's medal for [tier]; with [points], the title counts
  /// them ("75 points in November!") and [nextTier] / [nextAt] say what is
  /// next.
  static MedalCelebration tier({
    Key? key,
    required MedalTier tier,
    required ClimbTheme theme,
    required int month,
    required VoidCallback onClose,
    required AppLocalizations l10n,
    Avatar? hero,
    int? points,
    MedalTier? nextTier,
    int? nextAt,
  }) =>
      MedalCelebration(
        key: key,
        medal: MedalBadge.monthly(themeId: theme.id, tier: tier, disc: disc),
        glow: glowFor(tier),
        eyebrow: l10n.medalEyebrow(tier.label(l10n)).toUpperCase(),
        title: points == null
            ? l10n.medalEarnedTitle(tier.label(l10n))
            : l10n.medalPointsTitle(points, monthName(month, l10n)),
        subtitle: nextTier == null || nextAt == null
            ? l10n.medalMonthTheme(monthName(month, l10n), theme.title(l10n))
            : l10n.medalNextLine(
                nextTier.label(l10n), nextAt, theme.title(l10n)),
        hero: hero,
        onClose: onClose,
      );

  /// V11: the Welcome badge, lifted by the companion. The body keeps the
  /// card's audience-neutral copy (no "first test" language): a v2 user
  /// earns the same badge on their first Daily Test after updating.
  static MedalCelebration welcome(
          {Key? key,
          required VoidCallback onClose,
          required AppLocalizations l10n,
          Avatar? hero,
          String? name}) =>
      MedalCelebration(
        key: key,
        medal: const MedalBadge.welcome(disc: disc),
        glow: glowFor(null),
        eyebrow: l10n.badgeEarnedEyebrow,
        title: name == null || name.isEmpty
            ? l10n.medalWelcomeTitle
            : l10n.badgeWelcomeName(name),
        subtitle: l10n.medalWelcomeBody,
        hero: hero,
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
            '${context.l10n.medalTapToContinue}.',
        onTap: _close,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _close,
          child: Material(
            color: AppColors.of(context).navyDeep,
            child: Stack(children: [
              // V11 / R05: the navy page, the tier-coloured rays turning
              // (one turn per 40 s), the medal over the companion's head.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.of(context).navyDeep,
                        AppColors.of(context).navy,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.sizeOf(context).height * .08,
                child: Center(
                  child: Rays(
                    color: glow.withValues(alpha: .55),
                    size: MediaQuery.sizeOf(context).width * 1.4,
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Column(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: 320,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MedalPop(
                                  reduce: _reduceMotion,
                                  child: KeyedSubtree(
                                      key: _medalKey, child: widget.medal),
                                ),
                                if (widget.hero != null) ...[
                                  const SizedBox(height: 4),
                                  CompanionView(
                                    hero: widget.hero!,
                                    mood: CompanionMood.cheer,
                                    size: 132,
                                    showProp: false,
                                  ),
                                  Container(
                                    width: 150,
                                    height: 22,
                                    margin: const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: .22),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 22),
                                if (widget.eyebrow != null)
                                  Text(
                                    widget.eyebrow!,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelMedium!
                                        .withWeight(FontWeight.w900)
                                        .copyWith(
                                            color: glow, letterSpacing: 1.6),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.title,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineMedium!
                                      .withWeight(FontWeight.w900)
                                      .copyWith(
                                          color: Colors.white,
                                          letterSpacing: -.6),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  widget.subtitle,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyLarge!.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: .82)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PressableButton(
                        key: MedalCelebration.continueKey,
                        label: context.l10n.commonContinue,
                        tone: ButtonTone.outline,
                        haptic: ButtonHaptic.light,
                        onPressed: _close,
                      ),
                    ],
                  ),
                ),
              ),
              if (from != null)
                ConfettiBurst(
                  origin: from,
                  colors: [
                    glow,
                    AppColors.of(context).orange,
                    AppColors.of(context).gold,
                    Colors.white,
                  ],
                  length: const Duration(milliseconds: 2500),
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

/// The medal pops (0 → 1.12 → 1, 900 ms) and then floats (±4 px, 3 s); a
/// success haptic when it lands.
class _MedalPop extends StatefulWidget {
  final Widget child;
  final bool reduce;
  const _MedalPop({required this.child, required this.reduce});

  @override
  State<_MedalPop> createState() => _MedalPopState();
}

class _MedalPopState extends State<_MedalPop> with TickerProviderStateMixin {
  late final AnimationController _pop;
  AnimationController? _float;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    if (widget.reduce) {
      _pop.value = 1;
      HapticMap.success();
    } else {
      _pop.forward().whenComplete(() {
        if (mounted) HapticMap.success();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.loopsOn(context) && _float == null) {
      _float =
          AnimationController(vsync: this, duration: const Duration(seconds: 3))
            ..repeat();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    _float?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_pop, if (_float != null) _float!]),
      builder: (context, child) {
        final p = _pop.value;
        final scale = p < .65
            ? Curves.easeOut.transform(p / .65) * 1.12
            : 1.12 - .12 * Curves.easeInOut.transform((p - .65) / .35);
        final f = _float == null
            ? 0.0
            : -4 * (1 - math.cos(2 * math.pi * _float!.value)) / 2;
        return Transform.translate(
          offset: Offset(0, f),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}
