import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/utils/answer_matching.dart';

/// The Dart side of the two fixtures the proxy also tests against
/// (docs/1.1.0-shared-daily-test-quality.md §8.3): the proxy's TypeScript
/// port of the normalization and of the grading order must agree with
/// `normalizeAnswer`, `foldKeyboardVariants` and `checkDailyTestAnswer`, or
/// one of the two suites turns red.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('proxy/test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('answer_normalization.json', () {
    final fixture = _fixture('answer_normalization.json');

    test('has cases for both functions', () {
      expect(fixture['normalize'], isNotEmpty);
      expect(fixture['fold'], isNotEmpty);
    });

    for (final c in (fixture['normalize'] as List).cast<Map>()) {
      test('normalizeAnswer(${jsonEncode(c['input'])})', () {
        expect(normalizeAnswer(c['input'] as String), c['expected']);
      });
    }
    for (final c in (fixture['fold'] as List).cast<Map>()) {
      test('foldKeyboardVariants(${jsonEncode(c['input'])})', () {
        expect(foldKeyboardVariants(c['input'] as String), c['expected']);
      });
    }
  });

  group('daily_test_grading.json', () {
    final fixture = _fixture('daily_test_grading.json');
    final q = fixture['question'] as Map<String, dynamic>;
    final question = DailyTestQuestion(
      item: const PracticeItem(
        id: 'g1',
        type: PracticeItemType.errorCorrection,
        instruction: 'Correct the sentence.',
      ),
      topicId: 'tenseSelection',
      correctAnswer: q['correctAnswer'] as String,
      acceptedAnswers: (q['acceptedAnswers'] as List).cast<String>(),
      commonWrongAnswers: [
        for (final w in (q['commonWrongAnswers'] as List).cast<Map>())
          CommonWrongAnswer(answer: w['answer'] as String, comment: 'c'),
      ],
    );
    final cases = (fixture['cases'] as List).cast<Map>();

    test('reaches every kind', () {
      expect(cases.map((c) => c['kind']).toSet(),
          AnswerMatchKind.values.map((k) => k.name).toSet());
    });

    for (final c in cases) {
      test('${jsonEncode(c['input'])} → ${c['kind']}', () {
        final result = checkDailyTestAnswer(question, c['input'] as String);
        expect(result.kind.name, c['kind']);
        if (result.kind == AnswerMatchKind.accepted) {
          expect(result.acceptedAnswer, q['acceptedAnswers'][0]);
        } else {
          expect(result.acceptedAnswer, isNull);
        }
      });
    }
  });
}
