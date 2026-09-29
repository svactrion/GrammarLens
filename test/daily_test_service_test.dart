import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/data/day_zero_daily_test.dart';
import 'package:grammar_lens/data/fallback_pool.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Stands in for the real network-backed ClaudeService so this test can
/// assert on how many shared-set reads were made, for which dates, without a
/// proxy.
class _FakeClaudeService extends ClaudeService {
  final List<String> readDates = [];
  int get readCount => readDates.length;
  void Function()? onRead;

  /// When set, a read waits for it: a request that is still running.
  Completer<void>? gate;

  /// Reads that fail (no connection, a timeout, a bad body) before one
  /// succeeds.
  int failuresLeft = 0;

  /// Dates the proxy has no set for yet: a 404, read as null.
  final Set<String> unpublished = {};

  @override
  Future<List<DailyTestQuestion>?> fetchSharedDailyTest(String date) async {
    readDates.add(date);
    onRead?.call();
    if (gate != null) await gate!.future;
    if (failuresLeft > 0) {
      failuresLeft--;
      throw const ClaudeApiException('simulated read failure',
          kind: ClaudeApiErrorKind.network);
    }
    if (unpublished.contains(date)) return null;
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

/// A real store whose next [failuresLeft] saves of a Daily Test set fail: the
/// one failure the chain does not absorb.
class _FailingSaveStorage extends StorageService {
  int failuresLeft;

  _FailingSaveStorage({required super.dbName}) : failuresLeft = 1;

  @override
  Future<DailyTestSet> saveDailyTestSet(List<DailyTestQuestion> questions,
      {String? day, DailyTestSource source = DailyTestSource.generated}) {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('disk full');
    }
    return super.saveDailyTestSet(questions, day: day, source: source);
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
      // An empty pool: the fallback is then the day-0 questions, whatever
      // the shipped asset holds.
      fallbackPool: FallbackPool.withSets(const []),
    );
  });

  tearDown(() => StorageService.clockForTesting = DateTime.now);

  test('a read across midnight keeps the day captured before the request',
      () async {
    StorageService.clockForTesting = () => DateTime(2026, 9, 30, 23, 59);
    claudeService.onRead = () {
      StorageService.clockForTesting = () => DateTime(2026, 10, 1, 0, 1);
    };
    final set = await dailyTestService.getTodaysSet();
    expect(set.day, '2026-09-30');
    expect(await storageService.getDailyTestSetForToday(), isNull);
    StorageService.clockForTesting = () => DateTime(2026, 9, 30, 23, 59);
    expect((await dailyTestService.getTodaysSet()).day, set.day);
    expect(claudeService.readCount, 1);
  });

  test('reads today\'s shared set on first open and caches it as shared',
      () async {
    StorageService.clockForTesting = () => DateTime(2026, 9, 30, 9);
    final set = await dailyTestService.getTodaysSet();
    expect(claudeService.readDates, ['2026-09-30']);
    expect(set.day, '2026-09-30');
    expect(set.source, DailyTestSource.shared);
    expect(set.questions, hasLength(DailyTestSet.questionCount));
    expect(set.isCompleted, isFalse);
    expect((await storageService.getDailyTestSet('2026-09-30'))!.source,
        DailyTestSource.shared);
  });

  test('a repeat open the same day reuses the cached set: no request',
      () async {
    final first = await dailyTestService.getTodaysSet();
    final second = await dailyTestService.getTodaysSet();

    expect(claudeService.readCount, 1);
    expect(second.day, first.day);
    expect(
      second.questions.map((q) => q.item.id),
      first.questions.map((q) => q.item.id),
    );
  });

  test('a set already cached for today (e.g. from 1.0.0) makes no request',
      () async {
    await storageService.saveDailyTestSet([kDayZeroQuestions.first],
        day: storageService.currentDayKey);

    final set = await dailyTestService.getTodaysSet();

    expect(claudeService.readCount, 0);
    expect(set.source, DailyTestSource.generated);
  });

  test(
      'the Daily Test never reads the local error profile: an existing weak '
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

    expect(claudeService.readCount, 1);
    expect(recording.weakSpotReads, 0);
  });

  group('the fallback (docs/1.1.0-shared-daily-test.md §5)', () {
    Future<void> expectFallbackToday(DailyTestSet set) async {
      expect(set.source, DailyTestSource.fallback);
      expect(set.day, storageService.currentDayKey);
      expect(set.questions.map((q) => q.item.id),
          kDayZeroQuestions.map((q) => q.item.id));
      final stored = (await storageService.getDailyTestSetForToday())!;
      expect(stored.source, DailyTestSource.fallback);
    }

    test('a failed read (offline, timeout, bad body) opens the fallback',
        () async {
      claudeService.failuresLeft = 1;
      await expectFallbackToday(await dailyTestService.getTodaysSet());
      expect(claudeService.readCount, 1);
    });

    test('a date with no shared set (404) opens the fallback', () async {
      claudeService.unpublished.add(storageService.currentDayKey);
      await expectFallbackToday(await dailyTestService.getTodaysSet());
      expect(claudeService.readCount, 1);
    });

    test(
        'the fallback is kept for the rest of the day: a later open makes no '
        'request and shows the same questions', () async {
      claudeService.failuresLeft = 1;
      final first = await dailyTestService.getTodaysSet();

      final again = await dailyTestService.getTodaysSet();

      expect(claudeService.readCount, 1);
      expect(again.source, DailyTestSource.fallback);
      expect(again.questions.map((q) => q.item.id),
          first.questions.map((q) => q.item.id));
    });

    test(
        'with a pool, a failed read gives the pool set the date rotates to, '
        'marked fallback; another date gets another set', () async {
      List<DailyTestQuestion> poolSet(int n) => [
            for (final q in kDayZeroQuestions)
              DailyTestQuestion(
                item: PracticeItem(
                  id: 'fb0${n}_${q.item.id}',
                  type: q.item.type,
                  context: q.item.context,
                  instruction: q.item.instruction,
                  hint: q.item.hint,
                ),
                topicId: q.topicId,
                correctAnswer: q.correctAnswer,
                commonWrongAnswers: q.commonWrongAnswers,
                explanation: q.explanation,
              ),
          ];
      final sets = [for (var n = 1; n <= 7; n++) poolSet(n)];
      final service = DailyTestService(
        claudeService: claudeService,
        storageService: storageService,
        fallbackPool: FallbackPool.withSets(sets),
      );
      claudeService.failuresLeft = 2;

      StorageService.clockForTesting = () => DateTime(2026, 10, 2, 9);
      final first = await service.getTodaysSet();
      StorageService.clockForTesting = () => DateTime(2026, 10, 3, 9);
      final second = await service.getTodaysSet();

      expect(first.source, DailyTestSource.fallback);
      expect(first.questions.map((q) => q.item.id),
          sets[FallbackPool.indexFor('2026-10-02', 7)!].map((q) => q.item.id));
      expect(second.questions.map((q) => q.item.id),
          sets[FallbackPool.indexFor('2026-10-03', 7)!].map((q) => q.item.id));
      expect(
          first.questions.first.item.id, isNot(second.questions.first.item.id));
    });

    test(
        'a local storage failure is the one error that reaches the caller, '
        'and it is not remembered: the next open is a fresh attempt', () async {
      final failing = DailyTestService(
        claudeService: claudeService,
        storageService: _FailingSaveStorage(dbName: dbName),
      );

      await expectLater(failing.getTodaysSet(), throwsStateError);
      expect(await storageService.getDailyTestSetForToday(), isNull);

      final retried = await failing.getTodaysSet();
      expect(retried.source, DailyTestSource.shared);
      expect(claudeService.readCount, 2);
    });
  });

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

  group('single-flight', () {
    test('two calls while one is running share one request and one set',
        () async {
      claudeService.gate = Completer<void>();

      final first = dailyTestService.getTodaysSet();
      final second = dailyTestService.getTodaysSet();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      claudeService.gate!.complete();
      final sets = await Future.wait([first, second]);

      expect(claudeService.readCount, 1);
      expect(sets[0].day, sets[1].day);
      expect(sets[0].questions.map((q) => q.item.id),
          sets[1].questions.map((q) => q.item.id));
      // And it was cached once: a later call reads it, asking for nothing.
      await dailyTestService.getTodaysSet();
      expect(claudeService.readCount, 1);
    });

    test(
        'everyone who joined a failing read gets the same fallback, from one '
        'request', () async {
      claudeService
        ..gate = Completer<void>()
        ..failuresLeft = 1;

      final first = dailyTestService.getTodaysSet();
      final second = dailyTestService.getTodaysSet();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      claudeService.gate!.complete();
      final sets = await Future.wait([first, second]);

      expect(claudeService.readCount, 1);
      expect(sets.map((s) => s.source).toSet(), {DailyTestSource.fallback});
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

      expect(claudeService.readCount, 2);
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

    test('the Daily Test then opens on it with no request at all', () async {
      await dailyTestService.seedDayZeroSet();

      final set = await dailyTestService.getTodaysSet();

      expect(claudeService.readCount, 0);
      expect(set.source, DailyTestSource.bundled);
      expect(set.questions, hasLength(5));
    });

    test('does nothing when today already has a shared set', () async {
      final generated = await dailyTestService.getTodaysSet();
      expect(generated.source, DailyTestSource.shared);

      await dailyTestService.seedDayZeroSet();

      final after = await storageService.getDailyTestSetForToday();
      expect(after!.source, DailyTestSource.shared);
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
      expect(claudeService.readCount, 0);
    });

    test('the shared and fallback markers survive a reopen of the store',
        () async {
      StorageService.clockForTesting = () => DateTime(2026, 9, 30, 9);
      await dailyTestService.getTodaysSet();
      StorageService.clockForTesting = () => DateTime(2026, 10, 1, 9);
      claudeService.failuresLeft = 1;
      await dailyTestService.getTodaysSet();

      final reopened = StorageService(dbName: dbName);
      expect((await reopened.getDailyTestSet('2026-09-30'))!.source,
          DailyTestSource.shared);
      expect((await reopened.getDailyTestSet('2026-10-01'))!.source,
          DailyTestSource.fallback);
    });
  });

  group('the next day\'s shared set, read in the background', () {
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

    /// Today (2026-09-22) has its set, read with one request.
    Future<void> openToday() async {
      StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
      await dailyTestService.getTodaysSet();
      expect(claudeService.readCount, 1);
    }

    test(
        'completing today\'s test reads exactly one more set, tomorrow\'s, '
        'stored under tomorrow\'s day, shared and not completed', () async {
      await openToday();

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await eventually(tomorrowExists);

      expect(claudeService.readDates, ['2026-09-22', '2026-09-23']);
      final tomorrow = (await storageService.getDailyTestSet('2026-09-23'))!;
      expect(tomorrow.day, '2026-09-23');
      expect(tomorrow.source, DailyTestSource.shared);
      expect(tomorrow.isCompleted, isFalse);
      expect(tomorrow.questions, hasLength(DailyTestSet.questionCount));
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

      expect(claudeService.readCount, 2);
      expect(set.day, '2026-09-23');
      expect(set.isCompleted, isFalse);
      expect(set.questions.map((q) => q.item.id),
          prepared!.questions.map((q) => q.item.id));
    });

    for (final (name, arrange) in [
      (
        'a failed background read',
        (_FakeClaudeService c) => c.failuresLeft = 1,
      ),
      (
        'a tomorrow with no shared set yet (404)',
        (_FakeClaudeService c) => c.unpublished.add('2026-09-23'),
      ),
    ]) {
      test(
          '$name is silent, writes nothing (not even the fallback), and the '
          'next day reads again on its first open', () async {
        await openToday();
        arrange(claudeService);
        final uncaught = <Object>[];
        late bool earned;

        await runZonedGuarded(() async {
          earned = await dailyTestService.completeDailyTest({'q0': 'x'}, []);
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }, (error, _) => uncaught.add(error));

        expect(uncaught, isEmpty);
        // The completion itself succeeded and returned its own result (this
        // first answered test earns the Welcome badge).
        expect(earned, isTrue);
        expect(claudeService.readCount, 2);
        expect(await tomorrowExists(), isFalse);
        // Today's completion itself is saved regardless.
        expect((await storageService.getDailyTestSetForToday())!.isCompleted,
            isTrue);

        claudeService.unpublished.clear();
        StorageService.clockForTesting = () => DateTime(2026, 9, 23, 8);
        final set = await dailyTestService.getTodaysSet();
        expect(claudeService.readDates.last, '2026-09-23');
        expect(claudeService.readCount, 3);
        expect(set.source, DailyTestSource.shared);
      });
    }

    test('completing again does not ask a second time', () async {
      await openToday();

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await eventually(tomorrowExists);
      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // One for today, one for tomorrow: the repeats joined it, then found it.
      expect(claudeService.readCount, 2);
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

      expect(claudeService.readCount, 1);
      final tomorrow = (await storageService.getDailyTestSet('2026-09-23'))!;
      expect(tomorrow.questions.single.item.id, 'kept');
    });

    test('the day of the fixed first test prepares tomorrow too', () async {
      StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
      await dailyTestService.seedDayZeroSet();
      expect(claudeService.readCount, 0);

      await dailyTestService.completeDailyTest({'day0_1': 'eating'}, []);
      await eventually(tomorrowExists);

      expect(claudeService.readCount, 1);
      final today = (await storageService.getDailyTestSetForToday())!;
      expect(today.source, DailyTestSource.bundled);
      expect(today.isCompleted, isTrue);
      expect((await storageService.getDailyTestSet('2026-09-23'))!.source,
          DailyTestSource.shared);
    });

    test(
        'a day opened while its set is still being read waits for that read '
        'instead of asking again', () async {
      await openToday();
      claudeService.gate = Completer<void>();

      await dailyTestService.completeDailyTest({'q0': 'x'}, []);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      StorageService.clockForTesting = () => DateTime(2026, 9, 23, 0, 5);
      final opened = dailyTestService.getTodaysSet();
      claudeService.gate!.complete();
      final set = await opened;

      expect(claudeService.readCount, 2);
      expect(set.day, '2026-09-23');
      expect(set.source, DailyTestSource.shared);
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

      expect(claudeService.readCount, 1);
      expect(await tomorrowExists(), isFalse);
    });
  });

  group('StorageService.dayKeyAfter', () {
    test('goes to the next calendar day, across month, year and leap ends', () {
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

  group('over HTTP, with the real ClaudeService', () {
    final requests = <http.BaseRequest>[];
    late Future<http.Response> Function(http.Request) respond;

    Map<String, dynamic> question(String id) => {
          'id': id,
          'type': 'fill_in_blank',
          'context': 'She ___ to work.',
          'instruction': 'Fill it.',
          'topicId': 'tenseSelection',
          'correctAnswer': 'goes',
          'explanation': 'Why.',
          'commonWrongAnswers': [
            {'answer': 'go', 'comment': 'c'},
          ],
        };
    http.Response sharedSet(String date) => http.Response(
        jsonEncode({
          'date': date,
          'promptVersion': 2,
          'questions': [for (var i = 1; i <= 5; i++) question('s$i')],
        }),
        200);

    DailyTestService serviceOver({Duration? timeout}) => DailyTestService(
          claudeService: ClaudeService(
            client: MockClient((request) {
              requests.add(request);
              return respond(request);
            }),
            proxyBaseUrl: 'https://proxy.test',
            appToken: 'test-token',
            sharedSetTimeout: timeout,
          ),
          storageService: storageService,
          fallbackPool: FallbackPool.withSets(const []),
        );

    setUp(() {
      requests.clear();
      StorageService.clockForTesting = () => DateTime(2026, 9, 30, 9);
      respond = (request) async => sharedSet(request.url.pathSegments.last);
    });

    /// Every request any test in this group made: only reads of the shared
    /// route, never the legacy per-device generation
    /// (docs/1.1.0-shared-daily-test.md §13, decision 2).
    tearDown(() {
      for (final r in requests) {
        expect(r.method, 'GET');
        expect(r.url.path, startsWith('/v1/shared-daily-test/'));
        expect(r.url.path, isNot(contains('generate')));
      }
    });

    test('a shared set: one GET for today\'s local day key, saved as shared',
        () async {
      final set = await serviceOver().getTodaysSet();

      expect(requests.map((r) => r.url.path),
          ['/v1/shared-daily-test/2026-09-30']);
      expect(set.source, DailyTestSource.shared);
      expect(
          set.questions.map((q) => q.item.id), ['s1', 's2', 's3', 's4', 's5']);
    });

    final failures = <String, Future<http.Response> Function(http.Request)>{
      '404': (_) async => http.Response(
          jsonEncode({'error': 'not_found', 'message': 'x'}), 404),
      'a 5xx': (_) async => http.Response(
          jsonEncode({'error': 'upstream_error', 'message': 'x'}), 503),
      'no connection': (_) async => throw const SocketException('offline'),
      'a body that is not JSON': (_) async => http.Response('{"date":', 200),
      'a set for another date': (_) async => sharedSet('2026-10-01'),
      'a question missing its key': (_) async => http.Response(
          jsonEncode({
            'date': '2026-09-30',
            'questions': [
              {...question('s1')}..remove('correctAnswer'),
            ],
          }),
          200),
    };
    failures.forEach((name, failure) {
      test('$name → the fallback, from exactly one request', () async {
        respond = failure;

        final set = await serviceOver().getTodaysSet();

        expect(requests, hasLength(1));
        expect(set.source, DailyTestSource.fallback);
        expect(set.questions.map((q) => q.item.id),
            kDayZeroQuestions.map((q) => q.item.id));
      });
    });

    test('a timeout → the fallback', () async {
      respond = (_) => Completer<http.Response>().future;

      final set = await serviceOver(timeout: const Duration(milliseconds: 50))
          .getTodaysSet();

      expect(requests, hasLength(1));
      expect(set.source, DailyTestSource.fallback);
    });

    test('a cached set makes no request at all', () async {
      final service = serviceOver();
      await service.getTodaysSet();
      requests.clear();

      await service.getTodaysSet();

      expect(requests, isEmpty);
    });

    test(
        'a completion reads tomorrow\'s shared set with one GET; a 404 there '
        'writes nothing', () async {
      final service = serviceOver();
      await service.getTodaysSet();
      respond = (_) async => http.Response(
          jsonEncode({'error': 'not_found', 'message': 'x'}), 404);

      await service.completeDailyTest({'s1': 'goes'}, []);
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(requests.map((r) => r.url.path), [
        '/v1/shared-daily-test/2026-09-30',
        '/v1/shared-daily-test/2026-10-01',
      ]);
      expect(await storageService.getDailyTestSet('2026-10-01'), isNull);
    });

    test('the request carries no device id or anything about the user',
        () async {
      await serviceOver().getTodaysSet();

      final request = requests.single as http.Request;
      expect(request.body, isEmpty);
      expect(request.url.query, isEmpty);
      expect(request.headers.keys.map((k) => k.toLowerCase()).toSet(),
          {'x-grammarlens-token'});
    });
  });
}
