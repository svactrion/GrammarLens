import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/services/storage_service.dart';

/// The free tier's own daily counter (`StorageService.freeDailyPracticeLimit`)
/// — same real-persistence rationale as storage_service_daily_cap_test.dart's
/// own header comment: this needs genuine SQLite to mean anything, so it
/// runs against the ffi factory rather than a fake.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;

  const dbName = 'test_free_practice.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
  });

  tearDown(() {
    // Never leave a test-set clock affecting a later test in this file.
    StorageService.clockForTesting = DateTime.now;
  });

  test('a fresh day starts at zero free-practice sessions', () async {
    expect(await storageService.getFreePracticeCountForToday(), 0);
  });

  test('recordFreePracticeStarted increments the count for today', () async {
    await storageService.recordFreePracticeStarted();
    expect(await storageService.getFreePracticeCountForToday(), 1);
  });

  test('the count reaches the configured free-tier limit', () async {
    for (var i = 0; i < StorageService.freeDailyPracticeLimit; i++) {
      await storageService.recordFreePracticeStarted();
    }
    final count = await storageService.getFreePracticeCountForToday();
    expect(count, StorageService.freeDailyPracticeLimit);
    expect(count >= StorageService.freeDailyPracticeLimit, isTrue);
  });

  test(
      'independent of the Topic Practice session cap — recording one '
      'never moves the other', () async {
    await storageService.recordFreePracticeStarted();
    expect(await storageService.getSessionCountForToday(), 0);

    await storageService.recordSessionStarted();
    expect(await storageService.getFreePracticeCountForToday(), 1);
  });

  test(
      'the quota resets on a new local calendar day, with no manual reset '
      '— proven via the injectable clock seam, not by waiting for one',
      () async {
    StorageService.clockForTesting = () => DateTime(2026, 1, 1);
    await storageService.recordFreePracticeStarted();
    expect(await storageService.getFreePracticeCountForToday(), 1);

    // Still day one — the count doesn't move on its own.
    expect(await storageService.getFreePracticeCountForToday(), 1);

    StorageService.clockForTesting = () => DateTime(2026, 1, 2);
    expect(await storageService.getFreePracticeCountForToday(), 0);

    // The new day's own usage is tracked independently of yesterday's row.
    await storageService.recordFreePracticeStarted();
    expect(await storageService.getFreePracticeCountForToday(), 1);

    StorageService.clockForTesting = () => DateTime(2026, 1, 1);
    expect(await storageService.getFreePracticeCountForToday(), 1);
  });
}
