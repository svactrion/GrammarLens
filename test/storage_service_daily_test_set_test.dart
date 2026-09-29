import 'dart:convert';

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

  test(
      'a set cached before questions had an explanation still loads, '
      'with none', () async {
    await storageService.saveDailyTestSet(sampleQuestions(), day: '2026-09-20');
    // Rewrite the stored JSON exactly as an older build wrote it: the same
    // flat shape, with no "explanation" key at all.
    final db = await databaseFactory
        .openDatabase(join(await getDatabasesPath(), dbName));
    await db.update(
      'daily_test_sets',
      {
        'questions_json': jsonEncode([
          {
            'id': 'q1',
            'type': 'fill_in_blank',
            'instruction': 'Fill in the blank: She ___ to work every day.',
            'topicId': 'tenseSelection',
            'correctAnswer': 'goes',
            'commonWrongAnswers': [
              {'answer': 'go', 'comment': "Close! Needs an -s for 'she'."},
            ],
          },
        ]),
      },
      where: 'day = ?',
      whereArgs: ['2026-09-20'],
    );
    // Not closed: sqflite hands back the same single instance
    // StorageService already holds open for this path.

    final fetched = await storageService.getDailyTestSet('2026-09-20');

    final question = fetched!.questions.single;
    expect(question.correctAnswer, 'goes');
    expect(question.explanation, isNull);
    expect(question.commonWrongAnswers.single.answer, 'go');
  });

  test('a question\'s explanation survives the cache round trip', () async {
    await storageService.saveDailyTestSet([
      DailyTestQuestion(
        item: const PracticeItem(
          id: 'q1',
          type: PracticeItemType.fillInBlank,
          instruction: 'Fill in the blank: She ___ to work every day.',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'goes',
        commonWrongAnswers: const [],
        explanation: "With 'she', a present-simple verb takes -s.",
      ),
    ]);

    final fetched = await storageService.getDailyTestSetForToday();

    expect(fetched!.questions.single.explanation,
        "With 'she', a present-simple verb takes -s.");
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

  group('deleteStaleDailyTestSets (docs/1.1.0-shared-daily-test.md §7, C3)',
      () {
    final question = DailyTestQuestion(
      item: const PracticeItem(
        id: 'q0',
        type: PracticeItemType.fillInBlank,
        instruction: 'She ___ to work.',
      ),
      topicId: 'tenseSelection',
      correctAnswer: 'goes',
      commonWrongAnswers: const [],
    );

    Future<void> save(String day, {bool completed = false}) async {
      await storageService.saveDailyTestSet([question],
          day: day, source: DailyTestSource.shared);
      if (completed) {
        await storageService.completeDailyTest({'q0': 'goes'}, const [],
            day: day, completedAt: DateTime.parse(day));
      }
    }

    Future<Set<String>> days() async => {
          for (final d in [
            '2026-09-01',
            '2026-09-21',
            '2026-09-22',
            '2026-09-23',
            '2026-09-28',
            '2026-09-29',
            '2026-09-30',
          ])
            if (await storageService.getDailyTestSet(d) != null) d,
        };

    setUp(() {
      StorageService.clockForTesting = () => DateTime(2026, 9, 29, 10);
    });
    tearDown(() => StorageService.clockForTesting = DateTime.now);

    test(
        'deletes only unfinished sets more than 7 days old; completed ones, '
        'the last 7 days, today and tomorrow stay', () async {
      await save('2026-09-01'); // old, unfinished: deleted
      await save('2026-09-21'); // 8 days old, unfinished: deleted
      await save('2026-09-22'); // exactly 7 days old: kept
      await save('2026-09-23', completed: true);
      await save('2026-09-28', completed: true); // yesterday, completed
      await save('2026-09-29'); // today, unfinished
      await save('2026-09-30'); // tomorrow, prefetched
      StorageService.clockForTesting = () => DateTime(2026, 9, 29, 10);

      final deleted = await storageService.deleteStaleDailyTestSets();

      expect(deleted, 2);
      expect(await days(), {
        '2026-09-22',
        '2026-09-23',
        '2026-09-28',
        '2026-09-29',
        '2026-09-30',
      });
    });

    test('an old completed set keeps its answers', () async {
      await save('2026-09-01', completed: true);
      StorageService.clockForTesting = () => DateTime(2026, 9, 29, 10);

      expect(await storageService.deleteStaleDailyTestSets(), 0);
      final kept = (await storageService.getDailyTestSet('2026-09-01'))!;
      expect(kept.isCompleted, isTrue);
      expect(kept.answers, {'q0': 'goes'});
    });

    test('the cutoff follows the calendar across a month end', () async {
      await save('2026-09-23'); // 8 days before 2026-10-01
      await save('2026-09-24'); // exactly 7 days before
      StorageService.clockForTesting = () => DateTime(2026, 10, 1, 0, 5);

      expect(await storageService.deleteStaleDailyTestSets(), 1);
      expect(await storageService.getDailyTestSet('2026-09-23'), isNull);
      expect(await storageService.getDailyTestSet('2026-09-24'), isNotNull);
    });

    test('nothing to delete is a no-op', () async {
      expect(await storageService.deleteStaleDailyTestSets(), 0);
    });
  });
}
