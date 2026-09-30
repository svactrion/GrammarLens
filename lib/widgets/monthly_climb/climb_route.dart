import 'dart:math' as math;
import 'dart:ui';

import 'climb_table.dart';

/// Logical scene coordinates. Painting and movement use the same Path.
///
/// **The curve is frozen** (1.1.0 design decision K1,
/// `docs/1.1.0-design-side-tracks.md`, replacing Batch 3b's 45° curve):
/// candidate 1 of the Batch 3c-A study, five legs from a long 12° start to a
/// 73° final climb. Straight legs through [corners], joined by circular arcs
/// of the [fillets] radii. The same path serves every month length; day d of
/// an N-day month sits at d / N of its length, so steps are evenly spaced
/// and the last day is the summit.
///
/// Acceptance (K1): at 320 pt in a 31-day month a day's step is at least
/// 17 pt and neighbouring step markers are at least 5 pt apart
/// (`test/climb_acceptance_test.dart`).
///
/// Whole days are read from the generated [climbStepTable] (decision D3);
/// changing [corners] or [fillets] makes `test/climb_table_test.dart`
/// fail until the table is regenerated (`scripts/generate_climb_table.sh`).
class ClimbRoute {
  static const sceneSize = Size(320, 740);

  /// The foot, the four turns, and the summit (the trail's end, where the
  /// summit layer stands: Batch 0 decision 5).
  static const corners = [
    Offset(22, 716),
    Offset(276, 660),
    Offset(70, 540),
    Offset(236, 400),
    Offset(110, 250),
    Offset(160, 86),
  ];

  /// One radius per turn. A turn whose legs are too short for its radius
  /// gets a smaller one (the first turn: 42 units).
  static const fillets = [80.0, 70.0, 58.0, 46.0];

  /// The days that carry a stop marker: campfire, tent, mountain cabin,
  /// lookout terrace.
  static const markerDays = [7, 14, 21, 28];
  static const markerNames = [
    'campfire',
    'tent',
    'mountain cabin',
    'lookout terrace'
  ];

  /// Design decision D2: a marker within the month's last 2 steps is not
  /// drawn; the summit takes its place. By step, never by screen size.
  static bool markerShown(int markerDay, int days) => days - markerDay > 2;

  /// The shared path, built once.
  static final Path sharedPath = _filletPolyline(corners, fillets);
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

  /// The stop markers shown in this month (D2 applied), each with its
  /// drawing origin in scene units, from the generated [climbMarkerTable].
  List<({int day, Offset origin})> get markers => [
        for (final (day, x, y) in climbMarkerTable[days]!)
          (day: day, origin: Offset(x * sceneSize.width, y * sceneSize.height)),
      ];

  /// A step marker's size in scene units.
  static const stepMarkerSize = Size(20, 13);

  /// Points around day [day]'s step marker, as drawn: for measuring the gap
  /// between neighbouring markers.
  List<Offset> stepMarkerOutline(int day) {
    final r = Rect.fromCenter(
        center: stepAt(day),
        width: stepMarkerSize.width,
        height: stepMarkerSize.height);
    return [
      for (var i = 0; i <= 12; i++) ...[
        Offset.lerp(r.topLeft, r.topRight, i / 12)!,
        Offset.lerp(r.bottomLeft, r.bottomRight, i / 12)!,
        Offset.lerp(r.topLeft, r.bottomLeft, i / 12)!,
        Offset.lerp(r.topRight, r.bottomRight, i / 12)!,
      ]
    ];
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

  /// Straight legs joined by circular arcs of [radii] at the inner corners.
  /// If a leg is too short for the arc, the arc's tangent length is capped at
  /// 45 % of the shorter leg and the radius shrinks to fit.
  static Path _filletPolyline(List<Offset> points, List<double> radii) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    Offset unit(Offset o) => o / o.distance;
    for (var i = 1; i < points.length - 1; i++) {
      final a = points[i - 1], c = points[i], b = points[i + 1];
      final u = unit(c - a), v = unit(b - c);
      final turn =
          math.acos((u.dx * v.dx + u.dy * v.dy).clamp(-1.0, 1.0).toDouble());
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
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }
}
