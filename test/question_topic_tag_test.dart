import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
import 'package:grammar_lens/widgets/question_view.dart';

/// The topic tag on the question card (docs/question-screen-plan.md, item 1
/// and B1): a neutral chip after the type label, wrapping to a second line
/// when it does not fit, never cutting the type label; the badge stays top
/// right.

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

PracticeItem _item(PracticeItemType type) => PracticeItem(
      id: type.name,
      type: type,
      context: type == PracticeItemType.errorCorrection
          ? 'She enjoys to swim in the morning.'
          : null,
      instruction: type == PracticeItemType.fillInBlank
          ? 'I enjoy ____ (swim) in the morning.'
          : 'Rewrite the sentence correctly.',
    );

void _setView(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _pumpView(
  WidgetTester tester, {
  required PracticeItem item,
  Topic? topic,
  double width = 390,
  AppTextSize textSize = AppTextSize.medium,
  Brightness brightness = Brightness.light,
}) async {
  _setView(tester, Size(width, 844));
  final drafts = AnswerDrafts([item.id]);
  addTearDown(drafts.dispose);
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(brightness, textSize: textSize),
    home: Scaffold(
      body: QuestionView(
        item: item,
        index: 9,
        total: 10,
        topic: topic,
        drafts: drafts,
        horizontalPadding: width < 360 ? 14 : 16,
        onChanged: (_) {},
      ),
    ),
  ));
  await tester.pump();
}

Finder get _tag => find.byKey(QuestionView.topicTagKey);
Finder _typeLabel(PracticeItemType type) => find.text(questionTypeLabel(type));
Finder get _badge => find.text('10 / 10');
Finder get _card => find.byKey(QuestionView.questionCardKey);

/// The badge's pill (its text's padded box).
Rect _badgeRect(WidgetTester tester) => tester.getRect(
    find.ancestor(of: _badge, matching: find.byType(DecoratedBox)).first);

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('topicByName', () {
    test('finds every topic by its stored id', () {
      for (final topic in kTopics) {
        expect(topicByName(topic.id.name), same(topic));
      }
    });

    test('an unknown or empty id is no topic', () {
      expect(topicByName('passiveVoice'), isNull);
      expect(topicByName(''), isNull);
    });
  });

  group('the tag', () {
    testWidgets(
        'shows the topic title after the type label, before the '
        'badge, on one line when it fits', (tester) async {
      await _pumpView(tester,
          item: _item(PracticeItemType.fillInBlank),
          topic: topicById(TopicId.articles));
      expect(find.descendant(of: _tag, matching: find.text('Articles')),
          findsOneWidget);
      final label = tester.getRect(_typeLabel(PracticeItemType.fillInBlank));
      final tag = tester.getRect(_tag);
      final badge = _badgeRect(tester);
      expect(tag.left, greaterThan(label.right));
      expect(badge.left, greaterThan(tag.right));
      // One line: the label, the tag and the badge share a centre line.
      expect(tag.center.dy, moreOrLessEquals(badge.center.dy, epsilon: 0.5));
      expect(label.center.dy, moreOrLessEquals(badge.center.dy, epsilon: 0.5));
    });

    testWidgets('reads as "Topic: <title>"', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpView(tester,
          item: _item(PracticeItemType.fillInBlank),
          topic: topicById(TopicId.modalVerbs));
      expect(find.bySemanticsLabel('Topic: Modal Verbs'), findsOneWidget);
      handle.dispose();
    });

    testWidgets(
        'no topic: no tag, and the row is as before (label and badge '
        'on one centre line)', (tester) async {
      await _pumpView(tester, item: _item(PracticeItemType.fillInBlank));
      expect(_tag, findsNothing);
      final label = tester.getRect(_typeLabel(PracticeItemType.fillInBlank));
      expect(label.center.dy,
          moreOrLessEquals(_badgeRect(tester).center.dy, epsilon: 0.5));
    });

    for (final brightness in Brightness.values) {
      testWidgets(
          'neutral colours (${brightness.name}): subtle surface, '
          'border edge, secondary text; never the semantic colours',
          (tester) async {
        await _pumpView(tester,
            item: _item(PracticeItemType.fillInBlank),
            topic: topicById(TopicId.articles),
            brightness: brightness);
        final theme = buildAppTheme(brightness);
        final scheme = theme.colorScheme;
        final decoration =
            tester.widget<DecoratedBox>(_tag).decoration as BoxDecoration;
        final text = tester.widget<Text>(
            find.descendant(of: _tag, matching: find.byType(Text)));
        expect(decoration.color, scheme.surfaceContainerHighest);
        expect((decoration.border! as Border).top.color, scheme.outlineVariant);
        expect(text.style!.color, scheme.onSurfaceVariant);
        final semantic = theme.extension<SemanticColors>()!;
        final reserved = {
          semantic.correctBackground,
          semantic.onCorrectBackground,
          semantic.incorrectBackground,
          semantic.onIncorrectBackground,
          scheme.error,
        };
        expect(reserved, isNot(contains(decoration.color)));
        expect(reserved, isNot(contains(text.style!.color)));
      });
    }

    testWidgets(
        '"Gerund vs. Infinitive" after "Find and correct the error" '
        'at 320 pt, Large: on a second line, whole, the label whole and the '
        'badge top right', (tester) async {
      await _pumpView(tester,
          item: _item(PracticeItemType.errorCorrection),
          topic: topicById(TopicId.gerundVsInfinitive),
          width: 320,
          textSize: AppTextSize.large);
      expect(tester.takeException(), isNull);
      final label =
          tester.getRect(_typeLabel(PracticeItemType.errorCorrection));
      final tag = tester.getRect(_tag);
      final badge = _badgeRect(tester);
      expect(tag.top, greaterThan(label.bottom), reason: 'wrapped');
      expect(tag.left, moreOrLessEquals(label.left, epsilon: 0.5));
      expect(label.center.dy, moreOrLessEquals(badge.center.dy, epsilon: 0.5));
      final card = tester.getRect(_card);
      // 1 pt card border + 15 pt padding on the right.
      expect(badge.right, moreOrLessEquals(card.right - 15, epsilon: 1.5));
      // The tag's title is on one line inside the chip.
      final title = tester.renderObject<RenderParagraph>(find.descendant(
          of: _tag, matching: find.text('Gerund vs. Infinitive')));
      expect(title.didExceedMaxLines, isFalse);
      expect(
          title.size.height, lessThan(title.text.style!.fontSize! * 1.4 * 1.5));
    });

    testWidgets(
        '"Gerund vs. Infinitive" after "Fill in the blank" at 390 pt, '
        'Large: still on the first line (the plan\'s measurement)',
        (tester) async {
      await _pumpView(tester,
          item: _item(PracticeItemType.fillInBlank),
          topic: topicById(TopicId.gerundVsInfinitive),
          width: 390,
          textSize: AppTextSize.large);
      expect(tester.getRect(_tag).center.dy,
          moreOrLessEquals(_badgeRect(tester).center.dy, epsilon: 0.5));
    });

    // The whole matrix: no overflow, the type label never cut, the tag
    // whole and never under the badge.
    for (final width in [320.0, 375.0, 390.0, 430.0]) {
      for (final size in AppTextSize.values) {
        for (final brightness in Brightness.values) {
          testWidgets(
              '${width.toInt()} pt, ${size.name}, ${brightness.name}: every '
              'type × topic fits without overflow or a cut label',
              (tester) async {
            for (final type in PracticeItemType.values) {
              for (final topic in kTopics) {
                await _pumpView(tester,
                    item: _item(type),
                    topic: topic,
                    width: width,
                    textSize: size,
                    brightness: brightness);
                final why = '${type.name} / ${topic.title}';
                expect(tester.takeException(), isNull, reason: why);
                final label =
                    tester.renderObject<RenderParagraph>(_typeLabel(type));
                // Whole, on one line, no ellipsis.
                expect(label.didExceedMaxLines, isFalse, reason: why);
                expect(label.size.height,
                    lessThan(label.text.style!.fontSize! * 1.4 * 1.5),
                    reason: why);
                expect(find.text(topic.title), findsOneWidget, reason: why);
                final tag = tester.getRect(_tag);
                final badge = _badgeRect(tester);
                expect(tag.right, lessThanOrEqualTo(badge.left - 10 + 0.5),
                    reason: why);
                expect(tester.getRect(_typeLabel(type)).right,
                    lessThanOrEqualTo(badge.left - 10 + 0.5),
                    reason: why);
              }
            }
          });
        }
      }
    }
  });

  group('on the screens', () {
    testWidgets('Practice: the screen\'s topic', (tester) async {
      _setView(tester, const Size(390, 844));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: PracticeScreen(
          topic: topicById(TopicId.tenseSelection),
          practiceSet: PracticeSet(
              topicId: 'tenseSelection',
              items: [_item(PracticeItemType.fillInBlank)]),
          claudeService: ClaudeService(),
          storageService: _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: SubscriptionService(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.descendant(of: _tag, matching: find.text('Tense Selection')),
          findsOneWidget);
    });

    testWidgets(
        'Daily Test: each question\'s own topic; an unknown topic id '
        'shows no tag', (tester) async {
      _setView(tester, const Size(390, 844));
      DailyTestQuestion question(String id, String topicId) =>
          DailyTestQuestion(
            item: PracticeItem(
                id: id,
                type: PracticeItemType.fillInBlank,
                instruction: 'I enjoy ____ in the morning.'),
            topicId: topicId,
            correctAnswer: 'swimming',
            commonWrongAnswers: const [],
          );
      final set = DailyTestSet(
        day: '2026-10-12',
        source: DailyTestSource.shared,
        questions: [
          question('a', 'articles'),
          question('b', 'modalPastForms'),
          question('c', 'notATopic'),
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

      Future<void> skip() async {
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
      }

      expect(find.descendant(of: _tag, matching: find.text('Articles')),
          findsOneWidget);
      await skip();
      expect(find.descendant(of: _tag, matching: find.text('Modal Past Forms')),
          findsOneWidget);
      await skip();
      expect(_tag, findsNothing);
    });
  });
}
