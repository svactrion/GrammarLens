import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app.dart';

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

  testWidgets('onboarding requires both a name and a goal before continuing',
      (tester) async {
    await tester.pumpWidget(const GrammarLensApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    FilledButton continueButton() =>
        tester.widget(find.widgetWithText(FilledButton, 'Continue'));

    expect(continueButton().onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();
    expect(continueButton().onPressed, isNull,
        reason: 'a goal still hasn\'t been picked');

    await tester.tap(find.text('Exam prep'));
    await tester.pump();
    expect(continueButton().onPressed, isNotNull);
  });

  testWidgets(
      'onboarding states the collected info stays on-device (PRD v2 §10.1)',
      (tester) async {
    await tester.pumpWidget(const GrammarLensApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(
      find.text('Stored only on this device — never sent to a server.'),
      findsOneWidget,
    );
  });
}
