import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';

void main() {
  Future<void> fillNameAndGoal(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.ensureVisible(find.text('Exam prep'));
    await tester.tap(find.text('Exam prep'));
    await tester.pump();
  }

  Future<void> tapContinue(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Continue'));
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
  }

  /// Whichever avatar's own `Semantics` label currently sits at the
  /// carousel's horizontal center — i.e. whichever avatar is actually
  /// selected right now, read the same way a screen reader would, not
  /// from any private state.
  String centeredAvatarLabel(WidgetTester tester) {
    final center = tester.getCenter(find.byType(PageView)).dx;
    for (final avatar in Avatar.values) {
      final finder = find.bySemanticsLabel(avatar.semanticLabel);
      if (finder.evaluate().isEmpty) continue;
      final rect = tester.getRect(finder);
      if (rect.left <= center && center <= rect.right) {
        return avatar.semanticLabel;
      }
    }
    throw StateError('no centered avatar found');
  }

  testWidgets(
    'the privacy note no longer claims data never leaves the device — it '
    'names the AI provider and usage/crash data honestly',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: (_) {})),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(onboardingPrivacyNote));
      expect(find.text(onboardingPrivacyNote), findsOneWidget);
      expect(find.textContaining('never sent'), findsNothing);
      expect(find.textContaining('Stored only'), findsNothing);
      expect(onboardingPrivacyNote, contains('AI provider'));
      expect(onboardingPrivacyNote, contains('usage and crash data'));
    },
  );

  testWidgets(
    'completing onboarding without ever touching the avatar carousel '
    'still assigns a real avatar — no empty state (PRD v2 §13.5)',
    (tester) async {
      UserProfile? completed;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: (p) => completed = p)),
      );
      await tester.pumpAndSettle();

      await fillNameAndGoal(tester);
      await tapContinue(tester);

      expect(completed, isNotNull);
      expect(completed!.avatar, isNotNull);
      expect(Avatar.values, contains(completed!.avatar));
    },
  );

  testWidgets(
    'the avatar carousel sits above the name step — face and name are one '
    'identity screen, not two',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: (_) {})),
      );
      await tester.pumpAndSettle();

      final carouselTop = tester.getTopLeft(find.byType(PageView)).dy;
      final nameFieldTop = tester.getTopLeft(find.byType(TextField)).dy;
      expect(carouselTop, lessThan(nameFieldTop));
    },
  );

  testWidgets(
    'the embedded carousel has no Done button — only the full-screen '
    "Settings picker (AvatarPickerScreen) does; onboarding's own "
    'Continue button already covers confirming the whole form',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: (_) {})),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
    },
  );

  testWidgets(
    'swiping the carousel before continuing changes which avatar is '
    'actually submitted, not a value re-rolled independently at submit '
    'time',
    (tester) async {
      UserProfile? completed;
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(onComplete: (p) => completed = p)),
      );
      await tester.pumpAndSettle();

      final before = centeredAvatarLabel(tester);

      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // The carousel starts on a random avatar (no seam to fix it for this
      // test) — if that happened to land near the end of the list, a
      // forward drag has nowhere further to go and settles right back
      // where it started (PageView clamps, it doesn't wrap). Retry the
      // other direction rather than let the test flake on that boundary.
      var after = centeredAvatarLabel(tester);
      if (after == before) {
        await tester.drag(find.byType(PageView), const Offset(500, 0));
        await tester.pumpAndSettle();
        after = centeredAvatarLabel(tester);
      }
      expect(after, isNot(before));

      await fillNameAndGoal(tester);
      await tapContinue(tester);

      expect(completed, isNotNull);
      expect(completed!.avatar!.semanticLabel, after);
    },
  );
}
