import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/answer_diff.dart';

/// The word-level difference between "You wrote" and "Corrected" (1.4.0
/// B10), on the two cases from the owner's device and the designed ones.
void main() {
  const case1User =
      "Complete the sentences with the correct gerund or infinitive form of "
      "the verbs in brackets: 'I tend to procrastinate (procrastinate) when "
      "the task feels overwhelming, but I have decided changing (change) my "
      "habits this semester. I have also considered to join (join) a study "
      "group, because working alone makes it hard staying (stay) motivated.'";
  const case1Corrected =
      'I tend to procrastinate when the task feels overwhelming, but I have '
      'decided to change my habits this semester. I have also considered '
      'joining a study group, because working alone makes it hard to stay '
      'motivated.';
  const case1Prompt =
      "Complete the sentences with the correct gerund or infinitive form of "
      "the verbs in brackets: 'I tend ____ (procrastinate) when the task "
      "feels overwhelming, but I have decided ____ (change) my habits this "
      "semester. I have also considered ____ (join) a study group, because "
      "working alone makes it hard ____ (stay) motivated.'";
  const case2User =
      "Complete these two sentences: 'My manager suggested to hold (hold) "
      "the meeting online rather than in person.' and 'The new intern agreed "
      "staying (stay) late to finish the quarterly report.'";
  const case2Corrected =
      'My manager suggested holding the meeting online rather than in '
      'person. The new intern agreed to stay late to finish the quarterly '
      'report.';
  const case2Prompt =
      "Complete these two sentences: 'My manager suggested ____ (hold) the "
      "meeting online rather than in person.' and 'The new intern agreed "
      "____ (stay) late to finish the quarterly report.'";

  group('tokens', () {
    test('splitToken keeps leading and trailing marks apart from the core', () {
      final t = splitToken("'overwhelming,");
      expect((t.lead, t.core, t.trail), ("'", 'overwhelming', ','));
      expect(splitToken("report.'").core, 'report');
      expect(splitToken('(change)').core, 'change');
      expect(splitToken("don't").core, "don't");
      expect(splitToken("'I").text, "'I");
    });

    test('compareKey straightens quotes and lowercases; a lone dash is empty',
        () {
      expect(compareKey('“Isn’t”'), "isn't");
      expect(compareKey('Overwhelming,'), 'overwhelming');
      expect(compareKey('—'), '');
    });
  });

  group('case 1 (four blanks)', () {
    final diff = diffAnswer(
        userAnswer: case1User,
        correctedAnswer: case1Corrected,
        prompt: case1Prompt);

    test('assembled; the three fixes painted on each side', () {
      expect(diff.assembled, isTrue);
      expect(diff.highlighted, isTrue);
      expect(diff.paintedUser, ['changing', 'to', 'join', 'staying']);
      expect(diff.paintedCorrected, ['to', 'change', 'joining', 'to', 'stay']);
    });

    test('"to procrastinate", the hints and the instruction prefix are plain',
        () {
      final painted = diff.user.where((t) => t.painted).map((t) => t.text);
      expect(painted, isNot(contains('to procrastinate')));
      expect(painted.where((t) => t.startsWith('(')), isEmpty);
      final prefix = diff.user.take(15);
      expect(prefix.any((t) => t.painted), isFalse);
      expect(prefix.last.text, 'brackets:');
    });

    test('the text is unchanged, token by token', () {
      expect(diff.user.map((t) => t.text).join(' '), case1User);
      expect(diff.corrected.map((t) => t.text).join(' '), case1Corrected);
    });

    test('the changed share is well under the guard', () {
      expect(diff.changedShare, lessThan(0.2));
    });
  });

  group('case 2 (two blanks)', () {
    test('the two fixes painted; the "and" between the sentences plain', () {
      final diff = diffAnswer(
          userAnswer: case2User,
          correctedAnswer: case2Corrected,
          prompt: case2Prompt);
      expect(diff.assembled, isTrue);
      expect(diff.paintedUser, ['to', 'hold', 'staying']);
      expect(diff.paintedCorrected, ['holding', 'to', 'stay']);
      expect(diff.user.singleWhere((t) => t.text == 'and').painted, isFalse);
    });

    test(
        'with the first box left blank: only the typed word is painted, '
        'the correction shows both fixes', () {
      final diff = diffAnswer(
          userAnswer: case2User.replaceFirst('to hold (hold)', '____ (hold)'),
          correctedAnswer: case2Corrected,
          prompt: case2Prompt);
      expect(diff.assembled, isTrue);
      expect(diff.paintedUser, ['staying']);
      expect(diff.paintedCorrected, ['holding', 'to', 'stay']);
    });
  });

  group('simple mode', () {
    test('a heavy rewrite (44 % changed) is not highlighted', () {
      final diff = diffAnswer(
          userAnswer: 'Yesterday I am going to the market and I buyed many '
              'fruits because they was cheap.',
          correctedAnswer: 'Yesterday I went to the market and bought a lot '
              'of fruit because it was cheap.',
          prompt: 'Write a sentence about yesterday using the past simple.');
      expect(diff.assembled, isFalse);
      expect(diff.changedShare, closeTo(0.4375, 0.001));
      expect(diff.highlighted, isFalse);
      expect(diff.user.any((t) => t.painted), isFalse);
      expect(diff.corrected.any((t) => t.painted), isFalse);
    });

    test('a mild rewrite is highlighted', () {
      final diff = diffAnswer(
          userAnswer: 'If I would have more time I will learn to play the '
              'piano.',
          correctedAnswer: 'If I had more time, I would learn to play the '
              'piano.',
          prompt: 'Write a second conditional sentence.');
      expect(diff.highlighted, isTrue);
      expect(diff.paintedUser, ['would', 'have', 'will']);
      expect(diff.paintedCorrected, ['had', 'would']);
    });

    test('one word against one word ("goed" / "went") is highlighted', () {
      final diff = diffAnswer(
          userAnswer: 'goed',
          correctedAnswer: 'went',
          prompt: 'She ___ to the store yesterday.');
      expect(diff.highlighted, isTrue);
      expect(diff.paintedUser, ['goed']);
      expect(diff.paintedCorrected, ['went']);
    });

    test('error correction: "speaks" / "speak"', () {
      final diff = diffAnswer(
          userAnswer: 'She can speaks three languages',
          correctedAnswer: 'She can speak three languages.',
          prompt: 'Find the mistake: She can speaks three languages.');
      expect(diff.assembled, isFalse);
      expect(diff.paintedUser, ['speaks']);
      expect(diff.paintedCorrected, ['speak']);
    });

    test('a single-box fill against a full corrected sentence stays plain', () {
      final diff = diffAnswer(
          userAnswer: 'goed',
          correctedAnswer: 'She went to the store yesterday.',
          prompt: 'She ___ to the store yesterday.');
      expect(diff.highlighted, isFalse);
    });

    test('identical texts apart from case and a final stop paint nothing', () {
      final diff = diffAnswer(
          userAnswer: 'she can speak three languages',
          correctedAnswer: 'She can speak three languages.');
      expect(diff.highlighted, isFalse);
    });

    test(
        'without a prompt, an answer 1.5 times its correction or longer '
        'stays plain (the length guard; case 1 is exactly 1.5)', () {
      final diff =
          diffAnswer(userAnswer: case1User, correctedAnswer: case1Corrected);
      expect(diff.assembled, isFalse);
      expect(diff.highlighted, isFalse);
    });

    test('an empty side paints nothing and does not throw', () {
      expect(diffAnswer(userAnswer: '', correctedAnswer: 'went').highlighted,
          isFalse);
      expect(diffAnswer(userAnswer: 'goed', correctedAnswer: '').highlighted,
          isFalse);
    });
  });

  group('longestCommonSubsequence', () {
    test('matches in order and never on an empty key', () {
      expect(longestCommonSubsequence(['a', 'b', 'c'], ['b', 'c', 'a']),
          [(1, 0), (2, 1)]);
      expect(longestCommonSubsequence(['', 'a'], ['', 'a']), [(1, 1)]);
    });

    test('two 60-word lists are cheap', () {
      final a = List.generate(60, (i) => 'w$i');
      final b = List.generate(60, (i) => i.isEven ? 'w$i' : 'x$i');
      final watch = Stopwatch()..start();
      final pairs = longestCommonSubsequence(a, b);
      watch.stop();
      expect(pairs, hasLength(30));
      expect(watch.elapsedMilliseconds, lessThan(50));
    });
  });
}
