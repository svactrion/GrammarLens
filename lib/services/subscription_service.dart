import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

/// Outcome of a purchase attempt, for a future paywall screen to react to
/// without needing to know RevenueCat's own exception/error-code shape.
enum PurchaseOutcome { success, failure, cancelled }

/// Called with the current [SubscriptionService.hasFullAccess]-equivalent
/// value whenever it changes — see [SubscriptionService.addAccessListener].
typedef AccessListener = void Function(bool hasFullAccess);

/// Wraps RevenueCat subscription/entitlement checking (PRD v2 §12.6's
/// trial/paid mechanism) — code scaffold only as of this commit, no real
/// App Store Connect product or RevenueCat project connected yet (see
/// docs/roadmap.md).
///
/// **Identifiers to create for real later:** entitlement id `premium`,
/// product id `grammarlens_premium_monthly` (see the constants below).
///
/// Every method here is a best-effort no-op/safe-default until a real
/// project is connected — the exact same intent as Firebase's
/// `Firebase.initializeApp()` try/catch in main.dart, **but a plain
/// try/catch alone doesn't deliver it here**: calling any `Purchases.*`
/// method before `Purchases.configure()` succeeds throws a *native* Swift
/// `fatalError` (`PurchasesHybridCommon/CommonFunctionality.swift: Fatal
/// error: Purchases has not been configured`), which crashes the app
/// outright and is not something a Dart `catch` can intercept — confirmed
/// by actually hitting it on the iOS simulator while building
/// PaywallScreen. [_configured] is what actually prevents that: every
/// method below checks it and returns its safe default *before* ever
/// touching the SDK, rather than trusting try/catch to contain a crash it
/// structurally cannot.
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

  /// Set only after `Purchases.configure` actually succeeds — static
  /// because RevenueCat's SDK config is itself process-global, and every
  /// other method here (each typically called on its own fresh
  /// `SubscriptionService()` instance, e.g. from a screen) needs to see
  /// the outcome of whichever instance's [initialize] ran at startup.
  static bool _configured = false;

  /// Configures the RevenueCat SDK. A no-op if no key was provided at
  /// build time, and safe even if `Purchases.configure` itself throws (no
  /// RevenueCat project connected yet) — every other method on this class
  /// checks [_configured] and degrades to its safe default
  /// (`false`/`null`/[PurchaseOutcome.failure]) unless this actually
  /// succeeded, rather than attempting the SDK call and hoping to catch
  /// the failure (see the class doc comment on why that doesn't work here).
  Future<void> initialize() async {
    if (_apiKey.isEmpty) return;
    try {
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      _configured = true;
    } catch (_) {
      // No RevenueCat project connected yet, or a transient failure — see
      // the class doc comment.
    }
  }

  /// Whether the current user has the [entitlementIdPremium] entitlement
  /// active right now.
  Future<bool> get hasFullAccess async {
    if (!_configured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.active.containsKey(entitlementIdPremium);
    } catch (_) {
      // A transient failure post-configuration — fail closed rather than
      // grant access nobody paid for.
      return false;
    }
  }

  /// Purchases [package]. Never throws — cancellation and failure (which
  /// includes "not configured yet") both come back as a [PurchaseOutcome]
  /// so a future paywall screen can show the right message either way.
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    if (!_configured) return PurchaseOutcome.failure;
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
    if (!_configured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.active.containsKey(entitlementIdPremium);
    } catch (_) {
      return false;
    }
  }

  /// The current RevenueCat offering — the paywall's live price/trial
  /// terms — or null if none is configured yet (no project connected) or
  /// the call otherwise fails. Same safe-default pattern as every other
  /// method here: a paywall screen calling this should treat null as "show
  /// an unavailable state," never crash.
  Future<Offering?> getOfferings() async {
    if (!_configured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (_) {
      return null;
    }
  }

  /// Maps each registered [AccessListener] to the RevenueCat-shaped
  /// listener it's bridged through — needed because
  /// [Purchases.removeCustomerInfoUpdateListener] matches by the exact
  /// function reference that was added, and that reference isn't
  /// [AccessListener] itself (see [addAccessListener]).
  static final Map<AccessListener, CustomerInfoUpdateListener> _bridges = {};

  /// Subscribes [listener] to live entitlement changes — a trial starting,
  /// a subscription expiring, a restore completing — so a screen like Home
  /// can gate Topic Practice without re-checking [hasFullAccess] on a timer
  /// or requiring an app restart to notice a change. Fires once immediately
  /// with the last known value if RevenueCat has already reported one, then
  /// again on every subsequent change — mirrors
  /// [Purchases.addCustomerInfoUpdateListener]'s own behavior, which this
  /// wraps.
  ///
  /// Safe to call even when RevenueCat isn't configured: unlike every other
  /// method here, registering a listener is a local, SDK-side-effect-free
  /// operation (RevenueCat's own implementation just adds to an in-memory
  /// Dart `Set`, no platform channel involved) — the listener is registered
  /// either way, it will simply never fire until/unless a real project gets
  /// connected.
  void addAccessListener(AccessListener listener) {
    void bridge(CustomerInfo info) {
      listener(info.entitlements.active.containsKey(entitlementIdPremium));
    }

    _bridges[listener] = bridge;
    Purchases.addCustomerInfoUpdateListener(bridge);
  }

  /// Unsubscribes a listener previously passed to [addAccessListener] —
  /// call from a screen's `dispose()` to avoid leaking it past the
  /// widget's lifetime.
  void removeAccessListener(AccessListener listener) {
    final bridge = _bridges.remove(listener);
    if (bridge != null) Purchases.removeCustomerInfoUpdateListener(bridge);
  }
}
