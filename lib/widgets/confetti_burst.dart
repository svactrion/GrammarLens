import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One piece of confetti: where it is thrown, how fast, and what it looks like.
/// Everything is fixed when the burst is built, so a burst is fully determined
/// by its seed (no randomness while it plays) and can be tested exactly.
class ConfettiParticle {
  /// Launch direction in radians (screen space: negative y is up).
  final double angle;

  /// Launch speed in logical pixels per second.
  final double speed;

  /// Side length (or diameter) in logical pixels.
  final double size;

  final double rotation;

  /// Radians per second.
  final double spin;

  /// Index into the burst's colors (taken modulo their count).
  final int colorIndex;
  final bool round;

  const ConfettiParticle({
    required this.angle,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.spin,
    required this.colorIndex,
    required this.round,
  });
}

/// A fan of [count] particles thrown upward and outward. The same [seed] always
/// gives the same fan.
List<ConfettiParticle> buildConfettiParticles({int count = 40, int seed = 1}) {
  final random = math.Random(seed);
  return List.generate(count, (i) {
    // Up and out: from 150 to 30 degrees above the horizontal.
    final angle = -math.pi * (1 / 6 + random.nextDouble() * 2 / 3);
    return ConfettiParticle(
      angle: angle,
      speed: 260 + random.nextDouble() * 280,
      size: 6 + random.nextDouble() * 5,
      rotation: random.nextDouble() * math.pi * 2,
      spin: (random.nextDouble() - 0.5) * 12,
      colorIndex: i,
      round: random.nextBool(),
    );
  });
}

/// Draws [particles] thrown from [origin] under gravity, fading out over the
/// last part of the burst. Repaints with [progress] (0 to 1 over [duration]).
class ConfettiPainter extends CustomPainter {
  static const double gravity = 900;

  /// Share of the burst after which pieces start to fade.
  static const double fadeStart = 0.6;

  final Animation<double> progress;
  final List<ConfettiParticle> particles;
  final List<Color> colors;
  final Offset origin;
  final Duration duration;

  ConfettiPainter({
    required this.progress,
    required this.particles,
    required this.colors,
    required this.origin,
    required this.duration,
  }) : super(repaint: progress);

  /// Where [particle] is [seconds] after launch.
  static Offset positionAt(
      ConfettiParticle particle, Offset origin, double seconds) {
    return Offset(
      origin.dx + math.cos(particle.angle) * particle.speed * seconds,
      origin.dy +
          math.sin(particle.angle) * particle.speed * seconds +
          0.5 * gravity * seconds * seconds,
    );
  }

  /// 1 while a piece is fully visible, falling to 0 at the end of the burst.
  static double opacityAt(double progress) {
    if (progress <= fadeStart) return 1;
    return (1 - (progress - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final seconds =
        t * duration.inMicroseconds / Duration.microsecondsPerSecond;
    final opacity = opacityAt(t);
    if (opacity <= 0 || colors.isEmpty) return;
    final paint = Paint();
    for (final particle in particles) {
      final position = positionAt(particle, origin, seconds);
      paint.color = colors[particle.colorIndex % colors.length]
          .withValues(alpha: opacity);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(particle.rotation + particle.spin * seconds);
      if (particle.round) {
        canvas.drawCircle(Offset.zero, particle.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: particle.size,
            height: particle.size * 0.6,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) =>
      old.progress != progress ||
      old.particles != particles ||
      old.colors != colors ||
      old.origin != origin;
}

/// A single confetti burst that plays once and then calls [onFinished]. Meant
/// to be shown in an [OverlayEntry] above a screen: it ignores pointer events,
/// is hidden from screen readers (it decorates a message that is announced
/// separately) and asks for nothing from the widgets under it. It does not
/// check reduced motion; whoever shows it must not show it then.
class ConfettiBurst extends StatefulWidget {
  /// About two seconds: long enough to read as a celebration, short enough not
  /// to sit over the results the user came to read.
  static const Duration duration = Duration(milliseconds: 1800);

  final Offset origin;
  final List<Color> colors;
  final int seed;
  final VoidCallback? onFinished;

  const ConfettiBurst({
    super.key,
    required this.origin,
    required this.colors,
    this.seed = 1,
    this.onFinished,
  });

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = buildConfettiParticles(seed: widget.seed);
    _controller =
        AnimationController(vsync: this, duration: ConfettiBurst.duration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onFinished?.call();
          })
          ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: ConfettiPainter(
                progress: _controller,
                particles: _particles,
                colors: widget.colors,
                origin: widget.origin,
                duration: ConfettiBurst.duration,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
