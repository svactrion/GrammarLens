import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

import 'support/recording_analytics_sink.dart';

/// Counts every resume-driven read the two lifecycle observers make, so a
/// test can prove one resume triggers each job exactly once. Any storage call
/// not overridden here throws (no platform channel in a widget test), which
/// the app already tolerates.
class _CountingStorage extends StorageService {
  int finalizeCalls = 0;
  int dailyReads = 0;
  int climbReads = 0;
  DailyTestSet? todaysDailyTest;

  @override
  Future<UserProfile?> getUserProfile() async =>
      const UserProfile(name: 'Ada', learningGoal: LearningGoal.general);

  @override
  Future<List<MonthlyMedalResult>> finalizePastMedalMonths() async {
    finalizeCalls++;
    return const [];
  }

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async {
    dailyReads++;
    return todaysDailyTest;
  }

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
      int year, int month) async {
    climbReads++;
    return (steps: 0, correct: 0, wrong: 0, skipped: 0);
  }
}

DailyTestSet _completedYesterday() => DailyTestSet(
      day: '2026-01-01',
      questions: [
        DailyTestQuestion(
          item: const PracticeItem(
            id: 'q0',
            type: PracticeItemType.fillInBlank,
            instruction: 'Question 0',
          ),
          topicId: 'tenseSelection',
          correctAnswer: 'right',
          commonWrongAnswers: const [],
        ),
      ],
      completedAt: DateTime(2026, 1, 1, 22),
      answers: const {'q0': 'right'},
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
  });

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets(
      'an overnight background: resume refreshes the Daily Test day and the '
      'greeting, and each resume-time job runs exactly once', (tester) async {
    var now = DateTime(2026, 1, 1, 22, 30);
    final storage = _CountingStorage()..todaysDailyTest = _completedYesterday();

    await tester.pumpWidget(GrammarLensApp(
      storageService: storage,
      analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
      clock: () => now,
    ));
    await tester.pumpAndSettle();

    // Evening, yesterday's test done.
    expect(find.text('Good evening, Ada'), findsOneWidget);
    expect(find.textContaining('New test tomorrow'), findsOneWidget);
    final launch = (
      finalize: storage.finalizeCalls,
      daily: storage.dailyReads,
      climb: storage.climbReads,
    );
    // (Launch itself finalizes from the app and from Profile's mount; both
    // are idempotent, so this test only measures what a resume adds.)

    // Backgrounded overnight: nothing runs while paused.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    now = DateTime(2026, 1, 2, 8);
    storage.todaysDailyTest = null; // the new local day has no cached test
    expect(storage.finalizeCalls, launch.finalize);
    expect(storage.dailyReads, launch.daily);

    // The platform's real order back to the foreground.
    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();

    // New day is shown, not yesterday's state.
    expect(find.text('Good morning, Ada'), findsOneWidget);
    expect(find.text('Good evening, Ada'), findsNothing);
    expect(find.textContaining('New test tomorrow'), findsNothing);
    expect(find.textContaining("Today's 5-question warm-up"), findsOneWidget);

    // One resume, one of each job — no doubled work between the app-level
    // observer (finalization) and Home's (day/greeting/climb).
    expect(storage.finalizeCalls, launch.finalize + 1);
    expect(storage.dailyReads, launch.daily + 1);
    expect(storage.climbReads, launch.climb + 1);
  });
}
