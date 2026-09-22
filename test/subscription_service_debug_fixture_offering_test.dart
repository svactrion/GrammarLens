import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show PeriodUnit;

import 'package:grammar_lens/services/subscription_service.dart';

/// Exercises the real [SubscriptionService] (not a fake), the same
/// reasoning as `subscription_service_debug_override_test.dart`: reading/
/// setting the fixture is a local, platform-channel-free operation, safe
/// without a real RevenueCat project connected.
void main() {
  final service = SubscriptionService();

  tearDown(() {
    // Restore both the debug-mode simulation and the fixture itself so no
    // state leaks into the next test in this file.
    SubscriptionService.debugModeForTesting = kDebugMode;
    service.setDebugFixtureOffering(enabled: false);
  });

  test(
      'no fixture enabled: getOfferings falls through to the real, '
      'unconfigured-project default of null', () async {
    expect(service.debugFixtureOffering, isNull);
    expect(await service.getOfferings(), isNull);
  });

  test('enabling the fixture makes getOfferings return it', () async {
    service.setDebugFixtureOffering(enabled: true);

    expect(service.debugFixtureOffering, isNotNull);
    final offering = await service.getOfferings();
    expect(offering, same(service.debugFixtureOffering));
  });

  test('disabling the fixture returns to the real (null) status', () async {
    service.setDebugFixtureOffering(enabled: true);
    expect(await service.getOfferings(), isNotNull);

    service.setDebugFixtureOffering(enabled: false);
    expect(service.debugFixtureOffering, isNull);
    expect(await service.getOfferings(), isNull);
  });

  group('the fixture itself (buildDebugFixtureOffering)', () {
    final offering = buildDebugFixtureOffering();

    test(
        'has both a monthly and an annual package, annual preselected-'
        'compatible', () {
      expect(offering.monthly, isNotNull);
      expect(offering.annual, isNotNull);
    });

    test(
        'monthly is \$5.99 with a 3-day trial (PRD v2 §13.2, '
        '2026-09-17 note)', () {
      final product = offering.monthly!.storeProduct;
      expect(product.price, 5.99);
      expect(product.priceString, r'$5.99');
      expect(product.introductoryPrice?.periodUnit, PeriodUnit.day);
      expect(product.introductoryPrice?.periodNumberOfUnits, 3);
    });

    test(
        'annual is \$49.99 with a 1-week trial, mirroring the "1 Week" '
        'duration App Store Connect actually configures (PRD v2 §13.2, '
        '2026-09-17 note) rather than a simplified 7-day figure', () {
      final product = offering.annual!.storeProduct;
      expect(product.price, 49.99);
      expect(product.priceString, r'$49.99');
      expect(product.introductoryPrice?.periodUnit, PeriodUnit.week);
      expect(product.introductoryPrice?.periodNumberOfUnits, 1);
    });

    test(
        "the annual plan's per-month figure mirrors StoreKit's own "
        'truncation (49.99 / 12 = 4.1658... displayed as "4.16", not a '
        'rounded "4.17") — found live on-device 2026-09-17, so this fixture '
        "deliberately does not derive the figure by hand, which would "
        'round instead of truncate', () {
      final product = offering.annual!.storeProduct;
      expect(product.pricePerMonth, 4.16);
      expect(product.pricePerMonthString, r'$4.16');
    });

    test(
        'the savings badge is computed by PremiumScreen from the raw '
        'monthly/annual prices, not from the truncated per-month figure '
        'above — so previewing this fixture still exercises the real '
        'savings math instead of bypassing it', () {
      final monthly = offering.monthly!.storeProduct;
      final annual = offering.annual!.storeProduct;
      final realSavings =
          (monthly.price * 12 - annual.price) / (monthly.price * 12) * 100;
      expect(realSavings.floor(), 30);
    });
  });

  group('with debugModeForTesting simulating a release build', () {
    setUp(() {
      SubscriptionService.debugModeForTesting = false;
    });

    test('setDebugFixtureOffering is a complete no-op', () async {
      service.setDebugFixtureOffering(enabled: true);

      expect(service.debugFixtureOffering, isNull);
      expect(await service.getOfferings(), isNull);
    });

    test('debugFixtureOffering reads null even if one was set beforehand',
        () async {
      // Enable the fixture *before* flipping debugModeForTesting so the
      // static field genuinely holds a non-null value underneath — this
      // is what proves the getter itself is release-gated, not just that
      // the setter refused to run.
      SubscriptionService.debugModeForTesting = true;
      service.setDebugFixtureOffering(enabled: true);
      SubscriptionService.debugModeForTesting = false;

      expect(service.debugFixtureOffering, isNull);
      expect(await service.getOfferings(), isNull);
    });
  });
}
