import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/daily_test_completion.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/services/daily_test_grading.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';

/// SPEC §1.5: "Check" grades each Daily Test answer on the device with the
/// existing matching rules, and the points shown equal the completion's.
void main() {
  final questions = kDayZeroQuestions;

  test('every check equals the completion\'s own result for that answer', () {
    for (final q in questions) {
      for (final answer in [
        q.correctAnswer,
        q.correctAnswer.toUpperCase(),
        '  ${q.correctAnswer}  ',
        'something else entirely',
        ...q.acceptedAnswers,
        for (final w in q.commonWrongAnswers) w.answer,
      ]) {
        final check = QuestionCheck.of(q, answer);
        final completion = DailyTestCompletion(
          set: DailyTestSet(day: '2026-11-17', questions: [q]),
          answers: {q.item.id: answer},
          completedAt: DateTime(2026, 11, 17),
        );
        expect(check.isCorrect, completion.results.single.isCorrect,
            reason: '${q.item.id}: "$answer"');
        expect(check.result.match?.kind, completion.results.single.match?.kind);
      }
    }
  });

  test('the shown total equals the score the completion awards', () {
    final answerSets = <Map<String, String>>[
      {for (final q in questions) q.item.id: q.correctAnswer},
      {for (final q in questions) q.item.id: 'wrong'},
      {
        for (final (i, q) in questions.indexed)
          q.item.id: i.isEven ? q.correctAnswer : 'nope',
      },
      {questions.first.item.id: questions.first.correctAnswer},
      {},
    ];
    for (final answers in answerSets) {
      final checks = [
        for (final q in questions)
          QuestionCheck.of(q, answers[q.item.id] ?? ''),
      ];
      final completion = DailyTestCompletion(
        set: DailyTestSet(day: '2026-11-17', questions: questions),
        answers: answers,
        completedAt: DateTime(2026, 11, 17),
      );
      expect(
          QuestionCheck.displayTotal(checks),
          MonthlyMedalRules.score(
              correct: completion.correct, wrong: completion.wrong),
          reason: '$answers');
    }
  });

  test('+2 for a correct answer, +1 for a wrong one, 0 for a skip', () {
    final q = questions.first;
    expect(QuestionCheck.of(q, q.correctAnswer).points, 2);
    expect(QuestionCheck.of(q, 'definitely wrong').points, 1);
    expect(QuestionCheck.of(q, '   ').points, 0);
  });

  group('multi-blank (Q04)', () {
    const item = PracticeItem(
      id: 'm1',
      type: PracticeItemType.fillInBlank,
      context: 'We had ____ lunch at ____ small café near ____ station.',
      instruction: 'Fill in each blank with an article, or none.',
    );
    final q = DailyTestQuestion(
      item: item,
      topicId: 'articles',
      correctAnswer: 'We had lunch at a small café near the station.',
      commonWrongAnswers: const [],
    );

    test('the key is split at the template\'s fixed text', () {
      expect(QuestionCheck.expectedBlanks(q), ['', 'a', 'the']);
    });

    test('each blank is graded on its own; the question as a whole as before',
        () {
      final answers = [
        const BlankAnswer.noArticle(),
        const BlankAnswer('the'),
        const BlankAnswer('the'),
      ];
      final check = QuestionCheck.of(
          q, assembleBlanks(blankSourceText(item), answers),
          blankAnswers: answers);
      expect(check.blanks, [true, false, true]);
      expect(check.isCorrect, isFalse);
      expect(check.points, 1);
    });

    test('all blanks right: correct, +2', () {
      final answers = [
        const BlankAnswer.noArticle(),
        const BlankAnswer('a'),
        const BlankAnswer('The'),
      ];
      final check = QuestionCheck.of(
          q, assembleBlanks(blankSourceText(item), answers),
          blankAnswers: answers);
      expect(check.blanks, [true, true, true]);
      expect(check.isCorrect, isTrue);
      expect(check.points, 2);
    });

    test(
        'a key that does not follow the template: every blank takes the '
        'question\'s result', () {
      final odd = DailyTestQuestion(
          item: item,
          topicId: 'articles',
          correctAnswer: 'a, the',
          commonWrongAnswers: const []);
      final answers = [
        const BlankAnswer('x'),
        const BlankAnswer('y'),
        const BlankAnswer('z'),
      ];
      expect(QuestionCheck.blankResults(odd, answers, overall: false),
          [false, false, false]);
    });
  });
}
