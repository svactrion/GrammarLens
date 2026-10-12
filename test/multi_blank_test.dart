import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/blank_colors.dart';
import 'package:grammar_lens/widgets/practice_step_footer.dart';
import 'package:grammar_lens/widgets/question_app_bar.dart';
import 'package:grammar_lens/widgets/question_view.dart';

/// Practice's multi-blank answer boxes (question screen plan, §4 and B3):
/// one box per blank (2–4), linked by colour to the blank's underline, the
/// "—" no-article button on `articles` only, Next only when every box is
/// filled, the completed sentence sent to scoring and saved, drafts kept
/// across Next and Back, and the boxes' focus behaviour.

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
  final List<ErrorEntry> saved = [];

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async =>
      saved.addAll(entries);

  @override
  Future<void> recordPracticeCompletion(String topicId, int answered) async {}
}

const _articles = PracticeItem(
  id: 'articles3',
  type: PracticeItemType.fillInBlank,
  context: 'We had ____ lunch at ____ small café near ____ station.',
  instruction: 'Fill in each blank with an article, or none.',
);

const _two = PracticeItem(
  id: 'two',
  type: PracticeItemType.fillInBlank,
  instruction:
      'Tom says: "I can\'t stop ____, but I\'ve promised ____ by May."',
);

const _one = PracticeItem(
  id: 'one',
  type: PracticeItemType.fillInBlank,
  instruction: 'I enjoy ____ in the morning.',
);

const _four = PracticeItem(
  id: 'four',
  type: PracticeItemType.fillInBlank,
  instruction: 'I saw ____ owl, ____ eagle, ____ hawk and ____ swan.',
);

const _five = PracticeItem(
  id: 'five',
  type: PracticeItemType.fillInBlank,
  instruction: '__ a, __ b, __ c, __ d, __ e.',
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

class _Pumped {
  final _ScoringClaude claude;
  final _Storage storage;
  _Pumped(this.claude, this.storage);
}

Future<_Pumped> _pump(
  WidgetTester tester, {
  List<PracticeItem> items = const [_articles, _two, _one],
  TopicId topic = TopicId.articles,
  Size size = const Size(390, 844),
  double keyboard = 0,
  Brightness brightness = Brightness.light,
  AppTextSize textSize = AppTextSize.medium,
}) async {
  _setView(tester, size, keyboard: keyboard);
  final claude = _ScoringClaude();
  final storage = _Storage();
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(brightness, textSize: textSize),
    home: PracticeScreen(
      topic: topicById(topic),
      practiceSet: PracticeSet(topicId: topic.name, items: items),
      claudeService: claude,
      storageService: storage,
      analyticsService: AnalyticsService(),
      subscriptionService: SubscriptionService(),
    ),
  ));
  await tester.pumpAndSettle();
  return _Pumped(claude, storage);
}

Finder _box(int i) => find.byKey(QuestionView.blankBoxKey(i));
Finder _dash(int i) => find.byKey(QuestionView.noArticleKey(i));
Finder get _single => find.byKey(QuestionView.answerFieldKey);
Finder get _primary => find.byKey(PracticeStepFooter.primaryKey);
Finder get _skip => find.byKey(PracticeStepFooter.skipKey);
Finder get _control => find.byKey(QuestionView.keyboardControlKey);

TextField _field(WidgetTester tester, int i) =>
    tester.widget<TextField>(_box(i));

bool _primaryEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_primary).onPressed != null;

Future<void> _type(WidgetTester tester, int i, String text) async {
  await tester.enterText(_box(i), text);
  await tester.pump();
}

Future<void> _tapDash(WidgetTester tester, int i) async {
  await tester.tap(_dash(i));
  await tester.pump();
}

Future<void> _go(WidgetTester tester, Finder button) async {
  await tester.pump();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

/// The last question's Submit (or Skip): the loading view spins until the
/// scoring call is settled, so no pumpAndSettle.
Future<void> _submit(WidgetTester tester, Finder button) async {
  await tester.pump();
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The colours of the blanks' underlines in the question, in order.
List<Color> _underlineColors(WidgetTester tester) {
  final colors = <Color>[];
  for (final rich in tester.widgetList<RichText>(find.descendant(
      of: find.byKey(QuestionView.questionCardKey),
      matching: find.byType(RichText)))) {
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

Color? _tintOf(WidgetTester tester, int blank) {
  final tints = <Color?>[];
  for (final rich in tester.widgetList<RichText>(find.descendant(
      of: find.byKey(QuestionView.questionCardKey),
      matching: find.byType(RichText)))) {
    rich.text.visitChildren((span) {
      if (span.style?.decoration == TextDecoration.underline) {
        tints.add(span.style!.backgroundColor);
      }
      return true;
    });
  }
  return tints[blank];
}

double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('how many boxes', () {
    test('one per blank for 2–4 blanks; one box otherwise', () {
      expect(AnswerDrafts.boxCountFor(_articles), 3);
      expect(AnswerDrafts.boxCountFor(_two), 2);
      expect(AnswerDrafts.boxCountFor(_four), 4);
      expect(AnswerDrafts.boxCountFor(_one), 1);
      expect(AnswerDrafts.boxCountFor(_five), 1, reason: 'more than 4');
      expect(AnswerDrafts.boxCountFor(_rewrite), 1, reason: 'not a blank type');
    });

    testWidgets(
        'one blank: today\'s single field, no boxes, no coloured blanks',
        (tester) async {
      await _pump(tester, items: const [_one]);
      expect(_single, findsOneWidget);
      expect(_box(0), findsNothing);
      expect(_underlineColors(tester), isEmpty);
    });

    testWidgets('error correction keeps its single field', (tester) async {
      await _pump(tester, items: const [_rewrite]);
      expect(_single, findsOneWidget);
      expect(_box(0), findsNothing);
    });

    testWidgets('more than 4 blanks: the single field', (tester) async {
      await _pump(tester, items: const [_five]);
      expect(_single, findsOneWidget);
      expect(_box(0), findsNothing);
    });
  });

  group('the boxes and the blanks', () {
    for (final brightness in Brightness.values) {
      testWidgets(
          '(${brightness.name}) one box per blank, below the sentence in '
          'blank order, each edged in its blank\'s colour', (tester) async {
        await _pump(tester, items: const [_four], brightness: brightness);
        final colors = blankColors(brightness);
        expect(_underlineColors(tester), colors);
        expect(_single, findsNothing);
        final card = tester.getRect(find.byKey(QuestionView.questionCardKey));
        for (var i = 0; i < 4; i++) {
          final field = _field(tester, i);
          final edge = field.decoration!.enabledBorder! as OutlineInputBorder;
          expect(edge.borderSide.color, colors[i]);
          expect(edge.borderSide.width, 1.5);
          final focused =
              field.decoration!.focusedBorder! as OutlineInputBorder;
          expect(focused.borderSide.color, colors[i]);
          expect(focused.borderSide.width, 3);
          expect(field.maxLength, QuestionView.boxMaxLength);
          expect(tester.getRect(_box(i)).top, greaterThan(card.bottom));
          if (i > 0) {
            expect(tester.getRect(_box(i)).top,
                greaterThan(tester.getRect(_box(i - 1)).bottom));
          }
        }
      });
    }

    test(
        'the palette: 3:1 or more on the card and the page, no semantic '
        'colour, four distinct colours', () {
      for (final brightness in Brightness.values) {
        final theme = buildAppTheme(brightness);
        final scheme = theme.colorScheme;
        final semantic = theme.extension<SemanticColors>()!;
        final colors = blankColors(brightness);
        expect(colors.toSet().length, 4);
        for (final color in colors) {
          expect(_contrast(color, scheme.surfaceContainerHigh),
              greaterThanOrEqualTo(3),
              reason: '$brightness $color card');
          expect(_contrast(color, scheme.surfaceContainerLow),
              greaterThanOrEqualTo(3),
              reason: '$brightness $color page');
          for (final reserved in [
            semantic.correctBackground,
            semantic.onCorrectBackground,
            semantic.incorrectBackground,
            semantic.onIncorrectBackground,
            scheme.error,
          ]) {
            expect(color, isNot(reserved));
          }
        }
      }
    });

    testWidgets(
        'VoiceOver: "blank n of N" in the sentence, "Blank n of N" '
        'on the box', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester, items: const [_two]);
      expect(find.bySemanticsLabel(RegExp('blank 2 of 2')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('Blank 1 of 2')), findsWidgets);
      semantics.dispose();
    });

    testWidgets('the focused box\'s blank is tinted', (tester) async {
      await _pump(tester, items: const [_two]);
      expect(_tintOf(tester, 1), isNull);
      await tester.tap(_box(1));
      await tester.pumpAndSettle();
      expect(_tintOf(tester, 1), isNotNull);
      expect(_tintOf(tester, 0), isNull);
    });

    testWidgets(
        '4 boxes at 375 × 667, Large, keyboard up: no overflow; the last box '
        'scrolls into view above the Skip/Next bar', (tester) async {
      await _pump(tester,
          items: const [_four],
          size: const Size(375, 667),
          keyboard: 260,
          textSize: AppTextSize.large);
      await tester.tap(_box(0));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      final box = tester.getRect(_box(3));
      final footer = tester.getRect(find.byType(PracticeStepFooter));
      expect(box.bottom, lessThanOrEqualTo(footer.top + 0.5));
      expect(
          box.top, greaterThanOrEqualTo(tester.getRect(_control).bottom - 0.5));
    });
  });

  group('the "—" (no article) button', () {
    testWidgets('only on articles', (tester) async {
      await _pump(tester,
          items: const [_two], topic: TopicId.gerundVsInfinitive);
      expect(_dash(0), findsNothing);
    });

    testWidgets(
        'sets a clear no-article state and clears typed text; typing clears '
        'it again; a second tap turns it off', (tester) async {
      await _pump(tester, items: const [_articles]);
      expect(_dash(0), findsOneWidget);
      expect(tester.getSize(_dash(0)), const Size(44, 44));
      await _type(tester, 0, 'a');
      await _tapDash(tester, 0);
      expect(_field(tester, 0).controller!.text, '');
      expect(find.text('— no article'), findsOneWidget);

      await _type(tester, 0, 'the');
      expect(find.text('— no article'), findsNothing);

      await _type(tester, 0, '');
      expect(find.text('— no article'), findsNothing,
          reason: 'an empty box is never no article');
      await _tapDash(tester, 0);
      expect(find.text('— no article'), findsOneWidget);
      await _tapDash(tester, 0);
      expect(find.text('— no article'), findsNothing);
    });
  });

  group('Next (owner decision Q3)', () {
    testWidgets(
        'only when every box is typed or set to "—"; Skip is always there',
        (tester) async {
      await _pump(tester, items: const [_articles, _one]);
      expect(_primaryEnabled(tester), isFalse);
      await _type(tester, 1, 'a');
      expect(_primaryEnabled(tester), isFalse, reason: 'two boxes empty');
      await _type(tester, 2, 'the');
      expect(_primaryEnabled(tester), isFalse, reason: 'one box empty');
      await _type(tester, 0, '   ');
      expect(_primaryEnabled(tester), isFalse, reason: 'spaces only');
      await _tapDash(tester, 0);
      expect(_primaryEnabled(tester), isTrue);
      await _type(tester, 2, '');
      expect(_primaryEnabled(tester), isFalse);
      expect(tester.widget<TextButton>(_skip).onPressed, isNotNull);
    });
  });

  group('the answer', () {
    testWidgets(
        'the completed sentence goes to scoring (a no-article blank removed '
        'cleanly) and is what an error entry saves', (tester) async {
      final pumped = await _pump(tester, items: const [_articles, _two]);
      await _tapDash(tester, 0);
      await _type(tester, 1, ' a ');
      await _type(tester, 2, 'the');
      await _go(tester, _primary);
      await _type(tester, 0, 'smoking');
      await _type(tester, 1, 'to quit');
      await _submit(tester, _primary);

      final sent = pumped.claude.calls.single;
      expect(
          sent['articles3'], 'We had lunch at a small café near the station.');
      expect(
          sent['two'],
          'Tom says: "I can\'t stop smoking, but I\'ve promised to quit by '
          'May."');

      pumped.claude.pending!.complete(const ScoringResult(
        topicId: 'articles',
        feedback: [
          ItemFeedback(
            itemId: 'articles3',
            isCorrect: false,
            isSkipped: false,
            errorType: 'article_use',
            correctedAnswer: 'We had lunch at a small café near the station.',
            explanation: 'x',
          ),
          ItemFeedback(
            itemId: 'two',
            isCorrect: true,
            isSkipped: false,
            correctedAnswer: 'x',
            explanation: 'x',
          ),
        ],
      ));
      await tester.pumpAndSettle();
      expect(pumped.storage.saved.single.userAnswer,
          'We had lunch at a small café near the station.');
    });

    testWidgets('a skipped multi-blank question sends an empty answer',
        (tester) async {
      final pumped = await _pump(tester, items: const [_two]);
      await _submit(tester, _skip);
      expect(pumped.claude.calls.single['two'] ?? '', '');
    });
  });

  group('across Next and Back', () {
    testWidgets(
        'every box\'s text and "no article" come back on Back, and the next '
        'question starts empty', (tester) async {
      await _pump(tester, items: const [_articles, _two]);
      await _tapDash(tester, 0);
      await _type(tester, 1, 'a');
      await _type(tester, 2, 'the');
      await _go(tester, _primary);
      expect(_field(tester, 0).controller!.text, '');
      await _type(tester, 0, 'smoking');
      await tester.tap(find.byKey(QuestionHeader.backKey));
      await tester.pumpAndSettle();
      expect(find.text('— no article'), findsOneWidget);
      expect(_field(tester, 1).controller!.text, 'a');
      expect(_field(tester, 2).controller!.text, 'the');
      await _go(tester, _primary);
      expect(_field(tester, 0).controller!.text, 'smoking');
    });

    testWidgets(
        'Next with the keyboard in the third box, to a one-box question: the '
        'keyboard stays, in its single field', (tester) async {
      await _pump(tester, items: const [_articles, _one]);
      await tester.tap(_box(2));
      await tester.pumpAndSettle();
      await _go(tester, _skip);
      expect(_single, findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(FocusManager.instance.primaryFocus,
          tester.widget<TextField>(_single).focusNode);
    });
  });

  group('the keyboard across Next and Back', () {
    testWidgets(
        'from box 2 of a 3-blank question to a 2-blank one and back: the '
        'keyboard stays, in box 2 each time', (tester) async {
      await _pump(tester, items: const [_articles, _two]);
      await tester.tap(_box(1));
      await tester.pumpAndSettle();
      await _go(tester, _skip);
      expect(tester.testTextInput.isVisible, isTrue);
      expect(_field(tester, 1).focusNode!.hasFocus, isTrue);
      await tester.tap(find.byKey(QuestionHeader.backKey));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);
      expect(_field(tester, 1).focusNode!.hasFocus, isTrue);
    });
  });

  group('focus', () {
    testWidgets(
        'Return moves to the next box, and on the last closes the keyboard',
        (tester) async {
      await _pump(tester, items: const [_articles]);
      expect(_field(tester, 0).textInputAction, TextInputAction.next);
      expect(_field(tester, 2).textInputAction, TextInputAction.done);
      await tester.tap(_box(0));
      await tester.pumpAndSettle();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_field(tester, 1).focusNode!.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_field(tester, 2).focusNode!.hasFocus, isTrue);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.context?.widget,
          isNot(isA<EditableText>()));
      expect(_control, findsNothing);
    });

    testWidgets(
        '"Review answer" stays steady, frame by frame, while focus moves '
        'between boxes by Return and by a tap (any box counts)',
        (tester) async {
      await _pump(tester, items: const [_four]);
      await tester.tap(_box(0));
      await tester.pumpAndSettle();
      expect(_control, findsOneWidget);
      final place = tester.getRect(_control);

      Future<void> everyFrame() async {
        for (var frame = 0; frame < 20; frame++) {
          expect(_control, findsOneWidget, reason: 'frame $frame');
          expect(tester.getRect(_control), place, reason: 'frame $frame');
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      await everyFrame();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pump();
      await everyFrame();
      await tester.tap(_box(0));
      await tester.pump();
      await everyFrame();
      await tester.tap(_box(3));
      await tester.pump();
      await everyFrame();
      expect(_field(tester, 3).focusNode!.hasFocus, isTrue);

      // "Review answer" closes the keyboard from any box.
      await tester.tap(_control);
      await tester.pumpAndSettle();
      expect(_control, findsNothing);
      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}
