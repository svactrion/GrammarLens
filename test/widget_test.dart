import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';

void main() {
  // Welcome's ambient decorations (breathing mark, scan rings, drifting
  // background glow, twinkle dots) animate on an infinite loop by design,
  // which never lets `pumpAndSettle()` find a quiet frame — the same
  // class of hang any perpetual animation (e.g. a spinner) causes in
  // widget tests. Reporting "reduce motion" here exercises this app's
  // real accessibility path (see welcome_screen.dart) instead of working
  // around the hang some other way.
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('shows the welcome screen on a fresh install', (tester) async {
    // sqflite has no platform channel in the plain widget-test environment,
    // so `getUserProfile()` throws and the app falls back to onboarding —
    // the same path a genuinely fresh install takes.
    await tester.pumpWidget(const GrammarLensApp());
    await tester.pumpAndSettle();

    expect(find.text('GrammarLens'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
  });

  testWidgets(
      'onboarding requires a name to continue, then a goal (or Skip) to start',
      (tester) async {
    await tester.pumpWidget(const GrammarLensApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    FilledButton button(String label) =>
        tester.widget(find.widgetWithText(FilledButton, label));

    expect(button('Continue').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect(button('Continue').onPressed, isNotNull);

    // 1.2.0: the goal is its own step after the name.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    expect(button('Start my first test').onPressed, isNull,
        reason: 'a goal still hasn\'t been picked');
    expect(find.text('Skip goal & start'), findsOneWidget);

    await tester.tap(find.text('Exam prep'));
    await tester.pump();
    expect(button('Start my first test').onPressed, isNotNull);
  });

  testWidgets(
      'onboarding shows the accurate privacy note (PRD v2 §10.1, §13.9)',
      (tester) async {
    await tester.pumpWidget(const GrammarLensApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    // On the goal step since 1.2.0.
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(onboardingPrivacyNote));

    expect(find.text(onboardingPrivacyNote), findsOneWidget);
    expect(find.textContaining('never sent'), findsNothing);
  });
}
