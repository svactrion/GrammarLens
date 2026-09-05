import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_theme_mode.dart';
import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import '../models/practice_length.dart';
import '../models/review_sort_order.dart';
import '../models/topic_stats.dart';
import '../models/user_profile.dart';

/// Local SQLite-backed error profile (PRD §5: "on-device storage; no
/// accounts"). Tracks topic × error type × frequency, driving the Review tab.
class StorageService {
  static const _defaultDbName = 'grammar_lens.db';
  static const _dbVersion = 12;

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

  // `source` (added schema v12) distinguishes a Topic Practice mistake
  // from a Daily Test one — both write here now (2026-09-05 decision:
  // free tier diagnoses via Daily Test, paid tier treats via Topic
  // Practice — see docs/build-log.md). Defaults to the value every row
  // predating this column really was, since Topic Practice was the only
  // writer until now.
  static const _createTable = '''
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
  ''';

  static const _createReviewSettingsTable = '''
    CREATE TABLE review_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      sort_order TEXT NOT NULL
    )
  ''';

  static const _createThemeSettingsTable = '''
    CREATE TABLE theme_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      mode TEXT NOT NULL
    )
  ''';

  static const _createPracticeSettingsTable = '''
    CREATE TABLE practice_settings (
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
    CREATE TABLE topic_practice_stats (
      topic_id TEXT PRIMARY KEY,
      questions_answered INTEGER NOT NULL DEFAULT 0
    )
  ''';

  // Guest-first identity (PRD v2 §5) — a row existing here is what "has
  // completed onboarding" means, so there's no separate boolean flag.
  static const _createUserProfileTable = '''
    CREATE TABLE user_profile (
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
    CREATE TABLE daily_session_usage (
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
    CREATE TABLE daily_test_sets (
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
    CREATE TABLE debug_settings (
      id INTEGER PRIMARY KEY CHECK (id = 0),
      access_override TEXT
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
        await db.execute(_createPracticeSettingsTable);
        await db.execute(_createTopicPracticeStatsTable);
        await db.execute(_createUserProfileTable);
        await db.execute(_createDailySessionUsageTable);
        await db.execute(_createDailyTestSetsTable);
        await db.execute(_createDebugSettingsTable);
      },
      // Still pre-launch prototype with no real user data to preserve, so a
      // schema change just drops and recreates rather than carrying a real
      // migration — revisit once there's an actual install base to protect.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS error_entries');
        await db.execute('DROP TABLE IF EXISTS review_settings');
        await db.execute('DROP TABLE IF EXISTS theme_settings');
        await db.execute('DROP TABLE IF EXISTS practice_settings');
        await db.execute('DROP TABLE IF EXISTS topic_practice_stats');
        await db.execute('DROP TABLE IF EXISTS user_profile');
        await db.execute('DROP TABLE IF EXISTS daily_session_usage');
        await db.execute('DROP TABLE IF EXISTS daily_test_sets');
        await db.execute('DROP TABLE IF EXISTS debug_settings');
        await db.execute(_createTable);
        await db.execute(_createReviewSettingsTable);
        await db.execute(_createThemeSettingsTable);
        await db.execute(_createPracticeSettingsTable);
        await db.execute(_createTopicPracticeStatsTable);
        await db.execute(_createUserProfileTable);
        await db.execute(_createDailySessionUsageTable);
        await db.execute(_createDailyTestSetsTable);
        await db.execute(_createDebugSettingsTable);
      },
    );
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

  static String _todayKey() => DateTime.now().toIso8601String().split('T')[0];

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

  /// Caches [questions] as today's Daily Test set, replacing any existing
  /// row for today (there should never be one — this is only called after
  /// [getDailyTestSetForToday] came back null — but `replace` keeps this
  /// safe against a same-day double-generation race rather than throwing).
  /// Freshly generated, so never completed yet.
  Future<DailyTestSet> saveDailyTestSet(
    List<DailyTestQuestion> questions,
  ) async {
    final db = await _database;
    final day = _todayKey();
    await db.insert(
      'daily_test_sets',
      {
        'day': day,
        'questions_json':
            jsonEncode(questions.map((q) => q.toJson()).toList()),
        'completed_at': null,
        'answers_json': null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return DailyTestSet(day: day, questions: questions);
  }

  /// Marks today's Daily Test set completed and persists [answers] — the
  /// only record of what the user actually answered, since nothing else
  /// stores it. Needed so a score can be shown (and the result viewed
  /// again) later without a live in-memory answers map, e.g. from Home's
  /// "today" summary (PRD v2 §13.5). A no-op if there's no row for today
  /// (shouldn't happen — completing implies a set was already fetched/
  /// generated — but this is called from UI code, so it degrades quietly
  /// rather than throwing on an unexpected order of operations).
  Future<void> markDailyTestCompleted(Map<String, String> answers) async {
    final db = await _database;
    await db.update(
      'daily_test_sets',
      {
        'completed_at': DateTime.now().toIso8601String(),
        'answers_json': jsonEncode(answers),
      },
      where: 'day = ?',
      whereArgs: [_todayKey()],
    );
  }

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
