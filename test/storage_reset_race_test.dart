import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// The debug reset (`resetAllLocalData`) while the app still reads: the
/// diagnosis of the stalled "reset brings the app back to Welcome" test
/// (1.4.0 B5). Reads that arrive during the reset must neither fail on a
/// closed connection nor reopen the file the reset is about to delete.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  const dbName = 'test_storage_reset_race.db';
  setUp(() async =>
      databaseFactory.deleteDatabase(join(await getDatabasesPath(), dbName)));

  test('reads during the reset all complete, and afterwards find no profile',
      () async {
    for (var round = 0; round < 20; round++) {
      final storage = StorageService(dbName: dbName);
      await storage.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general));
      final reset = storage.resetAllLocalData();
      final reads = [for (var i = 0; i < 10; i++) storage.getUserProfile()];
      await reset;
      final later = [for (var i = 0; i < 10; i++) storage.getUserProfile()];
      final results = await Future.wait([...reads, ...later]);
      expect(results.skip(reads.length), everyElement(isNull),
          reason: 'round $round: a read after the reset found a profile');
      expect(await storage.getUserProfile(), isNull, reason: 'round $round');
      await storage.close();
    }
  });

  // An open still in flight when close() or the reset ran stayed open after
  // them, holding sqflite's per-path lock: the next open or delete of the
  // file from another zone waited on it (the debug-panel reset test's stall
  // under load, 2026-11-03).
  test('close() while an open is in flight leaves nothing open', () async {
    for (var round = 0; round < 20; round++) {
      final storage = StorageService(dbName: dbName);
      final read = storage.getUserProfile();
      await storage.close();
      expect(await read, isNull, reason: 'round $round: the read');
      expect(storage.isOpen, isFalse, reason: 'round $round');
    }
  });

  test('a reset while an open is in flight leaves nothing open', () async {
    for (var round = 0; round < 20; round++) {
      final storage = StorageService(dbName: dbName);
      await storage.saveUserProfile(
          const UserProfile(name: 'Ada', learningGoal: LearningGoal.general));
      await storage.close();
      // Started before the reset: it may still find the profile; it must
      // complete.
      final read = storage.getUserProfile();
      await storage.resetAllLocalData();
      await read;
      expect(storage.isOpen, isFalse, reason: 'round $round');
      expect(await storage.getUserProfile(), isNull, reason: 'round $round');
      await storage.close();
    }
  });

  test('two first reads both complete', () async {
    final storage = StorageService(dbName: dbName);
    final both =
        await Future.wait([storage.getUserProfile(), storage.getUserProfile()]);
    expect(both, [isNull, isNull]);
    await storage.close();
  });
}
