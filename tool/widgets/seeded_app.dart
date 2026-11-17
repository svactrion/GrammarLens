// Widgets and reminders (TASK-widgets W1–W5): the real app with a seeded
// learner, for checking links, widgets and reminders in the simulator by
// hand (`flutter run -d <simulator> --target tool/widgets/seeded_app.dart`).
// Not part of the app: nothing in lib/ imports tool/
// (`test/tool_import_guard_test.dart`).
//
// On an install without a profile it seeds the App Store screenshot learner
// (`tool/screenshots/seed.dart`: "Sam", the Fox, today's test not taken).
// Firebase and RevenueCat are not started and every analytics event is
// dropped, so a run sends nothing anywhere. The bridge is the real one.
//
// Defines: SEED_PREMIUM=true (Premium), SEED_SKIP=true (no seeding, the
// app opens on Welcome on a fresh install).
import 'package:flutter/material.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/utils/app_orientation.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

import '../screenshots/seed.dart';

class _NoAnalytics implements AnalyticsSink {
  const _NoAnalytics();
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

const _premium = bool.fromEnvironment('SEED_PREMIUM');
const _skip = bool.fromEnvironment('SEED_SKIP');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientation();
  final storage = StorageService();
  if (!_skip) {
    await seedScreenshotData(storage, now: DateTime.now(), premium: _premium);
  }
  SubscriptionService().setDebugFixtureOffering(enabled: true);
  runApp(LaunchGate(
    initialize: () async {},
    app: (_) => GrammarLensApp(
      storageService: storage,
      analyticsService: AnalyticsService(sink: const _NoAnalytics()),
    ),
  ));
}
