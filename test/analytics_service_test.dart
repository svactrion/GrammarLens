import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/services/analytics_service.dart';

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

  test('sessionCompleted does not throw without a Firebase project',
      () async {
    await analyticsService.sessionCompleted(
      topicId: 'articles',
      questionCount: 5,
    );
  });
}
