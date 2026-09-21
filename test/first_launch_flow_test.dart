import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/pending_climb.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/first_launch_flow.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

import 'support/recording_analytics_sink.dart';

/// A working (not network-backed) Daily Test generator, so the Day-0 flow
/// (PRD v2 §12.3) can be driven all the way through question → result
/// rather than relying on the real ClaudeService's network call failing —
/// same fake shape as daily_test_service_test.dart's own.
class _FakeClaudeService extends ClaudeService {
  int generateCalls = 0;

  /// When set, generation waits for it: a request that is still running.
  Completer<void>? gate;

  /// Generations that fail before one succeeds.
  int failuresLeft = 0;

  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
  }) async {
    generateCalls++;
    if (gate != null) await gate!.future;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const ClaudeApiException('simulated failure');
    }
    return List.generate(
      count,
      (i) => DailyTestQuestion(
        item: PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question $i',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'answer$i',
        commonWrongAnswers: const [],
      ),
    );
  }
}

/// An in-memory double for the handful of StorageService methods this flow
/// actually touches (onboarding save, Daily Test cache/completion) — not
/// the real sqflite-backed one. Real sqlite via sqflite_common_ffi works
/// fine in a plain `test()` (see daily_test_service_test.dart) but hangs
/// indefinitely inside `testWidgets()`'s fake-async test binding, which
/// doesn't pump the real timers/isolate callbacks that ffi's I/O depends
/// on — confirmed by reproducing the hang directly before switching to
/// this approach.
class _FakeStorageService extends StorageService {
  UserProfile? savedProfile;
  DailyTestSet? _todaysSet;

  // Tracks whether the Day-0 Daily Test step ever touches the free-tier
  // practice quota (`StorageService.freeDailyPracticeLimit`) — it must not
  // (this batch's decision 7): Daily Test and "Practice this" are two
  // independent counters, and onboarding only ever exercises the former.
  bool freePracticeCountRead = false;
  bool freePracticeStartedRecorded = false;
  int freePracticeCount = 0;

  // The Daily Test sends nothing to the AI provider's feedback path, so it
  // must never ask for, or depend on, the permission to do so.
  bool aiConsentRead = false;

  @override
  Future<AiConsent?> getAiConsent() async {
    aiConsentRead = true;
    return null;
  }

  /// What was written, in order: `seed` for a bundled set, `profile`.
  final List<String> events = [];

  /// Makes writing the bundled set fail, to prove onboarding survives it.
  bool failSeed = false;

  /// What a successful `completeDailyTest` reports: whether it just earned the
  /// Welcome badge.
  bool welcomeBadge = false;

  DailyTestSet? get todaysSet => _todaysSet;
  void setTodaysSet(DailyTestSet set) => _todaysSet = set;

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    events.add('profile');
    savedProfile = profile;
  }

  @override
  Future<int> getFreePracticeCountForToday() async {
    freePracticeCountRead = true;
    return freePracticeCount;
  }

  @override
  Future<void> recordFreePracticeStarted() async {
    freePracticeStartedRecorded = true;
    freePracticeCount++;
  }

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => _todaysSet;

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) =>
      getDailyTestSetForToday();

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<DailyTestSet> saveDailyTestSet(List<DailyTestQuestion> questions,
      {String? day, DailyTestSource source = DailyTestSource.generated}) async {
    if (source == DailyTestSource.bundled) {
      if (failSeed) throw StateError('disk full');
      events.add('seed');
    }
    final set =
        DailyTestSet(day: '2026-01-01', questions: questions, source: source);
    _todaysSet = set;
    return set;
  }

  @override
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    final current = _todaysSet;
    if (current != null) {
      _todaysSet = current.copyWith(
          completedAt: completedAt ?? DateTime.now(), answers: answers);
    }
    return welcomeBadge;
  }

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';
}

void main() {
  late _FakeStorageService storageService;
  late _FakeClaudeService claudeService;

  setUp(() {
    storageService = _FakeStorageService();
    claudeService = _FakeClaudeService();
  });

  Future<void> pumpFlow(
    WidgetTester tester, {
    required void Function(
      UserProfile, {
      PendingClimb? pendingClimb,
      bool dayZeroCompleted,
    }) onComplete,
    AnalyticsService? analytics,
  }) async {
    // Tall enough that every button in the flow (including PremiumScreen's
    // trailing actions) is reachable without a per-screen scroll dance.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Welcome's ambient decorations animate on an infinite loop by design
    // (see welcome_screen.dart), which never lets `pumpAndSettle()` find a
    // quiet frame. Reporting "reduce motion" exercises this app's real
    // accessibility path instead of working around the hang some other way.
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );

    await tester.pumpWidget(
      MaterialApp(
        // DailyTestResultScreen (reached partway through this flow) reads
        // SemanticColors off the theme — the app's real theme registers
        // it, the MaterialApp default doesn't.
        theme: buildAppTheme(Brightness.light),
        home: FirstLaunchFlow(
          claudeService: claudeService,
          storageService: storageService,
          analyticsService: analytics ?? AnalyticsService(),
          onComplete: onComplete,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> completeOnboardingForm(WidgetTester tester) async {
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.text('Exam prep'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
  }

  Future<void> answerThroughDailyTest(WidgetTester tester) async {
    // Skips every question without entering an answer — this flow only
    // cares about reaching the result screen, not the answers themselves.
    // The primary button is disabled while empty (item 4's fix, see
    // PracticeStepFooter), so this taps the outlined Skip button beside it
    // instead, same as a real user would.
    for (var i = 0; i < DailyTestService.questionCount; i++) {
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pumpAndSettle();
    }
  }

  /// The result screen's one button, always in view in its fixed footer.
  Future<void> tapResultButton(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(FilledButton, label));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'completing onboarding for the first time goes to Daily Test, not '
      "straight to Home — onComplete doesn't fire yet", (tester) async {
    UserProfile? completed;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) =>
            completed = p);
    await completeOnboardingForm(tester);

    expect(completed, isNull);
    expect(find.text('Daily Test'), findsOneWidget); // the app-bar title
    expect(find.text('You should avoid ___ too much sugar.'), findsOneWidget);
    expect(storageService.savedProfile?.name, 'Ada');
  });

  testWidgets(
      'the result screen ends with its one Continue button, no paywall pitch '
      'in the flow, and tapping it completes onboarding with the right '
      'profile', (tester) async {
    UserProfile? completed;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) =>
            completed = p);
    await completeOnboardingForm(tester);
    await answerThroughDailyTest(tester);

    expect(find.text('Daily Test Results'), findsOneWidget);
    expect(find.text('Like the personalized feedback?'), findsNothing);
    expect(find.text('Start free trial'), findsNothing);
    expect(find.text('Maybe later'), findsNothing);
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(completed, isNull);

    await tapResultButton(tester, 'Continue');

    expect(completed, isNotNull);
    expect(completed!.name, 'Ada');
    expect(completed!.learningGoal, LearningGoal.examPrep);
    expect(find.byType(PremiumScreen), findsNothing);
  });

  testWidgets(
      'a Day-0 test that earns the badge ends on "Start my climb" instead, '
      'and tapping it completes onboarding', (tester) async {
    UserProfile? completed;
    PendingClimb? pending;
    storageService.welcomeBadge = true;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {
      completed = p;
      pending = pendingClimb;
    });
    await completeOnboardingForm(tester);
    await tester.enterText(find.byType(TextField).first, 'eating');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    for (var i = 1; i < DailyTestService.questionCount; i++) {
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Start my climb'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
    expect(completed, isNull);
    // Reduced motion (the flow tests' setting): no confetti to wait for.
    await tapResultButton(tester, 'Start my climb');

    expect(completed?.name, 'Ada');
    expect(pending, (day: '2026-01-01', step: 1));
  });

  testWidgets(
      'finishing through the result button reports the Day-0 test as '
      'completed, so Home offers the first-day paywall', (tester) async {
    bool? reported;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {
      reported = dayZeroCompleted;
    });
    await completeOnboardingForm(tester);
    await answerThroughDailyTest(tester);
    await tapResultButton(tester, 'Continue');

    expect(reported, isTrue);
  });

  testWidgets(
      'leaving the Day-0 test unfinished reports it as not completed: no '
      'paywall offer', (tester) async {
    bool? reported;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {
      reported = dayZeroCompleted;
    });
    await completeOnboardingForm(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(reported, isFalse);
  });

  testWidgets(
      'abandoning Daily Test itself (the "leave" confirm dialog) also '
      'completes onboarding rather than leaving the user stuck',
      (tester) async {
    UserProfile? completed;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) =>
            completed = p);
    await completeOnboardingForm(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(completed, isNotNull);
    expect(completed!.name, 'Ada');
  });

  testWidgets(
      "the Day-0 Daily Test step never touches the free-practice quota, "
      "and a user who just finished onboarding still has today's free "
      'practice session available (decision 7: the two counters are '
      'independent)', (tester) async {
    UserProfile? completed;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) =>
            completed = p);
    await completeOnboardingForm(tester);
    await answerThroughDailyTest(tester);
    await tapResultButton(tester, 'Continue');

    expect(completed, isNotNull);
    expect(storageService.aiConsentRead, isFalse);
    expect(storageService.freePracticeCountRead, isFalse);
    expect(storageService.freePracticeStartedRecorded, isFalse);
    expect(storageService.freePracticeCount, 0);
  });

  testWidgets(
      'an answered Day-0 test hands Home a pending climb (the ledger day and '
      'one step) with the profile', (tester) async {
    UserProfile? completed;
    PendingClimb? pending;
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {
      completed = p;
      pending = pendingClimb;
    });
    await completeOnboardingForm(tester);
    await tester.enterText(find.byType(TextField).first, 'wrong');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    for (var i = 1; i < DailyTestService.questionCount; i++) {
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pumpAndSettle();
    }
    await tapResultButton(tester, 'Continue');

    expect(completed, isNotNull);
    expect(pending, (day: '2026-01-01', step: 1));
  });

  testWidgets('a Day-0 test with every question skipped earns no pending climb',
      (tester) async {
    PendingClimb? pending = (day: 'sentinel', step: 9);
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {
      pending = pendingClimb;
    });
    await completeOnboardingForm(tester);
    await answerThroughDailyTest(tester);
    await tapResultButton(tester, 'Continue');

    expect(pending, isNull);
  });

  testWidgets('abandoning the Day-0 Daily Test carries no pending climb',
      (tester) async {
    PendingClimb? pending = (day: 'sentinel', step: 9);
    await pumpFlow(tester,
        onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {
      pending = pendingClimb;
    });
    await completeOnboardingForm(tester);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(pending, isNull);
  });

  group('the fixed first Daily Test', () {
    Future<void> tapThroughToDailyTest(WidgetTester tester) async {
      await completeOnboardingForm(tester);
    }

    testWidgets(
        'nothing is generated or written while Welcome and the form are open',
        (tester) async {
      await pumpFlow(tester,
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      expect(find.text('Get started'), findsOneWidget);
      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();

      expect(claudeService.generateCalls, 0);
      expect(storageService.events, isEmpty);
    });

    testWidgets(
        'the Daily Test opens on the bundled set: the five fixed questions, '
        'no generation request', (tester) async {
      await pumpFlow(tester,
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      await tapThroughToDailyTest(tester);

      expect(find.text('You should avoid ___ too much sugar.'), findsOneWidget);
      expect(find.text('Question 0'), findsNothing);
      expect(claudeService.generateCalls, 0);
      expect(storageService.todaysSet!.source, DailyTestSource.bundled);
      expect(storageService.todaysSet!.questions.map((q) => q.item.id),
          ['day0_1', 'day0_2', 'day0_3', 'day0_4', 'day0_5']);
    });

    testWidgets(
        'the set is written before the profile, so a user who exists always '
        'has today\'s set on disk', (tester) async {
      await pumpFlow(tester,
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      await tapThroughToDailyTest(tester);

      expect(storageService.events, ['seed', 'profile']);
    });

    testWidgets(
        'leaving the test and opening it again gets the same fixed set, from '
        'the store', (tester) async {
      await pumpFlow(tester,
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      await tapThroughToDailyTest(tester);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      await tester.pumpAndSettle();

      // What Home does afterwards: a fresh service asks for today's set.
      final home = DailyTestService(
        claudeService: claudeService,
        storageService: storageService,
      );
      final set = await tester.runAsync(home.getTodaysSet);

      expect(set!.source, DailyTestSource.bundled);
      expect(set.questions.first.item.id, 'day0_1');
      expect(claudeService.generateCalls, 0);
    });

    testWidgets('a day that already has a set is left alone', (tester) async {
      storageService.setTodaysSet(DailyTestSet(
        day: '2026-01-01',
        questions: [
          DailyTestQuestion(
            item: const PracticeItem(
              id: 'q0',
              type: PracticeItemType.fillInBlank,
              instruction: 'Existing question',
            ),
            topicId: 'tenseSelection',
            correctAnswer: 'x',
            commonWrongAnswers: const [],
          ),
        ],
      ));
      await pumpFlow(tester,
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      await tapThroughToDailyTest(tester);

      expect(find.text('Existing question'), findsOneWidget);
      expect(storageService.events, ['profile']);
    });

    testWidgets(
        'if writing the set fails, onboarding still finishes and the Daily '
        'Test screen generates one as before', (tester) async {
      storageService.failSeed = true;
      await pumpFlow(tester,
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      await tapThroughToDailyTest(tester);

      expect(storageService.savedProfile?.name, 'Ada');
      expect(find.text('Question 0'), findsOneWidget);
      expect(claudeService.generateCalls, 1);
    });

    testWidgets(
        'finishing the Day-0 test reports daily_test_completed with '
        'set_source = bundled and day0 = 1', (tester) async {
      final sink = RecordingAnalyticsSink();
      await pumpFlow(tester,
          analytics: AnalyticsService(sink: sink),
          onComplete: (p, {pendingClimb, dayZeroCompleted = false}) {});
      await tapThroughToDailyTest(tester);
      await tester.enterText(find.byType(TextField).first, 'eating');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      for (var i = 1; i < DailyTestService.questionCount; i++) {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
        await tester.pumpAndSettle();
      }

      final event = sink.named('daily_test_completed').single;
      expect(event.parameters!['set_source'], 'bundled');
      expect(event.parameters!['day0'], 1);
      expect(event.parameters!['correct_count'], 1);
    });
  });
}
