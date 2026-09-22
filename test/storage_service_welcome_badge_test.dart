import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/welcome_badge_rules.dart';

/// Covers the v18 migration's one-time retroactive Welcome badge award
/// (docs/prd-gamification.md §M6.5) — separate from
/// storage_service_migration_test.dart's general schema-survival coverage,
/// since this feature has its own specific "only when a `step = 1` ledger
/// row already exists, exactly once" contract worth testing on its own.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const climbEntriesTableSql = '''
    CREATE TABLE climb_daily_entries (
      day TEXT PRIMARY KEY NOT NULL,
      completed_at TEXT NOT NULL,
      step INTEGER NOT NULL CHECK (step IN (0, 1)),
      correct_count INTEGER NOT NULL CHECK (correct_count >= 0),
      wrong_count INTEGER NOT NULL CHECK (wrong_count >= 0),
      skipped_count INTEGER NOT NULL CHECK (skipped_count >= 0),
      rule_version INTEGER NOT NULL
    )
  ''';

  Future<void> seedLedgerRow(
    Database db,
    String day, {
    int step = 1,
  }) =>
      db.insert('climb_daily_entries', {
        'day': day,
        'completed_at': '${day}T09:00:00.000',
        'step': step,
        'correct_count': 1,
        'wrong_count': 0,
        'skipped_count': 4,
        'rule_version': 1,
      });

  late String path;

  setUp(() async {
    path = join(await getDatabasesPath(), 'test_welcome_badge.db');
    await databaseFactory.deleteDatabase(path);
  });

  test('a fresh install has no Welcome badge', () async {
    final storage = StorageService(dbName: path);
    expect(await storage.getWelcomeBadge(), isNull);
  });

  test(
      'upgrading a device with existing step = 1 ledger history backfills '
      'the badge, dated to the earliest step = 1 row, marked backfilled',
      () async {
    final oldDb = await databaseFactory.openDatabase(path);
    await oldDb.execute(climbEntriesTableSql);
    // Deliberately inserted out of chronological order, and including an
    // *earlier* zero-step (all-skipped) day — the badge must key off the
    // earliest `step = 1` *day* (08-20), ignoring both insertion order and
    // the earlier all-skipped row (08-15).
    await seedLedgerRow(oldDb, '2026-08-20');
    await seedLedgerRow(oldDb, '2026-08-15', step: 0);
    await seedLedgerRow(oldDb, '2026-09-01');
    await oldDb.setVersion(17);
    await oldDb.close();

    final storage = StorageService(dbName: path);
    final badge = await storage.getWelcomeBadge();

    expect(badge, isNotNull);
    expect(badge!.earnedAt, DateTime.parse('2026-08-20'));
    expect(badge.ruleVersion, WelcomeBadgeRules.ruleVersion);
    expect(badge.backfilled, isTrue);
  });

  test(
      'a ledger holding only all-skipped (step = 0) rows is ignored — no '
      'backfill', () async {
    final oldDb = await databaseFactory.openDatabase(path);
    await oldDb.execute(climbEntriesTableSql);
    await seedLedgerRow(oldDb, '2026-08-15', step: 0);
    await seedLedgerRow(oldDb, '2026-08-16', step: 0);
    await oldDb.setVersion(17);
    await oldDb.close();

    final storage = StorageService(dbName: path);
    expect(await storage.getWelcomeBadge(), isNull);

    // The rows themselves are untouched — only the badge is withheld.
    final db = await databaseFactory.openDatabase(path);
    expect(await db.query('climb_daily_entries'), hasLength(2));
    await db.close();
  });

  test(
      'upgrading a device with an empty ledger (a typical pre-Monthly-Climb '
      'user) does not backfill anything', () async {
    final oldDb = await databaseFactory.openDatabase(path);
    await oldDb.execute(climbEntriesTableSql);
    await oldDb.setVersion(17);
    await oldDb.close();

    final storage = StorageService(dbName: path);
    expect(await storage.getWelcomeBadge(), isNull);

    // The table itself must still exist and be usable — only the
    // conditional backfill row is skipped, not the table creation.
    expect(await storage.getClimbProgress(2026, 9), isNotNull);
  });

  test(
      'a v1 device (predating the ledger entirely) upgrades cleanly with no '
      'Welcome badge', () async {
    final oldDb = await databaseFactory.openDatabase(path);
    await oldDb.execute(
        'CREATE TABLE error_entries (id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'topic_id TEXT NOT NULL, error_type TEXT NOT NULL, timestamp TEXT NOT NULL)');
    await oldDb.setVersion(1);
    await oldDb.close();

    final storage = StorageService(dbName: path);
    expect(await storage.getWelcomeBadge(), isNull);
  });

  test(
      'the migration step is idempotent — re-running onUpgrade over an '
      'already-backfilled device does not duplicate or overwrite the badge',
      () async {
    final oldDb = await databaseFactory.openDatabase(path);
    await oldDb.execute(climbEntriesTableSql);
    await seedLedgerRow(oldDb, '2026-08-15');
    await oldDb.setVersion(17);
    await oldDb.close();

    var storage = StorageService(dbName: path);
    final firstBadge = await storage.getWelcomeBadge();
    expect(firstBadge, isNotNull);

    // Reproduce sqflite's own silent-downgrade landmine, the same way
    // storage_service_migration_test.dart's own idempotency test does:
    // force the stored version back down without touching the schema, so
    // the next open re-evaluates onUpgrade(17, current) from scratch.
    final rawDb = await databaseFactory.openDatabase(path);
    await rawDb.setVersion(17);
    await rawDb.close();

    storage = StorageService(dbName: path);
    final secondBadge = await storage.getWelcomeBadge();

    expect(secondBadge, isNotNull);
    expect(secondBadge!.earnedAt, firstBadge!.earnedAt);
    expect(secondBadge.backfilled, isTrue);

    final db = await databaseFactory.openDatabase(path);
    expect(await db.query('welcome_badge'), hasLength(1));
    await db.close();
  });
}
