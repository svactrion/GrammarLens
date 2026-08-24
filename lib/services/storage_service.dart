import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_theme_mode.dart';
import '../models/error_entry.dart';
import '../models/practice_length.dart';
import '../models/review_sort_order.dart';
import '../models/topic_stats.dart';
import '../models/user_profile.dart';

/// Local SQLite-backed error profile (PRD §5: "on-device storage; no
/// accounts"). Tracks topic × error type × frequency, driving the Review tab.
class StorageService {
  static const _dbName = 'grammar_lens.db';
  static const _dbVersion = 6;

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
      rule TEXT
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
      occupation TEXT
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
        await db.execute(_createTable);
        await db.execute(_createReviewSettingsTable);
        await db.execute(_createThemeSettingsTable);
        await db.execute(_createPracticeSettingsTable);
        await db.execute(_createTopicPracticeStatsTable);
        await db.execute(_createUserProfileTable);
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
}
