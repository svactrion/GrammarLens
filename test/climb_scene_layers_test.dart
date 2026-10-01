import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Scene art Stage 2: the scene's layers, bottom to top — the background,
/// the passed-day dots, the save points and the summit flag, the avatar.
void main() {
  testWidgets('drawn in order: background, dots, save points, flag, avatar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
            body: SizedBox(
                width: 341.25,
                child: MonthlyMountain(
                    days: 31,
                    completedDays: 12,
                    avatar: Avatar.values.first)))));
    // The layer the camera moves: the Stack holding the avatar.
    final layer = tester.widget<Stack>(find
        .ancestor(of: find.byType(AvatarTile), matching: find.byType(Stack))
        .first);
    int indexOf(bool Function(Widget child) test) =>
        layer.children.indexWhere((c) =>
            c is Positioned && test(c.child) ||
            c is Positioned && c.child is KeyedSubtree && test(c.child));
    final background = indexOf((c) => c is Image);
    final dots =
        indexOf((c) => c is CustomPaint && c.painter is ClimbTrailDots);
    final points = [
      for (final p in ClimbSavePoints.all)
        indexOf((c) => c.key == ValueKey('climb_save_point_${p.clearing}'))
    ];
    final flag = indexOf((c) => c.key == const ValueKey('climb_summit_flag'));
    final avatar = indexOf((c) => c is AvatarTile);
    expect([background, dots, ...points, flag, avatar].every((i) => i >= 0),
        isTrue,
        reason: 'background $background, dots $dots, points $points, '
            'flag $flag, avatar $avatar');
    expect(background, lessThan(dots));
    for (final i in points) {
      expect(i, greaterThan(dots));
      expect(i, lessThan(flag));
    }
    expect(flag, lessThan(avatar));
  });
}
