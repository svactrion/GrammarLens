import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';

/// The additive parsing rule of the scorer's structured feedback (1.4.0
/// D11, server package report §4.3) and how it combines with the B8 blank
/// guard: today's six fields always parse as before; `summary` and
/// `blanks` only when they are well formed.
void main() {
  Map<String, dynamic> response({
    bool isCorrect = false,
    Object? blanks,
    Object? summary,
  }) =>
      {
        'itemId': 'q1',
        'isCorrect': isCorrect,
        'errorType': 'gerund_vs_infinitive',
        'correctedAnswer': 'I enjoy swimming, but I have decided to learn.',
        'explanation': 'The long paragraph.',
        if (blanks != null) 'blanks': blanks,
        if (summary != null) 'summary': summary,
      };

  Map<String, Object> blank(int index, {bool accepted = true}) => {
        'index': index,
        'correctAnswer': index == 0 ? 'swimming' : 'to learn',
        'accepted': accepted,
        'note': 'Note $index.',
      };

  group('ItemFeedback.fromJson, the old shape', () {
    test('parses exactly as before: no summary, no blanks', () {
      final f =
          ItemFeedback.fromJson(response(isCorrect: true), isSkipped: false);
      expect(f.isCorrect, isTrue);
      expect(f.summary, isNull);
      expect(f.blanks, isNull);
      expect(f.explanation, 'The long paragraph.');
    });

    test('the B8 guard still forces an unfilled blank wrong', () {
      final f = ItemFeedback.fromJson(response(isCorrect: true),
          isSkipped: false, hasUnfilledBlank: true);
      expect(f.isCorrect, isFalse);
      expect(f.errorType, 'gerund_vs_infinitive');
    });
  });

  group('ItemFeedback.fromJson, the structured shape', () {
    test('reads the summary and the blanks', () {
      final f = ItemFeedback.fromJson(
        response(
            blanks: [blank(0), blank(1, accepted: false)],
            summary: ' Two sentences. At most. '),
        isSkipped: false,
      );
      expect(f.summary, 'Two sentences. At most.');
      expect(f.blanks!.map((b) => b.correctAnswer), ['swimming', 'to learn']);
      expect(f.blanks!.map((b) => b.accepted), [true, false]);
      expect(f.blanks!.map((b) => b.note), ['Note 0.', 'Note 1.']);
    });

    test('a blank or non-string summary reads as none', () {
      for (final summary in ['', '  ', 3, true]) {
        expect(
            ItemFeedback.fromJson(response(summary: summary), isSkipped: false)
                .summary,
            isNull,
            reason: '$summary');
      }
    });

    test(
        'a malformed blanks list reads as null: non-list, empty, a missing field, a wrong type, a bad index',
        () {
      final malformed = <Object?>[
        'not a list',
        <Object>[],
        [
          {'index': 0, 'correctAnswer': 'x', 'accepted': true}
        ],
        [
          {'index': 0, 'correctAnswer': 'x', 'accepted': 'yes', 'note': 'n'}
        ],
        [blank(1)],
        [blank(0), blank(0)],
        [blank(1), blank(0)],
      ];
      for (final blanks in malformed) {
        final f = ItemFeedback.fromJson(
            response(isCorrect: true, blanks: blanks),
            isSkipped: false);
        expect(f.blanks, isNull, reason: '$blanks');
        expect(f.isCorrect, isTrue, reason: 'today\'s rule decides');
      }
    });
  });

  group('the guard with per-blank verdicts', () {
    test(
        'an empty box is never accepted, whatever the model says, and the item is wrong',
        () {
      final f = ItemFeedback.fromJson(
        response(isCorrect: true, blanks: [blank(0), blank(1)]),
        isSkipped: false,
        hasUnfilledBlank: true,
        userBlanks: const [BlankAnswer('swimming'), BlankAnswer('')],
      );
      expect(f.blanks!.map((b) => b.accepted), [true, false]);
      expect(f.isCorrect, isFalse);
    });

    test('a no-article box counts as filled', () {
      final f = ItemFeedback.fromJson(
        response(blanks: [blank(0), blank(1)]),
        isSkipped: false,
        userBlanks: const [BlankAnswer.noArticle(), BlankAnswer('an')],
      );
      expect(f.blanks!.every((b) => b.accepted), isTrue);
      expect(f.isCorrect, isTrue);
    });

    test(
        'every blank accepted makes the item correct even when the model\'s own verdict says otherwise',
        () {
      final f = ItemFeedback.fromJson(
        response(isCorrect: false, blanks: [blank(0), blank(1)]),
        isSkipped: false,
        userBlanks: const [BlankAnswer('swimming'), BlankAnswer('to learn')],
      );
      expect(f.isCorrect, isTrue);
    });

    test(
        'one rejected blank makes the item wrong even when the model\'s verdict says correct',
        () {
      final f = ItemFeedback.fromJson(
        response(
            isCorrect: true, blanks: [blank(0), blank(1, accepted: false)]),
        isSkipped: false,
        userBlanks: const [BlankAnswer('swimming'), BlankAnswer('learning')],
      );
      expect(f.isCorrect, isFalse);
    });

    test(
        'without a snapshot, or with a length that does not match, the blanks are kept and today\'s rule decides',
        () {
      for (final userBlanks in [
        null,
        const <BlankAnswer>[BlankAnswer('x')]
      ]) {
        final f = ItemFeedback.fromJson(
          response(
              isCorrect: true, blanks: [blank(0), blank(1, accepted: false)]),
          isSkipped: false,
          userBlanks: userBlanks,
        );
        expect(f.blanks, hasLength(2), reason: '$userBlanks');
        expect(f.blanks!.last.accepted, isFalse);
        expect(f.isCorrect, isTrue, reason: 'the model\'s verdict, as before');
      }
      final guarded = ItemFeedback.fromJson(
        response(isCorrect: true, blanks: [blank(0)]),
        isSkipped: false,
        hasUnfilledBlank: true,
      );
      expect(guarded.isCorrect, isFalse);
    });
  });

  test('BlankFeedback round-trips through toJson', () {
    const b = BlankFeedback(
        index: 2,
        correctAnswer: 'to run',
        accepted: false,
        note: 'After plan, use to.');
    expect(
        BlankFeedback.listFromJson([
          blank(0),
          blank(1),
          b.toJson(),
        ])!
            .last
            .note,
        'After plan, use to.');
    expect(b.copyWith(accepted: true).accepted, isTrue);
    expect(b.copyWith().index, 2);
  });
}
