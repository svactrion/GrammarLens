import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/answer_diff.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';
import 'package:grammar_lens/widgets/review_parts.dart';

/// Fix round 6, item 3 (V16, R03). On the owner's phone, after one practice
/// set each of Relative Clauses, Prepositions and Passive Voice: Review's
/// weak-spot cards showed the whole corrected sentence and then, appended,
/// a long struck-through piece of the learner's line, with instruction
/// words and the cue in brackets in it, instead of the wrong word struck
/// in place.
///
/// The shapes here are what the practice flow stores (`ResultsScreen`'s
/// `_saveErrors`): `prompt` is the item's full text; `userAnswer` is the
/// typed text for a single box, and for 2 to 4 blanks the text that holds
/// the blanks with each blank filled (`assembleBlanks(blankSourceText)`),
/// so with every other word on that text; `correctedAnswer` is the
/// scorer's. Every sentence below is invented.
PracticeItem _item(String instruction, {String? context}) => PracticeItem(
    id: 'q',
    type: PracticeItemType.fillInBlank,
    context: context,
    instruction: instruction);

/// The record a multi-blank practice answer leaves.
ErrorEntry _assembled(PracticeItem item, List<String> boxes, String fixed,
        {String topic = 'passiveVoice'}) =>
    ErrorEntry(
      topicId: topic,
      errorType: 'wrong_form',
      timestamp: DateTime(2026, 11, 19),
      source: ErrorSource.topicPractice,
      prompt: item.fullText,
      userAnswer: assembleBlanks(
          blankSourceText(item), [for (final box in boxes) BlankAnswer(box)]),
      correctedAnswer: fixed,
      userBlanks: [for (final box in boxes) BlankAnswer(box)],
    );

ErrorEntry _typed(String answer, String fixed, {String? prompt}) => ErrorEntry(
      topicId: 'relativeClauses',
      errorType: 'wrong_pronoun',
      timestamp: DateTime(2026, 11, 19),
      source: ErrorSource.topicPractice,
      prompt: prompt,
      userAnswer: answer,
      correctedAnswer: fixed,
    );

/// The card's sentence with its marks: ~struck~ and +green+.
String _card(ErrorEntry entry) => InlineMistake.parts(entry)!
    .map((part) => switch (part.$2) {
          InlineMark.plain => part.$1,
          InlineMark.wrong => '~${part.$1}~',
          InlineMark.right => '+${part.$1}+',
        })
    .join();

void main() {
  group('a multi-blank answer: the wrong word in place, nothing else struck',
      () {
    test(
        'a blank-bearing line that starts with an instruction and a '
        'quotation mark; one word differs (the owner\'s first two cards)', () {
      final relative = _assembled(
          _item("Fill in each blank with a relative pronoun: 'The woman "
              "____ lives next door has a son ____ plays the violin.'"),
          ['which', 'who'],
          'The woman who lives next door has a son who plays the violin.');
      expect(
          relative.userAnswer,
          "Fill in each blank with a relative pronoun: 'The woman which "
          "lives next door has a son who plays the violin.'",
          reason: 'what is stored: the whole line');
      expect(
          _card(relative),
          'The woman ~which~ +who+ lives next door has a son who plays the '
          'violin.');

      final preposition = _assembled(
          _item("Choose the right preposition for each blank: 'We arrived "
              "____ the airport ____ Monday morning.'"),
          ['to', 'on'],
          'We arrived at the airport on Monday morning.');
      expect(_card(preposition),
          'We arrived ~to~ +at+ the airport on Monday morning.');
    });

    test(
        'blanks followed by a base form in brackets (the third card): no '
        'instruction word and no cue is struck', () {
      final entry = _assembled(
          _item("Complete with the verbs in brackets: 'The reports ____ "
              "(send) yesterday, and the invoices ____ (pay) today.'"),
          ['was sent', 'are paid'],
          'The reports were sent yesterday, and the invoices are paid today.');
      final card = _card(entry);
      expect(
          card,
          'The reports ~was~ +were+ sent yesterday, and the invoices are '
          'paid today.');
      for (final never in ['brackets', 'Complete', '(send)', '(pay)']) {
        expect(card, isNot(contains(never)));
      }
    });

    test('the blanks in the context line, the instruction on its own line', () {
      final entry = _assembled(
          _item('Complete with the passive form of the verbs.',
              context: 'The bridge ____ (build) in 1932 and ____ (repair) '
                  'twice since then.'),
          ['built', 'has been repaired'],
          'The bridge was built in 1932 and has been repaired twice since '
          'then.');
      expect(
          _card(entry),
          'The bridge +was+ built in 1932 and has been repaired twice since '
          'then.');
    });

    test('several blanks in one sentence, two of them wrong', () {
      final entry = _assembled(
          _item("Put one preposition in each blank: 'She has lived ____ "
              "Lisbon ____ 2019 and works ____ a bank.'"),
          ['at', 'for', 'in'],
          'She has lived in Lisbon since 2019 and works in a bank.',
          topic: 'prepositions');
      expect(
          _card(entry),
          'She has lived ~at~ +in+ Lisbon ~for~ +since+ 2019 and works in a '
          'bank.');
    });

    test('a blank left empty: its underscores are not shown, the word is green',
        () {
      final entry = _assembled(
          _item("Fill in each blank with a relative pronoun: 'The film "
              "____ we saw, ____ director is Danish, won a prize.'"),
          ['that', ''],
          'The film that we saw, whose director is Danish, won a prize.');
      expect(entry.userAnswer, contains('____'));
      expect(_card(entry),
          'The film that we saw, +whose+ director is Danish, won a prize.');
    });

    test('the learner\'s wrong word is also a word of the instruction', () {
      final entry = _assembled(
          _item("Fill in the blanks with a, an or the: 'I saw ____ owl in "
              "____ garden behind our house.'"),
          ['the', 'a'],
          'I saw an owl in the garden behind our house.',
          topic: 'articles');
      expect(_card(entry),
          'I saw ~the~ +an+ owl in ~a~ +the+ garden behind our house.');
    });

    test(
        'the five older topics can show the same: an Articles line with its '
        'instruction renders as the bare sentence does', () {
      const fixed = 'She bought an umbrella and a pair of boots.';
      const expected = 'She bought ~a~ +an+ umbrella and a pair of boots.';
      final withInstruction = _assembled(
          _item("Fill in the blanks with a, an or the: 'She bought ____ "
              "umbrella and ____ pair of boots.'"),
          ['a', 'a'],
          fixed,
          topic: 'articles');
      final bare = _assembled(
          _item('She bought ____ umbrella and ____ pair of boots.'),
          ['a', 'a'],
          fixed,
          topic: 'articles');
      expect(_card(withInstruction), expected);
      expect(_card(bare), expected, reason: 'unchanged by this fix');
    });

    test(
        'too different to line up (the noise guard): what the learner typed, '
        'then the correction, never the line\'s other words', () {
      final entry = _assembled(
          _item("Complete with the verbs in brackets: 'The letters ____ "
              "(write) and ____ (post).'"),
          ['writing by her yesterday', 'posting them'],
          'The letters were written and posted.');
      final diff = diffAnswer(
          userAnswer: entry.userAnswer!,
          correctedAnswer: entry.correctedAnswer!,
          prompt: entry.prompt);
      expect(diff.assembled, isTrue);
      expect(diff.highlighted, isFalse);
      expect(
          _card(entry),
          '~writing by her yesterday posting them~ +The letters were '
          'written and posted.+');
    });
  });

  group('the other stored shapes are as before', () {
    test('a single box: the typed word, then the scorer\'s sentence', () {
      expect(
          _card(_typed('which', 'The man who lives next door is a doctor.',
              prompt: "Fill in the blank: 'The man ____ lives next door is a "
                  "doctor.'")),
          '~which~ +The man who lives next door is a doctor.+');
      expect(_card(_typed('which', 'who')), '~which~ +who+');
    });

    test('a rewritten sentence (error correction, sentence writing)', () {
      expect(
          _card(_typed('She is a tallest girl in her class.',
              'She is the tallest girl in her class.')),
          'She is ~a~ +the+ tallest girl in her class.');
      expect(
          _card(_typed('The house who I bought is old.',
              'The house that I bought is old.',
              prompt: 'Correct the sentence.\nThe house who I bought is '
                  'old.')),
          'The house ~who~ +that+ I bought is old.');
    });

    test('B10.3: a bridged function word stays inside its two runs', () {
      expect(
          _card(_typed('They finally to decide applying for it.',
              'They finally decided to apply for it.')),
          'They finally ~to~ ~decide~ ~applying~ +decided+ +to+ +apply+ for '
          'it.');
    });

    test('a word missing, a word too many, a different ending', () {
      expect(_card(_typed('He go to school.', 'He goes to school.')),
          'He ~go~ +goes+ to school.');
      expect(_card(_typed('I have went there.', 'I went there.')),
          'I ~have~ went there.');
      expect(_card(_typed('She bought umbrella.', 'She bought an umbrella.')),
          'She bought +an+ umbrella.');
      expect(_card(_typed('We met in Monday', 'We met on Monday.')),
          'We met ~in~ +on+ Monday.');
    });

    test('nothing stored: nothing shown; no answer: the correction', () {
      expect(InlineMistake.parts(_typed('x', '')), isNull);
      expect(_card(_typed('', 'who')), '+who+');
    });
  });

  testWidgets(
      'Review\'s card for a new topic: the sentence with the wrong word '
      'struck in place, as one text', (tester) async {
    final entry = _assembled(
        _item("Complete with the verbs in brackets: 'The reports ____ "
            "(send) yesterday, and the invoices ____ (pay) today.'"),
        ['was sent', 'are paid'],
        'The reports were sent yesterday, and the invoices are paid today.');
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: ReviewSpotCard(
          topic: topicByName('passiveVoice')!,
          spot: WeakSpot(
              topicId: 'passiveVoice',
              errorType: 'wrong_form',
              frequency: 1,
              lastSeen: DateTime(2026, 11, 19)),
          mistake: entry,
          onTap: () {},
          now: DateTime(2026, 11, 19, 12),
        ),
      ),
    ));
    final text = tester.widget<RichText>(find.descendant(
        of: find.byType(InlineMistake), matching: find.byType(RichText)));
    final spans = <(String, bool)>[];
    text.text.visitChildren((span) {
      if (span is TextSpan && span.text != null) {
        spans.add(
            (span.text!, span.style?.decoration == TextDecoration.lineThrough));
      }
      return true;
    });
    expect(spans.map((s) => s.$1).join(),
        'The reports was were sent yesterday, and the invoices are paid today.');
    expect([
      for (final (word, struck) in spans)
        if (struck) word
    ], [
      'was'
    ]);
  });
}
