import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/feedback_text.dart';
import 'package:grammar_lens/widgets/mistake_breakdown.dart';

import 'support/rich_text_support.dart';

/// FeedbackText (1.4.0 B9, chips from B10): paragraphs, the closing rule,
/// quoted examples as translucent chips split per word in both themes, no
/// overflow at 320 pt and the Large text size on the real case 1 feedback,
/// and MistakeBreakdown rendering its explanation through it (the
/// weak-spot detail's "Saved feedback" panel, the other site, is covered in
/// that screen's test).
void main() {
  const four = "First, 'a' is wrong. Second, 'b' is wrong. Third, 'c' is "
      'wrong. In short, learn the pattern.';
  const three = "First, 'a' is wrong. Second, 'b' is wrong. Third, 'c' is "
      'wrong.';
  const case1 =
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

  Future<void> pump(
    WidgetTester tester,
    String text, {
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    double? width,
  }) async {
    final theme = buildAppTheme(brightness, textSize: textSize);
    Widget body = FeedbackText(text, style: theme.textTheme.bodyMedium);
    if (width != null) {
      // A narrow column; scrollable, since four Large paragraphs are taller
      // than the test viewport and only the width is under test.
      body = SingleChildScrollView(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: body),
        ),
      );
    }
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(body: body),
    ));
  }

  testWidgets('four sentences: four paragraphs, a rule above the last',
      (tester) async {
    await pump(tester, four);
    for (var i = 0; i < 4; i++) {
      expect(find.byKey(FeedbackText.paragraphKey(i)), findsOneWidget);
    }
    expect(find.byKey(FeedbackText.paragraphKey(4)), findsNothing);
    final rule =
        tester.widget<Divider>(find.byKey(FeedbackText.closingRuleKey));
    expect(
        rule.color, buildAppTheme(Brightness.light).colorScheme.outlineVariant);
    expect(rule.thickness, 1);
    // The rule sits between the third and the closing paragraph.
    final ruleY = tester.getTopLeft(find.byKey(FeedbackText.closingRuleKey)).dy;
    expect(
        ruleY,
        greaterThan(
            tester.getBottomLeft(find.byKey(FeedbackText.paragraphKey(2))).dy));
    expect(
        ruleY,
        lessThan(
            tester.getTopLeft(find.byKey(FeedbackText.paragraphKey(3))).dy));
  });

  testWidgets('three sentences: three paragraphs and no rule', (tester) async {
    await pump(tester, three);
    expect(find.byKey(FeedbackText.paragraphKey(2)), findsOneWidget);
    expect(find.byKey(FeedbackText.paragraphKey(3)), findsNothing);
    expect(find.byKey(FeedbackText.closingRuleKey), findsNothing);
  });

  testWidgets(
      'one or two sentences: a single paragraph whose plain text is the '
      'feedback; VoiceOver reads it as one sentence', (tester) async {
    const text = "After 'enjoy', the verb takes -ing. Say 'enjoy eating'.";
    await pump(tester, text);
    expect(findPlainText(text), findsOneWidget);
    expect(find.byKey(FeedbackText.paragraphKey(1)), findsNothing);
    expect(find.byKey(FeedbackText.closingRuleKey), findsNothing);
    expect(find.bySemanticsLabel(text), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'quoted examples are chips: translucent onSurface fill, radius 4, '
        'weight 600, the body colour ($brightness)', (tester) async {
      await pump(tester, four, brightness: brightness);
      final theme = buildAppTheme(brightness);
      final body = theme.textTheme.bodyMedium!;
      final marks = marksIn(tester, find.byKey(FeedbackText.paragraphKey(0)));
      expect(marks.map((m) => m.word), ["'a'"]);
      final chip = marks.single;
      expect(chip.fill, FeedbackText.chipFill(theme.colorScheme));
      expect(chip.fill.a,
          closeTo(brightness == Brightness.dark ? 0.14 : 0.12, 0.001));
      expect(chip.style?.fontWeight, FontWeight.w600);
      expect(chip.style?.color, body.color);
      expect(chip.radius, BorderRadius.circular(4));
      // The paragraph's plain text is intact around the chip.
      expect(
          plainTextOfWidget(
              tester.widget<Text>(find.byKey(FeedbackText.paragraphKey(0)))),
          "First, 'a' is wrong.");
    });
  }

  testWidgets(
      'a quoted phrase is one chip per word, the spaces inside the pieces, '
      'outer corners rounded, one continuous strip (B10.1)', (tester) async {
    await pump(tester, "Say 'decided to change' here.");
    final paragraph = find.byKey(FeedbackText.paragraphKey(0));
    final marks = marksIn(tester, paragraph);
    expect(marks.map((m) => m.word), ["'decided ", 'to ', "change'"]);
    expect(marks.first.radius,
        const BorderRadius.horizontal(left: Radius.circular(4)));
    expect(marks[1].radius, BorderRadius.zero);
    expect(marks.last.radius,
        const BorderRadius.horizontal(right: Radius.circular(4)));
    expectContinuousMark(tester, paragraph, ["'decided ", 'to ', "change'"]);
    expect(plainTextOfWidget(tester.widget<Text>(paragraph)),
        "Say 'decided to change' here.");
  });

  testWidgets(
      'the real case 1 feedback at 320 pt and the Large text size: no '
      'overflow, every chip word narrower than the column', (tester) async {
    await pump(tester, case1, textSize: AppTextSize.large, width: 320);
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 4; i++) {
      final paragraph = find.byKey(FeedbackText.paragraphKey(i));
      expect(tester.getSize(paragraph).width, lessThanOrEqualTo(320));
      for (final mark in marksIn(tester, paragraph)) {
        expect(mark.word.trim().contains(' '), isFalse,
            reason: 'one word per chip');
      }
    }
    // Eleven quoted examples, split into their words.
    final words = [
      for (var i = 0; i < 4; i++)
        ...marksIn(tester, find.byKey(FeedbackText.paragraphKey(i)))
            .map((m) => m.word),
    ];
    expect(words.first, "'to ");
    expect(words, contains("'decided "));
    expect(words, contains("change'"));
    expect(words.length, greaterThanOrEqualTo(11));
  });

  testWidgets('MistakeBreakdown renders its explanation through FeedbackText',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const Scaffold(
        body: MistakeBreakdown(
          prompt: 'p',
          userAnswer: 'a',
          correctedAnswer: 'b',
          explanation: four,
        ),
      ),
    ));
    expect(find.byType(FeedbackText), findsOneWidget);
    expect(find.byKey(FeedbackText.closingRuleKey), findsOneWidget);
  });
}
