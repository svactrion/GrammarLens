import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

/// Records every call instead of the real (best-effort, silently
/// swallowed) Firebase call — needed so a test can assert exactly which
/// analytics events fired, in what order, with what parameters.
class _FakeAnalyticsCall {
  final String name;
  final Map<String, Object?> parameters;
  const _FakeAnalyticsCall(this.name, this.parameters);

  @override
  String toString() => '$name($parameters)';
}

class _FakeAnalyticsService extends AnalyticsService {
  final List<_FakeAnalyticsCall> calls = [];

  @override
  Future<void> paywallViewed(String source) async {
    calls.add(_FakeAnalyticsCall('paywall_viewed', {'source': source}));
  }

  @override
  Future<void> paywallDismissed({
    required String source,
    required String method,
  }) async {
    calls.add(_FakeAnalyticsCall(
      'paywall_dismissed',
      {'source': source, 'method': method},
    ));
  }

  @override
  Future<void> purchaseStarted(String plan) async {
    calls.add(_FakeAnalyticsCall('purchase_started', {'plan': plan}));
  }

  @override
  Future<void> purchaseResult({
    required String plan,
    required String outcome,
  }) async {
    calls.add(_FakeAnalyticsCall(
      'purchase_result',
      {'plan': plan, 'outcome': outcome},
    ));
  }
}

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

/// A real [StorageService]'s `getUserProfile()` goes through sqflite,
/// which has no platform channel in this test environment and throws —
/// `PremiumScreen._loadAvatar`'s own try/catch already handles that by
/// falling back to a random avatar (fine for tests that don't care what
/// the hero shows), but the hero-specific tests below need a *known*
/// avatar, hence this fake.
class _FakeStorageServiceForAvatar extends StorageService {
  final UserProfile? profile;

  _FakeStorageServiceForAvatar([this.profile]);

  @override
  Future<UserProfile?> getUserProfile() async => profile;
}

// Trial is 3 days, PeriodUnit.day — matches how App Store Connect's
// monthly introductory offer (a plain "3 Days" duration) actually reports
// back through StoreKit/RevenueCat (PRD v2 §13.2's 2026-09-17 note).
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
      'P3D',
      1,
      PeriodUnit.day,
      3,
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
// §13.3 uses in its own "Save 25%" pricing example. The savings badge
// itself is computed from the raw prices below, not from this
// pricePerMonth figure (see _planPricing's own doc comment) — 1 -
// 89.99 / (12 × 9.99) ≈ 24.94%, floored to 24, one point under the PRD
// example's own rough math.
// Trial is configured in App Store Connect as a "1 Week" duration, not
// "7 Days" — StoreKit/RevenueCat report that back as PeriodUnit.week /
// periodNumberOfUnits 1, not as 7 days (PRD v2 §13.2's 2026-09-17 note).
// Deliberately modeled as a week here, not a day count, so tests exercise
// PremiumScreen's own week-to-day conversion rather than assuming it away.
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
      'P1W',
      1,
      PeriodUnit.week,
      1,
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
    AnalyticsService? analyticsService,
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
          storageService: _FakeStorageServiceForAvatar(),
          analyticsService: analyticsService ?? _FakeAnalyticsService(),
          analyticsSource: AnalyticsService.paywallSourceHome,
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
    AnalyticsService? analyticsService,
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
                      storageService: _FakeStorageServiceForAvatar(),
                      analyticsService:
                          analyticsService ?? _FakeAnalyticsService(),
                      analyticsSource: AnalyticsService.paywallSourceHome,
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
      'leads with the personalized-feedback pitch, not invented ad copy '
      'about "a feature list"', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    // Visual-redesign follow-up: the previous fallback headline
    // ("Personalized feedback, not a feature list") traced to no spec —
    // it was written directly as ad copy in the commit that introduced
    // the standalone Paywall screen, not a quote from docs/prd.md despite
    // that commit citing it. Replaced with a plain statement of the pitch
    // itself, consistent with the sourceContext-present branch below.
    expect(find.text('Unlock personalized feedback'), findsOneWidget);
    expect(
      find.textContaining('not a feature list'),
      findsNothing,
    );
  });

  testWidgets(
      'keeps the headline stable and names sourceContext in the supporting text',
      (tester) async {
    await pumpPremium(
      tester,
      _FakeSubscriptionService(offering: null),
      sourceContext: 'definite articles',
    );
    expect(
      find.text('Practice definite articles.'),
      findsOneWidget,
    );
    expect(find.text('Unlock personalized feedback'), findsOneWidget);
    expect(find.text('Practice the mistakes you actually make.'), findsNothing);
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

  group(
      'the three pricing-area states (a paywall that can\'t fetch '
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
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
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
      // The annual fixture's introductory offer is modeled as
      // PeriodUnit.week/1 (matching real StoreKit), so this also proves
      // the disclosure text converts it to "7-day" rather than "1-week".
      expect(
        find.textContaining('7-day free trial'),
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
      // The trial part of the same disclosure line also updates — the
      // monthly fixture's own 3-day (not week-unit) introductory offer,
      // distinct from annual's 7-day figure above.
      expect(find.textContaining('3-day free trial'), findsOneWidget);
      expect(find.textContaining('7-day free trial'), findsNothing);
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
      // Savings: 1 - 89.99 / (12 × 9.99) ≈ 24.94%, floored to 24 —
      // computed from the two products' own real prices (never the
      // truncated pricePerMonth figure above, and never rounded up), not
      // a hardcoded "24%" string anywhere in the widget itself.
      expect(find.text('Save 24%'), findsOneWidget);
    });

    testWidgets(
        'regression: with the real live App Store prices (\$5.99/month, '
        '\$49.99/year), the savings badge reads "Save 30%", not "31%" '
        '(found on-device 2026-09-17: StoreKit truncates the per-month '
        'equivalent to \$4.16, and computing the percentage from that '
        'truncated figure — then rounding — overstated the true 30.44% '
        'saving as 31)', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(
          offering: _offeringWithRealLivePrices(),
        ),
      );

      final bigFigure = find.text('\$4.16 / month');
      await tester.scrollUntilVisible(bigFigure, 300);

      expect(bigFigure, findsOneWidget);
      expect(find.text('Save 30%'), findsOneWidget);
      expect(find.text('Save 31%'), findsNothing);
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
      // so Annual's own "Save 24%" badge is still on screen even with
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
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
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
      Brightness? brightness,
    }) async {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == null ? null : buildAppTheme(brightness),
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final brightness in Brightness.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'plan cards share bounds and stay stable on selection at ${scale}x text in $brightness',
            (tester) async {
          await pumpAt(tester,
              size: Size(scale == 1.0 ? 320 : 375, 667),
              textScale: scale,
              brightness: brightness,
              service:
                  _FakeSubscriptionService(offering: _offeringWithBothPlans()));
          final annual = find.byKey(const ValueKey('planCard_Annual'));
          final monthly = find.byKey(const ValueKey('planCard_Monthly'));
          await tester.scrollUntilVisible(annual, 250);
          final beforeAnnual = tester.getSize(annual);
          final beforeMonthly = tester.getSize(monthly);
          expect(beforeAnnual, beforeMonthly);
          expect(tester.getTopLeft(annual).dy, tester.getTopLeft(monthly).dy);
          await scrollAndTap(tester, find.text('Monthly'));
          expect(tester.getSize(annual), beforeAnnual);
          expect(tester.getSize(monthly), beforeMonthly);
          expect(tester.takeException(), isNull);
        });
      }
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
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
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
        'the selected plan card is distinguished from the Premium strip by '
        'its own 2px border and check mark, not by sharing the strip\'s '
        'fill color (visual-polish batch: card fill no longer switches to '
        'secondaryContainer on selection)', (tester) async {
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
      expect(
        find.descendant(
          of: annualCard,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
        reason: 'the selected card carries an explicit check mark, not '
            'just a fill-color change',
      );

      final monthlyCard = find.byKey(const ValueKey('planCard_Monthly'));
      final unselectedMaterial = tester.widget<Material>(
        find.descendant(of: monthlyCard, matching: find.byType(Material)).first,
      );
      final selectedMaterial = tester.widget<Material>(
        find.descendant(of: annualCard, matching: find.byType(Material)).first,
      );
      expect(unselectedMaterial.color, selectedMaterial.color,
          reason: 'card fill is identical selected or not — the surface '
              'never doubles as the selection signal');
      expect(
        find.descendant(
          of: monthlyCard,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );

      await scrollAndTap(tester, find.text('Monthly'));
      final selectedContainer2 = tester.widget<Container>(
        find
            .descendant(of: monthlyCard, matching: find.byType(Container))
            .first,
      );
      final selectedBorder2 =
          (selectedContainer2.decoration as BoxDecoration).border as Border;
      expect(selectedBorder2.top.width, 2);
      expect(
        find.descendant(
          of: monthlyCard,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );

      final annualContainerNowUnselected = tester.widget<Container>(
        find.descendant(of: annualCard, matching: find.byType(Container)).first,
      );
      final unselectedBorder =
          (annualContainerNowUnselected.decoration as BoxDecoration).border
              as Border;
      expect(unselectedBorder.top.width, 1);
      expect(
        find.descendant(
          of: annualCard,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsNothing,
      );
    });
  });

  group('the hero avatar group (Batch 3)', () {
    final profile = UserProfile(
      name: 'Ada',
      learningGoal: LearningGoal.work,
      avatar: Avatar.values[6], // avatar_07, arbitrary but fixed
    );

    // Reads each AvatarTile's own `avatar` property directly rather than
    // scanning semantics labels — the hero collapses to one semantic node
    // (see _AvatarHero's own doc comment: the other four are decorative,
    // not individually meaningful to a screen reader), so which avatars
    // are actually shown is only observable at the widget level now.
    List<Avatar?> avatarsShown(WidgetTester tester) => tester
        .widgetList<AvatarTile>(find.byType(AvatarTile))
        .map((tile) => tile.avatar)
        .toList();

    testWidgets(
        'shows exactly five avatars, the center one matching the '
        "real profile's avatar", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(profile),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final shown = avatarsShown(tester);
      expect(shown, hasLength(5));
      expect(shown[2], profile.avatar);
    });

    testWidgets(
        'the four other avatars are distinct from the center and from '
        'each other, and are the same every time (deterministic, not '
        'Avatar.random)', (tester) async {
      Future<List<Avatar?>> pumpAndRead() async {
        await tester.pumpWidget(
          MaterialApp(
            home: PremiumScreen(
              storageService: _FakeStorageServiceForAvatar(profile),
              analyticsService: _FakeAnalyticsService(),
              analyticsSource: AnalyticsService.paywallSourceHome,
              subscriptionService: _FakeSubscriptionService(offering: null),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return avatarsShown(tester);
      }

      final first = await pumpAndRead();
      expect(first, hasLength(5),
          reason: 'the center avatar plus four distinct others');
      expect(first.toSet(), hasLength(5),
          reason: 'no repeats among the five shown avatars');

      // Same profile, freshly pumped again — the four others must be the
      // exact same set, not re-rolled.
      final second = await pumpAndRead();
      expect(second.toSet(), first.toSet());
    });

    testWidgets(
        'a null avatar (legacy profile) never shows the generic '
        'placeholder — five real avatars are shown instead', (tester) async {
      const legacyProfile =
          UserProfile(name: 'Ada', learningGoal: LearningGoal.work);
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(legacyProfile),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AvatarTile), findsNWidgets(5));
      for (final tile
          in tester.widgetList<AvatarTile>(find.byType(AvatarTile))) {
        expect(tile.avatar, isNotNull,
            reason: 'no tile should fall back to the null/placeholder '
                'branch in the hero');
      }
    });

    testWidgets(
        'no Hero wraps any hero avatar — nothing to collide with '
        "Home's or Settings' own avatar Hero tags", (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(profile),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Hero), findsNothing);
    });

    testWidgets(
        'three avatars fit within a 320pt-wide viewport, no '
        'overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568) * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(profile),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AvatarTile), findsNWidgets(3));
    });

    for (final width in [320.0, 390.0]) {
      for (final dark in [false, true]) {
        testWidgets('opaque, separated and centered avatars at $width dark=$dark',
            (tester) async {
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(dark ? Brightness.dark : Brightness.light),
            home: PremiumScreen(
              storageService: _FakeStorageServiceForAvatar(profile),
              analyticsService: _FakeAnalyticsService(),
              analyticsSource: AnalyticsService.paywallSourceHome,
              subscriptionService: _FakeSubscriptionService(offering: null),
            ),
          ));
          await tester.pumpAndSettle();
          final tiles = find.byType(AvatarTile);
          final count = width == 320 ? 3 : 5;
          expect(tiles, findsNWidgets(count));
          expect(avatarsShown(tester)[count ~/ 2], profile.avatar);
          final rects = List.generate(count, (i) => tester.getRect(tiles.at(i)));
          final center = rects[count ~/ 2];
          expect(center.center.dx, closeTo(width / 2, 0.01));
          for (var i = 0; i < count; i++) {
            expect(rects[i].left, greaterThanOrEqualTo(0));
            expect(rects[i].right, lessThanOrEqualTo(width));
            if (i != count ~/ 2) expect(rects[i].width, lessThan(center.width));
            if (i > 0) {
              expect(rects[i].left - rects[i - 1].right, greaterThanOrEqualTo(8));
            }
          }
          expect(find.ancestor(of: tiles, matching: find.byType(Opacity)),
              findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('paywall analytics (Batch 4)', () {
    testWidgets('paywall_viewed fires once on mount with the correct source',
        (tester) async {
      final analytics = _FakeAnalyticsService();
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: null),
        analyticsService: analytics,
      );

      final viewed =
          analytics.calls.where((c) => c.name == 'paywall_viewed').toList();
      expect(viewed, hasLength(1));
      expect(viewed.single.parameters['source'],
          AnalyticsService.paywallSourceHome);
    });

    testWidgets(
        'tapping the close button logs paywall_dismissed with method '
        'close_button', (tester) async {
      final analytics = _FakeAnalyticsService();
      await pumpPremiumPushed(
        tester,
        _FakeSubscriptionService(offering: null),
        analyticsService: analytics,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();

      final dismissed =
          analytics.calls.where((c) => c.name == 'paywall_dismissed').toList();
      expect(dismissed, hasLength(1));
      expect(dismissed.single.parameters['method'],
          AnalyticsService.paywallDismissCloseButton);
      expect(dismissed.single.parameters['source'],
          AnalyticsService.paywallSourceHome);
    });

    testWidgets(
        'tapping "Maybe later" logs paywall_dismissed with method '
        'maybe_later', (tester) async {
      final analytics = _FakeAnalyticsService();
      await pumpPremiumPushed(
        tester,
        _FakeSubscriptionService(offering: null),
        analyticsService: analytics,
      );

      await scrollAndTap(tester, find.text('Maybe later'));

      final dismissed =
          analytics.calls.where((c) => c.name == 'paywall_dismissed').toList();
      expect(dismissed, hasLength(1));
      expect(dismissed.single.parameters['method'],
          AnalyticsService.paywallDismissMaybeLater);
    });

    testWidgets(
        'a system back gesture (no button tapped) logs paywall_dismissed '
        'with method system_back, via PopScope observing the pop rather '
        'than a specific onPressed', (tester) async {
      final analytics = _FakeAnalyticsService();
      await pumpPremiumPushed(
        tester,
        _FakeSubscriptionService(offering: null),
        analyticsService: analytics,
      );

      // The standard way to simulate a hardware/gesture back in a widget
      // test — this reaches the same Navigator.maybePop() path a real
      // system back would, without going through any of this screen's
      // own buttons.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(PremiumScreen), findsNothing);
      final dismissed =
          analytics.calls.where((c) => c.name == 'paywall_dismissed').toList();
      expect(dismissed, hasLength(1));
      expect(dismissed.single.parameters['method'],
          AnalyticsService.paywallDismissSystemBack);
    });

    testWidgets(
        'a successful purchase logs purchase_started then '
        'purchase_result(success) for the preselected annual plan, and '
        'the post-success "Continue" logs no paywall_dismissed at all',
        (tester) async {
      final analytics = _FakeAnalyticsService();
      final service = _FakeSubscriptionService(
        offering: _offeringWithBothPlans(),
        purchaseOutcome: PurchaseOutcome.success,
      );
      await pumpPremium(tester, service, analyticsService: analytics);

      await scrollAndTap(tester, find.text('Start free trial'));

      expect(
        analytics.calls.map((c) => c.name),
        containsAllInOrder(['purchase_started', 'purchase_result']),
      );
      final started =
          analytics.calls.firstWhere((c) => c.name == 'purchase_started');
      expect(started.parameters['plan'], AnalyticsService.planAnnual);
      final result =
          analytics.calls.firstWhere((c) => c.name == 'purchase_result');
      expect(result.parameters['plan'], AnalyticsService.planAnnual);
      expect(result.parameters['outcome'], 'success');

      await scrollAndTap(tester, find.text('Continue'));
      expect(
        analytics.calls.where((c) => c.name == 'paywall_dismissed'),
        isEmpty,
        reason: 'a completed purchase is not an abandonment — already '
            'covered by purchase_result',
      );
    });

    testWidgets(
        'switching to Monthly before purchasing logs plan: monthly, '
        'outcome: cancelled', (tester) async {
      final analytics = _FakeAnalyticsService();
      final service = _FakeSubscriptionService(
        offering: _offeringWithBothPlans(),
        purchaseOutcome: PurchaseOutcome.cancelled,
      );
      await pumpPremium(tester, service, analyticsService: analytics);

      await scrollAndTap(tester, find.text('Monthly'));
      await scrollAndTap(tester, find.text('Start free trial'));

      final result =
          analytics.calls.firstWhere((c) => c.name == 'purchase_result');
      expect(result.parameters['plan'], AnalyticsService.planMonthly);
      expect(result.parameters['outcome'], 'cancelled');
    });

    testWidgets('a failed purchase logs purchase_result(error)',
        (tester) async {
      final analytics = _FakeAnalyticsService();
      final service = _FakeSubscriptionService(
        offering: _offeringWithBothPlans(),
        purchaseOutcome: PurchaseOutcome.failure,
      );
      await pumpPremium(tester, service, analyticsService: analytics);

      await scrollAndTap(tester, find.text('Start free trial'));

      final result =
          analytics.calls.firstWhere((c) => c.name == 'purchase_result');
      expect(result.parameters['outcome'], 'error');
    });
  });

  group(
      'the free-value column (bugfix batch: no longer shares a flex '
      "factor with the row label, which used to squeeze the weak-spot "
      'row\'s "1 a day" into a narrow sliver that silently overflowed '
      "its row vertically — a failure mode ordinary overflow tests don't "
      'catch, since Flutter only reports a *horizontal* RenderFlex '
      'overflow as an exception)', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required Size size,
      required double textScale,
    }) async {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService:
                _FakeSubscriptionService(offering: _offeringWithBothPlans()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final size in [
      const Size(320, 700),
      const Size(375, 700),
      const Size(393, 852),
    ]) {
      for (final scale in [1.0, 1.3]) {
        testWidgets(
            'the weak-spot row\'s label, its free value, and the row '
            'itself never overlap at ${size.width.toInt()}x'
            '${size.height.toInt()} @${scale}x textScale', (tester) async {
          await pumpAt(tester, size: size, textScale: scale);
          expect(tester.takeException(), isNull);

          final row = find.byKey(
            const ValueKey('comparisonRow_Practice your weak spots'),
          );
          await tester.scrollUntilVisible(row, 300);
          final rowRect = tester.getRect(row);

          final labelRect = tester.getRect(
            find.descendant(
              of: row,
              matching: find.text('Practice your weak spots'),
            ),
          );
          // Either "1 a day" (the common case) or the "1/day" fallback at
          // the narrowest widths — either way, exactly one free-value
          // text renders, on one line.
          final freeValueFinder = find.descendant(
            of: row,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.data == '1 a day' || widget.data == '1/day'),
            ),
          );
          expect(freeValueFinder, findsOneWidget);
          final freeValueRect = tester.getRect(freeValueFinder);

          expect(labelRect.overlaps(freeValueRect), isFalse,
              reason: 'the label and the free-value text must never '
                  'occupy the same screen space');
          expect(
            rowRect.top <= freeValueRect.top &&
                freeValueRect.bottom <= rowRect.bottom,
            isTrue,
            reason: 'the free value must stay within its own row\'s '
                'vertical bounds, not spill into the divider or the row '
                'below it — this is exactly the silent, non-throwing '
                'overflow this batch fixed',
          );
        });
      }
    }
  });

  testWidgets(
      'the FREE header shares a horizontal center with the checkmarks '
      'below it, not just a right edge', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    final freeHeader = find.text('FREE');
    await tester.scrollUntilVisible(freeHeader, 300);
    final freeHeaderCenterX = tester.getCenter(freeHeader).dx;

    final firstRow = find.byKey(
      const ValueKey('comparisonRow_Daily Test, refreshed every day'),
    );
    // Row 1 is free (a checkmark, not text) — its free-column check mark
    // is the first "Included in Free" glyph in the tree, distinct from
    // that same row's Premium-column check mark.
    final freeCheck = find
        .descendant(of: firstRow, matching: find.byIcon(Icons.check_rounded))
        .first;
    final freeCheckCenterX = tester.getCenter(freeCheck).dx;

    expect((freeHeaderCenterX - freeCheckCenterX).abs(), lessThan(1.0),
        reason: 'FREE and the column of checkmarks/dashes beneath it must '
            'share one x-center, not just happen to line up at the right '
            'edge');
  });

  group(
      'the Premium strip\'s fill color (visual-polish batch: dark mode '
      'no longer uses the same saturated secondaryContainer as light '
      'mode)', () {
    testWidgets(
        'dark theme: the strip fills with the calmer surfaceContainerHighest',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.dark),
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final strip = find.byKey(const Key('premiumStripHeader'));
      await tester.scrollUntilVisible(strip, 300);
      final container = tester.widget<Container>(
        find.descendant(of: strip, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.color,
        buildAppTheme(Brightness.dark).colorScheme.surfaceContainerHighest,
      );
    });

    testWidgets('light theme: the strip keeps secondaryContainer, unchanged',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final strip = find.byKey(const Key('premiumStripHeader'));
      await tester.scrollUntilVisible(strip, 300);
      final container = tester.widget<Container>(
        find.descendant(of: strip, matching: find.byType(Container)).first,
      );
      final decoration = container.decoration as BoxDecoration;
      expect(
        decoration.color,
        buildAppTheme(Brightness.light).colorScheme.secondaryContainer,
      );
    });
  });

  testWidgets(
      "What's free, trial, and paid renders below the table and is "
      'horizontally centered', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    final link = find.text("What's free, trial, and paid");
    await tester.scrollUntilVisible(link, 300);

    final linkRect = tester.getRect(link);
    final tableBottom = tester.getBottomLeft(find.text('FREE')).dy;
    expect(linkRect.top, greaterThan(tableBottom),
        reason: 'the link must render below the comparison table, not '
            'above it as a section heading');

    final screenWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final linkCenterX = linkRect.center.dx;
    expect((linkCenterX - screenWidth / 2).abs(), lessThan(1.0),
        reason: 'the link must be horizontally centered under the table');
  });

  group(
      'the pricing-unavailable footer no longer has a stray divider '
      'directly above "Maybe later"', () {
    testWidgets('no top border in the footer when only "Maybe later" shows',
        (tester) async {
      await pumpPremium(tester, _FakeSubscriptionService(offering: null));

      final footer = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('premiumFooter')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = footer.decoration as BoxDecoration;
      expect(decoration.border, isNull,
          reason: 'the loaded/loading states\' top border is a real '
              'section separator; with only "Maybe later" in the footer '
              'it read as an orphaned line sitting right above it instead');
    });

    testWidgets('the top border is still there once pricing has loaded',
        (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      final footer = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const Key('premiumFooter')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = footer.decoration as BoxDecoration;
      expect(decoration.border, isNotNull,
          reason: 'the loaded state still separates the fixed footer from '
              'the scrollable body above it');
    });
  });

  group(
      'density pass (visual-polish batch): the loaded state fits above '
      'the fixed footer without scrolling at common device sizes', () {
    Future<void> pumpAt(WidgetTester tester, Size size,
        {String? sourceContext, Brightness? brightness}) async {
      tester.view.physicalSize = size * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: brightness == null ? null : buildAppTheme(brightness),
          home: PremiumScreen(
            sourceContext: sourceContext,
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService:
                _FakeSubscriptionService(offering: _offeringWithBothPlans()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final brightness in Brightness.values) {
      testWidgets(
          'weak-spot entry keeps normal paywall geometry in $brightness',
          (tester) async {
        await pumpAt(tester, const Size(393, 852), brightness: brightness);
        final baselineHeight =
            tester.getSize(find.byKey(const Key('premiumBody'))).height;
        final baselineCards =
            tester.getRect(find.byKey(const ValueKey('planCard_Annual')));
        final baselineFooter =
            tester.getRect(find.byKey(const Key('premiumFooter')));
        final baselineScroll = tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .maxScrollExtent;
        for (final source in ['Modal past forms', 'definite articles', '   ']) {
          await pumpAt(tester, const Size(393, 852),
              sourceContext: source, brightness: brightness);
          expect(find.text('Unlock personalized feedback'), findsOneWidget);
          expect(tester.getSize(find.byKey(const Key('premiumBody'))).height,
              baselineHeight);
          expect(tester.getRect(find.byKey(const ValueKey('planCard_Annual'))),
              baselineCards);
          expect(tester.getRect(find.byKey(const Key('premiumFooter'))),
              baselineFooter);
          expect(
              tester
                  .state<ScrollableState>(find.byType(Scrollable).first)
                  .position
                  .maxScrollExtent,
              baselineScroll);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets(
        'long weak-spot context stays readable at large text with an accessible footer',
        (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      const source = 'reported speech in questions and negative statements';
      await pumpAt(tester, const Size(375, 667),
          sourceContext: source, brightness: Brightness.dark);
      final supportingText =
          tester.widget<Text>(find.text('Practice $source.'));
      expect(supportingText.maxLines, isNull);
      expect(supportingText.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.getRect(find.byKey(const Key('premiumFooter'))).bottom,
          lessThanOrEqualTo(667));
      expect(tester.takeException(), isNull);
    });

    for (final size in [const Size(393, 852), const Size(375, 667)]) {
      testWidgets(
          'reports total content height and scroll extent at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await pumpAt(tester, size);
        final bodyHeight =
            tester.getSize(find.byKey(const Key('premiumBody'))).height;
        final scrollable =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        final footerHeight =
            tester.getSize(find.byKey(const Key('premiumFooter'))).height;
        final footerTop =
            tester.getTopLeft(find.byKey(const Key('premiumFooter'))).dy;
        final annualCardBottom = tester
            .getRect(find.byKey(const ValueKey('planCard_Annual')))
            .bottom;
        // ignore: avoid_print
        print('premium body content height @ ${size.width.toInt()}x'
            '${size.height.toInt()} = ${bodyHeight.toStringAsFixed(1)}pt, '
            'maxScrollExtent = '
            '${scrollable.position.maxScrollExtent.toStringAsFixed(1)}pt, '
            'footerHeight = ${footerHeight.toStringAsFixed(1)}pt, '
            'footerTop = ${footerTop.toStringAsFixed(1)}pt, '
            'annualCardBottom = ${annualCardBottom.toStringAsFixed(1)}pt');
      });
    }

    testWidgets(
        'at 393x852 with pricing loaded, the plan cards are fully visible '
        'above the fixed footer without scrolling (the batch\'s own '
        'requirement is specifically about the plan cards, not the whole '
        'scrollable body — Restore Purchases and the legal links below '
        'them may still require a scroll)', (tester) async {
      await pumpAt(tester, const Size(393, 852));

      final footerTop =
          tester.getTopLeft(find.byKey(const Key('premiumFooter'))).dy;
      final annualBottom =
          tester.getRect(find.byKey(const ValueKey('planCard_Annual'))).bottom;
      final monthlyBottom =
          tester.getRect(find.byKey(const ValueKey('planCard_Monthly'))).bottom;

      expect(annualBottom, lessThanOrEqualTo(footerTop),
          reason: 'the Annual plan card must be fully visible above the '
              'fixed footer at 393x852 without scrolling');
      expect(monthlyBottom, lessThanOrEqualTo(footerTop),
          reason: 'the Monthly plan card must be fully visible above the '
              'fixed footer at 393x852 without scrolling');

      // The primary CTA lives in the fixed footer, not the scrollable
      // body, so it's on screen by construction — checked directly anyway
      // since a tall enough footer could still push it off, in principle.
      final ctaRect = tester.getRect(find.text('Start free trial'));
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(ctaRect.bottom, lessThanOrEqualTo(viewportHeight));
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

/// The real live App Store prices ($5.99/month, $49.99/year — PRD v2
/// §13.3), distinct from [_fakeMonthlyPackage]/[_fakeAnnualPackage]'s
/// illustrative $9.99/$89.99 pair used elsewhere in this file. `pricePerMonth`
/// is hardcoded to 4.16, mirroring StoreKit's own truncation of 49.99 / 12
/// = 4.1658... (confirmed live on-device 2026-09-17) rather than a rounded
/// 4.17 — the same reasoning `buildDebugFixtureOffering`'s own comment
/// documents.
Offering _offeringWithRealLivePrices() {
  const context = PresentedOfferingContext('default', null, null);
  const monthlyProduct = StoreProduct(
    'grammarlens_premium_monthly',
    'Full access to Topic Practice',
    'GrammarLens Premium (Monthly)',
    5.99,
    '\$5.99',
    'USD',
    subscriptionPeriod: 'P1M',
  );
  const annualProduct = StoreProduct(
    'grammarlens_premium_annual',
    'Full access to Topic Practice (annual)',
    'GrammarLens Premium (Annual)',
    49.99,
    '\$49.99',
    'USD',
    subscriptionPeriod: 'P1Y',
    pricePerMonth: 4.16,
    pricePerMonthString: '\$4.16',
  );
  const monthly = Package(
    '\$rc_monthly',
    PackageType.monthly,
    monthlyProduct,
    context,
  );
  const annual = Package(
    '\$rc_annual',
    PackageType.annual,
    annualProduct,
    context,
  );
  return const Offering(
    'default',
    'Default offering',
    {},
    [monthly, annual],
    monthly: monthly,
    annual: annual,
  );
}
