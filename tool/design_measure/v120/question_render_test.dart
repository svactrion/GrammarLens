// Additional screens Batch 10: the real Question V2 screen with the real
// font, keyboard closed and open. The keyboard is a grey box of the given
// height drawn over the inset (the system keyboard is not part of the app).
// DESIGN_MEASURE_CASES picks cases by name (default: all).
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_question \
//     flutter test tool/design_measure/v120/question_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';
import 'package:grammar_lens/widgets/question_view.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

const _set = PracticeSet(topicId: 'gerundVsInfinitive', items: [
  PracticeItem(
    id: 'rewrite',
    type: PracticeItemType.errorCorrection,
    context: 'He said, “I won’t interrupt you again while you’re explaining '
        'your idea to the team.”',
    instruction: 'Rewrite using “promise” followed by an infinitive.',
  ),
  PracticeItem(
    id: 'long',
    type: PracticeItemType.sentenceWriting,
    context: 'You are chatting with a new friend about your hobbies and '
        'free-time activities. You want to mention one thing you really '
        'enjoy doing and one thing you have recently decided to start doing.',
    instruction: "Write two connected sentences: use a gerund after a verb "
        "like 'enjoy', 'love', or 'can’t stand' for the first, and an "
        "infinitive after a verb like 'decide', 'plan', or 'want' for the "
        'second.',
  ),
]);

typedef _Case = ({
  String name,
  double width,
  double height,
  double keyboard,
  AppTextSize size,
  int question,
  String answer,
});

const _answer = 'He promised not to interrupt me again while I was '
    'explaining my idea to the team.';

const List<_Case> _cases = [
  (
    name: '390_rewrite_closed',
    width: 390,
    height: 844,
    keyboard: 0,
    size: AppTextSize.medium,
    question: 0,
    answer: _answer,
  ),
  (
    name: '390_rewrite_open_291',
    width: 390,
    height: 844,
    keyboard: 291,
    size: AppTextSize.medium,
    question: 0,
    answer: _answer,
  ),
  (
    name: '390_rewrite_open',
    width: 390,
    height: 844,
    keyboard: 336,
    size: AppTextSize.medium,
    question: 0,
    answer: _answer,
  ),
  (
    name: '390_rewrite_open_long_answer',
    width: 390,
    height: 844,
    keyboard: 336,
    size: AppTextSize.medium,
    question: 0,
    answer: '$_answer He kept that promise for the rest of the meeting, '
        'and afterwards he thanked me for explaining it so clearly and '
        'asked for the slides.',
  ),
  (
    name: '375_rewrite_open',
    width: 375,
    height: 667,
    keyboard: 260,
    size: AppTextSize.medium,
    question: 0,
    answer: _answer,
  ),
  (
    name: '360_long_open',
    width: 360,
    height: 740,
    keyboard: 300,
    size: AppTextSize.medium,
    question: 1,
    answer: 'I enjoy hiking.',
  ),
  (
    name: '320_long_large_open',
    width: 320,
    height: 568,
    keyboard: 260,
    size: AppTextSize.large,
    question: 1,
    answer: 'I enjoy hiking.',
  ),
];

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  final picked = Platform.environment['DESIGN_MEASURE_CASES']?.split(',');
  for (final c in _cases) {
    if (picked != null && !picked.contains(c.name)) continue;
    for (final b in Brightness.values) {
      final file = 'question_${c.name}_${b.name}';
      testWidgets(file, (tester) async {
        tester.view.physicalSize = Size(c.width, c.height) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(
            top: (c.width < 360 ? 20 : 47) * 3,
            bottom: c.keyboard > 0 ? 0 : 34 * 3);
        tester.view.viewInsets = FakeViewPadding(bottom: c.keyboard * 3);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(b, textSize: c.size),
                home: PracticeScreen(
                  topic: const Topic(
                    id: TopicId.gerundVsInfinitive,
                    title: 'Gerund vs. Infinitive',
                    description: '',
                    icon: Icons.school,
                  ),
                  practiceSet: _set,
                  claudeService: ClaudeService(),
                  storageService: StorageService(),
                  analyticsService: AnalyticsService(),
                  subscriptionService: SubscriptionService(),
                ),
              ),
              if (c.keyboard > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: c.keyboard,
                  child: ColoredBox(
                    color: b == Brightness.dark
                        ? const Color(0xFF252527)
                        : const Color(0xFFD7D5D2),
                  ),
                ),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        for (var i = 0; i < c.question; i++) {
          await tester.tap(find.byKey(PracticeStepFooter.skipKey));
          await tester.pumpAndSettle();
        }
        final field = find.byKey(QuestionView.answerFieldKey);
        await tester.enterText(field, c.answer);
        await tester.pumpAndSettle();
        if (c.keyboard == 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final q = tester
            .state<ScrollableState>(find.descendant(
                of: find.byKey(QuestionView.questionScrollKey),
                matching: find.byType(Scrollable)))
            .position;
        // ignore: avoid_print
        print('$file: question hidden ${q.maxScrollExtent.toStringAsFixed(1)} '
            'of ${(q.maxScrollExtent + q.viewportDimension).toStringAsFixed(1)} pt; '
            'answer ${tester.getSize(field).height.toStringAsFixed(1)} pt');
        await tester.runAsync(() async {
          final img = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$file.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
