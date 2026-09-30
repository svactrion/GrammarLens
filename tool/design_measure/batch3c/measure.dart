// Batch 3c-A measurements. Measuring code only.
import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';
import 'placement.dart';

String f1d(double v) => v.toStringAsFixed(1);

/// The fillet radius each corner really gets (capped legs shrink it).
List<double> effectiveRadii(Candidate c) {
  final out = <double>[];
  final pts = c.corners;
  Offset unit(Offset o) => o / o.distance;
  for (var i = 1; i < pts.length - 1; i++) {
    final a = pts[i - 1], m = pts[i], b = pts[i + 1];
    final u = unit(m - a), v = unit(b - m);
    final turn =
        math.acos((u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0).toDouble());
    var r = c.fillets[i - 1];
    var t = r * math.tan(turn / 2);
    final cap = .45 * math.min((m - a).distance, (b - m).distance);
    if (t > cap) r = cap / math.tan(turn / 2);
    out.add(r);
  }
  return out;
}

List<Offset> pillOutline(Offset center, Offset dir) {
  final u = dir / dir.distance, n = Offset(-u.dy, u.dx);
  final pts = <Offset>[];
  for (var i = 0; i <= 12; i++) {
    final t = -1 + 2 * i / 12;
    for (final side in [-1.0, 1.0]) {
      pts.add(center + u * (t * stepLen / 2) + n * (side * stepWid / 2));
    }
    for (final end in [-1.0, 1.0]) {
      pts.add(center + u * (end * stepLen / 2) + n * (t * stepWid / 2));
    }
  }
  return pts;
}

double outlineGap(List<Offset> a, List<Offset> b) {
  var d = double.infinity;
  for (final p in a) {
    for (final q in b) {
      d = math.min(d, (p - q).distance);
    }
  }
  return d;
}

Map<String, Object> measureCandidate(Candidate c) {
  final out = <String, Object>{};
  final legs = <String>[];
  for (var i = 1; i < c.corners.length; i++) {
    final v = c.corners[i] - c.corners[i - 1];
    final deg = math.atan2(-v.dy, v.dx.abs()) * 180 / math.pi;
    legs.add('${deg.toStringAsFixed(0)}° (${v.distance.round()})');
  }
  out['legs bottom→top: angle (length, units)'] = legs.join(', ');
  final radii = effectiveRadii(c);
  out['turn radii (units)'] = radii.map((r) => r.round()).join(', ');
  out['smallest turn radius (units)'] = f1d(radii.reduce(math.min));
  out['trail length (units)'] = f1d(c.metric.length);
  // Trail on the ground, and its margin to the body's edge.
  final samples = trailSamples(c);
  var off = 0;
  for (final p in samples) {
    if (!c.onGround(p)) off++;
  }
  out['trail samples off the ground'] = off;
  for (final days in [31, 30, 29, 28]) {
    final step = c.metric.length / days;
    final steps = [
      for (var d = 0; d <= days; d++) c.tangentAt(c.metric.length * d / days)
    ];
    final pills = [for (final t in steps) pillOutline(t.position, t.vector)];
    var cons = double.infinity;
    var consAt = 0;
    for (var d = 0; d < days; d++) {
      final g = outlineGap(pills[d], pills[d + 1]);
      if (g < cons) {
        cons = g;
        consAt = d;
      }
    }
    var other = double.infinity;
    for (var i = 0; i <= days; i++) {
      for (var j = i + 2; j <= days; j++) {
        if ((j - i) * step < 90) continue;
        other = math.min(other, outlineGap(pills[i], pills[j]));
      }
    }
    // Avatar resting on a step covering another part of the trail.
    final avatarOver = <int>[];
    for (var d = 0; d <= days; d++) {
      final box = avatarBox.shift(steps[d].position).deflate(4);
      final s0 = c.metric.length * d / days;
      for (var k = 0; k < samples.length; k++) {
        if ((k - s0).abs() < 70) continue;
        if (rectDistance(box, samples[k]) < trailHalf) {
          avatarOver.add(d);
          break;
        }
      }
    }
    final markers = placeMarkers(c, days);
    final markerText = [
      for (final (day, o) in markers)
        o == null
            ? 'day $day: NO CLEAR SPOT'
            : 'day $day at (${o.dx.round()}, ${o.dy.round()}), '
                'trail band +${f1d(samples.map((p) => rectDistance(markerBox.shift(o), p)).reduce(math.min) - trailHalf)}'
    ];
    out['$days d'] = {
      'step spacing (units)': f1d(step),
      'step spacing at 320 pt, F1 / whole (pt)':
          '${f1d(step * 350 / 480)} / ${f1d(step * 350 / 740)}',
      'closest neighbouring steps, gap (pt at F1)':
          '${f1d(cons * 350 / 480)} (days $consAt→${consAt + 1})',
      'closest steps across a turn, gap (pt at F1)': f1d(other * 350 / 480),
      'days the resting avatar covers another part of the trail':
          '${avatarOver.length} ${avatarOver.isEmpty ? '' : avatarOver}',
      'markers (D2 applied)': markerText.join('; '),
    };
  }
  // Environment.
  final env = placeEnvironment(c);
  out['environment items'] = env
      .map((e) => '${e.$1} at (${e.$2.dx.round()}, ${e.$2.dy.round()}), '
          'trail clearance ${f1d(samples.map((p) => rectDistance((e.$1 == 'pine' ? pineBox : shrubBox).shift(e.$2), p)).reduce(math.min) - trailHalf)} units')
      .join('; ');
  final free = freeBoxes(c);
  final area = free.fold<double>(0, (a, r) => a + r.width * r.height);
  out['free boxes ≥ 56 × 56 on the ground, x 4–316 (after items)'] =
      '${free.length}: ${free.map((r) => '${r.width.round()}×${r.height.round()} at (${r.left.round()}, ${r.top.round()})').join(', ')}';
  out['free area left for more items (% of 320 × 740)'] =
      f1d(100 * area / (sceneW * sceneH));
  out['markers needing the second pass (top into the sky)'] =
      relaxedMarkers.toList().toString();
  relaxedMarkers.clear();
  return out;
}

/// Greedy free rectangles (Batch 3a rule) on the ground inside x 4–316:
/// outside the trail band + 6, the avatar's space, markers + 6, the summit
/// + 6 and the placed environment items + 6.
List<Rect> freeBoxes(Candidate c) {
  const cell = 4.0;
  final cols = (sceneW / cell).ceil(), rows = (sceneH / cell).ceil();
  final blocked = List.generate(rows, (_) => List<bool>.filled(cols, false));
  void block(Rect r) {
    final c0 = (r.left / cell).floor().clamp(0, cols - 1);
    final c1 = (r.right / cell).ceil().clamp(0, cols);
    final r0 = (r.top / cell).floor().clamp(0, rows - 1);
    final r1 = (r.bottom / cell).ceil().clamp(0, rows);
    for (var y = r0; y < r1; y++) {
      for (var x = c0; x < c1; x++) {
        blocked[y][x] = true;
      }
    }
  }

  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      final p = Offset(x * cell + 2, y * cell + 2);
      if (p.dx < 6 ||
          p.dx > sceneW - 6 ||
          p.dy < 6 ||
          p.dy > sceneH - 6 ||
          !c.onGround(p)) {
        blocked[y][x] = true;
      }
    }
  }
  for (final p in trailSamples(c, ds: 2)) {
    block(Rect.fromCircle(center: p, radius: trailHalf + 6));
    block(avatarBox.shift(p).inflate(4));
  }
  for (final (_, o) in placeMarkers(c, 31)) {
    if (o != null) block(markerBox.shift(o).inflate(6));
  }
  for (final (kind, o) in placeEnvironment(c)) {
    block((kind == 'pine' ? pineBox : shrubBox).shift(o).inflate(6));
  }
  block(summitBox(c.summit).inflate(6));
  final out = <Rect>[];
  for (var n = 0; n < 6; n++) {
    final r = _largest(blocked, rows, cols, (56 / cell).ceil());
    if (r == null) break;
    final rect =
        Rect.fromLTWH(r[1] * cell, r[0] * cell, r[3] * cell, r[2] * cell);
    out.add(rect);
    block(rect.inflate(8));
  }
  return out;
}

List<int>? _largest(List<List<bool>> b, int rows, int cols, int minCells) {
  final h = List<int>.filled(cols, 0);
  List<int>? best;
  var bestArea = 0;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < cols; x++) {
      h[x] = b[y][x] ? 0 : h[x] + 1;
    }
    for (var x = 0; x < cols; x++) {
      if (h[x] < minCells) continue;
      var minH = h[x];
      for (var x2 = x; x2 < cols && h[x2] >= minCells; x2++) {
        minH = math.min(minH, h[x2]);
        final w = x2 - x + 1;
        if (w >= minCells && w * minH > bestArea) {
          bestArea = w * minH;
          best = [y - minH + 1, x, minH, w];
        }
      }
    }
  }
  return best;
}
