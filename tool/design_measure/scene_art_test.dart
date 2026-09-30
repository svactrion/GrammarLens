// A composition guide for AI image tools: the whole mountain in the product's
// own geometry (ClimbScene, ClimbRoute, ClimbCamera), as flat grays with the
// trail in red, the four turns in blue and the summit as a black star. No
// text, labels or avatar. A second copy adds the F1 window on day 3 and day 25
// of a 31-day month; a third, "clean", has the silhouettes only. Output: DESIGN_MEASURE_OUT or build/design_measure.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_scene.dart';

import 'layouts.dart' show outDir;

/// The canvas, in scene units: the whole mountain (its foot reaches past the
/// 320-unit scene on both sides) and the widest F1 window (430 pt screens
/// show x −108 to 428), from the scene's top (72 units of sky above the peak)
/// to its bottom.
const canvas = Rect.fromLTRB(-130, 0, 450, 740);

/// Pixels per scene unit: 580 units → 1450 px wide.
const pxPerUnit = 2.5;

/// The reference screen for the window rectangles: 375 pt (card 341.25 pt).
const referenceCardWidth = 341.25;

/// Where each turn is: the point of the trail closest to the corner, i.e.
/// the middle of the turn's arc.
List<Offset> turnPoints() {
  final metric = ClimbRoute(31).path.computeMetrics().single;
  return [
    for (final corner in ClimbRoute.corners.sublist(1, 5))
      () {
        var best = Offset.zero, bestD = double.infinity;
        for (var s = 0.0; s <= metric.length; s += .5) {
          final p = metric.getTangentForOffset(s)!.position;
          final d = (p - corner).distance;
          if (d < bestD) {
            bestD = d;
            best = p;
          }
        }
        return best;
      }()
  ];
}

/// The F1 window (scene units) with the pawn on [day] of a 31-day month.
Rect f1Window(int day) {
  const camera = ClimbCamera();
  final s = camera.scale;
  final pawn = ClimbRoute(31).stepAt(day);
  final w = referenceCardWidth / s, h = ClimbCamera.windowHeight / s;
  final top = camera.scrollFor(pawn, ClimbCamera.windowHeight,
          ClimbRoute.sceneSize.height * s - ClimbCamera.windowHeight) /
      s;
  return Rect.fromLTWH(160 - w / 2, top, w, h);
}

void _star(Canvas c, Offset center, double r, Paint paint) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final a = -math.pi / 2 + i * math.pi / 5;
    final radius = i.isEven ? r : r * .45;
    final p = center + Offset(math.cos(a), math.sin(a)) * radius;
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  c.drawPath(path..close(), paint);
}

void _dashedRect(Canvas c, Rect r, Paint paint,
    {double dash = 10, double gap = 7}) {
  void line(Offset a, Offset b) {
    final len = (b - a).distance;
    final dir = (b - a) / len;
    for (var t = 0.0; t < len; t += dash + gap) {
      c.drawLine(a + dir * t, a + dir * math.min(t + dash, len), paint);
    }
  }

  line(r.topLeft, r.topRight);
  line(r.topRight, r.bottomRight);
  line(r.bottomRight, r.bottomLeft);
  line(r.bottomLeft, r.topLeft);
}

/// [markings] adds the trail, the turns and the summit star; [windows]
/// adds the F1 windows. With neither, only the silhouettes are drawn.
ui.Picture guide({bool markings = true, bool windows = false}) {
  final recorder = ui.PictureRecorder();
  final c = Canvas(recorder);
  c.scale(pxPerUnit);
  c.translate(-canvas.left, -canvas.top);
  c.clipRect(canvas);
  c.drawRect(canvas, Paint()..color = Colors.white);
  void poly(List<Offset> pts, Color color) =>
      c.drawPath(Path()..addPolygon(pts, true), Paint()..color = color);
  // Back ridges: lighter than the mountain.
  poly(ClimbScene.farRidge, const Color(0xFFEFEFEF));
  poly(ClimbScene.midRidge, const Color(0xFFE3E3E3));
  // The mountain and its foothills: one light gray.
  const mountain = Color(0xFFCCCCCC);
  poly(ClimbScene.body, mountain);
  for (final hill in ClimbScene.foothills) {
    c.drawOval(hill, Paint()..color = mountain);
  }
  // The boundary between the lit and the shadowed face: a thin line along
  // the ridge line (the shadow face's first seven points).
  c.drawPath(
      Path()..addPolygon(ClimbScene.shadowFace.sublist(0, 7), false),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFF7A7A7A));
  if (!markings) return recorder.endRecording();
  // The trail's center line.
  c.drawPath(
      ClimbRoute(31).path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFFE0201C));
  // The four turns: future save points.
  for (final p in turnPoints()) {
    c.drawCircle(p, 9, Paint()..color = const Color(0xFF1F5FD6));
  }
  // The summit: the trail's end, where the summit layer stands.
  _star(c, ClimbRoute.summit, 12, Paint()..color = Colors.black);
  if (windows) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF333333);
    // The two windows share their width; day 3 (short dashes) is drawn
    // 5 units in at the sides so it can be told from day 25 (long dashes),
    // whose edges are exact.
    final day3 = f1Window(3);
    _dashedRect(
        c,
        Rect.fromLTRB(
            day3.left + 5, day3.top + .6, day3.right - 5, day3.bottom - .6),
        paint,
        dash: 5,
        gap: 5);
    _dashedRect(c, f1Window(25).deflate(.6), paint, dash: 16, gap: 8);
  }
  return recorder.endRecording();
}

String _f(double v) => v.toStringAsFixed(1);

void main() {
  test('scene art guide', () async {
    final out = outDir();
    final w = (canvas.width * pxPerUnit).round(),
        h = (canvas.height * pxPerUnit).round();
    for (final (name, markings, windows) in [
      ('mountain_guide.png', true, false),
      ('mountain_guide_f1_windows.png', true, true),
      ('mountain_guide_clean.png', false, false),
    ]) {
      final image =
          await guide(markings: markings, windows: windows).toImage(w, h);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
    }

    // Numbers for the report.
    final metric = ClimbRoute(31).path.computeMetrics().single;
    var line = Rect.zero;
    for (var s = 0.0; s <= metric.length; s += .5) {
      final p = metric.getTangentForOffset(s)!.position;
      line = s == 0
          ? Rect.fromLTWH(p.dx, p.dy, 0, 0)
          : line.expandToInclude(Rect.fromLTWH(p.dx, p.dy, 0, 0));
    }
    final band = line.inflate(13); // the trail's outer stroke is 26 wide
    var body = Rect.zero;
    for (final (i, p) in ClimbScene.body.indexed) {
      final r = Rect.fromLTWH(p.dx, p.dy, 0, 0);
      body = i == 0 ? r : body.expandToInclude(r);
    }
    final bodyInScene = body.intersect(const Rect.fromLTWH(0, 0, 320, 740));
    String rect(Rect r) =>
        'x ${_f(r.left)}–${_f(r.right)}, y ${_f(r.top)}–${_f(r.bottom)} '
        '(${_f(r.width)} × ${_f(r.height)}); normalized x '
        '${(r.left / 320).toStringAsFixed(3)}–${(r.right / 320).toStringAsFixed(3)}, '
        'y ${(r.top / 740).toStringAsFixed(3)}–${(r.bottom / 740).toStringAsFixed(3)}';
    final numbers = StringBuffer()
      ..writeln('image: $w × $h px, $pxPerUnit px per unit; canvas '
          'x ${canvas.left}–${canvas.right}, y ${canvas.top}–${canvas.bottom} '
          '(${canvas.width} × ${canvas.height} units, aspect '
          '${(canvas.width / canvas.height).toStringAsFixed(4)})')
      ..writeln('mountain space: 320 × 740 units, aspect '
          '${(320 / 740).toStringAsFixed(4)}; in the image at px '
          '${(-canvas.left * pxPerUnit).round()}–${((320 - canvas.left) * pxPerUnit).round()} × 0–${(740 * pxPerUnit).round()}')
      ..writeln('trail center line: ${rect(line)}')
      ..writeln('trail band (±13): ${rect(band)}')
      ..writeln('mountain body (to y 760): ${rect(body)}')
      ..writeln('mountain body inside the scene: ${rect(bodyInScene)}')
      ..writeln('peak vertex: (${ClimbScene.peak.dx}, ${ClimbScene.peak.dy}); '
          'summit (trail end): (${ClimbRoute.summit.dx}, ${ClimbRoute.summit.dy})')
      ..writeln(
          'trail start: (${ClimbRoute.corners.first.dx}, ${ClimbRoute.corners.first.dy})')
      ..writeln(
          'turns (arc middle): ${turnPoints().map((p) => '(${_f(p.dx)}, ${_f(p.dy)})').join(', ')}')
      ..writeln(
          'turn corners (legs meet): ${ClimbRoute.corners.sublist(1, 5).map((p) => '(${p.dx}, ${p.dy})').join(', ')}');
    for (final screen in [320.0, 375.0, 430.0]) {
      final card = screen - 2 * (screen * .045).clamp(16.0, 28.0);
      final wu = card / (350 / 480);
      numbers.writeln('F1 window at $screen pt (card ${_f(card)} pt): '
          '${_f(wu)} × 480 units, x ${_f(160 - wu / 2)}–${_f(160 + wu / 2)}');
    }
    numbers
      ..writeln('F1 window, 375 pt, day 3 of 31: ${rect(f1Window(3))}')
      ..writeln('F1 window, 375 pt, day 25 of 31: ${rect(f1Window(25))}');
    File('$out/numbers.txt').writeAsStringSync(numbers.toString());
  });
}
