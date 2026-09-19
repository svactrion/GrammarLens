import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_theme_mode.dart';
import '../models/app_text_size.dart';
import '../models/daily_test_question.dart';
import '../models/daily_test_completion.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import '../models/medal_tier.dart';
import '../models/monthly_medal.dart';
import '../models/practice_length.dart';
import '../models/review_sort_order.dart';
import '../models/topic_stats.dart';
import '../models/user_profile.dart';
import '../models/welcome_badge.dart';
import 'monthly_medal_rules.dart';
import 'welcome_badge_rules.dart';

/// Local SQLite-backed error profile (PRD §5: "on-device storage; no
/// accounts"). Tracks topic × error type × frequency, driving the Review tab.
class StorageService {
  static const _defaultDbName = 'grammar_lens.db';
  static const _dbVersion = 18;

  // Overridable only so tests that exercise real SQLite (via
  // sqflite_common_ffi) can give each test file its own file on disk —
  // `flutter test` runs files concurrently, and they'd otherwise all
  // race on the one real device filename below.
  final String _dbName;

  StorageService({String dbName = _defaultDbName}) : _dbName = dbName;

  // Pre-launch checklist (PRD v2 §10.1) — a client-side daily cap bounds
  // Anthropic API spend per device without needing a server-side gate.
  // "10" is a placeholder reasonable default, not a measured number (§7.2
  // defers the real free-tier cap to post-launch cost data).
  static const int dailySessionLimit = 10;

  // Free tier's own daily cap on "Practice this" — the one real,
  // Claude-generated practice session a free (non-`hasFullAccess`) user gets
  // per day, from a weak spot's detail screen (`launchPracticeSet`).
  // Deliberately independent of [dailySessionLimit] above: that one is a
  // blanket cost guardrail applied to everyone regardless of entitlement,
  // this one is the actual product boundary between free and paid — Topic
  // Practice itself stays fully locked for a free user (`HomeScreen`), this
  // is the single exception. A free user is bounded by both numbers at
  // once (this one binds first, since it's the smaller of the two). Single
  // named constant so the gate, the button's caption, and the
  // exhausted-state copy all read the same number — never a literal.
  static const int freeDailyPracticeLimit = 1;

  /// Injectable clock, test-only — same seam pattern as
  /// `SubscriptionService.debugModeForTesting`. [_todayKey] reads through
  /// this instead of calling `DateTime.now()` directly so a test can prove
  /// a daily counter (session cap, free-practice quota, Daily Test cache)
  /// actually resets on a new calendar day without waiting for one or
  /// mutating the host clock. Never assigned outside a test.
  @visibleForTesting
  static DateTime Function() clockForTesting = DateTime.now;

  // `source` (added schema v12) distinguishes a Topic Practice mistake
  // from a Daily Test one — both write here now (2026-09-05 decision:
  // free tier diagnoses via Daily Test, paid tier treats via Topic
  // Practice — see docs/build-log.md). Defaults to the value every row
  // predating this column really was, since Topic Practice was the only
  // writer until now.
  static const _createTable = '''
    CREATE TABLE IF NOT EXISTS error_entries (
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
  ''';

  static const _createReviewSettingsTable = '''
    CREATE TABLE IF NOT EXISTS review_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      sort_order TEXT NOT NULL
    )
  ''';

  static const _createThemeSettingsTable = '''
    CREATE TABLE IF NOT EXISTS theme_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      mode TEXT NOT NULL
    )
  ''';

  static const _createTextSizeSettingsTable = '''
    CREATE TABLE IF NOT EXISTS text_size_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      size TEXT NOT NULL
    )
  ''';

  static const _createPracticeSettingsTable = '''
    CREATE TABLE IF NOT EXISTS practice_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      question_count INTEGER NOT NULL
    )
  ''';

  // Running per-topic total of answered (non-skipped) questions, across all
  // sessions. `error_entries` only logs mistakes, so it can't answer "how
  // many questions has the user practiced for this topic" on its own — this
  // is the minimal extra bit of state needed for the home screen's
  // "X practiced" stat.
  static const _createTopicPracticeStatsTable = '''
    CREATE TABLE IF NOT EXISTS topic_practice_stats (
      topic_id TEXT PRIMARY KEY,
      questions_answered INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // Guest-first identity (PRD v2 §5) — a row existing here is what "has
  // completed onboarding" means, so there's no separate boolean flag.
  static const _createUserProfileTable = '''
    CREATE TABLE IF NOT EXISTS user_profile (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      name TEXT NOT NULL,
      learning_goal TEXT NOT NULL,
      age INTEGER,
      occupation TEXT,
      avatar TEXT
    )
  ''';

  // Keyed by local calendar day ('YYYY-MM-DD') rather than a rolling
  // 24h window — simpler to reason about ("resets at midnight") and good
  // enough for a cost guardrail, which doesn't need to be precise to the
  // second.
  static const _createDailySessionUsageTable = '''
    CREATE TABLE IF NOT EXISTS daily_session_usage (
      day TEXT PRIMARY KEY,
      session_count INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // A third, separate daily counter — deliberately not a column on
  // `daily_session_usage` above, for the same reason `daily_test_sets`
  // isn't either (see that table's own comment): these are structurally
  // different tiers (PRD v2 §12.2) and must not interact. This one backs
  // [freeDailyPracticeLimit], counting only free-tier "Practice this"
  // sessions.
  static const _createFreePracticeUsageTable = '''
    CREATE TABLE IF NOT EXISTS free_practice_usage (
      day TEXT PRIMARY KEY,
      session_count INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // A separate cache from `daily_session_usage` above — Daily Test
  // generation must not consume or interact with Topic Practice's daily
  // session cap (PRD v2 §12.2: they're structurally different tiers). One
  // row per calendar day holds the whole generated set as JSON (there's
  // nothing to query inside it — it's always read/written as a unit) plus
  // a nullable completion timestamp, so re-opening the app the same day
  // shows the same set instead of generating a new one. `answers_json`
  // (added schema v11) holds the user's answers at the moment of
  // completion — needed so Home's "today" summary (PRD v2 §13.5) can show
  // a score and let the user view the result again without re-deriving
  // either from nothing: the score was never persisted anywhere before
  // this, only computed transiently in DailyTestResultScreen from an
  // in-memory answers map.
  static const _createDailyTestSetsTable = '''
    CREATE TABLE IF NOT EXISTS daily_test_sets (
      day TEXT PRIMARY KEY,
      questions_json TEXT NOT NULL,
      completed_at TEXT,
      answers_json TEXT
    )
  ''';

  // Debug-only developer setting (see SubscriptionService.debugAccessOverride):
  // 'full' / 'free' / absent-row (no override, use the real status). Reading
  // and writing this table is harmless in a release build — it's inert data
  // no release code path ever consults — the actual release-safety gate is
  // SubscriptionService's own kDebugMode check, not anything here.
  static const _createDebugSettingsTable = '''
    CREATE TABLE IF NOT EXISTS debug_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      access_override TEXT
    )
  ''';

  // Schema v13 — an anonymous, app-generated identifier the Cloudflare
  // Workers proxy uses for its per-device daily quota (docs/build-log.md).
  // Deliberately not a real device attribute (IDFV, ANDROID_ID, ...): a
  // random opaque token carries no personal data and is exactly as good
  // for "tell this install's requests apart from another's" as a real
  // identifier would be, without identifying anything real. Created once
  // on first use; resets on reinstall/data clear, which is fine since this
  // only bounds API cost per install, not a durable identity.
  //
  // Kept across every additive migration, alongside profile and history.
  static const _createDeviceIdentityTable = '''
    CREATE TABLE IF NOT EXISTS device_identity (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      device_id TEXT NOT NULL
    )
  ''';

  // One durable record per original set day. Outcome counts are raw facts;
  // medal scoring/thresholds are deliberately not baked into this schema.
  static const _createClimbEntriesTable = '''
    CREATE TABLE IF NOT EXISTS climb_daily_entries (
      day TEXT PRIMARY KEY NOT NULL,
      completed_at TEXT NOT NULL,
      step INTEGER NOT NULL CHECK (step IN (0, 1)),
      correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
      wrong_count INTEGER NOT NULL CHECK (wrong_count >= 0),
      skipped_count INTEGER NOT NULL CHECK (skipped_count >= 0),
      rule_version INTEGER NOT NULL
    )
  ''';

  static const _createMonthlyMedalResultsTable = '''
    CREATE TABLE IF NOT EXISTS monthly_medal_results (
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
    )
  ''';

  // One-time achievement, not recurring like the monthly medals above — a
  // row existing (always `id = 0`) means earned, the same "presence is the
  // boolean" pattern `user_profile` already uses for onboarding-complete.
  // `backfilled` distinguishes a v18-migration retroactive award (an
  // existing user with prior ledger history) from one earned live through
  // `completeDailyTest` — not surfaced differently in the UI today, kept
  // for future use. See docs/prd-gamification.md §M6.5.
  static const _createWelcomeBadgeTable = '''
    CREATE TABLE IF NOT EXISTS welcome_badge (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      earned_at TEXT NOT NULL,
      rule_version INTEGER NOT NULL,
      backfilled INTEGER NOT NULL CHECK (backfilled IN (0, 1))
    )
  ''';

  Database? _db;

  Future<Database> get _database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute(_createTable);
        await db.execute(_createReviewSettingsTable);
        await db.execute(_createThemeSettingsTable);
        await db.execute(_createTextSizeSettingsTable);
        await db.execute(_createPracticeSettingsTable);
        await db.execute(_createTopicPracticeStatsTable);
        await db.execute(_createUserProfileTable);
        await db.execute(_createDailySessionUsageTable);
        await db.execute(_createFreePracticeUsageTable);
        await db.execute(_createDailyTestSetsTable);
        await db.execute(_createDebugSettingsTable);
        await db.execute(_createDeviceIdentityTable);
        await db.execute(_createClimbEntriesTable);
        await db.execute(_createMonthlyMedalResultsTable);
        await db.execute(_createWelcomeBadgeTable);
      },
      // Incremental, per-version steps — replaying exactly what each past
      // schema bump actually added (each step below cites the commit that
      // introduced it), never a drop/recreate. A drop/recreate used to sit
      // here on the "no real user data yet" theory; once real installs
      // exist, the same code silently deletes every row in error_entries,
      // daily_test_sets, user_profile (incl. avatar) and topic_practice_stats
      // on every single version bump, not just ones that touch those
      // tables — see docs/build-log.md's migration-safety entry.
      //
      // Every step MUST be idempotent — CREATE TABLE IF NOT EXISTS for new
      // tables, a PRAGMA table_info check before ALTER TABLE ADD COLUMN for
      // new columns on an existing table — because sqflite silently lowers
      // the on-disk schema version on a downgrade (installing an older
      // build after a newer one) without touching the actual table shape:
      // the next upgrade back to a newer version can then re-run a step
      // whose table/column already exists. [_addColumnIfMissing] is the
      // shared guard for that; table-creation steps get it for free from
      // `IF NOT EXISTS` in the `_createXTable` constants themselves.
      onUpgrade: (db, oldVersion, newVersion) async {
        // v1 -> v2: error_entries gained prompt/user_answer/
        // corrected_answer/explanation/rule (all nullable TEXT).
        if (oldVersion < 2) {
          for (final column in [
            'prompt',
            'user_answer',
            'corrected_answer',
            'explanation',
            'rule',
          ]) {
            await _addColumnIfMissing(db, 'error_entries', column, 'TEXT');
          }
        }
        // v2 -> v3: review_settings.
        if (oldVersion < 3) {
          await db.execute(_createReviewSettingsTable);
        }
        // v3 -> v4: theme_settings + practice_settings.
        if (oldVersion < 4) {
          await db.execute(_createThemeSettingsTable);
          await db.execute(_createPracticeSettingsTable);
        }
        // v4 -> v5: topic_practice_stats.
        if (oldVersion < 5) {
          await db.execute(_createTopicPracticeStatsTable);
        }
        // v5 -> v6: user_profile. Created in its current (with `avatar`)
        // shape directly — a table that doesn't exist yet has no data to
        // preserve in a stale shape, so there's no need to create it
        // column-by-column across the v6 and v8 bumps; the oldVersion < 8
        // step below still guards the case where user_profile already
        // exists (a device already at v6 or v7) without that column.
        if (oldVersion < 6) {
          await db.execute(_createUserProfileTable);
        }
        // v6 -> v7: daily_session_usage.
        if (oldVersion < 7) {
          await db.execute(_createDailySessionUsageTable);
        }
        // v7 -> v8: user_profile gained a nullable `avatar` column.
        if (oldVersion < 8) {
          await _addColumnIfMissing(db, 'user_profile', 'avatar', 'TEXT');
        }
        // v8 -> v9: daily_test_sets, current (with `answers_json`) shape —
        // same reasoning as user_profile above.
        if (oldVersion < 9) {
          await db.execute(_createDailyTestSetsTable);
        }
        // v9 -> v10: debug_settings.
        if (oldVersion < 10) {
          await db.execute(_createDebugSettingsTable);
        }
        // v10 -> v11: daily_test_sets gained a nullable `answers_json`
        // column (only reachable if the table already existed without it —
        // a device already at v9 or v10).
        if (oldVersion < 11) {
          await _addColumnIfMissing(
              db, 'daily_test_sets', 'answers_json', 'TEXT');
        }
        // v11 -> v12: error_entries gained `source`, defaulting every
        // pre-existing row to 'topic_practice' — true of every row written
        // before this column existed, since Topic Practice was the only
        // writer at the time.
        if (oldVersion < 12) {
          await _addColumnIfMissing(db, 'error_entries', 'source',
              "TEXT NOT NULL DEFAULT 'topic_practice'");
        }
        // device_identity is deliberately NOT gated on a version check —
        // see its own doc comment above: it must survive/exist across every
        // upgrade, not just the v12 -> v13 bump that introduced it, and
        // `CREATE TABLE IF NOT EXISTS` makes running it unconditionally
        // every time safe.
        await db.execute(_createDeviceIdentityTable);
        // v13 -> v14: free_practice_usage.
        if (oldVersion < 14) {
          await db.execute(_createFreePracticeUsageTable);
        }
        if (oldVersion < 15) await db.execute(_createClimbEntriesTable);
        if (oldVersion < 16) await db.execute(_createTextSizeSettingsTable);
        if (oldVersion < 17) await db.execute(_createMonthlyMedalResultsTable);
        // v17 -> v18: welcome_badge, plus its one and only retroactive
        // award (docs/prd-gamification.md §M6.5). An existing install
        // already has every `climb_daily_entries` row it will ever have
        // from before this badge existed — by the time this line runs,
        // the `oldVersion < 15` step above has already created that table
        // even on a device upgrading from well before v15, so it's always
        // safe to read here regardless of the starting version. If it has
        // at least one row, this device earns the badge now, dated to its
        // *earliest* entry and marked `backfilled` — never a fresh
        // `completeDailyTest` call's job for a device that already has
        // history. `ConflictAlgorithm.ignore` makes this safe to run
        // again on the downgrade-then-upgrade sequence this whole method's
        // own doc comment describes: a second pass here must never
        // overwrite an award (backfilled or, in principle, a real one)
        // that already exists. There is deliberately no other backfill
        // path anywhere else in this codebase — a device that already
        // has ledger rows earns it here, once, or never at all.
        if (oldVersion < 18) {
          await db.execute(_createWelcomeBadgeTable);
          final earliest = await db.rawQuery(
            'SELECT MIN(day) AS earliest FROM climb_daily_entries',
          );
          final earliestDay = earliest.single['earliest'] as String?;
          if (earliestDay != null) {
            await db.insert(
              'welcome_badge',
              {
                'id': 0,
                'earned_at': DateTime.parse(earliestDay).toIso8601String(),
                'rule_version': WelcomeBadgeRules.ruleVersion,
                'backfilled': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      },
    );
  }

  /// True if [table] already has a column named [column] — the guard every
  /// `onUpgrade` column-adding step needs before an `ALTER TABLE ADD
  /// COLUMN`, since that step can legitimately run again over a schema that
  /// already has it (see `onUpgrade`'s own doc comment on sqflite's
  /// downgrade behavior).
  static Future<bool> _hasColumn(
    DatabaseExecutor db,
    String table,
    String column,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    return info.any((row) => row['name'] == column);
  }

  /// Adds `$column $definition` to [table] unless it's already there.
  /// [definition] is everything after the column name (type, NOT NULL,
  /// DEFAULT, ...) — SQLite backfills existing rows with DEFAULT when one
  /// is given, which is how [error_entries.source] became truthfully
  /// 'topic_practice' on every pre-v12 row without a separate data write.
  static Future<void> _addColumnIfMissing(
    DatabaseExecutor db,
    String table,
    String column,
    String definition,
  ) async {
    if (!await _hasColumn(db, table, column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> insertErrors(List<ErrorEntry> entries) async {
    final db = await _database;
    final batch = db.batch();
    for (final entry in entries) {
      batch.insert('error_entries', entry.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async {
    final db = await _database;
    final orderBy = sortOrder == ReviewSortOrder.frequent
        ? 'frequency DESC'
        : 'last_seen DESC';
    final rows = await db.rawQuery('''
      SELECT
        e.topic_id AS topic_id,
        e.error_type AS error_type,
        COUNT(*) AS frequency,
        MAX(e.timestamp) AS last_seen,
        (SELECT explanation FROM error_entries e2
         WHERE e2.topic_id = e.topic_id AND e2.error_type = e.error_type
         ORDER BY e2.timestamp DESC LIMIT 1) AS latest_explanation,
        (SELECT rule FROM error_entries e2
         WHERE e2.topic_id = e.topic_id AND e2.error_type = e.error_type
         ORDER BY e2.timestamp DESC LIMIT 1) AS latest_rule
      FROM error_entries e
      GROUP BY e.topic_id, e.error_type
      ORDER BY $orderBy
      LIMIT ?
    ''', [limit]);
    return rows
        .map((row) => WeakSpot(
              topicId: row['topic_id'] as String,
              errorType: row['error_type'] as String,
              frequency: row['frequency'] as int,
              lastSeen: DateTime.parse(row['last_seen'] as String),
              latestExplanation: row['latest_explanation'] as String?,
              latestRule: row['latest_rule'] as String?,
            ))
        .toList();
  }

  /// Most recent logged mistakes for one topic × error-type pair, newest
  /// first — feeds the Review weak-spot summary screen.
  Future<List<ErrorEntry>> getRecentMistakes(
    String topicId,
    String errorType, {
    int limit = 3,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'error_entries',
      where: 'topic_id = ? AND error_type = ?',
      whereArgs: [topicId, errorType],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.map(ErrorEntry.fromMap).toList();
  }

  /// The user's saved Review sort preference, so it survives navigation and
  /// app restarts. Defaults to [ReviewSortOrder.recent] if never set.
  Future<ReviewSortOrder> getReviewSortOrder() async {
    final db = await _database;
    final rows = await db.query('review_settings', limit: 1);
    if (rows.isEmpty) return ReviewSortOrder.recent;
    return ReviewSortOrderJson.fromJson(rows.first['sort_order'] as String?);
  }

  Future<void> setReviewSortOrder(ReviewSortOrder order) async {
    final db = await _database;
    await db.insert(
      'review_settings',
      {'id': 0, 'sort_order': order.toJson()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// The user's manually chosen theme, so it survives app restarts.
  /// Defaults to [AppThemeMode.system] until they pick one via the home
  /// screen's toggle.
  Future<AppThemeMode> getThemeMode() async {
    final db = await _database;
    final rows = await db.query('theme_settings', limit: 1);
    if (rows.isEmpty) return AppThemeMode.system;
    return AppThemeModeJson.fromJson(rows.first['mode'] as String?);
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    final db = await _database;
    await db.insert(
      'theme_settings',
      {'id': 0, 'mode': mode.toJson()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// User-selected app typography scale. Medium is deliberately the default:
  /// Nunito Sans reads slightly smaller than the former platform typeface.
  Future<AppTextSize> getTextSize() async {
    final db = await _database;
    final rows = await db.query('text_size_settings', limit: 1);
    if (rows.isEmpty) return AppTextSize.medium;
    return AppTextSizeJson.fromJson(rows.first['size'] as String?);
  }

  Future<void> setTextSize(AppTextSize size) async {
    final db = await _database;
    await db.insert(
      'text_size_settings',
      {'id': 0, 'size': size.toJson()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Anonymous, app-generated device identifier the Cloudflare Workers
  /// proxy uses for its per-device daily quota (see
  /// `_createDeviceIdentityTable`'s doc comment for why this isn't a real
  /// device attribute) — created on first call, then stable across calls.
  Future<String> getOrCreateDeviceId() async {
    final db = await _database;
    final rows = await db.query('device_identity', limit: 1);
    if (rows.isNotEmpty) return rows.first['device_id'] as String;

    final id = _generateDeviceId();
    await db.insert('device_identity', {'id': 0, 'device_id': id});
    return id;
  }

  static String _generateDeviceId() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// The user's last-picked practice set length, so the length picker
  /// pre-selects it next time instead of always defaulting to
  /// [PracticeLength.standard].
  Future<PracticeLength> getPracticeLength() async {
    final db = await _database;
    final rows = await db.query('practice_settings', limit: 1);
    if (rows.isEmpty) return PracticeLength.standard;
    return PracticeLengthInfo.fromQuestionCount(
        rows.first['question_count'] as int?);
  }

  Future<void> setPracticeLength(PracticeLength length) async {
    final db = await _database;
    await db.insert(
      'practice_settings',
      {'id': 0, 'question_count': length.questionCount},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Adds [questionsAnswered] to the running total for [topicId], called
  /// once per completed practice set (results screen) so the home screen's
  /// "X practiced" stat covers every session, not just the current one.
  Future<void> recordPracticeCompletion(
    String topicId,
    int questionsAnswered,
  ) async {
    if (questionsAnswered <= 0) return;
    final db = await _database;
    await db.rawInsert('''
      INSERT INTO topic_practice_stats (topic_id, questions_answered)
      VALUES (?, ?)
      ON CONFLICT(topic_id) DO UPDATE SET
        questions_answered = questions_answered + excluded.questions_answered
    ''', [topicId, questionsAnswered]);
  }

  static String _todayKey() =>
      clockForTesting().toIso8601String().split('T')[0];

  /// How many practice sessions this device has started today (local
  /// calendar day) — gates new generation once it reaches
  /// [dailySessionLimit] (`launchPracticeSet`, PRD v2 §10.1).
  Future<int> getSessionCountForToday() async {
    final db = await _database;
    final rows = await db.query(
      'daily_session_usage',
      where: 'day = ?',
      whereArgs: [_todayKey()],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['session_count'] as int;
  }

  /// Called once a practice set has actually been generated (i.e. the LLM
  /// call this cap exists to bound has happened), not merely requested —
  /// so an aborted or errored generation doesn't count against the limit.
  Future<void> recordSessionStarted() async {
    final db = await _database;
    await db.rawInsert('''
      INSERT INTO daily_session_usage (day, session_count)
      VALUES (?, 1)
      ON CONFLICT(day) DO UPDATE SET
        session_count = session_count + 1
    ''', [_todayKey()]);
  }

  /// How many free-tier "Practice this" sessions this device has started
  /// today (local calendar day) — gates new free-tier generation once it
  /// reaches [freeDailyPracticeLimit] (`launchPracticeSet`). Independent of
  /// [getSessionCountForToday]'s counter — see [freeDailyPracticeLimit]'s
  /// own doc comment for why these two never share a table.
  Future<int> getFreePracticeCountForToday() async {
    final db = await _database;
    final rows = await db.query(
      'free_practice_usage',
      where: 'day = ?',
      whereArgs: [_todayKey()],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return rows.first['session_count'] as int;
  }

  /// Called once a free-tier practice set has actually been generated —
  /// same "count success, not the attempt" posture as [recordSessionStarted],
  /// and for the same reason: a failed generation shouldn't burn the one
  /// free session a free user gets today.
  Future<void> recordFreePracticeStarted() async {
    final db = await _database;
    await db.rawInsert('''
      INSERT INTO free_practice_usage (day, session_count)
      VALUES (?, 1)
      ON CONFLICT(day) DO UPDATE SET
        session_count = session_count + 1
    ''', [_todayKey()]);
  }

  String get currentDayKey => _todayKey();

  /// Today's cached Daily Test set, if one has already been generated —
  /// null means none exists yet for the local calendar day, which is the
  /// caller's signal to generate one.
  Future<DailyTestSet?> getDailyTestSetForToday() async {
    final db = await _database;
    final rows = await db.query(
      'daily_test_sets',
      where: 'day = ?',
      whereArgs: [_todayKey()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _dailyTestSetFromRow(rows.first);
  }

  /// Cache the generated set for its original day. Unfinished sets retain
  /// main's replacement behavior; completed sets cannot be reset by a stale
  /// generation request, which would allow duplicate completion writes.
  Future<DailyTestSet> saveDailyTestSet(List<DailyTestQuestion> questions,
      {String? day}) async {
    final db = await _database;
    final setDay = day ?? _todayKey();
    return db.transaction((txn) async {
      final existing = await txn
          .query('daily_test_sets', where: 'day = ?', whereArgs: [setDay]);
      if (existing.isNotEmpty && existing.single['completed_at'] != null) {
        return _dailyTestSetFromRow(existing.single);
      }
      await txn.insert(
          'daily_test_sets',
          {
            'day': setDay,
            'questions_json':
                jsonEncode(questions.map((q) => q.toJson()).toList()),
            'completed_at': null,
            'answers_json': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await txn
          .query('daily_test_sets', where: 'day = ?', whereArgs: [setDay]);
      return _dailyTestSetFromRow(rows.single);
    });
  }

  /// Persists answers, mistakes and the daily climb entry in one transaction.
  /// Any failed write rolls back all three, so a retry cannot leave a partial
  /// completion. The original set [day] stays fixed across midnight/timezone
  /// changes; callers without it retain the existing current-day behavior.
  /// Missing cached sets are a harmless no-op. Already-completed sets are
  /// also ignored, preventing duplicate mistakes and retroactive climb credit.
  ///
  /// Returns whether *this* call is the one that just earned the Welcome
  /// badge (docs/prd-gamification.md §M6.5) — true only when this
  /// completion writes the very first row `climb_daily_entries` has ever
  /// had. That check, and the badge insert itself, happen inside this same
  /// transaction: a failed write rolls back the badge along with
  /// everything else, and the caller never needs a second read to find
  /// out, which would risk exactly the kind of stale-read race Batch 1's
  /// `SettingsScreen` fix avoided elsewhere in this codebase. Always false
  /// for a no-op call (missing/already-completed set) or any later
  /// completion once the ledger already has history.
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    final db = await _database;
    final setDay = day ?? _todayKey();
    final timestamp = completedAt ?? DateTime.now();
    return db.transaction((txn) async {
      final rows = await txn
          .query('daily_test_sets', where: 'day = ?', whereArgs: [setDay]);
      if (rows.isEmpty || rows.single['completed_at'] != null) return false;
      // Evaluate the persisted answer key, rather than trusting caller counts.
      final completion = DailyTestCompletion(
          set: _dailyTestSetFromRow(rows.single),
          answers: answers,
          completedAt: timestamp);
      await txn.update(
        'daily_test_sets',
        {
          'completed_at': timestamp.toIso8601String(),
          'answers_json': jsonEncode(answers),
        },
        where: 'day = ?',
        whereArgs: [setDay],
      );
      final batch = txn.batch();
      for (final entry in errorEntries) {
        batch.insert('error_entries', entry.toMap());
      }
      await batch.commit(noResult: true);

      final priorEntryCount = Sqflite.firstIntValue(
            await txn.rawQuery('SELECT COUNT(*) FROM climb_daily_entries'),
          ) ??
          0;

      await txn.insert('climb_daily_entries', {
        'day': setDay,
        'completed_at': timestamp.toIso8601String(),
        'step': completion.step,
        'correct_count': completion.correct,
        'wrong_count': completion.wrong,
        'skipped_count': completion.skipped,
        'rule_version': DailyTestCompletion.ruleVersion,
      });

      if (priorEntryCount > 0) return false;

      // The very first ledger row of all time, in this same transaction —
      // `priorEntryCount == 0`, computed atomically above, is the actual
      // source of truth for "just earned it" and is what this method
      // returns below. `ConflictAlgorithm.ignore` here is defensive only
      // (the only other writer is the v18 migration's one-time backfill,
      // which only ever fires when the ledger already has history, so
      // this table should always still be empty at this point too) —
      // deliberately NOT inspecting the insert's own returned rowid to
      // decide success: this row's `id` is hardcoded to 0, which is
      // indistinguishable from sqflite's "insert was ignored" sentinel.
      await txn.insert(
        'welcome_badge',
        {
          'id': 0,
          'earned_at': timestamp.toIso8601String(),
          'rule_version': WelcomeBadgeRules.ruleVersion,
          'backfilled': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      return true;
    });
  }

  /// Month boundaries use the same original local day keys as Daily Test.
  /// No reset/delete at rollover: prior months remain durable history.
  Future<({int steps, int correct, int wrong, int skipped})> getClimbProgress(
    int year,
    int month,
  ) async {
    if (month < 1 || month > 12 || year < 1 || year > 9999) {
      throw ArgumentError('Invalid calendar month');
    }
    final start =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
    final endDate = DateTime(year, month + 1);
    final end = endDate.toIso8601String().split('T').first;
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(step), 0) AS steps,
        COALESCE(SUM(correct_count), 0) AS correct,
        COALESCE(SUM(wrong_count), 0) AS wrong,
        COALESCE(SUM(skipped_count), 0) AS skipped
      FROM climb_daily_entries WHERE day >= ? AND day < ?
    ''', [start, end]);
    final row = rows.single;
    return (
      steps: row['steps'] as int,
      correct: row['correct'] as int,
      wrong: row['wrong'] as int,
      skipped: row['skipped'] as int
    );
  }

  Future<MonthlyMedalProgress> getMonthlyMedalProgress(
    int year,
    int month,
  ) async {
    final db = await _database;
    return _readMonthlyMedalProgress(db, year, month);
  }

  Future<MonthlyMedalProgress> getCurrentMonthlyMedalProgress() {
    final now = clockForTesting();
    return getMonthlyMedalProgress(now.year, now.month);
  }

  /// Freezes every past month that has at least one Daily Test result. A row
  /// is written even below Bronze, so later rule changes cannot retroactively
  /// award it. INSERT OR IGNORE makes repeated app opens harmless.
  Future<void> finalizePastMedalMonths() async {
    final now = clockForTesting();
    final currentMonth = _monthKey(now.year, now.month);
    final db = await _database;
    await db.transaction((txn) async {
      final months = await txn.rawQuery('''
        SELECT DISTINCT substr(day, 1, 7) AS month
        FROM climb_daily_entries
        WHERE day < ?
          AND substr(day, 1, 7) NOT IN (
            SELECT month FROM monthly_medal_results
          )
        ORDER BY month
      ''', ['$currentMonth-01']);
      for (final row in months) {
        final key = row['month'] as String;
        final parts = key.split('-');
        final year = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final progress = await _readMonthlyMedalProgress(txn, year, month);
        final tier = MonthlyMedalRules.tierFor(
          year: year,
          month: month,
          score: progress.score,
        );
        await txn.insert(
          'monthly_medal_results',
          {
            'month': key,
            'tier': tier?.name,
            'score': progress.score,
            'max_score': progress.maxScore,
            'active_days': progress.activeDays,
            'correct_count': progress.correct,
            'wrong_count': progress.wrong,
            'skipped_count': progress.skipped,
            'rule_version': MonthlyMedalRules.ruleVersion,
            'finalized_at': now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<List<MonthlyMedalResult>> getMonthlyMedalResults() async {
    final db = await _database;
    final rows = await db.query(
      'monthly_medal_results',
      orderBy: 'month DESC',
    );
    return rows.map(_monthlyMedalResultFromRow).toList(growable: false);
  }

  /// Null until earned — either live, inside [completeDailyTest]'s own
  /// transaction, or (for a device that already had ledger history)
  /// retroactively by the v18 migration. There is no lazy backfill call
  /// anywhere else; a caller just reads whatever is already on record.
  Future<WelcomeBadge?> getWelcomeBadge() async {
    final db = await _database;
    final rows = await db.query('welcome_badge', limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.single;
    return WelcomeBadge(
      earnedAt: DateTime.parse(row['earned_at'] as String),
      ruleVersion: row['rule_version'] as int,
      backfilled: (row['backfilled'] as int) == 1,
    );
  }

  Future<MonthlyMedalProgress> _readMonthlyMedalProgress(
    DatabaseExecutor db,
    int year,
    int month,
  ) async {
    if (month < 1 || month > 12 || year < 1 || year > 9999) {
      throw ArgumentError('Invalid calendar month');
    }
    final key = _monthKey(year, month);
    final endDate = DateTime(year, month + 1);
    final end = '${_monthKey(endDate.year, endDate.month)}-01';
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(step), 0) AS active_days,
        COALESCE(SUM(correct_count), 0) AS correct,
        COALESCE(SUM(wrong_count), 0) AS wrong,
        COALESCE(SUM(skipped_count), 0) AS skipped
      FROM climb_daily_entries WHERE day >= ? AND day < ?
    ''', ['$key-01', end]);
    final row = rows.single;
    final correct = row['correct'] as int;
    final wrong = row['wrong'] as int;
    return MonthlyMedalProgress(
      year: year,
      month: month,
      score: MonthlyMedalRules.score(correct: correct, wrong: wrong),
      maxScore: MonthlyMedalRules.maxScore(year, month),
      activeDays: row['active_days'] as int,
      correct: correct,
      wrong: wrong,
      skipped: row['skipped'] as int,
    );
  }

  MonthlyMedalResult _monthlyMedalResultFromRow(Map<String, Object?> row) {
    final parts = (row['month'] as String).split('-');
    final tierName = row['tier'] as String?;
    final tier = tierName == null
        ? null
        : MedalTier.values.firstWhere((value) => value.name == tierName);
    return MonthlyMedalResult(
      year: int.parse(parts[0]),
      month: int.parse(parts[1]),
      score: row['score'] as int,
      maxScore: row['max_score'] as int,
      activeDays: row['active_days'] as int,
      correct: row['correct_count'] as int,
      wrong: row['wrong_count'] as int,
      skipped: row['skipped_count'] as int,
      tier: tier,
      ruleVersion: row['rule_version'] as int,
      finalizedAt: DateTime.parse(row['finalized_at'] as String),
    );
  }

  static String _monthKey(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  DailyTestSet _dailyTestSetFromRow(Map<String, Object?> row) {
    final questions = (jsonDecode(row['questions_json'] as String) as List)
        .map((e) => DailyTestQuestion.fromJson(e as Map<String, dynamic>))
        .toList();
    final completedAt = row['completed_at'] as String?;
    final answersJson = row['answers_json'] as String?;
    return DailyTestSet(
      day: row['day'] as String,
      questions: questions,
      completedAt: completedAt == null ? null : DateTime.parse(completedAt),
      answers: answersJson == null
          ? null
          : Map<String, String>.from(jsonDecode(answersJson) as Map),
    );
  }

  /// The developer's persisted debug entitlement override (see
  /// `SubscriptionService.debugAccessOverride`) — `true`/`false` forces
  /// [SubscriptionService.hasFullAccess], `null` means no override is set,
  /// use the real status. Reading this in a release build is harmless
  /// (plain inert data); the actual release-safety guarantee lives in
  /// SubscriptionService's own `kDebugMode` check, not here.
  Future<bool?> getDebugAccessOverride() async {
    final db = await _database;
    final rows = await db.query('debug_settings', limit: 1);
    if (rows.isEmpty) return null;
    final value = rows.first['access_override'] as String?;
    if (value == null) return null;
    return value == 'full';
  }

  /// Persists the developer's debug entitlement override so it survives an
  /// app restart, same single-row-table convention as [setThemeMode].
  /// `null` clears it (back to "use the real status").
  Future<void> setDebugAccessOverride(bool? hasFullAccess) async {
    final db = await _database;
    await db.insert(
      'debug_settings',
      {
        'id': 0,
        'access_override':
            hasFullAccess == null ? null : (hasFullAccess ? 'full' : 'free'),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Per-topic stats for the home screen's topic cards: total questions
  /// practiced (from [recordPracticeCompletion]) and count of distinct error
  /// types still logged (from `error_entries`, the same data [getWeakSpots]
  /// draws on). Topics with no rows in either source are simply absent from
  /// the map — callers should default to [TopicStats.empty].
  Future<Map<String, TopicStats>> getTopicStats() async {
    final db = await _database;
    final practiceRows = await db.query('topic_practice_stats');
    final weakSpotRows = await db.rawQuery('''
      SELECT topic_id, COUNT(DISTINCT error_type) AS weak_spot_count
      FROM error_entries
      GROUP BY topic_id
    ''');
    final practiced = <String, int>{
      for (final row in practiceRows)
        row['topic_id'] as String: row['questions_answered'] as int,
    };
    final weakSpots = <String, int>{
      for (final row in weakSpotRows)
        row['topic_id'] as String: row['weak_spot_count'] as int,
    };
    final topicIds = {...practiced.keys, ...weakSpots.keys};
    return {
      for (final id in topicIds)
        id: TopicStats(
          practiced: practiced[id] ?? 0,
          weakSpotCount: weakSpots[id] ?? 0,
        ),
    };
  }

  /// Null means no profile has been saved yet — the app's signal to show
  /// the first-launch onboarding flow instead of Home.
  Future<UserProfile?> getUserProfile() async {
    final db = await _database;
    final rows = await db.query('user_profile', limit: 1);
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  /// Used both to complete onboarding and to save edits from Settings.
  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await _database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Settings' "reset data" (PRD v2 §4) — clears practice history (logged
  /// mistakes and per-topic counts) so the app reads like a fresh install
  /// without actually losing the guest identity: name, learning goal, and
  /// theme preference are deliberately left alone, since those are settings
  /// the user picked, not progress to start over.
  Future<void> resetProgressData() async {
    final db = await _database;
    final batch = db.batch();
    batch.delete('error_entries');
    batch.delete('topic_practice_stats');
    await batch.commit(noResult: true);
  }

  /// Debug-only: deletes the saved profile so the app treats this like a
  /// fresh install and shows the Welcome/Onboarding flow again on next
  /// build — a profile row existing is the *only* thing that gates that
  /// (see [getUserProfile]'s doc comment, no separate flag). Deliberately
  /// the opposite scope of [resetProgressData]: that one keeps identity/
  /// settings and clears history; this one clears only the identity gate,
  /// nothing else — practice history, theme, and daily caches are
  /// untouched.
  Future<void> resetOnboarding() async {
    final db = await _database;
    await db.delete('user_profile');
  }
}
