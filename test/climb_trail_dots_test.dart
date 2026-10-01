import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Scene art G5: faint dots on the passed days only, on the trail; future
/// days are not marked; one switch turns them off.
void main() {
  const width = 341.25;
  const camera = ClimbCamera(width);

  Widget mountain(int steps,
          {bool? dots, Brightness brightness = Brightness.light}) =>
      MaterialApp(
          theme: buildAppTheme(brightness),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: width,
                      child: MonthlyMountain(
                          days: 31,
                          completedDays: steps,
                          avatar: Avatar.values.first,
                          showPassedDayDots:
                              dots ?? MonthlyMountain.passedDayDots)))));

  Iterable<ClimbTrailDots> painters(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((p) => p.painter)
      .whereType<ClimbTrailDots>();

  test('the switch is on: the dots are the default', () {
    expect(MonthlyMountain.passedDayDots, isTrue);
  });

  testWidgets('on day 8, a dot on each of days 1–7 and on no other step',
      (tester) async {
    await tester.pumpWidget(mountain(8));
    final dots = painters(tester).single;
    final route = ClimbRoute(31);
    expect(dots.points, [
      for (var d = 1; d <= 7; d++) route.stepAt(d) * camera.scale,
    ]);
  });

  testWidgets('on day 0 and day 1 there are no dots yet', (tester) async {
    for (final steps in [0, 1]) {
      await tester.pumpWidget(mountain(steps));
      expect(painters(tester).single.points, isEmpty, reason: 'day $steps');
    }
  });

  testWidgets('a dot appears on the step the avatar has just left',
      (tester) async {
    await tester.pumpWidget(mountain(8));
    expect(painters(tester).single.points, hasLength(7));
    await tester.pumpWidget(mountain(9));
    await tester.pump(const Duration(milliseconds: 100));
    expect(painters(tester).single.points, hasLength(8));
    await tester.pumpAndSettle();
    expect(painters(tester).single.points, hasLength(8));
  });

  testWidgets('faint, in the palette\'s ink, in both modes', (tester) async {
    for (final b in Brightness.values) {
      await tester.pumpWidget(mountain(8, brightness: b));
      // MaterialApp animates a theme change; read the settled palette.
      await tester.pumpAndSettle();
      final dots = painters(tester).single;
      expect(dots.color, ClimbThemes.greenSlope.paletteFor(b).ink);
      expect(ClimbTrailDots.opacity, lessThanOrEqualTo(.25));
      expect(ClimbTrailDots.diameter, lessThanOrEqualTo(4));
    }
  });

  testWidgets('switched off, no dots are drawn', (tester) async {
    await tester.pumpWidget(mountain(20, dots: false));
    expect(painters(tester), isEmpty);
  });
}
