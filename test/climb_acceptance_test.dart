import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';

/// Design decision K1 (Batch 3c): at 320 pt in a 31-day month a day's step
/// is at least 17 pt and neighbouring step markers are at least 5 pt apart.
/// The camera's scale is the same at every width (F1), so 320 pt is no
/// special case; the 31-day month has the shortest steps.
void main() {
  const scale = 350 / 480; // ClimbCamera: points per scene unit
  final route = ClimbRoute(31);

  test('the camera scale is F1', () {
    expect(const ClimbCamera().scale, closeTo(scale, 1e-9));
  });

  test('a day\'s step is at least 17 pt', () {
    final length = route.path.computeMetrics().single.length;
    expect(length / 31 * scale, greaterThanOrEqualTo(17));
    // And as drawn: the shortest distance between two consecutive steps.
    var shortest = double.infinity;
    for (var d = 1; d <= 31; d++) {
      shortest =
          math.min(shortest, (route.stepAt(d) - route.stepAt(d - 1)).distance);
    }
    expect(shortest * scale, greaterThanOrEqualTo(17));
  });

  test('neighbouring step markers are at least 5 pt apart', () {
    var smallest = double.infinity;
    for (var d = 0; d < 31; d++) {
      for (final p in route.stepMarkerOutline(d)) {
        for (final q in route.stepMarkerOutline(d + 1)) {
          smallest = math.min(smallest, (p - q).distance);
        }
      }
    }
    expect(smallest * scale, greaterThanOrEqualTo(5));
  });

  test('each step marker is turned with the trail (Batch 3c d)', () {
    final metric = route.path.computeMetrics().single;
    for (var d = 0; d <= 31; d++) {
      final t = metric.getTangentForOffset(metric.length * d / 31)!;
      expect(route.stepAngle(d),
          closeTo(math.atan2(t.vector.dy, t.vector.dx), 1e-6));
    }
    // The flat first leg is not drawn level: the pills tilt with it.
    expect(route.stepAngle(1), lessThan(-.1));
  });
}
