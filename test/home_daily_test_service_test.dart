import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';

/// Home shares one `DailyTestService` across everything Daily Test, so its
/// single-flight generation holds across separate openings of the test, and the
/// next day's preparation goes through the same instance.
class _GatedClaude extends ClaudeService {
  int generationCalls = 0;
  Completer<void>? gate;

  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
  }) async {
    generationCalls++;
    if (gate != null) await gate!.future;
    return List.generate(
      count,
      (i) => DailyTestQuestion(
        item: PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question $i',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'right$i',
        commonWrongAnswers: const [],
      ),
    );
  }
}

class _Storage extends StorageService {
  final Map<String, DailyTestSet> sets = {};

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => sets[day];

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async =>
      sets[currentDayKey];

  @override
  Future<DailyTestSet> saveDailyTestSet(List<DailyTestQuestion> questions,
      {String? day, DailyTestSource source = DailyTestSource.generated}) async {
    final key = day ?? currentDayKey;
    return sets[key] =
        DailyTestSet(day: key, questions: questions, source: source);
  }

  @override
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    final key = day ?? currentDayKey;
    sets[key] = sets[key]!.copyWith(
        completedAt: completedAt ?? DateTime.now(), answers: answers);
    return false;
  }

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      (steps: 0, correct: 0, wrong: 0, skipped: 0);

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];
}

class _Subscription extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;

  @override
  void addAccessListener(AccessListener listener) {}

  @override
  void removeAccessListener(AccessListener listener) {}
}

void main() {
  late _GatedClaude claude;
  late _Storage storage;

  setUp(() {
    claude = _GatedClaude();
    storage = _Storage();
    StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
  });

  tearDown(() => StorageService.clockForTesting = DateTime.now);

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: HomeScreen(
        userName: 'Ada',
        claudeService: claude,
        storageService: storage,
        analyticsService: AnalyticsService(),
        subscriptionService: _Subscription(),
        clock: () => DateTime(2026, 9, 22, 10),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'opening the Daily Test again while its set is still being generated '
      'joins that request: one generation, not one per opening',
      (tester) async {
    claude.gate = Completer<void>();
    await pumpHome(tester);

    await tester.tap(find.text('Daily Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(claude.generationCalls, 1);

    // The loading spinner never settles, so plain pumps while the gate is shut.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Leave'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Daily Test'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(claude.generationCalls, 1, reason: 'joined, not asked again');

    claude.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Question 0'), findsOneWidget);
    expect(claude.generationCalls, 1);
  });

  testWidgets(
      'finishing the Daily Test from Home prepares tomorrow\'s set through '
      'the same service: one more request, stored for tomorrow', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Daily Test'));
    await tester.pumpAndSettle();
    expect(claude.generationCalls, 1);

    await tester.enterText(find.byType(TextField).first, 'right0');
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(i == 0 ? 'Next' : 'Skip'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Daily Test Results'), findsOneWidget);
    expect(claude.generationCalls, 2);
    expect(storage.sets.keys, containsAll(['2026-09-22', '2026-09-23']));
    expect(storage.sets['2026-09-22']!.isCompleted, isTrue);
    expect(storage.sets['2026-09-23']!.isCompleted, isFalse);
    expect(storage.sets['2026-09-23']!.source, DailyTestSource.generated);
  });

  testWidgets(
      'viewing the finished result again asks for nothing more: tomorrow '
      'already has its set', (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Daily Test'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    expect(claude.generationCalls, 2);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.textContaining('0/5 correct'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('0/5 correct'));
    await tester.pumpAndSettle();
    expect(find.text('Daily Test Results'), findsOneWidget);

    expect(claude.generationCalls, 2);
  });
}
