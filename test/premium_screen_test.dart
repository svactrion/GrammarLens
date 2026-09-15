import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/storage_service.dart';
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

  /// When set, [getOfferings] awaits this instead of resolving
  /// immediately — lets a test observe the *loading* state itself (a
  /// single `pump()` before completing it) rather than only ever seeing
  /// whichever state the fetch settles into by the time `pumpAndSettle`
  /// returns.
  final Completer<Offering?>? offeringsCompleter;

  _FakeSubscriptionService({
    this.offering,
    this.purchaseOutcome = PurchaseOutcome.failure,
    this.offeringsCompleter,
  });

  @override
  Future<Offering?> getOfferings() async {
    final completer = offeringsCompleter;
    if (completer != null) return completer.future;
    return offering;
  }

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
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
      await tester.pumpAndSettle();
    }
  }

  testWidgets(
      'never references the retired Early Access framing or an unbounded '
      'free promise', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    expect(find.textContaining('early access'), findsNothing);
    expect(find.text('Early Access'), findsNothing);
    // PRD v2 §6/§12.2: never say "free forever" or unqualified "free" for
    // Topic Practice — that promise stopped being true once it moved to
    // trial-then-paid. Daily Test is the one thing genuinely free/always.
    // The reordering batch removed the long framing card that used to
    // carry this claim entirely, rather than relocating it — its absence
    // is the fix, not a specific replacement sentence.
    expect(find.textContaining('forever'), findsNothing);
  });

  testWidgets(
      'the comparison table lists exactly the four real features (merged '
      'down from five), Daily Test free on both sides, weak-spot practice '
      'free at its real quota, and the rest Premium-only', (tester) async {
    // bySemanticsLabel needs the semantics tree actually built, which
    // (unlike a real device with an accessibility service running) is off
    // by default in a plain widget test. Disposed explicitly at the end
    // of this test body — addTearDown runs too late for the framework's
    // own end-of-test "no handle left open" check.
    final semantics = tester.ensureSemantics();

    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    final header = find.text('FREE');
    await tester.scrollUntilVisible(header, 300);

    expect(header, findsOneWidget);
    expect(find.text('PREMIUM'), findsOneWidget);

    expect(find.text('Daily Test, refreshed every day'), findsOneWidget);
    expect(find.text('Topic Practice, all five topics'), findsOneWidget);
    // "Questions from your own mistakes" and "Targeted weak-spot practice"
    // used to be two separate rows, both wrongly showing free as "—" —
    // merged into one, with the real per-day quota
    // (StorageService.freeDailyPracticeLimit) shown as text, not a
    // checkmark/dash.
    expect(find.text('Questions from your own mistakes'), findsNothing);
    expect(find.text('Targeted weak-spot practice'), findsNothing);
    expect(find.text('Practice your weak spots'), findsOneWidget);
    expect(
      find.text('${StorageService.freeDailyPracticeLimit} a day'),
      findsOneWidget,
    );
    // Session lengths read off PracticeLength, not hardcoded — see
    // premium_screen.dart's _joinWithOr.
    expect(find.text('Sessions of 3, 5 or 10 questions'), findsOneWidget);
    // Never claims unlimited anywhere on the table.
    expect(find.textContaining('Unlimited'), findsNothing);
    expect(find.textContaining('unlimited'), findsNothing);

    // Daily Test is free (checkmark); Topic Practice and Sessions are not
    // (dash); the merged weak-spot row uses its own text value instead of
    // either glyph, so it contributes to neither count. Premium includes
    // all four rows.
    expect(find.bySemanticsLabel('Included in Free'), findsOneWidget);
    expect(find.bySemanticsLabel('Not included in Free'), findsNWidgets(2));
    expect(find.bySemanticsLabel('Included in Premium'), findsNWidgets(4));
    semantics.dispose();
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

  group('the three pricing-area states (a paywall that can\'t fetch '
      'products must not silently hide the whole price section)', () {
    testWidgets(
        'loading shows a skeleton shaped like the plan cards in the body '
        '(a spinner belongs in the fixed footer instead, not here)',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final completer = Completer<Offering?>();

      // Not the shared pumpPremium helper: this specifically needs to
      // observe the screen *before* getOfferings() resolves, via a plain
      // pump() rather than pumpAndSettle().
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            subscriptionService:
                _FakeSubscriptionService(offeringsCompleter: completer),
          ),
        ),
      );
      await tester.pump();

      expect(find.bySemanticsLabel('Loading pricing'), findsOneWidget);
      // The fixed footer legitimately shows its own spinner while loading
      // (Batch 2's own spec) — what this test actually guards is that the
      // *body* (the plan-cards area) shows the shaped skeleton, not a
      // spinner standing in for it.
      final footer = find.byKey(const Key('premiumFooter'));
      expect(
        find.descendant(
          of: footer,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.bySemanticsLabel('Loading pricing'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
      expect(find.text('Start free trial'), findsNothing);

      completer.complete(null);
      await tester.pumpAndSettle();
      semantics.dispose();
    });

    testWidgets('loaded shows the real plan cards, not the skeleton',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      expect(find.bySemanticsLabel('Loading pricing'), findsNothing);
      final startButton = find.text('Start free trial');
      await tester.scrollUntilVisible(startButton, 300);
      expect(startButton, findsOneWidget);
      semantics.dispose();
    });

    testWidgets(
        'unavailable shows a short message with an inline retry — no '
        'plan cards, no skeleton, and never just nothing', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPremium(tester, _FakeSubscriptionService(offering: null));
      await scrollToEnd(tester);

      expect(find.bySemanticsLabel('Loading pricing'), findsNothing);
      final retry = find.widgetWithText(TextButton, 'Try again');
      expect(retry, findsOneWidget);

      // Retrying re-fetches for real (not a silent no-op) — with a fake
      // that still resolves to no offering, it lands back on the same
      // unavailable state rather than crashing or getting stuck.
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(
        find.text("Trial pricing isn't available right now"),
        findsOneWidget,
      );
      semantics.dispose();
    });
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
        'Privacy Policy / Terms are present and enabled now that '
        "AppLinks' URLs are real", (tester) async {
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
      // AppLinks.privacyPolicyUrl / termsUrl are real, permanent URLs as
      // of the custom-domain batch (see app_links.dart) — the buttons
      // must be enabled (onPressed non-null), not the disabled
      // placeholder state from before those URLs existed. This stays a
      // permanent regression test: if AppLinks is ever emptied out again
      // (it shouldn't be), this is what would catch a live-looking but
      // dead link shipping instead.
      expect(privacyButton.onPressed, isNotNull);
      expect(termsButton.onPressed, isNotNull);
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

      // The disclosure line reflects the *selected* plan — annual by
      // default — not always the monthly product. It's a single combined
      // sentence now (the reordering batch condensed the old three-line
      // _TrialTermsCard to fit the "at most two lines" requirement), but
      // still built from the same live trial length, price, and period.
      expect(
        find.textContaining(
          '${SubscriptionService.trialLengthDays}-day free trial',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('\$89.99 / year'), findsOneWidget);
      expect(
        find.textContaining('auto-renews unless cancelled'),
        findsOneWidget,
      );
      expect(startButton, findsOneWidget);
    });

    testWidgets(
        'switching to Monthly updates the disclosure line to the '
        'monthly product', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      await scrollAndTap(tester, find.text('Monthly'));

      // The disclosure line's own price mention ("then $X / month, ...")
      // is distinct text from the plan card's big figure ("$X / month"
      // alone) — checked separately below — so this checks the
      // disclosure line specifically, not just any "$9.99" substring
      // anywhere on screen.
      expect(
        find.textContaining('then \$9.99 / month, auto-renews'),
        findsOneWidget,
      );
      expect(find.textContaining('then \$89.99 / year'), findsNothing);
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
        'savings badge, regardless of which card is currently selected',
        (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      await scrollAndTap(tester, find.text('Monthly'));

      // Exact match: the monthly card's own big figure line, distinct
      // from the disclosure line's "then $9.99 / month, ..." sentence
      // checked in the previous test.
      expect(find.text('\$9.99 / month'), findsOneWidget);
      expect(find.text('Billed monthly.'), findsOneWidget);

      // Both plan cards render at once now (unlike the old segmented
      // toggle, which only ever showed the selected plan's price row) —
      // so Annual's own "Save 25%" badge is still on screen even with
      // Monthly selected. What must hold is that it's *inside the Annual
      // card specifically*, not the Monthly one.
      final monthlyCard = find.byKey(const ValueKey('planCard_Monthly'));
      expect(
        find.descendant(of: monthlyCard, matching: find.textContaining('Save')),
        findsNothing,
      );
      expect(find.textContaining('Save'), findsOneWidget);
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

  group('the reordering batch\'s "fits on one screen" requirement', () {
    testWidgets(
        'at 390x844 with pricing loaded, the primary button is on screen '
        'without scrolling', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      // No scrollUntilVisible here on purpose — the whole point of this
      // batch's reordering is that the primary button is reachable
      // without scrolling at this size, so simply finding it after the
      // initial pump (no drag) is the actual assertion.
      final buttonRect = tester.getRect(find.text('Start free trial'));
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(viewportHeight),
        reason: 'Start free trial should be visible on a 390x844 screen '
            'without scrolling.',
      );
    });

    testWidgets(
        'no overflow at a small screen (375x667) with a large text scale',
        (tester) async {
      tester.view.physicalSize = const Size(375, 667) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(
        tester.platformDispatcher.clearTextScaleFactorTestValue,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            subscriptionService:
                _FakeSubscriptionService(offering: _offeringWithBothPlans()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // The content is expected to genuinely exceed this viewport at this
      // text scale — confirms the "no overflow" result above is because
      // the screen is properly scrollable, not because there was nothing
      // to overflow in the first place.
      final scrollable =
          tester.state<ScrollableState>(find.byType(Scrollable).first);
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
    });
  });

  group('the fixed footer (Batch 2: structure, states, premium strip)', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required Size size,
      required double textScale,
      required SubscriptionService service,
    }) async {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(home: PremiumScreen(subscriptionService: service)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'pricing-unavailable: the footer shows only "Maybe later" — no CTA, '
        'no disclosure (the retry card stays in the scrollable body, not '
        'duplicated here)', (tester) async {
      await pumpAt(
        tester,
        size: const Size(375, 667),
        textScale: 1.0,
        service: _FakeSubscriptionService(offering: null),
      );

      final footer = find.byKey(const Key('premiumFooter'));
      expect(
        find.descendant(of: footer, matching: find.text('Maybe later')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: footer, matching: find.text('Start free trial')),
        findsNothing,
      );
      expect(
        find.descendant(
          of: footer,
          matching: find.textContaining('auto-renews'),
        ),
        findsNothing,
      );
      // The retry affordance is real, just outside the footer.
      expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
    });

    testWidgets(
        'loading: the footer shows a disabled spinner CTA and "Maybe '
        'later", no disclosure yet', (tester) async {
      final completer = Completer<Offering?>();
      // Not the pumpAt helper: it pumpAndSettle()s internally, which would
      // hang forever against a completer that's deliberately never
      // completed — this needs a single plain pump() to observe the
      // loading state itself, the same reasoning the earlier "loading
      // shows a skeleton" test already documents.
      tester.view.physicalSize = const Size(375, 667) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            subscriptionService:
                _FakeSubscriptionService(offeringsCompleter: completer),
          ),
        ),
      );
      await tester.pump();

      final footer = find.byKey(const Key('premiumFooter'));
      final ctaButton = tester.widget<FilledButton>(
        find.descendant(of: footer, matching: find.byType(FilledButton)),
      );
      expect(ctaButton.onPressed, isNull);
      expect(
        find.descendant(
          of: footer,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: footer, matching: find.text('Maybe later')),
        findsOneWidget,
      );

      completer.complete(null);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'purchase error: the existing retry-via-the-same-CTA behavior is '
        'unchanged in the new footer', (tester) async {
      await pumpAt(
        tester,
        size: const Size(375, 667),
        textScale: 1.0,
        service: _FakeSubscriptionService(
          offering: _offeringWithBothPlans(),
          purchaseOutcome: PurchaseOutcome.failure,
        ),
      );

      final footer = find.byKey(const Key('premiumFooter'));
      await tester.tap(
        find.descendant(of: footer, matching: find.text('Start free trial')),
      );
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: footer,
          matching: find.textContaining("couldn't start"),
        ),
        findsOneWidget,
      );
      final ctaButton = tester.widget<FilledButton>(
        find.descendant(of: footer, matching: find.byType(FilledButton)),
      );
      expect(ctaButton.onPressed, isNotNull,
          reason: 'the CTA must allow retrying directly after an error');
    });

    // Batch 2 item 3: measure the footer's own height at both target
    // widths/heights and both text scales, and stop if the worst case
    // (320x568 @1.3) would exceed 40% of the viewport — reported via the
    // build-log entry for this batch, not asserted as a hard failure here
    // unless that threshold is actually crossed.
    for (final size in [const Size(320, 568), const Size(375, 667)]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
            'footer height at ${size.width.toInt()}x${size.height.toInt()} '
            '@${scale}x textScale', (tester) async {
          await pumpAt(
            tester,
            size: size,
            textScale: scale,
            service:
                _FakeSubscriptionService(offering: _offeringWithBothPlans()),
          );

          final footerHeight =
              tester.getSize(find.byKey(const Key('premiumFooter'))).height;
          final fraction = footerHeight / size.height;
          // ignore: avoid_print
          print('footer height @ ${size.width.toInt()}x${size.height.toInt()} '
              '@${scale}x = ${footerHeight.toStringAsFixed(1)}pt '
              '(${(fraction * 100).toStringAsFixed(1)}% of viewport height)');

          if (size == const Size(320, 568) && scale == 1.3) {
            expect(fraction, lessThanOrEqualTo(0.40),
                reason: 'the footer would take up '
                    '${(fraction * 100).toStringAsFixed(1)}% of a 320x568 '
                    'viewport at 1.3x text scale — stop-and-report threshold '
                    'from this batch\'s own brief');
          }
        });
      }
    }

    testWidgets(
        "the PREMIUM header doesn't overflow at 1.3x or 2.0x text scale "
        '(replaces the old FittedBox(scaleDown) safety net with a real '
        'measured width)', (tester) async {
      for (final scale in [1.3, 2.0]) {
        await pumpAt(
          tester,
          size: const Size(375, 667),
          textScale: scale,
          service: _FakeSubscriptionService(offering: null),
        );
        await tester.scrollUntilVisible(find.text('PREMIUM'), 300);
        expect(tester.takeException(), isNull,
            reason: 'overflow at ${scale}x text scale');
      }
    });

    testWidgets(
        'no overflow anywhere at 320pt or 375pt width, default text scale',
        (tester) async {
      for (final width in [320.0, 375.0]) {
        await pumpAt(
          tester,
          size: Size(width, 667),
          textScale: 1.0,
          service: _FakeSubscriptionService(offering: _offeringWithBothPlans()),
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }
    });

    testWidgets(
        'the selected plan card still reads as selected next to the '
        'Premium strip, even though both use secondaryContainer — the '
        "card's own border is the distinguishing signal, checked directly "
        'rather than assumed from the shared fill color', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );
      final annualCard = find.byKey(const ValueKey('planCard_Annual'));
      await tester.scrollUntilVisible(annualCard, 300);

      final selectedContainer = tester.widget<Container>(
        find.descendant(of: annualCard, matching: find.byType(Container)).first,
      );
      final selectedDecoration = selectedContainer.decoration as BoxDecoration;
      final selectedBorder = selectedDecoration.border as Border;
      expect(selectedBorder.top.width, 2,
          reason: 'the selected card keeps its own 2px border, distinct '
              'from an unselected 1px one, regardless of fill color');

      await scrollAndTap(tester, find.text('Monthly'));
      final monthlyCard = find.byKey(const ValueKey('planCard_Monthly'));
      final selectedContainer2 = tester.widget<Container>(
        find
            .descendant(of: monthlyCard, matching: find.byType(Container))
            .first,
      );
      final selectedBorder2 =
          (selectedContainer2.decoration as BoxDecoration).border as Border;
      expect(selectedBorder2.top.width, 2);

      final annualContainerNowUnselected = tester.widget<Container>(
        find.descendant(of: annualCard, matching: find.byType(Container)).first,
      );
      final unselectedBorder =
          (annualContainerNowUnselected.decoration as BoxDecoration).border
              as Border;
      expect(unselectedBorder.top.width, 1);
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
