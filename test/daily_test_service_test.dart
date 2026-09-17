import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Stands in for the real network-backed ClaudeService so this test can
/// assert on how many times generation was actually called, without an API
/// key or a live request.
class _FakeClaudeService extends ClaudeService {
  int generateCallCount = 0;
  void Function()? onGenerate;
  List<WeakSpot>? lastWeakSpots;

  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
    generateCallCount++;
    onGenerate?.call();
    lastWeakSpots = weakSpots;
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

/// Simulates a generation call that fails partway through parsing the
/// API response (e.g. the schema-mismatch bug documented in
/// docs/build-log.md) — throws instead of ever returning a question list,
/// so `DailyTestService.getTodaysSet` never reaches `saveDailyTestSet`.
class _FailingClaudeService extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
    throw const FormatException('simulated parse failure');
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;
  late _FakeClaudeService claudeService;
  late DailyTestService dailyTestService;

  // A file distinct from other ffi-backed test files' — `flutter test` runs
  // files concurrently, and they'd otherwise race on the same real db path.
  const dbName = 'test_daily_test_service.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
    claudeService = _FakeClaudeService();
    dailyTestService = DailyTestService(
      claudeService: claudeService,
      storageService: storageService,
    );
  });

  tearDown(() => StorageService.clockForTesting = DateTime.now);

  test('generation across midnight keeps the day captured before the request',
      () async {
    StorageService.clockForTesting = () => DateTime(2026, 9, 30, 23, 59);
    claudeService.onGenerate = () {
      StorageService.clockForTesting = () => DateTime(2026, 10, 1, 0, 1);
    };
    final set = await dailyTestService.getTodaysSet();
    expect(set.day, '2026-09-30');
    expect(await storageService.getDailyTestSetForToday(), isNull);
    StorageService.clockForTesting = () => DateTime(2026, 9, 30, 23, 59);
    expect((await dailyTestService.getTodaysSet()).day, set.day);
    expect(claudeService.generateCallCount, 1);
  });

  test('generates and caches a set on first open today', () async {
    final set = await dailyTestService.getTodaysSet();
    expect(claudeService.generateCallCount, 1);
    expect(set.questions, hasLength(DailyTestService.questionCount));
    expect(set.isCompleted, isFalse);
  });

  test('a repeat open the same day reuses the cached set, no regeneration',
      () async {
    final first = await dailyTestService.getTodaysSet();
    final second = await dailyTestService.getTodaysSet();

    expect(claudeService.generateCallCount, 1);
    expect(second.day, first.day);
    expect(
      second.questions.map((q) => q.item.id),
      first.questions.map((q) => q.item.id),
    );
  });

  test(
      'a new user with no error profile generates with an empty weak-spot '
      'list', () async {
    await dailyTestService.getTodaysSet();
    expect(claudeService.lastWeakSpots, isEmpty);
  });

  test('an existing error profile is passed through to generation', () async {
    await storageService.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'missing_article',
        timestamp: DateTime.now(),
        source: ErrorSource.topicPractice,
      ),
    ]);

    await dailyTestService.getTodaysSet();

    expect(claudeService.lastWeakSpots, isNotEmpty);
    expect(claudeService.lastWeakSpots!.single.topicId, 'articles');
  });

  test(
    'a failed generation is never cached as "today\'s test" — no half/'
    'broken set gets saved, and a retry can still succeed',
    () async {
      final failingService = DailyTestService(
        claudeService: _FailingClaudeService(),
        storageService: storageService,
      );

      await expectLater(
        failingService.getTodaysSet(),
        throwsA(isA<FormatException>()),
      );

      // Nothing should have been written for today — the failure happened
      // before saveDailyTestSet was ever called.
      expect(await storageService.getDailyTestSetForToday(), isNull);

      // A subsequent attempt (e.g. the user reopening Daily Test) with a
      // working ClaudeService must not be blocked by a stale/partial row.
      final retried = await dailyTestService.getTodaysSet();
      expect(retried.questions, hasLength(DailyTestService.questionCount));
    },
  );

  test(
      'completeDailyTest flows through to the cached set (answers included) '
      'and the error profile together', () async {
    await dailyTestService.getTodaysSet();
    await dailyTestService.completeDailyTest(
      {'q0': 'answer0'},
      [
        ErrorEntry(
          topicId: 'tenseSelection',
          errorType: 'tenseSelection',
          timestamp: DateTime.now(),
          source: ErrorSource.dailyTest,
        ),
      ],
    );

    final set = await storageService.getDailyTestSetForToday();
    expect(set!.isCompleted, isTrue);
    expect(set.answers, {'q0': 'answer0'});

    final mistakes = await storageService.getRecentMistakes(
        'tenseSelection', 'tenseSelection');
    expect(mistakes, hasLength(1));
  });

  test(
      'a failure recording error entries rolls back the completion write too '
      '— the set stays not-completed rather than half-written', () async {
    await dailyTestService.getTodaysSet();

    // Seed error_entries with a row at id 1 so the completion call below's
    // error entry (same explicit id) hits a PRIMARY KEY conflict — forces
    // a failure inside the transaction's second write, proving the two
    // writes really share one transaction: if they didn't, the
    // daily_test_sets update would already have committed on its own
    // before this failure.
    await storageService.insertErrors([
      ErrorEntry(
        id: 1,
        topicId: 'seed',
        errorType: 'seed',
        timestamp: DateTime.now(),
        source: ErrorSource.topicPractice,
      ),
    ]);

    await expectLater(
      dailyTestService.completeDailyTest(
        {'q0': 'go'},
        [
          ErrorEntry(
            id: 1, // conflicts with the seeded row above
            topicId: 'tenseSelection',
            errorType: 'tenseSelection',
            timestamp: DateTime.now(),
            source: ErrorSource.dailyTest,
          ),
        ],
      ),
      throwsA(anything),
    );

    final set = await storageService.getDailyTestSetForToday();
    expect(set!.isCompleted, isFalse);

    final mistakes = await storageService.getRecentMistakes(
        'tenseSelection', 'tenseSelection');
    expect(mistakes, isEmpty);
  });

  test(
      'retaking a set after a failed completion does not leave duplicate or '
      'partial error rows once the retry succeeds', () async {
    await dailyTestService.getTodaysSet();
    await storageService.insertErrors([
      ErrorEntry(
        id: 1,
        topicId: 'seed',
        errorType: 'seed',
        timestamp: DateTime.now(),
        source: ErrorSource.topicPractice,
      ),
    ]);

    // First attempt fails and rolls back completely (same conflict as
    // above).
    await expectLater(
      dailyTestService.completeDailyTest(
        {'q0': 'go'},
        [
          ErrorEntry(
            id: 1,
            topicId: 'tenseSelection',
            errorType: 'tenseSelection',
            timestamp: DateTime.now(),
            source: ErrorSource.dailyTest,
          ),
        ],
      ),
      throwsA(anything),
    );
    expect(
        (await storageService.getDailyTestSetForToday())!.isCompleted, isFalse);

    // The still-not-completed set is retaken: a fresh, non-conflicting
    // completion succeeds.
    await dailyTestService.completeDailyTest(
      {'q0': 'went'},
      [
        ErrorEntry(
          topicId: 'tenseSelection',
          errorType: 'tenseSelection',
          timestamp: DateTime.now(),
          source: ErrorSource.dailyTest,
        ),
      ],
    );

    final set = await storageService.getDailyTestSetForToday();
    expect(set!.isCompleted, isTrue);

    // Exactly one mistake recorded — the failed first attempt left nothing
    // behind to double up.
    final mistakes = await storageService.getRecentMistakes(
        'tenseSelection', 'tenseSelection');
    expect(mistakes, hasLength(1));
  });
}
