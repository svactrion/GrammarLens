import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// `climb_month_themes` (schema v23): the theme each month's climb was shown
/// with. Written once for the current month, never backfilled, never changed.
final _questions = [
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
  Database? inspection;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('climb-month-theme-test-');
    path = join(dir.path, 'app.db');
    StorageService.clockForTesting = () => DateTime(2026, 11, 14, 9);
  });

  tearDown(() async {
    await inspection?.close();
    inspection = null;
    await databaseFactory.deleteDatabase(path);
    await dir.delete(recursive: true);
    StorageService.clockForTesting = DateTime.now;
  });

  Future<List<Map<String, Object?>>> themeRows() async {
    inspection ??= await openDatabase(path);
    return inspection!.query('climb_month_themes', orderBy: 'month');
  }

  /// A v22 database with real climb, medal, badge, flag and profile rows,
  /// built from the v22 table shapes (only the tables the checks read).
  Future<void> seedV22() async {
    final db = await databaseFactory.openDatabase(path);
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY CHECK (id = 0),
        name TEXT NOT NULL,
        learning_goal TEXT NOT NULL,
        avatar TEXT
      )''');
    await db.execute('''
      CREATE TABLE climb_daily_entries (
        day TEXT PRIMARY KEY NOT NULL,
        completed_at TEXT NOT NULL,
        step INTEGER NOT NULL CHECK (step IN (0, 1)),
        correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
        wrong_count INTEGER NOT NULL CHECK (wrong_count >= 0),
        skipped_count INTEGER NOT NULL CHECK (skipped_count >= 0),
        rule_version INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE monthly_medal_results (
        month TEXT PRIMARY KEY NOT NULL,
        tier TEXT CHECK (tier IN ('bronze', 'silver', 'gold')),
        score INTEGER NOT NULL CHECK (score >= 0),
        max_score INTEGER NOT NULL CHECK (max_score > 0),
        active_days INTEGER NOT NULL CHECK (active_days >= 0),
        correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
        wrong_count INTEGER NOT NULL CHECK (wrong_count >= 0),
        skipped_count INTEGER NOT NULL CHECK (skipped_count >= 0),
        rule_version INTEGER NOT NULL,
        finalized_at TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE welcome_badge (
        id INTEGER PRIMARY KEY CHECK (id = 0),
        earned_at TEXT NOT NULL,
        rule_version INTEGER NOT NULL,
        backfilled INTEGER NOT NULL CHECK (backfilled IN (0, 1))
      )''');
    await db.execute('''
      CREATE TABLE one_time_flags (
        key TEXT PRIMARY KEY,
        set_at TEXT NOT NULL
      )''');
    await db.insert('user_profile',
        {'id': 0, 'name': 'Ada', 'learning_goal': 'work', 'avatar': null});
    for (final day in ['2026-09-29', '2026-09-30', '2026-11-02']) {
      await db.insert('climb_daily_entries', {
        'day': day,
        'completed_at': '${day}T08:00:00.000',
        'step': 1,
        'correct_count': 4,
        'wrong_count': 1,
        'skipped_count': 0,
        'rule_version': 1,
      });
    }
    await db.insert('monthly_medal_results', {
      'month': '2026-09',
      'tier': 'bronze',
      'score': 80,
      'max_score': 300,
      'active_days': 2,
      'correct_count': 8,
      'wrong_count': 2,
      'skipped_count': 0,
      'rule_version': 1,
      'finalized_at': '2026-10-01T08:00:00.000',
    });
    await db.insert('welcome_badge', {
      'id': 0,
      'earned_at': '2026-09-29T08:00:00.000',
      'rule_version': 1,
      'backfilled': 0,
    });
    await db.insert('one_time_flags',
        {'key': 'day0_paywall', 'set_at': '2026-09-29T08:01:00.000'});
    await db.setVersion(22);
    await db.close();
  }

  group('v22 -> v23 migration', () {
    test('existing climb, medal, badge, flag and profile data survive',
        () async {
      await seedV22();
      final storage = StorageService(dbName: path);

      expect((await storage.getUserProfile())!.name, 'Ada');
      final november = await storage.getClimbProgress(2026, 11);
      expect(november.steps, 1);
      expect(november.correct, 4);
      final september = await storage.getClimbProgress(2026, 9);
      expect(september.steps, 2);
      final medals = await storage.getMonthlyMedalResults();
      expect(medals.single.month, 9);
      expect(medals.single.tier, MedalTier.bronze);
      expect(medals.single.score, 80);
      expect((await storage.getWelcomeBadge())!.backfilled, isFalse);
      expect(await storage.claimOneTimeFlag('day0_paywall'), isFalse);

      // The new table is there and empty: nothing is backfilled.
      expect(await themeRows(), isEmpty);
    });

    test('the table has month (primary key), theme_id and assigned_at',
        () async {
      await seedV22();
      await StorageService(dbName: path).getUserProfile();

      inspection ??= await openDatabase(path);
      final info =
          await inspection!.rawQuery('PRAGMA table_info(climb_month_themes)');
      expect(info.map((r) => r['name']), ['month', 'theme_id', 'assigned_at']);
      expect(info.singleWhere((r) => r['name'] == 'month')['pk'], 1);
      for (final column in ['theme_id', 'assigned_at']) {
        expect(info.singleWhere((r) => r['name'] == column)['notnull'], 1);
      }
      expect(await inspection!.getVersion(), 23);
    });

    test('a replayed migration (downgrade, then upgrade) keeps stored themes',
        () async {
      await seedV22();
      final storage = StorageService(dbName: path);
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'green_slope');

      final db = await databaseFactory.openDatabase(path);
      await db.setVersion(22);
      await db.close();

      final reopened = StorageService(dbName: path);
      expect(await reopened.resolveClimbMonthTheme(2026, 11), 'green_slope');
      expect(await themeRows(), hasLength(1));
      expect((await reopened.getClimbProgress(2026, 11)).steps, 1);
    });
  });

  group('resolveClimbMonthTheme', () {
    test('a past month without a row is green_slope and is not written',
        () async {
      final storage = StorageService(dbName: path);
      expect(await storage.resolveClimbMonthTheme(2026, 9), 'green_slope');
      expect(await storage.resolveClimbMonthTheme(2025, 12), 'green_slope');
      expect(await themeRows(), isEmpty);
    });

    test('the current month is written once, on first resolution', () async {
      final storage = StorageService(dbName: path);
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'green_slope');
      expect(await storage.resolveClimbMonthTheme(2026, 11), 'green_slope');

      final rows = await themeRows();
      expect(rows, hasLength(1));
      expect(rows.single['month'], '2026-11');
      expect(rows.single['theme_id'], 'green_slope');
      expect(rows.single['assigned_at'], '2026-11-14T09:00:00.000');
    });

    test('a stored month reads its row, even once it is in the past', () async {
      final storage = StorageService(dbName: path);
      await storage.getUserProfile(); // creates the database
      inspection ??= await openDatabase(path);
      await inspection!.insert('climb_month_themes', {
        'month': '2026-10',
        'theme_id': 'some_theme',
        'assigned_at': '2026-10-01T00:00:00.000',
      });
      expect(await storage.resolveClimbMonthTheme(2026, 10), 'some_theme');
    });

    test('a future month is not written', () async {
      final storage = StorageService(dbName: path);
      await storage.resolveClimbMonthTheme(2026, 12);
      expect(await themeRows(), isEmpty);
    });

    test('the month follows the climb calendar across the rollover', () async {
      final storage = StorageService(dbName: path);
      StorageService.clockForTesting = () => DateTime(2026, 11, 30, 23, 59);
      await storage.resolveClimbMonthTheme(2026, 11);
      StorageService.clockForTesting = () => DateTime(2026, 12, 1, 0, 1);
      await storage.resolveClimbMonthTheme(2026, 12);
      expect(
          (await themeRows()).map((r) => r['month']), ['2026-11', '2026-12']);
    });

    test('invalid months throw', () async {
      final storage = StorageService(dbName: path);
      expect(
          () => storage.resolveClimbMonthTheme(2026, 13), throwsArgumentError);
    });
  });

  test('completing a Daily Test records the current month\'s theme', () async {
    final storage = StorageService(dbName: path);
    final set = await storage.saveDailyTestSet(_questions);
    expect(set.day, '2026-11-14');
    await storage.completeDailyTest(
        {for (final q in _questions) q.item.id: 'cooking'}, const [],
        day: set.day, completedAt: DateTime(2026, 11, 14, 9, 5));

    final rows = await themeRows();
    expect(rows.single['month'], '2026-11');
    expect(rows.single['theme_id'], 'green_slope');
  });
}
