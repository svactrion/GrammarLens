import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Framing K-b 1.3× (scene art G2): the image fitted to the window's width
/// and zoomed 1.3×, the camera following the pawn on both axes and never
/// showing past the image. The camera is its own layer (D3).
void main() {
  // Home's card widths on 320, 375 and 430 pt screens.
  const cardWidths = [288.0, 341.25, 391.3];

  test('one zoom constant: 1.3×, the image fitted to the width and zoomed', () {
    expect(ClimbCamera.zoom, 1.3);
    for (final width in cardWidths) {
      final camera = ClimbCamera(width);
      expect(camera.imageSize.width, closeTo(width * 1.3, 1e-9));
      expect(camera.imageSize.height, closeTo(width * 1.3 * 4 / 3, 1e-6));
    }
  });

  test(
      'on no day, and at no moment between days, the window shows past '
      'the image', () {
    for (final width in cardWidths) {
      final camera = ClimbCamera(width);
      for (var days = 28; days <= 31; days++) {
        final route = ClimbRoute(days);
        for (var tick = 0; tick <= days * 20; tick++) {
          final o = camera.offsetFor(route.pointAt(tick / 20));
          final why = '$width pt, $days days, day ${tick / 20}';
          expect(o.dx, greaterThanOrEqualTo(0), reason: why);
          expect(o.dy, greaterThanOrEqualTo(0), reason: why);
          expect(o.dx + width, lessThanOrEqualTo(camera.imageSize.width + 1e-9),
              reason: why);
          expect(o.dy + ClimbCamera.windowHeight,
              lessThanOrEqualTo(camera.imageSize.height + 1e-9),
              reason: why);
        }
      }
    }
  });

  test('the pawn is centered across and at 72 % down, unless clamped', () {
    for (final width in cardWidths) {
      final camera = ClimbCamera(width);
      final maxX = camera.imageSize.width - width;
      final maxY = camera.imageSize.height - 350;
      var followedX = 0, followedY = 0;
      for (var s = 0.0; s <= ClimbRoute.length; s += ClimbRoute.length / 400) {
        final p = ClimbRoute.at(s);
        final o = camera.offsetFor(p);
        final w = camera.toWindow(p, o);
        if (o.dx > 0 && o.dx < maxX) {
          followedX++;
          expect(w.dx, closeTo(width / 2, 1e-9));
        }
        if (o.dy > 0 && o.dy < maxY) {
          followedY++;
          expect(w.dy, closeTo(350 * .72, 1e-9));
        }
      }
      // Both axes really follow for most of the trail.
      expect(followedX, greaterThan(100), reason: '$width pt');
      expect(followedY, greaterThan(100), reason: '$width pt');
      // At the foot the pawn is no higher than 72 % (the window may stop
      // at the image's bottom); at the summit the window stops at the top.
      expect(
          camera
              .toWindow(ClimbRoute.foot, camera.offsetFor(ClimbRoute.foot))
              .dy,
          greaterThanOrEqualTo(350 * .72 - 1e-9));
      expect(camera.offsetFor(ClimbRoute.summit).dy, 0);
    }
  });

  for (final width in cardWidths) {
    for (final day in [0, 12, 31]) {
      testWidgets(
          'a $width pt card, day $day: the image covers the window and '
          'the avatar stands on its step', (tester) async {
        await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(Brightness.light),
            home: Scaffold(
                body: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                        width: width,
                        child: MonthlyMountain(
                            days: 31,
                            completedDays: day,
                            avatar: Avatar.values.first))))));
        await tester.pump();
        final window = tester.getRect(find.byType(MonthlyMountain));
        expect(window.height, ClimbCamera.windowHeight);
        // The layer the camera moves: it covers the whole window.
        final image = tester.getRect(find.byType(Image).first);
        expect(image.left, lessThanOrEqualTo(window.left + 1e-6));
        expect(image.top, lessThanOrEqualTo(window.top + 1e-6));
        expect(image.right, greaterThanOrEqualTo(window.right - 1e-6));
        expect(image.bottom, greaterThanOrEqualTo(window.bottom - 1e-6));
        // The avatar's feet on the step: its tile's top is 55/58 of its
        // side above the step.
        final camera = ClimbCamera(width);
        final step = ClimbRoute(31).stepAt(day);
        final onScreen = camera.toWindow(step, camera.offsetFor(step));
        final avatar = tester.getRect(find.byType(AvatarTile));
        expect(avatar.center.dx - window.left, closeTo(onScreen.dx, .1));
        expect(avatar.top - window.top,
            closeTo(onScreen.dy - avatar.height * 55 / 58, .1));
      });
    }
  }
}
