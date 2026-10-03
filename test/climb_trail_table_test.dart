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
  test('the committed table is exactly what the extracted trail generates', () {
    expect(
        File(climbTrailTablePath).readAsStringSync(), generateClimbTrailTable(),
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

  // Batch 5 (N31, N32) replaced the even spacing over the whole trail: each
  // save point is pinned to a step, the days between pinned steps are even
  // by arc, and the climb ends at the flag's point (or the trail's tip).
  for (final (name, arcsByDays, stepsByDays, end) in [
    (
      'to the flag',
      climbStepArcsToFlag,
      climbSavePointStepsToFlag,
      climbFlagArc
    ),
    ('to the tip', climbStepArcsToTip, climbSavePointStepsToTip, length),
  ]) {
    for (final days in [28, 29, 30, 31]) {
      test(
          '$days-day month, $name: from the foot to the end, each save '
          'point on its step, spacing within 0.75–1.35 of even', () {
        final arcs = arcsByDays[days]!;
        expect(arcs, hasLength(days + 1));
        expect(arcs.first, 0);
        expect(arcs.last, closeTo(end, 1e-5));
        final steps = stepsByDays[days]!;
        final ordered = steps.values.toList();
        for (var k = 1; k < ordered.length; k++) {
          expect(ordered[k], greaterThan(ordered[k - 1]));
        }
        expect(ordered.last, lessThanOrEqualTo(days - 2));
        for (final MapEntry(key: clearing, value: step) in steps.entries) {
          expect(arcs[step], closeTo(climbSavePointArcs[clearing]!, 1e-5),
              reason: clearing);
          expect(step, (climbSavePointArcs[clearing]! / end * days).round());
        }
        final even = end / days;
        for (var d = 1; d <= days; d++) {
          final gap = arcs[d] - arcs[d - 1];
          expect(gap / even, inInclusiveRange(.75, 1.35), reason: 'day $d');
        }
      });
    }
  }
}
