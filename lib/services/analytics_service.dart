import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;

import '../models/app_text_size.dart';
import '../models/learning_goal.dart';
import '../models/medal_tier.dart';

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

/// Whether this build sends analytics at all (roadmap P11): a release build
/// always does; a debug or profile build does not, unless it was built with
/// `--dart-define=ANALYTICS_DEBUG_EVENTS=true` for a DebugView check. Those
/// builds write to the production Firebase project, and GA4's
/// developer-traffic filter only removes devices flagged in debug mode, so
/// without this their events would count as real ones.
///
/// The one place the rule lives: [GatedAnalyticsSink] drops this app's own
/// events and user properties by it, and `main()` hands it to Firebase's
/// collection switch so Firebase's automatic events (`first_open`,
/// `session_start`, ...) stop too. Crashlytics is not touched.
abstract final class AnalyticsGate {
  /// The explicit opt-in for a debug or profile build.
  static const bool debugEventsOptIn =
      bool.fromEnvironment('ANALYTICS_DEBUG_EVENTS');

  /// This build's answer: a compile-time constant (true in every release
  /// build, whatever the defines).
  static const bool enabled = kReleaseMode || debugEventsOptIn;

  /// The rule itself, for tests: [enabled] is `isEnabled()` with this
  /// build's constants.
  static bool isEnabled({
    bool releaseMode = kReleaseMode,
    bool optIn = debugEventsOptIn,
  }) =>
      releaseMode || optIn;
}

/// Passes events and user properties to [inner] only when [enabled]
/// ([AnalyticsGate]); otherwise drops them silently.
class GatedAnalyticsSink implements AnalyticsSink {
  const GatedAnalyticsSink(this.inner, {required this.enabled});

  final AnalyticsSink inner;
  final bool enabled;

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    if (enabled) await inner.logEvent(name, parameters);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    if (enabled) await inner.setUserProperty(name, value);
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
/// What the user decided about sending Topic Practice answers to the AI
/// provider. The names are the event's `outcome` values.
enum AiConsentOutcome { granted, declined, revoked }

/// Where the decision was made.
enum AiConsentSource {
  practiceLaunch('practice_launch'),
  dataSettings('data_settings');

  final String wireName;
  const AiConsentSource(this.wireName);
}

class AnalyticsService {
  AnalyticsService({
    AnalyticsSink sink = const GatedAnalyticsSink(FirebaseAnalyticsSink(),
        enabled: AnalyticsGate.enabled),
    DateTime Function() clock = DateTime.now,
  })  : _sink = sink,
        _clock = clock;

  final AnalyticsSink _sink;
  final DateTime Function() _clock;

  /// Firebase's default session timeout: after this long in the background,
  /// the next foreground stretch is a new session. Used only to decide when
  /// once-per-session events (see [profileMedalsViewed]) may fire again.
  static const sessionTimeout = Duration(minutes: 30);

  bool _profileViewedThisSession = false;
  DateTime? _backgroundedAt;

  /// The app went to the background.
  void appPaused() {
    _backgroundedAt = _clock();
  }

  /// The app came back to the foreground. If it was away for at least
  /// [sessionTimeout], once-per-session events may fire again.
  void appResumed() {
    final away = _backgroundedAt;
    _backgroundedAt = null;
    if (away != null && _clock().difference(away) >= sessionTimeout) {
      _profileViewedThisSession = false;
    }
  }

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

  /// [themeId] (Batch 6, M19): the month's theme, sent only with
  /// [modeDailyTest], the Daily Test's start. The theme follows a global
  /// calendar, so the other events derive it from their date.
  Future<void> modeSelected(String mode, {String? themeId}) {
    return _logEvent('mode_selected', {
      'mode': mode,
      if (themeId != null && mode == modeDailyTest) 'theme_id': themeId,
    });
  }

  /// The month transition card was shown (Batch 6, M19): the new month's
  /// [themeId], the [variant] (`summary` / `fresh`), last month's
  /// [medalTier] (null: `none`, also on the fresh-start card) and whether
  /// the near-miss line was shown.
  Future<void> monthCardShown({
    required String themeId,
    required String variant,
    required MedalTier? medalTier,
    required bool nearMissShown,
  }) {
    return _logEvent('month_card_shown', {
      'theme_id': themeId,
      'variant': variant,
      'medal_tier': medalTier?.name ?? 'none',
      'near_miss_shown': nearMissShown ? 1 : 0,
    });
  }

  /// The month card was closed by [method] (`button` / `drag` / `barrier`)
  /// after [openMs] milliseconds on screen in the foreground.
  Future<void> monthCardDismissed({
    required String themeId,
    required String variant,
    required String method,
    required int openMs,
  }) {
    return _logEvent('month_card_dismissed', {
      'theme_id': themeId,
      'variant': variant,
      'method': method,
      'open_ms': openMs,
    });
  }

  /// A zoom from the whole mountain to the daily framing ended (M16, M19):
  /// [outcome] `completed` / `skipped` / `reduce_motion` /
  /// `daily_test_opened`; [trigger] `month_change` / `first_run`.
  Future<void> monthZoomEnded({
    required String themeId,
    required String outcome,
    required String trigger,
  }) {
    return _logEvent('month_zoom_ended', {
      'theme_id': themeId,
      'outcome': outcome,
      'trigger': trigger,
    });
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

  /// The practice results screen showed its Premium prompt to a free user
  /// whose daily free practice is used up. Once per results screen. Since
  /// that is nearly every free session's end, this is an exposure count, not
  /// an interest signal: read it only as the denominator of
  /// [practiceResultUpsellTapped].
  Future<void> practiceResultUpsellViewed() {
    return _logEvent('practice_result_upsell_viewed');
  }

  /// The user tapped "See Premium" on the practice results screen.
  Future<void> practiceResultUpsellTapped() {
    return _logEvent('practice_result_upsell_tapped');
  }

  /// `PremiumScreen`'s `source` identifiers (`paywall_viewed`/
  /// `paywall_dismissed`) — one per distinct push call site, confirmed by
  /// reading each one rather than guessed: Home's own Premium row and
  /// locked-Topic-Practice-card taps (both funnel through the same push),
  /// the weak-spot detail screen's quota-exhausted redirect,
  /// `launchPracticeSet`'s own backstop version of that same check, the
  /// practice results screen's "See Premium" prompt, and the paywall Home
  /// opens by itself once, after the first climb.
  static const String paywallSourceHome = 'home';
  static const String paywallSourceWeakSpotQuota = 'weak_spot_quota';

  /// Review's daily practice card once today's free practice is used
  /// (1.2.0 Batch 5): a different entry point from [paywallSourceWeakSpotQuota]
  /// (a weak spot's own screen), kept apart in the data.
  static const String paywallSourceReviewQuota = 'review_quota';
  static const String paywallSourcePracticeLaunch = 'practice_launch';
  static const String paywallSourcePracticeResult = 'practice_result';

  /// Shown by Home on its own, once, after the Day-0 climb animation (not a
  /// user tap, so it sends no `mode_selected`).
  static const String paywallSourceDay0AfterClimb = 'day0_after_climb';

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
  /// `'cancelled'`, `'error'` (`PurchaseOutcome.failure`'s own event
  /// name here, matching the wording used everywhere else this outcome is
  /// shown to the user rather than the enum's internal Dart name), or
  /// `'pending'` (1.2.0: Ask to Buy or a deferred payment, waiting for
  /// approval; an approval that comes later is not logged again).
  Future<void> purchaseResult({
    required String plan,
    required String outcome,
  }) {
    return _logEvent('purchase_result', {'plan': plan, 'outcome': outcome});
  }

  /// A Daily Test completion was durably saved — the action that earns (or,
  /// when everything was skipped, does not earn) the day's climb step.
  /// Fired once per genuine new completion, never for a retried failed save
  /// that eventually succeeds twice, or for a reopened finished result.
  /// Counts only; no question or answer text. Booleans go out as `0`/`1`
  /// because Firebase parameters are strings or numbers. [setSource] is
  /// `DailyTestSource.name`: `shared` for the date's shared set, `fallback`
  /// when it could not be read, `bundled` for the fixed first-day set and
  /// `generated` for a set cached by 1.0.0's per-device generation — so
  /// completion, and how often the fallback is shown, can be read per
  /// source. [setDate] is the set's own day (`YYYY-MM-DD`, the local day key
  /// it was loaded for): everyone gets the same shared set on a date, so
  /// completions per `set_date` show whether one set was too hard or had a
  /// broken key (docs/1.1.0-shared-daily-test.md §9).
  Future<void> dailyTestCompleted({
    required int correctCount,
    required int wrongCount,
    required int skippedCount,
    required bool stepEarned,
    required bool day0,
    required String setSource,
    required String setDate,
  }) {
    return _logEvent('daily_test_completed', {
      'correct_count': correctCount,
      'wrong_count': wrongCount,
      'skipped_count': skippedCount,
      'step_earned': stepEarned ? 1 : 0,
      'day0': day0 ? 1 : 0,
      'set_source': setSource,
      'set_date': setDate,
    });
  }

  /// The Welcome badge was earned live (docs/prd-gamification.md §M6.5) —
  /// never for the v18 migration's backfill, which cannot happen on a
  /// production device. [dayOfMonth]/[daysInMonth] describe the ledger day
  /// of the first step, which is what lets the Welcome assumption be read
  /// against mid-month starters.
  Future<void> welcomeBadgeEarned({
    required int ruleVersion,
    required int dayOfMonth,
    required int daysInMonth,
  }) {
    return _logEvent('welcome_badge_earned', {
      'rule_version': ruleVersion,
      'day_of_month': dayOfMonth,
      'days_in_month': daysInMonth,
    });
  }

  /// The avatar reached a save point (Batch 5, N12, N21): the completion
  /// whose step reaches it, sent once per save point per month after a
  /// durable save, never for a month already finalized (N24). [savePoint]
  /// is the name in snake case (`first_camp` … `summit`); [step] the
  /// month's step it was reached on.
  Future<void> savePointReached({
    required String themeId,
    required String savePoint,
    required int step,
    required int daysInMonth,
  }) {
    return _logEvent('save_point_reached', {
      'theme_id': themeId,
      'save_point': savePoint,
      'step': step,
      'days_in_month': daysInMonth,
    });
  }

  /// A tier became certain this month (Batch 5, N12, N21): the completion
  /// whose points cross its threshold, once per tier per month, never for a
  /// month already finalized (N24). [tier] reuses E4's parameter and
  /// meaning (a tier earned). [dayOfMonth] is the set's day; [activeDays]
  /// the month's steps so far.
  Future<void> medalTierReached({
    required String themeId,
    required MedalTier tier,
    required int dayOfMonth,
    required int daysInMonth,
    required int activeDays,
    required int ruleVersion,
  }) {
    return _logEvent('medal_tier_reached', {
      'theme_id': themeId,
      'tier': tier.name,
      'day_of_month': dayOfMonth,
      'days_in_month': daysInMonth,
      'active_days': activeDays,
      'rule_version': ruleVersion,
    });
  }

  /// A past month's medal result was frozen (docs/analytics-plan.md E4).
  /// [tier] is `none` below Bronze. [scorePct] is the score as a whole
  /// percentage of the month's maximum; [monthsAgo] is how many months
  /// before finalization the finalized month was, so late finalizations
  /// (a user who did not open the app for a while) stay distinguishable.
  Future<void> medalMonthFinalized({
    required MedalTier? tier,
    required int scorePct,
    required int activeDays,
    required int daysInMonth,
    required int ruleVersion,
    required int monthsAgo,
  }) {
    return _logEvent('medal_month_finalized', {
      'tier': tier?.name ?? 'none',
      'score_pct': scorePct,
      'active_days': activeDays,
      'days_in_month': daysInMonth,
      'rule_version': ruleVersion,
      'months_ago': monthsAgo,
    });
  }

  /// The Profile medal collection was loaded while its tab was showing
  /// (docs/analytics-plan.md E5). Sent **at most once per session**: Profile
  /// reloads on every tab re-entry, and an unguarded event would count tab
  /// bouncing rather than interest. Later calls in the same session are
  /// dropped here, not by the caller.
  Future<void> profileMedalsViewed({
    required int finalizedMonths,
    required int medalsEarned,
    required bool welcomeEarned,
  }) async {
    if (_profileViewedThisSession) return;
    _profileViewedThisSession = true;
    await _logEvent('profile_medals_viewed', {
      'finalized_months': finalizedMonths,
      'medals_earned': medalsEarned,
      'welcome_earned': welcomeEarned ? 1 : 0,
    });
  }

  /// The user picked a different text size (docs/analytics-plan.md E6).
  /// Only real changes: the caller must not report re-selecting the current
  /// size.
  Future<void> textSizeChanged({
    required AppTextSize size,
    required AppTextSize previous,
  }) {
    return _logEvent('text_size_changed', {
      'size': size.name,
      'previous': previous.name,
    });
  }

  /// The user's answer to the AI-provider permission (docs/analytics-plan.md
  /// E7): granted, declined (Not now or back), or revoked (switched off in
  /// Profile → Data). Outcome, where it happened and the wording version only;
  /// nothing the user wrote.
  Future<void> aiConsentResult({
    required AiConsentOutcome outcome,
    required AiConsentSource source,
    required int consentVersion,
  }) {
    return _logEvent('ai_consent_result', {
      'outcome': outcome.name,
      'source': source.wireName,
      'consent_version': consentVersion,
    });
  }

  /// User property `text_size` (small/medium/large): the size in effect now.
  /// Set when the stored preference loads at startup and on every change, so
  /// retention can be segmented by it.
  Future<void> setTextSizeProperty(AppTextSize size) {
    return _setUserProperty('text_size', size.name);
  }

  /// User property `first_step_dom`: the day of the month (1–31) of the
  /// user's very first step. Call it exactly once, together with
  /// [welcomeBadgeEarned] — user properties only apply to events logged
  /// after they are set and cannot be reconstructed later.
  Future<void> setFirstStepDayOfMonth(int dayOfMonth) {
    return _setUserProperty('first_step_dom', dayOfMonth.toString());
  }

  /// User property `learning_goal`: `exam_prep` / `work` / `general` /
  /// `skipped`, the onboarding answer (1.2.0). Set once, as onboarding
  /// completes and before `onboarding_completed`, so that event carries it.
  /// Not set for installs that finished onboarding earlier: their stored
  /// `general` cannot be told apart from a choice.
  Future<void> setLearningGoalProperty(LearningGoal? goal) {
    return _setUserProperty('learning_goal', learningGoalValue(goal));
  }

  Future<void> _logEvent(String name, [Map<String, Object>? parameters]) async {
    try {
      await _sink.logEvent(name, parameters);
    } catch (_) {
      // No Firebase project connected yet, or a transient failure — never
      // let instrumentation take down the feature it's measuring.
    }
  }

  Future<void> _setUserProperty(String name, String? value) async {
    try {
      await _sink.setUserProperty(name, value);
    } catch (_) {
      // Same best-effort rule as [_logEvent].
    }
  }
}
