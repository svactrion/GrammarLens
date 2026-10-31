import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/feedback_format.dart';

/// The AI feedback formatter (1.4.0 B9, owner 2026-10-31): sentence split,
/// paragraphs, the closing paragraph and quoted-example emphasis, on the
/// real feedback text the decision was designed against.
void main() {
  const sample =
      "You got the first blank right ('to procrastinate' — great!), but "
      "'decided changing' sounds wrong; 'decided' is always followed by "
      "'to + verb', so it should be 'decided to change'. Similarly, "
      "'considered' is always followed by the -ing form, so 'considered to "
      "join' should be 'considered joining'. Finally, 'makes it hard "
      "staying' doesn't sound natural — the correct pattern here is 'makes "
      "it hard to stay'. Three of the four blanks needed a small fix, but "
      "the logic is simple: some words go with 'to + verb' and others go "
      "with '-ing', and learning which is which will make your sentences "
      "sound much more fluent.";

  List<String> emphasized(String sentence) => [
        for (final s in emphasizeQuotes(sentence))
          if (s.emphasized) s.text
      ];

  group('the real sample', () {
    test('four sentences, four paragraphs, the last one closing', () {
      final f = formatFeedback(sample);
      expect(f.sentenceCount, 4);
      expect(f.paragraphs, hasLength(4));
      expect(f.hasClosing, isTrue);
      expect(f.paragraphs[0].text, startsWith('You got the first blank'));
      expect(f.paragraphs[0].text, endsWith("'decided to change'."));
      expect(f.paragraphs[1].text, startsWith('Similarly,'));
      expect(f.paragraphs[2].text, startsWith('Finally,'));
      expect(f.paragraphs[3].text, startsWith('Three of the four'));
      expect(f.paragraphs[3].text, endsWith('much more fluent.'));
      // Nothing lost or doubled.
      expect(f.paragraphs.map((p) => p.text).join(' '), sample);
    });

    test('the quoted examples are emphasised, quotes included', () {
      final f = formatFeedback(sample);
      expect(f.paragraphs[0].emphasized, [
        "'to procrastinate'",
        "'decided changing'",
        "'decided'",
        "'to + verb'",
        "'decided to change'",
      ]);
      expect(f.paragraphs[1].emphasized,
          ["'considered'", "'considered to join'", "'considered joining'"]);
      expect(f.paragraphs[2].emphasized,
          ["'makes it hard staying'", "'makes it hard to stay'"]);
      expect(f.paragraphs[3].emphasized, ["'to + verb'", "'-ing'"]);
    });
  });

  group('splitSentences', () {
    test('a mark inside parentheses does not end the sentence', () {
      expect(splitSentences("Right ('great!' here), but wrong. Next one."),
          ["Right ('great!' here), but wrong.", 'Next one.']);
    });

    test('a mark followed by a closing quote still ends the sentence', () {
      expect(splitSentences("Say 'went.' Then stop."),
          ["Say 'went.'", 'Then stop.']);
    });

    test('an opening quote may start the next sentence', () {
      expect(splitSentences("Use the past. 'Went' is right."),
          ['Use the past.', "'Went' is right."]);
    });

    test('e.g., i.e., etc. and vs. do not end a sentence', () {
      expect(
          splitSentences('Some verbs, e.g. enjoy, take -ing. Others do not.'),
          ['Some verbs, e.g. enjoy, take -ing.', 'Others do not.']);
      expect(splitSentences('State verbs, i.e. know, stay simple. Fine.'),
          ['State verbs, i.e. know, stay simple.', 'Fine.']);
      expect(splitSentences('Apples, pears etc. Are all fruit.'),
          ['Apples, pears etc. Are all fruit.']);
      expect(splitSentences('Gerund vs. Infinitive is the topic. Learn it.'),
          ['Gerund vs. Infinitive is the topic.', 'Learn it.']);
    });

    test('a mark followed by a lowercase word does not split', () {
      expect(splitSentences('It is 3.5 metres. ok then. Fine.'),
          ['It is 3.5 metres. ok then.', 'Fine.']);
    });

    test('blank text gives no sentences; stray whitespace is trimmed', () {
      expect(splitSentences(''), isEmpty);
      expect(splitSentences('   '), isEmpty);
      expect(splitSentences('  One.   Two.  '), ['One.', 'Two.']);
    });
  });

  group('paragraphs', () {
    test('one sentence stays one paragraph, no closing', () {
      final f = formatFeedback("After 'enjoy', the verb takes -ing.");
      expect(f.sentenceCount, 1);
      expect(f.paragraphs, hasLength(1));
      expect(f.hasClosing, isFalse);
      expect(f.paragraphs.single.emphasized, ["'enjoy'"]);
    });

    test('two sentences stay one paragraph, a space between them', () {
      final f = formatFeedback(
          "Right fix. Next time write out the full sentence for practice.");
      expect(f.sentenceCount, 2);
      expect(f.paragraphs, hasLength(1));
      expect(f.paragraphs.single.text,
          'Right fix. Next time write out the full sentence for practice.');
      expect(f.hasClosing, isFalse);
    });

    test('three sentences: three paragraphs, no closing rule', () {
      final f = formatFeedback(
          "'Decided' takes 'to'. 'Considered' takes -ing. 'Hard' takes 'to'.");
      expect(f.sentenceCount, 3);
      expect(f.paragraphs.map((p) => p.text), [
        "'Decided' takes 'to'.",
        "'Considered' takes -ing.",
        "'Hard' takes 'to'."
      ]);
      expect(f.hasClosing, isFalse);
    });

    test('an empty string formats to no paragraphs', () {
      final f = formatFeedback('');
      expect(f.paragraphs, isEmpty);
      expect(f.sentenceCount, 0);
    });
  });

  group('emphasizeQuotes', () {
    test("an apostrophe inside a word never opens: only 'fine'", () {
      expect(emphasized("I don't think it's 'fine'."), ["'fine'"]);
    });

    test("a possessive is closing-shaped but nothing is open: only 'lost'", () {
      expect(emphasized("The learners' books were 'lost'."), ["'lost'"]);
    });

    test('an apostrophe inside a quoted phrase does not close it', () {
      expect(emphasized("He said 'it's okay' here."), ["'it's okay'"]);
    });

    test('an unbalanced opening quote stays plain', () {
      final spans = emphasizeQuotes("An unbalanced 'quote here and on.");
      expect(spans.where((s) => s.emphasized), isEmpty);
      expect(
          spans.map((s) => s.text).join(), "An unbalanced 'quote here and on.");
    });

    test('a double-quoted span is emphasised too', () {
      expect(
          emphasized('Also correct: "the best". Keep going.'), ['"the best"']);
      expect(emphasized('You typed “isn’t” here.'), ['“isn’t”']);
    });

    test('a quote after a bracket, a dash or a colon-space opens', () {
      expect(
          emphasized("Right ('great') and — 'fine'."), ["'great'", "'fine'"]);
    });

    test('curly single quotes open and close like straight ones', () {
      expect(emphasized("So it’s ‘avoid eating’ here."), ['‘avoid eating’']);
    });

    test('the first closing-shaped quote closes; no nesting', () {
      expect(emphasized("Say 'the learners' book' now."), ["'the learners'"]);
    });

    test('a span over 80 characters stays plain', () {
      final long = "'${'word ' * 20}'";
      expect(emphasized('Use $long here.'), isEmpty);
    });

    test('the spans put back together are the sentence', () {
      const s = "You got 'to procrastinate' right, but 'decided changing' no.";
      expect(emphasizeQuotes(s).map((x) => x.text).join(), s);
    });
  });
}
