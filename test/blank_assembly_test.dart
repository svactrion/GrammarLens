import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';

/// Putting the answer boxes back into the sentence (question screen plan,
/// §4 and B3).
void main() {
  const a = BlankAnswer.new;
  const none = BlankAnswer.noArticle;

  group('assembleBlanks', () {
    test("the plan's worked examples", () {
      expect(
          assembleBlanks(
              'We had ____ lunch at ____ small café near ____ '
              'station.',
              [none(), a('a'), a('the')]),
          'We had lunch at a small café near the station.');
      expect(
          assembleBlanks(
              'Tom says: "I can\'t stop ____, but I\'ve promised ____ by '
              'May."',
              [a('smoking'), a('to quit')]),
          'Tom says: "I can\'t stop smoking, but I\'ve promised to quit by '
          'May."');
      expect(assembleBlanks('____ water is essential.', [none()]),
          'Water is essential.');
    });

    test('2, 3 and 4 blanks, in order', () {
      expect(assembleBlanks('__ and __.', [a('x'), a('y')]), 'x and y.');
      expect(assembleBlanks('__, __ and __.', [a('1'), a('2'), a('3')]),
          '1, 2 and 3.');
      expect(
          assembleBlanks(
              '__ __ __ __.', [a('one'), a('two'), a('three'), a('four')]),
          'one two three four.');
    });

    test('each box is trimmed; inner spaces stay', () {
      expect(
          assembleBlanks('I ____ it and ____.', [a('  have  done '), a('go ')]),
          'I have  done it and go.');
    });

    group('a no-article box', () {
      test('in the middle: the blank and one space go, no double space', () {
        expect(
            assembleBlanks(
                'I like ____ music and ____ cats.', [none(), none()]),
            'I like music and cats.');
      });

      test('at the end, before punctuation: the space before it goes', () {
        expect(assembleBlanks('She went to ____.', [none()]), 'She went to.');
        expect(assembleBlanks('It was ____, I think.', [none()]),
            'It was, I think.');
      });

      test('starting a sentence: the next word gets a capital', () {
        expect(assembleBlanks('I came. ____ dogs were barking.', [none()]),
            'I came. Dogs were barking.');
        expect(assembleBlanks('Really? ____ water is free!', [none()]),
            'Really? Water is free!');
        expect(assembleBlanks('He said: "____ water is free."', [none()]),
            'He said: "Water is free."');
        expect(assembleBlanks('He said: “____ water is free.”', [none()]),
            'He said: “Water is free.”');
        expect(assembleBlanks('Line one.\n____ milk is white.', [none()]),
            'Line one.\nMilk is white.');
      });

      test('not starting a sentence: no capital', () {
        expect(
            assembleBlanks('I drink ____ water.', [none()]), 'I drink water.');
        expect(assembleBlanks("I can't afford ____ cars.", [none()]),
            "I can't afford cars.");
      });

      test('a typed word at a sentence start keeps its case', () {
        expect(
            assembleBlanks('____ sun is hot.', [a('the')]), 'the sun is hot.');
      });
    });

    test('every box empty: an empty answer (a skipped item)', () {
      expect(assembleBlanks('__ and __.', [a(''), a('  ')]), '');
      expect(assembleBlanks('__ and __.', const []), '');
    });

    test('partly filled: an empty box keeps its blank', () {
      expect(assembleBlanks('I saw ____ cat and ____ dog.', [a('a'), a('')]),
          'I saw a cat and ____ dog.');
      expect(assembleBlanks('I saw ____ cat and ____ dog.', [none(), a('')]),
          'I saw cat and ____ dog.');
    });
  });

  group('BlankAnswer.isFilled', () {
    test('typed text or no article; an empty box is never no article', () {
      expect(a('a').isFilled, isTrue);
      expect(none().isFilled, isTrue);
      expect(a('').isFilled, isFalse);
      expect(a('   ').isFilled, isFalse);
    });
  });

  group('blankSourceText', () {
    test('the context when the blanks are there', () {
      const item = PracticeItem(
          id: 'q',
          type: PracticeItemType.fillInBlank,
          context: 'She is ____ engineer at ____ hospital.',
          instruction: 'Fill in the blanks with an article.');
      expect(blankSourceText(item), item.context);
    });

    test('the instruction when the blanks are there', () {
      const item = PracticeItem(
          id: 'q',
          type: PracticeItemType.fillInBlank,
          context: 'At the zoo.',
          instruction: 'I saw ____ owl and ____ eagle.');
      expect(blankSourceText(item), item.instruction);
    });

    test('both, joined as the full text, when both have blanks', () {
      const item = PracticeItem(
          id: 'q',
          type: PracticeItemType.fillInBlank,
          context: 'I saw ____ owl.',
          instruction: 'Then ____ eagle.');
      expect(blankSourceText(item), 'I saw ____ owl.\nThen ____ eagle.');
    });
  });
}
