import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';
import 'package:grammar_lens/widgets/blank_colors.dart';
import 'package:grammar_lens/widgets/mistake_breakdown.dart';

import 'support/rich_text_support.dart';

/// Regression coverage for docs/design-audit.md, Batch 0 item 1: a skipped
/// question's correct answer used to render on the same green success
/// color as an actual correction, labeled "CORRECTED" — reading as if a
/// mistake had been made and fixed, on a question that was never
/// attempted. Fixed by deriving skippedness from the answer already being
/// empty (see mistake_breakdown.dart's own `isSkipped` comment) rather
/// than a caller-supplied flag.
void main() {
  Color? boxColor(WidgetTester tester, String label) {
    final container = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  Future<void> pump(
    WidgetTester tester, {
    required String userAnswer,
    required String correctedAnswer,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: MistakeBreakdown(
            prompt: 'She ___ to the store yesterday.',
            userAnswer: userAnswer,
            correctedAnswer: correctedAnswer,
            explanation: null,
          ),
        ),
      ),
    );
  }

  testWidgets(
      'a skipped question (empty answer) shows the correct answer in the '
      'neutral box, labeled CORRECT ANSWER — not CORRECTED', (tester) async {
    await pump(tester, userAnswer: '', correctedAnswer: 'went');

    expect(find.text('CORRECT ANSWER'), findsOneWidget);
    expect(find.text('CORRECTED'), findsNothing);
    // Neither the skipped answer nor a "YOU WROTE" box exist to show it in.
    expect(find.text('YOU WROTE'), findsNothing);

    final theme = buildAppTheme(Brightness.light);
    expect(boxColor(tester, 'CORRECT ANSWER'), theme.colorScheme.surface);
  });

  testWidgets(
      'a real wrong answer still shows the correction on the success '
      'color, labeled CORRECTED', (tester) async {
    await pump(tester, userAnswer: 'goed', correctedAnswer: 'went');

    expect(find.text('CORRECTED'), findsOneWidget);
    expect(find.text('CORRECT ANSWER'), findsNothing);
    expect(find.text('YOU WROTE'), findsOneWidget);

    final semantic =
        buildAppTheme(Brightness.light).extension<SemanticColors>()!;
    expect(boxColor(tester, 'CORRECTED'), semantic.correctBackground);
  });

  group('per-blank "YOU WROTE" rows (1.4.0 B8)', () {
    const prompt = 'We had ____ lunch at ____ small café near ____ station.';
    const answers = [
      BlankAnswer.noArticle(),
      BlankAnswer(' a '),
      BlankAnswer(''),
    ];

    Future<void> pumpBlanks(
      WidgetTester tester, {
      required List<BlankAnswer>? blankAnswers,
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          home: Scaffold(
            body: MistakeBreakdown(
              prompt: prompt,
              userAnswer: 'We had lunch at a small café near ____ station.',
              blankAnswers: blankAnswers,
              correctedAnswer: 'We had lunch at a small café near the station.',
              explanation: 'x',
            ),
          ),
        ),
      );
    }

    /// The decoration colours of the prompt's blanks, in order.
    List<Color> promptBlankColors(WidgetTester tester) {
      final colors = <Color>[];
      for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
        rich.text.visitChildren((span) {
          final style = span.style;
          if (style?.decoration == TextDecoration.underline &&
              style?.decorationColor != null) {
            colors.add(style!.decorationColor!);
          }
          return true;
        });
      }
      return colors;
    }

    Color rowBarColor(WidgetTester tester, int i) {
      final bar = tester.widget<Container>(find
          .descendant(
              of: find.byKey(MistakeBreakdown.blankRowKey(i)),
              matching: find.byType(Container))
          .first);
      return (bar.decoration as BoxDecoration).color!;
    }

    for (final brightness in Brightness.values) {
      testWidgets(
          'one row per blank in blank order, the bar in the blank\'s colour, '
          'the prompt\'s blanks in the same colours ($brightness)',
          (tester) async {
        await pumpBlanks(tester, blankAnswers: answers, brightness: brightness);
        final colors = blankColors(brightness);

        expect(find.text('YOU WROTE'), findsOneWidget);
        // The assembled sentence is not repeated.
        expect(find.text('We had lunch at a small café near ____ station.'),
            findsNothing);
        expect(find.text(MistakeBreakdown.noArticleLabel), findsOneWidget);
        expect(find.text('a'), findsOneWidget);
        expect(find.text(MistakeBreakdown.leftBlankLabel), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          expect(rowBarColor(tester, i), colors[i], reason: 'row $i');
        }
        expect(promptBlankColors(tester), colors.sublist(0, 3));
        expect(find.text('CORRECTED'), findsOneWidget);
      });
    }

    testWidgets('the row of a box left empty is muted; the others are not',
        (tester) async {
      await pumpBlanks(tester, blankAnswers: answers);
      final scheme = buildAppTheme(Brightness.light).colorScheme;
      Color? colorOf(String text) =>
          tester.widget<Text>(find.text(text)).style?.color;
      expect(colorOf(MistakeBreakdown.leftBlankLabel), scheme.onSurfaceVariant);
      expect(colorOf('a'), scheme.onSurface);
      expect(colorOf(MistakeBreakdown.noArticleLabel), scheme.onSurface);
    });

    testWidgets('VoiceOver reads each row as "Blank n: …"', (tester) async {
      await pumpBlanks(tester, blankAnswers: answers);
      expect(find.bySemanticsLabel('Blank 1: no article'), findsOneWidget);
      expect(find.bySemanticsLabel('Blank 2: a'), findsOneWidget);
      expect(find.bySemanticsLabel('Blank 3: left blank'), findsOneWidget);
    });

    testWidgets(
        'without a per-blank record (an old row), or with a single entry, '
        'the sentence shows as before and the prompt is plain', (tester) async {
      for (final blanks in [
        null,
        const [BlankAnswer('went')]
      ]) {
        await pumpBlanks(tester, blankAnswers: blanks);
        expect(find.text('We had lunch at a small café near ____ station.'),
            findsOneWidget);
        expect(find.byKey(MistakeBreakdown.blankRowKey(0)), findsNothing);
        expect(promptBlankColors(tester), isEmpty);
      }
    });
  });

  test('the "You wrote" pill fill (B10.2): the measured colours', () {
    final light = buildAppTheme(Brightness.light).extension<SemanticColors>()!;
    final dark = buildAppTheme(Brightness.dark).extension<SemanticColors>()!;
    expect(MistakeBreakdown.userMarkFill(light).toARGB32(), 0xFFE1C2C1);
    expect(MistakeBreakdown.userMarkFill(dark).toARGB32(), 0xFF563434);
  });

  group('word-level difference (1.4.0 B10)', () {
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

    Future<void> pumpCard(
      WidgetTester tester, {
      required String? prompt,
      required String userAnswer,
      required String correctedAnswer,
      List<BlankAnswer>? blankAnswers,
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MistakeBreakdown(
              prompt: prompt,
              userAnswer: userAnswer,
              blankAnswers: blankAnswers,
              correctedAnswer: correctedAnswer,
              explanation: 'x',
            ),
          ),
        ),
      ));
    }

    for (final brightness in Brightness.values) {
      testWidgets(
          'case 1 on an old record (no user_blanks): both boxes painted with '
          'the theme\'s colours, text intact ($brightness)', (tester) async {
        await pumpCard(tester,
            prompt: case1Prompt,
            userAnswer: case1User,
            correctedAnswer: case1Corrected,
            brightness: brightness);
        final semantic = buildAppTheme(brightness).extension<SemanticColors>()!;

        final user = marksIn(tester, find.byKey(MistakeBreakdown.userTextKey));
        // "to join" is one phrase: the space rides inside the first piece.
        expect(user.map((m) => m.word), ['changing', 'to ', 'join', 'staying']);
        for (final m in user) {
          expect(m.fill, MistakeBreakdown.userMarkFill(semantic));
          expect(m.style?.color, semantic.onIncorrectBackground);
          // B10.2: no underline; it collided with descenders.
          expect(m.style?.decoration, anyOf(isNull, TextDecoration.none));
        }
        final corrected =
            marksIn(tester, find.byKey(MistakeBreakdown.correctedTextKey));
        expect(corrected.map((m) => m.word),
            ['to ', 'change', 'joining', 'to ', 'stay']);
        for (final m in corrected) {
          expect(m.fill, semantic.onCorrectBackground);
          expect(m.style?.color, semantic.correctBackground);
        }
        // The phrases are continuous strips (B10.1): no gap between the
        // pieces, the underline running through the "You wrote" space.
        expectContinuousMark(
            tester, find.byKey(MistakeBreakdown.userTextKey), ['to ', 'join']);
        expectContinuousMark(tester,
            find.byKey(MistakeBreakdown.correctedTextKey), ['to ', 'change']);
        // B10.2: the gap inside a strip is one space of the pill's style.
        expectOneSpaceGap(tester, find.byKey(MistakeBreakdown.userTextKey),
            'to ', 'join', user[1].style!);
        expectOneSpaceGap(tester, find.byKey(MistakeBreakdown.correctedTextKey),
            'to ', 'change', corrected[0].style!);
        expect(
            plainTextOfWidget(
                textAt(tester, find.byKey(MistakeBreakdown.userTextKey))),
            case1User);
        expect(
            plainTextOfWidget(
                textAt(tester, find.byKey(MistakeBreakdown.correctedTextKey))),
            case1Corrected);
        expect(find.bySemanticsLabel(case1Corrected), findsOneWidget);
      });
    }

    testWidgets(
        'a new multi-blank record keeps B8\'s rows and paints only '
        '"Corrected"', (tester) async {
      await pumpCard(tester,
          prompt: case1Prompt,
          userAnswer: case1User,
          correctedAnswer: case1Corrected,
          blankAnswers: const [
            BlankAnswer('to procrastinate'),
            BlankAnswer('changing'),
            BlankAnswer('to join'),
            BlankAnswer('staying'),
          ]);
      expect(find.byKey(MistakeBreakdown.blankRowKey(3)), findsOneWidget);
      expect(find.byKey(MistakeBreakdown.userTextKey), findsNothing);
      expect(
          marksIn(tester, find.byKey(MistakeBreakdown.correctedTextKey))
              .map((m) => m.word),
          ['to ', 'change', 'joining', 'to ', 'stay']);
    });

    testWidgets(
        'the two-line stored prompt of the device\'s case 2 record paints '
        'only the learner\'s words (B10.1)', (tester) async {
      const prompt =
          'Choose the correct form — gerund or infinitive — for each gap.\n'
          "Complete these two sentences: 'My manager suggested ________ "
          "(hold) the meeting online rather than in person.' and 'The new "
          "intern agreed ________ (stay) late to finish the quarterly "
          "report.'";
      await pumpCard(tester,
          prompt: prompt,
          userAnswer:
              "Complete these two sentences: 'My manager suggested to hold "
              "(hold) the meeting online rather than in person.' and 'The "
              "new intern agreed staying (stay) late to finish the quarterly "
              "report.'",
          correctedAnswer:
              'My manager suggested holding the meeting online rather than '
              'in person. The new intern agreed to stay late to finish the '
              'quarterly report.');
      expect(
          marksIn(tester, find.byKey(MistakeBreakdown.userTextKey))
              .map((m) => m.word),
          ['to ', 'hold', 'staying']);
      expect(
          marksIn(tester, find.byKey(MistakeBreakdown.correctedTextKey))
              .map((m) => m.word),
          ['holding', 'to ', 'stay']);
    });

    testWidgets('a heavy rewrite renders plain, as before', (tester) async {
      const user = 'Yesterday I am going to the market and I buyed many '
          'fruits because they was cheap.';
      const corrected = 'Yesterday I went to the market and bought a lot of '
          'fruit because it was cheap.';
      await pumpCard(tester,
          prompt: 'Write a sentence about yesterday.',
          userAnswer: user,
          correctedAnswer: corrected);
      expect(find.text(user), findsOneWidget);
      expect(find.text(corrected), findsOneWidget);
      expect(
          marksIn(tester, find.byKey(MistakeBreakdown.userTextKey)), isEmpty);
    });

    testWidgets('one word against one word: both painted', (tester) async {
      await pumpCard(tester,
          prompt: 'She ___ to the store yesterday.',
          userAnswer: 'goed',
          correctedAnswer: 'went');
      expect(
          marksIn(tester, find.byKey(MistakeBreakdown.userTextKey))
              .map((m) => m.word),
          ['goed']);
      expect(
          marksIn(tester, find.byKey(MistakeBreakdown.correctedTextKey))
              .map((m) => m.word),
          ['went']);
    });

    testWidgets(
        'a skipped question (no answer) paints nothing in the '
        'neutral CORRECT ANSWER box', (tester) async {
      await pumpCard(tester,
          prompt: 'She ___ to the store yesterday.',
          userAnswer: '',
          correctedAnswer: 'went');
      expect(find.text('CORRECT ANSWER'), findsOneWidget);
      expect(find.text('went'), findsOneWidget);
    });
  });
}
