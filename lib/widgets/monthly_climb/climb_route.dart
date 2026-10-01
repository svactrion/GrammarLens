import 'dart:ui';

import 'climb_trail_table.dart';

/// The trail, as painted into the scene's illustration (1.1.0 design,
/// scene art S2): the center line Scene Art Batch 0 extracted from Green
/// Slope's image, the same in every theme's image (S4).
///
/// **Units: image widths.** x is a share of the image's width, and so is y
/// (y ÷ the image's height × its height ÷ width), so one unit is the same
/// length across and down; the image is 1 wide and 1 ÷ [climbImageAspect]
/// tall ([sceneSize]). Placing it on screen is the camera's job (D3).
///
/// Day d of an N-day month stands at d / N of the trail's length, so steps
/// are evenly spaced and the last day is the summit. Whole days are read
/// from the generated [climbStepTable]; a change to the extracted trail
/// makes `test/climb_trail_table_test.dart` fail until the table is
/// regenerated (`scripts/generate_climb_trail.sh`).
class ClimbRoute {
  static const sceneSize = Size(1, 1 / climbImageAspect);

  /// The center line, foot to summit, in image widths.
  static final List<Offset> trail = [
    for (final (x, y) in climbTrail) Offset(x, y / climbImageAspect)
  ];

  static final List<double> _cumulative = () {
    final out = <double>[0];
    for (var i = 1; i < trail.length; i++) {
      out.add(out.last + (trail[i] - trail[i - 1]).distance);
    }
    return out;
  }();

  /// The trail's length, in image widths.
  static double get length => _cumulative.last;

  /// The foot, beside the START flag: day 0.
  static Offset get foot => trail.first;

  /// The trail's end under the snow cap: the last day (Batch 0 decision 5).
  static Offset get summit => trail.last;

  final int days;

  ClimbRoute(this.days) {
    if (days < 28 || days > 31) {
      throw ArgumentError.value(days, 'days', 'Expected 28–31');
    }
  }

  /// Where day [day] stands, from the step table, in image widths.
  Offset stepAt(int day) {
    final (x, y) = climbStepTable[days]![day.clamp(0, days)];
    return Offset(x, y / climbImageAspect);
  }

  /// How far along the trail [day] is, in image widths; between two days
  /// for the pawn's motion.
  double arcAt(double day) => length * day.clamp(0.0, days.toDouble()) / days;

  /// Any point along the trail, including between two days (the pawn's
  /// motion). At whole days it equals [stepAt] to within the table's
  /// rounding.
  Offset pointAt(double day) => at(arcAt(day));

  /// The point [s] image widths along the trail.
  static Offset at(double s) {
    final i = _segment(s);
    final a = _cumulative[i - 1], b = _cumulative[i];
    final t = b == a ? 0.0 : ((s - a) / (b - a)).clamp(0.0, 1.0);
    return Offset.lerp(trail[i - 1], trail[i], t)!;
  }

  /// The trail's horizontal width at [s] image widths along it, in image
  /// widths: the room an upright avatar's footprint has there (G3).
  static double chordAt(double s) {
    final i = _segment(s);
    final a = _cumulative[i - 1], b = _cumulative[i];
    final t = b == a ? 0.0 : ((s - a) / (b - a)).clamp(0.0, 1.0);
    return climbTrailChords[i - 1] +
        (climbTrailChords[i] - climbTrailChords[i - 1]) * t;
  }

  /// The trail's narrowest horizontal width over its first [share] of
  /// length, in image widths.
  static double narrowestChord(double share) {
    var narrowest = double.infinity;
    for (var i = 0; i < trail.length; i++) {
      if (_cumulative[i] > length * share) break;
      if (climbTrailChords[i] < narrowest) narrowest = climbTrailChords[i];
    }
    return narrowest;
  }

  /// The index of the polyline point ending the segment that holds [s].
  static int _segment(double s) {
    var lo = 1, hi = _cumulative.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (_cumulative[mid] < s) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
