import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../spacing.dart';
import '../widgets/brand_mark.dart';

// Ambient background decoration for this screen only — not reused
// elsewhere, so (unlike BrandMark's glass/glint) these stay local rather
// than living in theme.dart.
const Color _kWarmAccent = Color(0xFFFFE7D1);

/// First screen a new install ever sees (PRD v2 §4). One job: say what this
/// app does in a sentence or two before asking for anything, then hand off
/// to onboarding. No sign-up, no account — see `first_launch_flow.dart`.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onGetStarted;

  const WelcomeScreen({super.key, required this.onGetStarted});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  static const _textsDuration = Duration(milliseconds: 1650);

  bool _reduceMotion = false;
  bool _initialized = false;

  AnimationController? _texts;
  Animation<double>? _titleProgress;
  Animation<double>? _subtitleProgress;
  Animation<double>? _ctaProgress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decide once, at mount, whether motion is allowed — not re-evaluated
    // reactively on every dependency change. Matches how the decorative
    // child widgets below each decide it once in their own initState.
    if (_initialized) return;
    _initialized = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) return; // no controller created at all
    final controller = AnimationController(
      vsync: this,
      duration: _textsDuration,
    );
    _texts = controller;
    _titleProgress = _staggered(controller, delay: 450, duration: 700);
    _subtitleProgress = _staggered(controller, delay: 700, duration: 700);
    _ctaProgress = _staggered(controller, delay: 950, duration: 700);
    controller.forward();
  }

  Animation<double> _staggered(
    AnimationController controller, {
    required int delay,
    required int duration,
  }) {
    final totalMs = _textsDuration.inMilliseconds;
    return CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay / totalMs,
        (delay + duration) / totalMs,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _texts?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final hPad = (size.width * 0.08).clamp(24.0, 40.0);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    // The decorative artwork below (mark, rings, background blobs, twinkle
    // dots) is specified against a 390x844 reference canvas; scaling it by
    // actual screen size keeps its proportions and placement consistent
    // across device sizes instead of hardcoding those reference pixels
    // outright. Body text is deliberately not scaled this way — text
    // sizing stays literal, same as everywhere else in the app.
    final sx = (size.width / 390).clamp(0.85, 1.3);
    final sy = (size.height / 844).clamp(0.85, 1.3);
    // Element *sizes* use the more restrictive of the two axes rather than
    // width alone — on a normal phone aspect ratio sx and sy track closely
    // and this changes nothing, but on an unusually short/wide viewport
    // (a landscape tablet, or flutter_test's default 800x600 surface)
    // sizing purely off width would blow the mark/box past what the
    // available height can actually fit, overflowing the column below.
    final elementScale = math.min(sx, sy);

    final markSize = 172.0 * elementScale;
    final markBoxSize = 200.0 * elementScale;
    final ringSize = 116.0 * elementScale;

    final titleProgress =
        _titleProgress ?? const AlwaysStoppedAnimation(1.0);
    final subtitleProgress =
        _subtitleProgress ?? const AlwaysStoppedAnimation(1.0);
    final ctaProgress = _ctaProgress ?? const AlwaysStoppedAnimation(1.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Ambient background decoration, painted behind the real content.
          _BackgroundBlob(
            size: 260 * elementScale,
            color: const Color.fromRGBO(255, 214, 168, 0.55),
            driftTo: Offset(28 * sx, -22 * sy),
            duration: const Duration(seconds: 14),
            reduceMotion: _reduceMotion,
            position: (child) =>
                Positioned(left: -70 * sx, top: 90 * sy, child: child),
          ),
          _BackgroundBlob(
            size: 300 * elementScale,
            color: const Color.fromRGBO(193, 68, 14, 0.38),
            driftTo: Offset(-24 * sx, 24 * sy),
            duration: const Duration(seconds: 18),
            reduceMotion: _reduceMotion,
            position: (child) =>
                Positioned(right: -80 * sx, bottom: 120 * sy, child: child),
          ),
          _TwinkleDot(
            size: 10 * elementScale,
            duration: const Duration(milliseconds: 4500),
            delay: Duration.zero,
            reduceMotion: _reduceMotion,
            position: (child) =>
                Positioned(left: 64 * sx, top: 190 * sy, child: child),
          ),
          _TwinkleDot(
            size: 7 * elementScale,
            duration: const Duration(milliseconds: 5500),
            delay: const Duration(milliseconds: 1200),
            reduceMotion: _reduceMotion,
            position: (child) =>
                Positioned(right: 56 * sx, top: 300 * sy, child: child),
          ),
          _TwinkleDot(
            size: 6 * elementScale,
            duration: const Duration(milliseconds: 6500),
            delay: const Duration(milliseconds: 2400),
            reduceMotion: _reduceMotion,
            position: (child) =>
                Positioned(left: 44 * sx, top: 430 * sy, child: child),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: hPad),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  SizedBox(
                    width: markBoxSize,
                    height: markBoxSize,
                    child: Stack(
                      alignment: Alignment.center,
                      // Scan rings expand well past this box's own bounds
                      // (up to ~1.85x their base size) — must not be
                      // clipped to it.
                      clipBehavior: Clip.none,
                      children: [
                        _ScanRing(
                          size: ringSize,
                          delay: const Duration(milliseconds: 1200),
                          reduceMotion: _reduceMotion,
                        ),
                        _ScanRing(
                          size: ringSize,
                          delay: const Duration(milliseconds: 2900),
                          reduceMotion: _reduceMotion,
                        ),
                        _AnimatedBrandMark(
                          size: markSize,
                          reduceMotion: _reduceMotion,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                  _FadeSlideIn(
                    progress: titleProgress,
                    child: Text(
                      'GrammarLens',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: appBarFg,
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.lg),
                  _FadeSlideIn(
                    progress: subtitleProgress,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        'Practice English grammar with instant, '
                        'plain-language feedback — no jargon, no judgment, '
                        'just what to fix and why.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: appBarFg),
                      ),
                    ),
                  ),
                  const Spacer(flex: 4),
                  _FadeSlideIn(
                    progress: ctaProgress,
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: widget.onGetStarted,
                        child: const Text('Get started'),
                      ),
                    ),
                  ),
                  const SizedBox(height: Spacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades a child in while sliding it up 16 logical pixels — the shared
/// shape behind the title/subtitle/CTA stagger. [progress] is expected to
/// already be curved/delayed (see `_WelcomeScreenState._staggered`) or to
/// be a stopped animation fixed at 1.0 (the reduced-motion case), so this
/// widget itself stays a plain, dumb renderer.
class _FadeSlideIn extends StatelessWidget {
  final Animation<double> progress;
  final Widget child;

  const _FadeSlideIn({required this.progress, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (context, child) {
          return Opacity(
            opacity: progress.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - progress.value) * 16),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// The brand mark's one-time entrance (fade + scale-up + un-rotate) and,
/// once that settles, a slow continuous "breathing" scale loop.
class _AnimatedBrandMark extends StatefulWidget {
  final double size;
  final bool reduceMotion;

  const _AnimatedBrandMark({required this.size, required this.reduceMotion});

  @override
  State<_AnimatedBrandMark> createState() => _AnimatedBrandMarkState();
}

class _AnimatedBrandMarkState extends State<_AnimatedBrandMark>
    with TickerProviderStateMixin {
  AnimationController? _entrance;
  AnimationController? _breathe;
  Animation<double>? _opacity;
  Animation<double>? _entranceScale;
  Animation<double>? _rotate;
  Animation<double>? _breatheScale;
  Timer? _breatheStartTimer;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) return;

    final entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _entrance = entrance;
    final entranceCurve = CurvedAnimation(
      parent: entrance,
      curve: const Cubic(0.2, 0.9, 0.25, 1.0),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(entranceCurve);
    _entranceScale =
        Tween<double>(begin: 0.86, end: 1.0).animate(entranceCurve);
    _rotate = Tween<double>(begin: -14 * math.pi / 180, end: 0)
        .animate(entranceCurve);

    final breathe = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _breathe = breathe;
    _breatheScale = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: breathe, curve: Curves.easeInOut),
    );
    // Starts after the entrance has already finished (900ms), so the two
    // never fight over the mark's scale.
    _breatheStartTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) breathe.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _breatheStartTimer?.cancel();
    _entrance?.dispose();
    _breathe?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mark = BrandMark(size: widget.size);
    if (widget.reduceMotion) return mark;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_entrance, _breathe]),
        builder: (context, child) {
          return Opacity(
            opacity: _opacity!.value,
            child: Transform.rotate(
              angle: _rotate!.value,
              child: Transform.scale(
                scale: _entranceScale!.value * _breatheScale!.value,
                child: child,
              ),
            ),
          );
        },
        child: mark,
      ),
    );
  }
}

/// One expanding, fading "sonar ping" ring — a plain circle outline that
/// grows and disappears, then repeats. Two instances at staggered delays
/// give the impression of ripples emanating from the brand mark.
class _ScanRing extends StatefulWidget {
  final double size;
  final Duration delay;
  final bool reduceMotion;

  const _ScanRing({
    required this.size,
    required this.delay,
    required this.reduceMotion,
  });

  @override
  State<_ScanRing> createState() => _ScanRingState();
}

class _ScanRingState extends State<_ScanRing>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _scale;
  Animation<double>? _opacity;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) return;
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    _controller = controller;
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.62, end: 1.85).animate(curved);
    _opacity = Tween<double>(begin: 0.5, end: 0).animate(curved);
    _startTimer = Timer(widget.delay, () {
      if (mounted) controller.repeat();
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A frozen mid-ping ring would read as a rendering glitch rather than
    // a deliberate state, unlike the mark/texts (which have an obvious
    // "fully shown" rest frame) — so under reduced motion this ripple
    // simply isn't shown at all, with no controller ever created.
    if (widget.reduceMotion) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller!,
        builder: (context, _) {
          return Opacity(
            opacity: _opacity!.value,
            child: Transform.scale(
              scale: _scale!.value,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kWarmAccent, width: 2),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A soft, slowly-drifting radial-gradient glow used as full-bleed
/// background ambiance. [position] wraps the visual in the `Positioned`
/// that anchors it (left/top or right/bottom, per instance).
class _BackgroundBlob extends StatefulWidget {
  final double size;
  final Color color;
  final Offset driftTo;
  final Duration duration;
  final bool reduceMotion;
  final Widget Function(Widget child) position;

  const _BackgroundBlob({
    required this.size,
    required this.color,
    required this.driftTo,
    required this.duration,
    required this.reduceMotion,
    required this.position,
  });

  @override
  State<_BackgroundBlob> createState() => _BackgroundBlobState();
}

class _BackgroundBlobState extends State<_BackgroundBlob>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<Offset>? _offset;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) return;
    final controller =
        AnimationController(vsync: this, duration: widget.duration);
    _controller = controller;
    // No curve given in the spec for this drift — easeInOut for a smooth,
    // non-mechanical back-and-forth, matching the breathing mark's curve.
    _offset = Tween<Offset>(begin: Offset.zero, end: widget.driftTo).animate(
      CurvedAnimation(parent: controller, curve: Curves.easeInOut),
    );
    controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _glow(Offset offset) {
    return Transform.translate(
      offset: offset,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [widget.color, widget.color.withAlpha(0)],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      // A resting, non-drifting glow is a perfectly normal-looking static
      // background — no controller needed to show it at its base position.
      return widget.position(_glow(Offset.zero));
    }
    return widget.position(
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _offset!,
          builder: (context, _) => _glow(_offset!.value),
        ),
      ),
    );
  }
}

/// A small twinkling accent dot: opacity and scale breathe together on a
/// loop. [position] wraps the visual in the `Positioned` that anchors it.
class _TwinkleDot extends StatefulWidget {
  final double size;
  final Duration duration;
  final Duration delay;
  final bool reduceMotion;
  final Widget Function(Widget child) position;

  const _TwinkleDot({
    required this.size,
    required this.duration,
    required this.delay,
    required this.reduceMotion,
    required this.position,
  });

  @override
  State<_TwinkleDot> createState() => _TwinkleDotState();
}

class _TwinkleDotState extends State<_TwinkleDot>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _opacity;
  Animation<double>? _scale;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) return;
    final controller =
        AnimationController(vsync: this, duration: widget.duration);
    _controller = controller;
    // No curve given in the spec for this twinkle — easeInOut, same
    // reasoning as the background blobs above.
    final curved = CurvedAnimation(parent: controller, curve: Curves.easeInOut);
    _opacity = Tween<double>(begin: 0.2, end: 0.95).animate(curved);
    _scale = Tween<double>(begin: 0.85, end: 1.15).animate(curved);
    _startTimer = Timer(widget.delay, () {
      if (mounted) controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Widget _dot() => Container(
        width: widget.size,
        height: widget.size,
        decoration:
            const BoxDecoration(shape: BoxShape.circle, color: _kWarmAccent),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) {
      // A static dot at a fixed, comfortably-visible brightness reads as
      // an intentional accent rather than a broken animation.
      return widget.position(Opacity(opacity: 0.6, child: _dot()));
    }
    return widget.position(
      RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, _) => Opacity(
            opacity: _opacity!.value,
            child: Transform.scale(scale: _scale!.value, child: _dot()),
          ),
        ),
      ),
    );
  }
}
