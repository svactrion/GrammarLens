import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/utils/answer_matching.dart';

import 'support/l10n_support.dart';

/// The keyboard-variant note as the card shows it in English.
String? note(AnswerMatchResult result) => result.keyboardNote == null
    ? null
    : keyboardVariantNoteText(result.keyboardNote!, en);

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

    test('a match to a predicted common wrong answer returns its comment', () {
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

    test('an unpredicted wrong answer falls back with no canned comment', () {
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

  group(
      'keyboard variants (Turkish letters 2026-09-07; the eight classes '
      '1.4.0 D3 / B3)', () {
    final keyboardQuestion = DailyTestQuestion(
      item: const PracticeItem(
        id: 'kb1',
        type: PracticeItemType.fillInBlank,
        instruction: "Fill in the blank: I really enjoy ___ for people.",
      ),
      topicId: 'gerundVsInfinitive',
      correctAnswer: 'cooking',
      commonWrongAnswers: const [
        CommonWrongAnswer(
          answer: 'cook',
          comment: "Use the '-ing' form after 'enjoy'.",
        ),
      ],
    );

    test('an exact identical answer is plain correct, not a keyboard variant',
        () {
      final result = checkDailyTestAnswer(keyboardQuestion, 'cooking');
      expect(result.kind, AnswerMatchKind.correct);
      expect(result.comment, isNull);
    });

    test(
        'a dotless-ı vs. dotted-i difference (the actual reported case) is a '
        'keyboard variant, not a mistake', () {
      final result = checkDailyTestAnswer(keyboardQuestion, 'cookıng');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      expect(result.correctAnswer, 'cooking');
      expect(note(result), isNotNull);
      expect(note(result), contains('ı'));
      expect(note(result), contains('i'));
    });

    test('a case-only difference is plain correct, not a keyboard variant', () {
      // normalizeAnswer's own lowercasing resolves this before the
      // keyboard-variant fold ever runs — locks down that the two paths
      // don't overlap.
      final result = checkDailyTestAnswer(keyboardQuestion, 'COOKING');
      expect(result.kind, AnswerMatchKind.correct);
    });

    test(
        'leading/trailing whitespace around a keyboard-variant answer '
        'still matches as a variant', () {
      final result = checkDailyTestAnswer(keyboardQuestion, '  cookıng  ');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
    });

    test('a genuinely wrong answer is unaffected by keyboard-variant folding',
        () {
      final result = checkDailyTestAnswer(keyboardQuestion, 'swimming');
      expect(result.kind, AnswerMatchKind.fallback);
    });

    test('a skipped (empty) answer is unaffected by keyboard-variant folding',
        () {
      final result = checkDailyTestAnswer(keyboardQuestion, '');
      expect(result.kind, AnswerMatchKind.fallback);
    });

    test(
        'a real one-character grammar difference is still wrong — folding '
        'is a closed letter set, not general edit-distance', () {
      final tenseQuestion = DailyTestQuestion(
        item: const PracticeItem(
          id: 'kb2',
          type: PracticeItemType.fillInBlank,
          instruction: "Fill in the blank: She usually ___ home late.",
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'stays',
        commonWrongAnswers: const [],
      );

      final result = checkDailyTestAnswer(tenseQuestion, 'stay');
      expect(result.kind, AnswerMatchKind.fallback);
    });

    test('multiple differing keyboard letters are all named in the note', () {
      final multiQuestion = DailyTestQuestion(
        item: const PracticeItem(
          id: 'kb3',
          type: PracticeItemType.fillInBlank,
          instruction: 'Fill in the blank: I want ___ sugar.',
        ),
        topicId: 'gerundVsInfinitive',
        correctAnswer: 'to give up',
        commonWrongAnswers: const [],
      );

      final result = checkDailyTestAnswer(multiQuestion, 'to gıve üp');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      expect(
          note(result),
          'You typed "ı", "ü" — your keyboard\'s versions of "i", "u". Not '
          'a grammar mistake.');
    });

    test('one character: "version", singular', () {
      final result = checkDailyTestAnswer(keyboardQuestion, 'cookıng');
      expect(
          note(result),
          'You typed "ı" — your keyboard\'s version of "i". Not a grammar '
          'mistake.');
    });

    test('a full-width answer (ja, ko IME) is a keyboard variant', () {
      final result = checkDailyTestAnswer(keyboardQuestion, 'ｃｏｏｋｉｎｇ');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      // More than three characters: the note shows three and "…".
      expect(
          note(result),
          'You typed "ｃ", "ｏ", "ｋ" … — your keyboard\'s versions of "c", '
          '"o", "k" …. Not a grammar mistake.');
    });

    test('a full-width question mark at the end is dropped like "?"', () {
      expect(checkDailyTestAnswer(keyboardQuestion, 'cooking？').kind,
          AnswerMatchKind.keyboardVariant);
    });

    test('an added mark gets its own clause', () {
      final result = checkDailyTestAnswer(keyboardQuestion, '¡cooking');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      expect(note(result), 'Your keyboard added "¡" — not a grammar mistake.');
    });

    test('an invisible mark is named, not quoted', () {
      final result = checkDailyTestAnswer(keyboardQuestion, 'cook\u200Bing');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      expect(
          note(result),
          'Your keyboard added an invisible character — not a grammar '
          'mistake.');
    });

    test('both clauses when both happen', () {
      final result = checkDailyTestAnswer(keyboardQuestion, '¿cookıng');
      expect(
          note(result),
          'You typed "ı" — your keyboard\'s version of "i". Your keyboard '
          'added "¿" — not a grammar mistake.');
    });

    test('ß against ss changes the length and still names the letter', () {
      final question = DailyTestQuestion(
        item: const PracticeItem(
          id: 'kb4',
          type: PracticeItemType.fillInBlank,
          instruction: 'Fill in the blank: Please ___ the salt.',
        ),
        topicId: 'modalVerbs',
        correctAnswer: 'pass',
        commonWrongAnswers: const [],
      );
      final result = checkDailyTestAnswer(question, 'paß');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      expect(note(result), contains('"ß"'));
      expect(note(result), contains('"ss"'));
    });

    test('an answer in another script is not folded into English', () {
      expect(checkDailyTestAnswer(keyboardQuestion, '요리').kind,
          AnswerMatchKind.fallback);
    });

    test(
        'a non-plain key with a plain answer (never published: keys are '
        'plain) gets the general sentence', () {
      final question = DailyTestQuestion(
        item: const PracticeItem(
          id: 'kb5',
          type: PracticeItemType.fillInBlank,
          instruction: 'Fill in the blank: This is a ___ topic.',
        ),
        topicId: 'articles',
        correctAnswer: 'değişik',
        commonWrongAnswers: const [],
      );
      final result = checkDailyTestAnswer(question, 'degisik');
      expect(result.kind, AnswerMatchKind.keyboardVariant);
      expect(
          note(result),
          'Your answer matches apart from keyboard characters. Not a '
          'grammar mistake.');
    });
  });

  group('foldKeyboardVariants', () {
    test('folds each Turkish letter to its plain-ASCII variant', () {
      expect(foldKeyboardVariants('ışığı çözüyor'), 'isigi cozuyor');
    });

    test('folds by code point, not by UTF-16 unit', () {
      // An astral character passes through whole.
      expect(foldKeyboardVariants('go 🙂'), 'go 🙂');
    });

    test('leaves plain ASCII and unrelated characters untouched', () {
      expect(foldKeyboardVariants('stays, right?'), 'stays, right?');
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

    test('turns curly apostrophes and quotes into straight ones', () {
      expect(normalizeAnswer('She isn\u2019t ready'), "she isn't ready");
      expect(normalizeAnswer('\u2018tis'), "'tis");
      expect(normalizeAnswer('\u201CGo\u201D'), '"go"');
    });
  });

  group('curly punctuation in a checked answer', () {
    DailyTestQuestion contraction() => DailyTestQuestion(
          item: const PracticeItem(
            id: 'q1',
            type: PracticeItemType.errorCorrection,
            context: 'She not ready.',
            instruction: 'Rewrite the sentence.',
          ),
          topicId: 'tenseSelection',
          correctAnswer: "She isn't ready",
          commonWrongAnswers: const [
            CommonWrongAnswer(
              answer: "She don't ready",
              comment: "Use 'isn't' with 'ready'.",
            ),
          ],
        );

    test('a curly apostrophe still matches the correct answer', () {
      final result =
          checkDailyTestAnswer(contraction(), 'She isn\u2019t ready.');
      expect(result.kind, AnswerMatchKind.correct);
    });

    test('a curly apostrophe still matches a predicted wrong answer', () {
      final result =
          checkDailyTestAnswer(contraction(), 'She don\u2019t ready');
      expect(result.kind, AnswerMatchKind.commonWrong);
      expect(result.comment, "Use 'isn't' with 'ready'.");
    });

    test('a curly apostrophe in the answer key matches a straight one', () {
      final question = DailyTestQuestion(
        item: const PracticeItem(
          id: 'q1',
          type: PracticeItemType.fillInBlank,
          instruction: 'Fill in.',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'isn\u2019t',
        commonWrongAnswers: const [],
      );
      expect(checkDailyTestAnswer(question, "isn't").kind,
          AnswerMatchKind.correct);
    });
  });

  group('computeDailyTestScore', () {
    DailyTestQuestion questionAt(int i) => DailyTestQuestion(
          item: PracticeItem(
            id: 'q$i',
            type: PracticeItemType.fillInBlank,
            instruction: 'Question $i',
          ),
          topicId: 'tenseSelection',
          correctAnswer: 'answer$i',
          commonWrongAnswers: const [],
        );

    test('counts correct, wrong, and skipped separately', () {
      final questions = [questionAt(0), questionAt(1), questionAt(2)];
      final result = computeDailyTestScore(questions, {
        'q0': 'answer0', // correct
        'q1': 'something else', // wrong
        'q2': '', // skipped
      });

      expect(result.correct, 1);
      expect(result.total, 3);
      expect(result.skipped, 1);
    });

    test('a missing answer counts as skipped, not wrong', () {
      final questions = [questionAt(0)];
      final result = computeDailyTestScore(questions, const {});

      expect(result.correct, 0);
      expect(result.skipped, 1);
    });
  });

  group('acceptedAnswers (docs/1.1.0-shared-daily-test-quality.md §8)', () {
    DailyTestQuestion withAlternatives(List<String> accepted) =>
        DailyTestQuestion(
          item: question.item,
          topicId: question.topicId,
          correctAnswer: question.correctAnswer,
          commonWrongAnswers: question.commonWrongAnswers,
          acceptedAnswers: accepted,
        );

    test('without alternatives every answer grades exactly as before', () {
      final withEmpty = withAlternatives(const []);
      for (final answer in [
        'goes',
        'Goes.',
        'goes!',
        'go',
        'is going',
        'went',
        'göes',
        '',
      ]) {
        final a = checkDailyTestAnswer(question, answer);
        final b = checkDailyTestAnswer(withEmpty, answer);
        expect(b.kind, a.kind, reason: answer);
        expect(b.comment, a.comment, reason: answer);
        expect(a.acceptedAnswer, isNull);
      }
    });

    test('an alternative is accepted, normalized the same way, and counts', () {
      final q = withAlternatives(const ['is used to going']);
      final result = checkDailyTestAnswer(q, '  Is used to GOING. ');
      expect(result.kind, AnswerMatchKind.accepted);
      expect(result.acceptedAnswer, 'is used to going');
      expect(result.correctAnswer, 'goes');
      expect(result.kind.isCorrect, isTrue);
      expect(computeDailyTestScore([q], {'q1': 'is used to going'}).correct, 1);
    });

    test('a keyboard variant of an alternative is accepted too', () {
      final q = withAlternatives(const ['is used to going']);
      expect(checkDailyTestAnswer(q, 'ıs used to going').kind,
          AnswerMatchKind.accepted);
    });

    test('a full-width alternative is accepted too (1.4.0 B3)', () {
      final q = withAlternatives(const ['is used to going']);
      expect(checkDailyTestAnswer(q, 'ｉｓ　ｕｓｅｄ　ｔｏ　ｇｏｉｎｇ').kind,
          AnswerMatchKind.accepted);
    });

    test('the key still wins over an alternative', () {
      final q = withAlternatives(const ['goes']);
      expect(checkDailyTestAnswer(q, 'goes').kind, AnswerMatchKind.correct);
    });

    test('an alternative is checked before the predicted wrong answers', () {
      final q = withAlternatives(const ['go']);
      expect(checkDailyTestAnswer(q, 'go').kind, AnswerMatchKind.accepted);
      expect(checkDailyTestAnswer(q, 'is going').kind,
          AnswerMatchKind.commonWrong);
    });

    test('only correct, keyboardVariant and accepted count as correct', () {
      expect(AnswerMatchKind.values.where((k) => k.isCorrect).toSet(), {
        AnswerMatchKind.correct,
        AnswerMatchKind.keyboardVariant,
        AnswerMatchKind.accepted,
      });
    });
  });
}
