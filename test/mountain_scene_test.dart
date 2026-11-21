import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';

/// The whole-mountain scene (V06, V12, R04, V24): the image always covers
/// its box — no empty band at any edge — at any zoom and focus.
void main() {
  test('cover: no empty band for wide, tall and square boxes', () {
    for (final box in const [
      Size(402, 620),
      Size(402, 300),
      Size(320, 900),
      Size(500, 500),
    ]) {
      for (final zoom in [1.0, 2.2]) {
        for (final focus in [null, ClimbRoute.foot, ClimbRoute.summit]) {
          final map = SceneMap(box, zoom: zoom, focus: focus);
          final o = map.origin;
          final s = map.imageSize;
          expect(o.dx, lessThanOrEqualTo(0.0001), reason: '$box $zoom');
          expect(o.dy, lessThanOrEqualTo(0.0001), reason: '$box $zoom');
          expect(o.dx + s.width, greaterThanOrEqualTo(box.width - .0001));
          expect(o.dy + s.height, greaterThanOrEqualTo(box.height - .0001));
        }
      }
    }
  });

  test('a zoomed map centres its focus when the image allows it', () {
    const box = Size(402, 874);
    final focus = ClimbRoute(30).stepAt(1);
    final map = SceneMap(box, zoom: 2.2, focus: focus);
    final p = map.toBox(focus);
    expect(p.dx, closeTo(box.width / 2, box.width / 2));
    expect(p.dy, inInclusiveRange(0, box.height));
  });

  testWidgets('draws the mountain, the flag and the avatar', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: SizedBox(
        width: 402,
        height: 620,
        child: MountainScene(
            theme: ClimbThemes.emberPeak, days: 30, avatar: Avatar.fox),
      ),
    ));
    await tester.pump();
    expect(find.byType(Image), findsWidgets);
    expect(find.bySemanticsLabel('Fox, your companion'), findsOneWidget);
  });
}
