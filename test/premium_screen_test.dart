import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/subscription_service.dart';

/// Real [SubscriptionService] methods go through RevenueCat's platform
/// channel, which just hangs forever in a plain widget test (no engine to
/// answer it, unlike a real device/simulator where an unconfigured SDK at
/// least throws and gets caught — see the class's own try/catch). Faking
/// the service here is what actually lets these tests exercise every
/// outcome path (unavailable / trial available / success / cancelled /
/// error) deterministically.
class _FakeSubscriptionService extends SubscriptionService {
  final Offering? offering;
  final PurchaseOutcome purchaseOutcome;
  int purchaseCalls = 0;

  _FakeSubscriptionService({
    this.offering,
    this.purchaseOutcome = PurchaseOutcome.failure,
  });

  @override
  Future<Offering?> getOfferings() async => offering;

  @override
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    purchaseCalls++;
    return purchaseOutcome;
  }

  @override
  Future<bool> restorePurchases() async => false;
}

Package _fakeMonthlyPackage() {
  const context = PresentedOfferingContext('default', null, null);
  const product = StoreProduct(
    'grammarlens_premium_monthly',
    'Full access to Topic Practice',
    'GrammarLens Premium (Monthly)',
    9.99,
    '\$9.99',
    'USD',
    introductoryPrice: IntroductoryPrice(
      0,
      '\$0.00',
      'P7D',
      1,
      PeriodUnit.day,
      7,
    ),
    subscriptionPeriod: 'P1M',
  );
  return const Package(
    '\$rc_monthly',
    PackageType.monthly,
    product,
    context,
  );
}

// pricePerMonth/pricePerMonthString are set explicitly here the way
// RevenueCat/StoreKit would compute and format them for a real annual
// product — a fake has no SDK behind it to derive these, so they're
// supplied directly, matching the $9.99/mo vs $89.99/yr numbers PRD v2
// §13.3 uses in its own "Save 25%" example ((9.99 - 7.49) / 9.99 ≈ 25%).
Package _fakeAnnualPackage() {
  const context = PresentedOfferingContext('default', null, null);
  const product = StoreProduct(
    'grammarlens_premium_annual',
    'Full access to Topic Practice (annual)',
    'GrammarLens Premium (Annual)',
    89.99,
    '\$89.99',
    'USD',
    introductoryPrice: IntroductoryPrice(
      0,
      '\$0.00',
      'P7D',
      1,
      PeriodUnit.day,
      7,
    ),
    subscriptionPeriod: 'P1Y',
    pricePerMonth: 7.49,
    pricePerMonthString: '\$7.49',
  );
  return const Package(
    '\$rc_annual',
    PackageType.annual,
    product,
    context,
  );
}

void main() {
  Future<void> pumpPremium(
    WidgetTester tester,
    SubscriptionService service, {
    String? sourceContext,
  }) async {
    // The default test surface (800x600 logical px) is too short to lay
    // out the table + purchase block + legal links without scrolling, and
    // ListView only mounts what's within the viewport + cache extent — a
    // taller, phone-realistic size is what actually makes every widget
    // here reachable by find()/tap().
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: PremiumScreen(
          subscriptionService: service,
          sourceContext: sourceContext,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // "Maybe later"/post-success "Continue" both pop this screen — that's
  // only observable by actually pushing it onto a real stack first, unlike
  // [pumpPremium] above which plants it as the app's sole route.
  Future<void> pumpPremiumPushed(
    WidgetTester tester,
    SubscriptionService service, {
    VoidCallback? onDone,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PremiumScreen(
                      subscriptionService: service,
                      onDone: onDone,
                    ),
                  ),
                ),
                child: const Text('open premium'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open premium'));
    await tester.pumpAndSettle();
  }

  // find.tap()'s default finder skips offstage elements, and a ListView
  // only paints what's within the current viewport — several actions sit
  // low enough in the scrollable list to start out genuinely offstage
  // (not just outside cache extent), so scroll each into the visible
  // viewport before tapping rather than assuming a taller test surface
  // alone would do it.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  // This screen is long enough that even a phone-tall test surface (see
  // pumpPremium) doesn't mount everything at once — Sliver virtualization
  // only builds what's within the viewport plus a small cache extent, so
  // anything further down genuinely isn't in the tree yet, not just
  // unpainted. Any assertion that something is *absent* from the whole
  // screen is only meaningful once every section has actually been built
  // at least once — this drags to the end for that, rather than trusting
  // a single scrollUntilVisible (which only guarantees its own target).
  Future<void> scrollToEnd(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
      'states the free/first-users message without an unbounded promise',
      (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    expect(find.textContaining("one of our first users"), findsOneWidget);
    expect(find.textContaining('early access'), findsNothing);
    expect(find.text('Early Access'), findsNothing);
    // PRD v2 §6/§12.2: never say "free forever" or unqualified "free" for
    // Topic Practice — that promise stopped being true once it moved to
    // trial-then-paid. Daily Test is the one thing genuinely free/always.
    expect(find.textContaining('forever'), findsNothing);
  });

  testWidgets(
      'reflects the real free/trial/paid split with the current trial '
      'length, not a hardcoded one', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    final trialBadge =
        find.text('${SubscriptionService.trialLengthDays}-day trial');
    await tester.scrollUntilVisible(trialBadge, 300);

    expect(find.text('Daily Test'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Topic Practice'), findsOneWidget);
    expect(trialBadge, findsOneWidget);
  });

  testWidgets(
      'leads with the personalized-feedback pitch, not a feature list',
      (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    expect(
      find.text('Personalized feedback, not a feature list'),
      findsOneWidget,
    );
  });

  testWidgets(
      'names the given sourceContext in the pitch instead of the generic '
      'headline', (tester) async {
    await pumpPremium(
      tester,
      _FakeSubscriptionService(offering: null),
      sourceContext: 'definite articles',
    );
    expect(
      find.text('Unlock personalized feedback on "definite articles"'),
      findsOneWidget,
    );
    expect(
      find.text('Personalized feedback, not a feature list'),
      findsNothing,
    );
  });

  group('nothing unbuilt is sold (PRD v2 §13.4)', () {
    testWidgets('lists no roadmap/coming-soon features anywhere on screen',
        (tester) async {
      await pumpPremium(tester, _FakeSubscriptionService(offering: null));
      await scrollToEnd(tester);
      expect(find.text('Unlimited Streak Mode'), findsNothing);
      expect(find.text('AI Practice Partner'), findsNothing);
      expect(find.text('Coming soon'), findsNothing);
    });

    testWidgets('has no invented social proof', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );
      await scrollToEnd(tester);
      expect(find.textContaining('most popular'), findsNothing);
      expect(find.textContaining('Most Popular'), findsNothing);
      expect(find.textContaining('thousands'), findsNothing);
      expect(find.textContaining('Join'), findsNothing);
    });
  });

  testWidgets(
      'with no RevenueCat product connected, shows an unavailable state '
      'instead of crashing or hanging', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    await scrollToEnd(tester);

    // No RevenueCat SDK key is configured on the simulator today either
    // (see docs/roadmap.md) — getOfferings() fails safe to null there too,
    // so this is the state real testing on-device is expected to hit.
    expect(
      find.text("Trial pricing isn't available right now"),
      findsOneWidget,
    );
    expect(find.text('Start free trial'), findsNothing);
    // The unavailable state shouldn't show any number at all, hardcoded
    // or otherwise — there's nothing real to show yet.
    expect(find.textContaining('\$'), findsNothing);
  });

  testWidgets('Restore Purchases is always reachable and never crashes',
      (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));

    await scrollAndTap(tester, find.text('Restore Purchases'));

    expect(
      find.textContaining('No previous purchases found'),
      findsOneWidget,
    );
  });

  group('legal links (App Store required)', () {
    testWidgets(
        'Privacy Policy / Terms are present but rendered disabled — not a '
        "dead-but-clickable link — while AppLinks' URLs are still empty",
        (tester) async {
      await pumpPremium(tester, _FakeSubscriptionService(offering: null));
      await scrollToEnd(tester);

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);

      final privacyButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Privacy Policy'),
      );
      final termsButton = tester.widget<TextButton>(
        find.widgetWithText(TextButton, 'Terms of Service'),
      );
      // AppLinks.privacyPolicyUrl / termsUrl are still the empty
      // pre-launch placeholder (see app_links.dart) — disabled
      // (onPressed: null), not a dead/broken tap that goes nowhere. This
      // is a permanent regression test: keep it green (and keep it) even
      // once real URLs are set, at which point onPressed should no
      // longer be null — see app_links_test.dart for the reminder that
      // catches *that* half.
      expect(privacyButton.onPressed, isNull);
      expect(termsButton.onPressed, isNull);
    });
  });

  testWidgets(
      '"Maybe later" is always present, calls onDone, and returns to '
      'whatever pushed this screen', (tester) async {
    var doneCalled = false;
    await pumpPremiumPushed(
      tester,
      _FakeSubscriptionService(offering: null),
      onDone: () => doneCalled = true,
    );

    await scrollAndTap(tester, find.text('Maybe later'));

    expect(doneCalled, isTrue);
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('open premium'), findsOneWidget);
  });

  testWidgets(
      'with no onDone provided (Home-reached), "Maybe later" just pops '
      'without crashing', (tester) async {
    await pumpPremiumPushed(tester, _FakeSubscriptionService(offering: null));

    await scrollAndTap(tester, find.text('Maybe later'));

    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('open premium'), findsOneWidget);
  });

  group('with a package available (a real RevenueCat product connected)', () {
    testWidgets(
        'annual is preselected, states trial length, its own price, '
        'billing period, and auto-renewal', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      final startButton = find.text('Start free trial');
      await tester.scrollUntilVisible(startButton, 300);

      expect(
        find.text('${SubscriptionService.trialLengthDays}-day free trial'),
        findsOneWidget,
      );
      // The disclosure block reflects the *selected* plan — annual by
      // default — not always the monthly product.
      expect(find.textContaining('\$89.99 / year'), findsOneWidget);
      expect(
        find.textContaining('Auto-renews until cancelled'),
        findsOneWidget,
      );
      expect(startButton, findsOneWidget);
    });

    testWidgets(
        'switching to Monthly updates the disclosure block to the '
        'monthly product', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      await scrollAndTap(tester, find.text('Monthly'));

      // The disclosure card's own price line ("Then $X / month, billed
      // automatically...") is distinct text from the plan picker's big
      // figure ("$X / month" alone) — checked separately below — so this
      // checks the disclosure line specifically, not just any "$9.99"
      // substring anywhere on screen.
      expect(
        find.textContaining('Then \$9.99 / month, billed automatically'),
        findsOneWidget,
      );
      expect(find.textContaining('\$89.99 / year'), findsNothing);
    });

    testWidgets(
        'the annual plan shows its real per-month equivalent as the big '
        'figure, the real annual total as the small detail, and a savings '
        'badge computed from both real prices — nothing hardcoded',
        (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );
      // The plan picker sits below the table and the explanatory
      // paragraph — scroll to its own price line, which also forces
      // everything above it (including the picker itself) to be built.
      final bigFigure = find.text('\$7.49 / month');
      await tester.scrollUntilVisible(bigFigure, 300);

      // Big figure: the annual product's own pricePerMonthString (SDK-
      // computed from its real $89.99 price), not $9.99 (the monthly
      // product's price) and not a manually divided number.
      expect(bigFigure, findsOneWidget);
      // Small detail: the real annual total.
      expect(find.text('Billed \$89.99 annually.'), findsOneWidget);
      // Savings: (9.99 - 7.49) / 9.99 ≈ 25%, computed from the two real
      // products' prices, not a hardcoded "25%" string anywhere in the
      // widget itself.
      expect(find.text('Save 25%'), findsOneWidget);
    });

    testWidgets(
        'the monthly plan shows its own price as the big figure and no '
        'savings badge', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      await scrollAndTap(tester, find.text('Monthly'));

      // Exact match: the plan picker's big figure line, distinct from
      // the disclosure card's "Then $9.99 / month, billed..." sentence
      // checked in the previous test.
      expect(find.text('\$9.99 / month'), findsOneWidget);
      expect(find.text('Billed monthly.'), findsOneWidget);
      expect(find.textContaining('Save'), findsNothing);
    });

    testWidgets(
        'an offering with only one plan configured is treated as '
        'unavailable, not a picker with one dead option', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithOnlyMonthly()),
      );
      await scrollToEnd(tester);

      expect(
        find.text("Trial pricing isn't available right now"),
        findsOneWidget,
      );
      expect(find.text('Monthly'), findsNothing);
      expect(find.text('Annual'), findsNothing);
    });

    testWidgets('a successful purchase shows a success state', (tester) async {
      final service = _FakeSubscriptionService(
        offering: _offeringWithBothPlans(),
        purchaseOutcome: PurchaseOutcome.success,
      );
      await pumpPremium(tester, service);

      await scrollAndTap(tester, find.text('Start free trial'));

      expect(service.purchaseCalls, 1);
      expect(
        find.textContaining('Trial started — Topic Practice is unlocked'),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled purchase shows a cancelled state, not an error',
        (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(
          offering: _offeringWithBothPlans(),
          purchaseOutcome: PurchaseOutcome.cancelled,
        ),
      );

      await scrollAndTap(tester, find.text('Start free trial'));

      expect(
        find.textContaining('Purchase cancelled — no charge was made'),
        findsOneWidget,
      );
    });

    testWidgets(
        'a failed purchase (expected with no real product connected) shows '
        'a clear error state, not a crash', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(
          offering: _offeringWithBothPlans(),
          purchaseOutcome: PurchaseOutcome.failure,
        ),
      );

      await scrollAndTap(tester, find.text('Start free trial'));

      expect(find.textContaining("couldn't start"), findsOneWidget);
    });

    testWidgets(
        'after a successful purchase, the primary button becomes '
        '"Continue" (not a second "Start free trial") and calling it fires '
        'onDone then returns', (tester) async {
      var doneCalled = false;
      final service = _FakeSubscriptionService(
        offering: _offeringWithBothPlans(),
        purchaseOutcome: PurchaseOutcome.success,
      );
      await pumpPremiumPushed(tester, service, onDone: () => doneCalled = true);

      await scrollAndTap(tester, find.text('Start free trial'));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Start free trial'), findsNothing);
      // Redundant with "Continue" once a trial has actually started.
      expect(find.text('Maybe later'), findsNothing);

      await scrollAndTap(tester, find.text('Continue'));

      expect(doneCalled, isTrue);
      expect(find.byType(PremiumScreen), findsNothing);
    });
  });
}

Offering _offeringWithBothPlans() {
  final monthly = _fakeMonthlyPackage();
  final annual = _fakeAnnualPackage();
  return Offering(
    'default',
    'Default offering',
    const {},
    [monthly, annual],
    monthly: monthly,
    annual: annual,
  );
}

Offering _offeringWithOnlyMonthly() {
  final monthly = _fakeMonthlyPackage();
  return Offering(
    'default',
    'Default offering',
    const {},
    [monthly],
    monthly: monthly,
  );
}
