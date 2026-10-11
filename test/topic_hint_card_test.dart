import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topic_hints.dart';
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
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:grammar_lens/widgets/topic_hint_card.dart';

/// The Daily Test's topic hint card (docs/question-screen-plan.md, item 2 and
/// B2): the owner's texts, the fit above the "Your answer" row with the
/// keyboard up, the reveal (drag, spring close, long-press), and that using
/// it changes nothing.

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

class _RecordingSink implements AnalyticsSink {
  final List<String> events = [];

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async =>
      events.add(name);

  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

const _longScene =
    'You are chatting with a new friend about your hobbies and free-time '
    'activities. You want to mention one thing you really enjoy doing and '
    'one thing you have recently decided to start doing, and you want both '
    'sentences to sound natural, connected and specific to your own life, '
    'not like a textbook example that anyone could have written at all.';

/// One question per topic, in [kTopics] order; the first is short.
DailyTestSet _set({bool longFirst = false}) => DailyTestSet(
      day: '2026-10-12',
      source: DailyTestSource.shared,
      questions: [
        for (final (i, topic) in kTopics.indexed)
          DailyTestQuestion(
            item: PracticeItem(
              id: 'q$i',
              type: PracticeItemType.fillInBlank,
              context: i == 0 && longFirst ? _longScene : null,
              instruction: 'I enjoy ____ in the morning.',
            ),
            topicId: topic.id.name,
            correctAnswer: 'swimming',
            commonWrongAnswers: const [],
          ),
      ],
    );

void _setView(WidgetTester tester, Size size,
    {double keyboard = 0, double top = 0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  tester.view.padding = FakeViewPadding(top: top * 3);
  addTearDown(tester.view.reset);
}

class _Daily {
  final List<Map<String, String>> finished = [];
  final _RecordingSink sink = _RecordingSink();
}

Future<_Daily> _pumpDaily(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  double top = 0,
  AppTextSize textSize = AppTextSize.medium,
  bool reduceMotion = false,
  bool longFirst = false,
}) async {
  _setView(tester, size, keyboard: keyboard, top: top);
  final daily = _Daily();
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light, textSize: textSize),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: DailyTestScreen(
      dailyTestService: DailyTestService(
          claudeService: _NoNetworkClaude(),
          storageService: _Storage(_set(longFirst: longFirst))),
      analyticsService: AnalyticsService(sink: daily.sink),
      onFinished: (_, answers) => daily.finished.add(answers),
      onExit: () {},
    ),
  ));
  await tester.pumpAndSettle();
  return daily;
}

Finder get _handle => find.byKey(TopicHintHandle.handleKey);
Finder get _card => find.byKey(TopicHintHandle.cardKey);
Finder get _cover => find.byKey(TopicHintHandle.coverKey);
Finder get _field => find.byKey(QuestionView.answerFieldKey);

/// The "Your answer" row: the row that holds the handle.
Rect _row(WidgetTester tester) => tester
    .getRect(find.ancestor(of: _handle, matching: find.byType(Row)).first);

/// How much of the card shows: 1 − the cover's share of its width.
double _revealed(WidgetTester tester) {
  if (_cover.evaluate().isEmpty) return 1;
  return 1 - tester.getSize(_cover).width / tester.getSize(_card).width;
}

Future<void> _focusAnswer(WidgetTester tester) async {
  await tester.tap(_field);
  await tester.pumpAndSettle();
}

Future<void> _skip(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
}

/// Holds the handle down long enough for a long-press.
Future<TestGesture> _press(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_handle));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  return gesture;
}

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('the texts', () {
    test('every topic has a card', () {
      expect(kTopicHints.keys.toSet(), TopicId.values.toSet());
    });

    test("are the owner's, verbatim (2026-10-12)", () {
      expect(kTopicHints, {
        TopicId.gerundVsInfinitive: [
          '+ -ing: enjoy, avoid, finish, keep',
          '+ to: want, decide, hope, plan',
          'Meaning changes: stop, remember, try',
          'After a preposition: always -ing',
        ],
        TopicId.modalVerbs: [
          'modal + base verb: no "to", no "-s"',
          'must: obligation · should: advice',
          'may / might / could: possibility',
          "mustn't ≠ don't have to",
        ],
        TopicId.modalPastForms: [
          'modal + have + past participle',
          "must / can't have: sure it did / didn't",
          'might / could have: maybe it did',
          "should have: right, but it didn't happen",
        ],
        TopicId.tenseSelection: [
          'Past simple: finished time (ago, in 2020)',
          'Present perfect: up to now (since, for, yet)',
          'Past perfect: before another past event',
          'Continuous: in progress at that moment',
        ],
        TopicId.articles: [
          'a / an: one of many, or first mention',
          'an before a vowel sound: an hour',
          'the: specific, known, or the only one',
          'No article: general plural or uncountable',
        ],
      });
    });
  });

  // The guard the owner asked for (2026-10-12): under the shortest possible
  // question (one line, no scene), with the keyboard up on a 375 × 667
  // phone (20 pt status bar, 260 pt keyboard), at Medium and Large, every
  // card fits above the "Your answer" row and below the status bar. A
  // longer text fails here.
  for (final size in [AppTextSize.medium, AppTextSize.large]) {
    testWidgets(
        'every card fits above the row under the shortest question, keyboard '
        'up, 375 × 667 (${size.name})', (tester) async {
      await _pumpDaily(tester,
          size: const Size(375, 667), keyboard: 260, top: 20, textSize: size);
      await _focusAnswer(tester);
      for (final topic in kTopics) {
        final gesture = await _press(tester);
        final card = tester.getRect(_card);
        final row = _row(tester);
        expect(
            card.bottom, lessThanOrEqualTo(row.top - TopicHintHandle.gap + 0.5),
            reason: '${topic.title}: ${card.height} pt tall, '
                '${row.top - TopicHintHandle.gap - 20 - TopicHintHandle.gap} '
                'pt of room above the row');
        expect(card.top, greaterThanOrEqualTo(20 + TopicHintHandle.gap - 0.5),
            reason: topic.title);
        await gesture.up();
        await tester.pumpAndSettle();
        if (topic != kTopics.last) await _skip(tester);
      }
      expect(tester.testTextInput.isVisible, isTrue);
    });
  }

  group('where it is offered', () {
    testWidgets('not on Practice', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: PracticeScreen(
          topic: topicById(TopicId.articles),
          practiceSet: const PracticeSet(topicId: 'articles', items: [
            PracticeItem(
                id: 'p',
                type: PracticeItemType.fillInBlank,
                instruction: 'I saw ____ owl.'),
          ]),
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(sink: _RecordingSink()),
          subscriptionService: SubscriptionService(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(_handle, findsNothing);
    });

    testWidgets('on the Daily Test: the handle, 44 × 44, and no card at rest',
        (tester) async {
      await _pumpDaily(tester);
      expect(_handle, findsOneWidget);
      expect(tester.getSize(_handle), const Size(44, 44));
      expect(_card, findsNothing);
    });

    testWidgets('the handle reads the whole card to VoiceOver', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDaily(tester);
      final label = tester.getSemantics(_handle).label;
      expect(label, contains('Gerund vs. Infinitive'));
      for (final point in kTopicHints[TopicId.gerundVsInfinitive]!) {
        expect(label, contains(point));
      }
      semantics.dispose();
    });
  });

  group('the reveal', () {
    testWidgets(
        'a sideways drag shows the card in proportion, either way, above the '
        'row; nothing moves', (tester) async {
      await _pumpDaily(tester);
      final rowBefore = _row(tester);
      final travel = rowBefore.width * TopicHintHandle.travelShare;
      final gesture = await tester.startGesture(tester.getCenter(_handle));
      // Past the touch slop, so the drag has started.
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      expect(_card, findsOneWidget);
      final start = _revealed(tester);
      await gesture.moveBy(Offset(-travel * 0.25, 0));
      await tester.pump();
      expect(_revealed(tester), moreOrLessEquals(start + 0.25, epsilon: 0.01));
      await gesture.moveBy(Offset(-travel * 0.25, 0));
      await tester.pump();
      expect(_revealed(tester), moreOrLessEquals(start + 0.5, epsilon: 0.01));
      // Back the other way and past the start: the distance counts, not the
      // direction.
      await gesture.moveBy(Offset(travel * (0.5 + start) + travel * 0.4, 0));
      await tester.pump();
      expect(_revealed(tester), moreOrLessEquals(0.4, epsilon: 0.02));
      await gesture.moveBy(Offset(travel, 0));
      await tester.pump();
      expect(_revealed(tester), 1);
      expect(_cover, findsNothing);
      // Above the row, and the row has not moved.
      expect(tester.getRect(_card).bottom,
          lessThanOrEqualTo(_row(tester).top - TopicHintHandle.gap + 0.5));
      expect(_row(tester), rowBefore);
      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets(
        'on release it springs closed: still there a frame later, '
        'gone when settled', (tester) async {
      await _pumpDaily(tester);
      final gesture = await tester.startGesture(tester.getCenter(_handle));
      await gesture.moveBy(const Offset(-30, 0));
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      final before = _revealed(tester);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(_card, findsOneWidget);
      expect(_revealed(tester), lessThan(before));
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets('under Reduce Motion it closes at once', (tester) async {
      await _pumpDaily(tester, reduceMotion: true);
      final gesture = await _press(tester);
      expect(_revealed(tester), 1);
      await gesture.up();
      await tester.pump();
      expect(_card, findsNothing);
    });

    testWidgets(
        'a long-press shows it whole while held, and closes it on '
        'release', (tester) async {
      await _pumpDaily(tester);
      final gesture = await _press(tester);
      expect(_card, findsOneWidget);
      expect(_revealed(tester), 1);
      await tester.pump(const Duration(seconds: 2));
      expect(_revealed(tester), 1, reason: 'stays while held');
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets("a vertical drag scrolls the question and shows no card",
        (tester) async {
      await _pumpDaily(tester,
          size: const Size(375, 667), keyboard: 260, longFirst: true);
      await _focusAnswer(tester);
      final scroll = tester
          .state<ScrollableState>(find.descendant(
              of: find.byKey(QuestionView.questionScrollKey),
              matching: find.byType(Scrollable)))
          .position;
      expect(scroll.maxScrollExtent, greaterThan(0));
      await tester.drag(
          find.byKey(QuestionView.questionScrollKey), const Offset(0, -60));
      await tester.pump();
      expect(scroll.pixels, greaterThan(0));
      expect(_card, findsNothing);
      // An upward flick that starts on the handle is not a reveal either.
      await tester.drag(_handle, const Offset(0, -80));
      await tester.pump();
      expect(_card, findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('changes nothing', () {
    testWidgets(
        'the keyboard stays up, the answer, its cursor and the question stay; '
        'no event is logged; Finish hands over the same answers',
        (tester) async {
      final daily = await _pumpDaily(tester, keyboard: 336);
      await _focusAnswer(tester);
      await tester.enterText(_field, 'swimming');
      await tester.pump();
      final controller = tester.widget<TextField>(_field).controller!;
      controller.selection = const TextSelection.collapsed(offset: 4);
      await tester.pump();
      final eventsBefore = List.of(daily.sink.events);

      // A tap on the handle does not close the keyboard.
      await tester.tap(_handle);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      // A drag and a long-press.
      final drag = await tester.startGesture(tester.getCenter(_handle));
      await drag.moveBy(const Offset(-30, 0));
      await drag.moveBy(const Offset(-200, 0));
      await tester.pump();
      expect(tester.testTextInput.isVisible, isTrue);
      await drag.up();
      await tester.pumpAndSettle();
      final press = await _press(tester);
      expect(tester.testTextInput.isVisible, isTrue);
      await press.up();
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isTrue);
      expect(FocusManager.instance.primaryFocus,
          tester.widget<TextField>(_field).focusNode);
      expect(controller.text, 'swimming');
      expect(controller.selection, const TextSelection.collapsed(offset: 4));
      expect(find.text('1 / 5'), findsOneWidget);
      expect(daily.sink.events, eventsBefore);
      expect(daily.finished, isEmpty);

      // Skip through the rest; Skip on the last question finishes.
      for (var i = 0; i < kTopics.length; i++) {
        await _skip(tester);
      }
      expect(daily.finished.single, {'q0': 'swimming'});
    });
  });

  group('when a card does not fit above the row', () {
    testWidgets(
        'the safety net: it reaches down over the row (320 × 568, Small, '
        'keyboard up: Gerund vs. Infinitive), the handle drawn on top',
        (tester) async {
      await _pumpDaily(tester,
          size: const Size(320, 568),
          keyboard: 260,
          top: 20,
          textSize: AppTextSize.small);
      await _focusAnswer(tester);
      final row = _row(tester);
      final handle = tester.getRect(_handle);
      final gesture = await _press(tester);
      final card = tester.getRect(_card);
      expect(card.bottom, greaterThan(row.top - TopicHintHandle.gap),
          reason: 'does not fit above the row');
      expect(card.bottom, moreOrLessEquals(row.bottom, epsilon: 0.5));
      // The handle is drawn again over the card, in the same place.
      final faces = find.byIcon(Icons.tips_and_updates_rounded);
      expect(faces, findsNWidgets(2));
      final face = tester.getRect(faces.last).center;
      expect(face.dx, moreOrLessEquals(handle.center.dx, epsilon: 0.5));
      expect(face.dy, moreOrLessEquals(handle.center.dy, epsilon: 0.5));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets(
        '320 × 568, Large, keyboard up: every card is whole on screen, '
        'reaching over the answer field and the Skip/Next bar if it must',
        (tester) async {
      await _pumpDaily(tester,
          size: const Size(320, 568),
          keyboard: 260,
          top: 20,
          textSize: AppTextSize.large);
      await _focusAnswer(tester);
      const keyboardTop = 568 - 260.0;
      for (final topic in kTopics) {
        final gesture = await _press(tester);
        final card = tester.getRect(_card);
        // Nothing of the card is clipped: its painted box is its whole box.
        expect(card.top, greaterThanOrEqualTo(20 + TopicHintHandle.gap - 0.5),
            reason: '${topic.title}: top cut off');
        expect(card.bottom,
            lessThanOrEqualTo(keyboardTop - TopicHintHandle.gap + 0.5),
            reason: '${topic.title}: under the keyboard');
        expect(find.text(topic.title), findsWidgets);
        expect(find.byIcon(Icons.tips_and_updates_rounded), findsNWidgets(2),
            reason: '${topic.title}: the handle on top');
        await gesture.up();
        await tester.pumpAndSettle();
        if (topic != kTopics.last) await _skip(tester);
      }
      expect(tester.takeException(), isNull);
    });
  });
}
