import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';

/// Regression coverage for the Daily Test crash: "type 'Null' is not a
/// subtype of type 'Map<String, dynamic>' in type cast". Root cause was a
/// schema mismatch, not bad API data — DailyTestQuestion.fromJson expected
/// a nested "item" key that the JSON schema
/// ClaudeService.generateDailyTestQuestions actually sends the API never
/// asked for (see docs/build-log.md). None of this hits the network: it
/// feeds fixed JSON, shaped exactly like the real request schema, straight
/// into the parser.
void main() {
  group('DailyTestQuestion.fromJson', () {
    test(
      'parses the flat shape actually requested from the Claude API '
      '(regression: this used to require a nested "item" key the schema '
      'never asked for, which crashed on every real generation call)',
      () {
        final flatApiShapedJson = {
          'id': 'q1',
          'type': 'fill_in_blank',
          'context': 'Some context.',
          'instruction': 'Fill in the blank: She ___ to work every day.',
          'hint': 'a hint',
          'topicId': 'tenseSelection',
          'correctAnswer': 'goes',
          'commonWrongAnswers': [
            {'answer': 'go', 'comment': "Close! Needs an -s for 'she'."},
          ],
        };

        final question = DailyTestQuestion.fromJson(flatApiShapedJson);

        expect(question.item.id, 'q1');
        expect(question.item.instruction,
            'Fill in the blank: She ___ to work every day.');
        expect(question.topicId, 'tenseSelection');
        expect(question.correctAnswer, 'goes');
        expect(question.commonWrongAnswers.single.answer, 'go');
      },
    );

    test(
      'a missing required field throws an error naming that field, not a '
      'raw type-cast error',
      () {
        final missingTopicId = {
          'id': 'q1',
          'type': 'fill_in_blank',
          'instruction': 'Fill in the blank.',
          'correctAnswer': 'goes',
          'commonWrongAnswers': <Map<String, dynamic>>[],
          // 'topicId' deliberately omitted.
        };

        expect(
          () => DailyTestQuestion.fromJson(missingTopicId),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('topicId'),
            ),
          ),
        );
      },
    );

    test('round-trips through toJson using the same flat shape', () {
      final json = {
        'id': 'q2',
        'type': 'error_correction',
        'instruction': 'Rewrite the corrected sentence.',
        'topicId': 'articles',
        'correctAnswer': 'He goes to school.',
        'commonWrongAnswers': <Map<String, dynamic>>[],
      };

      final roundTripped =
          DailyTestQuestion.fromJson(DailyTestQuestion.fromJson(json).toJson());

      expect(roundTripped.item.id, 'q2');
      expect(roundTripped.topicId, 'articles');
      expect(roundTripped.correctAnswer, 'He goes to school.');
    });
  });
}
