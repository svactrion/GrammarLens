import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/confetti_burst.dart';
import 'package:grammar_lens/widgets/result_score_band.dart';

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
        'result footer waits for saving, retries failure, and fits large text in $brightness',
        (tester) async {
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
      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      expect(find.text('Saving your results…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      pending.complete();
      await tester.pumpAndSettle();
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      expect(find.text('See your climb'), findsNothing);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      storageService.failCompletionWith = null;
      await tester.tap(find.text('Retry saving'));
      await tester.pumpAndSettle();
      expect(find.text('See your climb'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull);
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
    await tester.scrollUntilVisible(find.text('Back to Home'), 200);
    expect(find.text('See your climb'), findsNothing);
    expect(storageService.completeDailyTestCalls, 1);
  });

  Future<void> pumpResult(WidgetTester tester, DailyTestSet set) async {
    await tester.pumpWidget(
      MaterialApp(
        // Reads SemanticColors off the theme.
        theme: buildAppTheme(Brightness.light),
        // Wired the same way app.dart does, so a completion failure's
        // AppMessenger.show call actually has a messenger to reach.
        scaffoldMessengerKey: AppMessenger.key,
        home: DailyTestResultScreen(
          dailyTestSet: set,
          answers: answers,
          dailyTestService: dailyTestService,
          analyticsService: analyticsService,
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
    testWidgets(
        'a completion that just earned the badge shows the one-time '
        'celebration, exactly once', (tester) async {
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

    testWidgets('an ordinary completion (not the first ever) shows nothing',
        (tester) async {
      storageService.welcomeBadgeJustEarned = false;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(find.text('Welcome to the climb'), findsNothing);
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
    });

    testWidgets(
        'a failed first attempt shows no celebration; the retry that '
        'actually earns it shows exactly one, not two', (tester) async {
      storageService.failCompletionWith = StateError('disk full');
      storageService.welcomeBadgeJustEarned = true;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );
      expect(find.text('Welcome to the climb'), findsNothing);

      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to the climb'), findsOneWidget);
    });

    testWidgets('does not gate or delay the existing "See your climb" CTA',
        (tester) async {
      storageService.welcomeBadgeJustEarned = true;

      await pumpResult(
        tester,
        DailyTestSet(day: '2026-01-01', questions: questions),
      );

      expect(find.text('Welcome to the climb'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('See your climb'), 300);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
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

  group('Welcome confetti (one-time, overlay, no package)', () {
    final burst = find.byType(ConfettiBurst);

    /// Pumps without settling, so the confetti can be observed while it plays.
    Future<void> pumpUnsettled(
      WidgetTester tester,
      DailyTestSet set, {
      Brightness brightness = Brightness.light,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(brightness),
          scaffoldMessengerKey: AppMessenger.key,
          home: DailyTestResultScreen(
            dailyTestSet: set,
            answers: answers,
            dailyTestService: dailyTestService,
            analyticsService: analyticsService,
          ),
        ),
      );
      // The save runs from initState; one frame lets it land and the
      // post-frame callback that starts the confetti run.
      await tester.pump();
      await tester.pump();
    }

    DailyTestSet freshSet() =>
        DailyTestSet(day: '2026-01-01', questions: questions);

    void reduceMotion(WidgetTester tester, bool value) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: value);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }

    testWidgets(
        'earning the badge throws one burst from the banner, about 1.8 s, '
        'and then it is gone', (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());

      expect(burst, findsOneWidget);
      // (An item with no height yet counts as offstage to finders, so give the
      // banner a moment to take its first bit of space.)
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Welcome to the climb'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 950));
      expect(burst, findsOneWidget, reason: 'still playing at 1.0 s');
      await tester.pump(const Duration(milliseconds: 900));
      expect(burst, findsNothing, reason: 'finished by 1.9 s');
      expect(ConfettiBurst.duration, const Duration(milliseconds: 1800));
      // The banner itself stays.
      expect(find.text('Welcome to the climb'), findsOneWidget);
    });

    testWidgets('it starts from the banner, not from a corner', (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());
      await tester.pump(const Duration(milliseconds: 400));

      final origin = tester.widget<ConfettiBurst>(burst).origin;
      final banner = tester.getRect(find.byType(Card).first);
      expect(origin.dx, closeTo(banner.center.dx, 1));
      expect(origin.dy, greaterThan(banner.top - 1));
      expect(origin.dy, lessThan(banner.bottom + 1));
    });

    testWidgets("it uses the theme's own colors, light and dark",
        (tester) async {
      for (final brightness in Brightness.values) {
        storageService.welcomeBadgeJustEarned = true;
        await pumpUnsettled(tester, freshSet(), brightness: brightness);
        final scheme = buildAppTheme(brightness).colorScheme;

        expect(tester.widget<ConfettiBurst>(burst).colors,
            [scheme.primary, scheme.secondary, scheme.tertiary]);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    });

    for (final scenario in [
      (
        name: 'an ordinary completion',
        earned: false,
        set: () => DailyTestSet(day: '2026-01-01', questions: questions),
      ),
      (
        name: 'reopening an already-completed set',
        earned: true,
        set: () => DailyTestSet(
              day: '2026-01-01',
              questions: questions,
              completedAt: DateTime(2026, 1, 1),
              answers: answers,
            ),
      ),
    ]) {
      testWidgets('no confetti for ${scenario.name}', (tester) async {
        storageService.welcomeBadgeJustEarned = scenario.earned;
        await pumpUnsettled(tester, scenario.set());
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          expect(burst, findsNothing);
        }
        expect(find.text('Welcome to the climb'), findsNothing);
      });
    }

    testWidgets(
        'a failed first attempt throws nothing; the retry that earns it '
        'throws exactly one', (tester) async {
      storageService.failCompletionWith = StateError('disk full');
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());
      expect(burst, findsNothing);

      storageService.failCompletionWith = null;
      await tester.tap(find.text('Try saving again'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(burst, findsOneWidget);
    });

    testWidgets(
        'reduced motion: no confetti at all, and the banner simply appears',
        (tester) async {
      reduceMotion(tester, true);
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());

      expect(burst, findsNothing);
      // At once, in one frame: no size or fade animation to wait for.
      expect(find.text('Welcome to the climb'), findsOneWidget);
      expect(find.byType(AnimatedSize), findsNothing);
      expect(find.byType(AnimatedOpacity), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(burst, findsNothing);
    });

    testWidgets('the banner eases in (fade and size) instead of jumping',
        (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());

      final fadeFinder = find.descendant(
          of: find.byType(AnimatedOpacity, skipOffstage: false),
          matching: find.byType(FadeTransition, skipOffstage: false));
      final size = find.byType(AnimatedSize, skipOffstage: false);
      final fade = tester.widget<FadeTransition>(fadeFinder);
      expect(fade.opacity.value, lessThan(1));
      final earlyHeight = tester.getSize(size).height;
      await tester.pump(const Duration(milliseconds: 400));
      expect(fade.opacity.value, 1);
      expect(tester.getSize(size).height, greaterThan(earlyHeight));
    });

    testWidgets(
        'scrolling away and back never replays it: the banner comes back '
        'already in place, with no new burst', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());
      await tester.pump(const Duration(milliseconds: 2000));
      expect(burst, findsNothing);

      final scroll =
          tester.state<ScrollableState>(find.byType(Scrollable).first).position;
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      scroll.jumpTo(0);
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(burst, findsNothing);
      }
      expect(find.text('Welcome to the climb'), findsOneWidget);
      final fade = tester.widget<FadeTransition>(find.descendant(
          of: find.byType(AnimatedOpacity),
          matching: find.byType(FadeTransition)));
      expect(fade.opacity.value, 1);
    });

    testWidgets(
        'leaving the screen mid-burst removes it at once, with nothing left '
        'running and no error', (tester) async {
      storageService.welcomeBadgeJustEarned = true;
      await pumpUnsettled(tester, freshSet());
      await tester.pump(const Duration(milliseconds: 500));
      expect(burst, findsOneWidget);

      await tester.pumpWidget(MaterialApp(home: Container()));
      await tester.pump();
      expect(burst, findsNothing);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
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
