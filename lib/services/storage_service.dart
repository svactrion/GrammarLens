import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_theme_mode.dart';
import '../models/error_entry.dart';
import '../models/practice_length.dart';
import '../models/review_sort_order.dart';

/// Local SQLite-backed error profile (PRD §5: "on-device storage; no
/// accounts"). Tracks topic × error type × frequency, driving the Review tab.
class StorageService {
  static const _dbName = 'grammar_lens.db';
  static const _dbVersion = 4;

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
      },
      // Still pre-launch prototype with no real user data to preserve, so a
      // schema change just drops and recreates rather than carrying a real
      // migration — revisit once there's an actual install base to protect.
      onUpgrade: (db, oldVersion, newVersion) async {
        await db.execute('DROP TABLE IF EXISTS error_entries');
        await db.execute('DROP TABLE IF EXISTS review_settings');
        await db.execute('DROP TABLE IF EXISTS theme_settings');
        await db.execute('DROP TABLE IF EXISTS practice_settings');
        await db.execute(_createTable);
        await db.execute(_createReviewSettingsTable);
        await db.execute(_createThemeSettingsTable);
        await db.execute(_createPracticeSettingsTable);
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
}
