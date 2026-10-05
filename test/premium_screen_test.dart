import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/models/app_text_size.dart';
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

  /// What the eligibility check answers for every product (1.2.0); the
  /// real check needs a configured SDK.
  final TrialEligibility eligibility;
  int eligibilityCalls = 0;

  /// What Restore finds.
  final bool restoreResult;

  /// When set, a purchase waits for it (a purchase still running).
  final Completer<PurchaseOutcome>? purchaseCompleter;

  _FakeSubscriptionService({
    this.offering,
    this.purchaseOutcome = PurchaseOutcome.failure,
    this.offeringsCompleter,
    this.eligibility = TrialEligibility.eligible,
    this.restoreResult = false,
    this.purchaseCompleter,
  });

  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
      List<String> productIds) async {
    eligibilityCalls++;
    return {for (final id in productIds) id: eligibility};
  }

  @override
  Future<Offering?> getOfferings() async {
    final completer = offeringsCompleter;
    if (completer != null) return completer.future;
    return offering;
  }

  @override
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    purchaseCalls++;
    final completer = purchaseCompleter;
    if (completer != null) return completer.future;
    return purchaseOutcome;
  }

  @override
  Future<bool> restorePurchases() async => restoreResult;
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
  // `flutter test` renders every family in the test font (Ahem, one em wide
  // per glyph), roughly twice as wide as the real typeface. The comparison
  // table decides between its table and stacked layouts by measuring its
  // labels, so tests that expect a particular layout must measure in the real
  // font: load the bundled Nunito Sans once for the whole file and give those
  // tests the app theme, which selects it.
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

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
        theme: buildAppTheme(Brightness.light),
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

  // 1.2.0: the comparison table sits behind "Compare Free & Premium",
  // closed by default; tests about the table open it first.
  Future<void> openComparison(WidgetTester tester) async {
    final shown =
        find.byKey(const Key('comparisonTable')).evaluate().isNotEmpty ||
            find.byKey(const Key('comparisonStacked')).evaluate().isNotEmpty;
    if (shown) return;
    final toggle = find.byKey(PremiumScreen.compareToggleKey);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
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
    await openComparison(tester);
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
    // 1.2.0: the benefits card has a line of the same name; the row is the
    // table's own.
    expect(
        find.descendant(
            of: find.byKey(const Key('comparisonTable')),
            matching: find.text('Practice your weak spots')),
        findsOneWidget);
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
      'leads with the 1.2.0 headline, not invented ad copy about "a feature '
      'list"', (tester) async {
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    expect(find.text('Turn your mistakes into progress.'), findsOneWidget);
    expect(find.text(PremiumScreen.headline), findsOneWidget);
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
    expect(find.text(PremiumScreen.headline), findsOneWidget);
    expect(
        find.text('Focused practice. Personal feedback. A little more '
            'confidence, every day.'),
        findsNothing);
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
      find.text("Prices aren't available right now"),
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
      expect(find.byKey(const ValueKey('planCard_Annual')), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Start my 7-day free trial'),
          findsOneWidget);
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
        find.text("Prices aren't available right now"),
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
        'annual is preselected; with the trial eligible, the button and the '
        'terms name its own trial (a week, shown as 7 days), price and period '
        'and auto-renewal', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      expect(find.widgetWithText(FilledButton, 'Start my 7-day free trial'),
          findsOneWidget);
      expect(
        find.text('7 days free, then \$89.99 per year, auto-renews unless '
            'cancelled.'),
        findsOneWidget,
      );
      final annual = find.byKey(const ValueKey('planCard_Annual'));
      expect(
          tester.getSemantics(annual),
          isSemantics(
              isInMutuallyExclusiveGroup: true,
              hasCheckedState: true,
              isChecked: true));
    });

    testWidgets(
        'switching to Monthly changes the button, the price and the terms '
        'together, to the monthly product', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );

      await scrollAndTap(tester, find.text('Monthly'));

      expect(find.widgetWithText(FilledButton, 'Start my 3-day free trial'),
          findsOneWidget);
      expect(
        find.text('3 days free, then \$9.99 per month, auto-renews unless '
            'cancelled.'),
        findsOneWidget,
      );
      expect(find.textContaining('\$89.99 per year'), findsNothing);
      expect(find.textContaining('7-day'), findsOneWidget,
          reason: 'only on the annual card, not the button or terms');
    });

    testWidgets(
        'the annual plan shows its real total as the big figure with its '
        'period, and a savings badge computed from both real prices — '
        'nothing hardcoded', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );
      final annual = find.byKey(const ValueKey('planCard_Annual'));
      Finder inAnnual(String text) =>
          find.descendant(of: annual, matching: find.text(text));

      // The brief: the yearly total is the prominent figure (1.2.0; the
      // per-month equivalent was the big figure before).
      expect(inAnnual('\$89.99'), findsOneWidget);
      expect(inAnnual('per year'), findsOneWidget);
      expect(inAnnual('7-day free trial'), findsOneWidget);
      // 1 - 89.99 / (12 × 9.99) ≈ 24.94%, floored to 24, from the two
      // products' own prices.
      expect(inAnnual('Save 24%'), findsOneWidget);
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

      final annual = find.byKey(const ValueKey('planCard_Annual'));
      expect(find.descendant(of: annual, matching: find.text('\$49.99')),
          findsOneWidget);
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

      final monthlyCard = find.byKey(const ValueKey('planCard_Monthly'));
      expect(find.descendant(of: monthlyCard, matching: find.text('\$9.99')),
          findsOneWidget);
      expect(find.descendant(of: monthlyCard, matching: find.text('per month')),
          findsOneWidget);
      // Both cards render at once: the saving stays on Annual's card only.
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
        find.text("Prices aren't available right now"),
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

      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

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

      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

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

      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

      expect(find.textContaining("couldn't start"), findsOneWidget);
    });

    testWidgets(
        'after a successful purchase, the primary button becomes '
        '"Continue" (not a second purchase button) and calling it fires '
        'onDone then returns', (tester) async {
      var doneCalled = false;
      final service = _FakeSubscriptionService(
        offering: _offeringWithBothPlans(),
        purchaseOutcome: PurchaseOutcome.success,
      );
      await pumpPremiumPushed(tester, service, onDone: () => doneCalled = true);

      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Start my 7-day free trial'), findsNothing);
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
      final buttonRect = tester.getRect(find.byKey(PremiumScreen.ctaKey));
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;

      expect(
        buttonRect.bottom,
        lessThanOrEqualTo(viewportHeight),
        reason: 'The purchase button should be visible on a 390x844 screen '
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
            'plan cards share their width, stack Annual above Monthly 10 '
            'apart, and keep their size on selection at ${scale}x text in '
            '$brightness', (tester) async {
          await pumpAt(tester,
              size: Size(scale == 1.0 ? 320 : 375, 667),
              textScale: scale,
              brightness: brightness,
              service:
                  _FakeSubscriptionService(offering: _offeringWithBothPlans()));
          final annual = find.byKey(const ValueKey('planCard_Annual'));
          final monthly = find.byKey(const ValueKey('planCard_Monthly'));
          await tester.scrollUntilVisible(annual, 250,
              scrollable: find.byType(Scrollable).first);
          final beforeAnnual = tester.getSize(annual);
          final beforeMonthly = tester.getSize(monthly);
          // 1.2.0: stacked (the mockup), so the cards share a width and a
          // left edge, not a top edge.
          expect(beforeAnnual.width, beforeMonthly.width);
          expect(tester.getTopLeft(annual).dx, tester.getTopLeft(monthly).dx);
          expect(
              tester.getTopLeft(monthly).dy - tester.getBottomLeft(annual).dy,
              10);
          expect(beforeAnnual.height, greaterThanOrEqualTo(87));
          expect(beforeMonthly.height, greaterThanOrEqualTo(87));
          await tester.ensureVisible(monthly);
          await tester.pumpAndSettle();
          await tester.tap(monthly);
          await tester.pumpAndSettle();
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
        find.descendant(of: footer, matching: find.byKey(PremiumScreen.ctaKey)),
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

    // The footer's measured height at the small sizes lives in the "fixed
    // footer on the smallest supported screens" group below. The old 40%
    // stop-and-report guard for 320x568 at 1.3x was measured in the test font
    // (about twice as wide as the real one) and predates the legal links
    // moving into the footer (2026-09-22, owner decision); it is replaced by
    // real-font assertions.

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
        await openComparison(tester);
        // At large scales the table falls back to the stacked layout (see
        // the "stacked comparison" group); either way nothing may overflow.
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('comparisonRow_Practice your weak spots')),
          300,
          scrollable: find.byType(Scrollable).first,
        );
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
        'the selected plan card has a 2 pt link-coloured edge, a filled radio '
        'mark and the info surface (1.2.0 mockup); the other card a 1 pt edge, '
        'an empty mark and the card surface', (tester) async {
      await pumpPremium(
        tester,
        _FakeSubscriptionService(offering: _offeringWithBothPlans()),
      );
      final theme = buildAppTheme(Brightness.light);
      final annualCard = find.byKey(const ValueKey('planCard_Annual'));
      final monthlyCard = find.byKey(const ValueKey('planCard_Monthly'));

      Border borderOf(Finder card) => (tester
              .widget<Container>(find
                  .descendant(of: card, matching: find.byType(Container))
                  .first)
              .decoration as BoxDecoration)
          .border as Border;
      Color? fillOf(Finder card) => tester
          .widget<Material>(
              find.descendant(of: card, matching: find.byType(Material)).first)
          .color;
      Finder mark(Finder card, IconData icon) =>
          find.descendant(of: card, matching: find.byIcon(icon));

      expect(borderOf(annualCard).top.width, 2);
      expect(borderOf(annualCard).top.color, theme.colorScheme.secondary);
      expect(fillOf(annualCard), theme.colorScheme.secondaryContainer);
      expect(
          mark(annualCard, Icons.radio_button_checked_rounded), findsOneWidget);
      expect(borderOf(monthlyCard).top.width, 1);
      expect(fillOf(monthlyCard), theme.colorScheme.surfaceContainerHigh);
      expect(mark(monthlyCard, Icons.radio_button_unchecked_rounded),
          findsOneWidget);

      await scrollAndTap(tester, find.text('Monthly'));
      expect(borderOf(monthlyCard).top.width, 2);
      expect(mark(monthlyCard, Icons.radio_button_checked_rounded),
          findsOneWidget);
      expect(borderOf(annualCard).top.width, 1);
      expect(mark(annualCard, Icons.radio_button_unchecked_rounded),
          findsOneWidget);
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
    // The hero is dropped on screens under 700 pt tall (an iPhone SE), and the
    // default test surface is 800x600, so these tests use a phone-sized one.
    void useTallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    List<Avatar?> avatarsShown(WidgetTester tester) => tester
        .widgetList<AvatarTile>(find.byType(AvatarTile))
        .map((tile) => tile.avatar)
        .toList();

    testWidgets(
        'shows exactly three avatars (O11), the center one matching the '
        "real profile's avatar", (tester) async {
      useTallScreen(tester);
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
      expect(shown, hasLength(3));
      expect(shown[1], profile.avatar);
    });

    testWidgets(
        'the two other avatars are distinct from the center and from '
        'each other, and are the same every time (deterministic, not '
        'Avatar.random)', (tester) async {
      useTallScreen(tester);
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
      expect(first, hasLength(3),
          reason: 'the center avatar plus two distinct others');
      expect(first.toSet(), hasLength(3),
          reason: 'no repeats among the three shown avatars');

      // Same profile, freshly pumped again — the four others must be the
      // exact same set, not re-rolled.
      final second = await pumpAndRead();
      expect(second.toSet(), first.toSet());
    });

    testWidgets(
        'a null avatar (legacy profile) never shows the generic '
        'placeholder — three real avatars are shown instead', (tester) async {
      useTallScreen(tester);
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

      expect(find.byType(AvatarTile), findsNWidgets(3));
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
      tester.view.physicalSize = const Size(320, 740) * 2.0;
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
        testWidgets(
            'opaque, separated and centered avatars at $width dark=$dark',
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
          // 1.2.0 (O11): three at every width.
          const count = 3;
          expect(tiles, findsNWidgets(count));
          expect(avatarsShown(tester)[count ~/ 2], profile.avatar);
          final rects =
              List.generate(count, (i) => tester.getRect(tiles.at(i)));
          final center = rects[count ~/ 2];
          expect(center.center.dx, closeTo(width / 2, 0.01));
          for (var i = 0; i < count; i++) {
            expect(rects[i].left, greaterThanOrEqualTo(0));
            expect(rects[i].right, lessThanOrEqualTo(width));
            if (i != count ~/ 2) expect(rects[i].width, lessThan(center.width));
            if (i > 0) {
              expect(
                  rects[i].left - rects[i - 1].right, greaterThanOrEqualTo(8));
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

      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

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
      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

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

      await scrollAndTap(tester, find.byKey(PremiumScreen.ctaKey));

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
      await openComparison(tester);
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
    await openComparison(tester);
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
      await openComparison(tester);

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
      await openComparison(tester);

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
      '"Compare Free & Premium" opens and closes the comparison table; it '
      'starts closed and says so to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpPremium(tester, _FakeSubscriptionService(offering: null));
    final toggle = find.byKey(PremiumScreen.compareToggleKey);
    expect(find.byKey(const Key('comparisonTable')), findsNothing);
    expect(tester.getSemantics(toggle),
        isSemantics(hasExpandedState: true, isExpanded: false, isButton: true));

    await openComparison(tester);
    expect(find.byKey(const Key('comparisonTable')), findsOneWidget);
    expect(tester.getSemantics(toggle),
        isSemantics(hasExpandedState: true, isExpanded: true, isButton: true));

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('comparisonTable')), findsNothing);
    semantics.dispose();
  });

  group(
      'the footer keeps its top border in every state: the legal links now sit '
      'above "Maybe later", so the rule separates them from the body', () {
    testWidgets('pricing unavailable: links and "Maybe later" under a border',
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
      expect(decoration.border, isNotNull);
      expect(
          find.descendant(
              of: find.byKey(const Key('premiumFooter')),
              matching: find.text('Privacy Policy')),
          findsOneWidget);
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
          theme: buildAppTheme(brightness ?? Brightness.light),
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
          expect(find.text(PremiumScreen.headline), findsOneWidget);
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
        'at 393x852 with pricing loaded, the button and the renewal terms are '
        'on the first screen in the fixed footer, and both plan cards are '
        'reachable above it (1.2.0: the companion group and the benefits card '
        'come first, so the cards are no longer all in view without '
        'scrolling)', (tester) async {
      await pumpAt(tester, const Size(393, 852));

      final footerTop =
          tester.getTopLeft(find.byKey(const Key('premiumFooter'))).dy;
      final viewportHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      final ctaRect = tester.getRect(find.byKey(PremiumScreen.ctaKey));
      expect(ctaRect.top, greaterThanOrEqualTo(footerTop));
      expect(ctaRect.bottom, lessThanOrEqualTo(viewportHeight));
      expect(tester.getRect(find.textContaining('auto-renews')).bottom,
          lessThanOrEqualTo(viewportHeight));

      final monthly = find.byKey(const ValueKey('planCard_Monthly'));
      await tester.ensureVisible(monthly);
      await tester.pumpAndSettle();
      expect(tester.getRect(monthly).bottom, lessThanOrEqualTo(footerTop));
      expect(tester.getRect(find.byKey(const ValueKey('planCard_Annual'))).top,
          greaterThanOrEqualTo(0));
    });
  });

  group(
      'fixed footer on the smallest supported screens: the button, the '
      'disclosure sentence and the legal links are on the first screen, '
      'measured in the real font', () {
    Future<void> pumpMeasured(
      WidgetTester tester, {
      required Size size,
      required AppTextSize textSize,
      double systemScale = 1,
      Brightness brightness = Brightness.light,
      bool pricingLoaded = true,
    }) async {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      // An iPhone SE has a 20 pt status bar and no home-indicator inset.
      tester.view.padding = const FakeViewPadding(top: 40);
      tester.view.viewPadding = const FakeViewPadding(top: 40);
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = systemScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness, textSize: textSize),
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(
              offering: pricingLoaded ? _offeringWithBothPlans() : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    // The scrolling body's own scrollable (the footer does not scroll).
    final bodyScrollable = find.ancestor(
        of: find.byKey(const Key('premiumBody')),
        matching: find.byType(Scrollable));

    /// Every rectangle is in screen coordinates, so "on the first screen"
    /// simply means inside the viewport, with nothing scrolled.
    Future<
        ({
          Rect footer,
          Rect scrollRegion,
          Rect cta,
          Rect disclosure,
          Rect privacy,
          Rect terms,
          Rect maybeLater,
          Rect privacyTarget,
          Rect termsTarget,
          Rect maybeLaterTarget,
          bool disclosureTruncated,
        })> measure(WidgetTester tester) async {
      final disclosureFinder = find.textContaining('auto-renews');
      // A text button's tappable area is the ink well inside it.
      Rect target(String label) => tester.getRect(find.descendant(
          of: find.widgetWithText(TextButton, label),
          matching: find.byType(InkWell)));
      return (
        footer: tester.getRect(find.byKey(const Key('premiumFooter'))),
        scrollRegion: tester.getRect(find.ancestor(
            of: find.byKey(const Key('premiumBody')),
            matching: find.byType(SingleChildScrollView))),
        cta: tester.getRect(find.byKey(PremiumScreen.ctaKey)),
        disclosure: tester.getRect(disclosureFinder),
        privacy: tester.getRect(find.text('Privacy Policy')),
        terms: tester.getRect(find.text('Terms of Service')),
        maybeLater: tester.getRect(find.text('Maybe later')),
        privacyTarget: target('Privacy Policy'),
        termsTarget: target('Terms of Service'),
        maybeLaterTarget: target('Maybe later'),
        disclosureTruncated: tester
            .renderObject<RenderParagraph>(disclosureFinder)
            .didExceedMaxLines,
      );
    }

    void expectOnFirstScreen(dynamic m, double screenHeight) {
      for (final entry in {
        'the purchase button': m.cta as Rect,
        'the disclosure sentence': m.disclosure as Rect,
        'the Privacy Policy link': m.privacy as Rect,
        'the Terms of Service link': m.terms as Rect,
        'Maybe later': m.maybeLater as Rect,
      }.entries) {
        expect(entry.value.top, greaterThanOrEqualTo(m.scrollRegion.top),
            reason: '${entry.key} starts inside the screen');
        expect(entry.value.bottom, lessThanOrEqualTo(screenHeight),
            reason: '${entry.key} ends inside the screen (no scrolling)');
      }
      // The links are in the fixed footer, below the scrolling region.
      expect(m.privacy.top, greaterThanOrEqualTo(m.footer.top));
      expect(m.terms.top, greaterThanOrEqualTo(m.footer.top));
      expect(m.disclosureTruncated, isFalse,
          reason: 'the disclosure sentence is never cut off');
      // The footer was tightened without shrinking any target: the legal links
      // and "Maybe later" are at least 44 pt tall, and the purchase button
      // keeps the app's button height (48 since 1.2.0, 52 before).
      for (final entry in {
        'the Privacy Policy link': m.privacyTarget as Rect,
        'the Terms of Service link': m.termsTarget as Rect,
        'Maybe later': m.maybeLaterTarget as Rect,
      }.entries) {
        expect(entry.value.height, greaterThanOrEqualTo(44),
            reason: '${entry.key} keeps a 44 pt target');
        expect(entry.value.width, greaterThanOrEqualTo(44),
            reason: '${entry.key} is at least 44 pt wide');
      }
      expect((m.cta as Rect).height, greaterThanOrEqualTo(48));
    }

    // The two sizes the owner asked for, at the sizes the app offers: on an
    // iPhone SE (375x667), Medium (the default) and Large, and also with the
    // system text scale at 1.6x.
    for (final textSize in [AppTextSize.medium, AppTextSize.large]) {
      testWidgets(
          '375x667, ${textSize.name}: button, disclosure and both legal '
          'links are on the first screen, and the footer stays a third of it',
          (tester) async {
        await pumpMeasured(tester,
            size: const Size(375, 667), textSize: textSize);
        final m = await measure(tester);

        expectOnFirstScreen(m, 667);
        // 196 pt at Medium and 200 pt at Large (218 and 222 before the
        // 2026-09-22 spacing pass): under a third of the screen.
        expect(m.footer.height / 667, lessThan(0.31));
        // The text above it keeps more room than before (373 and 369 pt).
        expect(m.scrollRegion.height, greaterThan(385));
        // The avatar hero is dropped on a screen this short...
        expect(find.byType(AvatarTile), findsNothing);
        // ...which lifts the content: the headline and the start of the
        // benefits card are in view (1.2.0: the comparison table is behind
        // "Compare Free & Premium" and the plan cards come after the
        // benefits, so neither is in view without scrolling any more).
        expect(tester.getRect(find.text(PremiumScreen.headline)).bottom,
            lessThan(m.scrollRegion.bottom));
        expect(tester.getRect(find.text('Understand your mistakes')).top,
            lessThan(m.scrollRegion.bottom));
        final annual = find.byKey(const ValueKey('planCard_Annual'));
        await tester.scrollUntilVisible(annual, 200,
            scrollable: bodyScrollable);
        expect(tester.getRect(annual).top,
            greaterThanOrEqualTo(m.scrollRegion.top));
        // Restore Purchases: in the fixed footer since 1.2.0 (the mockup),
        // on the first screen.
        expect(
            find.descendant(
                of: find.byKey(const Key('premiumFooter')),
                matching: find.text('Restore Purchases')),
            findsOneWidget);
        expect(tester.getRect(find.text('Restore Purchases')).bottom,
            lessThanOrEqualTo(667));
      });

      testWidgets(
          '375x667, ${textSize.name}, system text 1.6x: still all on the first '
          'screen, the disclosure wraps to more lines instead of being cut, '
          'and the text area keeps a usable height', (tester) async {
        await pumpMeasured(tester,
            size: const Size(375, 667), textSize: textSize, systemScale: 1.6);
        final m = await measure(tester);

        expectOnFirstScreen(m, 667);
        // About 295 pt (321 before the spacing pass).
        expect(m.footer.height / 667, lessThan(0.46));
        expect(m.scrollRegion.height, greaterThan(285));
      });
    }

    testWidgets(
        '375x667 Medium: the footer stack is tight: the disclosure sits close '
        'under the button, the links directly under the disclosure, and '
        '"Maybe later" directly under the links, each a 44 pt target',
        (tester) async {
      await pumpMeasured(tester,
          size: const Size(375, 667), textSize: AppTextSize.medium);
      final m = await measure(tester);

      // Button to disclosure: a small gap, never more than 6 pt.
      expect(m.disclosure.top - m.cta.bottom, inInclusiveRange(0, 6));
      // Disclosure to the links row, and the links row to "Maybe later":
      // the targets are stacked with no space between them.
      final linksTop = m.privacyTarget.top;
      expect(linksTop - m.disclosure.bottom, inInclusiveRange(0, 1));
      expect(m.maybeLaterTarget.top - m.privacyTarget.bottom,
          inInclusiveRange(0, 1));
      // Padding above the button and under "Maybe later".
      expect(m.cta.top - m.footer.top, lessThanOrEqualTo(8));
      expect(m.footer.bottom - m.maybeLaterTarget.bottom, lessThanOrEqualTo(4));
      // The whole footer, 375x667 Medium: 196 pt (218 before).
      expect(m.footer.height, lessThanOrEqualTo(196));
    });

    testWidgets(
        'beyond what the screen can hold (375x667 at 3x text) the links go '
        'back to the end of the scrolling body, so the footer never takes '
        'over the screen', (tester) async {
      await pumpMeasured(tester,
          size: const Size(375, 667),
          textSize: AppTextSize.medium,
          systemScale: 3);
      final footer = find.byKey(const Key('premiumFooter'));

      expect(find.descendant(of: footer, matching: find.text('Privacy Policy')),
          findsNothing);
      expect(tester.takeException(), isNull);
      // Still there, at the end of the body.
      await tester.scrollUntilVisible(find.text('Privacy Policy'), 300,
          scrollable: bodyScrollable);
      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
    });

    testWidgets(
        '320x568 at the default size also fits everything, in both '
        'themes, with links in the footer', (tester) async {
      for (final brightness in Brightness.values) {
        await pumpMeasured(tester,
            size: const Size(320, 568),
            textSize: AppTextSize.medium,
            brightness: brightness);
        final m = await measure(tester);
        expectOnFirstScreen(m, 568);
        expect(m.scrollRegion.height, greaterThan(250));
      }
    });

    testWidgets(
        'the pricing-unavailable state also has the links in the footer, '
        'never gated on pricing loading', (tester) async {
      await pumpMeasured(tester,
          size: const Size(375, 667),
          textSize: AppTextSize.large,
          pricingLoaded: false);
      final footer = find.byKey(const Key('premiumFooter'));

      expect(find.descendant(of: footer, matching: find.text('Privacy Policy')),
          findsOneWidget);
      expect(
          find.descendant(of: footer, matching: find.text('Terms of Service')),
          findsOneWidget);
      expect(tester.getRect(find.text('Terms of Service')).bottom,
          lessThanOrEqualTo(667));
    });

    testWidgets(
        'the avatar hero shows on a tall screen and is dropped under 700 pt',
        (tester) async {
      await pumpMeasured(tester,
          size: const Size(390, 844), textSize: AppTextSize.medium);
      expect(find.byType(AvatarTile), findsWidgets);

      await pumpMeasured(tester,
          size: const Size(390, 699), textSize: AppTextSize.medium);
      expect(find.byType(AvatarTile), findsNothing);

      await pumpMeasured(tester,
          size: const Size(390, 700), textSize: AppTextSize.medium);
      expect(find.byType(AvatarTile), findsWidgets);
    });
  });

  group(
      'stacked comparison layout (launch checklist item 3): when the three '
      'table columns do not fit, rows stack — no horizontal scroll, no '
      'dropped content, no overflow', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required Size size,
      required double textScale,
      required Brightness brightness,
      required bool pricingLoaded,
    }) async {
      tester.view.physicalSize = size * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(
              offering: pricingLoaded ? _offeringWithBothPlans() : null,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await openComparison(tester);
    }

    const labels = [
      'Daily Test, refreshed every day',
      'Topic Practice, all five topics',
      'Practice your weak spots',
      'Sessions of 3, 5 or 10 questions',
    ];

    // The two launch-checklist targets: 320x667 at 2x text and 375x667 at 3x.
    for (final target in [
      (size: const Size(320, 667), scale: 2.0),
      (size: const Size(375, 667), scale: 3.0),
    ]) {
      for (final brightness in Brightness.values) {
        for (final pricingLoaded in [true, false]) {
          testWidgets(
              'stacks cleanly at ${target.size.width.toInt()}x'
              '${target.size.height.toInt()} @${target.scale}x text, '
              '$brightness, pricing ${pricingLoaded ? 'loaded' : 'unavailable'}',
              (tester) async {
            await pumpAt(
              tester,
              size: target.size,
              textScale: target.scale,
              brightness: brightness,
              pricingLoaded: pricingLoaded,
            );
            final stacked = find.byKey(const Key('comparisonStacked'));
            await tester.scrollUntilVisible(stacked, 300,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull,
                reason: 'no overflow anywhere on the screen');
            expect(find.byKey(const Key('comparisonTable')), findsNothing);

            // Never a sideways scroller inside the comparison.
            expect(
              find.descendant(
                of: stacked,
                matching: find.byWidgetPredicate((w) =>
                    w is SingleChildScrollView &&
                    w.scrollDirection == Axis.horizontal),
              ),
              findsNothing,
            );

            // Nothing dropped: every label is present in full (no maxLines /
            // ellipsis on a stacked label), plus the free quota phrase.
            for (final label in labels) {
              final text =
                  find.descendant(of: stacked, matching: find.text(label));
              expect(text, findsOneWidget, reason: label);
              expect(tester.widget<Text>(text).maxLines, isNull);
              expect(tester.widget<Text>(text).overflow, isNull);
            }
            expect(find.descendant(of: stacked, matching: find.text('1 a day')),
                findsOneWidget);

            // Every row and everything in it stays inside the screen width.
            final screenWidth = target.size.width;
            for (final label in labels) {
              final row = find.byKey(ValueKey('comparisonRow_$label'));
              final rowRect = tester.getRect(row);
              expect(rowRect.left, greaterThanOrEqualTo(0));
              expect(rowRect.right, lessThanOrEqualTo(screenWidth));
              for (final tier in ['FREE', 'PREMIUM']) {
                final chip =
                    find.descendant(of: row, matching: find.text(tier));
                final chipRect = tester.getRect(chip);
                expect(chipRect.left, greaterThanOrEqualTo(rowRect.left));
                expect(chipRect.right, lessThanOrEqualTo(rowRect.right),
                    reason: '$tier chip inside its row');
              }
            }

            // Screen readers still get one explicit sentence per cell.
            expect(
                find.bySemanticsLabel('Included in Premium'), findsNWidgets(4));
            expect(find.bySemanticsLabel('Included in Free'), findsOneWidget);
            expect(find.bySemanticsLabel('Not included in Free'),
                findsNWidgets(2));
          });
        }
      }
    }

    // The pricing-unavailable card has its own icon + sentence + retry row.
    // It keeps that row on normal screens and drops the retry below the
    // sentence only when the row cannot fit.
    for (final config in [
      (size: const Size(393, 852), scale: 1.0, stacked: false),
      (size: const Size(375, 667), scale: 1.0, stacked: false),
      (size: const Size(320, 667), scale: 2.0, stacked: true),
      (size: const Size(375, 667), scale: 3.0, stacked: true),
    ]) {
      testWidgets(
          'the unavailable card ${config.stacked ? 'stacks its retry' : 'stays one row'} '
          'at ${config.size.width.toInt()}x${config.size.height.toInt()} '
          '@${config.scale}x text', (tester) async {
        await pumpAt(
          tester,
          size: config.size,
          textScale: config.scale,
          brightness: Brightness.light,
          pricingLoaded: false,
        );
        final card = find.byKey(const Key('pricingUnavailableCard'));
        await tester.scrollUntilVisible(card, 300,
            scrollable: find.byType(Scrollable).first);
        final message = find.descendant(
            of: card, matching: find.textContaining("Prices aren't"));
        final retry =
            find.descendant(of: card, matching: find.text('Try again'));
        expect(tester.takeException(), isNull);
        final cardRect = tester.getRect(card);
        expect(tester.getRect(retry).right, lessThanOrEqualTo(cardRect.right));
        expect(
            tester.getRect(message).right, lessThanOrEqualTo(cardRect.right));
        if (config.stacked) {
          expect(tester.getRect(retry).top,
              greaterThanOrEqualTo(tester.getRect(message).bottom));
        } else {
          expect(tester.getRect(retry).left,
              greaterThanOrEqualTo(tester.getRect(message).right));
        }
      });
    }

    // Which layout each size gets, measured in the real font. The rule: the
    // three-column table only where every label reads in full in its two
    // lines; anywhere a label would be cut off with an ellipsis, stacked.
    // Sizes with no clipping keep the existing table unchanged.
    const keepTable = <(double, double)>[
      (360, 1.0),
      (375, 1.0),
      (390, 1.0),
      (393, 1.0),
      (414, 1.0),
      (430, 1.0),
      (360, 1.1),
      (375, 1.1),
      (390, 1.1),
      (393, 1.1),
      (414, 1.1),
      (430, 1.1),
      (375, 1.15),
      (390, 1.15),
      (393, 1.15),
      (414, 1.15),
      (430, 1.15),
      (414, 1.3),
      (430, 1.3),
    ];
    // Sizes where the previous table cut a label to two lines with an
    // ellipsis (320 @1x among them) plus every size beyond. 1.2.0 Batch 1:
    // the type scale's smaller default text (batch0-report.md Q5) fits the
    // labels at 360 @1.15x and 393 @1.3x, so those two moved to keepTable;
    // the rule itself is unchanged. 1.2.0 Q18: the 14 pt side padding below
    // 360 pt (16 before) gives the table room to fit at 320 @1x too.
    // 1.2.0 Batch 12: the paywall's page edge is the mockup's 20 pt (15
    // under 360 pt; 18 and 14 before), so the table is 2 pt narrower on each
    // side and three more sizes stack: 320 @1x, 360 @1.15x, 393 @1.3x. The
    // rule is unchanged: a table only where no label is cut.
    const nowStacked = <(double, double)>[
      (320, 1.0),
      (360, 1.15),
      (393, 1.3),
      (320, 1.1),
      (320, 1.15),
      (320, 1.3),
      (360, 1.3),
      (375, 1.3),
      (390, 1.3),
      (375, 1.5),
      (393, 1.5),
      (430, 1.5),
      (320, 2.0),
      (375, 2.0),
      (430, 2.0),
      (320, 3.0),
      (375, 3.0),
      (430, 3.0),
    ];

    for (final entry in [
      ...keepTable.map((c) => (c, true)),
      ...nowStacked.map((c) => (c, false)),
    ]) {
      final (size, scale) = entry.$1;
      final expectTable = entry.$2;
      for (final pricingLoaded in [true, false]) {
        testWidgets(
            '${expectTable ? 'keeps the table' : 'stacks'} at '
            '${size.toInt()}x667 @${scale}x text, pricing '
            '${pricingLoaded ? 'loaded' : 'unavailable'}', (tester) async {
          await pumpAt(
            tester,
            size: Size(size, 667),
            textScale: scale,
            brightness: Brightness.light,
            pricingLoaded: pricingLoaded,
          );
          final layout = find.byKey(
              Key(expectTable ? 'comparisonTable' : 'comparisonStacked'));
          await tester.scrollUntilVisible(layout, 300,
              scrollable: find.byType(Scrollable).first);
          expect(tester.takeException(), isNull);
          expect(
            find.byKey(
                Key(expectTable ? 'comparisonStacked' : 'comparisonTable')),
            findsNothing,
          );

          // The invariant behind the rule: whichever layout is on screen,
          // no label is cut off.
          for (final label in labels) {
            final text = find.descendant(
              of: find.byKey(ValueKey('comparisonRow_$label')),
              matching: find.text(label),
            );
            expect(tester.renderObject<RenderParagraph>(text).didExceedMaxLines,
                isFalse,
                reason: '"$label" is clipped at ${size.toInt()} @${scale}x');
          }
          if (expectTable) {
            expect(find.byKey(const Key('premiumStripHeader')), findsOneWidget);
          }
        });
      }
    }
  });

  group('the 1.2.0 paywall (additional screens Batch 12)', () {
    String ctaLabel(WidgetTester tester) {
      final cta = find.byKey(PremiumScreen.ctaKey);
      return tester
          .widgetList<Text>(
              find.descendant(of: cta, matching: find.byType(Text)))
          .map((t) => t.data)
          .join();
    }

    Future<void> scrollWholeScreen(WidgetTester tester) async {
      await openComparison(tester);
      for (var i = 0; i < 8; i++) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
    }

    testWidgets(
        'not eligible for a trial: no trial anywhere; the button and the terms '
        'state the price and the period, for either plan', (tester) async {
      await pumpPremium(
          tester,
          _FakeSubscriptionService(
              offering: _offeringWithBothPlans(),
              eligibility: TrialEligibility.ineligible));
      expect(ctaLabel(tester), 'Subscribe for \$89.99 per year');
      expect(find.text('\$89.99 per year, auto-renews unless cancelled.'),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('planCard_Annual')),
              matching: find.text('Billed yearly')),
          findsOneWidget);
      await scrollAndTap(tester, find.text('Monthly'));
      expect(ctaLabel(tester), 'Subscribe for \$9.99 per month');
      expect(find.text('\$9.99 per month, auto-renews unless cancelled.'),
          findsOneWidget);
      await scrollWholeScreen(tester);
      expect(find.textContaining('trial'), findsNothing);
      expect(find.textContaining('free,'), findsNothing);
    });

    testWidgets(
        'eligibility unknown (a failed or unconfigured check): a neutral '
        'button, the price in the terms, and no trial promised',
        (tester) async {
      await pumpPremium(
          tester,
          _FakeSubscriptionService(
              offering: _offeringWithBothPlans(),
              eligibility: TrialEligibility.unknown));
      expect(ctaLabel(tester), 'Continue with Annual');
      expect(find.text('\$89.99 per year, auto-renews unless cancelled.'),
          findsOneWidget);
      await scrollAndTap(tester, find.text('Monthly'));
      expect(ctaLabel(tester), 'Continue with Monthly');
      await scrollWholeScreen(tester);
      expect(find.textContaining('trial'), findsNothing);
    });

    testWidgets(
        'eligible but the product has no introductory offer: no trial (the '
        'live prices carry none)', (tester) async {
      await pumpPremium(tester,
          _FakeSubscriptionService(offering: _offeringWithRealLivePrices()));
      expect(ctaLabel(tester), 'Subscribe for \$49.99 per year');
      expect(find.text('\$49.99 per year, auto-renews unless cancelled.'),
          findsOneWidget);
      expect(find.textContaining('trial'), findsNothing);
    });

    testWidgets(
        'nothing is hardcoded: other prices, another currency and a two-week '
        'trial come through as they are', (tester) async {
      await pumpPremium(
          tester, _FakeSubscriptionService(offering: _offeringInEuros()));
      expect(ctaLabel(tester), 'Start my 14-day free trial');
      expect(
          find.text('14 days free, then €39.99 per year, auto-renews unless '
              'cancelled.'),
          findsOneWidget);
      expect(find.textContaining('\$'), findsNothing);
      expect(find.textContaining('7-day'), findsNothing);
      // 1 - 39.99 / (12 × 4.99) ≈ 33.2%
      expect(find.text('Save 33%'), findsOneWidget);
      await scrollAndTap(tester, find.text('Monthly'));
      expect(ctaLabel(tester), 'Subscribe for €4.99 per month',
          reason: 'the monthly product has no introductory offer');
    });

    testWidgets('a second tap while purchasing sends no second request',
        (tester) async {
      final completer = Completer<PurchaseOutcome>();
      final service = _FakeSubscriptionService(
          offering: _offeringWithBothPlans(), purchaseCompleter: completer);
      await pumpPremium(tester, service);
      await tester.tap(find.byKey(PremiumScreen.ctaKey));
      await tester.tap(find.byKey(PremiumScreen.ctaKey), warnIfMissed: false);
      await tester.pump();
      expect(service.purchaseCalls, 1);
      expect(
          tester
              .widget<FilledButton>(find.byKey(PremiumScreen.ctaKey))
              .onPressed,
          isNull);
      completer.complete(PurchaseOutcome.cancelled);
      await tester.pumpAndSettle();
      expect(service.purchaseCalls, 1);
    });

    testWidgets(
        'a pending purchase (Ask to Buy) has its own message, opens nothing '
        'and logs purchase_result with outcome pending, once (O10)',
        (tester) async {
      final analytics = _FakeAnalyticsService();
      await pumpPremium(
          tester,
          _FakeSubscriptionService(
              offering: _offeringWithBothPlans(),
              purchaseOutcome: PurchaseOutcome.pending),
          analyticsService: analytics);
      await tester.tap(find.byKey(PremiumScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('Waiting for approval'), findsOneWidget);
      expect(find.textContaining("couldn't start"), findsNothing);
      expect(find.textContaining('unlocked'), findsNothing);
      expect(analytics.calls.map((c) => c.name), contains('purchase_started'));
      final results =
          analytics.calls.where((c) => c.name == 'purchase_result').toList();
      expect(results, hasLength(1));
      expect(results.single.parameters,
          {'plan': AnalyticsService.planAnnual, 'outcome': 'pending'});
      expect(find.text('Maybe later'), findsOneWidget);
    });

    testWidgets(
        'a purchase with no trial says Premium is active, not that a trial '
        'started', (tester) async {
      await pumpPremium(
          tester,
          _FakeSubscriptionService(
              offering: _offeringWithBothPlans(),
              eligibility: TrialEligibility.ineligible,
              purchaseOutcome: PurchaseOutcome.success));
      await tester.tap(find.byKey(PremiumScreen.ctaKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('Premium is active'), findsOneWidget);
      expect(find.textContaining('Trial started'), findsNothing);
    });

    for (final restored in [true, false]) {
      testWidgets('Restore Purchases reports what it found ($restored)',
          (tester) async {
        await pumpPremium(
            tester,
            _FakeSubscriptionService(
                offering: _offeringWithBothPlans(), restoreResult: restored));
        await tester.tap(find.byKey(PremiumScreen.restoreKey));
        await tester.pumpAndSettle();
        expect(
            find.text(restored
                ? 'Purchases restored — full access is active.'
                : 'No previous purchases found to restore.'),
            findsOneWidget);
      });
    }

    testWidgets(
        'no "Have a code?" and no code field (redeem codes deferred); no '
        '"unlimited" anywhere; the session cap is stated', (tester) async {
      await pumpPremium(
          tester, _FakeSubscriptionService(offering: _offeringWithBothPlans()));
      await scrollWholeScreen(tester);
      expect(find.textContaining('code'), findsNothing);
      expect(find.textContaining('Code'), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('nlimited'), findsNothing);
      expect(
          find.textContaining(
              'up to ${StorageService.dailySessionLimit} sessions a day'),
          findsOneWidget);
    });

    testWidgets(
        'the benefits match the real tiers: free users keep their daily '
        'practice and its AI feedback, so nothing says AI is Premium-only',
        (tester) async {
      await pumpPremium(tester, _FakeSubscriptionService(offering: null));
      expect(
          find.text('AI feedback on every topic you practice, not just your '
              'free daily practice.'),
          findsOneWidget);
      expect(
          find.text('Go beyond your one free daily practice.'), findsOneWidget);
      expect(find.textContaining('only in Premium'), findsNothing);
      expect(find.textContaining('AI feedback explains'), findsNothing);
    });

    testWidgets('paywall_viewed carries every source value as it is',
        (tester) async {
      for (final source in [
        AnalyticsService.paywallSourceHome,
        AnalyticsService.paywallSourceWeakSpotQuota,
        AnalyticsService.paywallSourceReviewQuota,
        AnalyticsService.paywallSourcePracticeLaunch,
        AnalyticsService.paywallSourcePracticeResult,
        AnalyticsService.paywallSourceDay0AfterClimb,
      ]) {
        final analytics = _FakeAnalyticsService();
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(),
            analyticsService: analytics,
            analyticsSource: source,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ));
        await tester.pumpAndSettle();
        final viewed =
            analytics.calls.where((c) => c.name == 'paywall_viewed').toList();
        expect(viewed, hasLength(1), reason: source);
        expect(viewed.single.parameters, {'source': source});
      }
    });

    testWidgets('the centre companion is the user\'s own, whichever it is',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      for (final avatar in [
        Avatar.values.first,
        Avatar.values[7],
        Avatar.values.last
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(MaterialApp(
          home: PremiumScreen(
            storageService: _FakeStorageServiceForAvatar(UserProfile(
                name: 'Ada', learningGoal: LearningGoal.work, avatar: avatar)),
            analyticsService: _FakeAnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _FakeSubscriptionService(offering: null),
          ),
        ));
        await tester.pumpAndSettle();
        final tiles =
            tester.widgetList<AvatarTile>(find.byType(AvatarTile)).toList();
        expect(tiles, hasLength(3));
        expect(tiles[1].avatar, avatar);
        expect(tiles[1].radius * 2, 124);
        expect(tiles[0].radius * 2, 66);
        expect(tiles[2].radius * 2, 66);
        expect({tiles[0].avatar, tiles[2].avatar}.contains(avatar), isFalse);
      }
    });

    for (final size in [
      const Size(320, 568),
      const Size(360, 740),
      const Size(375, 667),
      const Size(390, 844),
      const Size(430, 932),
    ]) {
      for (final brightness in Brightness.values) {
        testWidgets(
            '${size.width.toInt()}x${size.height.toInt()}, Large text, '
            '${brightness.name}: no overflow with the comparison open, the '
            'button and the terms on the first screen', (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            theme: buildAppTheme(brightness, textSize: AppTextSize.large),
            home: PremiumScreen(
              storageService: _FakeStorageServiceForAvatar(),
              analyticsService: _FakeAnalyticsService(),
              analyticsSource: AnalyticsService.paywallSourceHome,
              subscriptionService:
                  _FakeSubscriptionService(offering: _offeringWithBothPlans()),
            ),
          ));
          await tester.pumpAndSettle();
          expect(tester.getRect(find.byKey(PremiumScreen.ctaKey)).bottom,
              lessThanOrEqualTo(size.height));
          expect(tester.getRect(find.textContaining('auto-renews')).bottom,
              lessThanOrEqualTo(size.height));
          await scrollWholeScreen(tester);
          await scrollAndTap(tester, find.text('Monthly'));
          expect(tester.takeException(), isNull);
          // Nothing cut: the comparison labels may carry an ellipsis as a
          // last resort, but the table is only used where none is reached.
          for (final element in find.byType(Text).evaluate()) {
            final paragraph = element.renderObject is RenderParagraph
                ? element.renderObject! as RenderParagraph
                : tester.renderObject<RenderParagraph>(find
                    .descendant(
                        of: find.byWidget(element.widget),
                        matching: find.byType(RichText))
                    .first);
            expect(paragraph.didExceedMaxLines, isFalse,
                reason: (element.widget as Text).data);
          }
        });
      }
    }
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

/// Prices in euros, a two-week annual trial and no monthly trial: proves the
/// screen prints what the store gives, not this app's own numbers.
Offering _offeringInEuros() {
  const context = PresentedOfferingContext('default', null, null);
  const monthlyProduct = StoreProduct(
    'grammarlens_premium_monthly',
    'Full access to Topic Practice',
    'GrammarLens Premium (Monthly)',
    4.99,
    '€4.99',
    'EUR',
    subscriptionPeriod: 'P1M',
  );
  const annualProduct = StoreProduct(
    'grammarlens_premium_annual',
    'Full access to Topic Practice (annual)',
    'GrammarLens Premium (Annual)',
    39.99,
    '€39.99',
    'EUR',
    introductoryPrice: IntroductoryPrice(
      0,
      '€0.00',
      'P2W',
      1,
      PeriodUnit.week,
      2,
    ),
    subscriptionPeriod: 'P1Y',
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
