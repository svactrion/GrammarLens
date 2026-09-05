import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
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

/// A working (not network-backed) Daily Test generator, so the Day-0 flow
/// (PRD v2 §12.3) can be driven all the way through question → result
/// rather than relying on the real ClaudeService's network call failing —
/// same fake shape as daily_test_service_test.dart's own.
class _FakeClaudeService extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
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

  @override
  Future<void> saveUserProfile(UserProfile profile) async {
    savedProfile = profile;
  }

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => _todaysSet;

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<DailyTestSet> saveDailyTestSet(
    List<DailyTestQuestion> questions,
  ) async {
    final set = DailyTestSet(day: '2026-01-01', questions: questions);
    _todaysSet = set;
    return set;
  }

  @override
  Future<void> markDailyTestCompleted(Map<String, String> answers) async {
    final current = _todaysSet;
    if (current != null) {
      _todaysSet =
          current.copyWith(completedAt: DateTime.now(), answers: answers);
    }
  }
}

void main() {
  late _FakeStorageService storageService;

  setUp(() {
    storageService = _FakeStorageService();
  });

  Future<void> pumpFlow(
    WidgetTester tester, {
    required ValueChanged<UserProfile> onComplete,
  }) async {
    // Tall enough that every button in the flow (including PremiumScreen's
    // trailing actions) is reachable without a per-screen scroll dance.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        // DailyTestResultScreen (reached partway through this flow) reads
        // SemanticColors off the theme — the app's real theme registers
        // it, the MaterialApp default doesn't.
        theme: buildAppTheme(Brightness.light),
        home: FirstLaunchFlow(
          claudeService: _FakeClaudeService(),
          storageService: storageService,
          analyticsService: AnalyticsService(),
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
    // PracticeStepFooter), so this taps the quiet Skip text action instead,
    // same as a real user would.
    for (var i = 0; i < DailyTestService.questionCount; i++) {
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'completing onboarding for the first time goes to Daily Test, not '
      "straight to Home — onComplete doesn't fire yet", (tester) async {
    UserProfile? completed;
    await pumpFlow(tester, onComplete: (p) => completed = p);
    await completeOnboardingForm(tester);

    expect(completed, isNull);
    expect(find.text('Daily Test'), findsOneWidget); // the app-bar title
    expect(find.text('Question 0'), findsOneWidget);
    expect(storageService.savedProfile?.name, 'Ada');
  });

  testWidgets(
      "the result screen's paywall CTA is shown instead of a plain finish, "
      'and tapping "Maybe later" there completes onboarding with the right '
      'profile', (tester) async {
    UserProfile? completed;
    await pumpFlow(tester, onComplete: (p) => completed = p);
    await completeOnboardingForm(tester);
    await answerThroughDailyTest(tester);

    expect(find.text('Daily Test Results'), findsOneWidget);
    final ctaHeadline = find.text('Like the personalized feedback?');
    await tester.scrollUntilVisible(ctaHeadline, 300);
    expect(ctaHeadline, findsOneWidget);
    expect(completed, isNull);

    await scrollAndTap(tester, find.text('Maybe later'));

    expect(completed, isNotNull);
    expect(completed!.name, 'Ada');
    expect(completed!.learningGoal, LearningGoal.examPrep);
  });

  testWidgets(
      'tapping "Start free trial" on the result CTA opens the real '
      'PremiumScreen, and its own "Maybe later" also completes onboarding',
      (tester) async {
    UserProfile? completed;
    await pumpFlow(tester, onComplete: (p) => completed = p);
    await completeOnboardingForm(tester);
    await answerThroughDailyTest(tester);

    await scrollAndTap(tester, find.text('Start free trial'));

    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(completed, isNull);

    await scrollAndTap(tester, find.text('Maybe later'));

    expect(completed, isNotNull);
    expect(find.byType(PremiumScreen), findsNothing);
  });

  testWidgets(
      'abandoning Daily Test itself (the "leave" confirm dialog) also '
      'completes onboarding rather than leaving the user stuck', (tester) async {
    UserProfile? completed;
    await pumpFlow(tester, onComplete: (p) => completed = p);
    await completeOnboardingForm(tester);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();

    expect(completed, isNotNull);
    expect(completed!.name, 'Ada');
  });
}
