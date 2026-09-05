import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/services/storage_service.dart';

/// The Cloudflare Workers proxy's per-device quota (docs/build-log.md)
/// needs this id to actually be stable across calls — real persistence to
/// mean anything, see storage_service_daily_cap_test.dart's note on why
/// this uses the ffi `databaseFactory` instead of plain `flutter test`.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;

  const dbName = 'test_device_id.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
  });

  test('creates a non-empty id on first call', () async {
    final id = await storageService.getOrCreateDeviceId();
    expect(id, isNotEmpty);
  });

  test('returns the same id on repeated calls, not a fresh one each time',
      () async {
    final first = await storageService.getOrCreateDeviceId();
    final second = await storageService.getOrCreateDeviceId();
    expect(second, first);
  });

  test('survives a fresh StorageService instance against the same db — '
      'real persistence, not an in-memory cache', () async {
    final id = await storageService.getOrCreateDeviceId();

    final reopened = StorageService(dbName: dbName);
    expect(await reopened.getOrCreateDeviceId(), id);
  });

  test('two different devices (databases) get two different ids', () async {
    const otherDbName = 'test_device_id_other.db';
    final otherPath = join(await getDatabasesPath(), otherDbName);
    await databaseFactory.deleteDatabase(otherPath);
    final other = StorageService(dbName: otherDbName);

    final idA = await storageService.getOrCreateDeviceId();
    final idB = await other.getOrCreateDeviceId();
    expect(idA, isNot(idB));
  });
}
