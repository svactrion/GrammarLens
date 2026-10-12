import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
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

/// Two polish items after the B3 device check: the articles boxes' two-part
/// hint points at "—", and a tap on a blank in the question
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

  group('the articles boxes\' two-part hint', () {
    Finder inBox(int i, String text) =>
        find.descendant(of: _box(i), matching: find.text(text));

    // The variant per width and size (measured, plan §4): "none →" only at
    // 320 pt, Large; the left is never shortened.
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      for (final size in AppTextSize.values) {
        final right = width == 320 && size == AppTextSize.large
            ? 'none →'
            : 'no article →';
        testWidgets(
            '${width.toInt()} pt, ${size.name}: "Type an article…" and '
            '"$right" against the "—" button, on one line, apart',
            (tester) async {
          await _pumpPractice(tester,
              items: const [_two], size: Size(width, 700), textSize: size);
          for (var i = 0; i < 2; i++) {
            final left = inBox(i, 'Type an article…');
            final hint = inBox(i, right);
            expect(left, findsOneWidget, reason: 'box $i');
            expect(hint, findsOneWidget, reason: 'box $i');
            final l = tester.getRect(left);
            final r = tester.getRect(hint);
            final dash =
                tester.getRect(find.byKey(QuestionView.noArticleKey(i)));
            expect(r.right, lessThanOrEqualTo(dash.left + 0.5));
            expect(dash.left - r.right, lessThan(16), reason: 'right-aligned');
            expect(r.left - l.right, greaterThanOrEqualTo(8 - 0.5),
                reason: 'apart');
            expect(r.center.dy, moreOrLessEquals(l.center.dy, epsilon: 4),
                reason: 'one line');
            final paragraph = tester.renderObject<RenderParagraph>(left);
            expect(paragraph.didExceedMaxLines, isFalse, reason: 'not cut');
          }
          expect(find.textContaining('Type, or tap'), findsNothing);
        });
      }
    }

    /// Whether [text] shows in box [i]: there, and not faded out (a field
    /// fades its hint rather than removing it).
    bool shown(WidgetTester tester, int i, String text) {
      final found = inBox(i, text);
      if (found.evaluate().isEmpty) return false;
      return tester
          .widgetList<AnimatedOpacity>(
              find.ancestor(of: found, matching: find.byType(AnimatedOpacity)))
          .every((fade) => fade.opacity > 0);
    }

    testWidgets(
        'both go when the box has text or is set to "—", and come back when '
        'it is empty again', (tester) async {
      await _pumpPractice(tester, items: const [_two]);
      expect(shown(tester, 0, 'Type an article…'), isTrue);
      expect(shown(tester, 0, 'no article →'), isTrue);
      await tester.enterText(_box(0), 'an');
      await tester.pumpAndSettle();
      expect(shown(tester, 0, 'Type an article…'), isFalse);
      expect(shown(tester, 0, 'no article →'), isFalse);
      expect(shown(tester, 1, 'Type an article…'), isTrue,
          reason: 'the other box keeps its hint');
      await tester.enterText(_box(0), '');
      await tester.pumpAndSettle();
      expect(shown(tester, 0, 'Type an article…'), isTrue);
      expect(shown(tester, 0, 'no article →'), isTrue);

      await tester.tap(find.byKey(QuestionView.noArticleKey(0)));
      await tester.pumpAndSettle();
      expect(shown(tester, 0, 'Type an article…'), isFalse);
      expect(shown(tester, 0, 'no article →'), isFalse);
      expect(shown(tester, 0, '— no article'), isTrue);
      await tester.tap(find.byKey(QuestionView.noArticleKey(0)));
      await tester.pumpAndSettle();
      expect(shown(tester, 0, 'Type an article…'), isTrue);
      expect(shown(tester, 0, 'no article →'), isTrue);
    });

    testWidgets('other topics\' boxes keep "Write your answer…"',
        (tester) async {
      await _pumpPractice(tester,
          items: const [_two], topic: TopicId.gerundVsInfinitive);
      expect(_hint(tester, _box(0)), 'Write your answer…');
      expect(find.text('Type an article…'), findsNothing);
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
