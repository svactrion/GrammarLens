import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_day.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_debug_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// `--dart-define=CLIMB_DEBUG_THEME=<id>`: debug builds only, display only,
/// usable with CLIMB_DEBUG_DAY.
void main() {
  tearDown(() {
    ClimbDebugTheme.valueForTesting = null;
    ClimbDebugDay.valueForTesting = null;
  });

  test('release ignores it (N27): debug and profile builds apply it', () {
    for (final theme in ClimbThemes.all) {
      expect(
          ClimbDebugTheme.resolve(enabled: false, defined: theme.id), isNull);
      expect(ClimbDebugTheme.resolve(enabled: true, defined: theme.id), theme);
    }
    expect(ClimbDebugTheme.resolve(enabled: true, defined: ''), isNull);
    // An unknown id has no effect (it does not fall back to Green Slope).
    expect(ClimbDebugTheme.resolve(enabled: true, defined: 'ember'), isNull);
  });

  test('the test suite runs without the define', () {
    expect(ClimbDebugTheme.value, isNull);
  });

  Widget mountain({int steps = 3}) => MaterialApp(
      theme: buildAppTheme(Brightness.dark),
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                  width: 341.25,
                  child: MonthlyMountain(
                      days: 31,
                      completedDays: steps,
                      avatar: Avatar.values.first)))));

  String drawn(WidgetTester tester) => (tester
          .widget<Image>(find
              .descendant(
                  of: find.byType(MonthlyMountain),
                  matching: find.byType(Image))
              .first)
          .image as AssetImage)
      .assetName;

  testWidgets('set, the scene shows that theme instead of the month\'s',
      (tester) async {
    ClimbDebugTheme.valueForTesting = 'red_canyon';
    await tester.pumpWidget(mountain());
    await tester.pumpAndSettle();
    final widget = tester.widget<MonthlyMountain>(find.byType(MonthlyMountain));
    expect(widget.theme, ClimbThemes.greenSlope); // the month's, unchanged
    expect(drawn(tester), 'assets/climb/red_canyon/background_dark.webp');
    expect(find.bySemanticsLabel(RegExp('^Red Canyon\\.')), findsOneWidget);
  });

  testWidgets('with CLIMB_DEBUG_DAY: that theme on that day', (tester) async {
    ClimbDebugTheme.valueForTesting = 'glacier_peak';
    ClimbDebugDay.valueForTesting = 31;
    await tester.pumpWidget(mountain());
    await tester.pumpAndSettle();
    expect(drawn(tester), 'assets/climb/glacier_peak/background_dark.webp');
    const camera = ClimbCamera(341.25);
    expect(tester.getSize(find.byType(AvatarTile)).width,
        closeTo(camera.avatarTileAt(ClimbRoute(31).arcAt(31)), 1e-6));
    expect(find.bySemanticsLabel(RegExp('31 of 31 steps')), findsOneWidget);
  });
}
