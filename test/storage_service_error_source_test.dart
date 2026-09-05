import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// `error_entries.source` (schema v12) needs real persistence to mean
/// anything — see storage_service_daily_cap_test.dart's note on why this
/// uses the ffi `databaseFactory` instead of plain `flutter test`.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;

  const dbName = 'test_error_source.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
  });

  test('a Daily Test mistake round-trips through getRecentMistakes tagged '
      'as such', () async {
    await storageService.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'articles',
        timestamp: DateTime(2026, 1, 1),
        source: ErrorSource.dailyTest,
      ),
    ]);

    final mistakes =
        await storageService.getRecentMistakes('articles', 'articles');

    expect(mistakes.single.source, ErrorSource.dailyTest);
  });

  test('a Topic Practice mistake round-trips tagged as such', () async {
    await storageService.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'missing_article',
        timestamp: DateTime(2026, 1, 1),
        source: ErrorSource.topicPractice,
      ),
    ]);

    final mistakes =
        await storageService.getRecentMistakes('articles', 'missing_article');

    expect(mistakes.single.source, ErrorSource.topicPractice);
  });

  test('both sources feed the same weak-spot aggregation — no parallel '
      'path, they group together when topic and error type match',
      () async {
    await storageService.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'articles',
        timestamp: DateTime(2026, 1, 1),
        source: ErrorSource.dailyTest,
      ),
      ErrorEntry(
        topicId: 'articles',
        errorType: 'articles',
        timestamp: DateTime(2026, 1, 2),
        source: ErrorSource.topicPractice,
      ),
    ]);

    final weakSpots = await storageService.getWeakSpots();

    expect(weakSpots, hasLength(1));
    expect(weakSpots.single.frequency, 2);
  });
}
