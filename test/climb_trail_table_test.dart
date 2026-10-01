import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';

import '../tool/climb_table/climb_trail_generator.dart';

/// Design decision D3, fed by the image (scene art S2): the trail and the
/// step table are generated from the trail Scene Art Batch 0 extracted from
/// Green Slope's image, never written by hand, and a change to that trail
/// must not go unnoticed.
void main() {
  test('the committed table is exactly what the extracted trail generates',
      () {
    expect(File(climbTrailTablePath).readAsStringSync(),
        generateClimbTrailTable(),
        reason: 'the extracted trail and the table disagree: run '
            'scripts/generate_climb_trail.sh');
  });

  test('the trail runs from the foot (low, left) to the summit (high)', () {
    expect(climbTrail.length, greaterThan(500));
    expect(climbTrailChords, hasLength(climbTrail.length));
    for (final (x, y) in climbTrail) {
      expect(x, inInclusiveRange(0, 1));
      expect(y, inInclusiveRange(0, 1));
    }
    final (fx, fy) = climbTrail.first;
    final (sx, sy) = climbTrail.last;
    expect(fy, greaterThan(.8)); // beside the START flag
    expect(sy, lessThan(.2)); // under the snow cap
    expect(fx, lessThan(sx));
  });

  // Distance in image-width units.
  double dist((double, double) a, (double, double) b) {
    final dx = a.$1 - b.$1, dy = (a.$2 - b.$2) / climbImageAspect;
    return math.sqrt(dx * dx + dy * dy);
  }

  final length = [
    for (var i = 1; i < climbTrail.length; i++)
      dist(climbTrail[i - 1], climbTrail[i])
  ].reduce((a, b) => a + b);

  for (final days in [28, 29, 30, 31]) {
    test('$days-day month: one entry per day, from the foot to the summit',
        () {
      final table = climbStepTable[days]!;
      expect(table, hasLength(days + 1));
      expect(dist(table.first, climbTrail.first), lessThan(1e-4));
      expect(dist(table.last, climbTrail.last), lessThan(1e-4));
      // Evenly spaced by arc length: no straight step is longer than the
      // even share, and none is under 0.6 of it (the tight B5–B6 wiggle
      // under the summit shortens the chord most, to 0.65).
      for (var d = 1; d <= days; d++) {
        expect(dist(table[d - 1], table[d]), lessThan(length / days + 1e-4),
            reason: 'day $d');
        expect(dist(table[d - 1], table[d]), greaterThan(length / days * .6),
            reason: 'day $d');
      }
    });
  }
}
