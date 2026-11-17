import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// UI polish §1.2 (owner, 2026-11-17): a profile on one of the seven
/// retired heroes becomes Fox on the first read of the new build, silently,
/// and the stored id is rewritten (format unchanged, `avatar_14`).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_avatar_retired_migration.db';
  late String path;

  setUp(() async {
    path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
  });

  Future<String?> storedAvatar() async {
    final db = await databaseFactory.openDatabase(path);
    final row = (await db.query('user_profile')).single;
    await db.close();
    return row['avatar'] as String?;
  }

  Future<void> seed(StorageService storage, String? avatarId) async {
    // A first read creates the schema; then the row is written raw, as an
    // older build would have stored it.
    await storage.getUserProfile();
    await storage.close();
    final db = await databaseFactory.openDatabase(path);
    await db.insert('user_profile', {
      'id': 0,
      'name': 'Ada',
      'learning_goal': 'work',
      'avatar': avatarId,
    });
    await db.close();
  }

  for (final id in [
    'avatar_02',
    'avatar_03',
    'avatar_04',
    'avatar_06',
    'avatar_09',
    'avatar_10',
    'avatar_12',
  ]) {
    test('$id becomes Fox and is stored as avatar_14', () async {
      await seed(StorageService(dbName: dbName), id);
      final storage = StorageService(dbName: dbName);
      final profile = await storage.getUserProfile();
      expect(profile!.avatar, same(Avatar.fox));
      expect(profile.name, 'Ada');
      await storage.close();
      expect(await storedAvatar(), 'avatar_14');
    });
  }

  test('a current hero is left as it is', () async {
    await seed(StorageService(dbName: dbName), 'avatar_07');
    final storage = StorageService(dbName: dbName);
    expect((await storage.getUserProfile())!.avatar, same(Avatar.crab));
    await storage.close();
    expect(await storedAvatar(), 'avatar_07');
  });

  test('no avatar stays no avatar', () async {
    await seed(StorageService(dbName: dbName), null);
    final storage = StorageService(dbName: dbName);
    expect((await storage.getUserProfile())!.avatar, isNull);
    await storage.close();
    expect(await storedAvatar(), isNull);
  });
}
