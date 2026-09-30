import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_table.dart';

import '../tool/climb_table/climb_table_generator.dart';

/// Design decision D3: the step table is generated from the frozen curve,
/// never written by hand, and a change to the curve must not go unnoticed.
void main() {
  test('the committed table is exactly what the curve generates', () {
    expect(File(climbTablePath).readAsStringSync(), generateClimbTable(),
        reason: 'the curve and the table disagree: run '
            'scripts/generate_climb_table.sh');
  });

  for (final days in [28, 29, 30, 31]) {
    test('$days-day month: one normalized entry per day, on the curve', () {
      final table = climbStepTable[days]!;
      expect(table, hasLength(days + 1));
      final route = ClimbRoute(days);
      for (var d = 0; d <= days; d++) {
        final (x, y) = table[d];
        expect(x, inInclusiveRange(0, 1));
        expect(y, inInclusiveRange(0, 1));
        final onCurve = route.pointAt(d.toDouble());
        expect((route.stepAt(d) - onCurve).distance, lessThan(.01),
            reason: 'day $d');
      }
      expect(route.stepAt(0),
          offsetMoreOrLessEquals(ClimbRoute.corners.first, epsilon: .01));
      expect(route.stepAt(days),
          offsetMoreOrLessEquals(ClimbRoute.summit, epsilon: .01));
    });
  }
}
