import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';

/// Design decision K1, kept for the image's trail (scene art S2): at 320 pt
/// in a 31-day month a day's step is at least 17 pt. The 31-day month has
/// the shortest steps; 288 pt is the card on a 320 pt screen.
void main() {
  const camera = ClimbCamera(288);
  final route = ClimbRoute(31);

  test('a day\'s step is at least 17 pt', () {
    expect(ClimbRoute.length / 31 * camera.scale, greaterThanOrEqualTo(17));
    // And as drawn: the shortest distance between two consecutive steps.
    var shortest = double.infinity;
    for (var d = 1; d <= 31; d++) {
      shortest =
          math.min(shortest, (route.stepAt(d) - route.stepAt(d - 1)).distance);
    }
    expect(shortest * camera.scale, greaterThanOrEqualTo(17));
  });
}
