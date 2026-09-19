import 'package:flutter_test/flutter_test.dart';

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
