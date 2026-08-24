import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/premium_screen.dart';

void main() {
  Future<void> pumpPremium(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PremiumScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('states the early-access message without an unbounded promise',
      (tester) async {
    await pumpPremium(tester);
    expect(
      find.textContaining("one of our first users"),
      findsOneWidget,
    );
    expect(find.textContaining('early access'), findsWidgets);
    // PRD v2 §6: never say "free forever" or unqualified "free" — that
    // promise becomes a constraint once real pricing ships.
    expect(find.textContaining('forever'), findsNothing);
  });

  testWidgets('lists premium features with a coming-soon status',
      (tester) async {
    await pumpPremium(tester);
    expect(find.text('Unlimited Streak Mode'), findsOneWidget);
    expect(find.text('AI Voice Practice'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(2));
  });

  testWidgets('has no payment flow: no price, buy button, or card field',
      (tester) async {
    await pumpPremium(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.textContaining('\$'), findsNothing);
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.textContaining('Subscribe'), findsNothing);
    expect(find.textContaining('Upgrade'), findsNothing);
  });
}
