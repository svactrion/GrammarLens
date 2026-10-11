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
import 'package:grammar_lens/widgets/practice_step_footer.dart';
import 'package:grammar_lens/widgets/question_view.dart';
import 'package:grammar_lens/widgets/topic_hint_card.dart';

/// The Daily Test's topic hint slider and card (docs/question-screen-plan.md,
/// item 2, the B2 rework): the owner's texts; the slider between the
/// question card and "Your answer", left out with the keyboard up and below
/// 375 pt; the reveal (drag, spring back, long-press) that never moves the
/// question; the fit of the open card above the Skip/Next bar; and that
/// using it changes nothing.

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
    'not like a textbook example that anyone could have written at all. '
    'Think about the last month, what you did on most evenings, and what '
    'you would like to do differently from now on, and say it simply.';

/// The two question shapes of the fit check: the shortest possible (one
/// line, no scene) and a realistic one from the fallback pool.
enum _Shape { shortest, pool, long }

PracticeItem _item(int i, _Shape shape) => switch (shape) {
      _Shape.shortest => PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'I enjoy ____ in the morning.',
        ),
      _Shape.pool => PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          context: 'At the weekend market, Lena talks about her budget: "I '
              "can't afford ____ all my vegetables here, so I buy some at the "
              'supermarket."',
          instruction:
              'Fill in the blank with the correct form of the verb (buy).',
          hint: "Think about what comes after 'afford'.",
        ),
      _Shape.long => PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          context: _longScene,
          instruction: 'I enjoy ____ in the morning.',
        ),
    };

/// One question per topic, in [kTopics] order.
DailyTestSet _set(_Shape shape) => DailyTestSet(
      day: '2026-10-12',
      source: DailyTestSource.shared,
      questions: [
        for (final (i, topic) in kTopics.indexed)
          DailyTestQuestion(
            item: _item(i, shape),
            topicId: topic.id.name,
            correctAnswer: 'swimming',
            commonWrongAnswers: const [],
          ),
      ],
    );

void _setView(WidgetTester tester, Size size,
    {double keyboard = 0, double top = 0, double bottom = 0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
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
  double bottom = 0,
  AppTextSize textSize = AppTextSize.medium,
  bool reduceMotion = false,
  _Shape shape = _Shape.shortest,
}) async {
  _setView(tester, size, keyboard: keyboard, top: top, bottom: bottom);
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
          storageService: _Storage(_set(shape))),
      analyticsService: AnalyticsService(sink: daily.sink),
      onFinished: (_, answers) => daily.finished.add(answers),
      onExit: () {},
    ),
  ));
  await tester.pumpAndSettle();
  return daily;
}

Finder get _slider => find.byType(TopicHintSlider);
Finder get _knob => find.byKey(TopicHintSlider.knobKey);
Finder get _track => find.byKey(TopicHintSlider.trackKey);
Finder get _card => find.byKey(TopicHintSlider.cardKey);
Finder get _field => find.byKey(QuestionView.answerFieldKey);
Finder get _questionCard => find.byKey(QuestionView.questionCardKey);
Finder get _yourAnswer => find.text('Your answer');

/// The knob's travel: the track less the knob.
double _travel(WidgetTester tester) =>
    tester.getSize(_track).width - TopicHintSlider.trackHeight;

/// How far the knob is along the track, 0–1.
double _knobAt(WidgetTester tester) =>
    (tester.getTopLeft(_knob).dx - tester.getTopLeft(_track).dx) /
    _travel(tester);

/// How much of the card (and the gap above it) shows: 0 when closed.
double _shownHeight(WidgetTester tester) {
  if (_card.evaluate().isEmpty) return 0;
  return tester
      .getSize(find.ancestor(of: _card, matching: find.byType(ClipRect)).first)
      .height;
}

double _fullHeight(WidgetTester tester) =>
    tester.getSize(_card).height + TopicHintSlider.cardGap;

double _labelOpacity(WidgetTester tester) => tester
    .widget<Opacity>(find.ancestor(
        of: find.byKey(TopicHintSlider.labelKey),
        matching: find.byType(Opacity)))
    .opacity;

Future<void> _skip(WidgetTester tester) async {
  await tester.tap(find.text('Skip'));
  await tester.pumpAndSettle();
}

/// Holds the knob down long enough for a long-press.
Future<TestGesture> _press(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_knob));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
  return gesture;
}

/// Starts a drag on the knob, past the touch slop.
Future<TestGesture> _startDrag(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_knob));
  await gesture.moveBy(const Offset(30, 0));
  await tester.pump();
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

  group('the slider', () {
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
      expect(_slider, findsNothing);
    });

    for (final brightness in Brightness.values) {
      testWidgets(
          'on the Daily Test (${brightness.name}): a 48 pt full-width track '
          'between the question card and "Your answer", the knob at its left '
          'end, "Slide for a hint", brand colours, no card at rest',
          (tester) async {
        _setView(tester, const Size(390, 844));
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(brightness),
          home: DailyTestScreen(
            dailyTestService: DailyTestService(
                claudeService: _NoNetworkClaude(),
                storageService: _Storage(_set(_Shape.shortest))),
            analyticsService: AnalyticsService(sink: _RecordingSink()),
            onFinished: (_, __) {},
            onExit: () {},
          ),
        ));
        await tester.pumpAndSettle();
        final track = tester.getRect(_track);
        final question = tester.getRect(_questionCard);
        expect(track.height, TopicHintSlider.trackHeight);
        expect(track.width, question.width);
        expect(track.left, question.left);
        expect(track.top, greaterThan(question.bottom));
        expect(track.bottom, lessThan(tester.getRect(_yourAnswer).top));
        expect(tester.getTopLeft(_knob), track.topLeft);
        expect(find.text('Slide for a hint'), findsOneWidget);
        expect(find.byIcon(Icons.keyboard_double_arrow_right_rounded),
            findsOneWidget);
        expect(_card, findsNothing);

        final theme = buildAppTheme(brightness);
        final palette = theme.extension<AppPalette>()!;
        final trackFill = tester
            .widgetList<DecoratedBox>(find.descendant(
                of: _track, matching: find.byType(DecoratedBox)))
            .map((box) => (box.decoration as BoxDecoration).color)
            .toList();
        expect(trackFill.first, palette.warm);
        expect(trackFill, contains(theme.colorScheme.primary));
        final semantic = theme.extension<SemanticColors>()!;
        for (final color in trackFill) {
          expect(color, isNot(semantic.correctBackground));
          expect(color, isNot(semantic.incorrectBackground));
        }
      });
    }

    testWidgets('reads the whole card to VoiceOver', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpDaily(tester);
      final label = tester.getSemantics(_knob).label;
      expect(label, contains('Gerund vs. Infinitive'));
      for (final point in kTopicHints[TopicId.gerundVsInfinitive]!) {
        expect(label, contains(point));
      }
      semantics.dispose();
    });

    testWidgets(
        'is left out while the keyboard is up, and comes back closed when it '
        'goes down', (tester) async {
      await _pumpDaily(tester);
      // Open it, then let it close: it must come back closed.
      final gesture = await _startDrag(tester);
      await gesture.moveBy(Offset(_travel(tester), 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.tap(_field);
      await tester.pumpAndSettle();
      expect(_slider, findsNothing);

      FocusManager.instance.primaryFocus?.unfocus();
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(_slider, findsOneWidget);
      expect(_card, findsNothing);
      expect(_knobAt(tester), 0);
    });

    for (final width in [320.0, 360.0, 374.0]) {
      testWidgets('is left out on a ${width.toInt()} pt screen',
          (tester) async {
        await _pumpDaily(tester, size: Size(width, 700));
        expect(_slider, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('is there on a 375 pt screen', (tester) async {
      await _pumpDaily(tester, size: const Size(375, 667));
      expect(_slider, findsOneWidget);
    });
  });

  group('the reveal', () {
    testWidgets(
        'dragging the knob right opens the card below the track in '
        'proportion, the trail follows and the label fades; the question '
        'card never moves, "Your answer" is pushed down', (tester) async {
      await _pumpDaily(tester);
      final question = tester.getRect(_questionCard);
      final answerRow = tester.getRect(_yourAnswer).top;
      final travel = _travel(tester);
      final gesture = await _startDrag(tester);
      final start = _knobAt(tester);
      expect(start, greaterThanOrEqualTo(0));

      await gesture.moveBy(Offset(travel * 0.25, 0));
      await tester.pump();
      expect(_knobAt(tester), moreOrLessEquals(start + 0.25, epsilon: 0.01));
      final full = _fullHeight(tester);
      expect(_shownHeight(tester),
          moreOrLessEquals(full * (start + 0.25), epsilon: 0.5));
      expect(_labelOpacity(tester),
          moreOrLessEquals(1 - 2 * (start + 0.25), epsilon: 0.02));

      await gesture.moveBy(Offset(travel * 0.25, 0));
      await tester.pump();
      expect(_shownHeight(tester),
          moreOrLessEquals(full * (start + 0.5), epsilon: 0.5));
      expect(_labelOpacity(tester), 0);
      expect(tester.getRect(_questionCard), question);
      expect(tester.getRect(_yourAnswer).top,
          moreOrLessEquals(answerRow + _shownHeight(tester), epsilon: 0.5));

      // To the end of the track: fully open, and no further.
      await gesture.moveBy(Offset(travel, 0));
      await tester.pump();
      expect(_knobAt(tester), moreOrLessEquals(1, epsilon: 0.001));
      expect(_shownHeight(tester), moreOrLessEquals(full, epsilon: 0.5));
      expect(tester.getRect(_card).top,
          greaterThan(tester.getRect(_track).bottom));
      expect(tester.getRect(_questionCard), question);

      // Back left past the start: closed, no further.
      await gesture.moveBy(Offset(-travel * 3, 0));
      await tester.pump();
      expect(_knobAt(tester), 0);
      expect(_shownHeight(tester), 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'on release the knob springs back and the card collapses: still '
        'moving a frame later, closed within about 250 ms', (tester) async {
      await _pumpDaily(tester);
      final gesture = await _startDrag(tester);
      await gesture.moveBy(Offset(_travel(tester), 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final knob = _knobAt(tester);
      expect(knob, inExclusiveRange(0, 1));
      expect(_card, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_knobAt(tester), lessThan(0.02));
      await tester.pumpAndSettle();
      expect(_knobAt(tester), 0);
      expect(_card, findsNothing);
    });

    testWidgets('under Reduce Motion it closes at once', (tester) async {
      await _pumpDaily(tester, reduceMotion: true);
      final gesture = await _press(tester);
      expect(_shownHeight(tester),
          moreOrLessEquals(_fullHeight(tester), epsilon: 0.5));
      await gesture.up();
      await tester.pump();
      expect(_card, findsNothing);
      expect(_knobAt(tester), 0);
    });

    testWidgets(
        'a long-press on the knob shows the card whole while held, '
        'and closes it on release', (tester) async {
      await _pumpDaily(tester);
      final question = tester.getRect(_questionCard);
      final gesture = await _press(tester);
      expect(_shownHeight(tester),
          moreOrLessEquals(_fullHeight(tester), epsilon: 0.5));
      await tester.pump(const Duration(seconds: 2));
      expect(_shownHeight(tester),
          moreOrLessEquals(_fullHeight(tester), epsilon: 0.5),
          reason: 'stays while held');
      expect(tester.getRect(_questionCard), question);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_card, findsNothing);
    });

    testWidgets('a vertical drag scrolls the question and opens nothing',
        (tester) async {
      await _pumpDaily(tester,
          size: const Size(375, 667),
          textSize: AppTextSize.large,
          shape: _Shape.long);
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
      // An upward flick that starts on the knob opens nothing either.
      await tester.drag(_knob, const Offset(0, -80));
      await tester.pump();
      expect(_card, findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('with the keyboard', () {
    FocusNode answerFocus(WidgetTester tester) =>
        tester.widget<TextField>(_field).focusNode!;

    // The focus change lands, then the next frame starts the animation's
    // clock: times below count from there.
    Future<void> settleFocus(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
        'opening: the slider slides up under the question card while its '
        'slot closes and "Your answer" moves up with it; the question card '
        'never moves', (tester) async {
      await _pumpDaily(tester);
      final question = tester.getRect(_questionCard);
      final track = tester.getRect(_track);
      final row = tester.getRect(_yourAnswer).top;

      answerFocus(tester).requestFocus();
      await settleFocus(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getRect(_track).top;
      final earlyRow = tester.getRect(_yourAnswer).top;
      expect(early, lessThan(track.top));
      expect(earlyRow, lessThan(row));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getRect(_track).top;
      final midRow = tester.getRect(_yourAnswer).top;
      expect(mid, lessThan(early), reason: 'still moving up');
      expect(midRow, lessThan(earlyRow));
      expect(mid, greaterThan(track.top - TopicHintSlider.closedHeight));
      // Tucked under the card: its top is behind the card's bottom edge.
      expect(mid, lessThan(question.bottom));
      expect(tester.getRect(_questionCard), question);
      // "Your answer" moves with the track (within the ~2 pt the row's
      // "Review answer" control, shown once the answer has focus, adds).
      expect(row - midRow, moreOrLessEquals(track.top - mid, epsilon: 3));

      await tester.pump(const Duration(milliseconds: 140));
      expect(_slider, findsNothing, reason: 'done within 250 ms');
      expect(tester.getRect(_yourAnswer).top,
          moreOrLessEquals(row - TopicHintSlider.closedHeight, epsilon: 3),
          reason: 'up by the slot (and the ~2 pt of "Review answer")');
      expect(tester.getRect(_questionCard), question);
    });

    testWidgets(
        'closing: the slider slides back out from under the card, its slot '
        'grows back, and it comes back closed', (tester) async {
      await _pumpDaily(tester);
      final question = tester.getRect(_questionCard);
      final track = tester.getRect(_track);
      final row = tester.getRect(_yourAnswer).top;
      answerFocus(tester).requestFocus();
      await tester.pumpAndSettle();
      expect(_slider, findsNothing);

      answerFocus(tester).unfocus();
      await settleFocus(tester);
      await tester.pump(const Duration(milliseconds: 60));
      final early = tester.getRect(_track).top;
      expect(early, lessThan(track.top));
      expect(early, greaterThan(track.top - TopicHintSlider.closedHeight));
      await tester.pump(const Duration(milliseconds: 60));
      final mid = tester.getRect(_track).top;
      expect(mid, greaterThan(early), reason: 'moving down');
      expect(tester.getRect(_yourAnswer).top, lessThan(row));
      expect(tester.getRect(_questionCard), question);
      // Not touchable until it is all the way out.
      await tester.drag(_knob, const Offset(200, 0), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.getRect(_track), track);
      expect(tester.getRect(_yourAnswer).top, row);
      expect(tester.getRect(_questionCard), question);
      expect(_card, findsNothing);
      expect(_knobAt(tester), 0);
    });

    testWidgets('the slider is painted under the question card',
        (tester) async {
      await _pumpDaily(tester);
      final layout = tester.widget<CustomMultiChildLayout>(find
          .ancestor(
              of: _questionCard, matching: find.byType(CustomMultiChildLayout))
          .first);
      final ids = [for (final child in layout.children) (child as LayoutId).id];
      final hint = ids.indexWhere((id) => id.toString().endsWith('hint'));
      final question =
          ids.indexWhere((id) => id.toString().endsWith('question'));
      expect(hint, greaterThanOrEqualTo(0));
      expect(hint, lessThan(question));
    });

    testWidgets('under Reduce Motion it goes and comes back at once',
        (tester) async {
      await _pumpDaily(tester, reduceMotion: true);
      final track = tester.getRect(_track);
      answerFocus(tester).requestFocus();
      await settleFocus(tester);
      expect(_slider, findsNothing);
      answerFocus(tester).unfocus();
      await settleFocus(tester);
      expect(tester.getRect(_track), track);
      expect(_card, findsNothing);
    });

    testWidgets(
        'a knob held when the keyboard opens: the card closes at once, the '
        'slider tucks away, nothing is stuck, and it comes back closed',
        (tester) async {
      await _pumpDaily(tester);
      final gesture = await _press(tester);
      expect(_card, findsOneWidget);
      answerFocus(tester).requestFocus();
      await settleFocus(tester);
      expect(_card, findsNothing, reason: 'closed at once');
      await tester.pump(const Duration(milliseconds: 60));
      // The held finger moves on: nothing opens.
      await gesture.moveBy(const Offset(200, 0));
      await tester.pump();
      expect(_card, findsNothing);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(_slider, findsNothing);
      answerFocus(tester).unfocus();
      await tester.pumpAndSettle();
      expect(_slider, findsOneWidget);
      expect(_card, findsNothing);
      expect(_knobAt(tester), 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('changes nothing', () {
    testWidgets(
        'the answer and the question stay; no event is logged; the answers '
        'handed over at the end are the same', (tester) async {
      final daily = await _pumpDaily(tester);
      await tester.enterText(_field, 'swimming');
      await tester.pump();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      final eventsBefore = List.of(daily.sink.events);

      await tester.tap(_knob);
      await tester.pumpAndSettle();
      final drag = await _startDrag(tester);
      await drag.moveBy(Offset(_travel(tester), 0));
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      final press = await _press(tester);
      await press.up();
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(_field).controller!.text, 'swimming');
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

  // The fit check the owner asked for (2026-10-12): with the keyboard down,
  // on 375 pt and wider phones, at Medium and Large, under the shortest and
  // a realistic question, the fully open card is whole above the Skip/Next
  // bar and below the question card.
  const phones = [
    (size: Size(375, 667), top: 20.0, bottom: 0.0),
    (size: Size(390, 844), top: 47.0, bottom: 34.0),
    (size: Size(430, 932), top: 59.0, bottom: 34.0),
  ];
  for (final phone in phones) {
    for (final textSize in [AppTextSize.medium, AppTextSize.large]) {
      for (final shape in [_Shape.shortest, _Shape.pool]) {
        testWidgets(
            'fit: ${phone.size.width.toInt()} × ${phone.size.height.toInt()}, '
            '${textSize.name}, ${shape.name} question: every open card is '
            'whole above the Skip/Next bar', (tester) async {
          await _pumpDaily(tester,
              size: phone.size,
              top: phone.top,
              bottom: phone.bottom,
              textSize: textSize,
              shape: shape);
          for (final topic in kTopics) {
            final question = tester.getRect(_questionCard);
            final gesture = await _press(tester);
            final card = tester.getRect(_card);
            final footer = tester.getRect(find.byType(PracticeStepFooter));
            expect(_shownHeight(tester),
                moreOrLessEquals(_fullHeight(tester), epsilon: 0.5),
                reason: topic.title);
            expect(card.bottom, lessThanOrEqualTo(footer.top + 0.5),
                reason: '${topic.title}: ${card.bottom - footer.top} pt '
                    'under the Skip/Next bar');
            expect(card.top, greaterThan(question.bottom), reason: topic.title);
            expect(tester.getRect(_questionCard), question,
                reason: topic.title);
            await gesture.up();
            await tester.pumpAndSettle();
            if (topic != kTopics.last) await _skip(tester);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
