import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/app_theme_mode.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Proves `StorageService.onUpgrade` carries real rows across a schema
/// bump instead of the drop-and-recreate it used to do (docs/build-log.md's
/// migration-safety entry): every table but `device_identity` used to be
/// dropped and recreated empty on *any* version transition, wiping
/// error history, Daily Test sets, the user's profile (incl. avatar) and
/// per-topic stats on every future release, not just ones that actually
/// touch those tables.
///
/// Builds each "old" database directly with raw SQL matching that
/// historical schema shape — bypassing `StorageService` entirely for the
/// setup step — then opens it through a real `StorageService` at the
/// current `_dbVersion`, so `onUpgrade` genuinely runs the same code path
/// a real device upgrade would.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('migrating from the oldest supported schema (v1)', () {
    const dbName = 'test_migration_v1.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    test(
        'a real error_entries row survives an upgrade all the way to the '
        'current schema, and every later table is created and usable',
        () async {
      // v1's error_entries had only 4 columns, all NOT NULL — no prompt/
      // user_answer/corrected_answer/explanation/rule/source, and no other
      // table existed at all.
      final oldDb = await databaseFactory.openDatabase(path);
      await oldDb.execute('''
        CREATE TABLE error_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          topic_id TEXT NOT NULL,
          error_type TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
      await oldDb.insert('error_entries', {
        'topic_id': 'tenseSelection',
        'error_type': 'wrong_tense',
        'timestamp': '2026-01-01T00:00:00.000',
      });
      await oldDb.setVersion(1);
      await oldDb.close();

      final storageService = StorageService(dbName: dbName);

      // The seeded row must still be there, readable through the normal
      // getter, with the columns added after v1 correctly backfilled.
      final mistakes = await storageService.getRecentMistakes(
        'tenseSelection',
        'wrong_tense',
      );
      expect(mistakes, hasLength(1));
      expect(mistakes.single.topicId, 'tenseSelection');
      expect(mistakes.single.errorType, 'wrong_tense');
      expect(
          mistakes.single.timestamp, DateTime.parse('2026-01-01T00:00:00.000'));
      expect(mistakes.single.prompt, isNull);
      // Backfilled by the v11->v12 column's own DEFAULT — every row
      // written before that column existed really was Topic Practice's.
      expect(mistakes.single.source, ErrorSource.topicPractice);

      // Every table introduced after v1 must exist and be queryable, not
      // just error_entries.
      expect(await storageService.getUserProfile(), isNull);
      expect(await storageService.getDailyTestSetForToday(), isNull);
      expect(await storageService.getSessionCountForToday(), 0);
      expect(await storageService.getFreePracticeCountForToday(), 0);
      expect(await storageService.getDebugAccessOverride(), isNull);
      expect(await storageService.getOrCreateDeviceId(), isNotEmpty);
      expect(await storageService.getReviewSortOrder(), isNotNull);
      expect(await storageService.getThemeMode(), isNotNull);
      expect(await storageService.getTextSize(), AppTextSize.medium);
      await storageService.setTextSize(AppTextSize.large);
      expect(await storageService.getTextSize(), AppTextSize.large);
      expect(await storageService.getPracticeLength(), isNotNull);
      final topicStats = await storageService.getTopicStats();
      expect(topicStats['tenseSelection']?.weakSpotCount, 1);
    });
  });

  group('migrating from v13 to the current schema (v14)', () {
    const dbName = 'test_migration_v13.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    test('real rows across every v13 table survive the v13 -> v14 upgrade',
        () async {
      final oldDb = await databaseFactory.openDatabase(path);
      // Recreate the exact v13 schema (every table that exists by v13,
      // in its v13 shape — error_entries already has `source`, user_profile
      // already has `avatar`, daily_test_sets already has `answers_json`;
      // only `free_practice_usage`, added at v14, is missing).
      await oldDb.execute('''
        CREATE TABLE error_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          topic_id TEXT NOT NULL,
          error_type TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          prompt TEXT,
          user_answer TEXT,
          corrected_answer TEXT,
          explanation TEXT,
          rule TEXT,
          source TEXT NOT NULL DEFAULT 'topic_practice'
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE review_settings (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          sort_order TEXT NOT NULL
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE theme_settings (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          mode TEXT NOT NULL
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE practice_settings (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          question_count INTEGER NOT NULL
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE topic_practice_stats (
          topic_id TEXT PRIMARY KEY,
          questions_answered INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          name TEXT NOT NULL,
          learning_goal TEXT NOT NULL,
          age INTEGER,
          occupation TEXT,
          avatar TEXT
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE daily_session_usage (
          day TEXT PRIMARY KEY,
          session_count INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE daily_test_sets (
          day TEXT PRIMARY KEY,
          questions_json TEXT NOT NULL,
          completed_at TEXT,
          answers_json TEXT
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE debug_settings (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          access_override TEXT
        )
      ''');
      await oldDb.execute('''
        CREATE TABLE device_identity (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          device_id TEXT NOT NULL
        )
      ''');

      // Seed a real row in every one of those tables.
      await oldDb.insert('error_entries', {
        'topic_id': 'articleUsage',
        'error_type': 'missing_article',
        'timestamp': '2026-09-01T10:00:00.000',
        'prompt': 'I saw ___ dog.',
        'user_answer': 'I saw dog.',
        'corrected_answer': 'I saw a dog.',
        'explanation': "Singular countable nouns need an article.",
        'rule': 'Articles',
        'source': 'daily_test',
      });
      await oldDb
          .insert('review_settings', {'id': 0, 'sort_order': 'frequent'});
      await oldDb.insert('theme_settings', {'id': 0, 'mode': 'dark'});
      await oldDb.insert('practice_settings', {'id': 0, 'question_count': 10});
      await oldDb.insert('topic_practice_stats',
          {'topic_id': 'articleUsage', 'questions_answered': 42});
      await oldDb.insert('user_profile', {
        'id': 0,
        'name': 'Ada',
        'learning_goal': 'work',
        'age': 30,
        'occupation': 'Engineer',
        'avatar': 'avatar_03',
      });
      await oldDb.insert(
          'daily_session_usage', {'day': '2026-09-16', 'session_count': 4});
      await oldDb.insert('daily_test_sets', {
        'day': '2026-09-16',
        'questions_json': '[]',
        'completed_at': '2026-09-16T09:00:00.000',
        'answers_json': '{"q1":"a dog"}',
      });
      await oldDb
          .insert('debug_settings', {'id': 0, 'access_override': 'full'});
      await oldDb.insert(
          'device_identity', {'id': 0, 'device_id': 'existing-device-id'});
      await oldDb.setVersion(13);
      await oldDb.close();

      final storageService = StorageService(dbName: dbName);

      final mistakes = await storageService.getRecentMistakes(
          'articleUsage', 'missing_article');
      expect(mistakes, hasLength(1));
      expect(mistakes.single.source, ErrorSource.dailyTest);
      expect(mistakes.single.correctedAnswer, 'I saw a dog.');

      expect(
          await storageService.getReviewSortOrder(), ReviewSortOrder.frequent);
      expect(await storageService.getThemeMode(), AppThemeMode.dark);

      final profile = await storageService.getUserProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Ada');
      expect(profile.learningGoal, LearningGoal.work);
      expect(profile.avatar, Avatar.values[2]);

      final topicStats = await storageService.getTopicStats();
      expect(topicStats['articleUsage']?.practiced, 42);

      expect(await storageService.getSessionCountForToday(), 0);

      final dailyTestSet = await storageService.getDailyTestSetForToday();
      expect(dailyTestSet, isNull); // seeded row was for 2026-09-16, not today

      // device_identity must survive untouched — getOrCreateDeviceId must
      // return the pre-existing id, never regenerate a new one.
      expect(await storageService.getOrCreateDeviceId(), 'existing-device-id');

      expect(await storageService.getDebugAccessOverride(), isTrue);

      // free_practice_usage is new at v14 and must now exist and be usable.
      expect(await storageService.getFreePracticeCountForToday(), 0);
    });
  });

  group(
      'idempotency — a downgrade can leave onUpgrade re-running over an '
      'already-migrated schema', () {
    const dbName = 'test_migration_idempotency.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    test('running onUpgrade a second time over the same db is harmless',
        () async {
      // First migration: v1 -> current, with one real row.
      final oldDb = await databaseFactory.openDatabase(path);
      await oldDb.execute('''
        CREATE TABLE error_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          topic_id TEXT NOT NULL,
          error_type TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
      await oldDb.insert('error_entries', {
        'topic_id': 'prepositions',
        'error_type': 'wrong_preposition',
        'timestamp': '2026-02-01T00:00:00.000',
      });
      await oldDb.setVersion(1);
      await oldDb.close();

      var storageService = StorageService(dbName: dbName);
      await storageService.getRecentMistakes(
          'prepositions', 'wrong_preposition');
      final deviceIdAfterFirstUpgrade =
          await storageService.getOrCreateDeviceId();

      // Reproduce sqflite's own silent-downgrade landmine (see
      // `onUpgrade`'s doc comment in storage_service.dart): the stored
      // version gets forced back down without the schema itself changing
      // at all, e.g. by installing an older build after this one. The next
      // upgrade back to the current version then re-runs every step above
      // over a schema that already has everything they're about to add.
      final rawDb = await databaseFactory.openDatabase(path);
      await rawDb.setVersion(1);
      await rawDb.close();

      // A fresh StorageService instance forces sqflite to reopen the file
      // and re-evaluate onUpgrade(1, current) from scratch.
      storageService = StorageService(dbName: dbName);

      // Must not throw (e.g. "duplicate column name: source" from a
      // non-idempotent ALTER TABLE, or a UNIQUE/PRIMARY KEY violation from
      // a non-idempotent CREATE TABLE).
      final mistakesAfterSecondUpgrade = await storageService.getRecentMistakes(
          'prepositions', 'wrong_preposition');

      // The original row must still be exactly one row, not duplicated or
      // altered by the second pass.
      expect(mistakesAfterSecondUpgrade, hasLength(1));
      expect(mistakesAfterSecondUpgrade.single.topicId, 'prepositions');

      // device_identity must not have been regenerated by the second pass.
      expect(await storageService.getOrCreateDeviceId(),
          deviceIdAfterFirstUpgrade);
    });
  });

  group('v19: age and occupation are removed from the profile', () {
    const dbName = 'test_migration_v19.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    Future<List<String>> profileColumns() async {
      final db = await databaseFactory.openDatabase(path);
      final info = await db.rawQuery('PRAGMA table_info(user_profile)');
      await db.close();
      return [for (final row in info) row['name'] as String];
    }

    /// A v18-shaped database: user_profile still has age and occupation, and
    /// holds real values in them.
    Future<void> seedV18Profile({Object? avatar = 'avatar_03'}) async {
      final db = await databaseFactory.openDatabase(path);
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          name TEXT NOT NULL,
          learning_goal TEXT NOT NULL,
          age INTEGER,
          occupation TEXT,
          avatar TEXT
        )
      ''');
      await db.insert('user_profile', {
        'id': 0,
        'name': 'Ada',
        'learning_goal': 'work',
        'age': 34,
        'occupation': 'Nurse',
        'avatar': avatar,
      });
      await db.setVersion(18);
      await db.close();
    }

    test(
        'the columns and every stored value are gone; the rest of the '
        'profile survives', () async {
      await seedV18Profile();
      final storage = StorageService(dbName: dbName);

      final profile = await storage.getUserProfile();
      expect(profile, isNotNull);
      expect(profile!.name, 'Ada');
      expect(profile.learningGoal, LearningGoal.work);
      expect(profile.avatar, Avatar.values[2]);

      expect(await profileColumns(), ['id', 'name', 'learning_goal', 'avatar']);
      // Nothing of the old values remains anywhere in the row.
      final db = await databaseFactory.openDatabase(path);
      final raw = (await db.query('user_profile')).single;
      await db.close();
      expect(raw.values, isNot(contains(34)));
      expect(raw.values, isNot(contains('Nurse')));
    });

    test('a profile with no avatar migrates too', () async {
      await seedV18Profile(avatar: null);
      final profile = await StorageService(dbName: dbName).getUserProfile();
      expect(profile!.name, 'Ada');
      expect(profile.avatar, isNull);
    });

    test('a database with no profile row migrates cleanly', () async {
      final db = await databaseFactory.openDatabase(path);
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          name TEXT NOT NULL,
          learning_goal TEXT NOT NULL,
          age INTEGER,
          occupation TEXT,
          avatar TEXT
        )
      ''');
      await db.setVersion(18);
      await db.close();

      expect(await StorageService(dbName: dbName).getUserProfile(), isNull);
      expect(await profileColumns(), ['id', 'name', 'learning_goal', 'avatar']);
    });

    test('saving a profile works on the migrated table', () async {
      await seedV18Profile();
      final storage = StorageService(dbName: dbName);
      final profile = (await storage.getUserProfile())!;

      await storage.saveUserProfile(profile.copyWith(name: 'Grace'));

      expect((await storage.getUserProfile())!.name, 'Grace');
    });

    test('a replayed migration (downgrade, then upgrade again) is a no-op',
        () async {
      await seedV18Profile();
      await StorageService(dbName: dbName).getUserProfile();

      // Simulate the downgrade sqflite allows: version lowered, table shape
      // untouched. The next open runs the v19 step over a migrated table.
      final db = await databaseFactory.openDatabase(path);
      await db.setVersion(18);
      await db.close();

      final profile = await StorageService(dbName: dbName).getUserProfile();
      expect(profile!.name, 'Ada');
      expect(profile.avatar, Avatar.values[2]);
      expect(await profileColumns(), ['id', 'name', 'learning_goal', 'avatar']);
    });

    test('a fresh install never creates the columns', () async {
      await StorageService(dbName: dbName).getUserProfile();
      expect(await profileColumns(), ['id', 'name', 'learning_goal', 'avatar']);
    });
  });

  group('v20: the AI permission table', () {
    const dbName = 'test_migration_v20.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    /// A v19-shaped database: everything but ai_consent, holding a profile.
    Future<void> seedV19() async {
      final db = await databaseFactory.openDatabase(path);
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          name TEXT NOT NULL,
          learning_goal TEXT NOT NULL,
          avatar TEXT
        )
      ''');
      await db.insert('user_profile',
          {'id': 0, 'name': 'Ada', 'learning_goal': 'work', 'avatar': null});
      await db.setVersion(19);
      await db.close();
    }

    test(
        'an existing user gets the table with no row: never asked, existing '
        'data untouched', () async {
      await seedV19();
      final storage = StorageService(dbName: dbName);

      expect(await storage.getAiConsent(), isNull);
      expect((await storage.getUserProfile())!.name, 'Ada');
      await storage.setAiConsent(granted: true);
      expect((await storage.getAiConsent())!.allowsSending, isTrue);
    });

    test('a replayed migration (downgrade, then upgrade) keeps the decision',
        () async {
      await seedV19();
      await StorageService(dbName: dbName).setAiConsent(granted: true);

      final db = await databaseFactory.openDatabase(path);
      await db.setVersion(19);
      await db.close();

      final consent = await StorageService(dbName: dbName).getAiConsent();
      expect(consent!.allowsSending, isTrue);
    });

    test('a fresh install creates the table too', () async {
      final storage = StorageService(dbName: dbName);
      expect(await storage.getAiConsent(), isNull);
      await storage.setAiConsent(granted: false);
      expect((await storage.getAiConsent())!.granted, isFalse);
    });
  });

  group('v21: the Daily Test set source', () {
    const dbName = 'test_migration_v21.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    const questionsJson = '[{"id":"q1","type":"fill_in_blank",'
        '"instruction":"Fill in.","topicId":"tenseSelection",'
        '"correctAnswer":"goes","commonWrongAnswers":[]}]';

    /// A v20-shaped daily_test_sets table (no `source`) with a pending set
    /// and a completed one.
    Future<void> seedV20() async {
      final db = await databaseFactory.openDatabase(path);
      await db.execute('''
        CREATE TABLE daily_test_sets (
          day TEXT PRIMARY KEY,
          questions_json TEXT NOT NULL,
          completed_at TEXT,
          answers_json TEXT
        )
      ''');
      await db.insert('daily_test_sets', {
        'day': '2026-09-20',
        'questions_json': questionsJson,
        'completed_at': '2026-09-20T09:00:00.000',
        'answers_json': '{"q1":"goes"}',
      });
      await db.insert('daily_test_sets', {
        'day': '2026-09-21',
        'questions_json': questionsJson,
      });
      await db.setVersion(20);
      await db.close();
    }

    Future<List<Map<String, Object?>>> rows() async {
      final db = await databaseFactory.openDatabase(path);
      final result = await db.query('daily_test_sets', orderBy: 'day ASC');
      await db.close();
      return result;
    }

    test('existing sets become generated and keep their answers and dates',
        () async {
      await seedV20();
      // Any read opens the database and runs the upgrade.
      await StorageService(dbName: dbName).getDailyTestSetForToday();

      final stored = await rows();
      expect(stored.map((r) => r['source']), ['generated', 'generated']);
      expect(stored.first['completed_at'], '2026-09-20T09:00:00.000');
      expect(stored.first['answers_json'], '{"q1":"goes"}');
      expect(stored.last['completed_at'], isNull);
    });

    test('the column is NOT NULL with a generated default', () async {
      await seedV20();
      await StorageService(dbName: dbName).getDailyTestSetForToday();

      final db = await databaseFactory.openDatabase(path);
      final column = (await db.rawQuery('PRAGMA table_info(daily_test_sets)'))
          .singleWhere((r) => r['name'] == 'source');
      // A row inserted without the column falls back to the default.
      await db.insert('daily_test_sets',
          {'day': '2026-09-22', 'questions_json': questionsJson});
      final inserted = await db.query('daily_test_sets',
          where: 'day = ?', whereArgs: ['2026-09-22']);
      await db.close();

      expect(column['notnull'], 1);
      expect(inserted.single['source'], 'generated');
    });

    test('a migrated set reads as generated through the service', () async {
      await seedV20();
      final storage = StorageService(dbName: dbName);
      StorageService.clockForTesting = () => DateTime(2026, 9, 21, 12);
      addTearDown(() => StorageService.clockForTesting = DateTime.now);

      final set = await storage.getDailyTestSetForToday();

      expect(set!.source, DailyTestSource.generated);
    });

    test('a replayed migration (downgrade, then upgrade) keeps a bundled set',
        () async {
      await seedV20();
      final storage = StorageService(dbName: dbName);
      StorageService.clockForTesting = () => DateTime(2026, 9, 23, 12);
      addTearDown(() => StorageService.clockForTesting = DateTime.now);
      await storage.saveDailyTestSet(const [], source: DailyTestSource.bundled);

      final db = await databaseFactory.openDatabase(path);
      await db.setVersion(20);
      await db.close();

      final set =
          await StorageService(dbName: dbName).getDailyTestSetForToday();
      expect(set!.source, DailyTestSource.bundled);
      expect((await rows()).map((r) => r['source']),
          ['generated', 'generated', 'bundled']);
    });

    test('a fresh install creates the column', () async {
      final storage = StorageService(dbName: dbName);
      await storage.saveDailyTestSet(const [], source: DailyTestSource.bundled);

      expect((await storage.getDailyTestSetForToday())!.source,
          DailyTestSource.bundled);
    });
  });

  group('v22: the one-time flags table', () {
    const dbName = 'test_migration_v22.db';
    late String path;

    setUp(() async {
      path = join(await getDatabasesPath(), dbName);
      await databaseFactory.deleteDatabase(path);
    });

    /// A v21-shaped database: a profile and a daily test set, no flags table.
    Future<void> seedV21() async {
      final db = await databaseFactory.openDatabase(path);
      await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY CHECK (id = 0),
          name TEXT NOT NULL,
          learning_goal TEXT NOT NULL,
          avatar TEXT
        )
      ''');
      await db.insert('user_profile',
          {'id': 0, 'name': 'Ada', 'learning_goal': 'work', 'avatar': null});
      await db.setVersion(21);
      await db.close();
    }

    Future<List<Map<String, Object?>>> flagRows() async {
      final db = await databaseFactory.openDatabase(path);
      final rows = await db.query('one_time_flags');
      await db.close();
      return rows;
    }

    test('an existing user gets the empty table; nothing else changes',
        () async {
      await seedV21();
      final storage = StorageService(dbName: dbName);

      expect((await storage.getUserProfile())!.name, 'Ada');
      expect(await flagRows(), isEmpty);
      // Nothing was claimed by the upgrade: the first claim still wins. (A new
      // service, as flagRows() closed the shared connection.)
      expect(await StorageService(dbName: dbName).claimOneTimeFlag('day0_paywall'),
          isTrue);
    });

    test('the table has exactly the key and set_at columns, key as the primary '
        'key', () async {
      await seedV21();
      await StorageService(dbName: dbName).getUserProfile();

      final db = await databaseFactory.openDatabase(path);
      final info = await db.rawQuery('PRAGMA table_info(one_time_flags)');
      await db.close();
      expect(info.map((r) => r['name']), ['key', 'set_at']);
      expect(info.singleWhere((r) => r['name'] == 'key')['pk'], 1);
      expect(info.singleWhere((r) => r['name'] == 'set_at')['notnull'], 1);
    });

    test('a replayed migration (downgrade, then upgrade) keeps a claimed flag',
        () async {
      await seedV21();
      final storage = StorageService(dbName: dbName);
      expect(await storage.claimOneTimeFlag('day0_paywall'), isTrue);

      final db = await databaseFactory.openDatabase(path);
      await db.setVersion(21);
      await db.close();

      final reopened = StorageService(dbName: dbName);
      expect(await reopened.claimOneTimeFlag('day0_paywall'), isFalse);
      expect(await flagRows(), hasLength(1));
    });

    test('a fresh install creates the table too', () async {
      final storage = StorageService(dbName: dbName);
      expect(await storage.claimOneTimeFlag('day0_paywall'), isTrue);
      expect(await flagRows(), hasLength(1));
    });
  });
}
