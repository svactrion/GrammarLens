import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/services/storage_service.dart';

/// PRD v2 §10.1's daily session cap needs real persistence to mean anything
/// — the ffi `databaseFactory` runs genuine SQLite on the host VM (unlike
/// plain `flutter test`, which has no platform channel for the default
/// sqflite factory; see widget_test.dart's note on that), so this exercises
/// StorageService's actual read/write path instead of just its Dart-side
/// logic.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;

  setUp(() async {
    final path = join(await getDatabasesPath(), 'grammar_lens.db');
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService();
  });

  test('a fresh day starts at zero sessions', () async {
    expect(await storageService.getSessionCountForToday(), 0);
  });

  test('recordSessionStarted increments the count for today', () async {
    await storageService.recordSessionStarted();
    await storageService.recordSessionStarted();
    await storageService.recordSessionStarted();
    expect(await storageService.getSessionCountForToday(), 3);
  });

  test('the count reaches the configured daily limit', () async {
    for (var i = 0; i < StorageService.dailySessionLimit; i++) {
      await storageService.recordSessionStarted();
    }
    final count = await storageService.getSessionCountForToday();
    expect(count, StorageService.dailySessionLimit);
    expect(count >= StorageService.dailySessionLimit, isTrue);
  });
}
