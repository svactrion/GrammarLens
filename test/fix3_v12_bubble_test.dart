import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/first_climb_screen.dart';
import 'package:grammar_lens/widgets/anchored_bubble.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';

import 'support/fix3_render.dart';

/// Fix round 3, C3 (SPEC V12, v11): "First step done! 29 to the summit."
/// opens right above the companion when the walk is over: the tail's tip
/// 12 pt above its head and under its centre, the bubble at least 16 pt
/// from the screen's sides; below with the tail up when there is no room
/// above. Checked at B1's five sizes (and 393 × 852). With
/// `FIX3_CAPTURE=1` the end frames render to `build/fix3-captures/`.
void main() {
  final body = find.byKey(AnchoredBubble.bodyKey);
  final tailDown = find.byKey(AnchoredBubble.tailDownKey);
  final tailUp = find.byKey(AnchoredBubble.tailUpKey);

  for (final (size, top, bottom) in const [
    (Size(375, 667), 20.0, 0.0),
    (Size(390, 844), 47.0, 34.0),
    (Size(393, 852), 59.0, 34.0),
    (Size(402, 874), 62.0, 34.0),
    (Size(428, 926), 47.0, 34.0),
    (Size(440, 956), 62.0, 34.0),
  ]) {
    final name = '${size.width.toInt()}x${size.height.toInt()}';
    testWidgets('$name: the bubble right above the companion', (tester) async {
      await pumpFix3(
        tester,
        FirstClimbScreen(
          theme: ClimbThemes.emberPeak,
          hero: Avatar.fox,
          days: 30,
          onContinue: () {},
        ),
        size: size,
        top: top,
        bottom: bottom,
      );
      final companion = tester.getRect(find.descendant(
          of: find.byType(MountainScene),
          matching: find.byType(CompanionView)));
      expect(companion.size, const Size.square(FirstClimbScreen.avatarSize));
      final bubble = tester.getRect(body);
      final tail = tester.getRect(tailDown);
      final tip = tail.center.dy + AnchoredBubble.tailReach;
      expect(tip, closeTo(companion.top - AnchoredBubble.gap, .5),
          reason: 'the tail\'s tip 12 pt above the head');
      expect(tail.center.dx, closeTo(companion.center.dx, .5),
          reason: 'the tail under the companion\'s centre');
      expect(tail.center.dy, closeTo(bubble.bottom, .5));
      expect(bubble.left, greaterThanOrEqualTo(AnchoredBubble.edge - .01));
      expect(bubble.right,
          lessThanOrEqualTo(size.width - AnchoredBubble.edge + .01));
      // Between the step chip and Continue.
      final chip = tester.getRect(find.text('Step 1 of 30'));
      final button = tester.getRect(find.byKey(FirstClimbScreen.continueKey));
      expect(bubble.top, greaterThan(chip.bottom));
      expect(bubble.bottom, lessThan(button.top));
      expect(find.text('First step done! 29 to the summit.'), findsOneWidget);
      await fix3Capture(tester, 'V12-end-$name');
      if (size == const Size(390, 844)) {
        await pumpFix3(
          tester,
          FirstClimbScreen(
            theme: ClimbThemes.emberPeak,
            hero: Avatar.fox,
            days: 30,
            onContinue: () {},
          ),
          size: size,
          top: top,
          bottom: bottom,
          brightness: Brightness.dark,
        );
        await fix3Capture(tester, 'V12-end-$name', dark: true);
      }
    });
  }

  Future<void> pumpBubble(WidgetTester tester, Rect anchor) => pumpFix3(
        tester,
        Stack(children: [
          Positioned.fill(
            child: AnchoredBubble(
              anchor: anchor,
              text: 'First step done! 29 to the summit.',
              minTop: 150,
              maxBottom: 760,
            ),
          ),
        ]),
        size: const Size(390, 844),
      );

  testWidgets('no room above: it opens below, the tail up at the companion',
      (tester) async {
    const anchor = Rect.fromLTWH(160, 120, 64, 64);
    await pumpBubble(tester, anchor);
    final bubble = tester.getRect(body);
    final tail = tester.getRect(tailUp);
    expect(tail.center.dy - AnchoredBubble.tailReach,
        closeTo(anchor.bottom + AnchoredBubble.gap, .5));
    expect(tail.center.dx, closeTo(anchor.center.dx, .5));
    expect(tail.center.dy, closeTo(bubble.top, .5));
    expect(tester.getRect(tailDown).top, lessThan(-1000));
  });

  testWidgets(
      'a companion at the edge: the bubble stays 16 pt in, the tail moves '
      'towards the companion (off the corner)', (tester) async {
    const anchor = Rect.fromLTWH(330, 600, 64, 64);
    await pumpBubble(tester, anchor);
    final bubble = tester.getRect(body);
    final tail = tester.getRect(tailDown);
    expect(bubble.right, closeTo(390 - AnchoredBubble.edge, .5));
    expect(
        tail.center.dx, closeTo(bubble.right - AnchoredBubble.tailInset, .5));
    expect(tail.center.dy + AnchoredBubble.tailReach,
        closeTo(anchor.top - AnchoredBubble.gap, .5));
  });
}
