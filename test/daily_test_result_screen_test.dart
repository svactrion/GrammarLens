import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/monthly_medal.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/monthly_medal_rules.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/confetti_burst.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';
import 'package:grammar_lens/widgets/result_score_band.dart';

import 'support/celebration_support.dart';
import 'support/recording_analytics_sink.dart';

/// Captures what DailyTestResultScreen actually writes, instead of hitting
/// the real (platform-channel-backed, throwing-in-tests) StorageService.
/// Both halves of a completion (marking the day completed and recording its
/// wrong answers) now land through the single atomic
/// `completeDailyTest` — see StorageService.completeDailyTest's own doc
/// comment for why that replaced two independent calls.
class _FakeStorageService extends StorageService {
  final List<ErrorEntry> insertedErrors = [];
  int completeDailyTestCalls = 0;

  /// When set, `completeDailyTest` throws this instead of recording
  /// anything — simulates a failed transaction (e.g. a real one rolled
  /// back by a storage error) to prove the screen reacts to it instead of
  /// swallowing it.
  Object? failCompletionWith;
  Completer<void>? pendingCompletion;

  /// Controls the return value a *successful* call reports — mirrors
  /// `StorageService.completeDailyTest`'s real "did this call just earn
  /// the Welcome badge" signal (docs/prd-gamification.md §M6.5). Defaults
  /// to false; tests that care about the celebration set it explicitly.
  bool welcomeBadgeJustEarned = false;

  /// Batch 5 (N15, N24): the set's month as stored after the save, and the
  /// months already finalized; what `ClimbMilestones` reads.
  ({int steps, int correct, int wrong, int skipped}) monthAfter =
      (steps: 0, correct: 0, wrong: 0, skipped: 0);
  final Set<(int, int)> finalized = {};

  @override
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
          int year, int month) async =>
      monthAfter;

  @override
  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async => [
        for (final (y, m) in finalized)
          MonthlyMedalResult(
              year: y,
              month: m,
              score: 0,
              maxScore: MonthlyMedalRules.maxScore(y, m),
              activeDays: 0,
              correct: 0,
              wrong: 0,
              skipped: 0,
              tier: null,
              ruleVersion: 1,
              finalizedAt: DateTime(y, m + 1)),
      ];

  @override
  Future<String> resolveClimbMonthTheme(int year, int month) async =>
      ClimbThemeRotation.shownFor(year, month).id;

  @override
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    if (pendingCompletion != null) await pendingCompletion!.future;
    if (failCompletionWith != null) {
      throw failCompletionWith!;
    }
    completeDailyTestCalls++;
    insertedErrors.addAll(errorEntries);
    return welcomeBadgeJustEarned;
  }
}

DailyTestQuestion _question({
  required String id,
  required String topicId,
  required String correctAnswer,
  List<CommonWrongAnswer> commonWrongAnswers = const [],
  String? explanation,
  List<String> acceptedAnswers = const [],
}) =>
    DailyTestQuestion(
      item: PracticeItem(
        id: id,
        type: PracticeItemType.fillInBlank,
        instruction: 'Question $id',
      ),
      topicId: topicId,
      correctAnswer: correctAnswer,
      commonWrongAnswers: commonWrongAnswers,
      explanation: explanation,
      acceptedAnswers: acceptedAnswers,
    );

void main() {
  late _FakeStorageService storageService;
  late DailyTestService dailyTestService;
  late RecordingAnalyticsSink analyticsSink;
  late AnalyticsService analyticsService;

  setUp(() {
    storageService = _FakeStorageService();
    analyticsSink = RecordingAnalyticsSink();
    analyticsService = AnalyticsService(sink: analyticsSink);
    dailyTestService = DailyTestService(
      claudeService: ClaudeService(),
      storageService: storageService,
    );
  });

  // A mix covering all four outcomes in one set: correct, wrong-matching-a-
  // predicted-answer (has a comment), wrong-with-no-match (no comment),
  // and skipped.
  final questions = [
    _question(id: 'q1', topicId: 'articles', correctAnswer: 'the'),
    _question(
      id: 'q2',
      topicId: 'articles',
      correctAnswer: 'the',
      commonWrongAnswers: const [
        CommonWrongAnswer(
            answer: 'a', comment: "Close, but 'the' is specific."),
      ],
    ),
    _question(id: 'q3', topicId: 'tenseSelection', correctAnswer: 'went'),
    _question(id: 'q4', topicId: 'modalVerbs', correctAnswer: 'must'),
  ];
  final answers = {
    'q1': 'the', // correct
    'q2': 'a', // wrong, matches the predicted common wrong answer
    'q3': 'go', // wrong, matches nothing predicted
    'q4': '', // skipped
  };

  // AppMessenger.key is a process-global GlobalKey, so a leftover message
  // from one test could otherwise bleed into the next.
  tearDown(() => AppMessenger.clear());

  for (final brightness in Brightness.values) {
    testWidgets(
        'the fixed footer waits for saving, retries a failure, and stays '
        'in view at large text in $brightness', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      storageService.pendingCompletion = pending;
      storageService.failCompletionWith = StateError('disk full');
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: DailyTestResultScreen(
          dailyTestSet:
              DailyTestSet(day: '2026-01-01', questions: [questions.first]),
          answers: const {'q1': 'the'},
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
        ),
      ));
      await tester.pump();

      // Nothing has been scrolled: the button is in view and disabled.
      void expectButtonInView() {
        final rect = tester.getRect(find.byType(FilledButton));
        expect(rect.bottom, lessThanOrEqualTo(568));
        expect(rect.top, greaterThanOrEqualTo(0));
      }

      expect(find.text('Saving your results…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expectButtonInView();

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('See your climb'), findsNothing);
      expect(find.text('Try saving again'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      expectButtonInView();

      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();
      expect(find.text('See your climb'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
      expectButtonInView();
      expect(storageService.completeDailyTestCalls, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('all-skipped result offers Home without promising a step',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet:
              DailyTestSet(day: '2026-01-01', questions: [questions.first]),
          answers: const {},
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
        )));
    await tester.pumpAndSettle();
    expect(find.text('Back to Home'), findsOneWidget);
    expect(find.text('See your climb'), findsNothing);
    expect(storageService.completeDailyTestCalls, 1);
  });

  Future<void> pumpResult(
    WidgetTester tester,
    DailyTestSet set, {
    bool isDay0 = false,
    VoidCallback? onDone,
    Map<String, String>? answersOverride,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        // Reads SemanticColors off the theme.
        theme: buildAppTheme(Brightness.light),
        // Wired the same way app.dart does, so a completion failure's
        // AppMessenger.show call actually has a messenger to reach.
        scaffoldMessengerKey: AppMessenger.key,
        home: DailyTestResultScreen(
          dailyTestSet: set,
          answers: answersOverride ?? answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
          isDay0: isDay0,
          onDone: onDone,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('failed atomic save exposes retry without duplicating errors',
      (tester) async {
    storageService.failCompletionWith = StateError('simulated disk error');
    await pumpResult(
        tester, DailyTestSet(day: '2026-01-01', questions: questions));
    expect(find.text('Try saving again'), findsOneWidget);
    expect(storageService.insertedErrors, isEmpty);
    storageService.failCompletionWith = null;
    await tester.tap(find.text('Try saving again'));
    await tester.pumpAndSettle();
    expect(find.text('Try saving again'), findsNothing);
    expect(storageService.completeDailyTestCalls, 1);
    expect(storageService.insertedErrors, hasLength(2));
  });

  group('card explanations', () {
    const q1Why = "Use 'the' for q1 because there is only one.";
    const q2Why = "Use 'the' for q2 because it is specific.";
    const q3Why = "'Went' is the simple past of 'go'.";
    const q4Why = "'Must' is for a strong obligation.";
    const q2Comment = "Close, but 'the' is specific.";

    // The same four outcomes as `questions`, each question now carrying
    // its own pre-written explanation.
    final explained = [
      _question(
          id: 'q1',
          topicId: 'articles',
          correctAnswer: 'the',
          explanation: q1Why),
      _question(
        id: 'q2',
        topicId: 'articles',
        correctAnswer: 'the',
        explanation: q2Why,
        commonWrongAnswers: const [
          CommonWrongAnswer(answer: 'a', comment: q2Comment),
        ],
      ),
      _question(
          id: 'q3',
          topicId: 'tenseSelection',
          correctAnswer: 'went',
          explanation: q3Why),
      _question(
          id: 'q4',
          topicId: 'modalVerbs',
          correctAnswer: 'must',
          explanation: q4Why),
    ];

    Finder text(String value) => find.text(value, skipOffstage: false);

    // The result list builds lazily; a tall surface keeps every card built
    // so each one's text can be checked directly.
    void useTallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets(
        'a correct and a skipped card show the explanation, as Topic '
        'Practice does', (tester) async {
      useTallView(tester);
      await pumpResult(
          tester, DailyTestSet(day: '2026-01-01', questions: explained));

      expect(text(q1Why), findsOneWidget);
      expect(text(q4Why), findsOneWidget);
    });

    testWidgets(
        'an unpredicted wrong answer shows the explanation instead of the '
        'generic line', (tester) async {
      useTallView(tester);
      await pumpResult(
          tester, DailyTestSet(day: '2026-01-01', questions: explained));

      expect(text(q3Why), findsOneWidget);
      expect(text("Not quite — here's the correct answer."), findsNothing);
    });

    testWidgets(
        'a predicted wrong answer keeps its own comment over the '
        'explanation', (tester) async {
      useTallView(tester);
      await pumpResult(
          tester, DailyTestSet(day: '2026-01-01', questions: explained));

      expect(text(q2Comment), findsOneWidget);
      expect(text(q2Why), findsNothing);
    });

    testWidgets('a keyboard-variant match shows its note, then the explanation',
        (tester) async {
      useTallView(tester);
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: [
          _question(
              id: 'k1',
              topicId: 'gerundVsInfinitive',
              correctAnswer: 'cooking',
              explanation: "After 'enjoy', the verb takes -ing."),
        ]),
        answersOverride: {'k1': 'cookıng'},
      );

      final shown = tester
          .widgetList<Text>(find.byType(Text, skipOffstage: false))
          .map((t) => t.data ?? '')
          .firstWhere((d) => d.contains('keyboard character'));
      expect(shown, contains('Not a grammar mistake.'));
      expect(shown, endsWith("After 'enjoy', the verb takes -ing."));
    });

    testWidgets(
        'a set cached before explanations existed still renders: the '
        'generic line for an unpredicted mistake, the comment for a '
        'predicted one, and no empty explanation anywhere', (tester) async {
      useTallView(tester);
      // `questions` is built with no explanation at all — exactly what an
      // older cached set parses to.
      await pumpResult(
          tester, DailyTestSet(day: '2026-01-01', questions: questions));

      expect(tester.takeException(), isNull);
      expect(text("Not quite — here's the correct answer."), findsOneWidget);
      expect(text(q2Comment), findsOneWidget);
      // No card rendered a blank explanation line.
      final texts = tester
          .widgetList<Text>(find.byType(Text, skipOffstage: false))
          .map((t) => t.data);
      expect(texts.where((d) => d != null && d.trim().isEmpty), isEmpty);
    });
  });

  group(
      'feeding the error profile (2026-09-05 decision, see docs/build-log.md)',
      () {
    testWidgets('wrong answers are written, correct and skipped are not',
        (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(storageService.insertedErrors, hasLength(2));
      expect(
        storageService.insertedErrors.map((e) => e.prompt),
        containsAll(['Question q2', 'Question q3']),
      );
    });

    testWidgets('every written entry is tagged as coming from Daily Test',
        (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(
        storageService.insertedErrors
            .every((e) => e.source == ErrorSource.dailyTest),
        isTrue,
      );
    });

    testWidgets(
        'a wrong answer matching a predicted common mistake keeps its real '
        'comment as the explanation', (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final q2Entry = storageService.insertedErrors
          .firstWhere((e) => e.prompt == 'Question q2');
      expect(q2Entry.explanation, "Close, but 'the' is specific.");
    });

    testWidgets(
        'a wrong answer matching nothing predicted has no explanation — '
        'never an invented one, since there is no LLM call to produce a '
        'real one', (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final q3Entry = storageService.insertedErrors
          .firstWhere((e) => e.prompt == 'Question q3');
      expect(q3Entry.explanation, isNull);
      // In particular, never the screen's own "Not quite" display fallback
      // — that's UI copy, not something to persist as if it were real
      // feedback.
      expect(q3Entry.explanation, isNot(contains('Not quite')));
    });

    testWidgets(
        "errorType falls back to the question's topic — the coarsest true "
        'classification Daily Test has, not a fabricated finer one',
        (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final q3Entry = storageService.insertedErrors
          .firstWhere((e) => e.prompt == 'Question q3');
      expect(q3Entry.topicId, 'tenseSelection');
      expect(q3Entry.errorType, 'tenseSelection');
    });

    testWidgets(
        'a keyboard-variant answer (docs/build-log.md, 2026-09-07) is not '
        'written to the error profile', (tester) async {
      final keyboardQuestions = [
        _question(
            id: 'k1', topicId: 'gerundVsInfinitive', correctAnswer: 'cooking'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: DailyTestResultScreen(
            dailyTestSet:
                DailyTestSet(day: '2026-01-01', questions: keyboardQuestions),
            answers: const {'k1': 'cookıng'},
            dailyTestService: dailyTestService,
            analyticsService: analyticsService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(storageService.insertedErrors, isEmpty);
    });

    testWidgets(
        'a keyboard-variant answer is shown as Correct, never Needs work, '
        'with a short note explaining the character difference',
        (tester) async {
      final keyboardQuestions = [
        _question(
            id: 'k1', topicId: 'gerundVsInfinitive', correctAnswer: 'cooking'),
      ];
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: DailyTestResultScreen(
            dailyTestSet:
                DailyTestSet(day: '2026-01-01', questions: keyboardQuestions),
            answers: const {'k1': 'cookıng'},
            dailyTestService: dailyTestService,
            analyticsService: analyticsService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Needs work'), findsNothing);
      expect(find.textContaining('keyboard character'), findsOneWidget);
    });

    testWidgets(
        'an accepted alternative is shown as Correct with the key named, '
        'and is not written to the error profile', (tester) async {
      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: [
          _question(
              id: 'a1',
              topicId: 'modals',
              correctAnswer: 'had to',
              acceptedAnswers: const ['should'],
              explanation: 'Past obligation.'),
        ]),
        answersOverride: {'a1': 'Should'},
      );

      expect(find.text('Correct'), findsOneWidget);
      expect(find.text('Needs work'), findsNothing);
      expect(
          find.text('Also correct: "had to". Past obligation.',
              skipOffstage: false),
          findsOneWidget);
      expect(storageService.insertedErrors, isEmpty);
    });

    testWidgets(
        'reopening an already-completed set (Home\'s "view result again") '
        'does not re-log the same mistakes a second time', (tester) async {
      final completedSet = DailyTestSet(
        day: '2026-01-01',
        questions: questions,
        completedAt: DateTime(2026, 1, 1),
        answers: answers,
      );

      await pumpResult(tester, completedSet);

      expect(storageService.insertedErrors, isEmpty);
      expect(storageService.completeDailyTestCalls, 0);
    });
  });

  group('atomic completion (StorageService.completeDailyTest)', () {
    testWidgets(
        'a completion failure surfaces via the existing AppMessenger toast '
        'alongside the retry affordance', (tester) async {
      storageService.failCompletionWith = Exception('disk full');

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(
        find.textContaining('Could not save your Daily Test results'),
        findsOneWidget,
      );
    });
  });

  group('Welcome badge celebration (docs/prd-gamification.md §M6.5)', () {
    /// Tall enough that the whole list is built and in view, so the card
    /// below the results can be found without scrolling.
    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets(
        'a completion that just earned the badge shows the one-time '
        'celebration, exactly once', (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(find.text('Welcome to the climb'), findsOneWidget);
      // The copy states the step rule: one answered question earns the day's
      // step, so it must not promise progress for every completed test.
      expect(
        find.text(
          "Answer at least one question a day to keep moving "
          "up this month's mountain.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Every completed Daily Test'), findsNothing);
    });

    testWidgets(
        'the button becomes "Start my climb", with a small badge icon, in '
        'place of the plain one', (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(find.text('Start my climb'), findsOneWidget);
      expect(find.text('See your climb'), findsNothing);
      expect(find.text('Back to Home'), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(FilledButton),
          matching: find.byIcon(Icons.emoji_events_rounded),
        ),
        findsNWidgets(1),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'N15: the celebration opens over the results when the save lands; '
        'nothing in the list moves, and one tap shows the results',
        (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;
      final pending = Completer<void>();
      storageService.pendingCompletion = pending;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet: DailyTestSet(day: '2026-01-01', questions: questions),
          answers: answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
        ),
      ));
      await tester.pump();
      expect(celebrationFinder, findsNothing);
      final resultCards = find.byType(Card);
      expect(resultCards, findsNWidgets(4));
      final before = [
        for (final e in resultCards.evaluate())
          tester.getTopLeft(find.byWidget(e.widget))
      ];

      pending.complete();
      await tester.pumpAndSettle();

      // A layer, not a list item: the results stay where they were.
      expect(celebrationFinder, findsOneWidget);
      final after = [
        for (final e in find.byType(Card).evaluate().take(4))
          tester.getTopLeft(find.byWidget(e.widget))
      ];
      expect(after, before);
      // The four results; the layer has no card (N28).
      expect(find.byType(Card), findsNWidgets(4));
      final medal = tester.widget<MedalBadge>(find.descendant(
          of: celebrationFinder, matching: find.byType(MedalBadge)));
      expect(medal.asset, MedalArt.welcome);
      expect(medal.disc, MedalCelebration.disc);

      await closeCelebration(tester);
      expect(find.byType(Card), findsNWidgets(4));
      expect(find.text('Start my climb'), findsOneWidget);
    });

    testWidgets('an ordinary completion (not the first ever) shows nothing',
        (tester) async {
      storageService.welcomeBadgeJustEarned = false;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(find.text('Welcome to the climb'), findsNothing);
      expect(find.text('Start my climb'), findsNothing);
      expect(find.text('See your climb'), findsOneWidget);
    });

    testWidgets(
        'an all-skipped result shows no celebration — storage reports '
        'false for it (a step = 0 row never earns the badge)', (tester) async {
      // Mirrors what the real StorageService returns for an all-skipped
      // first test; the earning rule itself is covered in
      // storage_service_climb_test.dart.
      storageService.welcomeBadgeJustEarned = false;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet:
              DailyTestSet(day: '2026-01-01', questions: [questions.first]),
          answers: const {},
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
        ),
      ));
      await tester.pumpAndSettle();

      expect(storageService.completeDailyTestCalls, 1);
      expect(find.text('Welcome to the climb'), findsNothing);
      expect(find.text('Back to Home'), findsOneWidget);
    });

    testWidgets(
        'reopening an already-completed set never shows it, even if the '
        'fake were told to earn it — the save path never runs at all',
        (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      final completedSet = DailyTestSet(
        day: '2026-01-01',
        questions: questions,
        completedAt: DateTime(2026, 1, 1),
        answers: answers,
      );

      await pumpResult(tester, completedSet);

      expect(storageService.completeDailyTestCalls, 0);
      expect(find.text('Welcome to the climb'), findsNothing);
      expect(find.text('Back to Home'), findsOneWidget);
    });

    testWidgets(
        'a failed first attempt shows no celebration; the retry that '
        'actually earns it shows exactly one, not two', (tester) async {
      tallView(tester);
      storageService.failCompletionWith = StateError('disk full');
      storageService.welcomeBadgeJustEarned = true;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );
      expect(find.text('Welcome to the climb'), findsNothing);
      expect(find.text('Start my climb'), findsNothing);

      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to the climb'), findsOneWidget);
      expect(find.text('Start my climb'), findsOneWidget);
    });

    testWidgets('does not gate or delay the way out once saved',
        (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(find.text('Welcome to the climb'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'Day-0 without a badge reads "Continue" and leaves through onDone '
        'at once', (tester) async {
      var left = 0;
      storageService.welcomeBadgeJustEarned = false;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
        isDay0: true,
        onDone: () => left++,
      );

      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('See your climb'), findsNothing);
      await tester.tap(find.text('Continue'));
      await tester.pump();

      expect(left, 1);
      expect(find.byType(ConfettiBurst), findsNothing);
    });
  });

  testWidgets(
      'shows its score via the shared ResultScoreBand widget '
      '(docs/design-audit.md, Batch 0/4 — both result screens must agree '
      'by construction, not by each independently matching the other)',
      (tester) async {
    await pumpResult(
      tester,
      DailyTestSet(day: '2026-01-01', questions: questions),
    );

    expect(find.byType(ResultScoreBand), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultScoreBand),
        matching: find.text('1/4 correct · 1 skipped'),
      ),
      findsOneWidget,
    );
  });

  group('analytics (docs/analytics-plan.md E1/E3)', () {
    Future<void> pumpWith(
      WidgetTester tester, {
      required DailyTestSet set,
      Map<String, String>? withAnswers,
      bool isDay0 = false,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          scaffoldMessengerKey: AppMessenger.key,
          home: DailyTestResultScreen(
            dailyTestSet: set,
            answers: withAnswers ?? answers,
            dailyTestService: dailyTestService,
            analyticsService: analyticsService,
            isDay0: isDay0,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
        'a new completion reports daily_test_completed with exactly the '
        'agreed keys, counts only', (tester) async {
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-01-01', questions: questions),
      );

      final events = analyticsSink.named('daily_test_completed');
      expect(events, hasLength(1));
      expect(events.single.parameters, {
        'correct_count': 1,
        'wrong_count': 2,
        'skipped_count': 1,
        'step_earned': 1,
        'day0': 0,
        'set_source': 'generated',
        'set_date': '2026-01-01',
      });
    });

    testWidgets(
        'a bundled set reports set_source = bundled, a generated one '
        'generated', (tester) async {
      await pumpWith(
        tester,
        set: DailyTestSet(
          day: '2026-01-01',
          questions: questions,
          source: DailyTestSource.bundled,
        ),
        isDay0: true,
      );

      expect(
        analyticsSink
            .named('daily_test_completed')
            .single
            .parameters!['set_source'],
        'bundled',
      );
    });

    for (final source in [DailyTestSource.shared, DailyTestSource.fallback]) {
      testWidgets(
          'a ${source.name} set reports set_source = ${source.name} and its '
          'own day as set_date', (tester) async {
        await pumpWith(
          tester,
          set: DailyTestSet(
            day: '2026-10-01',
            questions: questions,
            source: source,
          ),
        );

        final parameters =
            analyticsSink.named('daily_test_completed').single.parameters!;
        expect(parameters['set_source'], source.name);
        expect(parameters['set_date'], '2026-10-01');
      });
    }

    testWidgets('the Day-0 result screen reports day0 = 1', (tester) async {
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-01-01', questions: questions),
        isDay0: true,
      );

      expect(
        analyticsSink.named('daily_test_completed').single.parameters!['day0'],
        1,
      );
    });

    testWidgets('an all-skipped completion reports step_earned = 0',
        (tester) async {
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-01-01', questions: [questions.first]),
        withAnswers: const {},
      );

      expect(analyticsSink.named('daily_test_completed').single.parameters, {
        'correct_count': 0,
        'wrong_count': 0,
        'skipped_count': 1,
        'step_earned': 0,
        'day0': 0,
        'set_source': 'generated',
        'set_date': '2026-01-01',
      });
      expect(analyticsSink.named('welcome_badge_earned'), isEmpty);
    });

    testWidgets(
        'a failed save reports nothing; the retry that succeeds reports '
        'exactly once', (tester) async {
      storageService.failCompletionWith = StateError('disk full');
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-01-01', questions: questions),
      );
      expect(analyticsSink.events, isEmpty);

      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();

      expect(analyticsSink.named('daily_test_completed'), hasLength(1));
    });

    testWidgets('reopening an already-completed result reports nothing',
        (tester) async {
      await pumpWith(
        tester,
        set: DailyTestSet(
          day: '2026-01-01',
          questions: questions,
          completedAt: DateTime(2026, 1, 1, 9),
          answers: answers,
        ),
      );

      expect(storageService.completeDailyTestCalls, 0);
      expect(analyticsSink.events, isEmpty);
      expect(analyticsSink.userPropertyWrites, isEmpty);
    });

    testWidgets(
        'a live Welcome earn reports welcome_badge_earned from the ledger '
        'day and sets first_step_dom once', (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-02-19', questions: questions),
      );

      final events = analyticsSink.named('welcome_badge_earned');
      expect(events, hasLength(1));
      expect(events.single.parameters, {
        'rule_version': 1,
        'day_of_month': 19,
        'days_in_month': 28,
      });
      expect(analyticsSink.userPropertyWrites, ['first_step_dom']);
      expect(analyticsSink.userProperties['first_step_dom'], '19');
    });

    testWidgets(
        'an ordinary completion never reports Welcome or sets the '
        'user property', (tester) async {
      storageService.welcomeBadgeJustEarned = false;
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(analyticsSink.named('welcome_badge_earned'), isEmpty);
      expect(analyticsSink.userPropertyWrites, isEmpty);
    });

    testWidgets(
        'a retry after a failed first attempt earns and reports '
        'Welcome exactly once', (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      storageService.failCompletionWith = StateError('disk full');
      await pumpWith(
        tester,
        set: DailyTestSet(day: '2026-01-01', questions: questions),
      );
      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();

      expect(analyticsSink.named('welcome_badge_earned'), hasLength(1));
      expect(analyticsSink.userPropertyWrites, ['first_step_dom']);
    });
  });

  testWidgets('a double tap on Continue leaves once, not twice',
      (tester) async {
    var left = 0;
    storageService.welcomeBadgeJustEarned = false;
    await pumpResult(
      tester,
      DailyTestSet(day: '2026-01-01', questions: questions),
      isDay0: true,
      onDone: () => left++,
    );

    await tester.tap(find.text('Continue'));
    await tester.tap(find.text('Continue'), warnIfMissed: false);
    await tester.pump();

    expect(left, 1);
  });

  group('N28, N36: the celebration layer and "Start my climb" (Batch 5)', () {
    final burst = find.byType(ConfettiBurst);
    final button = find.byType(FilledButton);
    var left = 0;

    setUp(() => left = 0);

    DailyTestSet freshSet() =>
        DailyTestSet(day: '2026-01-01', questions: questions);

    void tallView(WidgetTester tester) {
      tester.view.physicalSize = const Size(400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    void reduceMotion(WidgetTester tester, bool value) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: value);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    /// Pumps a Day-0 style result screen (left through [onDone]) whose save
    /// earns the badge, and lets everything settle. The celebration opens
    /// with its own burst (N15); unless [keepCelebration], it is closed
    /// here, so what follows sees only the button's burst.
    Future<void> pumpEarned(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      bool muteTickers = false,
      bool keepCelebration = false,
      DailyTestSet? set,
    }) async {
      storageService.welcomeBadgeJustEarned = true;
      Widget app = MaterialApp(
        theme: buildAppTheme(brightness),
        scaffoldMessengerKey: AppMessenger.key,
        home: DailyTestResultScreen(
          dailyTestSet: set ?? freshSet(),
          answers: answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
          isDay0: true,
          onDone: () => left++,
        ),
      );
      if (muteTickers) app = TickerMode(enabled: false, child: app);
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();
      if (!keepCelebration && celebrationFinder.evaluate().isNotEmpty) {
        await closeCelebration(tester);
      }
    }

    testWidgets(
        'earning the badge opens the layer with one burst from its medal; '
        'once it is closed nothing plays', (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet: freshSet(),
          answers: answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
          isDay0: true,
          onDone: () => left++,
        ),
      ));
      await tester.pump();
      await tester.pump();
      expect(celebrationFinder, findsOneWidget);
      expect(find.descendant(of: celebrationFinder, matching: burst),
          findsOneWidget);
      final origin = tester.widget<ConfettiBurst>(burst).origin;
      final medal = tester.getRect(find.byType(MedalBadge));
      expect(origin.dx, closeTo(medal.center.dx, 1));
      expect(origin.dy, closeTo(medal.center.dy, 1));
      await tester.pumpAndSettle();
      await closeCelebration(tester);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(burst, findsNothing);
      }
      expect(left, 0);
    });

    testWidgets(
        'N36: "Start my climb" plays no confetti: it leaves at once, once',
        (tester) async {
      tallView(tester);
      await pumpEarned(tester);
      expect(find.text('Start my climb'), findsOneWidget);
      await tester.tap(find.text('Start my climb'));
      await tester.pump();
      expect(burst, findsNothing);
      expect(left, 1);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump(const Duration(seconds: 3));
      expect(left, 1);
    });

    testWidgets(
        'N28: the dark layer, the medal large in the middle, light text; the '
        'same in light and dark mode', (tester) async {
      tallView(tester);
      for (final b in Brightness.values) {
        await pumpEarned(tester, brightness: b, keepCelebration: true);
        final material = tester.widget<Material>(find
            .descendant(of: celebrationFinder, matching: find.byType(Material))
            .first);
        expect(material.color, MedalCelebration.scrim);
        expect(
            tester
                .widget<MedalBadge>(find.descendant(
                    of: celebrationFinder, matching: find.byType(MedalBadge)))
                .disc,
            MedalCelebration.disc);
        final title = tester.widget<Text>(find.text('Welcome to the climb'));
        expect(title.style!.color, Colors.white);
        final rays = tester.widget<CustomPaint>(find.descendant(
            of: celebrationFinder,
            matching: find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is CelebrationRays)));
        expect((rays.painter! as CelebrationRays).colour,
            MedalCelebration.welcomeOrange);
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('N28: the rays turn slowly for a while, then rest',
        (tester) async {
      tallView(tester);
      await pumpEarned(tester, keepCelebration: true);
      double turn() => (tester
              .widget<CustomPaint>(find.descendant(
                  of: celebrationFinder,
                  matching: find.byWidgetPredicate(
                      (w) => w is CustomPaint && w.painter is CelebrationRays)))
              .painter! as CelebrationRays)
          .turn;
      // pumpAndSettle in pumpEarned ran them to the end: they rest there.
      expect(turn(), closeTo(MedalCelebration.raysAngle, 1e-9));
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('N28: the close is a short shrink and fade', (tester) async {
      tallView(tester);
      await pumpEarned(tester, keepCelebration: true);
      await tester.tap(celebrationFinder);
      await tester.pump();
      await tester.pump(MedalCelebration.close ~/ 2);
      final opacity =
          tester.widget<Opacity>(find.byKey(MedalCelebration.fadeKey));
      expect(opacity.opacity, inExclusiveRange(0, 1));
      final scale =
          tester.widget<Transform>(find.byKey(MedalCelebration.scaleKey));
      expect(scale.transform.entry(0, 0), lessThan(1));
      await tester.pump(MedalCelebration.close);
      await tester.pump();
      expect(celebrationFinder, findsNothing);
      expect(find.text('Start my climb'), findsOneWidget);
    });

    testWidgets(
        'Reduce Motion: no confetti, no fade in, no turning; the close is a '
        'fade only; the button leaves at once', (tester) async {
      tallView(tester);
      reduceMotion(tester, true);
      await pumpEarned(tester, keepCelebration: true);
      expect(celebrationFinder, findsOneWidget);
      expect(burst, findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      final opacity =
          tester.widget<Opacity>(find.byKey(MedalCelebration.fadeKey));
      expect(opacity.opacity, 1);
      await tester.tap(celebrationFinder);
      await tester.pump();
      await tester.pump(MedalCelebration.close ~/ 2);
      expect(
          tester
              .widget<Transform>(find.byKey(MedalCelebration.scaleKey))
              .transform
              .entry(0, 0),
          1);
      await tester.pump(MedalCelebration.close);
      await tester.pump();
      expect(celebrationFinder, findsNothing);
      await tester.tap(find.text('Start my climb'));
      await tester.pump();
      expect(burst, findsNothing);
      expect(left, 1);
    });

    testWidgets(
        'a failed first attempt plays nothing; the retry that earns it opens '
        'the layer once', (tester) async {
      tallView(tester);
      storageService.failCompletionWith = StateError('disk full');
      await pumpEarned(tester);
      expect(burst, findsNothing);
      expect(celebrationFinder, findsNothing);
      expect(find.text('Start my climb'), findsNothing);

      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();
      await closeCelebration(tester);
      expect(find.text('Start my climb'), findsOneWidget);
    });

    testWidgets('the layer fades in over 200 ms instead of jumping',
        (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet: freshSet(),
          answers: answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
        ),
      ));
      await tester.pump();
      await tester.pump();
      double opacity() =>
          tester.widget<Opacity>(find.byKey(MedalCelebration.fadeKey)).opacity;
      expect(opacity(), lessThan(1));
      await tester.pump(MedalCelebration.fadeIn);
      expect(opacity(), 1);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'closing it never replays it: scrolling the results and waiting '
        'play nothing, and it does not come back', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpEarned(tester);

      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      scroll.jumpTo(0);
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        expect(burst, findsNothing);
        expect(celebrationFinder, findsNothing);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('from Home: "Start my climb" pops the route at once',
        (tester) async {
      tallView(tester);
      storageService.welcomeBadgeJustEarned = true;
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => DailyTestResultScreen(
                  dailyTestSet: freshSet(),
                  answers: answers,
                  dailyTestService: dailyTestService,
                  analyticsService: analyticsService,
                ),
              )),
              child: const Text('open results'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open results'));
      await tester.pumpAndSettle();
      await closeCelebration(tester);
      await tester.tap(find.text('Start my climb'));
      await tester.pumpAndSettle();
      expect(find.text('open results'), findsOneWidget);
      expect(find.text('Daily Test Results'), findsNothing);
      expect(burst, findsNothing);
    });

    test('N28: each tier has its glow colour; Welcome the brand orange', () {
      expect(MedalCelebration.glowFor(MedalTier.gold), MedalCelebration.gold);
      expect(
          MedalCelebration.glowFor(MedalTier.silver), MedalCelebration.silver);
      expect(
          MedalCelebration.glowFor(MedalTier.bronze), MedalCelebration.copper);
      expect(MedalCelebration.glowFor(null), MedalCelebration.welcomeOrange);
    });
  });

  group('N15, N24, N29: a tier earned (Batch 5)', () {
    // The fixture's completion: one step, 1 correct + 2 wrong = 4 points.
    DailyTestSet setOn(String day) =>
        DailyTestSet(day: day, questions: questions);
    void monthAfter(int score) => storageService.monthAfter =
        (steps: 15, correct: score ~/ 2, wrong: score % 2, skipped: 0);
    final burst = find.byType(ConfettiBurst);

    for (final tier in MedalTier.values) {
      testWidgets(
          '${tier.label}: the completion that crosses it opens the '
          'celebration once, and one tap shows the results', (tester) async {
        monthAfter(MonthlyMedalRules.threshold(2026, 10, tier));
        await pumpResult(tester, setOn('2026-10-20'));

        expect(
            find.descendant(
                of: celebrationFinder,
                matching: find.text('October · Green Slope')),
            findsOneWidget);
        expect(
            find.descendant(
                of: celebrationFinder,
                matching: find.text(MedalCelebration.closeHint)),
            findsOneWidget);
        final medal = tester.widget<MedalBadge>(find.descendant(
            of: celebrationFinder, matching: find.byType(MedalBadge)));
        expect(medal.asset, MedalArt.monthly('green_slope', tier));
        expect(medal.earned, isTrue);

        await closeCelebration(tester, title: '${tier.label} medal earned');
        expect(find.text('See your climb'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(celebrationFinder, findsNothing);
      });
    }

    testWidgets("the month's own theme: a November set is Ember Peak's",
        (tester) async {
      monthAfter(MonthlyMedalRules.threshold(2026, 11, MedalTier.silver));
      await pumpResult(tester, setOn('2026-11-18'));
      expect(find.text('November · Ember Peak'), findsOneWidget);
      expect(
          tester
              .widget<MedalBadge>(find.descendant(
                  of: celebrationFinder, matching: find.byType(MedalBadge)))
              .asset,
          MedalArt.monthly('ember_peak', MedalTier.silver));
    });

    testWidgets('below Bronze after the completion: nothing', (tester) async {
      monthAfter(MonthlyMedalRules.threshold(2026, 10, MedalTier.bronze) - 1);
      await pumpResult(tester, setOn('2026-10-20'));
      expect(celebrationFinder, findsNothing);
      expect(find.text('See your climb'), findsOneWidget);
    });

    testWidgets('a tier already reached before the completion: nothing',
        (tester) async {
      // Bronze exactly before these 4 points.
      monthAfter(MonthlyMedalRules.threshold(2026, 10, MedalTier.bronze) + 4);
      await pumpResult(tester, setOn('2026-10-20'));
      expect(celebrationFinder, findsNothing);
    });

    testWidgets(
        'N24: a late completion of a month already finalized is not '
        'celebrated', (tester) async {
      monthAfter(MonthlyMedalRules.threshold(2026, 10, MedalTier.gold));
      storageService.finalized.add((2026, 10));
      await pumpResult(tester, setOn('2026-10-31'));
      expect(storageService.completeDailyTestCalls, 1);
      expect(celebrationFinder, findsNothing);
    });

    testWidgets('a reopened, already-completed set never plays it again',
        (tester) async {
      monthAfter(MonthlyMedalRules.threshold(2026, 10, MedalTier.gold));
      await pumpResult(
          tester,
          DailyTestSet(
              day: '2026-10-20',
              questions: questions,
              completedAt: DateTime(2026, 10, 20),
              answers: answers));
      expect(storageService.completeDailyTestCalls, 0);
      expect(celebrationFinder, findsNothing);
    });

    testWidgets('Reduce Motion: no confetti, no fade', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      monthAfter(MonthlyMedalRules.threshold(2026, 10, MedalTier.bronze));
      await pumpResult(tester, setOn('2026-10-20'));
      expect(celebrationFinder, findsOneWidget);
      expect(burst, findsNothing);
      await closeCelebration(tester, title: 'Bronze medal earned');
    });

    testWidgets('with motion the burst comes from the medal at the opening',
        (tester) async {
      monthAfter(MonthlyMedalRules.threshold(2026, 10, MedalTier.gold));
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: DailyTestResultScreen(
          dailyTestSet: setOn('2026-10-20'),
          answers: answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }
      expect(find.descendant(of: celebrationFinder, matching: burst),
          findsOneWidget);
      await tester.pumpAndSettle();
      await closeCelebration(tester, title: 'Gold medal earned');
    });
  });

  group('N21: save_point_reached and medal_tier_reached (Batch 5)', () {
    DailyTestSet setOn(String day) =>
        DailyTestSet(day: day, questions: questions);
    void monthAfter({required int steps, required int score}) =>
        storageService.monthAfter =
            (steps: steps, correct: score ~/ 2, wrong: score % 2, skipped: 0);

    testWidgets(
        'one completion that reaches a save point and crosses a tier sends '
        'one of each, with the set\'s month and theme', (tester) async {
      // October 2026 (31 days, Green Slope): Halfway Hut on step 15, Silver
      // at 155.
      monthAfter(steps: 15, score: 155);
      await pumpResult(tester, setOn('2026-10-20'));
      expect(analyticsSink.named('save_point_reached').single.parameters, {
        'theme_id': 'green_slope',
        'save_point': 'halfway_hut',
        'step': 15,
        'days_in_month': 31,
      });
      expect(analyticsSink.named('medal_tier_reached').single.parameters, {
        'theme_id': 'green_slope',
        'tier': 'silver',
        'day_of_month': 20,
        'days_in_month': 31,
        'active_days': 15,
        'rule_version': 1,
      });
      // Not again: the result stays, nothing re-reports.
      await closeCelebration(tester, title: 'Silver medal earned');
      await tester.pump(const Duration(seconds: 5));
      expect(analyticsSink.named('save_point_reached'), hasLength(1));
      expect(analyticsSink.named('medal_tier_reached'), hasLength(1));
    });

    testWidgets('the flag: summit on the month\'s last step, Ember Peak',
        (tester) async {
      monthAfter(steps: 30, score: 100);
      await pumpResult(tester, setOn('2026-11-30'));
      expect(analyticsSink.named('save_point_reached').single.parameters, {
        'theme_id': 'ember_peak',
        'save_point': 'summit',
        'step': 30,
        'days_in_month': 30,
      });
      expect(analyticsSink.named('medal_tier_reached'), isEmpty);
    });

    testWidgets('a step that reaches nothing and crosses nothing sends neither',
        (tester) async {
      monthAfter(steps: 9, score: 40);
      await pumpResult(tester, setOn('2026-10-20'));
      expect(analyticsSink.named('daily_test_completed'), hasLength(1));
      expect(analyticsSink.named('save_point_reached'), isEmpty);
      expect(analyticsSink.named('medal_tier_reached'), isEmpty);
    });

    testWidgets('N24: none for a late completion of a finalized month',
        (tester) async {
      monthAfter(steps: 15, score: 155);
      storageService.finalized.add((2026, 10));
      await pumpResult(tester, setOn('2026-10-31'));
      expect(analyticsSink.named('daily_test_completed'), hasLength(1));
      expect(analyticsSink.named('save_point_reached'), isEmpty);
      expect(analyticsSink.named('medal_tier_reached'), isEmpty);
    });

    testWidgets('none for a reopened result, none for a failed save',
        (tester) async {
      monthAfter(steps: 15, score: 155);
      await pumpResult(
          tester,
          DailyTestSet(
              day: '2026-10-20',
              questions: questions,
              completedAt: DateTime(2026, 10, 20),
              answers: answers));
      expect(analyticsSink.named('save_point_reached'), isEmpty);
      await tester.pumpWidget(const SizedBox());
      storageService.failCompletionWith = StateError('disk full');
      await pumpResult(tester, setOn('2026-10-20'));
      expect(analyticsSink.named('save_point_reached'), isEmpty);
      expect(analyticsSink.named('medal_tier_reached'), isEmpty);
    });
  });

  group('the confetti itself', () {
    test('the same seed always gives the same fan, another seed another', () {
      final a = buildConfettiParticles(seed: 5);
      final b = buildConfettiParticles(seed: 5);
      final c = buildConfettiParticles(seed: 6);

      expect(a, hasLength(40));
      for (var i = 0; i < a.length; i++) {
        expect(a[i].angle, b[i].angle);
        expect(a[i].speed, b[i].speed);
        expect(a[i].size, b[i].size);
      }
      expect(a.map((p) => p.angle), isNot(c.map((p) => p.angle)));
    });

    test('every piece starts at the origin and is thrown upward first', () {
      const origin = Offset(100, 200);
      for (final p in buildConfettiParticles()) {
        expect(ConfettiPainter.positionAt(p, origin, 0), origin);
        final early = ConfettiPainter.positionAt(p, origin, 0.1);
        expect(early.dy, lessThan(origin.dy));
        expect(early.dx.isFinite && early.dy.isFinite, isTrue);
        // Gravity wins in the end: it is below where it started.
        expect(ConfettiPainter.positionAt(p, origin, 1.8).dy,
            greaterThan(origin.dy));
      }
    });

    test('fully visible for the first 60%, then fades to nothing', () {
      expect(ConfettiPainter.opacityAt(0), 1);
      expect(ConfettiPainter.opacityAt(0.6), 1);
      expect(ConfettiPainter.opacityAt(0.8), closeTo(0.5, 1e-9));
      expect(ConfettiPainter.opacityAt(1), 0);
    });
  });
}
