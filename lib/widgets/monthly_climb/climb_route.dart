import 'dart:math' as math;
import 'dart:ui';

import 'climb_table.dart';

/// Logical scene coordinates. Painting and movement use the same Path.
///
/// **The curve is frozen** (1.1.0 design decision D1,
/// `docs/1.1.0-design-side-tracks.md`): trail (b) "Wide S" from the Batch 3a
/// study, its first leg steepened to 45° in Batch 3b. Straight legs through
/// [corners], joined by circular arcs of radius [filletRadius]. The same path
/// serves every month length; day d of an N-day month sits at d / N of its
/// length, so steps are evenly spaced and the last day is the summit.
///
/// Whole days are read from the generated [climbStepTable] (decision D3);
/// changing [corners] or [filletRadius] makes `test/climb_table_test.dart`
/// fail until the table is regenerated (`scripts/generate_climb_table.sh`).
class ClimbRoute {
  static const sceneSize = Size(320, 740);

  /// Foot, the two bends, and the summit (the trail's end, where the summit
  /// layer stands: Batch 0 decision 5).
  static const corners = [
    Offset(136, 700),
    Offset(270, 566),
    Offset(50, 338),
    Offset(162, 84),
  ];
  static const filletRadius = 110.0;

  /// The shared path, built once.
  static final Path sharedPath = _filletPolyline(corners, filletRadius);
  static final PathMetric _metric = sharedPath.computeMetrics().single;

  static Offset get summit => corners.last;

  final int days;
  Path get path => sharedPath;

  ClimbRoute(this.days) {
    if (days < 28 || days > 31) {
      throw ArgumentError.value(days, 'days', 'Expected 28–31');
    }
  }

  /// Where day [day] stands, from the step table, in scene units.
  Offset stepAt(int day) {
    final (x, y) = climbStepTable[days]![day.clamp(0, days)];
    return Offset(x * sceneSize.width, y * sceneSize.height);
  }

  /// Any point along the trail, including between two days (the pawn's
  /// motion). At whole days it equals [stepAt] to within the table's
  /// rounding.
  Offset pointAt(double day) {
    final bounded = day.clamp(0.0, days.toDouble());
    return _metric
        .getTangentForOffset(_metric.length * bounded / days)!
        .position;
  }

  /// Straight legs joined by circular arcs of [radius] at each inner corner.
  /// If a leg is too short for the arc, the arc's tangent length is capped at
  /// 45 % of the shorter leg and the radius shrinks to fit.
  static Path _filletPolyline(List<Offset> points, double radius) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    Offset unit(Offset o) => o / o.distance;
    for (var i = 1; i < points.length - 1; i++) {
      final a = points[i - 1], c = points[i], b = points[i + 1];
      final u = unit(c - a), v = unit(b - c);
      final turn =
          math.acos((u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0).toDouble());
      var r = radius;
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
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
}
