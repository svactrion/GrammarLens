import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/fallback_pool.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_tools.dart';

import 'support/recording_analytics_sink.dart';

/// Fails the first [failCount] shared-set reads, then serves a shared set —
/// simulates the read failing (offline, a timeout, a bad response) without a
/// real proxy.
class _FlakyClaudeService extends ClaudeService {
  int callCount = 0;
  final int failCount;

  _FlakyClaudeService({required this.failCount});

  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async {
    callCount++;
    if (callCount <= failCount) {
      throw const ClaudeApiException('simulated read failure',
          kind: ClaudeApiErrorKind.network);
    }
    return List.generate(
      DailyTestSet.questionCount,
      (i) => DailyTestQuestion(
        item: PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question $i',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'answer$i',
        commonWrongAnswers: const [],
      ),
    );
  }
}

/// Answers every read with a quota-exceeded error: the read route never
/// sends one, but the screen must not show "Today's limit reached" even if
/// it did.
class _QuotaExceededClaudeService extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async {
    throw const ClaudeApiException(
      "You've reached today's practice limit on this device. Please try "
      'again tomorrow.',
      kind: ClaudeApiErrorKind.quotaExceeded,
    );
  }
}

/// An in-memory double for the handful of StorageService methods
/// DailyTestService actually touches. Real sqlite via sqflite_common_ffi
/// works fine in a plain `test()` (see daily_test_service_test.dart) but
/// hangs indefinitely inside `testWidgets()`'s fake-async test binding —
/// same reasoning and same shape as first_launch_flow_test.dart's own
/// fake, which hit and documented this exact issue first.
class _FakeStorageService extends StorageService {
  DailyTestSet? todaysSet;

  /// Saves that fail before one succeeds: the one failure left that can
  /// keep the Daily Test from opening (a shared read failure falls back).
  int saveFailuresLeft = 0;

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => todaysSet;

  @override
  Future<DailyTestSet?> getDailyTestSet(String day) =>
      getDailyTestSetForToday();

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<DailyTestSet> saveDailyTestSet(List<DailyTestQuestion> questions,
      {String? day, DailyTestSource source = DailyTestSource.generated}) async {
    if (saveFailuresLeft > 0) {
      saveFailuresLeft--;
      throw StateError('simulated storage failure');
    }
    final set =
        DailyTestSet(day: '2026-01-01', questions: questions, source: source);
    todaysSet = set;
    return set;
  }

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';
}

void main() {
  late _FakeStorageService storageService;

  setUp(() {
    storageService = _FakeStorageService();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    DailyTestService service, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
          theme: theme,
          home: DailyTestScreen(
            dailyTestService: service,
            analyticsService: AnalyticsService(sink: RecordingAnalyticsSink()),
          )),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the answer field turns off autocorrect, suggestions and smart '
    'punctuation, so the keyboard cannot fix the learner\'s mistake',
    (tester) async {
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );
      await pumpScreen(tester, service);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autocorrect, isFalse);
      expect(field.enableSuggestions, isFalse);
      expect(field.smartQuotesType, SmartQuotesType.disabled);
      expect(field.smartDashesType, SmartDashesType.disabled);
    },
  );

  testWidgets(
    'a failed shared read opens the fallback questions, never an error '
    'screen (docs/1.1.0-shared-daily-test.md §5)',
    (tester) async {
      final claudeService = _FlakyClaudeService(failCount: 1);
      final service = DailyTestService(
        claudeService: claudeService,
        storageService: storageService,
        fallbackPool: FallbackPool.withSets(const []),
      );

      await pumpScreen(tester, service);

      expect(claudeService.callCount, 1);
      expect(find.text("Couldn't load today's test"), findsNothing);
      expect(find.text('Try again'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(storageService.todaysSet!.source, DailyTestSource.fallback);
      expect(storageService.todaysSet!.questions.map((q) => q.item.id),
          kDayZeroQuestions.map((q) => q.item.id));
    },
  );

  testWidgets('a readable shared set is what the screen shows', (tester) async {
    final service = DailyTestService(
      claudeService: _FlakyClaudeService(failCount: 0),
      storageService: storageService,
    );

    await pumpScreen(tester, service);

    expect(find.text('Question 0'), findsOneWidget);
    expect(storageService.todaysSet!.source, DailyTestSource.shared);
  });

  testWidgets(
    'a load failure (local storage) shows an in-screen error with a human '
    'sentence and a Try again action, not a SnackBar',
    (tester) async {
      storageService.saveFailuresLeft = 1;
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );

      await pumpScreen(tester, service);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text("Couldn't load today's test"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets('Try again really retries and can succeed', (tester) async {
    storageService.saveFailuresLeft = 1;
    final claudeService = _FlakyClaudeService(failCount: 0);
    final service = DailyTestService(
      claudeService: claudeService,
      storageService: storageService,
    );

    await pumpScreen(tester, service);
    expect(find.text('Try again'), findsOneWidget);
    expect(claudeService.callCount, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(claudeService.callCount, 2);
    expect(find.text('Try again'), findsNothing);
    expect(find.text('Question 0'), findsOneWidget);
  });

  testWidgets(
    'Try again can fail again and still shows the error state, not a crash',
    (tester) async {
      storageService.saveFailuresLeft = 2;
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );

      await pumpScreen(tester, service);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets('the technical error detail is shown in this (debug) build',
      (tester) async {
    storageService.saveFailuresLeft = 5;
    final service = DailyTestService(
      claudeService: _FlakyClaudeService(failCount: 0),
      storageService: storageService,
    );

    await pumpScreen(tester, service);

    expect(find.textContaining('simulated storage failure'), findsOneWidget);
  });

  testWidgets('a release build never shows the technical error detail',
      (tester) async {
    DebugTools.enabledForTesting = false;
    addTearDown(() => DebugTools.enabledForTesting = true);
    storageService.saveFailuresLeft = 5;
    final service = DailyTestService(
      claudeService: _FlakyClaudeService(failCount: 0),
      storageService: storageService,
    );

    await pumpScreen(tester, service);

    // The human message and retry stay; the raw exception text does not.
    expect(find.text("Couldn't load today's test"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('simulated storage failure'), findsNothing);
  });

  group('Skip is never the primary action (docs/design-audit.md D3)', () {
    testWidgets(
        'with an empty answer, the primary button reads Next/Finish, '
        'disabled — never "Skip"', (tester) async {
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );

      await pumpScreen(tester, service);

      expect(find.widgetWithText(FilledButton, 'Skip'), findsNothing);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(button.onPressed, isNull);
      // Still reachable, just quiet — not gone.
      expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);
    });

    testWidgets('entering an answer enables the primary button',
        (tester) async {
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );

      await pumpScreen(tester, service);
      await tester.enterText(find.byType(TextField), 'answer0');
      await tester.pump();

      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Next'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets(
        'tapping Skip with an empty answer still advances to the '
        'next question', (tester) async {
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );

      await pumpScreen(tester, service);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1'), findsOneWidget);
    });
  });

  testWidgets(
      'a quota error from the proxy opens the fallback, never "Today\'s '
      'limit reached": the read route has no quota', (tester) async {
    final service = DailyTestService(
      claudeService: _QuotaExceededClaudeService(),
      storageService: storageService,
    );

    await pumpScreen(tester, service);

    expect(find.text("Today's limit reached"), findsNothing);
    expect(find.byType(TextField), findsOneWidget);
    expect(storageService.todaysSet!.source, DailyTestSource.fallback);
  });

  for (final brightness in Brightness.values) {
    group('"Leave Daily Test?" dialog ($brightness)', () {
      Color? fill(ButtonStyleButton b) =>
          b.style?.backgroundColor?.resolve(const {});
      Color? label(ButtonStyleButton b) =>
          b.style?.foregroundColor?.resolve(const {});
      Color? border(ButtonStyleButton b) =>
          b.style?.side?.resolve(const {})?.color;

      Future<void> openDialog(WidgetTester tester) async {
        final service = DailyTestService(
          claudeService: _FlakyClaudeService(failCount: 0),
          storageService: storageService,
        );
        await pumpScreen(tester, service, theme: buildAppTheme(brightness));
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Leave Daily Test?'), findsOneWidget);
        expect(find.text('Your progress will be lost.'), findsOneWidget);
      }

      testWidgets('Leave is destructive, Cancel is neutral and not primary',
          (tester) async {
        await openDialog(tester);
        final scheme = buildAppTheme(brightness).colorScheme;

        final leave = tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Leave'));
        expect(fill(leave), scheme.destructive);
        expect(label(leave), scheme.onDestructive);

        final cancel = tester.widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Cancel'));
        expect(label(cancel), scheme.onSurface);
        expect(label(cancel), isNot(scheme.primary));
        expect(border(cancel), scheme.onSurfaceVariant);
        expect(border(cancel), isNot(scheme.primary));
        expect(fill(cancel), isNull);
      });

      testWidgets('Cancel keeps the test open', (tester) async {
        await openDialog(tester);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Leave Daily Test?'), findsNothing);
        expect(find.byType(DailyTestScreen), findsOneWidget);
      });
    });
  }
}
