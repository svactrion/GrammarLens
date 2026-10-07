// Trail geometry and measurements for the design studies (Batch 3a/3b).
// Measuring code only: nothing in lib/ imports it.
import 'dart:math' as math;
import 'dart:ui';

const sceneW = 320.0, sceneH = 740.0;
const trailHalf = 13.0; // outer stroke 26
const stepW = 20.0, stepH = 13.0;
const hopHeight = 14.0; // scene units above the chord's midpoint
// Landmark drawing bounds relative to its origin (from _landmark, all four).
const markBox = Rect.fromLTRB(-28, -30, 30, 20);
// Avatar tile relative to the step point: left −29, top −55, 58 × 58.
const avatarBox = Rect.fromLTRB(-29, -55, 29, 3);

/// One trail layout: a path, and where day d of an N-day month sits.
abstract class Layout {
  String get id;
  String get title;
  Path pathFor(int days);
  List<Offset> steps(int days);
  List<Offset> markerOrigins(int days);

  /// Where the summit marker (flag base) stands.
  Offset summit(int days);
}

List<Offset> sample(Path path, {double ds = 1}) {
  final m = path.computeMetrics().single;
  return [
    for (var s = 0.0; s < m.length; s += ds) m.getTangentForOffset(s)!.position,
    m.getTangentForOffset(m.length)!.position,
  ];
}

double pathLength(Path p) => p.computeMetrics().single.length;

/// A shared path (the same for 28–31 days); steps evenly spaced along it.
class EvenLayout extends Layout {
  @override
  final String id, title;
  final Path path;
  late final PathMetric metric = path.computeMetrics().single;
  late final List<Offset> _samples = sample(path);
  EvenLayout(this.id, this.title, this.path);

  @override
  Path pathFor(int days) => path;
  @override
  List<Offset> steps(int days) => [
        for (var d = 0; d <= days; d++)
          metric.getTangentForOffset(metric.length * d / days)!.position
      ];

  /// Beside its step, on whichever side is clear: the closest spot (both
  /// sides, 30–90 units out along the normal, lifted 0/±10/−20) where the
  /// landmark's box stays 4 units off the trail band, covers no step, stays
  /// on the mountain and in the scene, and meets no other landmark or the
  /// summit. The avatar may pass in front of it (measured separately).
  @override
  List<Offset> markerOrigins(int days) {
    final st = steps(days);
    final placed = <Rect>[];
    final result = <Offset>[];
    relaxedDays.clear();
    noSpotDays.clear();
    for (final day in [7, 14, 21, 28]) {
      final s = metric.length * day / days;
      final t = metric.getTangentForOffset(s)!;
      final n = Offset(-t.vector.dy, t.vector.dx);
      Offset? best;
      double bestCost = double.infinity;
      for (final side in [1.0, -1.0]) {
        for (var dist = 30.0; dist <= 90; dist += 2) {
          for (final lift in [0.0, -10.0, 10.0, -20.0]) {
            final o = t.position + n * (side * dist) + Offset(0, lift);
            if (!_fits(markBox.shift(o), st, placed)) continue;
            final cost = (o - t.position).distance + lift.abs() * .5;
            if (cost < bestCost) {
              bestCost = cost;
              best = o;
            }
          }
        }
      }
      if (best == null) {
        // No spot on the mountain (the top is narrow): allow the box's top
        // into the sky and closer to the summit.
        for (final side in [1.0, -1.0]) {
          for (var dist = 30.0; dist <= 90; dist += 2) {
            for (final lift in [0.0, -10.0, 10.0, -20.0]) {
              final o = t.position + n * (side * dist) + Offset(0, lift);
              if (!_fits(markBox.shift(o), st, placed, relaxed: true)) continue;
              final cost = (o - t.position).distance + lift.abs() * .5;
              if (cost < bestCost) {
                bestCost = cost;
                best = o;
              }
            }
          }
        }
        if (best != null) relaxedDays.add(day);
      }
      if (best == null) noSpotDays.add(day);
      best ??= t.position + n * 44;
      placed.add(markBox.shift(best).inflate(6));
      result.add(best);
    }
    return result;
  }

  final relaxedDays = <int>{};
  final noSpotDays = <int>{};

  bool _fits(Rect box, List<Offset> st, List<Rect> placed,
      {bool relaxed = false}) {
    if (box.left < 4 || box.right > sceneW - 4 || box.top < 4) return false;
    if (box.bottom > sceneH - 4) return false;
    if (!onMountain(box.bottomLeft + const Offset(4, -4)) ||
        !onMountain(box.bottomRight + const Offset(-4, -4)) ||
        (!relaxed && !onMountain(box.topCenter + const Offset(0, 10)))) {
      return false;
    }
    for (final p in _samples) {
      if (_rectDist(box, p) < trailHalf + 4) return false;
    }
    for (final p in st) {
      if (box
          .overlaps(Rect.fromCenter(center: p, width: stepW, height: stepH))) {
        return false;
      }
    }
    for (final r in placed) {
      if (r.overlaps(box)) return false;
    }
    if (box.inflate(relaxed ? 0 : 6).overlaps(summitBox(summit(0)))) {
      return false;
    }
    return true;
  }

  @override
  Offset summit(int days) =>
      metric.getTangentForOffset(metric.length)!.position;
}

/// The mountain body polygon (monthly_mountain.dart).
final mountainPath = Path()
  ..addPolygon(const [
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
  ], true);
bool onMountain(Offset p) => mountainPath.contains(p);

/// Flag pole and cloth drawn at the summit point, like today's flag.
Rect summitBox(Offset s) => Rect.fromLTRB(s.dx - 3, s.dy - 40, s.dx + 28, s.dy);

double _rectDist(Rect r, Offset p) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

/// Straight legs joined by circular arcs of radius r at each corner (a
/// fillet). If a leg is too short for the arc, the arc's tangent length is
/// capped at 45 % of the shorter leg and the radius shrinks to fit.
Path filletPolyline(List<Offset> pts, List<double> radii) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length - 1; i++) {
    final a = pts[i - 1], c = pts[i], b = pts[i + 1];
    final u = _unit(c - a), v = _unit(b - c);
    final turn = math.acos((u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0));
    var r = radii[i - 1];
    var t = r * math.tan(turn / 2);
    final cap = .45 * math.min((c - a).distance, (b - c).distance);
    if (t > cap) {
      t = cap;
      r = t / math.tan(turn / 2);
    }
    final entry = c - u * t, exit = c + v * t;
    path.lineTo(entry.dx, entry.dy);
    final cross = u.dx * v.dy - u.dy * v.dx;
    path.arcToPoint(exit, radius: Radius.circular(r), clockwise: cross > 0);
  }
  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}

Offset _unit(Offset o) => o / o.distance;

// ---------------------------------------------------------------------------
// Measurements

class Turn {
  final double s, x, y, minRadius;
  Turn(this.s, this.x, this.y, this.minRadius);
}

/// Turns are the local extremes of x along the path; each reports the
/// smallest radius of curvature within ±40 units of it.
List<Turn> turns(Path path) {
  final m = path.computeMetrics().single;
  const ds = 1.0;
  final pts = <Offset>[], ang = <double>[];
  for (var s = 0.0; s <= m.length; s += ds) {
    final t = m.getTangentForOffset(s)!;
    pts.add(t.position);
    ang.add(t.angle);
  }
  final radius = List<double>.filled(pts.length, double.infinity);
  const w = 3; // curvature over 2·w units
  for (var i = w; i < pts.length - w; i++) {
    var d = ang[i + w] - ang[i - w];
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    final k = d.abs() / (2 * w * ds);
    radius[i] = k < 1e-6 ? double.infinity : 1 / k;
  }
  final result = <Turn>[];
  for (var i = 2; i < pts.length - 2; i++) {
    final x = pts[i].dx;
    final isMax = x >= pts[i - 1].dx && x > pts[i + 1].dx;
    final isMin = x <= pts[i - 1].dx && x < pts[i + 1].dx;
    if (!isMax && !isMin) continue;
    var r = double.infinity;
    for (var j = math.max(0, i - 40); j < math.min(pts.length, i + 40); j++) {
      r = math.min(r, radius[j]);
    }
    result.add(Turn(i * ds, x, pts[i].dy, r));
  }
  return result;
}

/// Legs: path pieces between start, each turn and the end.
List<double> legLengths(Path path) {
  final t = turns(path);
  final len = pathLength(path);
  final cuts = [0.0, for (final x in t) x.s, len];
  return [for (var i = 1; i < cuts.length; i++) cuts[i] - cuts[i - 1]];
}

double rectGap(Offset a, Offset b) {
  final dx = math.max(0.0, (a.dx - b.dx).abs() - stepW);
  final dy = math.max(0.0, (a.dy - b.dy).abs() - stepH);
  return math.sqrt(dx * dx + dy * dy);
}

/// Arc position of each step along [path] (closest sample).
List<double> arcPositions(Path path, List<Offset> st) {
  final m = path.computeMetrics().single;
  final samples = <double>[];
  final pts = <Offset>[];
  for (var s = 0.0; s <= m.length; s += .5) {
    samples.add(s);
    pts.add(m.getTangentForOffset(s)!.position);
  }
  return [
    for (final p in st)
      () {
        var best = 0, bd = double.infinity;
        for (var i = 0; i < pts.length; i++) {
          final d = (pts[i] - p).distanceSquared;
          if (d < bd) {
            bd = d;
            best = i;
          }
        }
        return samples[best];
      }()
  ];
}

/// Facing per step: the sign of the move from the previous step; a move
/// under 3 units sideways keeps the previous facing. Day 0 faces the first
/// move.
List<int> facings(List<Offset> st) {
  final f = <int>[];
  var cur = 0;
  for (var i = 1; i < st.length; i++) {
    final dx = st[i].dx - st[i - 1].dx;
    if (dx > 3) cur = 1;
    if (dx < -3) cur = -1;
    f.add(cur);
  }
  final first = f.firstWhere((x) => x != 0, orElse: () => 1);
  return [first, ...f.map((x) => x == 0 ? first : x)];
}

Map<String, Object> measure(Layout l, int days, double scale) {
  final path = l.pathFor(days);
  final st = l.steps(days);
  final len = pathLength(path);
  final pos = arcPositions(path, st);
  final spacing = [for (var i = 1; i < st.length; i++) pos[i] - pos[i - 1]];
  final chord = [
    for (var i = 1; i < st.length; i++) (st[i] - st[i - 1]).distance
  ];
  // Closest pair of step markers, consecutive and not.
  var minCons = double.infinity, minConsAt = 0;
  var minOther = double.infinity, minOtherAt = [0, 0];
  var minOtherCenter = double.infinity;
  for (var i = 0; i < st.length; i++) {
    for (var j = i + 1; j < st.length; j++) {
      final g = rectGap(st[i], st[j]);
      if (j == i + 1) {
        if (g < minCons) {
          minCons = g;
          minConsAt = i;
        }
      } else if ((pos[j] - pos[i]).abs() >= 90 && g < minOther) {
        minOther = g;
        minOtherAt = [i, j];
        minOtherCenter = (st[i] - st[j]).distance;
      }
    }
  }
  // Leg-to-leg clearance: the smallest distance between two points of the
  // path at least 90 units apart along it (centerline; the bands touch at 26).
  final smp = sample(path, ds: 2);
  var legGap = double.infinity;
  Offset legGapAt = Offset.zero;
  for (var i = 0; i < smp.length; i++) {
    for (var j = i + 45; j < smp.length; j++) {
      final d = (smp[i] - smp[j]).distance;
      if (d < legGap) {
        legGap = d;
        legGapAt = smp[i];
      }
    }
  }
  // Avatar resting on a step covering another part of the trail.
  final avatarOver = <int>[];
  for (var d = 0; d < st.length; d++) {
    final box = avatarBox.shift(st[d]).deflate(4);
    var hit = false;
    for (var i = 0; i < smp.length && !hit; i++) {
      final s = i * 2.0;
      if ((s - pos[d]).abs() < 70) continue;
      if (_rectDist(box, smp[i]) < trailHalf) hit = true;
    }
    if (hit) avatarOver.add(d);
  }
  // Hop arc (the feet): does it cross another part of the trail band?
  final hopCross = <int>[];
  var hopClear = double.infinity;
  for (var d = 0; d < st.length - 1; d++) {
    for (var k = 0; k <= 20; k++) {
      final t = k / 20;
      final q = Offset.lerp(st[d], st[d + 1], t)! -
          Offset(0, hopHeight * 4 * t * (1 - t));
      for (var i = 0; i < smp.length; i++) {
        final s = i * 2.0;
        if (s > pos[d] - 30 && s < pos[d + 1] + 30) continue;
        final dist = (smp[i] - q).distance;
        if (dist < hopClear) hopClear = dist;
        if (dist < trailHalf && !hopCross.contains(d)) hopCross.add(d);
      }
    }
  }
  // Landmarks: overlap with the trail band, the steps and the avatar.
  final marks = l.markerOrigins(days);
  final relaxed = l is EvenLayout ? l.relaxedDays.toList() : const <int>[];
  final markIssues = <String>[];
  for (var i = 0; i < marks.length; i++) {
    final box = markBox.shift(marks[i]);
    var trailClear = double.infinity;
    for (final p in smp) {
      trailClear = math.min(trailClear, _rectDist(box, p));
    }
    final stepsUnder = [
      for (var d = 0; d < st.length; d++)
        if (box.overlaps(
            Rect.fromCenter(center: st[d], width: stepW, height: stepH)))
          d
    ];
    final avatarUnder = [
      for (var d = 0; d < st.length; d++)
        if (box.overlaps(avatarBox.shift(st[d]).deflate(4))) d
    ];
    markIssues.add('day ${7 * (i + 1)}: box-to-centerline '
        '${trailClear.toStringAsFixed(1)} (band edge at 13)'
        '${stepsUnder.isEmpty ? '' : ', covers steps $stepsUnder'}'
        '${avatarUnder.isEmpty ? '' : ', meets avatar at days $avatarUnder'}');
  }
  final f = facings(st);
  var flips = 0;
  final flipDays = <int>[];
  for (var i = 1; i < f.length; i++) {
    if (f[i] != f[i - 1]) {
      flips++;
      flipDays.add(i);
    }
  }
  final end = st.last, sum = l.summit(days);
  final t = turns(path);
  final free = freeBoxes(l, days);
  final freeArea = free.fold<double>(0, (a, r) => a + r.width * r.height);
  double pt(double v) => double.parse((v * scale).toStringAsFixed(1));
  double u(double v) => double.parse(v.toStringAsFixed(1));
  return {
    'layout': l.id,
    'days': days,
    'scale': scale,
    'length_units': u(len),
    'turns': t.length,
    'turn_min_radius_units': [for (final x in t) u(x.minRadius)],
    'turn_at': [for (final x in t) '(${x.x.round()}, ${x.y.round()})'],
    'legs_units': [for (final x in legLengths(path)) u(x)],
    'spacing_min_units': u(spacing.reduce(math.min)),
    'spacing_max_units': u(spacing.reduce(math.max)),
    'spacing_min_pt': pt(spacing.reduce(math.min)),
    'spacing_max_pt': pt(spacing.reduce(math.max)),
    'chord_min_pt': pt(chord.reduce(math.min)),
    'chord_min_at_day': chord.indexOf(chord.reduce(math.min)) + 1,
    'consecutive_gap_min_pt': pt(minCons),
    'consecutive_gap_min_at': '$minConsAt→${minConsAt + 1}',
    'nonconsecutive_gap_min_pt': pt(minOther),
    'nonconsecutive_center_pt': pt(minOtherCenter),
    'nonconsecutive_at': '${minOtherAt[0]} & ${minOtherAt[1]}',
    'leg_to_leg_centerline_min_pt': pt(legGap),
    'leg_to_leg_at': '(${legGapAt.dx.round()}, ${legGapAt.dy.round()})',
    'avatar_covers_other_leg_days': avatarOver,
    'hop_crosses_other_leg': hopCross,
    'hop_min_clearance_pt': pt(hopClear),
    'facing_changes': flips,
    'facing_change_days': flipDays,
    'end': '(${end.dx.round()}, ${end.dy.round()})',
    'summit': '(${sum.dx.round()}, ${sum.dy.round()})',
    'end_to_summit_units': u((end - sum).distance),
    'markers': markIssues,
    'markers_partly_off_mountain': relaxed,
    'markers_no_clear_spot':
        l is EvenLayout ? l.noSpotDays.toList() : const <int>[],
    'free_boxes': [
      for (final r in free)
        '${r.width.round()}×${r.height.round()} at (${r.left.round()}, ${r.top.round()})'
    ],
    'free_boxes_on_mountain': free.where((r) => onMountain(r.center)).length,
    'free_boxes_count': free.length,
    'free_boxes_80': free.where((r) => r.shortestSide >= 80).length,
    'free_area_pct_scene': u(100 * freeArea / (sceneW * sceneH)),
  };
}

/// Empty rectangles where environment items can go: outside the trail band
/// (+6), the avatar's space above every point of the trail (+4), the
/// landmarks (+6) and the summit (+6); inside the scene with a 6-unit margin.
/// Greedy: the largest free rectangle (both sides ≥ 56), then the next one
/// 8 units away from those taken, up to 6.
List<Rect> freeBoxes(Layout l, int days) {
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
      final cx = x * cell, cy = y * cell;
      if (cx < 6 ||
          cy < 6 ||
          cx + cell > sceneW - 6 ||
          cy + cell > sceneH - 6) {
        blocked[y][x] = true;
      }
    }
  }
  for (final p in sample(l.pathFor(days), ds: 2)) {
    block(Rect.fromCircle(center: p, radius: trailHalf + 6));
    block(avatarBox.shift(p).inflate(4));
  }
  for (final o in l.markerOrigins(days)) {
    block(markBox.shift(o).inflate(6));
  }
  block(summitBox(l.summit(days)).inflate(6));
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

/// Largest all-free rectangle with both sides ≥ minCells: [row, col, h, w].
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
