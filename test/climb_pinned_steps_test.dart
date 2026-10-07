import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/services/climb_milestones.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';

/// Batch 5, N31 and N32: each save point pinned to a step, on which the
/// avatar stands at the save point's point on the trail; the climb ends at
/// the flag's point (or, switched, at the trail's tip).
void main() {
  tearDown(() => ClimbRoute.debugEndsAtFlagOverride = null);

  test('the default ends at the flag', () {
    expect(ClimbRoute.endsAtFlagSetting, isTrue);
    expect(ClimbRoute.endsAtFlag, isTrue);
    expect(ClimbRoute.climbLength, climbFlagArc);
    expect(climbFlagArc, lessThan(ClimbRoute.length));
  });

  for (final atFlag in [true, false]) {
    final name = atFlag ? 'ending at the flag' : 'ending at the tip';
    for (var days = 28; days <= 31; days++) {
      test(
          '$days days, $name: on each save point\'s step the avatar stands '
          'on its point; the last step is the climb\'s end', () {
        ClimbRoute.debugEndsAtFlagOverride = atFlag;
        final route = ClimbRoute(days);
        var previous = 0;
        for (final p in ClimbSavePoints.all) {
          final step = p.reachedOn(days);
          expect(step, greaterThan(previous));
          expect(step, lessThanOrEqualTo(days - 2));
          previous = step;
          expect(route.arcAt(step.toDouble()), closeTo(p.arc, 1e-6));
          expect((route.stepAt(step) - ClimbRoute.at(p.arc)).distance,
              lessThan(1e-6));
          // Reached on its step, not on the one before.
          expect(p.reachedAt(route.arcAt(step.toDouble())), isTrue);
          expect(p.reachedAt(route.arcAt(step - 1.0)), isFalse);
        }
        final flag = ClimbSavePoints.flag;
        expect(flag.reachedOn(days), days);
        expect(route.arcAt(days.toDouble()),
            closeTo(atFlag ? climbFlagArc : ClimbRoute.length, 1e-6));
        expect(flag.reachedAt(route.arcAt(days.toDouble())), isTrue);
        expect(flag.reachedAt(route.arcAt(days - 1.0)), isFalse);
      });
    }
  }

  test('save_point_reached and the label follow the pinned step', () {
    for (var days = 28; days <= 31; days++) {
      for (final p in ClimbSavePoints.all) {
        final step = p.reachedOn(days);
        final m = ClimbMilestones.between(
            year: 2026,
            month: 10,
            theme: ClimbThemes.greenSlope,
            stepsBefore: step - 1,
            stepsAfter: step,
            scoreBefore: 0,
            scoreAfter: 0);
        // Between()'s month is October (31 days); the steps of [days].
        if (days == 31) expect(m.savePoints, [p]);
        expect(ClimbRoute.savePointSteps(days)[p.clearing], step);
      }
    }
  });
}
