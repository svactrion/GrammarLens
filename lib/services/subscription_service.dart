import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

/// Outcome of a purchase attempt, for a future paywall screen to react to
/// without needing to know RevenueCat's own exception/error-code shape.
enum PurchaseOutcome { success, failure, cancelled }

/// Wraps RevenueCat subscription/entitlement checking (PRD v2 §12.6's
/// trial/paid mechanism) — code scaffold only as of this commit, no real
/// App Store Connect product or RevenueCat project connected yet (see
/// docs/roadmap.md).
///
/// **Identifiers to create for real later:** entitlement id `premium`,
/// product id `grammarlens_premium_monthly` (see the constants below).
///
/// Every method here is a best-effort no-op/safe-default until a real
/// project is connected — the exact same pattern main.dart already uses
/// for Firebase (see [initialize]'s comment): nothing here should ever be
/// able to crash or block the app it's instrumenting.
class SubscriptionService {
  /// The entitlement identifier configured in RevenueCat for full access —
  /// true for both an active trial and a paid subscriber, since RevenueCat
  /// doesn't distinguish the two for entitlement purposes, which is what
  /// [hasFullAccess] callers actually want ("does this person get full
  /// access right now").
  static const String entitlementIdPremium = 'premium';

  /// The App Store Connect / RevenueCat product identifier for the
  /// (not yet created) premium monthly subscription.
  static const String productIdPremiumMonthly = 'grammarlens_premium_monthly';

  /// RevenueCat's public SDK key, read at build/run time via
  /// `--dart-define=REVENUECAT_API_KEY=...` — same mechanism ClaudeService
  /// uses for the Anthropic key, but for a different reason: RevenueCat's
  /// SDK key is meant to be public/embeddable (unlike a server API key),
  /// so this isn't a secrecy measure, just keeping it in one configurable
  /// place instead of hardcoded in source.
  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');

  /// Configures the RevenueCat SDK. A no-op if no key was provided at
  /// build time, and safe even if `Purchases.configure` itself throws (no
  /// RevenueCat project connected yet) — every other method on this class
  /// degrades to its safe default (`false`/[PurchaseOutcome.failure]) in
  /// that case rather than crashing, exactly like Firebase's
  /// `Firebase.initializeApp()` try/catch in main.dart.
  Future<void> initialize() async {
    if (_apiKey.isEmpty) return;
    try {
      await Purchases.configure(PurchasesConfiguration(_apiKey));
    } catch (_) {
      // No RevenueCat project connected yet, or a transient failure — see
      // the class doc comment.
    }
  }

  /// Whether the current user has the [entitlementIdPremium] entitlement
  /// active right now.
  Future<bool> get hasFullAccess async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementIdPremium);
    } catch (_) {
      // Not configured, or a transient failure — fail closed rather than
      // grant access nobody paid for.
      return false;
    }
  }

  /// Purchases [package]. Never throws — cancellation and failure (which
  /// includes "not configured yet") both come back as a [PurchaseOutcome]
  /// so a future paywall screen can show the right message either way.
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return PurchaseOutcome.success;
    } on PlatformException catch (e) {
      final cancelled = PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.purchaseCancelledError;
      return cancelled ? PurchaseOutcome.cancelled : PurchaseOutcome.failure;
    } catch (_) {
      return PurchaseOutcome.failure;
    }
  }

  /// Restores previously-purchased entitlements (required by App Store
  /// guidelines for any paywall) and reports whether that leaves the user
  /// with full access.
  Future<bool> restorePurchases() async {
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementIdPremium);
    } catch (_) {
      return false;
    }
  }
}
