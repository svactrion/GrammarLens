import 'package:firebase_analytics/firebase_analytics.dart';

/// Where [AnalyticsService] hands finished events. `FirebaseAnalytics.instance`
/// is a static, so without this seam a test could only prove that a call does
/// not throw — never which event name or parameter keys it produced. Feature
/// code never touches a sink: it calls the typed [AnalyticsService] methods,
/// which are the only place an event name or parameter map is built.
abstract class AnalyticsSink {
  Future<void> logEvent(String name, Map<String, Object>? parameters);
  Future<void> setUserProperty(String name, String? value);
}

/// The production sink: straight through to Firebase Analytics.
class FirebaseAnalyticsSink implements AnalyticsSink {
  const FirebaseAnalyticsSink();

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) {
    return FirebaseAnalytics.instance
        .logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> setUserProperty(String name, String? value) {
    return FirebaseAnalytics.instance.setUserProperty(name: name, value: value);
  }
}

/// Minimal local event logging (PRD v2 §9's "measurement approach for
/// launch") plus crash reporting, both anonymous and device-based — no
/// account/login involved, so this doesn't touch the guest-first identity
/// model (PRD v2 §5). Contract and privacy rules: docs/analytics-plan.md —
/// counts, tiers, rule versions and closed-vocabulary strings only; never
/// question text, answers or any profile field.
///
/// Every method here is a best-effort no-op when Firebase is unavailable —
/// analytics is a nice-to-have signal, not something that should ever be able
/// to crash or block the app it's instrumenting.
class AnalyticsService {
  AnalyticsService({AnalyticsSink sink = const FirebaseAnalyticsSink()})
      : _sink = sink;

  final AnalyticsSink _sink;

  /// Practice mode identifiers for the `mode_selected` event — matches
  /// Home's three tappable entries (PRD v2 §4): Daily Test, Topic Practice,
  /// and the Premium banner (formerly "Early Access", retired — PRD v2
  /// §13.1), since knowing what people tap there is exactly the kind of
  /// pre-launch interest signal analytics exists for. (Streak Mode and
  /// Voice Practice identifiers were removed along with their Home tiles
  /// — see docs/roadmap.md.)
  static const String modeDailyTest = 'daily_test';
  static const String modeTopic = 'topic';
  static const String modePremium = 'premium';

  Future<void> onboardingCompleted() {
    return _logEvent('onboarding_completed');
  }

  Future<void> modeSelected(String mode) {
    return _logEvent('mode_selected', {'mode': mode});
  }

  /// A Topic Practice session reached its results screen. Named
  /// `practice_completed` (formerly `session_completed`) so it can't be
  /// confused with [dailyTestCompleted]'s Daily Test event; renamed before
  /// launch, so no historical data carries the old name.
  Future<void> practiceCompleted({
    required String topicId,
    required int questionCount,
  }) {
    return _logEvent('practice_completed', {
      'topic_id': topicId,
      'question_count': questionCount,
    });
  }

  /// A free (non-`hasFullAccess`) user actually started their one daily
  /// "Practice this" session — the conversion funnel's first half. Without
  /// this and [freePracticeQuotaExhausted], there's no way to tell after
  /// launch whether `StorageService.freeDailyPracticeLimit` is the right
  /// number.
  Future<void> freePracticeUsed() {
    return _logEvent('free_practice_used');
  }

  /// A free user hit `StorageService.freeDailyPracticeLimit` and was routed
  /// to `PremiumScreen` because of it — logged from both the spot where a
  /// user taps an already-locked "Practice this" and `launchPracticeSet`'s
  /// own backstop check, since either one is a real "quota → paywall" event
  /// worth counting the same way.
  Future<void> freePracticeQuotaExhausted() {
    return _logEvent('free_practice_quota_exhausted');
  }

  /// `PremiumScreen`'s `source` identifiers (`paywall_viewed`/
  /// `paywall_dismissed`) — one per distinct push call site, confirmed by
  /// reading each one rather than guessed: Home's own Premium row and
  /// locked-Topic-Practice-card taps (both funnel through the same push),
  /// the weak-spot detail screen's quota-exhausted redirect,
  /// `launchPracticeSet`'s own backstop version of that same check, and
  /// the Day-0 onboarding pitch.
  static const String paywallSourceHome = 'home';
  static const String paywallSourceWeakSpotQuota = 'weak_spot_quota';
  static const String paywallSourcePracticeLaunch = 'practice_launch';
  static const String paywallSourceOnboarding = 'onboarding';

  /// `PremiumScreen`'s dismissal methods (`paywall_dismissed`) — the X in
  /// the band, the footer's "Maybe later", or a system back gesture/
  /// hardware back button (the one path not triggered by this app's own
  /// code, so `PremiumScreen` has to observe it via `PopScope` rather than
  /// tag it at a specific `onPressed`). Never logged for the post-success
  /// "Continue" button — that's a completed purchase, not an abandonment,
  /// and already covered by [purchaseResult].
  static const String paywallDismissCloseButton = 'close_button';
  static const String paywallDismissMaybeLater = 'maybe_later';
  static const String paywallDismissSystemBack = 'system_back';

  /// `PremiumScreen`'s plan identifiers (`purchase_started`/
  /// `purchase_result`) — matches its own two `Package`s (PRD v2 §13.3).
  static const String planMonthly = 'monthly';
  static const String planAnnual = 'annual';

  /// A `PremiumScreen` visit — fired once per screen mount, tagged by
  /// [source] (see the `paywallSource*` constants above) so post-launch
  /// data can say which entry points actually convert, not just that the
  /// paywall was shown somewhere.
  Future<void> paywallViewed(String source) {
    return _logEvent('paywall_viewed', {'source': source});
  }

  /// The paywall was left without buying — [source] is the same entry
  /// point [paywallViewed] recorded for this visit, [method] one of the
  /// `paywallDismiss*` constants above.
  Future<void> paywallDismissed({
    required String source,
    required String method,
  }) {
    return _logEvent(
      'paywall_dismissed',
      {'source': source, 'method': method},
    );
  }

  /// A purchase attempt actually started — [plan] is [planMonthly] or
  /// [planAnnual].
  Future<void> purchaseStarted(String plan) {
    return _logEvent('purchase_started', {'plan': plan});
  }

  /// How a purchase attempt ended — [outcome] is `'success'`,
  /// `'cancelled'`, or `'error'` (`PurchaseOutcome.failure`'s own event
  /// name here, matching the wording used everywhere else this outcome is
  /// shown to the user rather than the enum's internal Dart name).
  Future<void> purchaseResult({
    required String plan,
    required String outcome,
  }) {
    return _logEvent('purchase_result', {'plan': plan, 'outcome': outcome});
  }

  Future<void> _logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _sink.logEvent(name, parameters);
    } catch (_) {
      // No Firebase project connected yet, or a transient failure — never
      // let instrumentation take down the feature it's measuring.
    }
  }
}
