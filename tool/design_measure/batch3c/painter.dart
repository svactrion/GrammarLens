// Candidate painter. Landmarks are a copy of the product's _landmark
// (lib/widgets/monthly_climb/monthly_mountain.dart). Measuring code only.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:grammar_lens/models/climb_theme.dart';

import 'geometry.dart';
import 'placement.dart';

/// New layer tones, derived from Green Slope's palette so light and dark
/// follow the same rule: farther layers lean toward the sky (haze), the
/// shadow face is the palette's ridge color, ground in front leans toward
/// the ridge.
/// The darker of the palette's ink and sky: "toward dark" in both modes.
Color _dark(ClimbPalette p) =>
    p.ink.computeLuminance() < p.sky.computeLuminance() ? p.ink : p.sky;

Map<String, Color> tones(ClimbPalette p) => {
      'sky': p.sky,
      'far': Color.lerp(p.mountain, p.sky, .58)!,
      'mid': Color.lerp(p.mountain, p.sky, .32)!,
      'body': p.mountain,
      'shadow': p.ridge,
      'crease': Color.lerp(p.mountain, p.ridge, .45)!,
      'cap': p.stone,
      'hill': Color.lerp(p.mountain, p.ridge, .28)!,
      'plain': Color.lerp(p.mountain, p.ridge, .18)!,
      'pine': Color.lerp(p.ridge, _dark(p), .38)!,
      'trunk': Color.lerp(p.ridge, _dark(p), .7)!,
      'shrub': Color.lerp(p.mountain, p.ridge, .78)!,
    };

class CandidatePainter extends CustomPainter {
  final Candidate c;
  final int days;
  final int progress;
  final ClimbPalette palette;
  CandidatePainter(this.c, this.days, this.progress, this.palette);

  @override
  void paint(Canvas canvas, Size size) {
    final t = tones(palette);
    canvas.save();
    canvas.scale(size.width / sceneW);
    void poly(List<Offset> pts, Color color) =>
        canvas.drawPath(Path()..addPolygon(pts, true), Paint()..color = color);
    for (final (tone, pts) in c.backLayers) {
      poly(pts, t[tone]!);
    }
    poly(c.body, t['body']!);
    for (final (tone, pts) in c.faces) {
      poly(pts, t[tone]!);
    }
    for (final (tone, r) in c.foothills) {
      canvas.drawOval(r, Paint()..color = t[tone]!);
    }
    // Environment items behind the trail.
    for (final (kind, base) in placeEnvironment(c)) {
      canvas.save();
      canvas.translate(base.dx, base.dy);
      if (kind == 'pine') {
        _pine(canvas, t);
      } else {
        _shrub(canvas, t);
      }
      canvas.restore();
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        c.trail,
        stroke
          ..color = palette.ridge
          ..strokeWidth = 26);
    canvas.drawPath(
        c.trail,
        stroke
          ..color = palette.trail
          ..strokeWidth = 21);
    // Step pills turned with the trail (decision d).
    for (var d = 0; d <= days; d++) {
      final tan = c.tangentAt(c.metric.length * d / days);
      canvas.save();
      canvas.translate(tan.position.dx, tan.position.dy);
      canvas.rotate(math.atan2(tan.vector.dy, tan.vector.dx));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero, width: stepLen, height: stepWid),
              const Radius.circular(5.5)),
          Paint()..color = d <= progress ? palette.accent : palette.stone);
      canvas.restore();
    }
    for (final (day, o) in placeMarkers(c, days)) {
      if (o == null) continue;
      canvas.save();
      canvas.translate(o.dx, o.dy);
      _landmark(canvas, day ~/ 7 - 1);
      canvas.restore();
    }
    final s = c.summit;
    canvas.drawLine(
        s + const Offset(0, 1),
        s + const Offset(0, -36),
        stroke
          ..color = palette.ink
          ..strokeWidth = 2.5);
    poly([
      s + const Offset(1, -35),
      s + const Offset(26, -34),
      s + const Offset(19, -26),
      s + const Offset(26, -20),
      s + const Offset(1, -21)
    ], palette.accent);
    canvas.restore();
  }

  void _pine(Canvas canvas, Map<String, Color> t) {
    canvas.drawRect(
        const Rect.fromLTRB(-3, -12, 3, 0), Paint()..color = t['trunk']!);
    final p = Paint()..color = t['pine']!;
    for (final (top, w, h) in [
      (-58.0, 12.0, 22.0),
      (-46.0, 16.0, 24.0),
      (-32.0, 16.0, 22.0)
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(0, top)
            ..lineTo(w, top + h)
            ..lineTo(-w, top + h)
            ..close(),
          p);
    }
  }

  void _shrub(Canvas canvas, Map<String, Color> t) {
    final p = Paint()..color = t['shrub']!;
    canvas.drawOval(const Rect.fromLTRB(-22, -16, 2, 0), p);
    canvas.drawOval(const Rect.fromLTRB(-8, -22, 16, 0), p);
    canvas.drawOval(const Rect.fromLTRB(6, -14, 22, 0), p);
    // Wildflowers: a few accent dots with pale centers.
    for (final o in const [Offset(-14, -12), Offset(2, -17), Offset(13, -8)]) {
      canvas.drawCircle(o, 3, Paint()..color = palette.accent);
      canvas.drawCircle(o, 1.1, Paint()..color = palette.stone);
    }
  }

  void _landmark(Canvas canvas, int index) {
    final fill = Paint()..color = palette.stone;
    final line = Paint()
      ..color = palette.ridge
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawOval(const Rect.fromLTRB(-28, 7, 28, 20),
        Paint()..color = palette.ridge.withValues(alpha: .3));
    switch (index) {
      case 0:
        canvas.drawLine(const Offset(-13, 12), const Offset(12, 2), line);
        canvas.drawLine(const Offset(-12, 2), const Offset(13, 12), line);
        canvas.drawPath(
            Path()
              ..moveTo(1, -25)
              ..cubicTo(20, -8, 12, 14, -7, 7)
              ..cubicTo(-20, -1, -9, -13, -7, -13)
              ..quadraticBezierTo(-4, -5, 1, -25),
            fill..color = palette.accent);
      case 1:
        canvas.drawPath(
            Path()
              ..moveTo(-25, 12)
              ..lineTo(-6, -23)
              ..lineTo(30, 12)
              ..close(),
            fill..color = palette.accent);
        canvas.drawPath(
            Path()
              ..moveTo(-16, 12)
              ..lineTo(-6, -8)
              ..lineTo(3, 12)
              ..close(),
            fill..color = palette.ridge);
      case 2:
        canvas.drawRect(const Rect.fromLTRB(-21, -8, 22, 18), fill);
        canvas.drawPath(
            Path()
              ..moveTo(-28, -7)
              ..lineTo(0, -30)
              ..lineTo(30, -7)
              ..close(),
            Paint()..color = palette.ridge);
        canvas.drawRect(
            const Rect.fromLTRB(-5, 1, 5, 18), Paint()..color = palette.ridge);
        canvas.drawRect(const Rect.fromLTRB(-16, 0, -9, 8),
            Paint()..color = palette.accent);
        canvas.drawRect(
            const Rect.fromLTRB(11, 0, 18, 8), Paint()..color = palette.accent);
      case 3:
        canvas.drawRect(const Rect.fromLTRB(-27, 4, 28, 12), fill);
        for (final x in [-24.0, 0.0, 24.0]) {
          canvas.drawLine(Offset(x, 4), Offset(x, -12), line);
        }
        canvas.drawLine(const Offset(-24, -10), const Offset(24, -10), line);
        canvas.drawLine(const Offset(0, 3), const Offset(7, -16), line);
        canvas.drawLine(
            const Offset(7, -16),
            const Offset(20, -22),
            line
              ..color = palette.ink
              ..strokeWidth = 6);
    }
  }

  @override
  bool shouldRepaint(CandidatePainter old) => true;
}
