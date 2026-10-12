import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:grammar_lens/widgets/topic_hint_card.dart';

/// Two polish items after the B3 device check: the articles boxes'
/// placeholder says what "—" does, and a tap on a blank in the question
/// puts the keyboard in its answer box (44 pt tap areas, overlaps split).

class _Storage extends StorageService {
  final DailyTestSet? set;
  _Storage([this.set]);

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => set;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => set;
}

class _NoNetworkClaude extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async =>
      null;
}

const _four = PracticeItem(
  id: 'four',
  type: PracticeItemType.fillInBlank,
  context: '____ sun was setting when ____ old man sat down on ____ bench '
      'near the river and opened ____ newspaper he had bought that morning.',
  instruction: 'Fill in each blank with a, an or the, or tap — for no '
      'article.',
);

const _two = PracticeItem(
  id: 'two',
  type: PracticeItemType.fillInBlank,
  instruction: 'I saw ____ owl and ____ eagle.',
);

const _one = PracticeItem(
  id: 'one',
  type: PracticeItemType.fillInBlank,
  context: 'Lena talks about her budget at the weekend market in town.',
  instruction: 'I can\'t afford ____ all my vegetables here, so I buy some '
      'at the supermarket every week.',
);

const _long = PracticeItem(
  id: 'long',
  type: PracticeItemType.fillInBlank,
  context: 'You are chatting with a new friend about your hobbies and '
      'free-time activities. You want to mention one thing you really enjoy '
      'doing and one thing you have recently decided to start doing, and '
      'you want both sentences to sound natural, connected and specific to '
      'your own life. Think about the last month, what you did on most '
      'evenings, and what you would like to do differently from now on. '
      'I enjoy ____ in the morning, and later ____ in the evening.',
  instruction: 'Fill in the blanks.',
);

const _rewrite = PracticeItem(
  id: 'rewrite',
  type: PracticeItemType.errorCorrection,
  context: 'She enjoy to swim __ every day.',
  instruction: 'Rewrite the sentence correctly.',
);

void _setView(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);
}

Future<void> _pumpPractice(
  WidgetTester tester, {
  required List<PracticeItem> items,
  TopicId topic = TopicId.articles,
  Size size = const Size(390, 844),
  double keyboard = 0,
  AppTextSize textSize = AppTextSize.medium,
}) async {
  _setView(tester, size, keyboard: keyboard);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light, textSize: textSize),
    home: PracticeScreen(
      topic: topicById(topic),
      practiceSet: PracticeSet(topicId: topic.name, items: items),
      claudeService: ClaudeService(),
      storageService: _Storage(),
      analyticsService: AnalyticsService(),
      subscriptionService: SubscriptionService(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Blank [blank]'s tap areas (one per line it is on).
Finder _target(int blank) => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('question_blank_target_${blank}_');
    });

Finder get _anyTarget => find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('question_blank_target_');
    });

Finder _box(int i) => find.byKey(QuestionView.blankBoxKey(i));
Finder get _single => find.byKey(QuestionView.answerFieldKey);

String? _hint(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).decoration!.hintText;

bool _focused(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).focusNode!.hasFocus;

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('the articles boxes\' placeholder', () {
    testWidgets('375 pt, Large: "Type, or tap — for no article"',
        (tester) async {
      await _pumpPractice(tester,
          items: const [_two],
          size: const Size(375, 667),
          textSize: AppTextSize.large);
      expect(_hint(tester, _box(0)), 'Type, or tap — for no article');
      expect(_hint(tester, _box(1)), 'Type, or tap — for no article');
    });

    testWidgets('320 pt, Medium: still the long text (it fits)',
        (tester) async {
      await _pumpPractice(tester,
          items: const [_two], size: const Size(320, 568));
      expect(_hint(tester, _box(0)), 'Type, or tap — for no article');
    });

    testWidgets(
        '320 pt, Large: "Type, or tap — for none" (the long one does not fit '
        'on one line), and the box keeps one line', (tester) async {
      await _pumpPractice(tester,
          items: const [_two],
          size: const Size(320, 568),
          textSize: AppTextSize.large);
      expect(_hint(tester, _box(0)), 'Type, or tap — for none');
      final theme =
          buildAppTheme(Brightness.light, textSize: AppTextSize.large);
      expect(
          tester.getSize(_box(0)).height,
          lessThanOrEqualTo(QuestionView.answerMinHeight(
                  theme, TextScaler.noScaling, PracticeItemType.fillInBlank) +
              0.5));
    });

    testWidgets('other topics\' boxes keep "Write your answer…"',
        (tester) async {
      await _pumpPractice(tester,
          items: const [_two], topic: TopicId.gerundVsInfinitive);
      expect(_hint(tester, _box(0)), 'Write your answer…');
    });

    testWidgets(
        'a one-blank articles question keeps its single field\'s '
        '"Write your answer…"', (tester) async {
      await _pumpPractice(tester, items: const [_one]);
      expect(_hint(tester, _single), 'Write your answer…');
    });
  });

  group('a tap on a blank', () {
    testWidgets(
        'puts the keyboard in that blank\'s box, each in turn, and the box '
        'scrolls into view (375 × 667, keyboard up)', (tester) async {
      await _pumpPractice(tester,
          items: const [_four],
          size: const Size(375, 667),
          keyboard: 260,
          textSize: AppTextSize.large);
      for (final blank in [3, 0, 2, 1]) {
        // The question scrolls in its card with the keyboard up: bring the
        // blank into view first, as a learner would.
        await tester.ensureVisible(_target(blank).first);
        await tester.pumpAndSettle();
        await tester.tap(_target(blank).first);
        await tester.pumpAndSettle();
        expect(_focused(tester, _box(blank)), isTrue, reason: 'blank $blank');
        expect(tester.testTextInput.isVisible, isTrue);
        final box = tester.getRect(_box(blank));
        final footer = tester.getRect(find.byType(PracticeStepFooter));
        expect(box.bottom, lessThanOrEqualTo(footer.top + 0.5),
            reason: 'box $blank in view');
      }
    });

    testWidgets(
        'each area is at least 44 pt tall and wide around its blank, and no '
        'two blanks\' areas overlap', (tester) async {
      await _pumpPractice(tester, items: const [_four]);
      final rects = <int, List<Rect>>{};
      for (var blank = 0; blank < 4; blank++) {
        rects[blank] = [
          for (final element in _target(blank).evaluate())
            tester.getRect(find.byWidget(element.widget)),
        ];
        expect(rects[blank], isNotEmpty, reason: 'blank $blank');
        for (final rect in rects[blank]!) {
          expect(rect.width, greaterThanOrEqualTo(44 - 0.5));
        }
      }
      for (var a = 0; a < 4; a++) {
        for (var b = a + 1; b < 4; b++) {
          for (final ra in rects[a]!) {
            for (final rb in rects[b]!) {
              final overlap = ra.intersect(rb);
              expect(overlap.width <= 0.5 || overlap.height <= 0.5, isTrue,
                  reason: 'blanks $a and $b');
            }
          }
        }
      }
    });

    testWidgets('one blank: a 44 pt area over the drawn blank, centred on it',
        (tester) async {
      await _pumpPractice(tester, items: const [_one]);
      final area = tester.getRect(_target(0));
      expect(area.height, moreOrLessEquals(44, epsilon: 0.5));
      expect(area.width, greaterThanOrEqualTo(44 - 0.5));
    });

    testWidgets('one blank on Practice: the single field', (tester) async {
      await _pumpPractice(tester, items: const [_one]);
      expect(_focused(tester, _single), isFalse);
      await tester.tap(_target(0));
      await tester.pumpAndSettle();
      expect(_focused(tester, _single), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets(
        'one blank on the Daily Test: the single field; the blank keeps its '
        'look (plain underscores, no colour)', (tester) async {
      _setView(tester, const Size(390, 844));
      final set = DailyTestSet(
        day: '2026-10-12',
        source: DailyTestSource.shared,
        questions: [
          DailyTestQuestion(
            item: _one,
            topicId: 'gerundVsInfinitive',
            correctAnswer: 'to buy',
            commonWrongAnswers: const [],
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestScreen(
          dailyTestService: DailyTestService(
              claudeService: _NoNetworkClaude(), storageService: _Storage(set)),
          analyticsService: AnalyticsService(),
          onFinished: (_, __) {},
          onExit: () {},
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text(_one.instruction), findsOneWidget,
          reason: 'a plain Text, no coloured spans');
      await tester.tap(_target(0));
      await tester.pumpAndSettle();
      expect(_focused(tester, _single), isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('not on error correction', (tester) async {
      await _pumpPractice(tester, items: const [_rewrite]);
      expect(_anyTarget, findsNothing);
    });
  });

  group('no regressions', () {
    testWidgets(
        'a tap in the question away from any blank still closes the keyboard',
        (tester) async {
      await _pumpPractice(tester, items: const [_one]);
      await tester.tap(_single);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      // The scene's first word, a line of its own above the blank's.
      final word =
          tester.getTopLeft(find.text(_one.context!)) + const Offset(8, 8);
      for (final element in _anyTarget.evaluate()) {
        expect(tester.getRect(find.byWidget(element.widget)).contains(word),
            isFalse);
      }
      await tester.tapAt(word);
      await tester.pumpAndSettle();
      expect(_focused(tester, _single), isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets(
        'a drag that starts on a blank scrolls the question and focuses '
        'nothing', (tester) async {
      await _pumpPractice(tester,
          items: const [_long],
          size: const Size(375, 667),
          keyboard: 260,
          textSize: AppTextSize.large);
      final scroll = tester
          .state<ScrollableState>(find.descendant(
              of: find.byKey(QuestionView.questionScrollKey),
              matching: find.byType(Scrollable)))
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      await tester.ensureVisible(_target(0).first);
      await tester.pumpAndSettle();
      final before = scroll.pixels;
      await tester.drag(_target(0).first, const Offset(0, -40));
      await tester.pumpAndSettle();
      expect(scroll.pixels, isNot(before));
      expect(_focused(tester, _box(0)), isFalse);
      expect(_focused(tester, _box(1)), isFalse);
    });

    testWidgets('the hint slider still opens (long-press) and closes',
        (tester) async {
      await _pumpPractice(tester, items: const [_four]);
      final knob = find.byKey(TopicHintSlider.knobKey);
      final gesture = await tester.startGesture(tester.getCenter(knob));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();
      expect(find.byKey(TopicHintSlider.cardKey), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.byKey(TopicHintSlider.cardKey), findsNothing);
      // And a blank is still tappable afterwards.
      await tester.tap(_target(1).first);
      await tester.pumpAndSettle();
      expect(_focused(tester, _box(1)), isTrue);
    });
  });
}
