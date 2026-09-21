import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// One-time flags need real persistence to mean anything: what matters is that
/// the answer survives a restart and that overlapping callers cannot both win.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storage;

  // A file distinct from other ffi-backed test files' — `flutter test` runs
  // files concurrently, and they'd otherwise race on the same real db path.
  const dbName = 'test_one_time_flag.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storage = StorageService(dbName: dbName);
  });

  tearDown(() => StorageService.clockForTesting = DateTime.now);

  test('the first claim wins, every later one loses', () async {
    expect(await storage.claimOneTimeFlag('a'), isTrue);
    expect(await storage.claimOneTimeFlag('a'), isFalse);
    expect(await storage.claimOneTimeFlag('a'), isFalse);
  });

  test('flags are independent of each other', () async {
    expect(await storage.claimOneTimeFlag('a'), isTrue);
    expect(await storage.claimOneTimeFlag('b'), isTrue);
    expect(await storage.claimOneTimeFlag('a'), isFalse);
    expect(await storage.claimOneTimeFlag('b'), isFalse);
  });

  test('a claim survives a restart (a new service on the same database)',
      () async {
    expect(await storage.claimOneTimeFlag('a'), isTrue);

    final reopened = StorageService(dbName: dbName);

    expect(await reopened.claimOneTimeFlag('a'), isFalse);
  });

  test('overlapping claims produce exactly one winner', () async {
    final results = await Future.wait([
      for (var i = 0; i < 8; i++) storage.claimOneTimeFlag('a'),
    ]);

    expect(results.where((r) => r), hasLength(1));
  });

  test('a losing claim leaves the winning row untouched (same time, one row)',
      () async {
    StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
    await storage.claimOneTimeFlag('a');
    StorageService.clockForTesting = () => DateTime(2026, 9, 23, 10);
    await storage.claimOneTimeFlag('a');

    final db = await databaseFactory.openDatabase(
        join(await getDatabasesPath(), dbName));
    final rows = await db.query('one_time_flags');
    await db.close();
    expect(rows, hasLength(1));
    expect(rows.single['key'], 'a');
    expect(rows.single['set_at'], DateTime(2026, 9, 22, 10).toIso8601String());
  });

  group('resetOnboarding (debug only)', () {
    test('brings the first-day paywall back, and only that flag', () async {
      await storage.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.work));
      expect(
          await storage.claimOneTimeFlag(StorageService.day0PaywallFlag), isTrue);
      expect(await storage.claimOneTimeFlag('other'), isTrue);

      await storage.resetOnboarding();

      expect(await storage.getUserProfile(), isNull);
      expect(
          await storage.claimOneTimeFlag(StorageService.day0PaywallFlag), isTrue);
      expect(await storage.claimOneTimeFlag('other'), isFalse);
    });

    test('on a fresh install with no flag it is still a harmless no-op',
        () async {
      await storage.resetOnboarding();
      expect(
          await storage.claimOneTimeFlag(StorageService.day0PaywallFlag), isTrue);
    });
  });

  test('the first-day paywall flag has its fixed key', () {
    expect(StorageService.day0PaywallFlag, 'day0_paywall');
  });
}
