import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/services/storage_service.dart';

/// The debug entitlement override (see SubscriptionService) needs real
/// persistence to mean anything — see storage_service_daily_cap_test.dart's
/// note on why this uses the ffi `databaseFactory` instead of plain
/// `flutter test`.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;

  // A file distinct from other ffi-backed test files' — `flutter test` runs
  // files concurrently, and they'd otherwise race on the same real db path.
  const dbName = 'test_debug_override.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
  });

  test('no override is set by default', () async {
    expect(await storageService.getDebugAccessOverride(), isNull);
  });

  test('setDebugAccessOverride(true) round-trips as true', () async {
    await storageService.setDebugAccessOverride(true);
    expect(await storageService.getDebugAccessOverride(), isTrue);
  });

  test('setDebugAccessOverride(false) round-trips as false', () async {
    await storageService.setDebugAccessOverride(false);
    expect(await storageService.getDebugAccessOverride(), isFalse);
  });

  test('setDebugAccessOverride(null) clears a previously-set override',
      () async {
    await storageService.setDebugAccessOverride(true);
    expect(await storageService.getDebugAccessOverride(), isTrue);

    await storageService.setDebugAccessOverride(null);
    expect(await storageService.getDebugAccessOverride(), isNull);
  });

  test('setting it again replaces rather than duplicating the row',
      () async {
    await storageService.setDebugAccessOverride(true);
    await storageService.setDebugAccessOverride(false);
    expect(await storageService.getDebugAccessOverride(), isFalse);
  });
}
