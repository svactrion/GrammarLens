import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme.dart';

/// A ring that fills to [value] (0–1) around a centre label (X05's "4/5",
/// R02's question count, V10's result, the score capsule's tier progress).
/// The fill animates from 0 (or the previous value) in [duration].
class ScoreRing extends StatelessWidget {
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? center;
  final Duration duration;

  /// The ring's own value as VoiceOver reads it, or null to read [center].
  final String? semanticLabel;

  const ScoreRing({
    super.key,
    required this.value,
    required this.color,
    required this.track,
    this.size = 100,
    this.stroke = 12,
    this.center,
    this.duration = const Duration(milliseconds: 600),
    this.semanticLabel,
  });

  /// The "4/5" label of a score ring, in the ring's own style.
  static Widget fraction(BuildContext context, int done, int total,
      {required Color color, double fontSize = 26}) {
    return Text(
      '$done/$total', // l10n-guard: a fraction of numbers
      maxLines: 1,
      textScaler: TextScaler.noScaling,
      style: Theme.of(context)
          .textTheme
          .headlineSmall!
          .withWeight(FontWeight.w900)
          .copyWith(
              color: color,
              fontSize: fontSize,
              height: 1,
              fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: AppMotion.orInstant(context, duration),
      curve: AppMotion.enter,
      builder: (context, v, child) => CustomPaint(
        painter:
            _RingPainter(value: v, color: color, track: track, stroke: stroke),
        child: child,
      ),
      child: SizedBox(
        width: size,
        height: size,
        child: Center(child: center),
      ),
    );
    if (semanticLabel == null) return ring;
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: ring),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arc, 0, math.pi * 2, false, base);
    if (value <= 0) return;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arc, -math.pi / 2, math.pi * 2 * value, false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
