import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../motion.dart';
import '../theme.dart';
import '../utils/haptics.dart';
import '../widgets/anchored_bubble.dart';
import '../widgets/companion_view.dart';
import '../widgets/monthly_climb/climb_route.dart';
import '../widgets/monthly_climb/climb_zoom.dart';
import '../widgets/monthly_climb/mountain_scene.dart';
import '../widgets/pressable_button.dart';

/// V12: the first step on the mountain, after the first Daily Test. One
/// camera on the whole mountain (cover framing: the image always fills the
/// screen, the wide shot fits its height and crops the sides): wide → 2.2×
/// close (1 s) → the companion walks to the step in 0.45 s hops while the
/// trail paints (2 s) → wide again (1 s). "Step N of D" pops on arrival;
/// the bubble and Continue appear once the camera has opened back up.
///
/// This is the first run's zoom (it takes the place of Home's in-card one,
/// PROGRESS.md D5-3): a tap during the camera jumps to its end; with Reduce
/// Motion the end frame fades in. [onCameraEnded] reports how it ended.
class FirstClimbScreen extends StatefulWidget {
  final ClimbTheme theme;
  final Avatar hero;
  final int days;

  /// The step reached (1 on the first day).
  final int step;
  final VoidCallback onContinue;
  final ValueChanged<ClimbZoomOutcome>? onCameraEnded;

  const FirstClimbScreen({
    super.key,
    required this.theme,
    required this.hero,
    required this.days,
    this.step = 1,
    required this.onContinue,
    this.onCameraEnded,
  });

  static const continueKey = ValueKey('first_climb_continue');
  static const sceneKey = ValueKey('first_climb_scene');

  /// The companion on the mountain (its box is the bubble's anchor).
  static const double avatarSize = 64;

  /// The camera's phases (SPEC §5.2 V12), after a short hold on the wide
  /// shot.
  static const hold = Duration(milliseconds: 300);
  static const zoomIn = Duration(milliseconds: 1000);
  static const walk = Duration(milliseconds: 2000);
  static const zoomOut = Duration(milliseconds: 1000);
  static Duration get total => hold + zoomIn + walk + zoomOut;

  /// The close shot's zoom over cover.
  static const closeZoom = 2.2;

  /// One hop of the walk.
  static const hop = Duration(milliseconds: 450);

  @override
  State<FirstClimbScreen> createState() => _FirstClimbScreenState();
}

class _FirstClimbScreenState extends State<FirstClimbScreen>
    with TickerProviderStateMixin {
  late final AnimationController _camera =
      AnimationController(vsync: this, duration: FirstClimbScreen.total);
  late final AnimationController _ending =
      AnimationController(vsync: this, duration: AppMotion.slow);
  bool _arrived = false;
  bool _started = false;
  bool _ended = false;

  /// V12 (v11): the bubble stays between the step chip and Continue;
  /// measured after layout.
  final _chipKey = GlobalKey();
  final _buttonKey = GlobalKey();
  double? _bubbleMinTop;
  double? _bubbleMaxBottom;

  void _measureBubbleLimits() {
    final chip = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    final button = _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (chip == null || button == null || !chip.hasSize || !button.hasSize) {
      return;
    }
    final minTop = chip.localToGlobal(Offset(0, chip.size.height)).dy + 8;
    final maxBottom = button.localToGlobal(Offset.zero).dy - 8;
    if (minTop != _bubbleMinTop || maxBottom != _bubbleMaxBottom) {
      setState(() {
        _bubbleMinTop = minTop;
        _bubbleMaxBottom = maxBottom;
      });
    }
  }

  double _at(Duration d) =>
      d.inMicroseconds / FirstClimbScreen.total.inMicroseconds;

  late final double _zoomInStart = _at(FirstClimbScreen.hold);
  late final double _walkStart =
      _at(FirstClimbScreen.hold + FirstClimbScreen.zoomIn);
  late final double _walkEnd = _at(
      FirstClimbScreen.hold + FirstClimbScreen.zoomIn + FirstClimbScreen.walk);

  @override
  void initState() {
    super.initState();
    _camera.addListener(_onTick);
    _camera.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _end(ClimbZoomOutcome.completed);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (AppMotion.reduced(context)) {
      // Reduce Motion: the end frame, faded in. (The outcome first: the
      // controller reaching its end reports "completed".)
      _end(ClimbZoomOutcome.reduceMotion);
      _camera.value = 1;
      _arrive(haptic: false);
    } else {
      _camera.forward();
    }
  }

  void _onTick() {
    if (!_arrived && _camera.value >= _walkEnd) _arrive();
  }

  void _arrive({bool haptic = true}) {
    _arrived = true;
    if (haptic) {
      HapticMap.light();
      HapticMap.success();
    }
    if (mounted) setState(() {});
  }

  void _end(ClimbZoomOutcome outcome) {
    if (_ended) return;
    _ended = true;
    widget.onCameraEnded?.call(outcome);
    _ending.forward();
    if (mounted) setState(() {});
  }

  /// A tap during the camera jumps to its end.
  void _skip() {
    if (_ended) return;
    _end(ClimbZoomOutcome.skipped);
    _camera.stop();
    _camera.value = 1;
    if (!_arrived) _arrive(haptic: false);
  }

  @override
  void dispose() {
    _camera.dispose();
    _ending.dispose();
    super.dispose();
  }

  double _phase(double t, double from, double to) =>
      ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final route = ClimbRoute(widget.days.clamp(28, 31));
    // The camera looks at the middle of the walk.
    final focus = Offset.lerp(route.pointAt(widget.step - 1.0),
        route.pointAt(widget.step.toDouble()), .5)!;
    final arrow = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;

    return Scaffold(
      backgroundColor: c.navyDeep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _ended ? null : _skip,
        excludeFromSemantics: true,
        child: Stack(fit: StackFit.expand, children: [
          AnimatedBuilder(
            key: FirstClimbScreen.sceneKey,
            animation: _camera,
            builder: (context, _) {
              final t = _camera.value;
              final zoomIn = Curves.easeInOut
                  .transform(_phase(t, _zoomInStart, _walkStart));
              final zoomOut =
                  Curves.easeInOut.transform(_phase(t, _walkEnd, 1));
              final zoom =
                  1 + (FirstClimbScreen.closeZoom - 1) * (zoomIn - zoomOut);
              final walk = _phase(t, _walkStart, _walkEnd);
              final walked = walk * FirstClimbScreen.walk.inMilliseconds;
              final hop = walk >= 1 || walk <= 0
                  ? 0.0
                  : math
                      .sin(math.pi *
                          (walked % FirstClimbScreen.hop.inMilliseconds) /
                          FirstClimbScreen.hop.inMilliseconds)
                      .abs();
              return MountainScene(
                theme: widget.theme,
                days: widget.days,
                avatar: widget.hero,
                avatarDay: widget.step - 1 + walk,
                avatarSize: FirstClimbScreen.avatarSize,
                avatarLift: hop * 10,
                avatarMood: _arrived ? CompanionMood.cheer : CompanionMood.idle,
                zoom: zoom,
                focus: focus,
                trailPaint: walk,
              );
            },
          ),
          // A soft shade at the top and bottom keeps the chips and the
          // button readable over any mountain.
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: .28),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: .34),
                  ],
                  stops: const [0, .22, .66, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: _Chip(
                      text: l10n.firstClimbMountain(
                          widget.theme.title(l10n), widget.days),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    key: _chipKey,
                    child: AnimatedScale(
                      scale: _arrived ? 1 : 0,
                      duration: AppMotion.orInstant(context, AppMotion.base),
                      curve: AppMotion.pop,
                      child: _Chip(
                        text: l10n.firstClimbStep(widget.step, widget.days),
                        icon: Icons.flag_rounded,
                        strong: true,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Continue at the bottom once the camera has opened back
                  // up (the bubble is placed over the scene, below).
                  _Ending(
                    key: _buttonKey,
                    animation: _ending,
                    child: IgnorePointer(
                      ignoring: !_ended,
                      child: PressableButton(
                        key: FirstClimbScreen.continueKey,
                        label: l10n.commonContinue,
                        tone: ButtonTone.orange,
                        trailingIcon: arrow,
                        haptic: ButtonHaptic.medium,
                        onPressed: widget.onContinue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // V12 (v11): the bubble right above the companion, its tail at
          // it, placed from where the wide shot shows it; once the camera
          // has opened back up.
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(builder: (context, box) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _measureBubbleLimits());
                final map = SceneMap(box.biggest, focus: focus);
                final p = map.toBox(route.pointAt(widget.step.toDouble()));
                const s = FirstClimbScreen.avatarSize;
                final padding = MediaQuery.paddingOf(context);
                return FadeTransition(
                  opacity: _ending,
                  child: AnimatedBuilder(
                    animation: _ending,
                    builder: (context, child) => Transform.translate(
                        offset: Offset(0, 8 * (1 - _ending.value)),
                        child: child),
                    child: AnchoredBubble(
                      anchor: Rect.fromLTWH(p.dx - s / 2, p.dy - s * .9, s, s),
                      text: l10n.firstClimbBubble(widget.days - widget.step),
                      minTop: _bubbleMinTop ?? padding.top + 120,
                      maxBottom: _bubbleMaxBottom ??
                          box.maxHeight - padding.bottom - 96,
                    ),
                  ),
                );
              }),
            ),
          ),
          // VoiceOver reads the scene as one line.
          Semantics(
            label: l10n.firstClimbSemantics(
                widget.hero.name(l10n), widget.step, widget.days),
            child: const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

/// Fades and slides [child] in with [animation].
class _Ending extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _Ending({super.key, required this.animation, required this.child});

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, .2), end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: AppMotion.enter)),
          child: child,
        ),
      );
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool strong;
  const _Chip({required this.text, this.icon, this.strong = false});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final style = Theme.of(context)
        .textTheme
        .labelLarge!
        .withWeight(FontWeight.w900)
        .copyWith(color: strong ? c.onOrange : c.text);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: strong ? c.gold : c.card,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
              color: strong ? c.goldDeep : c.lip, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: style.color),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(text,
              style: style, maxLines: 2, textAlign: TextAlign.center),
        ),
      ]),
    );
  }
}
