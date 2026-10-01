import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// The camera places the scene's image in the 350 pt window (D3: its own
/// layer, separate from the trail's coordinates).
void main() {
  // Home's card widths on 320, 375 and 430 pt screens.
  const cardWidths = [288.0, 341.25, 391.3];

  test('the image fits the window\'s width, 3:4', () {
    for (final width in cardWidths) {
      final camera = ClimbCamera(width);
      expect(camera.imageSize.width, closeTo(width, 1e-9));
      expect(camera.imageSize.height, closeTo(width * 4 / 3, 1e-6));
    }
  });

  test('the pawn sits at 72 % of the window, clamped to the image', () {
    for (final width in cardWidths) {
      final camera = ClimbCamera(width);
      final maxY = camera.imageSize.height - 350;
      // At the foot: clamped to the image's bottom.
      expect(camera.offsetFor(ClimbRoute.foot).dy, closeTo(maxY, 1e-9));
      // At the summit: clamped to the image's top.
      expect(camera.offsetFor(ClimbRoute.summit).dy, 0);
      // Wherever it is not clamped, the pawn is at 72 %.
      for (var s = 0.0; s <= ClimbRoute.length; s += ClimbRoute.length / 200) {
        final p = ClimbRoute.at(s);
        final y = camera.offsetFor(p).dy;
        if (y > 0 && y < maxY) {
          expect(camera.toWindow(p, camera.offsetFor(p)).dy,
              closeTo(350 * .72, 1e-9));
        }
      }
    }
  });

  for (final width in cardWidths) {
    testWidgets('a $width pt card: the avatar standing on its step',
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
                          avatar: Avatar.values.first))))));
      await tester.pump();
      final mountain = tester.getRect(find.byType(MonthlyMountain));
      expect(mountain.height, ClimbCamera.windowHeight);
      final avatar = tester.getRect(find.byType(AvatarTile));
      final camera = ClimbCamera(width);
      final step = ClimbRoute(31).stepAt(12);
      final onScreen = camera.toWindow(step, camera.offsetFor(step));
      expect(avatar.center.dx - mountain.left, closeTo(onScreen.dx, .1));
      // The feet on the step: the tile's top is 55/58 of its side above.
      expect(avatar.top - mountain.top,
          closeTo(onScreen.dy - avatar.height * 55 / 58, .1));
    });
  }
}
