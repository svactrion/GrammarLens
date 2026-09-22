import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Daily Test's local cache needs real persistence to mean anything — see
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
  const dbName = 'test_daily_test_set.db';

  setUp(() async {
    final path = join(await getDatabasesPath(), dbName);
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService(dbName: dbName);
  });

  List<DailyTestQuestion> sampleQuestions() => [
        DailyTestQuestion(
          item: const PracticeItem(
            id: 'q1',
            type: PracticeItemType.fillInBlank,
            instruction: 'Fill in the blank: She ___ to work every day.',
          ),
          topicId: 'tenseSelection',
          correctAnswer: 'goes',
          commonWrongAnswers: const [
            CommonWrongAnswer(
              answer: 'go',
              comment: "Close! But with 'she', the verb needs an -s.",
            ),
          ],
        ),
      ];

  test('a set is read by its day, and another day\'s set is not today\'s',
      () async {
    StorageService.clockForTesting = () => DateTime(2026, 9, 22, 10);
    addTearDown(() => StorageService.clockForTesting = DateTime.now);
    await storageService.saveDailyTestSet(sampleQuestions(), day: '2026-09-23');

    expect(await storageService.getDailyTestSet('2026-09-22'), isNull);
    expect(await storageService.getDailyTestSetForToday(), isNull);
    final tomorrow = await storageService.getDailyTestSet('2026-09-23');
    expect(tomorrow!.day, '2026-09-23');
    expect(tomorrow.questions.single.correctAnswer, 'goes');

    StorageService.clockForTesting = () => DateTime(2026, 9, 23, 0, 1);
    expect((await storageService.getDailyTestSetForToday())!.day, '2026-09-23');
  });

  test('a fresh day has no cached set yet', () async {
    expect(await storageService.getDailyTestSetForToday(), isNull);
  });

  test('a saved set round-trips with the same questions and no completion',
      () async {
    final saved = await storageService.saveDailyTestSet(sampleQuestions());
    expect(saved.isCompleted, isFalse);

    final fetched = await storageService.getDailyTestSetForToday();
    expect(fetched, isNotNull);
    expect(fetched!.day, saved.day);
    expect(fetched.isCompleted, isFalse);
    expect(fetched.questions, hasLength(1));
    expect(fetched.questions.single.correctAnswer, 'goes');
    expect(fetched.questions.single.item.instruction,
        'Fill in the blank: She ___ to work every day.');
    expect(fetched.questions.single.commonWrongAnswers.single.answer, 'go');
  });

  test(
      'a set is generated unless saved as bundled, and the source survives a '
      'reopen', () async {
    final generated = await storageService.saveDailyTestSet(sampleQuestions());
    expect(generated.source, DailyTestSource.generated);

    await storageService.saveDailyTestSet(sampleQuestions(),
        source: DailyTestSource.bundled);
    final reopened = StorageService(dbName: dbName);
    expect((await reopened.getDailyTestSetForToday())!.source,
        DailyTestSource.bundled);
  });

  test('a completed set keeps its source, and a stale save cannot change it',
      () async {
    await storageService.saveDailyTestSet(sampleQuestions(),
        source: DailyTestSource.bundled);
    await storageService.completeDailyTest({'q1': 'goes'}, []);

    final again = await storageService.saveDailyTestSet(sampleQuestions());

    expect(again.isCompleted, isTrue);
    expect(again.source, DailyTestSource.bundled);
  });

  test('saving again for the same day replaces rather than duplicating',
      () async {
    await storageService.saveDailyTestSet(sampleQuestions());
    await storageService.saveDailyTestSet([
      DailyTestQuestion(
        item: const PracticeItem(
          id: 'q2',
          type: PracticeItemType.errorCorrection,
          context: 'He go to school.',
          instruction: 'Rewrite the corrected sentence.',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'He goes to school.',
        commonWrongAnswers: const [],
      ),
    ]);

    final fetched = await storageService.getDailyTestSetForToday();
    expect(fetched!.questions, hasLength(1));
    expect(fetched.questions.single.item.id, 'q2');
  });

  test(
      'completeDailyTest sets a completion timestamp and persists '
      'the answers', () async {
    await storageService.saveDailyTestSet(sampleQuestions());
    await storageService.completeDailyTest({'q1': 'goes'}, []);

    final fetched = await storageService.getDailyTestSetForToday();
    expect(fetched!.isCompleted, isTrue);
    expect(fetched.completedAt, isNotNull);
    expect(fetched.answers, {'q1': 'goes'});
  });

  test('completeDailyTest with no set for today is a harmless no-op', () async {
    await storageService.completeDailyTest({'q1': 'goes'}, []);
    expect(await storageService.getDailyTestSetForToday(), isNull);
  });

  test("Daily Test's cache is independent of the Topic Practice daily cap",
      () async {
    await storageService.recordSessionStarted();
    await storageService.recordSessionStarted();

    expect(await storageService.getDailyTestSetForToday(), isNull);
    await storageService.saveDailyTestSet(sampleQuestions());

    // Saving/generating a Daily Test set must not touch the separate
    // Topic Practice session counter either way.
    expect(await storageService.getSessionCountForToday(), 2);
  });
}
