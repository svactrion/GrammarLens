import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/daily_test_completion.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/item_feedback.dart';
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

/// Skip discards what was typed (owner, 2026-10-12; the roadmap's open item
/// "Skip sends typed text"): a typed-then-skipped question counts as skipped
/// in scoring, the results, the error profile and the practiced count, on
/// Practice and the Daily Test; going back to it shows empty boxes.

/// Scores the way the proxy path does for skipping: an empty answer is a
/// skipped item (`ClaudeService.scoreAnswers`); every answered one "Needs
/// work", so it would be saved as a mistake.
class _ScoringClaude extends ClaudeService {
  final List<Map<String, String>> calls = [];

  @override
  Future<ScoringResult> scoreAnswers({
    required String deviceId,
    required PracticeSet practiceSet,
    required Map<String, String> answers,
  }) async {
    calls.add(Map.of(answers));
    return ScoringResult(topicId: practiceSet.topicId, feedback: [
      for (final item in practiceSet.items)
        ItemFeedback(
          itemId: item.id,
          isCorrect: false,
          isSkipped: (answers[item.id] ?? '').trim().isEmpty,
          errorType: 'article_use',
          correctedAnswer: 'x',
          explanation: 'x',
        ),
    ]);
  }

  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async =>
      null;
}

class _Storage extends StorageService {
  final DailyTestSet? set;
  final List<ErrorEntry> saved = [];
  final List<int> practiced = [];
  _Storage([this.set]);

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async =>
      saved.addAll(entries);

  @override
  Future<void> recordPracticeCompletion(String topicId, int answered) async =>
      practiced.add(answered);

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) async => set;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => set;
}

const _single = PracticeItem(
  id: 'single',
  type: PracticeItemType.fillInBlank,
  instruction: 'I enjoy ____ in the morning.',
);

const _multi = PracticeItem(
  id: 'multi',
  type: PracticeItemType.fillInBlank,
  instruction: 'I saw ____ owl and ____ eagle.',
);

const _last = PracticeItem(
  id: 'last',
  type: PracticeItemType.fillInBlank,
  instruction: 'She wants ____ home.',
);

Finder get _field => find.byKey(QuestionView.answerFieldKey);
Finder _box(int i) => find.byKey(QuestionView.blankBoxKey(i));
Finder get _primary => find.byKey(PracticeStepFooter.primaryKey);
Finder get _skip => find.byKey(PracticeStepFooter.skipKey);

bool _primaryEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(_primary).onPressed != null;

String _text(WidgetTester tester, Finder field) =>
    tester.widget<TextField>(field).controller!.text;

Future<void> _tap(WidgetTester tester, Finder button) async {
  await tester.pump();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void _setView(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<(_ScoringClaude, _Storage)> _pumpPractice(
    WidgetTester tester, List<PracticeItem> items) async {
  _setView(tester);
  final claude = _ScoringClaude();
  final storage = _Storage();
  await tester.pumpWidget(MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: PracticeScreen(
      topic: topicById(TopicId.articles),
      practiceSet: PracticeSet(topicId: 'articles', items: items),
      claudeService: claude,
      storageService: storage,
      analyticsService: AnalyticsService(),
      subscriptionService: SubscriptionService(),
    ),
  ));
  await tester.pumpAndSettle();
  return (claude, storage);
}

DailyTestQuestion _question(PracticeItem item) => DailyTestQuestion(
      item: item,
      topicId: 'gerundVsInfinitive',
      correctAnswer: 'swimming',
      commonWrongAnswers: const [],
    );

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('Practice', () {
    testWidgets(
        'a typed-then-skipped single box is skipped in scoring, the error '
        'profile and the practiced count; an answered one is unaffected',
        (tester) async {
      final (claude, storage) = await _pumpPractice(tester, [_single, _last]);
      await tester.enterText(_field, 'swimming');
      await _tap(tester, _skip);
      await tester.enterText(_field, 'to go');
      await _tap(tester, _primary);

      final sent = claude.calls.single;
      expect(sent['single'] ?? '', '');
      expect(sent['last'], 'to go');
      // Only the answered question's mistake is saved; 1 of 2 practised.
      expect(storage.saved.map((e) => e.userAnswer), ['to go']);
      expect(storage.practiced.single, 1);
    });

    testWidgets(
        'a typed-then-skipped multi-blank question (text and "—") is skipped '
        'in scoring', (tester) async {
      final (claude, storage) = await _pumpPractice(tester, [_multi, _last]);
      await tester.enterText(_box(0), 'an');
      await tester.tap(find.byKey(QuestionView.noArticleKey(1)));
      await _tap(tester, _skip);
      await tester.enterText(_field, 'to go');
      await _tap(tester, _primary);

      expect(claude.calls.single['multi'] ?? '', '');
      expect(storage.saved.map((e) => e.userAnswer), ['to go']);
      expect(storage.practiced.single, 1);
    });

    testWidgets('Back after Skip shows empty boxes and no "no article"',
        (tester) async {
      await _pumpPractice(tester, [_multi, _single, _last]);
      await tester.enterText(_box(0), 'an');
      await tester.tap(find.byKey(QuestionView.noArticleKey(1)));
      await tester.pump();
      expect(_primaryEnabled(tester), isTrue);
      await _tap(tester, _skip);
      await tester.enterText(_field, 'swimming');
      await _tap(tester, _skip);
      await _tap(tester, find.byKey(QuestionHeader.backKey));
      expect(_text(tester, _field), '', reason: 'the single box');
      await _tap(tester, find.byKey(QuestionHeader.backKey));
      expect(_text(tester, _box(0)), '');
      expect(_text(tester, _box(1)), '');
      expect(find.text('— no article'), findsNothing);
      expect(_primaryEnabled(tester), isFalse);
    });

    testWidgets('an answer kept with Next survives Back as before',
        (tester) async {
      await _pumpPractice(tester, [_single, _last]);
      await tester.enterText(_field, 'swimming');
      await _tap(tester, _primary);
      await _tap(tester, find.byKey(QuestionHeader.backKey));
      expect(_text(tester, _field), 'swimming');
    });
  });

  group('Daily Test', () {
    Future<List<Map<String, String>>> pumpDaily(WidgetTester tester) async {
      _setView(tester);
      final finished = <Map<String, String>>[];
      final set = DailyTestSet(
        day: '2026-10-12',
        source: DailyTestSource.shared,
        questions: [
          _question(_single),
          _question(_last.copyWithId('second')),
          _question(_last),
        ],
      );
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestScreen(
          dailyTestService: DailyTestService(
              claudeService: _ScoringClaude(), storageService: _Storage(set)),
          analyticsService: AnalyticsService(),
          onFinished: (_, answers) => finished.add(answers),
          onExit: () {},
        ),
      ));
      await tester.pumpAndSettle();
      return finished;
    }

    testWidgets(
        'a typed-then-skipped question is graded as skipped; an answered one '
        'is graded', (tester) async {
      final finished = await pumpDaily(tester);
      await tester.enterText(_field, 'swimming');
      await _tap(tester, _skip);
      await tester.enterText(_field, 'to go');
      await _tap(tester, _primary);
      await _tap(tester, _skip); // the last: finishes

      final answers = finished.single;
      expect(answers['single'] ?? '', '');
      expect(answers['second'], 'to go');
      final skipped =
          DailyTestAnswerResult.from(_question(_single), answers['single']);
      expect(skipped.isSkipped, isTrue);
      final answered = DailyTestAnswerResult.from(
          _question(_last.copyWithId('second')), answers['second']);
      expect(answered.isSkipped, isFalse);
    });

    testWidgets('Back after Skip shows an empty field', (tester) async {
      await pumpDaily(tester);
      await tester.enterText(_field, 'swimming');
      await _tap(tester, _skip);
      await _tap(tester, find.byKey(QuestionHeader.backKey));
      expect(_text(tester, _field), '');
      expect(_primaryEnabled(tester), isFalse);
    });
  });
}

extension on PracticeItem {
  PracticeItem copyWithId(String id) => PracticeItem(
        id: id,
        type: type,
        context: context,
        instruction: instruction,
        hint: hint,
      );
}
