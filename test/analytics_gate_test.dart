import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/services/analytics_service.dart';

import 'support/recording_analytics_sink.dart';

/// Roadmap P11: a release build sends analytics; a debug or profile build
/// does not, unless built with `ANALYTICS_DEBUG_EVENTS=true`.
void main() {
  group('AnalyticsGate.isEnabled', () {
    test('a release build sends, with or without the opt-in', () {
      expect(AnalyticsGate.isEnabled(releaseMode: true, optIn: false), isTrue);
      expect(AnalyticsGate.isEnabled(releaseMode: true, optIn: true), isTrue);
    });

    test('a debug or profile build does not send by default', () {
      expect(
          AnalyticsGate.isEnabled(releaseMode: false, optIn: false), isFalse);
    });

    test('a debug or profile build sends with the opt-in', () {
      expect(AnalyticsGate.isEnabled(releaseMode: false, optIn: true), isTrue);
    });

    test('this test run (debug, no define) is gated off', () {
      expect(AnalyticsGate.debugEventsOptIn, isFalse);
      expect(AnalyticsGate.enabled, isFalse);
      expect(AnalyticsGate.enabled, AnalyticsGate.isEnabled());
    });
  });

  group('GatedAnalyticsSink', () {
    Future<RecordingAnalyticsSink> run({required bool enabled}) async {
      final inner = RecordingAnalyticsSink();
      final service =
          AnalyticsService(sink: GatedAnalyticsSink(inner, enabled: enabled));
      await service.onboardingCompleted();
      await service.modeSelected(AnalyticsService.modeDailyTest,
          themeId: 'green_slope');
      await service.setFirstStepDayOfMonth(4);
      return inner;
    }

    test('release: events and user properties are sent', () async {
      final inner = await run(
          enabled: AnalyticsGate.isEnabled(releaseMode: true, optIn: false));
      expect(inner.events.map((e) => e.name),
          ['onboarding_completed', 'mode_selected']);
      expect(inner.events[1].parameters,
          {'mode': 'daily_test', 'theme_id': 'green_slope'});
      expect(inner.userProperties, {'first_step_dom': '4'});
    });

    test('debug or profile by default: nothing is sent', () async {
      final inner = await run(
          enabled: AnalyticsGate.isEnabled(releaseMode: false, optIn: false));
      expect(inner.events, isEmpty);
      expect(inner.userPropertyWrites, isEmpty);
    });

    test('debug or profile with the opt-in: events are sent', () async {
      final inner = await run(
          enabled: AnalyticsGate.isEnabled(releaseMode: false, optIn: true));
      expect(inner.events.map((e) => e.name),
          ['onboarding_completed', 'mode_selected']);
      expect(inner.userProperties, {'first_step_dom': '4'});
    });
  });

  test('main() hands the same gate to Firebase\'s collection switch', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source,
        contains('setAnalyticsCollectionEnabled(AnalyticsGate.enabled)'));
  });

  test('the default AnalyticsService sink is the gated Firebase sink', () {
    final source =
        File('lib/services/analytics_service.dart').readAsStringSync();
    expect(
        source,
        contains('AnalyticsSink sink = const GatedAnalyticsSink('
            'FirebaseAnalyticsSink(),\n'
            '        enabled: AnalyticsGate.enabled)'));
  });
}
