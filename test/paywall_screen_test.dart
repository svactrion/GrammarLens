import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:grammar_lens/screens/paywall_screen.dart';
import 'package:grammar_lens/services/subscription_service.dart';

/// Real [SubscriptionService] methods go through RevenueCat's platform
/// channel, which just hangs forever in a plain widget test (no engine to
/// answer it, unlike a real device/simulator where an unconfigured SDK at
/// least throws and gets caught — see the class's own try/catch). Faking
/// the service here is what actually lets these tests exercise every
/// outcome path (unavailable / trial available / success / cancelled /
/// error) deterministically, matching this repo's existing pattern of
/// subclassing a service and overriding methods for a test double (see
/// `_RecordingAnalyticsService` in home_screen_test.dart).
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

Package _fakePackage() {
  const context = PresentedOfferingContext('default', null, null);
  const product = StoreProduct(
    'grammarlens_premium_monthly',
    'Full access to Topic Practice',
    'GrammarLens Premium',
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

void main() {
  Future<void> pumpPaywall(
    WidgetTester tester,
    SubscriptionService service,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: PaywallScreen(subscriptionService: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
      'with no RevenueCat product connected, shows an unavailable state '
      'instead of crashing or hanging', (tester) async {
    await pumpPaywall(tester, _FakeSubscriptionService(offering: null));

    // No RevenueCat SDK key is configured on the simulator today either
    // (see docs/roadmap.md) — getOfferings() fails safe to null there too,
    // so this is the state real testing on-device is expected to hit.
    expect(
      find.text("Trial pricing isn't available right now"),
      findsOneWidget,
    );
    expect(find.text('Start free trial'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('leads with the personalized-feedback pitch, not a feature list',
      (tester) async {
    await pumpPaywall(tester, _FakeSubscriptionService(offering: null));
    expect(
      find.text('Personalized feedback, not a feature list'),
      findsOneWidget,
    );
  });

  testWidgets('Restore Purchases is always reachable and never crashes',
      (tester) async {
    await pumpPaywall(tester, _FakeSubscriptionService(offering: null));

    await tester.tap(find.text('Restore Purchases'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No previous purchases found'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Privacy Policy / Terms links are present but disabled while '
      "AppLinks' URLs are still empty (no hosted pages exist yet)",
      (tester) async {
    await pumpPaywall(tester, _FakeSubscriptionService(offering: null));

    expect(find.text('Privacy Policy'), findsOneWidget);
    expect(find.text('Terms of Service'), findsOneWidget);

    final privacyButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Privacy Policy'));
    final termsButton =
        tester.widget<TextButton>(find.widgetWithText(TextButton, 'Terms of Service'));
    // AppLinks.privacyPolicyUrl / termsUrl are still the empty pre-launch
    // placeholder (see app_links.dart) — disabled (onPressed: null), not a
    // dead/broken tap that goes nowhere.
    expect(privacyButton.onPressed, isNull);
    expect(termsButton.onPressed, isNull);
  });

  group('with a package available (a real RevenueCat product connected)', () {
    final package = _fakePackage();
    late Offering offering;

    setUp(() {
      offering = Offering(
        'default',
        'Default offering',
        const {},
        [package],
        monthly: package,
      );
    });

    testWidgets('states trial length, price, billing period, and auto-renewal',
        (tester) async {
      await pumpPaywall(
        tester,
        _FakeSubscriptionService(offering: offering),
      );

      expect(find.text('3-day free trial'), findsOneWidget);
      expect(find.textContaining('\$9.99 / month'), findsOneWidget);
      expect(find.textContaining('Auto-renews until cancelled'), findsOneWidget);
      expect(find.text('Start free trial'), findsOneWidget);
    });

    testWidgets('a successful purchase shows a success state', (tester) async {
      final service = _FakeSubscriptionService(
        offering: offering,
        purchaseOutcome: PurchaseOutcome.success,
      );
      await pumpPaywall(tester, service);

      await tester.tap(find.text('Start free trial'));
      await tester.pumpAndSettle();

      expect(service.purchaseCalls, 1);
      expect(
        find.textContaining('Trial started — Topic Practice is unlocked'),
        findsOneWidget,
      );
    });

    testWidgets('a cancelled purchase shows a cancelled state, not an error',
        (tester) async {
      await pumpPaywall(
        tester,
        _FakeSubscriptionService(
          offering: offering,
          purchaseOutcome: PurchaseOutcome.cancelled,
        ),
      );

      await tester.tap(find.text('Start free trial'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Purchase cancelled — no charge was made'),
        findsOneWidget,
      );
    });

    testWidgets(
        'a failed purchase (expected with no real product connected) shows '
        'a clear error state, not a crash', (tester) async {
      await pumpPaywall(
        tester,
        _FakeSubscriptionService(
          offering: offering,
          purchaseOutcome: PurchaseOutcome.failure,
        ),
      );

      await tester.tap(find.text('Start free trial'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining("couldn't start"),
        findsOneWidget,
      );
    });
  });
}
