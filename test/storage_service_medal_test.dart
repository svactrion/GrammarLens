import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/services/storage_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_monthly_medals.db';
  late StorageService storage;
  late Database db;

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    StorageService.clockForTesting = () => DateTime(2026, 10, 5, 12);
    storage = StorageService(dbName: dbName);
    await storage.getCurrentMonthlyMedalProgress();
    db = await databaseFactory.openDatabase(path);
  });

  tearDown(() async {
    await db.close();
    StorageService.clockForTesting = DateTime.now;
  });

  test('finalizes past months once, including a below-Bronze result', () async {
    for (var day = 1; day <= 23; day++) {
      await _insertEntry(db, '2026-09-${day.toString().padLeft(2, '0')}',
          correct: 5);
    }
    await _insertEntry(db, '2026-08-12', wrong: 1);
    await _insertEntry(db, '2026-10-01', correct: 5);

    await storage.finalizePastMedalMonths();
    final results = await storage.getMonthlyMedalResults();

    expect(results, hasLength(2));
    expect(results[0].month, 9);
    expect(results[0].score, 230);
    expect(results[0].maxScore, 300);
    expect(results[0].activeDays, 23);
    expect(results[0].tier, MedalTier.gold);
    expect(results[0].ruleVersion, 1);
    expect(results[1].month, 8);
    expect(results[1].tier, isNull);

    final current = await storage.getCurrentMonthlyMedalProgress();
    expect(current.month, 10);
    expect(current.score, 10);
    expect(current.maxScore, 310);

    await _insertEntry(db, '2026-09-24', correct: 5);
    await storage.finalizePastMedalMonths();
    final frozen = await storage.getMonthlyMedalResults();
    expect(frozen.first.score, 230,
        reason: 'finalized history must never be silently recalculated');
  });

  test('does not create empty months or finalize the current month', () async {
    await _insertEntry(db, '2026-10-01', correct: 5);
    await storage.finalizePastMedalMonths();
    expect(await storage.getMonthlyMedalResults(), isEmpty);
  });
}

Future<void> _insertEntry(
  Database db,
  String day, {
  int correct = 0,
  int wrong = 0,
  int skipped = 0,
}) =>
    db.insert('climb_daily_entries', {
      'day': day,
      'completed_at': '${day}T12:00:00.000',
      'step': correct + wrong > 0 ? 1 : 0,
      'correct_count': correct,
      'wrong_count': wrong,
      'skipped_count': skipped,
      'rule_version': 1,
    });
