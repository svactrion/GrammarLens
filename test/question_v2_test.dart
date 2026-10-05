import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
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
import 'package:grammar_lens/widgets/question_app_bar.dart';
import 'package:grammar_lens/widgets/question_view.dart';

/// Question V2 (docs/design/1.2.0-additional, brief §5 and the acceptance
/// checklist's "Soru V2" items): the multiline answer, the question-first
/// layout with the keyboard open, drafts kept per question, and the rules
/// that must not change (no extra request, no double submission).

/// Counts scoring calls; each one waits on [pending] until the test settles it.
class _ScoringClaude extends ClaudeService {
  final List<Map<String, String>> calls = [];
  Completer<ScoringResult>? pending;

  @override
  Future<ScoringResult> scoreAnswers({
    required String deviceId,
    required PracticeSet practiceSet,
    required Map<String, String> answers,
  }) {
    calls.add(Map.of(answers));
    pending = Completer<ScoringResult>();
    return pending!.future;
  }
}

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

/// Counts reads of the shared set: the Daily Test reads once, on open.
class _ReadCountingClaude extends ClaudeService {
  int reads = 0;

  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async {
    reads++;
    return null;
  }
}

const _topic = Topic(
  id: TopicId.gerundVsInfinitive,
  title: 'Gerund vs. Infinitive',
  description: 'enjoy doing / decide to do',
  icon: Icons.school,
);

const _longContext =
    'You are chatting with a new friend about your hobbies and free-time '
    'activities. You want to mention one thing you really enjoy doing and '
    'one thing you have recently decided to start doing, and you want both '
    'sentences to sound natural, connected and specific to your own life, '
    'not like a textbook example that anyone could have written.';

const _practiceSet = PracticeSet(
  topicId: 'gerundVsInfinitive',
  items: [
    PracticeItem(
      id: 'blank',
      type: PracticeItemType.fillInBlank,
      instruction: 'He kept ________ (interrupt) me while I was talking.',
    ),
    PracticeItem(
      id: 'rewrite',
      type: PracticeItemType.errorCorrection,
      context: 'He promised to not interrupting me again while I explain '
          'my idea to the team.',
      instruction: 'Find the mistake and rewrite the full corrected sentence.',
    ),
    PracticeItem(
      id: 'sentence',
      type: PracticeItemType.sentenceWriting,
      context: _longContext,
      instruction: "Write two connected sentences: a gerund after 'enjoy', "
          "then an infinitive after 'decide'.",
      hint: 'Example verbs: enjoy, love, decide, plan.',
    ),
  ],
);

const _longAnswer =
    'He promised not to interrupt me again while I was explaining my idea '
    'to the team, and he kept that promise for the rest of the meeting.';

DailyTestSet _dailySet() => DailyTestSet(
      day: '2026-10-05',
      source: DailyTestSource.shared,
      questions: [
        for (final item in _practiceSet.items.take(2))
          DailyTestQuestion(
            item: item,
            topicId: 'gerundVsInfinitive',
            correctAnswer: 'interrupting',
            commonWrongAnswers: const [],
          ),
      ],
    );

void _setView(WidgetTester tester, Size size, {double keyboard = 0}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard * 3);
  addTearDown(tester.view.reset);
}

Future<_ScoringClaude> _pumpPractice(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double keyboard = 0,
  Brightness brightness = Brightness.light,
  AppTextSize textSize = AppTextSize.medium,
}) async {
  _setView(tester, size, keyboard: keyboard);
  final claude = _ScoringClaude();
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(brightness, textSize: textSize),
    home: PracticeScreen(
      topic: _topic,
      practiceSet: _practiceSet,
      claudeService: claude,
      storageService: _Storage(),
      analyticsService: AnalyticsService(),
      subscriptionService: SubscriptionService(),
    ),
  ));
  await tester.pumpAndSettle();
  return claude;
}

Finder get _field => find.byKey(QuestionView.answerFieldKey);
Finder get _primary => find.byKey(PracticeStepFooter.primaryKey);
Finder get _skip => find.byKey(PracticeStepFooter.skipKey);

TextField _textField(WidgetTester tester) => tester.widget<TextField>(_field);

TextEditingController _controller(WidgetTester tester) =>
    _textField(tester).controller!;

ScrollPosition _answerScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
        find.descendant(of: _field, matching: find.byType(Scrollable)).first)
    .position;

ScrollPosition _questionScroll(WidgetTester tester) => tester
    .state<ScrollableState>(find.descendant(
        of: find.byKey(QuestionView.questionScrollKey),
        matching: find.byType(Scrollable)))
    .position;

bool _primaryEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_primary).onPressed != null;

Future<void> _next(WidgetTester tester) async {
  // The frame after typing enables Next.
  await tester.pump();
  await tester.tap(_primary);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) async {
  await tester.tap(find.byKey(QuestionHeader.backKey));
  await tester.pumpAndSettle();
}

Future<void> _unfocus(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
}

void main() {
  // The real font: with the test font every glyph is a square and the
  // question/answer measurements would mean nothing.
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('the answer field', () {
    testWidgets(
        'is multiline for every type: Return makes a new line, no single '
        'line, fill in the blank starts at 1 line, the others at 2',
        (tester) async {
      await _pumpPractice(tester);
      for (final item in _practiceSet.items) {
        final field = _textField(tester);
        expect(field.keyboardType, TextInputType.multiline, reason: item.id);
        expect(field.textInputAction, TextInputAction.newline);
        expect(field.maxLines, isNull);
        expect(
            field.minLines, item.type == PracticeItemType.fillInBlank ? 1 : 2);
        if (item == _practiceSet.items.last) break;
        await tester.tap(_skip);
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
        'sentence answers start with a capital, a blank does not; the '
        'keyboard still corrects nothing (O4)', (tester) async {
      await _pumpPractice(tester);
      for (final item in _practiceSet.items) {
        final field = _textField(tester);
        expect(
            field.textCapitalization,
            item.type == PracticeItemType.fillInBlank
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            reason: item.id);
        expect(field.autocorrect, isFalse);
        expect(field.enableSuggestions, isFalse);
        expect(field.smartQuotesType, SmartQuotesType.disabled);
        expect(field.smartDashesType, SmartDashesType.disabled);
        if (item == _practiceSet.items.last) break;
        await tester.tap(_skip);
        await tester.pumpAndSettle();
      }
    });

    testWidgets(
        'a long answer wraps onto more lines and never scrolls sideways',
        (tester) async {
      await _pumpPractice(tester);
      final oneLine = tester.getSize(_field).height;
      await tester.enterText(_field, _longAnswer);
      await tester.pumpAndSettle();

      expect(tester.getSize(_field).height, greaterThan(oneLine + 40),
          reason: 'the text wrapped onto at least three lines');
      final scroll = _answerScroll(tester);
      expect(scroll.axis, Axis.vertical);
      expect(scroll.maxScrollExtent, 0, reason: 'all of it is in view');
      // No horizontal scrollable anywhere in the field.
      for (final s in tester.stateList<ScrollableState>(
          find.descendant(of: _field, matching: find.byType(Scrollable)))) {
        expect(s.position.axis, Axis.vertical);
      }
    });

    testWidgets(
        'grows as lines are added, shrinks when they are deleted, and past '
        'the space left scrolls inside itself; the question and the actions '
        'stay where they are', (tester) async {
      await _pumpPractice(tester, keyboard: 300);
      await tester.tap(_field);
      await tester.pumpAndSettle();

      final empty = tester.getSize(_field).height;
      final questionRect =
          tester.getRect(find.byKey(QuestionView.questionCardKey));
      final primaryRect = tester.getRect(_primary);

      await tester.enterText(_field, 'one\ntwo\nthree\nfour');
      await tester.pumpAndSettle();
      final four = tester.getSize(_field).height;
      expect(four, greaterThan(empty));

      await tester.enterText(
          _field, List.generate(40, (i) => 'line $i').join('\n'));
      await tester.pumpAndSettle();
      final full = tester.getRect(_field);
      expect(full.height, greaterThan(four));
      expect(full.bottom, lessThanOrEqualTo(tester.getRect(_primary).top),
          reason: 'the field stops above the actions');
      expect(_answerScroll(tester).maxScrollExtent, greaterThan(0),
          reason: 'the rest scrolls inside the field');
      expect(tester.getRect(find.byKey(QuestionView.questionCardKey)),
          questionRect);
      expect(tester.getRect(_primary), primaryRect);

      await tester.enterText(_field, '');
      await tester.pumpAndSettle();
      expect(tester.getSize(_field).height, empty);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'the Return action adds no submission: the question stays, and a '
        'typed line break stays in the answer', (tester) async {
      await _pumpPractice(tester);
      await tester.tap(_field);
      await tester.enterText(_field, 'line one\nline two');
      await tester.testTextInput.receiveAction(TextInputAction.newline);
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(_controller(tester).text, 'line one\nline two');
    });

    testWidgets(
        'an empty or whitespace-only answer keeps Next disabled; Skip stays '
        'available', (tester) async {
      await _pumpPractice(tester);
      expect(_primaryEnabled(tester), isFalse);
      await tester.enterText(_field, '   \n  ');
      await tester.pump();
      expect(_primaryEnabled(tester), isFalse);
      expect(tester.widget<TextButton>(_skip).onPressed, isNotNull);
      await tester.enterText(_field, 'interrupting');
      await tester.pump();
      expect(_primaryEnabled(tester), isTrue);
    });

    testWidgets(
        'emoji and line breaks are kept exactly and reach scoring as typed',
        (tester) async {
      final claude = await _pumpPractice(tester);
      const answer = 'I enjoy hiking 🥾\nand I decided to learn 🎸';
      await tester.enterText(_field, 'interrupting 👍');
      await _next(tester);
      await tester.enterText(_field, answer);
      await _next(tester);
      await tester.enterText(_field, answer);
      await tester.pump();
      expect(_primaryEnabled(tester), isTrue);
      await tester.tap(_primary);
      await tester.pump();

      expect(claude.calls.single['blank'], 'interrupting 👍');
      expect(claude.calls.single['sentence'], answer);
      claude.pending!.completeError(Exception('offline'));
      await tester.pumpAndSettle();
    });

    testWidgets(
        'Topic Practice: at most 2,000 characters, the count only past 1,800',
        (tester) async {
      await _pumpPractice(tester);
      expect(_textField(tester).maxLength, 2000);
      await tester.enterText(_field, 'a' * 1800);
      await tester.pump();
      expect(find.text('1800 / 2000'), findsNothing);
      await tester.enterText(_field, 'a' * 1801);
      await tester.pump();
      expect(find.text('1801 / 2000'), findsOneWidget);
      await tester.enterText(_field, 'a' * 2100);
      await tester.pump();
      expect(_controller(tester).text.length, 2000);
    });
  });

  group('drafts', () {
    testWidgets(
        'Next → Back → Next keeps every answer, its selection and the '
        "answer field's scroll position, per question", (tester) async {
      await _pumpPractice(tester);
      await tester.enterText(_field, 'interrupting');
      _controller(tester).selection =
          const TextSelection(baseOffset: 2, extentOffset: 7);
      await _unfocus(tester);
      await _next(tester);

      final lines = List.generate(30, (i) => 'line $i').join('\n');
      await tester.enterText(_field, lines);
      await tester.pumpAndSettle();
      await _unfocus(tester);
      final scroll = _answerScroll(tester);
      expect(scroll.maxScrollExtent, greaterThan(60));
      scroll.jumpTo(60);
      await tester.pump();
      await _next(tester);
      await tester.enterText(_field, 'third');
      await _unfocus(tester);

      await _back(tester);
      expect(_controller(tester).text, lines);
      expect(_answerScroll(tester).pixels, 60);
      await _back(tester);
      expect(_controller(tester).text, 'interrupting');
      expect(_controller(tester).selection,
          const TextSelection(baseOffset: 2, extentOffset: 7));
      expect(_answerScroll(tester).pixels, 0);

      await _next(tester);
      expect(_controller(tester).text, lines);
      expect(_answerScroll(tester).pixels, 60);
      await _next(tester);
      expect(_controller(tester).text, 'third');
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets(
        'Back is disabled on the first question and never leaves the session',
        (tester) async {
      await _pumpPractice(tester);
      final back = find.descendant(
          of: find.byKey(QuestionHeader.backKey),
          matching: find.byType(IconButton));
      expect(tester.widget<IconButton>(back).onPressed, isNull);
      await tester.tap(back, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(find.text('Leave practice?'), findsNothing);

      await tester.tap(_skip);
      await tester.pumpAndSettle();
      expect(tester.widget<IconButton>(back).onPressed, isNotNull);
    });

    testWidgets(
        'moving between questions, focusing and closing the keyboard make no '
        'scoring request', (tester) async {
      final claude = await _pumpPractice(tester);
      await tester.tap(_field);
      await tester.enterText(_field, 'interrupting');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(QuestionView.keyboardControlKey));
      await tester.pumpAndSettle();
      await _next(tester);
      await _back(tester);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tester.tap(_field);
      await tester.pumpAndSettle();
      await _unfocus(tester);

      expect(claude.calls, isEmpty);
    });
  });

  group('the keyboard', () {
    testWidgets(
        '"Review answer" closes the keyboard and keeps the answer; it is '
        'shown only while typing', (tester) async {
      await _pumpPractice(tester, keyboard: 336);
      expect(find.byKey(QuestionView.keyboardControlKey), findsNothing);
      await tester.tap(_field);
      await tester.enterText(_field, 'interrupting');
      await tester.pumpAndSettle();
      expect(find.text('Review answer'), findsOneWidget);

      await tester.tap(find.byKey(QuestionView.keyboardControlKey));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(_controller(tester).text, 'interrupting');
      expect(find.byKey(QuestionView.keyboardControlKey), findsNothing);
    });

    testWidgets(
        'a short question and its instruction are whole with the keyboard '
        'open (390 × 844, a 336 pt keyboard)', (tester) async {
      await _pumpPractice(tester, keyboard: 336);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tester.tap(_field);
      await tester.pumpAndSettle();

      expect(_questionScroll(tester).maxScrollExtent, 0);
      expect(find.byKey(QuestionView.moreBelowKey), findsNothing);
      expect(find.text('Review answer'), findsOneWidget);
    });

    testWidgets(
        'a long question on a small screen at Large text scrolls in its card, '
        'shows there is more, and offers "Read full question", which closes '
        'the keyboard', (tester) async {
      await _pumpPractice(tester,
          size: const Size(320, 568),
          keyboard: 260,
          textSize: AppTextSize.large);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tester.tap(_skip);
      await tester.pumpAndSettle(); // the long sentence-writing question
      await tester.tap(_field);
      await tester.pumpAndSettle();

      expect(_questionScroll(tester).maxScrollExtent, greaterThan(0));
      expect(find.byKey(QuestionView.moreBelowKey), findsOneWidget);
      expect(find.text('Read full question'), findsOneWidget);
      // The text is the item's own, not shortened.
      final context = tester.widget<Text>(find.text(_longContext));
      expect(context.maxLines, isNull);
      expect(context.overflow, isNull);

      await tester.tap(find.text('Read full question'));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isFalse);
      expect(tester.takeException(), isNull);
    });

    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
            '$width pt, Large text, ${brightness.name}, keyboard open: Skip '
            'and Next above the keyboard, no overflow', (tester) async {
          final height = width < 360 ? 568.0 : 844.0;
          final keyboard = width < 360 ? 260.0 : 336.0;
          await _pumpPractice(tester,
              size: Size(width, height),
              keyboard: keyboard,
              brightness: brightness,
              textSize: AppTextSize.large);
          for (var i = 0; i < _practiceSet.items.length; i++) {
            await tester.tap(_field);
            await tester.enterText(_field, '$_longAnswer\n$_longAnswer');
            await tester.pumpAndSettle();
            final top = height - keyboard;
            expect(tester.getRect(_primary).bottom, lessThanOrEqualTo(top));
            expect(tester.getRect(_skip).bottom, lessThanOrEqualTo(top));
            expect(tester.getRect(_field).bottom, lessThanOrEqualTo(top));
            expect(tester.getRect(_primary).height, greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
            if (i < _practiceSet.items.length - 1) await _next(tester);
          }
        });
      }
    }
  });

  group('submitting', () {
    testWidgets('a second tap on Submit sends no second scoring request',
        (tester) async {
      final claude = await _pumpPractice(tester);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tester.enterText(_field, 'An answer.');
      await tester.pump();

      await tester.tap(_primary);
      await tester.tap(_primary, warnIfMissed: false);
      await tester.pump();
      expect(claude.calls, hasLength(1));
      claude.pending!.completeError(Exception('offline'));
      await tester.pumpAndSettle();
    });

    testWidgets('after a failed submission every answer is still there',
        (tester) async {
      final claude = await _pumpPractice(tester);
      await tester.enterText(_field, 'interrupting');
      await _next(tester);
      await tester.enterText(_field, _longAnswer);
      await _next(tester);
      await tester.enterText(_field, 'I enjoy hiking.');
      await tester.pump();
      await tester.tap(_primary);
      await tester.pump();
      expect(find.text('Reviewing your answers…'), findsOneWidget);

      claude.pending!.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(_controller(tester).text, 'I enjoy hiking.');
      await _back(tester);
      expect(_controller(tester).text, _longAnswer);
      await _back(tester);
      expect(_controller(tester).text, 'interrupting');
    });
  });

  group('Daily Test', () {
    Future<(List<Map<String, String>>, _ReadCountingClaude)> pumpDaily(
        WidgetTester tester) async {
      _setView(tester, const Size(390, 844));
      final finished = <Map<String, String>>[];
      final claude = _ReadCountingClaude();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestScreen(
          dailyTestService: DailyTestService(
              claudeService: claude, storageService: _Storage(_dailySet())),
          analyticsService: AnalyticsService(),
          onFinished: (_, answers) => finished.add(answers),
          onExit: () {},
        ),
      ));
      await tester.pumpAndSettle();
      return (finished, claude);
    }

    testWidgets(
        'the same multiline field, no character limit, and "Finish" on the '
        'last question (O5)', (tester) async {
      await pumpDaily(tester);
      expect(_textField(tester).maxLines, isNull);
      expect(_textField(tester).minLines, 1);
      expect(_textField(tester).maxLength, isNull);
      expect(_textField(tester).autocorrect, isFalse);
      expect(_textField(tester).textCapitalization, TextCapitalization.none);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      expect(_textField(tester).minLines, 2);
      expect(
          _textField(tester).textCapitalization, TextCapitalization.sentences);
      expect(find.widgetWithText(FilledButton, 'Finish'), findsOneWidget);
    });

    testWidgets(
        'Next → Back keeps the answers, and moving makes no read or grading',
        (tester) async {
      final (finished, claude) = await pumpDaily(tester);
      final reads = claude.reads;
      await tester.enterText(_field, 'interrupting');
      await _next(tester);
      await tester.enterText(_field, _longAnswer);
      await _back(tester);
      expect(_controller(tester).text, 'interrupting');
      await _next(tester);
      expect(_controller(tester).text, _longAnswer);
      expect(claude.reads, reads);
      expect(finished, isEmpty);
    });

    testWidgets('a second tap on Finish does not finish twice', (tester) async {
      final (finished, _) = await pumpDaily(tester);
      await tester.tap(_skip);
      await tester.pumpAndSettle();
      await tester.enterText(_field, _longAnswer);
      await tester.pump();
      await tester.tap(_primary);
      await tester.tap(_primary, warnIfMissed: false);
      await tester.pump();
      expect(finished, hasLength(1));
      expect(finished.single['rewrite'], _longAnswer);
    });
  });
}
