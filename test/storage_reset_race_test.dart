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

  test('two first reads both complete', () async {
    final storage = StorageService(dbName: dbName);
    final both =
        await Future.wait([storage.getUserProfile(), storage.getUserProfile()]);
    expect(both, [isNull, isNull]);
    await storage.close();
  });
}
