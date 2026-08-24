import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/app.dart';

void main() {
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
}
