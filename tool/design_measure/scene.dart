// A copy of 1.0's _MountainPainter (lib/widgets/monthly_climb/
// monthly_mountain.dart before Batch 3b) with the trail, steps, landmarks and
// summit taken from a Layout, so candidate geometries can be drawn without
// touching the product. The Batch 3b report's images were made with it.

import 'package:flutter/material.dart';
import 'package:grammar_lens/models/climb_theme.dart';

import 'geo.dart';

class StudyPainter extends CustomPainter {
  final Layout layout;
  final int days;
  final double progress;
  final ClimbPalette palette;
  final bool freeOverlay;
  final Rect? window; // the Home window, in scene units
  final Set<int> skipMarkers; // D2: marker indexes (0..3) not drawn
  StudyPainter(
      {required this.layout,
      required this.days,
      required this.progress,
      required this.palette,
      this.freeOverlay = false,
      this.window,
      this.skipMarkers = const {}});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320);
    void shape(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = color);
    }

    shape(const [
      Offset(-60, 740),
      Offset(0, 403),
      Offset(42, 264),
      Offset(88, 211),
      Offset(118, 128),
      Offset(162, 56),
      Offset(205, 138),
      Offset(226, 210),
      Offset(279, 286),
      Offset(340, 470),
      Offset(379, 740)
    ], palette.mountain);
    shape(const [
      Offset(162, 56),
      Offset(151, 177),
      Offset(181, 240),
      Offset(153, 347),
      Offset(180, 453),
      Offset(147, 560),
      Offset(189, 740),
      Offset(379, 740),
      Offset(340, 470),
      Offset(279, 286),
      Offset(226, 210),
      Offset(205, 138)
    ], palette.ridge);
    shape(const [
      Offset(162, 56),
      Offset(118, 128),
      Offset(103, 171),
      Offset(139, 149),
      Offset(158, 163),
      Offset(181, 143),
      Offset(211, 161),
      Offset(205, 138)
    ], palette.stone);
    final path = layout.pathFor(days);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        path,
        stroke
          ..color = palette.ridge
          ..strokeWidth = 26);
    canvas.drawPath(
        path,
        stroke
          ..color = palette.trail
          ..strokeWidth = 21);
    final steps = layout.steps(days);
    for (var day = 0; day <= days; day++) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: steps[day], width: 20, height: 13),
              const Radius.circular(6)),
          Paint()..color = day <= progress ? palette.accent : palette.stone);
    }
    final marks = layout.markerOrigins(days);
    for (var i = 0; i < 4; i++) {
      if (skipMarkers.contains(i)) continue;
      canvas.save();
      canvas.translate(marks[i].dx, marks[i].dy);
      _landmark(canvas, i);
      canvas.restore();
    }
    final s = layout.summit(days);
    canvas.drawLine(
        s + const Offset(0, 1),
        s + const Offset(0, -36),
        stroke
          ..color = palette.ink
          ..strokeWidth = 2.5);
    shape([
      s + const Offset(1, -35),
      s + const Offset(26, -34),
      s + const Offset(19, -26),
      s + const Offset(26, -20),
      s + const Offset(1, -21)
    ], palette.accent);
    if (freeOverlay) {
      final fill = Paint()
        ..color = const Color(0xFF2F6BFF).withValues(alpha: .28);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF2F6BFF).withValues(alpha: .85);
      for (final r in freeBoxes(layout, days)) {
        canvas.drawRect(r, fill);
        canvas.drawRect(r.deflate(1), edge);
      }
    }
    if (window != null) {
      final dash = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * 320 / size.width
        ..color = palette.ink.withValues(alpha: .7);
      final r = window!.deflate(1.5 * 320 / size.width);
      for (final edge in [
        [r.topLeft, r.topRight],
        [r.bottomLeft, r.bottomRight],
      ]) {
        final a = edge[0], b = edge[1];
        for (var x = a.dx; x < b.dx; x += 12) {
          canvas.drawLine(
              Offset(x, a.dy), Offset((x + 7).clamp(a.dx, b.dx), a.dy), dash);
        }
      }
    }
    canvas.restore();
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
  bool shouldRepaint(StudyPainter old) => true;
}
