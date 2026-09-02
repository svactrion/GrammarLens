import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/utils/answer_matching.dart';

void main() {
  final question = DailyTestQuestion(
    item: const PracticeItem(
      id: 'q1',
      type: PracticeItemType.fillInBlank,
      instruction: 'Fill in the blank: She ___ to work every day.',
    ),
    topicId: 'tenseSelection',
    correctAnswer: 'goes',
    commonWrongAnswers: const [
      CommonWrongAnswer(
        answer: 'go',
        comment: "Close! But with 'she', the verb needs an -s: 'goes'.",
      ),
      CommonWrongAnswer(
        answer: 'is going',
        comment: 'That describes right now, not a daily routine — use the '
            'simple present instead.',
      ),
    ],
  );

  group('checkDailyTestAnswer', () {
    test('an exact match to the correct answer is marked correct', () {
      final result = checkDailyTestAnswer(question, 'goes');
      expect(result.kind, AnswerMatchKind.correct);
      expect(result.correctAnswer, 'goes');
      expect(result.comment, isNull);
    });

    test('a match to a predicted common wrong answer returns its comment',
        () {
      final result = checkDailyTestAnswer(question, 'go');
      expect(result.kind, AnswerMatchKind.commonWrong);
      expect(result.correctAnswer, 'goes');
      expect(result.comment, contains('goes'));
    });

    test('a second predicted common wrong answer also matches', () {
      final result = checkDailyTestAnswer(question, 'is going');
      expect(result.kind, AnswerMatchKind.commonWrong);
      expect(result.comment, contains('simple present'));
    });

    test('an unpredicted wrong answer falls back with no canned comment',
        () {
      final result = checkDailyTestAnswer(question, 'went');
      expect(result.kind, AnswerMatchKind.fallback);
      expect(result.correctAnswer, 'goes');
      expect(result.comment, isNull);
    });

    test('an empty answer falls back rather than matching anything', () {
      final result = checkDailyTestAnswer(question, '');
      expect(result.kind, AnswerMatchKind.fallback);
    });

    test('matching is case-insensitive', () {
      expect(
        checkDailyTestAnswer(question, 'GOES').kind,
        AnswerMatchKind.correct,
      );
      expect(
        checkDailyTestAnswer(question, 'Go').kind,
        AnswerMatchKind.commonWrong,
      );
    });

    test('surrounding and collapsed internal whitespace is ignored', () {
      expect(
        checkDailyTestAnswer(question, '  goes  ').kind,
        AnswerMatchKind.correct,
      );
      expect(
        checkDailyTestAnswer(question, 'is    going').kind,
        AnswerMatchKind.commonWrong,
      );
    });

    test('a trailing sentence-ending mark is ignored', () {
      final sentenceQuestion = DailyTestQuestion(
        item: const PracticeItem(
          id: 'q2',
          type: PracticeItemType.errorCorrection,
          context: 'He go to school yesterday.',
          instruction: 'Rewrite the full corrected sentence.',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'He went to school yesterday.',
        commonWrongAnswers: const [
          CommonWrongAnswer(
            answer: 'He goes to school yesterday.',
            comment: "'Goes' is present tense, but 'yesterday' needs past "
                "tense: 'went'.",
          ),
        ],
      );

      expect(
        checkDailyTestAnswer(
          sentenceQuestion,
          'He went to school yesterday',
        ).kind,
        AnswerMatchKind.correct,
      );
      expect(
        checkDailyTestAnswer(
          sentenceQuestion,
          'he went to school yesterday.',
        ).kind,
        AnswerMatchKind.correct,
      );
    });
  });

  group('normalizeAnswer', () {
    test('trims, lowercases, and collapses internal whitespace', () {
      expect(normalizeAnswer('  Goes   Home '), 'goes home');
    });

    test('drops exactly one trailing sentence-ending mark', () {
      expect(normalizeAnswer('He went home.'), 'he went home');
      expect(normalizeAnswer('He went home!'), 'he went home');
      expect(normalizeAnswer('He went home?'), 'he went home');
    });

    test('leaves internal punctuation alone', () {
      expect(normalizeAnswer("She isn't ready."), "she isn't ready");
    });
  });
}
