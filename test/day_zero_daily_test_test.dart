import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/utils/answer_matching.dart';

/// The first-launch Daily Test is hand-written content, so the tests read it
/// the way a learner would: every right answer must be accepted, every answer
/// the set predicts must hit its own comment, and the shape must satisfy what
/// the Daily Test needs (allowed types, distinct catalog topics, stable ids).
void main() {
  test('is five questions with the ids day0_1 to day0_5, in order', () {
    expect(kDayZeroQuestions.map((q) => q.item.id),
        ['day0_1', 'day0_2', 'day0_3', 'day0_4', 'day0_5']);
  });

  test('is three fill-in-the-blank and two error-correction questions', () {
    final types = kDayZeroQuestions.map((q) => q.item.type).toList();
    expect(types.where((t) => t == PracticeItemType.fillInBlank), hasLength(3));
    expect(types.where((t) => t == PracticeItemType.errorCorrection),
        hasLength(2));
    // Only the two types with one canonical answer are allowed in a Daily
    // Test (the model asserts it too).
    expect(
        types,
        everyElement(anyOf(
            PracticeItemType.fillInBlank, PracticeItemType.errorCorrection)));
  });

  test('covers five different topics, all in the topic catalog', () {
    final catalog = kTopics.map((t) => t.id.name).toSet();
    final used = kDayZeroQuestions.map((q) => q.topicId).toList();
    expect(used.toSet(), hasLength(5));
    expect(catalog.containsAll(used), isTrue);
  });

  test('every question has an instruction, its own context and no empty text',
      () {
    for (final q in kDayZeroQuestions) {
      expect(q.item.instruction.trim(), isNotEmpty, reason: q.item.id);
      expect(q.item.context?.trim(), isNotEmpty, reason: q.item.id);
      expect(q.correctAnswer.trim(), isNotEmpty, reason: q.item.id);
      expect(q.commonWrongAnswers, isNotEmpty, reason: q.item.id);
      for (final wrong in q.commonWrongAnswers) {
        expect(wrong.answer.trim(), isNotEmpty, reason: q.item.id);
        expect(wrong.comment.trim(), isNotEmpty, reason: q.item.id);
      }
    }
  });

  test(
      'every question explains its answer in one sentence that stands on '
      'its own', () {
    for (final q in kDayZeroQuestions) {
      final explanation = q.explanation;
      expect(explanation, isNotNull, reason: q.item.id);
      expect(explanation!.trim(), isNotEmpty, reason: q.item.id);
      expect(explanation, endsWith('.'), reason: q.item.id);
      // One sentence: the only full stop is the final one.
      expect('.'.allMatches(explanation), hasLength(1), reason: q.item.id);
      // Shown on correct, skipped and unpredicted-wrong cards alike, so it
      // must not read as feedback on a particular answer.
      expect(explanation, isNot(startsWith('Not quite')), reason: q.item.id);
      expect(explanation, isNot(contains('you wrote')), reason: q.item.id);
    }
  });

  test(
      'a fill-in-the-blank question has a blank and a hint; an error '
      'correction one has neither', () {
    for (final q in kDayZeroQuestions) {
      if (q.item.type == PracticeItemType.fillInBlank) {
        expect(q.item.context, contains('___'), reason: q.item.id);
        expect(q.item.hint, isNotNull, reason: q.item.id);
      } else {
        expect(q.item.context, isNot(contains('___')), reason: q.item.id);
        expect(q.item.hint, isNull, reason: q.item.id);
      }
    }
  });

  test('each correct answer is graded correct', () {
    for (final q in kDayZeroQuestions) {
      expect(checkDailyTestAnswer(q, q.correctAnswer).kind,
          AnswerMatchKind.correct,
          reason: q.item.id);
      // With the punctuation and case a learner might add.
      expect(
          checkDailyTestAnswer(q, '  ${q.correctAnswer.toUpperCase()}. ').kind,
          AnswerMatchKind.correct,
          reason: q.item.id);
    }
  });

  test(
      'no predicted wrong answer is also the correct answer, and none is '
      'listed twice', () {
    for (final q in kDayZeroQuestions) {
      final wrongs =
          q.commonWrongAnswers.map((w) => normalizeAnswer(w.answer)).toList();
      expect(wrongs, isNot(contains(normalizeAnswer(q.correctAnswer))),
          reason: q.item.id);
      expect(wrongs.toSet(), hasLength(wrongs.length), reason: q.item.id);
    }
  });

  test(
      'every predicted wrong answer is graded commonWrong with its own '
      'comment', () {
    for (final q in kDayZeroQuestions) {
      for (final wrong in q.commonWrongAnswers) {
        final result = checkDailyTestAnswer(q, wrong.answer);
        expect(result.kind, AnswerMatchKind.commonWrong,
            reason: '${q.item.id}: ${wrong.answer}');
        expect(result.comment, wrong.comment);
      }
    }
  });

  /// The answers a learner is most likely to give, per question, written
  /// out from the product decision (not read back from the data), so
  /// removing one from the set turns this red.
  test('the guessable wrong answers each get a specific comment', () {
    const guesses = {
      'day0_1': ['to eat', 'eat'],
      'day0_2': [
        'She is a best student in our class',
        'She is best student in our class'
      ],
      'day0_3': [
        'She can speaking three languages',
        'She can to speak three languages',
        'She can speaks three languages',
      ],
      'day0_4': ['will', 'could'],
      'day0_5': ['have seen', 'seen', 'had seen'],
    };
    for (final q in kDayZeroQuestions) {
      for (final guess in guesses[q.item.id]!) {
        expect(checkDailyTestAnswer(q, guess).kind, AnswerMatchKind.commonWrong,
            reason: '${q.item.id}: $guess');
      }
    }
  });

  test(
      'an error-correction question predicts the unchanged sentence, with or '
      'without its final full stop', () {
    for (final q in kDayZeroQuestions
        .where((q) => q.item.type == PracticeItemType.errorCorrection)) {
      final unchanged = q.item.context!;
      expect(
          checkDailyTestAnswer(q, unchanged).kind, AnswerMatchKind.commonWrong,
          reason: q.item.id);
      expect(
          checkDailyTestAnswer(q, unchanged.replaceFirst(RegExp(r'\.$'), ''))
              .kind,
          AnswerMatchKind.commonWrong,
          reason: q.item.id);
      expect(
          normalizeAnswer(unchanged), isNot(normalizeAnswer(q.correctAnswer)),
          reason: '${q.item.id}: the shown sentence must contain the mistake');
    }
  });

  test('an unpredicted answer falls through to the generic fallback', () {
    for (final q in kDayZeroQuestions) {
      expect(checkDailyTestAnswer(q, 'zzz not an answer').kind,
          AnswerMatchKind.fallback,
          reason: q.item.id);
    }
  });

  test('round-trips through toJson and fromJson', () {
    for (final q in kDayZeroQuestions) {
      final copy = DailyTestQuestion.fromJson(q.toJson());
      expect(copy.toJson(), q.toJson(), reason: q.item.id);
      expect(copy.item.id, q.item.id);
      expect(copy.topicId, q.topicId);
      expect(copy.correctAnswer, q.correctAnswer);
      expect(copy.commonWrongAnswers.map((w) => (w.answer, w.comment)),
          q.commonWrongAnswers.map((w) => (w.answer, w.comment)));
      expect(copy.explanation, q.explanation);
    }
  });
}
