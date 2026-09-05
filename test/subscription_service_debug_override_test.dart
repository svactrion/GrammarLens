import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/services/subscription_service.dart';

/// Exercises the real [SubscriptionService] (not a fake) since this is
/// specifically about its debug-override plumbing — [addAccessListener]
/// registering a listener and [hasFullAccess] reading `_configured`/
/// `_debugAccessOverride` are both local, platform-channel-free operations
/// (see those methods' doc comments), so this is safe without a real
/// RevenueCat project connected.
void main() {
  final service = SubscriptionService();

  tearDown(() async {
    // Restore both the debug-mode simulation and the override itself so
    // no state leaks into the next test in this file.
    SubscriptionService.debugModeForTesting = kDebugMode;
    await service.setDebugAccessOverride(null);
  });

  test('no override set: hasFullAccess is unaffected (falls through to the '
      'real, unconfigured-project default of false)', () async {
    expect(service.debugAccessOverride, isNull);
    expect(await service.hasFullAccess, isFalse);
  });

  test('setting the override to true forces hasFullAccess to true',
      () async {
    await service.setDebugAccessOverride(true);
    expect(service.debugAccessOverride, isTrue);
    expect(await service.hasFullAccess, isTrue);
  });

  test('setting the override to false forces hasFullAccess to false',
      () async {
    await service.setDebugAccessOverride(false);
    expect(service.debugAccessOverride, isFalse);
    expect(await service.hasFullAccess, isFalse);
  });

  test('clearing the override (null) returns to the real status', () async {
    await service.setDebugAccessOverride(true);
    expect(await service.hasFullAccess, isTrue);

    await service.setDebugAccessOverride(null);
    expect(service.debugAccessOverride, isNull);
    expect(await service.hasFullAccess, isFalse);
  });

  test(
    'setting the override notifies every listener already registered via '
    'addAccessListener, the same as a real entitlement change would',
    () async {
      final notified = <bool>[];
      void listener(bool value) => notified.add(value);
      service.addAccessListener(listener);
      addTearDown(() => service.removeAccessListener(listener));

      await service.setDebugAccessOverride(true);
      await service.setDebugAccessOverride(false);

      expect(notified, [true, false]);
    },
  );

  group('with debugModeForTesting simulating a release build', () {
    setUp(() {
      SubscriptionService.debugModeForTesting = false;
    });

    test('setDebugAccessOverride is a complete no-op', () async {
      final notified = <bool>[];
      service.addAccessListener((value) => notified.add(value));

      await service.setDebugAccessOverride(true);

      expect(service.debugAccessOverride, isNull);
      expect(await service.hasFullAccess, isFalse);
      expect(notified, isEmpty);
    });

    test('debugAccessOverride reads null even if one was set beforehand',
        () async {
      // Set the override *before* flipping debugModeForTesting so the
      // static field genuinely holds a non-null value underneath — this
      // is what proves the getter itself is release-gated, not just that
      // the setter refused to run.
      SubscriptionService.debugModeForTesting = true;
      await service.setDebugAccessOverride(true);
      SubscriptionService.debugModeForTesting = false;

      expect(service.debugAccessOverride, isNull);
      expect(await service.hasFullAccess, isFalse);
    });
  });
}
