import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/paywall_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';

void main() {
  Future<void> pumpPremium(WidgetTester tester) async {
    // The default test surface (800x600 logical px) is too short to lay
    // out every feature tile + the CTA button without scrolling, and
    // ListView only mounts what's within the viewport + cache extent — a
    // taller, phone-realistic size is what actually makes every widget
    // here reachable by find()/tap(), same fix home_screen_test.dart uses
    // for its own cards.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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
    expect(find.textContaining('early access'), findsNothing);
    // PRD v2 §6/§12.2: never say "free forever" or unqualified "free" for
    // Topic Practice — that promise stopped being true once it moved to
    // trial-then-paid. Daily Test is the one thing genuinely free/always.
    expect(find.textContaining('forever'), findsNothing);
  });

  testWidgets(
      'reflects the real free/trial/paid split (PRD v2 §12.2), not "free '
      'while in early access"', (tester) async {
    await pumpPremium(tester);
    expect(find.text('Daily Test'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Topic Practice'), findsOneWidget);
    expect(find.text('3-day trial'), findsOneWidget);
  });

  testWidgets('lists premium features with a coming-soon status',
      (tester) async {
    await pumpPremium(tester);
    // The revised, longer early-access copy pushes these two tiles below
    // the fold even at a tall test viewport — scroll them into the
    // Sliver's build range rather than assuming they're already mounted.
    await tester.scrollUntilVisible(find.text('AI Practice Partner'), 300);
    expect(find.text('Unlimited Streak Mode'), findsOneWidget);
    expect(find.text('AI Practice Partner'), findsOneWidget);
    expect(find.text('Coming soon'), findsNWidgets(2));
  });

  testWidgets('has no hardcoded price and no direct buy/subscribe action',
      (tester) async {
    await pumpPremium(tester);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.textContaining('\$'), findsNothing);
    expect(find.textContaining('Buy'), findsNothing);
    expect(find.textContaining('Subscribe'), findsNothing);
    expect(find.textContaining('Upgrade'), findsNothing);
  });

  testWidgets('"Start free trial" navigates to the paywall screen',
      (tester) async {
    await pumpPremium(tester);
    expect(find.byType(PaywallScreen), findsNothing);

    final startTrialButton = find.widgetWithText(FilledButton, 'Start free trial');
    await tester.scrollUntilVisible(startTrialButton, 300);
    await tester.ensureVisible(startTrialButton);
    await tester.tap(startTrialButton);
    // Not pumpAndSettle: PremiumScreen pushes a real (unfaked)
    // PaywallScreen here, whose initial load hits RevenueCat's platform
    // channel — which just hangs forever with no engine to answer it in a
    // plain widget test (see paywall_screen_test.dart's own note on this).
    // A few pumps are enough to carry the push's route transition to
    // completion without waiting on that load to ever settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(PaywallScreen), findsOneWidget);
  });
}
