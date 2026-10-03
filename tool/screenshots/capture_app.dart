// App Store screenshots (1.1.0 release, P4, P5): the real app, run in the
// simulator by `flutter drive` with `capture_driver.dart` steering it.
// Not part of the app: nothing in lib/ imports this file.
//
// Before the app starts, on a fresh install, it seeds local data that
// looks like a few weeks of real use by a fictional learner ("Sam"):
//   - this month's Daily Tests done up to one step before Halfway Hut, so
//     today's test, taken live by the driver, lands the avatar on it;
//   - today's Daily Test stored but not taken (the bundled first-day
//     questions, so no network is needed);
//   - mistakes in two more topics for Review (today's test adds a third,
//     the one the weak spot detail opens), typed as Daily Test mistakes
//     are (the topic id), so their titles are the topics' names;
//   - the one-time records that would otherwise open a paywall or a zoom.
// Firebase and RevenueCat are not started, and every analytics event is
// dropped: a capture run sends nothing to the production project.
//
// With CAPTURE_WELCOME=true nothing is seeded: the app opens on Welcome.
//
// Run through tool/screenshots/capture.sh, not on its own.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/utils/app_orientation.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';

/// Drops every event.
class _NoAnalytics implements AnalyticsSink {
  const _NoAnalytics();
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Today's answers as the driver types them: the first wrong (so the result
/// shows a corrected answer and its explanation), the rest right.
List<String> get _todayAnswers => [
      for (final (i, q) in kDayZeroQuestions.indexed)
        i == 0 ? 'to eat' : q.correctAnswer,
    ];

Future<void> _seed(StorageService storage) async {
  if (await storage.getUserProfile() != null) return;
  await storage.saveUserProfile(UserProfile(
      name: 'Sam',
      learningGoal: LearningGoal.examPrep,
      avatar: Avatar.values[6])); // Crab, as in the 1.0.0 set.

  final now = DateTime.now();
  final days = DateTime(now.year, now.month + 1, 0).day;
  final hut = ClimbSavePoints.all.firstWhere((p) => p.object == 'cabin');
  // Steps before today's test: one short of Halfway Hut.
  final before = hut.reachedOn(days) - 1;
  final dayNumbers = [
    for (var d = 1; d <= days; d++)
      if (d != now.day) d
  ].take(before).toList();

  // Every seeded day all right (10 points), unless that would let today's
  // 9 points cross a medal threshold (the result frame must show the
  // explanations, not a celebration): then the last seeded days drop a
  // question until it does not.
  final correct = List.filled(dayNumbers.length, 5);
  int score() => correct.fold(
      0, (s, c) => s + MonthlyMedalRules.score(correct: c, wrong: 5 - c));
  final todayPoints = MonthlyMedalRules.score(correct: 4, wrong: 1);
  final tiers = [
    for (final t in MedalTier.values)
      MonthlyMedalRules.threshold(now.year, now.month, t)
  ];
  bool crosses() => tiers.any((t) => score() < t && score() + todayPoints >= t);
  for (var i = correct.length - 1; crosses() && i >= 0; i--) {
    while (crosses() && correct[i] > 2) {
      correct[i]--;
    }
  }

  for (final (i, d) in dayNumbers.indexed) {
    final day = DateTime(now.year, now.month, d);
    await storage.saveDailyTestSet(kDayZeroQuestions,
        day: _key(day), source: DailyTestSource.shared);
    await storage.completeDailyTest({
      for (final (j, q) in kDayZeroQuestions.indexed)
        q.item.id: j < correct[i] ? q.correctAnswer : 'x',
    }, const [],
        day: _key(day), completedAt: DateTime(now.year, now.month, d, 8, 40));
  }
  await storage.saveDailyTestSet(kDayZeroQuestions,
      day: _key(now), source: DailyTestSource.shared);

  final seen = now.subtract(const Duration(days: 1));
  await storage.insertErrors([
    ErrorEntry(
        topicId: 'modalVerbs',
        errorType: 'modalVerbs',
        timestamp: seen.subtract(const Duration(days: 2)),
        prompt: 'She can speaks three languages.\nFind the mistake and '
            'rewrite the full corrected sentence.',
        userAnswer: 'She can speaks three languages',
        correctedAnswer: 'She can speak three languages',
        explanation: "After 'can', the verb stays in its plain form, even "
            "with 'she'.",
        rule: 'Plain verb after a modal',
        source: ErrorSource.dailyTest),
    ErrorEntry(
        topicId: 'tenseSelection',
        errorType: 'tenseSelection',
        timestamp: seen.subtract(const Duration(days: 4)),
        prompt: 'I have seen that film last week.\nFind the mistake and '
            'rewrite the full corrected sentence.',
        userAnswer: 'I have seen that film last week',
        correctedAnswer: 'I saw that film last week',
        explanation: "'Last week' is a finished time, so the past simple: "
            "'I saw'.",
        rule: 'Past simple with a finished time',
        source: ErrorSource.dailyTest),
  ]);

  await storage.claimOneTimeFlag(StorageService.day0PaywallFlag);
  await storage.claimOneTimeFlag(StorageService.firstRunZoomFlag);
}

/// `--dart-define=CAPTURE_WELCOME=true`: no seeding, so the app opens on
/// Welcome as a fresh install does (frame 09).
const _welcomeOnly = bool.fromEnvironment('CAPTURE_WELCOME');

Future<void> main() async {
  enableFlutterDriverExtension(handler: (request) async {
    if (request == 'answers') return jsonEncode(_todayAnswers);
    // Frame 06 shows the first question with its right answer typed.
    if (request == 'first_correct') {
      return kDayZeroQuestions.first.correctAnswer;
    }
    if (request == 'mode') return _welcomeOnly ? 'welcome' : 'full';
    // The driver switches between flutter_driver's text-entry emulation and
    // the real iOS keyboard (frame 06): a field opens its text input
    // connection, to whichever is active, only when it gains focus.
    if (request == 'unfocus') {
      FocusManager.instance.primaryFocus?.unfocus();
      return 'ok';
    }
    if (request == 'release_look') {
      // From here on the screens show what a release build shows (no
      // Developer section on Profile). The screens are rebuilt, not
      // reloaded, so Profile keeps the sample shelf already on it. The
      // debug panel is not reachable after this.
      DebugTools.enabledForTesting = false;
      await WidgetsBinding.instance.reassembleApplication();
      return 'ok';
    }
    return '';
  });
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientation();
  final storage = StorageService();
  if (!_welcomeOnly) await _seed(storage);
  runApp(LaunchGate(
    initialize: () async {},
    app: (_) => GrammarLensApp(
      // Today at 9:41, the status bar's time: Home greets "Good morning"
      // whatever the hour of the run. The date is today's, so the data
      // seeded for today is the data Home shows.
      clock: () {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, 9, 41);
      },
      storageService: storage,
      analyticsService: AnalyticsService(sink: const _NoAnalytics()),
    ),
  ));
}
