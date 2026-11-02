import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_length_picker.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/feedback_text.dart';
import 'package:grammar_lens/widgets/mistake_breakdown.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_score_bar.dart';
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:grammar_lens/widgets/topic_hint_card.dart';

/// 1.4.0 B3, the RTL preparation (docs/1.4.0-b3-batch0-report.md §3): under
/// a right-to-left interface (Arabic, from B5) the start-edge layouts
/// mirror, and the English content stays left to right. Driven by a
/// `Directionality` above the navigator, since no Arabic strings exist yet.
void main() {
  Future<void> pumpRtl(WidgetTester tester, Widget body,
      {TextDirection direction = TextDirection.rtl}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) =>
          Directionality(textDirection: direction, child: child!),
      home: Scaffold(body: body),
    ));
    await tester.pumpAndSettle();
  }

  TextDirection directionAt(WidgetTester tester, Finder finder) =>
      Directionality.of(tester.element(finder));

  group('the hint slider', () {
    final topic = topicById(TopicId.gerundVsInfinitive);
    Widget slider() => Padding(
          padding: const EdgeInsets.all(20),
          child: TopicHintSlider(topic: topic, points: kTopicHints[topic.id]!),
        );
    const knob = TopicHintSlider.knobKey;
    const track = TopicHintSlider.trackKey;

    testWidgets('the knob starts at the right end, its chevrons point left',
        (tester) async {
      await pumpRtl(tester, slider());
      expect(tester.getTopRight(find.byKey(knob)).dx,
          tester.getTopRight(find.byKey(track)).dx);
      expect(find.byIcon(Icons.keyboard_double_arrow_left_rounded),
          findsOneWidget);
      expect(
          find.byIcon(Icons.keyboard_double_arrow_right_rounded), findsNothing);
    });

    testWidgets('dragging left opens the card; dragging right does not',
        (tester) async {
      await pumpRtl(tester, slider());
      final travel =
          tester.getSize(find.byKey(track)).width - TopicHintSlider.trackHeight;

      var gesture =
          await tester.startGesture(tester.getCenter(find.byKey(knob)));
      await gesture.moveBy(const Offset(20, 0));
      await gesture.moveBy(Offset(travel, 0));
      await tester.pump();
      expect(find.byKey(TopicHintSlider.cardKey), findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();

      gesture = await tester.startGesture(tester.getCenter(find.byKey(knob)));
      await gesture.moveBy(const Offset(-20, 0));
      await gesture.moveBy(Offset(-travel, 0));
      await tester.pump();
      expect(find.byKey(TopicHintSlider.cardKey), findsOneWidget);
      expect(tester.getTopLeft(find.byKey(knob)).dx,
          closeTo(tester.getTopLeft(find.byKey(track)).dx, 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(TopicHintSlider.cardKey), findsNothing);
    });
  });

  testWidgets('the climb score bar fills from the right', (tester) async {
    final thresholds = {
      for (final tier in MedalTier.values)
        tier: MonthlyMedalRules.threshold(2026, 11, tier),
    };
    await pumpRtl(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 288,
            child: ClimbScoreBar(
              score: 100,
              maxScore: MonthlyMedalRules.maxScore(2026, 11),
              thresholds: thresholds,
            ),
          ),
        ));
    final bar = tester.getRect(find.byType(ClimbScoreBar));
    final fill = tester.getRect(find.descendant(
        of: find.byType(FractionallySizedBox),
        matching: find.byType(ColoredBox)));
    expect(fill.right, closeTo(bar.right - 16, 0.5));
    expect(fill.width, closeTo((288 - 32) * 100 / 300, 0.5));
    // Bronze, the lowest threshold, is the rightmost label.
    final bronze = tester.getCenter(find.text(MedalTier.bronze.label));
    final gold = tester.getCenter(find.text(MedalTier.gold.label));
    expect(bronze.dx, greaterThan(gold.dx));
  });

  testWidgets('the practice length labels follow the mirrored slider',
      (tester) async {
    await pumpRtl(
        tester,
        Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showPracticeLengthPicker(
                  context: context, initial: PracticeLength.standard),
              child: const Text('open'),
            ),
          ),
        ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    Offset label(String name) =>
        tester.getCenter(find.byKey(ValueKey('lengthLabel_$name')));
    final quick = label('quick');
    final standard = label('standard');
    final extended = label('extended');
    // "3" on the right, "10" on the left, "5" in the middle, each the same
    // distance from it: the LTR row mirrored about its centre.
    expect(quick.dx, greaterThan(standard.dx));
    expect(standard.dx, greaterThan(extended.dx));
    expect((quick.dx + extended.dx) / 2, closeTo(standard.dx, 0.5));
    // The mirrored Slider's middle stop is the selected one, under "5".
    expect(tester.getCenter(find.byType(Slider)).dx, closeTo(standard.dx, 0.5));
  });

  testWidgets('each length label is the LTR position reflected',
      (tester) async {
    Future<(Rect, Map<String, double>)> measure(TextDirection d) async {
      await pumpRtl(
          tester,
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showPracticeLengthPicker(
                    context: context, initial: PracticeLength.standard),
                child: const Text('open'),
              ),
            ),
          ),
          direction: d);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final slider = tester.getRect(find.byType(Slider));
      return (
        slider,
        {
          for (final l in PracticeLength.values)
            l.name: tester
                .getCenter(find.byKey(ValueKey('lengthLabel_${l.name}')))
                .dx,
        }
      );
    }

    final (ltrSlider, ltr) = await measure(TextDirection.ltr);
    final (rtlSlider, rtl) = await measure(TextDirection.rtl);
    for (final name in ltr.keys) {
      expect(rtlSlider.right - rtl[name]!,
          closeTo(ltr[name]! - ltrSlider.left, 0.5),
          reason: name);
    }
  });

  group('English content stays left to right', () {
    testWidgets('the question text and the answer field; not the header',
        (tester) async {
      const item = PracticeItem(
        id: 'q1',
        type: PracticeItemType.fillInBlank,
        instruction: 'She ____ to the store yesterday.',
      );
      await pumpRtl(
          tester,
          QuestionView(
            item: item,
            index: 0,
            total: 5,
            drafts: AnswerDrafts(const ['q1']),
            onChanged: (_) {},
            horizontalPadding: 20,
          ));
      expect(
          directionAt(tester, find.text(item.instruction)), TextDirection.ltr);
      expect(directionAt(tester, find.byKey(QuestionView.answerFieldKey)),
          TextDirection.ltr);
      expect(directionAt(tester, find.text('1 / 5')), TextDirection.rtl);
    });

    testWidgets('the mistake card\'s prompt, boxes and feedback; not labels',
        (tester) async {
      await pumpRtl(
          tester,
          const MistakeBreakdown(
            prompt: 'She ___ to the store yesterday.',
            userAnswer: 'goed',
            correctedAnswer: 'went',
            explanation: "'Go' is irregular: its past form is 'went'.",
          ));
      expect(directionAt(tester, find.text('She ___ to the store yesterday.')),
          TextDirection.ltr);
      expect(directionAt(tester, find.byKey(MistakeBreakdown.userTextKey)),
          TextDirection.ltr);
      expect(directionAt(tester, find.byKey(MistakeBreakdown.correctedTextKey)),
          TextDirection.ltr);
      expect(directionAt(tester, find.byType(FeedbackText).first),
          TextDirection.rtl);
      expect(directionAt(tester, find.byKey(FeedbackText.paragraphKey(0))),
          TextDirection.ltr);
      expect(directionAt(tester, find.text('YOU WROTE')), TextDirection.rtl);
      // Left-aligned: the prompt starts at the card's left edge.
      final prompt =
          tester.getRect(find.text('She ___ to the store yesterday.'));
      expect(prompt.left, closeTo(0, 0.5));
    });
  });

  testWidgets('nothing changes in LTR: the knob starts at the left end',
      (tester) async {
    final topic = topicById(TopicId.articles);
    await pumpRtl(
        tester,
        Padding(
          padding: const EdgeInsets.all(20),
          child: TopicHintSlider(topic: topic, points: kTopicHints[topic.id]!),
        ),
        direction: TextDirection.ltr);
    expect(tester.getTopLeft(find.byKey(TopicHintSlider.knobKey)).dx,
        tester.getTopLeft(find.byKey(TopicHintSlider.trackKey)).dx);
  });
}
