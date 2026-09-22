import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/services/storage_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  const dbName = 'test_ai_consent.db';
  late StorageService storage;

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storage = StorageService(dbName: dbName);
  });

  test('a user who was never asked has no decision', () async {
    expect(await storage.getAiConsent(), isNull);
  });

  test('a grant persists with its time and the current version', () async {
    final at = DateTime(2026, 9, 21, 10, 30);
    await storage.setAiConsent(granted: true, decidedAt: at);

    final consent = (await storage.getAiConsent())!;
    expect(consent.granted, isTrue);
    expect(consent.decidedAt, at);
    expect(consent.version, AiConsent.currentVersion);
    expect(consent.allowsSending, isTrue);
  });

  test('a decline is stored and does not allow sending', () async {
    await storage.setAiConsent(granted: false);

    final consent = (await storage.getAiConsent())!;
    expect(consent.granted, isFalse);
    expect(consent.allowsSending, isFalse);
  });

  test('a later decision replaces the earlier one (one row only)', () async {
    await storage.setAiConsent(granted: true);
    await storage.setAiConsent(granted: false);
    expect((await storage.getAiConsent())!.granted, isFalse);
    await storage.setAiConsent(granted: true);
    expect((await storage.getAiConsent())!.granted, isTrue);

    final db = await databaseFactory
        .openDatabase(join(await getDatabasesPath(), dbName));
    final rows = await db.query('ai_consent');
    await db.close();
    expect(rows, hasLength(1));
  });

  test('a grant given for an older version no longer allows sending', () async {
    await storage.setAiConsent(granted: true);
    final path = join(await getDatabasesPath(), dbName);
    final db = await databaseFactory.openDatabase(path);
    await db.update('ai_consent', {'consent_version': 0});
    await db.close();

    final consent = (await StorageService(dbName: dbName).getAiConsent())!;
    expect(consent.granted, isTrue);
    expect(consent.allowsSending, isFalse);
  });

  test('resetting progress data keeps the permission decision', () async {
    await storage.setAiConsent(granted: true);
    await storage.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'missing_article',
        timestamp: DateTime.now(),
        source: ErrorSource.topicPractice,
      ),
    ]);

    await storage.resetProgressData();

    expect(await storage.getWeakSpots(), isEmpty);
    expect((await storage.getAiConsent())!.allowsSending, isTrue);
  });
}
