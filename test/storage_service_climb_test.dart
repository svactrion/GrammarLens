import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:grammar_lens/models/daily_test_completion.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/services/storage_service.dart';

final questions = [
  for (var i = 0; i < 5; i++)
    DailyTestQuestion(
        item: PracticeItem(
            id: 'q$i',
            type: PracticeItemType.fillInBlank,
            instruction: 'Question $i'),
        topicId: 'tenseSelection',
        correctAnswer: 'cooking',
        commonWrongAnswers: const []),
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  late Directory dir;
  late String path;
  late StorageService storage;
  Database? inspection;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('monthly-climb-test-');
    path = join(dir.path, 'app.db');
    storage = StorageService(dbName: path);
    StorageService.clockForTesting = () => DateTime(2026, 9, 30, 23, 58);
  });
  tearDown(() async {
    await inspection?.close();
    inspection = null;
    await databaseFactory.deleteDatabase(path);
    await dir.delete(recursive: true);
    StorageService.clockForTesting = DateTime.now;
  });
  Future<Database> inspect() async => inspection ??= await openDatabase(path);
  DailyTestCompletion completion(
          DailyTestSet set, Map<String, String> answers) =>
      DailyTestCompletion(
          set: set, answers: answers, completedAt: DateTime(2026, 10, 1, 0, 3));

  Future<void> saveCompletion(DailyTestCompletion result) =>
      storage.completeDailyTest(result.answers, result.errors,
          day: result.set.day, completedAt: result.completedAt);

  // Same call, but keeping the Welcome-badge return value — used by the
  // tests below that specifically care whether a given completion is the
  // one that earned it.
  Future<bool> saveCompletionReturning(DailyTestCompletion result) =>
      storage.completeDailyTest(result.answers, result.errors,
          day: result.set.day, completedAt: result.completedAt);

  test(
      'v14 upgrade preserves every table row and never backfills old completions',
      () async {
    final old = await openDatabase(path, version: 14, onCreate: (db, _) async {
      final sql = await File('test/fixtures/storage_v14.sql').readAsString();
      for (final statement in sql.split(';')) {
        if (statement.trim().isNotEmpty) await db.execute(statement);
      }
    });
    final rows = <String, Map<String, Object?>>{
      'error_entries': {
        'id': 42,
        'topic_id': 'articles',
        'error_type': 'missing',
        'timestamp': '2026-09-30T12:00:00',
        'prompt': 'a prompt',
        'user_answer': 'a',
        'corrected_answer': 'the',
        'explanation': 'specific',
        'rule': 'article',
        'source': 'daily_test'
      },
      'review_settings': {'id': 0, 'sort_order': 'frequent'},
      'theme_settings': {'id': 0, 'mode': 'dark'},
      'practice_settings': {'id': 0, 'question_count': 10},
      'topic_practice_stats': {
        'topic_id': 'articles',
        'questions_answered': 17
      },
      'user_profile': {
        'id': 0,
        'name': 'Migration fixture',
        'learning_goal': 'work',
        'age': 32,
        'occupation': 'Engineer',
        'avatar': 'avatar_06'
      },
      'daily_session_usage': {'day': '2026-09-30', 'session_count': 3},
      'free_practice_usage': {'day': '2026-09-30', 'session_count': 1},
      'daily_test_sets': {
        'day': '2026-09-30',
        'questions_json': jsonEncode(questions.map((q) => q.toJson()).toList()),
        'completed_at': '2026-09-30T12:00:00',
        'answers_json': '{"q0":"cooking"}'
      },
      'debug_settings': {'id': 0, 'access_override': 'free'},
      'device_identity': {'id': 0, 'device_id': 'unchanged-device-identity'},
    };
    for (final entry in rows.entries) {
      await old.insert(entry.key, entry.value);
    }
    final before = {
      for (final table in rows.keys) table: await old.query(table)
    };
    await old.close();
    expect((await storage.getClimbProgress(2026, 9)).steps, 0);
    final db = await inspect();
    expect(await db.getVersion(), 20);
    for (final table in rows.keys) {
      // v19 removed age and occupation from user_profile; every other column
      // of every table must come through untouched.
      final expected = table == 'user_profile'
          ? [
              for (final row in before[table]!)
                {...row}
                  ..remove('age')
                  ..remove('occupation')
            ]
          : before[table];
      expect(await db.query(table), expected, reason: table);
    }
    final saved = (await storage.getDailyTestSetForToday())!;
    await saveCompletion(completion(saved, {'q0': 'wrong'}));
    expect(await db.query('climb_daily_entries'), isEmpty);
    expect(await db.query('error_entries'), before['error_entries']);
    expect(await storage.getOrCreateDeviceId(), 'unchanged-device-identity');
    await db.close();
    inspection = null;
    storage = StorageService(dbName: path);
    expect((await storage.getClimbProgress(2026, 9)).steps, 0);
    expect(await storage.getOrCreateDeviceId(), 'unchanged-device-identity');
    await inspect();
  });

  test('a missing cached set never creates a climb entry or mistakes',
      () async {
    final missing = DailyTestSet(day: '2026-09-30', questions: questions);
    await saveCompletion(completion(missing, {'q0': 'wrong'}));
    final db = await inspect();
    expect(await db.query('daily_test_sets'), isEmpty);
    expect(await db.query('error_entries'), isEmpty);
    expect(await db.query('climb_daily_entries'), isEmpty);
    expect((await storage.getClimbProgress(2026, 9)).steps, 0);
  });

  test('v1 upgrade retains the original mistake and adds missing schema',
      () async {
    final old = await openDatabase(path, version: 1, onCreate: (db, _) async {
      await db.execute(
          'CREATE TABLE error_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'topic_id TEXT NOT NULL, error_type TEXT NOT NULL, timestamp TEXT NOT NULL)');
      await db.insert('error_entries', {
        'id': 9,
        'topic_id': 'articles',
        'error_type': 'missing',
        'timestamp': '2026-01-01T00:00:00'
      });
    });
    await old.close();
    await storage.getClimbProgress(2026, 9);
    final db = await inspect();
    final row = (await db.query('error_entries')).single;
    expect(row['id'], 9);
    expect(row['source'], 'topic_practice');
    expect((await storage.getWeakSpots()).single.frequency, 1);
    expect(await db.getVersion(), 20);
  });

  test('concurrent and stale retries persist one completion, gain and mistake',
      () async {
    final set = await storage.saveDailyTestSet(questions);
    final result = completion(set, {'q0': 'wrong', 'q1': 'cookıng'});
    await Future.wait([saveCompletion(result), saveCompletion(result)]);
    expect(await storage.getClimbProgress(2026, 9),
        (steps: 1, correct: 1, wrong: 1, skipped: 3));
    final db = await inspect();
    expect(await db.query('error_entries'), hasLength(1));
    expect(await db.query('climb_daily_entries'), hasLength(1));
    await db.close();
    inspection = null;
    storage = StorageService(dbName: path);
    await saveCompletion(result);
    expect((await storage.getClimbProgress(2026, 9)).steps, 1);
    final cached = await storage.saveDailyTestSet([]);
    expect(cached.questions, hasLength(5));
    expect(cached.isCompleted, isTrue);
    await inspect();
  });

  test(
      'a ledger write failure rolls back completion and mistakes; retry succeeds',
      () async {
    final set = await storage.saveDailyTestSet(questions);
    final db = await inspect();
    await db.execute(
        "CREATE TRIGGER fail_climb BEFORE INSERT ON climb_daily_entries "
        "BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END");
    final result = completion(set, {'q0': 'wrong'});
    await expectLater(
        saveCompletion(result), throwsA(isA<DatabaseException>()));
    expect((await storage.getDailyTestSetForToday())!.isCompleted, isFalse);
    expect(await db.query('error_entries'), isEmpty);
    expect(await db.query('climb_daily_entries'), isEmpty);
    await db.execute('DROP TRIGGER fail_climb');
    await saveCompletion(result);
    expect((await storage.getClimbProgress(2026, 9)).steps, 1);
    expect(await db.query('error_entries'), hasLength(1));
  });

  test('all skipped completes with no step; any wrong answer still earns one',
      () async {
    var set = await storage.saveDailyTestSet(questions);
    await saveCompletion(completion(set, {'q0': '   ', 'unknown': 'answer'}));
    expect((await storage.getDailyTestSetForToday())!.isCompleted, isTrue);
    expect(await storage.getClimbProgress(2026, 9),
        (steps: 0, correct: 0, wrong: 0, skipped: 5));
    StorageService.clockForTesting = () => DateTime(2026, 10, 1);
    set = await storage.saveDailyTestSet(questions);
    await saveCompletion(completion(set, {'q0': 'wrong'}));
    expect(await storage.getClimbProgress(2026, 10),
        (steps: 1, correct: 0, wrong: 1, skipped: 4));
    await inspect();
  });

  for (final lastDay in [
    DateTime(2026, 2, 28),
    DateTime(2028, 2, 29),
    DateTime(2026, 9, 30),
    DateTime(2026, 12, 31)
  ]) {
    test(
        'month/year boundary credits original day $lastDay and preserves new day',
        () async {
      StorageService.clockForTesting = () => lastDay;
      final previous = await storage.saveDailyTestSet(questions);
      final nextDay = lastDay.add(const Duration(days: 1));
      StorageService.clockForTesting = () => nextDay;
      final next = await storage.saveDailyTestSet(questions);
      await saveCompletion(completion(previous, {'q0': 'cooking'}));
      expect((await storage.getDailyTestSetForToday())!.isCompleted, isFalse);
      expect(
          (await storage.getClimbProgress(lastDay.year, lastDay.month)).steps,
          1);
      expect(
          (await storage.getClimbProgress(nextDay.year, nextDay.month)).steps,
          0);
      await saveCompletion(completion(next, {'q0': 'cooking'}));
      expect(
          (await storage.getClimbProgress(nextDay.year, nextDay.month)).steps,
          1);
      await inspect();
    });
  }

  test('a backward local-day change cannot duplicate a previously earned day',
      () async {
    final set = await storage.saveDailyTestSet(questions);
    await saveCompletion(completion(set, {'q0': 'cooking'}));
    StorageService.clockForTesting = () => DateTime(2026, 9, 29);
    expect(await storage.getDailyTestSetForToday(), isNull);
    await saveCompletion(completion(set, {'q0': 'wrong'}));
    expect((await storage.getClimbProgress(2026, 9)).steps, 1);
    await inspect();
  });

  group('Welcome badge earned via completeDailyTest', () {
    test(
        'the first step = 1 ledger entry ever written earns it, live (not '
        'backfilled)', () async {
      final set = await storage.saveDailyTestSet(questions);
      final justEarned =
          await saveCompletionReturning(completion(set, {'q0': 'cooking'}));

      expect(justEarned, isTrue);
      final badge = await storage.getWelcomeBadge();
      expect(badge, isNotNull);
      expect(badge!.backfilled, isFalse);
      expect(badge.earnedAt, DateTime(2026, 10, 1, 0, 3));
    });

    test(
        'an all-skipped first test earns nothing but still writes its ledger '
        'row; the next test with an answer earns it, and only once', () async {
      final skippedSet = await storage.saveDailyTestSet(questions);
      final skippedEarned = await saveCompletionReturning(
          completion(skippedSet, {'q0': '   ', 'q1': ''}));

      expect(skippedEarned, isFalse);
      expect(await storage.getWelcomeBadge(), isNull);
      // The all-skipped row is still recorded (completes, no step).
      expect(await storage.getClimbProgress(2026, 9),
          (steps: 0, correct: 0, wrong: 0, skipped: 5));

      StorageService.clockForTesting = () => DateTime(2026, 10, 1);
      final answeredSet = await storage.saveDailyTestSet(questions);
      final answeredEarned = await saveCompletionReturning(
          completion(answeredSet, {'q0': 'cooking'}));

      expect(answeredEarned, isTrue);
      final badge = await storage.getWelcomeBadge();
      expect(badge, isNotNull);
      expect(badge!.backfilled, isFalse);

      StorageService.clockForTesting = () => DateTime(2026, 10, 2);
      final laterSet = await storage.saveDailyTestSet(questions);
      final laterEarned = await saveCompletionReturning(
          completion(laterSet, {'q0': 'cooking'}));
      expect(laterEarned, isFalse, reason: 'already earned — never twice');
    });

    test(
        'an all-skipped test after the badge is earned neither re-earns nor '
        'disturbs it', () async {
      final first = await storage.saveDailyTestSet(questions);
      expect(await saveCompletionReturning(completion(first, {'q0': 'a'})),
          isTrue);
      final earnedAt = (await storage.getWelcomeBadge())!.earnedAt;

      StorageService.clockForTesting = () => DateTime(2026, 10, 1);
      final second = await storage.saveDailyTestSet(questions);
      expect(await saveCompletionReturning(completion(second, {'q0': ''})),
          isFalse);
      expect((await storage.getWelcomeBadge())!.earnedAt, earnedAt);
    });

    test('a second, later completion does not re-earn it', () async {
      final first = await storage.saveDailyTestSet(questions);
      expect(await saveCompletionReturning(completion(first, {'q0': 'a'})),
          isTrue);

      StorageService.clockForTesting = () => DateTime(2026, 10, 1);
      final second = await storage.saveDailyTestSet(questions);
      final justEarnedAgain =
          await saveCompletionReturning(completion(second, {'q0': 'cooking'}));

      expect(justEarnedAgain, isFalse);
      final badge = await storage.getWelcomeBadge();
      // Still dated to the first completion, not overwritten by the second.
      expect(badge!.earnedAt, DateTime(2026, 10, 1, 0, 3));
    });

    test(
        'a rolled-back completion (simulated write failure) earns nothing; '
        'the retry that actually succeeds earns it', () async {
      final set = await storage.saveDailyTestSet(questions);
      final db = await inspect();
      await db.execute(
          "CREATE TRIGGER fail_climb BEFORE INSERT ON climb_daily_entries "
          "BEGIN SELECT RAISE(ABORT, 'simulated write failure'); END");

      await expectLater(
        saveCompletionReturning(completion(set, {'q0': 'wrong'})),
        throwsA(isA<DatabaseException>()),
      );
      expect(await storage.getWelcomeBadge(), isNull);

      await db.execute('DROP TRIGGER fail_climb');
      final justEarned =
          await saveCompletionReturning(completion(set, {'q0': 'wrong'}));
      expect(justEarned, isTrue);
      expect(await storage.getWelcomeBadge(), isNotNull);
    });

    test(
        'concurrent duplicate completions of the same day earn it exactly '
        'once, never twice', () async {
      final set = await storage.saveDailyTestSet(questions);
      final result = completion(set, {'q0': 'wrong'});
      final outcomes = await Future.wait(
          [saveCompletionReturning(result), saveCompletionReturning(result)]);

      // Exactly one of the two concurrent calls is the one that actually
      // wrote the (unique, day-keyed) ledger row and earned the badge —
      // the other is the no-op branch for an already-completed set.
      expect(outcomes.where((earned) => earned), hasLength(1));
      final db = await inspect();
      expect(await db.query('welcome_badge'), hasLength(1));
    });

    test(
        'reopening an already-completed set never re-earns it (idempotent '
        'no-op, not a fresh completion)', () async {
      final set = await storage.saveDailyTestSet(questions);
      expect(
          await saveCompletionReturning(completion(set, {'q0': 'a'})), isTrue);

      final reopened =
          await saveCompletionReturning(completion(set, {'q0': 'a'}));
      expect(reopened, isFalse);
    });
  });
}
