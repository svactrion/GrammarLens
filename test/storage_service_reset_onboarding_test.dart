import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// resetOnboarding (debug-only, see SettingsScreen's "Developer" section)
/// needs real persistence to mean anything — see
/// storage_service_daily_cap_test.dart's note on why this uses the ffi
/// `databaseFactory` instead of plain `flutter test`.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;

  // A file distinct from other ffi-backed test files' — `flutter test` runs
  // files concurrently, and they'd otherwise race on the same real db path.
  const dbName = 'test_reset_onboarding.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
  });

  test('resetOnboarding on a fresh install is a harmless no-op', () async {
    expect(await storageService.getUserProfile(), isNull);
    await storageService.resetOnboarding();
    expect(await storageService.getUserProfile(), isNull);
  });

  test('resetOnboarding clears a saved profile so getUserProfile is null '
      'again — the app\'s only "onboarding complete" signal', () async {
    const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);
    await storageService.saveUserProfile(profile);
    expect(await storageService.getUserProfile(), isNotNull);

    await storageService.resetOnboarding();

    expect(await storageService.getUserProfile(), isNull);
  });

  test('resetOnboarding does not touch practice history, unlike '
      'resetProgressData\'s separate, opposite scope', () async {
    const profile = UserProfile(name: 'Ada', learningGoal: LearningGoal.work);
    await storageService.saveUserProfile(profile);
    await storageService.recordSessionStarted();

    await storageService.resetOnboarding();

    expect(await storageService.getUserProfile(), isNull);
    expect(await storageService.getSessionCountForToday(), 1);
  });
}
