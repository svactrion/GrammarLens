import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';

/// Captures what DailyTestResultScreen actually writes, instead of hitting
/// the real (platform-channel-backed, throwing-in-tests) StorageService.
class _FakeStorageService extends StorageService {
  final List<ErrorEntry> insertedErrors = [];
  int markCompletedCalls = 0;

  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async {
    insertedErrors.addAll(entries);
  }

  @override
  Future<void> markDailyTestCompleted(Map<String, String> answers) async {
    markCompletedCalls++;
  }
}

DailyTestQuestion _question({
  required String id,
  required String topicId,
  required String correctAnswer,
  List<CommonWrongAnswer> commonWrongAnswers = const [],
}) =>
    DailyTestQuestion(
      item: PracticeItem(
        id: id,
        type: PracticeItemType.fillInBlank,
        instruction: 'Question $id',
      ),
      topicId: topicId,
      correctAnswer: correctAnswer,
      commonWrongAnswers: commonWrongAnswers,
    );

void main() {
  late _FakeStorageService storageService;
  late DailyTestService dailyTestService;

  setUp(() {
    storageService = _FakeStorageService();
    dailyTestService = DailyTestService(
      claudeService: ClaudeService(),
      storageService: storageService,
    );
  });

  // A mix covering all four outcomes in one set: correct, wrong-matching-a-
  // predicted-answer (has a comment), wrong-with-no-match (no comment),
  // and skipped.
  final questions = [
    _question(id: 'q1', topicId: 'articles', correctAnswer: 'the'),
    _question(
      id: 'q2',
      topicId: 'articles',
      correctAnswer: 'the',
      commonWrongAnswers: const [
        CommonWrongAnswer(answer: 'a', comment: "Close, but 'the' is specific."),
      ],
    ),
    _question(id: 'q3', topicId: 'tenseSelection', correctAnswer: 'went'),
    _question(id: 'q4', topicId: 'modalVerbs', correctAnswer: 'must'),
  ];
  final answers = {
    'q1': 'the', // correct
    'q2': 'a', // wrong, matches the predicted common wrong answer
    'q3': 'go', // wrong, matches nothing predicted
    'q4': '', // skipped
  };

  Future<void> pumpResult(WidgetTester tester, DailyTestSet set) async {
    await tester.pumpWidget(
      MaterialApp(
        // Reads SemanticColors off the theme.
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet: set,
          answers: answers,
          dailyTestService: dailyTestService,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('feeding the error profile (2026-09-05 decision, see docs/build-log.md)', () {
    testWidgets('wrong answers are written, correct and skipped are not',
        (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(storageService.insertedErrors, hasLength(2));
      expect(
        storageService.insertedErrors.map((e) => e.prompt),
        containsAll(['Question q2', 'Question q3']),
      );
    });

    testWidgets('every written entry is tagged as coming from Daily Test',
        (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(
        storageService.insertedErrors.every((e) => e.source == ErrorSource.dailyTest),
        isTrue,
      );
    });

    testWidgets(
        'a wrong answer matching a predicted common mistake keeps its real '
        'comment as the explanation', (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final q2Entry =
          storageService.insertedErrors.firstWhere((e) => e.prompt == 'Question q2');
      expect(q2Entry.explanation, "Close, but 'the' is specific.");
    });

    testWidgets(
        'a wrong answer matching nothing predicted has no explanation — '
        'never an invented one, since there is no LLM call to produce a '
        'real one', (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final q3Entry =
          storageService.insertedErrors.firstWhere((e) => e.prompt == 'Question q3');
      expect(q3Entry.explanation, isNull);
      // In particular, never the screen's own "Not quite" display fallback
      // — that's UI copy, not something to persist as if it were real
      // feedback.
      expect(q3Entry.explanation, isNot(contains('Not quite')));
    });

    testWidgets(
        "errorType falls back to the question's topic — the coarsest true "
        'classification Daily Test has, not a fabricated finer one',
        (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final q3Entry =
          storageService.insertedErrors.firstWhere((e) => e.prompt == 'Question q3');
      expect(q3Entry.topicId, 'tenseSelection');
      expect(q3Entry.errorType, 'tenseSelection');
    });

    testWidgets(
        'reopening an already-completed set (Home\'s "view result again") '
        'does not re-log the same mistakes a second time', (tester) async {
      final completedSet = DailyTestSet(
        day: '2026-01-01',
        questions: questions,
        completedAt: DateTime(2026, 1, 1),
        answers: answers,
      );

      await pumpResult(tester, completedSet);

      expect(storageService.insertedErrors, isEmpty);
      expect(storageService.markCompletedCalls, 0);
    });
  });
}
