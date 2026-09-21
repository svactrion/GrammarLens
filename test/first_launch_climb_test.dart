import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/confetti_burst.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import 'support/recording_analytics_sink.dart';

/// The end-to-end regression for the Day-0 climb: the bug lived exactly at
/// the seam between `FirstLaunchFlow` and the Home that `app.dart` swaps in
/// afterwards, so these tests run the real app instead of a look-alike
/// harness. Only the network and the database are replaced.

class _FakeClaudeService extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
  }) async =>
      List.generate(
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

/// A tiny in-memory ledger: the first answered Daily Test earns one step.
class _Day0Storage extends StorageService {
  UserProfile? profile;
  DailyTestSet? todaysSet;
  int steps = 0;
  int completionCalls = 0;

  /// When set, `completeDailyTest` waits for it: the "save is slow" case.
  Completer<void>? saveGate;

  @override
  Future<UserProfile?> getUserProfile() async => profile;

  @override
  Future<void> saveUserProfile(UserProfile value) async => profile = value;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => todaysSet;

  @override
  Future<DailyTestSet> saveDailyTestSet(List<DailyTestQuestion> questions,
      {String? day, DailyTestSource source = DailyTestSource.generated}) async {
    todaysSet =
        DailyTestSet(day: '2026-01-01', questions: questions, source: source);
    return todaysSet!;
  }

  @override
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    completionCalls++;
    if (saveGate != null) await saveGate!.future;
    final set = todaysSet!;
    todaysSet = DailyTestSet(
      day: set.day,
      questions: set.questions,
      answers: answers,
      completedAt: completedAt ?? DateTime.now(),
      source: set.source,
    );
    final answered = answers.values.any((a) => a.trim().isNotEmpty);
    if (answered) steps++;
    // The first step ever is what earns the Welcome badge.
    return answered && steps == 1;
  }

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: steps, correct: 0, wrong: 0, skipped: 0);

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';
}

void main() {
  late _Day0Storage storage;

  setUp(() => storage = _Day0Storage());

  void setReduceMotion(WidgetTester tester, bool value) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: value);
  }

  /// Welcome's ambient loops never settle, so everything up to the result
  /// screen runs with motion reduced; each test then chooses the motion
  /// setting Home is built under.
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    setReduceMotion(tester, true);

    await tester.pumpWidget(GrammarLensApp(
      storageService: storage,
      analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
      claudeService: _FakeClaudeService(),
      clock: () => DateTime(2026, 1, 1, 9),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> completeOnboarding(WidgetTester tester) async {
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.tap(find.text('Exam prep'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();
  }

  /// Answers the first question and skips the other four, or skips them all.
  Future<void> takeDailyTest(WidgetTester tester,
      {required bool answerFirst}) async {
    for (var i = 0; i < 5; i++) {
      if (i == 0 && answerFirst) {
        await tester.enterText(find.byType(TextField).first, 'wrong');
        await tester.pump();
        await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      } else {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      }
      await tester.pumpAndSettle();
    }
  }

  final burst = find.byType(ConfettiBurst);
  final resultsTitle = find.text('Daily Test Results');

  final mountain = find.byType(MonthlyMountain, skipOffstage: false);

  double pawnTop(WidgetTester tester) => tester
      .widget<Positioned>(find
          .descendant(
              of: mountain,
              matching: find.byWidgetPredicate(
                  (w) => w is Positioned && w.child is AvatarTile,
                  skipOffstage: false))
          .last)
      .top!;

  /// Pumps [frames] frames of 25 ms, recording every distinct step count the
  /// mountain was given and every distinct pawn height it was drawn at.
  /// pumpAndSettle would hide an animation that had already been consumed.
  Future<({List<int> steps, List<double> tops})> observeHome(
    WidgetTester tester, {
    int frames = 100,
  }) async {
    final steps = <int>[];
    final tops = <double>[];
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 25));
      if (mountain.evaluate().isEmpty) continue;
      final days = tester.widget<MonthlyMountain>(mountain).completedDays;
      if (steps.isEmpty || steps.last != days) steps.add(days);
      final top = pawnTop(tester);
      if (tops.isEmpty || (tops.last - top).abs() > 0.01) tops.add(top);
    }
    return (steps: steps, tops: tops);
  }

  group('Day-0 climb', () {
    testWidgets(
        'Start my climb: the confetti plays on the results for its whole '
        'run, then Home mounts before the step and the pawn climbs to it',
        (tester) async {
      await pumpApp(tester);
      await completeOnboarding(tester);
      await takeDailyTest(tester, answerFirst: true);
      expect(storage.steps, 1);

      setReduceMotion(tester, false);
      await tester.pump();
      await tester.tap(find.text('Start my climb'));
      await tester.pump();
      // Nothing overlaps: the burst is on the results, Home is not built yet.
      expect(burst, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1000));
      expect(burst, findsOneWidget);
      expect(resultsTitle, findsOneWidget);
      expect(mountain, findsNothing);

      await tester.pump(const Duration(milliseconds: 900));
      final seen = await observeHome(tester);
      await tester.pumpAndSettle();
      final finalTop = pawnTop(tester);

      expect(burst, findsNothing);
      expect(resultsTitle, findsNothing);
      // The first thing Home ever drew was the position before the step...
      expect(seen.steps, [0, 1]);
      // ...and the pawn travelled between the two positions (start, at least
      // one point in between, end), rather than appearing at the end.
      expect(seen.tops.first, greaterThan(finalTop));
      expect(seen.tops.length, greaterThan(2));
      expect(seen.tops.first, greaterThan(seen.tops[1]));
      expect(seen.tops.last, closeTo(finalTop, 0.01));
      expect(find.text('1 / 31 steps'), findsOneWidget);
    });

    testWidgets(
        'reduce motion: no confetti, Start my climb goes straight to Home, '
        'which still mounts before the step and then jumps with no '
        'in-between frames', (tester) async {
      await pumpApp(tester);
      await completeOnboarding(tester);
      await takeDailyTest(tester, answerFirst: true);

      await tester.tap(find.text('Start my climb'));
      await tester.pump();
      expect(burst, findsNothing);
      final seen = await observeHome(tester);
      await tester.pumpAndSettle();

      expect(seen.steps, [0, 1]);
      expect(seen.tops, hasLength(2));
      expect(seen.tops.first, greaterThan(seen.tops.last));
    });

    testWidgets(
        'all questions skipped (no step, no badge): Continue goes straight to '
        'Home, nothing is pending and the pawn never moves', (tester) async {
      await pumpApp(tester);
      await completeOnboarding(tester);
      await takeDailyTest(tester, answerFirst: false);
      expect(storage.steps, 0);
      expect(find.text('Start my climb'), findsNothing);

      setReduceMotion(tester, false);
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pump();
      expect(burst, findsNothing);
      final seen = await observeHome(tester, frames: 60);

      expect(seen.steps, [0]);
      expect(seen.tops, hasLength(1));
      expect(find.text('0 / 31 steps'), findsOneWidget);
    });

    testWidgets(
        'a slow save keeps the way out disabled until it lands, then Start '
        'my climb plays the confetti and Home shows the saved step',
        (tester) async {
      storage.saveGate = Completer<void>();
      await pumpApp(tester);
      await completeOnboarding(tester);
      for (var i = 0; i < 5; i++) {
        if (i == 0) {
          await tester.enterText(find.byType(TextField).first, 'wrong');
          await tester.pump();
          await tester.tap(find.widgetWithText(FilledButton, 'Next'));
        } else {
          await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
        }
        // The last tap opens the result screen, whose saving progress bar
        // never settles, so plain pumps from here on.
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(resultsTitle, findsOneWidget);
      expect(storage.completionCalls, 1);

      // While saving the one button reads "Saving your results…" and is off.
      final saving = find.widgetWithText(FilledButton, 'Saving your results…');
      expect(tester.widget<FilledButton>(saving).onPressed, isNull);
      await tester.tap(saving, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 200));
      expect(resultsTitle, findsOneWidget);
      expect(mountain, findsNothing);
      expect(burst, findsNothing);

      storage.saveGate!.complete();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      final climb = find.widgetWithText(FilledButton, 'Start my climb');
      expect(tester.widget<FilledButton>(climb).onPressed, isNotNull);

      setReduceMotion(tester, false);
      await tester.pump();
      await tester.tap(climb);
      await tester.pump();
      expect(burst, findsOneWidget);
      expect(mountain, findsNothing);
      final seen = await observeHome(tester, frames: 200);
      await tester.pumpAndSettle();

      expect(seen.steps, [0, 1]);
      expect(find.text('1 / 31 steps'), findsOneWidget);
    });

    testWidgets(
        'leaving the very first Daily Test unanswered: Home opens with '
        'nothing to animate', (tester) async {
      await pumpApp(tester);
      await completeOnboarding(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave'));
      setReduceMotion(tester, false);
      final seen = await observeHome(tester, frames: 60);

      expect(storage.completionCalls, 0);
      expect(seen.steps, [0]);
      expect(seen.tops, hasLength(1));
    });
  });
}
