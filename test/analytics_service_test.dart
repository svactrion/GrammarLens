import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/analytics_service.dart';

import 'support/recording_analytics_sink.dart';

/// No Firebase project is connected yet (see main.dart's comment on
/// `_initializeFirebase`), and even once one is, firebase_analytics has no
/// platform-channel implementation in this plugin-less test environment
/// (same situation as sqflite — see widget_test.dart's note). Every public
/// method must complete without throwing regardless, since analytics is a
/// nice-to-have signal that must never be able to crash the feature it's
/// instrumenting.
void main() {
  final analyticsService = AnalyticsService();

  test('onboardingCompleted does not throw without a Firebase project',
      () async {
    await analyticsService.onboardingCompleted();
  });

  test('modeSelected does not throw without a Firebase project', () async {
    await analyticsService.modeSelected(AnalyticsService.modeTopic);
  });

  test('practiceCompleted does not throw without a Firebase project', () async {
    await analyticsService.practiceCompleted(
      topicId: 'articles',
      questionCount: 5,
    );
  });

  test('freePracticeUsed does not throw without a Firebase project', () async {
    await analyticsService.freePracticeUsed();
  });

  test('freePracticeQuotaExhausted does not throw without a Firebase project',
      () async {
    await analyticsService.freePracticeQuotaExhausted();
  });

  test('paywallViewed does not throw without a Firebase project', () async {
    await analyticsService.paywallViewed(AnalyticsService.paywallSourceHome);
  });

  test('paywallDismissed does not throw without a Firebase project', () async {
    await analyticsService.paywallDismissed(
      source: AnalyticsService.paywallSourceWeakSpotQuota,
      method: AnalyticsService.paywallDismissMaybeLater,
    );
  });

  test('purchaseStarted does not throw without a Firebase project', () async {
    await analyticsService.purchaseStarted(AnalyticsService.planAnnual);
  });

  test('purchaseResult does not throw without a Firebase project', () async {
    await analyticsService.purchaseResult(
      plan: AnalyticsService.planMonthly,
      outcome: 'error',
    );
  });

  group('event contract (docs/analytics-plan.md)', () {
    late RecordingAnalyticsSink sink;
    late AnalyticsService service;

    setUp(() {
      sink = RecordingAnalyticsSink();
      service = AnalyticsService(sink: sink);
    });

    /// Asserts exactly one event was logged, with exactly this name and
    /// exactly these parameter keys and values — no extra keys can slip in
    /// unnoticed, which is what keeps personal data out of events.
    void expectOnly(String name, Map<String, Object>? parameters) {
      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, name);
      expect(sink.events.single.parameters, parameters);
    }

    test('onboarding_completed carries no parameters', () async {
      await service.onboardingCompleted();
      expectOnly('onboarding_completed', null);
    });

    test('mode_selected carries only mode', () async {
      await service.modeSelected(AnalyticsService.modeDailyTest);
      expectOnly('mode_selected', {'mode': 'daily_test'});
    });

    test('practice_completed carries only topic_id and question_count',
        () async {
      await service.practiceCompleted(topicId: 'articles', questionCount: 5);
      expectOnly('practice_completed', {
        'topic_id': 'articles',
        'question_count': 5,
      });
    });

    test('free_practice_used carries no parameters', () async {
      await service.freePracticeUsed();
      expectOnly('free_practice_used', null);
    });

    test('free_practice_quota_exhausted carries no parameters', () async {
      await service.freePracticeQuotaExhausted();
      expectOnly('free_practice_quota_exhausted', null);
    });

    test('paywall_viewed carries only source', () async {
      await service.paywallViewed(AnalyticsService.paywallSourceOnboarding);
      expectOnly('paywall_viewed', {'source': 'onboarding'});
    });

    test('paywall_dismissed carries only source and method', () async {
      await service.paywallDismissed(
        source: AnalyticsService.paywallSourceHome,
        method: AnalyticsService.paywallDismissSystemBack,
      );
      expectOnly('paywall_dismissed', {
        'source': 'home',
        'method': 'system_back',
      });
    });

    test('purchase_started carries only plan', () async {
      await service.purchaseStarted(AnalyticsService.planAnnual);
      expectOnly('purchase_started', {'plan': 'annual'});
    });

    test('purchase_result carries only plan and outcome', () async {
      await service.purchaseResult(
        plan: AnalyticsService.planMonthly,
        outcome: 'cancelled',
      );
      expectOnly('purchase_result', {
        'plan': 'monthly',
        'outcome': 'cancelled',
      });
    });

    test('daily_test_completed carries only counts and two 0/1 flags',
        () async {
      await service.dailyTestCompleted(
        correctCount: 3,
        wrongCount: 1,
        skippedCount: 1,
        stepEarned: true,
        day0: false,
      );
      expectOnly('daily_test_completed', {
        'correct_count': 3,
        'wrong_count': 1,
        'skipped_count': 1,
        'step_earned': 1,
        'day0': 0,
      });
    });

    test('welcome_badge_earned carries only rule and calendar numbers',
        () async {
      await service.welcomeBadgeEarned(
        ruleVersion: 1,
        dayOfMonth: 20,
        daysInMonth: 30,
      );
      expectOnly('welcome_badge_earned', {
        'rule_version': 1,
        'day_of_month': 20,
        'days_in_month': 30,
      });
    });

    test('medal_month_finalized carries only tier and numbers', () async {
      await service.medalMonthFinalized(
        tier: MedalTier.silver,
        scorePct: 61,
        activeDays: 20,
        daysInMonth: 31,
        ruleVersion: 1,
        monthsAgo: 1,
      );
      expectOnly('medal_month_finalized', {
        'tier': 'silver',
        'score_pct': 61,
        'active_days': 20,
        'days_in_month': 31,
        'rule_version': 1,
        'months_ago': 1,
      });
    });

    test('a month below Bronze reports the tier "none"', () async {
      await service.medalMonthFinalized(
        tier: null,
        scorePct: 4,
        activeDays: 1,
        daysInMonth: 28,
        ruleVersion: 1,
        monthsAgo: 3,
      );
      expect(sink.events.single.parameters!['tier'], 'none');
    });

    test('first_step_dom is a user property, stored as a string', () async {
      await service.setFirstStepDayOfMonth(24);
      expect(sink.events, isEmpty);
      expect(sink.userProperties, {'first_step_dom': '24'});
    });

    test('profile_medals_viewed carries only counts and a 0/1 flag', () async {
      await service.profileMedalsViewed(
        finalizedMonths: 3,
        medalsEarned: 2,
        welcomeEarned: true,
      );
      expectOnly('profile_medals_viewed', {
        'finalized_months': 3,
        'medals_earned': 2,
        'welcome_earned': 1,
      });
    });

    test('text_size_changed carries only size and previous', () async {
      await service.textSizeChanged(
        size: AppTextSize.large,
        previous: AppTextSize.medium,
      );
      expectOnly('text_size_changed', {'size': 'large', 'previous': 'medium'});
    });

    test('text_size is a user property carrying the size name', () async {
      await service.setTextSizeProperty(AppTextSize.small);
      expect(sink.events, isEmpty);
      expect(sink.userProperties, {'text_size': 'small'});
    });

    group('profile_medals_viewed session limit', () {
      late DateTime now;
      late RecordingAnalyticsSink sessionSink;
      late AnalyticsService session;

      Future<void> view() => session.profileMedalsViewed(
            finalizedMonths: 0,
            medalsEarned: 0,
            welcomeEarned: false,
          );

      setUp(() {
        now = DateTime(2026, 10, 1, 9);
        sessionSink = RecordingAnalyticsSink();
        session = AnalyticsService(sink: sessionSink, clock: () => now);
      });

      test('a second view in the same session is dropped', () async {
        await view();
        await view();
        expect(sessionSink.named('profile_medals_viewed'), hasLength(1));
      });

      test('a short trip to the background stays the same session', () async {
        await view();
        session.appPaused();
        now = now.add(const Duration(minutes: 29));
        session.appResumed();
        await view();
        expect(sessionSink.named('profile_medals_viewed'), hasLength(1));
      });

      test('30 minutes or more in the background starts a new session',
          () async {
        await view();
        session.appPaused();
        now = now.add(AnalyticsService.sessionTimeout);
        session.appResumed();
        await view();
        expect(sessionSink.named('profile_medals_viewed'), hasLength(2));
      });
    });

    test('a failing sink never throws out of the wrapper', () async {
      final failing = AnalyticsService(sink: _ThrowingSink());
      await failing.onboardingCompleted();
      await failing.modeSelected(AnalyticsService.modeTopic);
    });
  });
}

class _ThrowingSink implements AnalyticsSink {
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) =>
      throw StateError('sink unavailable');

  @override
  Future<void> setUserProperty(String name, String? value) =>
      throw StateError('sink unavailable');
}
