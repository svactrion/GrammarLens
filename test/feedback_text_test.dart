import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/feedback_text.dart';
import 'package:grammar_lens/widgets/mistake_breakdown.dart';

/// FeedbackText (1.4.0 B9): paragraphs, the closing rule and weight-700
/// quoted examples in the surrounding colour; and that MistakeBreakdown
/// renders its explanation through it (the weak-spot detail's "Saved
/// feedback" panel, the other site, is covered in that screen's test).
void main() {
  const four = "First, 'a' is wrong. Second, 'b' is wrong. Third, 'c' is "
      'wrong. In short, learn the pattern.';
  const three = "First, 'a' is wrong. Second, 'b' is wrong. Third, 'c' is "
      'wrong.';

  Future<void> pump(WidgetTester tester, String text,
      {Brightness brightness = Brightness.light}) async {
    final theme = buildAppTheme(brightness);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: FeedbackText(text, style: theme.textTheme.bodyMedium),
      ),
    ));
  }

  /// The (text, weight, colour) of every span in paragraph [index].
  List<(String, FontWeight?, Color?)> spansOf(WidgetTester tester, int index) {
    final text =
        tester.widget<Text>(find.byKey(FeedbackText.paragraphKey(index)));
    final base = text.textSpan!.style;
    final out = <(String, FontWeight?, Color?)>[];
    text.textSpan!.visitChildren((span) {
      if (span is TextSpan && span.text != null) {
        out.add((
          span.text!,
          span.style?.fontWeight ?? base?.fontWeight,
          span.style?.color ?? base?.color,
        ));
      }
      return true;
    });
    return out;
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

  testWidgets('one or two sentences: a single paragraph, found as its text',
      (tester) async {
    await pump(
        tester, "After 'enjoy', the verb takes -ing. Say 'enjoy eating'.");
    expect(find.text("After 'enjoy', the verb takes -ing. Say 'enjoy eating'."),
        findsOneWidget);
    expect(find.byKey(FeedbackText.paragraphKey(1)), findsNothing);
    expect(find.byKey(FeedbackText.closingRuleKey), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'quoted examples are weight 700 in the surrounding colour '
        '($brightness)', (tester) async {
      await pump(tester, four, brightness: brightness);
      final body = buildAppTheme(brightness).textTheme.bodyMedium!;
      final spans = spansOf(tester, 0);
      expect(spans.map((s) => s.$1).join(), "First, 'a' is wrong.");
      final quoted = spans.singleWhere((s) => s.$1 == "'a'");
      expect(quoted.$2, FontWeight.w700);
      expect(quoted.$3, body.color);
      final plain = spans.firstWhere((s) => s.$1 == 'First, ');
      expect(plain.$2, body.fontWeight);
      expect(plain.$3, body.color);
    });
  }

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
