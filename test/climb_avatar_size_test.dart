import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Scene art G3: the avatar's ground shadow (its footprint, 0.65 of the
/// tile) fits the trail's horizontal width; toward the summit, where the
/// trail narrows, the avatar shrinks over several days to a floor.
void main() {
  // Home's card widths on 320, 375 and 430 pt screens.
  const cardWidths = [288.0, 341.25, 391.3];

  test('the base size: about 27–37 pt with K-b 1.1×, never above 42.3 pt', () {
    final bases = [
      for (final w in cardWidths) ClimbCamera(w).baseAvatarTile,
    ];
    expect(bases[0], inInclusiveRange(25, 42.3));
    expect(bases[1], inInclusiveRange(bases[0], 42.3));
    expect(bases[2], inInclusiveRange(bases[1], 42.3));
    for (final b in bases) {
      expect(b, lessThanOrEqualTo(ClimbCamera.maxAvatarTile));
    }
  });

  for (final width in cardWidths) {
    test(
        '$width pt: on every day before the summit the footprint fits the '
        'trail', () {
      final camera = ClimbCamera(width);
      for (var days = 28; days <= 31; days++) {
        final route = ClimbRoute(days);
        for (var d = 0; d < days; d++) {
          final s = route.arcAt(d.toDouble());
          final footprint = camera.avatarTileAt(s) * ClimbCamera.footprintShare;
          expect(footprint,
              lessThanOrEqualTo(ClimbRoute.chordAt(s) * camera.scale + 1e-9),
              reason: '$days days, day $d');
        }
      }
      // And along the trail itself, up to 99 % of its length (only the
      // tip is narrower than the floor).
      for (var s = 0.0;
          s <= ClimbRoute.length * .99;
          s += ClimbRoute.length / 1000) {
        expect(camera.avatarTileAt(s) * ClimbCamera.footprintShare,
            lessThanOrEqualTo(ClimbRoute.chordAt(s) * camera.scale + 1e-9),
            reason: 'at ${(s / ClimbRoute.length).toStringAsFixed(3)}');
      }
    });

    test(
        '$width pt: at the summit the avatar shrinks gradually, to the '
        'floor', () {
      final camera = ClimbCamera(width);
      final base = camera.baseAvatarTile;
      for (var days = 28; days <= 31; days++) {
        final route = ClimbRoute(days);
        final sizes = [
          for (var d = 0; d <= days; d++)
            camera.avatarTileAt(route.arcAt(d.toDouble()))
        ];
        // The summit: the floor, not below it.
        expect(sizes.last, closeTo(base * ClimbCamera.shrinkFloor, 1e-9));
        for (final size in sizes) {
          expect(size, greaterThanOrEqualTo(base * ClimbCamera.shrinkFloor));
        }
        // Several days get smaller, none by more than 15 % of the base,
        // and the size never grows back.
        var shrinking = 0;
        for (var d = 1; d <= days; d++) {
          final drop = sizes[d - 1] - sizes[d];
          expect(drop, greaterThanOrEqualTo(-1e-9), reason: 'day $d');
          expect(drop, lessThanOrEqualTo(base * .15), reason: 'day $d');
          if (drop > 1e-9) shrinking++;
        }
        expect(shrinking, greaterThanOrEqualTo(4), reason: '$days days');
      }
    });
  }

  for (final day in [12, 31]) {
    testWidgets('the drawn avatar has the size for its place: day $day',
        (tester) async {
      const width = 341.25;
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
      const camera = ClimbCamera(width);
      expect(
          tester.getSize(find.byType(AvatarTile)).width,
          closeTo(
              camera.avatarTileAt(ClimbRoute(31).arcAt(day.toDouble())), 1e-6));
    });
  }
}
