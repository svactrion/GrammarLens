import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/error_entry.dart';

/// Local SQLite-backed error profile (PRD §5: "on-device storage; no
/// accounts"). Tracks topic × error type × frequency, driving the Review tab.
class StorageService {
  static const _dbName = 'grammar_lens.db';
  static const _dbVersion = 1;

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
      onCreate: (db, version) => db.execute('''
        CREATE TABLE error_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          topic_id TEXT NOT NULL,
          error_type TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      '''),
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

  Future<List<WeakSpot>> getWeakSpots({int limit = 10}) async {
    final db = await _database;
    final rows = await db.rawQuery('''
      SELECT topic_id, error_type, COUNT(*) as frequency
      FROM error_entries
      GROUP BY topic_id, error_type
      ORDER BY frequency DESC
      LIMIT ?
    ''', [limit]);
    return rows
        .map((row) => WeakSpot(
              topicId: row['topic_id'] as String,
              errorType: row['error_type'] as String,
              frequency: row['frequency'] as int,
            ))
        .toList();
  }
}
