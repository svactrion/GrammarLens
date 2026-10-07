// Stop markers and environment items for a candidate. Measuring code only.
import 'dart:math' as math;
import 'dart:ui';

import 'geometry.dart';

const trailHalf = 13.0;
const markerBox = Rect.fromLTRB(-28, -30, 30, 20); // the product's drawings
const avatarBox = Rect.fromLTRB(-29, -55, 29, 3);
const stepLen = 18.0, stepWid = 11.0; // step pill, along x across

Rect summitBox(Offset s) => Rect.fromLTRB(s.dx - 3, s.dy - 40, s.dx + 28, s.dy);

double rectDistance(Rect r, Offset p) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

List<Offset> trailSamples(Candidate c, {double ds = 1}) {
  final m = c.metric;
  return [
    for (var s = 0.0; s < m.length; s += ds) m.getTangentForOffset(s)!.position,
    m.getTangentForOffset(m.length)!.position,
  ];
}

/// Markers that needed the second pass, for the report.
final relaxedMarkers = <String>{};

/// D2: the marker at day d is shown only if days − d > 2.
bool markerShown(int day, int days) => days - day > 2;

/// The Batch 3a placement rule on this candidate: beside its own step, the
/// closest clear spot (both sides, 30–90 units out, lifted 0/−10/+10/−20),
/// 4 units off the trail band, covering no step, on the ground, in the
/// scene, away from other markers and the summit flag. Null if no spot.
List<(int, Offset?)> placeMarkers(Candidate c, int days) {
  final samples = trailSamples(c);
  final steps = [for (var d = 0; d <= days; d++) c.stepAt(d, days)];
  final placed = <Rect>[];
  bool fits(Rect box, {bool relaxed = false}) {
    if (box.left < 4 || box.right > sceneW - 4 || box.top < 4) return false;
    if (!c.onGround(box.bottomLeft + const Offset(4, -4)) ||
        !c.onGround(box.bottomRight + const Offset(-4, -4)) ||
        (!relaxed && !c.onGround(box.topCenter + const Offset(0, 10)))) {
      return false;
    }
    for (final p in samples) {
      if (rectDistance(box, p) < trailHalf + 4) return false;
    }
    for (final p in steps) {
      if (box.overlaps(Rect.fromCenter(center: p, width: 20, height: 20))) {
        return false;
      }
    }
    for (final r in placed) {
      if (r.overlaps(box)) return false;
    }
    return !box.inflate(relaxed ? 0 : 6).overlaps(summitBox(c.summit));
  }

  final out = <(int, Offset?)>[];
  for (final day in [7, 14, 21, 28]) {
    if (!markerShown(day, days)) continue;
    final t = c.tangentAt(c.metric.length * day / days);
    final n = Offset(-t.vector.dy, t.vector.dx);
    Offset? best;
    // Second pass (Batch 3a's rule): the box's top may reach into the sky.
    for (final relaxed in [false, true]) {
      var bestCost = double.infinity;
      for (final side in [1.0, -1.0]) {
        for (var dist = 30.0; dist <= 90; dist += 2) {
          for (final lift in [0.0, -10.0, 10.0, -20.0]) {
            final o = t.position + n * (side * dist) + Offset(0, lift);
            if (!fits(markerBox.shift(o), relaxed: relaxed)) continue;
            final cost = (o - t.position).distance + lift.abs() * .5;
            if (cost < bestCost) {
              bestCost = cost;
              best = o;
            }
          }
        }
      }
      if (best != null) {
        if (relaxed) relaxedMarkers.add('$days d day $day');
        break;
      }
    }
    if (best != null) placed.add(markerBox.shift(best).inflate(6));
    out.add((day, best));
  }
  return out;
}

/// Environment item boxes around their base point (bottom center).
const pineBox = Rect.fromLTRB(-16, -58, 16, 0);
const shrubBox = Rect.fromLTRB(-22, -22, 22, 0);

/// Blocked for environment items: the trail band + 8, the avatar's space
/// above every point of the trail, the markers + 6, the summit + 6, and
/// outside x 4–316 (so every width shows them) or off the ground.
bool envFree(Candidate c, Rect box, List<Offset> samples, List<Rect> taken) {
  if (box.left < 4 || box.right > sceneW - 4 || box.top < 4) return false;
  if (!c.onGround(box.bottomLeft + const Offset(3, -2)) ||
      !c.onGround(box.bottomRight + const Offset(-3, -2))) {
    return false;
  }
  for (final p in samples) {
    if (rectDistance(box, p) < trailHalf + 8) return false;
    if (box.overlaps(avatarBox.shift(p).inflate(2))) return false;
  }
  for (final r in taken) {
    if (r.overlaps(box)) return false;
  }
  return !box.overlaps(summitBox(c.summit).inflate(6));
}

/// Green Slope's two items (Batch 0 decision 6: the 4 markers plus at most
/// 2): a pine low on the mountain and a shrub with wildflowers higher up,
/// each at the free spot farthest from the trail within its band. Placed
/// for a 31-day month, the most markers.
List<(String, Offset)> placeEnvironment(Candidate c) {
  final samples = trailSamples(c, ds: 2);
  final taken = [
    for (final (_, o) in placeMarkers(c, 31))
      if (o != null) markerBox.shift(o).inflate(6)
  ];
  Offset? pick(Rect item, double yMin, double yMax) {
    Offset? best;
    var bestScore = -1.0;
    for (var y = yMin; y <= yMax; y += 4) {
      for (var x = 20.0; x <= 300; x += 4) {
        final base = Offset(x, y);
        final box = item.shift(base);
        if (!envFree(c, box, samples, taken)) continue;
        var clear = double.infinity;
        for (final p in samples) {
          clear = math.min(clear, rectDistance(box, p));
        }
        if (clear > bestScore) {
          bestScore = clear;
          best = base;
        }
      }
    }
    if (best != null) taken.add(item.shift(best).inflate(8));
    return best;
  }

  final pine = pick(pineBox, 520, 730);
  final shrub = pick(shrubBox, 250, 500);
  return [
    if (pine != null) ('pine', pine),
    if (shrub != null) ('shrub', shrub),
  ];
}
