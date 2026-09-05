import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';

void main() {
  testWidgets(
    'completing onboarding assigns one of the eight stock avatars, not '
    'the generic placeholder (PRD v2 §13.5)',
    (tester) async {
      UserProfile? completed;
      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingScreen(onComplete: (p) => completed = p),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Ada');
      await tester.tap(find.text('Exam prep'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pump();

      expect(completed, isNotNull);
      expect(completed!.avatar, isNotNull);
      expect(Avatar.values, contains(completed!.avatar));
    },
  );
}
