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
// app opens on Welcome on a fresh install). Applied at every launch, so one
// install walks through the states (W5 captures):
//   SEED_DONE=true            today's Daily Test is completed (4 of 5);
//   SEED_TICKET_USED=true     today's free practice ticket is used (with
//                             SEED_DONE: the rest scene, V24);
//   SEED_RESET_ASK=true       reminder settings back to "never asked"
//                             (N01 opens on its own again);
//   SEED_REMINDER_IN=<n>      reminders on (accepted, all four) at the
//                             time n minutes from now, for a real reminder.
import 'package:flutter/material.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
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
const _done = bool.fromEnvironment('SEED_DONE');
const _ticketUsed = bool.fromEnvironment('SEED_TICKET_USED');
const _resetAsk = bool.fromEnvironment('SEED_RESET_ASK');
const _reminderIn = int.fromEnvironment('SEED_REMINDER_IN', defaultValue: -1);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientation();
  final storage = StorageService();
  if (!_skip) {
    await seedScreenshotData(storage, now: DateTime.now(), premium: _premium);
  }
  if (_done) {
    final today = await storage.getDailyTestSetForToday();
    if (today != null && !today.isCompleted) {
      await storage.completeDailyTest({
        for (final (i, q) in today.questions.indexed)
          q.item.id: i == 0 ? 'x' : q.correctAnswer,
      }, const []);
    }
  }
  if (_ticketUsed && await storage.getFreePracticeCountForToday() == 0) {
    await storage.recordFreePracticeStarted();
  }
  if (_resetAsk) await storage.setReminderSettings(const ReminderSettings());
  if (_reminderIn >= 0) {
    final at = DateTime.now().add(const Duration(minutes: _reminderIn));
    await storage.setReminderSettings(const ReminderSettings()
        .turnedOn(minutes: at.hour * 60 + at.minute));
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
