import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Fails the first [failCount] calls, then succeeds — simulates a
/// transient generation failure (a bad API response, a network error, the
/// schema-mismatch bug fixed in a previous batch) so a test can drive
/// DailyTestScreen's retry path without a real API key.
class _FlakyClaudeService extends ClaudeService {
  int callCount = 0;
  final int failCount;

  _FlakyClaudeService({required this.failCount});

  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
    callCount++;
    if (callCount <= failCount) {
      throw const FormatException('simulated generation failure');
    }
    return List.generate(
      count,
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

/// Always throws a quota-exceeded ClaudeApiException, simulating the
/// proxy's 429 response once the device/global daily cap is reached.
class _QuotaExceededClaudeService extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
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

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => todaysSet;

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      const [];

  @override
  Future<DailyTestSet> saveDailyTestSet(
    List<DailyTestQuestion> questions,
  ) async {
    final set = DailyTestSet(day: '2026-01-01', questions: questions);
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
    DailyTestService service,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: DailyTestScreen(dailyTestService: service)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a load failure shows an in-screen error with a human sentence and a '
    'Try again action, not a SnackBar',
    (tester) async {
      final claudeService = _FlakyClaudeService(failCount: 1);
      final service = DailyTestService(
        claudeService: claudeService,
        storageService: storageService,
      );

      await pumpScreen(tester, service);

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text("Couldn't load today's test"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets('Try again really retries and can succeed', (tester) async {
    final claudeService = _FlakyClaudeService(failCount: 1);
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
      final claudeService = _FlakyClaudeService(failCount: 2);
      final service = DailyTestService(
        claudeService: claudeService,
        storageService: storageService,
      );

      await pumpScreen(tester, service);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(claudeService.callCount, 2);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets(
    "a failed attempt is never cached as today's test — retrying gets a "
    'real generation attempt, and only a real success gets cached',
    (tester) async {
      final claudeService = _FlakyClaudeService(failCount: 1);
      final service = DailyTestService(
        claudeService: claudeService,
        storageService: storageService,
      );

      await pumpScreen(tester, service);
      expect(storageService.todaysSet, isNull);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(storageService.todaysSet, isNotNull);
      expect(storageService.todaysSet!.questions, hasLength(5));
    },
  );

  testWidgets('the technical error detail is shown in this (debug) build',
      (tester) async {
    final claudeService = _FlakyClaudeService(failCount: 5);
    final service = DailyTestService(
      claudeService: claudeService,
      storageService: storageService,
    );

    await pumpScreen(tester, service);

    expect(find.textContaining('simulated generation failure'), findsOneWidget);
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
      expect(find.widgetWithText(TextButton, 'Skip'), findsOneWidget);
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

    testWidgets('tapping Skip with an empty answer still advances to the '
        'next question', (tester) async {
      final service = DailyTestService(
        claudeService: _FlakyClaudeService(failCount: 0),
        storageService: storageService,
      );

      await pumpScreen(tester, service);
      await tester.tap(find.widgetWithText(TextButton, 'Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Question 1'), findsOneWidget);
    });
  });

  group('quota exceeded (Cloudflare Workers proxy 429)', () {
    testWidgets(
        'shows accurate copy, not the generic "check your connection" '
        'message — retrying can\'t succeed until tomorrow', (tester) async {
      final service = DailyTestService(
        claudeService: _QuotaExceededClaudeService(),
        storageService: storageService,
      );

      await pumpScreen(tester, service);

      expect(find.text("Today's limit reached"), findsOneWidget);
      expect(find.textContaining('try again tomorrow'), findsWidgets);
      expect(find.textContaining('check your connection'), findsNothing);
    });

    testWidgets('has no "Try again" CTA — it would just fail again with '
        'the same answer', (tester) async {
      final service = DailyTestService(
        claudeService: _QuotaExceededClaudeService(),
        storageService: storageService,
      );

      await pumpScreen(tester, service);

      expect(find.text('Try again'), findsNothing);
    });
  });
}
