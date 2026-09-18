import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/services/storage_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_text_size.db';
  late StorageService storage;

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storage = StorageService(dbName: dbName);
  });

  test('defaults to medium and persists every text-size option', () async {
    expect(await storage.getTextSize(), AppTextSize.medium);

    for (final size in AppTextSize.values) {
      await storage.setTextSize(size);
      expect(await storage.getTextSize(), size);
    }
  });
}
