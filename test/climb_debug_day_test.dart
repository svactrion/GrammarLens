import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_day.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// `--dart-define=CLIMB_DEBUG_DAY=<n>`: debug builds only, display only.
void main() {
  tearDown(() => ClimbDebugDay.valueForTesting = null);

  test('release ignores it (N27): debug and profile builds apply the day', () {
    for (final day in [0, 1, 15, 31]) {
      expect(ClimbDebugDay.resolve(enabled: false, defined: day), isNull);
      expect(ClimbDebugDay.resolve(enabled: true, defined: day), day);
    }
    // Not defined (−1): nothing, in any build.
    expect(ClimbDebugDay.resolve(enabled: true, defined: -1), isNull);
    expect(ClimbDebugDay.resolve(enabled: false, defined: -1), isNull);
  });

  test('the test suite runs without the define', () {
    expect(ClimbDebugDay.value, isNull);
  });

  const width = 341.25;
  Widget mountain(int steps) => MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                  width: width,
                  child: MonthlyMountain(
                      days: 31,
                      completedDays: steps,
                      avatar: Avatar.values.first)))));

  double avatarTop(WidgetTester tester) => tester
      .widget<Positioned>(find
          .ancestor(
              of: find.byType(AvatarTile), matching: find.byType(Positioned))
          .first)
      .top!;

  testWidgets('set, the scene shows that day instead of the real progress',
      (tester) async {
    ClimbDebugDay.valueForTesting = 27;
    await tester.pumpWidget(mountain(3));
    final widget = tester.widget<MonthlyMountain>(find.byType(MonthlyMountain));
    // The real progress is passed on unchanged.
    expect(widget.completedDays, 3);
    // The avatar stands on day 27, with day 27's (shrinking) size.
    const camera = ClimbCamera(width);
    final route = ClimbRoute(31);
    final tile = camera.avatarTileAt(route.arcAt(27));
    expect(tester.getSize(find.byType(AvatarTile)).width, closeTo(tile, 1e-6));
    expect(avatarTop(tester),
        closeTo(route.stepAt(27).dy * camera.scale - tile * 55 / 58, .01));
    expect(find.bySemanticsLabel(RegExp('27 of 31 steps')), findsOneWidget);
  });

  testWidgets('larger than the month, it stops at the summit', (tester) async {
    ClimbDebugDay.valueForTesting = 40;
    await tester.pumpWidget(mountain(3));
    expect(find.bySemanticsLabel(RegExp('31 of 31 steps')), findsOneWidget);
  });
}
