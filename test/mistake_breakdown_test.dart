import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/blank_assembly.dart';
import 'package:grammar_lens/widgets/blank_colors.dart';
import 'package:grammar_lens/widgets/mistake_breakdown.dart';

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
}
