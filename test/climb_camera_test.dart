import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Framing F1 (design decision D5): 480 scene units of height in the 350 pt
/// window at every width, centered; the camera is its own layer (D3).
void main() {
  const camera = ClimbCamera();
  // Home's card widths on 320, 375 and 430 pt screens.
  const cardWidths = [288.0, 341.25, 391.3];

  test('the scale is the same at every width: 480 units in 350 pt', () {
    expect(camera.scale, closeTo(350 / 480, 1e-9));
    expect(camera.sceneHeight, closeTo(740 * 350 / 480, 1e-9));
  });

  test('the scene is centered in the window', () {
    for (final width in cardWidths) {
      final center = camera.toScreen(const Offset(160, 0), width).dx;
      expect(center, closeTo(width / 2, 1e-9));
    }
  });

  test('the pawn sits at 72 % of the window, clamped to the scene', () {
    const maxExtent = 740 * 350 / 480 - 350;
    // Low on the trail: clamped to the foot of the scene.
    expect(camera.scrollFor(const Offset(136, 700), 350, maxExtent),
        closeTo(maxExtent, 1e-9));
    // On the summit: clamped to the top.
    expect(camera.scrollFor(ClimbRoute.summit, 350, maxExtent), 0);
    // In between: at 72 %.
    const pawn = Offset(160, 500);
    expect(camera.scrollFor(pawn, 350, maxExtent),
        closeTo(500 * 350 / 480 - 350 * .72, 1e-9));
  });

  test('from day 17 of a 31-day month the summit flag is in the window', () {
    const maxExtent = 740 * 350 / 480 - 350;
    final route = ClimbRoute(31);
    for (var day = 17; day <= 31; day++) {
      final top =
          camera.scrollFor(route.pointAt(day.toDouble()), 350, maxExtent);
      // The flag reaches 36 units above the summit point.
      expect(
          (ClimbRoute.summit.dy - 36) * camera.scale, greaterThanOrEqualTo(top),
          reason: 'day $day');
    }
  });

  for (final width in cardWidths) {
    testWidgets('a $width pt card: 42.3 pt avatar standing on its step',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
              body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                      width: width,
                      child: MonthlyMountain(
                          days: 31,
                          completedDays: 12,
                          avatar: Avatar.values.first,
                          allowUserScroll: false))))));
      await tester.pump();
      final mountain = tester.getRect(find.byType(MonthlyMountain));
      expect(mountain.height, ClimbCamera.windowHeight);
      final avatar = tester.getRect(find.byType(AvatarTile));
      expect(avatar.width, closeTo(58 * 350 / 480, .01));
      // Horizontally: the step's x through the camera.
      final step = ClimbRoute(31).stepAt(12);
      expect(avatar.center.dx - mountain.left,
          closeTo(camera.toScreen(step, width).dx, .1));
      // Vertically: at 72 % of the window (day 12 is mid-trail).
      expect(avatar.bottom - 3 * camera.scale - mountain.top,
          closeTo(350 * .72, .1));
    });
  }
}
