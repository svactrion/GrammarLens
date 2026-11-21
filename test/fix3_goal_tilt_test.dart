import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';

import 'support/fix3_render.dart';

/// Fix round 3, B3 (SPEC V05, v11): a selected goal card tilts by its
/// position, alternating: card 1 right (+2°), card 2 left (−2°), card 3
/// right, card 4 left (on the device cards 2 and 3 tilted the same way).
void main() {
  test('the tilt comes from the position, alternating', () {
    expect([for (var i = 0; i < 4; i++) GoalCard.tiltFor(i)],
        [2.0, -2.0, 2.0, -2.0]);
  });

  testWidgets('each card, selected in its place, turns that way',
      (tester) async {
    for (final (i, goal) in LearningGoal.values.indexed) {
      await pumpFix3(
          tester,
          Scaffold(
            body: Center(
              child: GoalCard(
                goal: goal,
                position: i,
                hero: Avatar.fox,
                selected: true,
                onTap: () {},
              ),
            ),
          ));
      final rotation = tester.widget<AnimatedRotation>(find.descendant(
          of: find.byType(GoalCard), matching: find.byType(AnimatedRotation)));
      expect(rotation.turns * 360, closeTo(i.isEven ? 2 : -2, 1e-9),
          reason: 'card ${i + 1}');
    }
  });
}
