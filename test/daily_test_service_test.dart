import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Stands in for the real network-backed ClaudeService so this test can
/// assert on how many times generation was actually called, without an API
/// key or a live request.
class _FakeClaudeService extends ClaudeService {
  int generateCallCount = 0;
  void Function()? onGenerate;

  /// When set, generation waits for it: a request that is still running.
  Completer<void>? gate;

  /// Generations that fail before one succeeds.
  int failuresLeft = 0;

  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
  }) async {
    generateCallCount++;
    onGenerate?.call();
    if (gate != null) await gate!.future;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const FormatException('simulated failure');
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

/// Simulates a generation call that fails partway through parsing the
/// API response (e.g. the schema-mismatch bug documented in
/// docs/build-log.md) — throws instead of ever returning a question list,
/// so `DailyTestService.getTodaysSet` never reaches `saveDailyTestSet`.
class _FailingClaudeService extends ClaudeService {
  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required String deviceId,
    required int count,
  }) async {
    throw const FormatException('simulated parse failure');
  }
}

/// A real, ffi-backed store that counts reads of the error profile, so a test
/// can prove the Daily Test never touches it.
class _RecordingStorage extends StorageService {
  int weakSpotReads = 0;

  _RecordingStorage({required super.dbName});

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) {
    weakSpotReads++;
    return super.getWeakSpots(limit: limit, sortOrder: sortOrder);
  }
}

/// A real store whose completion write fails, to prove nothing is prepared
/// for a completion that was not saved.
class _FailingCompletionStorage extends StorageService {
  _FailingCompletionStorage({required super.dbName});

  @override
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async =>
      throw StateError('disk full');
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
      'generation never reads the local error profile: an existing weak '
      'spot changes nothing about the request', () async {
    await storageService.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'missing_article',
        timestamp: DateTime.now(),
        source: ErrorSource.topicPractice,
      ),
    ]);
    final recording = _RecordingStorage(dbName: dbName);
    final service = DailyTestService(
      claudeService: claudeService,
      storageService: recording,
    );

    await service.getTodaysSet();

    expect(claudeService.generateCallCount, 1);
    expect(recording.weakSpotReads, 0);
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

  group('single-flight generation', () {
    test('two calls while one is running share one request and one set',
        () async {
      claudeService.gate = Completer<void>();

      final first = dailyTestService.getTodaysSet();
      final second = dailyTestService.getTodaysSet();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      claudeService.gate!.complete();
      final sets = await Future.wait([first, second]);

      expect(claudeService.generateCallCount, 1);
      expect(sets[0].day, sets[1].day);
      expect(sets[0].questions.map((q) => q.item.id),
          sets[1].questions.map((q) => q.item.id));
      // And it was cached once: a later call reads it, generating nothing.
      await dailyTestService.getTodaysSet();
      expect(claudeService.generateCallCount, 1);
    });

    test(
        'everyone who joined a failing request sees its error, and the next '
        'call is a fresh attempt', () async {
      claudeService
        ..gate = Completer<void>()
        ..failuresLeft = 1;

      final first = dailyTestService.getTodaysSet();
      final second = dailyTestService.getTodaysSet();
      final failures = [
        expectLater(first, throwsA(isA<FormatException>())),
        expectLater(second, throwsA(isA<FormatException>())),
      ];
      await Future<void>.delayed(const Duration(milliseconds: 20));
      claudeService.gate!.complete();
      await Future.wait(failures);
      expect(claudeService.generateCallCount, 1);

      // Nothing was cached and nothing is remembered as in flight.
      expect(await storageService.getDailyTestSetForToday(), isNull);
      final retry = await dailyTestService.getTodaysSet();
      expect(claudeService.generateCallCount, 2);
      expect(retry.questions, hasLength(DailyTestService.questionCount));
    });

    test('a call for another day does not join a request for the first',
        () async {
      StorageService.clockForTesting = () => DateTime(2026, 9, 30, 23, 59);
      claudeService.gate = Completer<void>();
      final evening = dailyTestService.getTodaysSet();

      StorageService.clockForTesting = () => DateTime(2026, 10, 1, 0, 1);
      final morning = dailyTestService.getTodaysSet();
      claudeService.gate!.complete();
      final sets = await Future.wait([evening, morning]);

      expect(claudeService.generateCallCount, 2);
      expect(sets[0].day, '2026-09-30');
      expect(sets[1].day, '2026-10-01');
    });
  });

  group('seedDayZeroSet', () {
    test('writes the fixed set as today\'s set, marked bundled', () async {
      await dailyTestService.seedDayZeroSet();

      final set = await storageService.getDailyTestSetForToday();
      expect(set, isNotNull);
      expect(set!.source, DailyTestSource.bundled);
      expect(set.isCompleted, isFalse);
      expect(set.day, storageService.currentDayKey);
      expect(set.questions.map((q) => q.item.id),
          kDayZeroQuestions.map((q) => q.item.id));
      expect(set.questions.map((q) => q.correctAnswer),
          kDayZeroQuestions.map((q) => q.correctAnswer));
    });

    test('the Daily Test then opens on it with no generation at all', () async {
      await dailyTestService.seedDayZeroSet();

      final set = await dailyTestService.getTodaysSet();

      expect(claudeService.generateCallCount, 0);
      expect(set.source, DailyTestSource.bundled);
      expect(set.questions, hasLength(5));
    });

    test('does nothing when today already has a generated set', () async {
      final generated = await dailyTestService.getTodaysSet();
      expect(generated.source, DailyTestSource.generated);

      await dailyTestService.seedDayZeroSet();

      final after = await storageService.getDailyTestSetForToday();
      expect(after!.source, DailyTestSource.generated);
      expect(after.questions.map((q) => q.item.id),
          generated.questions.map((q) => q.item.id));
    });

    test('does nothing when today\'s set is already completed', () async {
      await dailyTestService.seedDayZeroSet();
      await dailyTestService.completeDailyTest({'day0_1': 'eating'}, []);

      await dailyTestService.seedDayZeroSet();

      final after = await storageService.getDailyTestSetForToday();
      expect(after!.isCompleted, isTrue);
      expect(after.answers, {'day0_1': 'eating'});
    });

    test('seeding twice leaves one set and does not reset it', () async {
      await dailyTestService.seedDayZeroSet();
      await dailyTestService.seedDayZeroSet();

      final set = await storageService.getDailyTestSetForToday();
      expect(set!.questions, hasLength(5));
      expect(claudeService.generateCallCount, 0);
    });

    test(
        'a generated set is marked generated, and the marker survives a '
        'reopen of the store', () async {
      await dailyTestService.getTodaysSet();

      final reopened = StorageService(dbName: dbName);
      expect((await reopened.getDailyTestSetForToday())!.source,
          DailyTestSource.generated);
    });
  });

  group('the next day\'s set, prepared in the background', () {
    /// Polls until [check] holds: the preparation is background work, so a test
    /// cannot await it directly.
    Future<void> eventually(Future<bool> Function() check) async {
      for (var i = 0; i < 200; i++) {
        if (await check()) return;
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      fail('did not happen in time');
    }

    Future<bool> tomorrowExists() async =>
        await storageService.getDailyTestSet('2026-09-23') != null;

    /// Today (2026-09-22) has its set, generated with one request.
    Future<void> openToday() async {
      StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
      await dailyTestService.getTodaysSet();
      expect(claudeService.generateCallCount, 1);
    }

    test(
        'completing today\'s test asks for exactly one more set, stored under '
        'tomorrow\'s day, generated and not completed', () async {
      await openToday();

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await eventually(tomorrowExists);

      expect(claudeService.generateCallCount, 2);
      final tomorrow = (await storageService.getDailyTestSet('2026-09-23'))!;
      expect(tomorrow.day, '2026-09-23');
      expect(tomorrow.source, DailyTestSource.generated);
      expect(tomorrow.isCompleted, isFalse);
      expect(tomorrow.questions, hasLength(DailyTestService.questionCount));
      // Today's own set is untouched: completed, with its answers.
      final today = (await storageService.getDailyTestSetForToday())!;
      expect(today.day, '2026-09-22');
      expect(today.isCompleted, isTrue);
      expect(today.answers, {'q0': 'x'});
    });

    test('the next day opens from the cache: no request, same questions',
        () async {
      await openToday();
      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await eventually(tomorrowExists);
      final prepared = await storageService.getDailyTestSet('2026-09-23');

      StorageService.clockForTesting = () => DateTime(2026, 9, 23, 8);
      final set = await dailyTestService.getTodaysSet();

      expect(claudeService.generateCallCount, 2);
      expect(set.day, '2026-09-23');
      expect(set.isCompleted, isFalse);
      expect(set.questions.map((q) => q.item.id),
          prepared!.questions.map((q) => q.item.id));
    });

    test(
        'a failed background generation is silent, leaves nothing behind, and '
        'the next day generates as before', () async {
      await openToday();
      claudeService.failuresLeft = 1;
      final uncaught = <Object>[];
      late bool earned;

      await runZonedGuarded(() async {
        earned = await dailyTestService.completeDailyTest({'q0': 'x'}, []);
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }, (error, _) => uncaught.add(error));

      expect(uncaught, isEmpty);
      // The completion itself succeeded and returned its own result (this first
      // answered test earns the Welcome badge).
      expect(earned, isTrue);
      expect(claudeService.generateCallCount, 2);
      expect(await tomorrowExists(), isFalse);
      // Today's completion itself is saved regardless.
      expect((await storageService.getDailyTestSetForToday())!.isCompleted,
          isTrue);

      StorageService.clockForTesting = () => DateTime(2026, 9, 23, 8);
      final set = await dailyTestService.getTodaysSet();
      expect(claudeService.generateCallCount, 3);
      expect(set.questions, hasLength(DailyTestService.questionCount));
    });

    test('completing again does not ask a second time', () async {
      await openToday();

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await eventually(tomorrowExists);
      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // One for today, one for tomorrow: the repeats joined it, then found it.
      expect(claudeService.generateCallCount, 2);
    });

    test('a next day that already has a set costs no request', () async {
      await openToday();
      await storageService.saveDailyTestSet([
        DailyTestQuestion(
          item: const PracticeItem(
            id: 'kept',
            type: PracticeItemType.fillInBlank,
            instruction: 'Already here',
          ),
          topicId: 'tenseSelection',
          correctAnswer: 'x',
          commonWrongAnswers: const [],
        ),
      ], day: '2026-09-23');

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(claudeService.generateCallCount, 1);
      final tomorrow = (await storageService.getDailyTestSet('2026-09-23'))!;
      expect(tomorrow.questions.single.item.id, 'kept');
    });

    test('the day of the fixed first test prepares tomorrow too', () async {
      StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
      await dailyTestService.seedDayZeroSet();
      expect(claudeService.generateCallCount, 0);

      await dailyTestService.completeDailyTest({'day0_1': 'eating'}, []);
      await eventually(tomorrowExists);

      expect(claudeService.generateCallCount, 1);
      final today = (await storageService.getDailyTestSetForToday())!;
      expect(today.source, DailyTestSource.bundled);
      expect(today.isCompleted, isTrue);
      expect((await storageService.getDailyTestSet('2026-09-23'))!.source,
          DailyTestSource.generated);
    });

    test(
        'a day opened while its set is still being prepared joins the request '
        'instead of asking again', () async {
      await openToday();
      claudeService.gate = Completer<void>();

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      StorageService.clockForTesting = () => DateTime(2026, 9, 23, 0, 5);
      final opened = dailyTestService.getTodaysSet();
      claudeService.gate!.complete();
      final set = await opened;

      expect(claudeService.generateCallCount, 2);
      expect(set.day, '2026-09-23');
    });

    test('a completion that fails to save starts no preparation', () async {
      await openToday();
      final failing = DailyTestService(
        claudeService: claudeService,
        storageService: _FailingCompletionStorage(dbName: dbName),
      );

      await expectLater(
          failing.completeDailyTest({'q0': 'x'}, []), throwsStateError);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(claudeService.generateCallCount, 1);
      expect(await tomorrowExists(), isFalse);
    });
  });

  group('StorageService.dayKeyAfter', () {
    test('goes to the next calendar day, across month, year and leap ends',
        () {
      expect(StorageService.dayKeyAfter('2026-09-22'), '2026-09-23');
      expect(StorageService.dayKeyAfter('2026-09-30'), '2026-10-01');
      expect(StorageService.dayKeyAfter('2026-12-31'), '2027-01-01');
      expect(StorageService.dayKeyAfter('2026-02-28'), '2026-03-01');
      expect(StorageService.dayKeyAfter('2028-02-28'), '2028-02-29');
      expect(StorageService.dayKeyAfter('2028-02-29'), '2028-03-01');
    });

    // Correct by construction (the key is built from calendar fields, not by
    // adding 24 hours). A machine in a zone without daylight saving, like the one
    // this was written on, cannot tell the two apart, so this only guards a run
    // in a zone that has it.
    test('daylight-saving change days still give the next calendar day', () {
      expect(StorageService.dayKeyAfter('2026-03-08'), '2026-03-09');
      expect(StorageService.dayKeyAfter('2026-03-28'), '2026-03-29');
      expect(StorageService.dayKeyAfter('2026-10-24'), '2026-10-25');
      expect(StorageService.dayKeyAfter('2026-10-25'), '2026-10-26');
      expect(StorageService.dayKeyAfter('2026-11-01'), '2026-11-02');
    });
  });
}
