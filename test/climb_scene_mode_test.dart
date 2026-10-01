import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Scene art S4/G7: the scene is the theme's light image in light mode and
/// its dark (dusk) image in dark mode. Stage 1: only Green Slope has
/// images, so every month draws Green Slope's.
void main() {
  String drawnAsset(WidgetTester tester) => (tester
          .widget<Image>(find
              .descendant(
                  of: find.byType(MonthlyMountain),
                  matching: find.byType(Image))
              .first)
          .image as AssetImage)
      .assetName;

  Widget mountain(Brightness b) => MaterialApp(
      theme: buildAppTheme(b),
      home: Scaffold(
          body: SizedBox(
              width: 341.25,
              child: MonthlyMountain(
                  days: 30, completedDays: 5, avatar: Avatar.values.first))));

  testWidgets('light mode: Green Slope\'s light image', (tester) async {
    await tester.pumpWidget(mountain(Brightness.light));
    expect(
        drawnAsset(tester), 'assets/climb/green_slope/background_light.webp');
  });

  testWidgets('dark mode: Green Slope\'s dark image', (tester) async {
    await tester.pumpWidget(mountain(Brightness.dark));
    expect(drawnAsset(tester), 'assets/climb/green_slope/background_dark.webp');
  });

  test('every month of the rotation is shown as Green Slope for now', () {
    // A year from the anchor covers every theme of the rotation.
    for (var i = 0; i < 12; i++) {
      final month = DateTime(2026, 10 + i);
      expect(ClimbThemeRotation.scheduledFor(month.year, month.month),
          isA<ClimbTheme>());
      expect(ClimbThemeRotation.shownFor(month.year, month.month),
          ClimbThemes.greenSlope,
          reason: '${month.year}-${month.month}');
    }
    // The one ready theme has both images.
    for (final theme in ClimbThemes.all.where((t) => t.ready)) {
      expect(theme.backgroundLight, isNotNull);
      expect(theme.backgroundDark, isNotNull);
    }
  });
}
