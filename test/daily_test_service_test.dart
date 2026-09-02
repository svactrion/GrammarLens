import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/daily_test_service.dart';
import 'package:grammar_lens/services/storage_service.dart';

/// Stands in for the real network-backed ClaudeService so this test can
/// assert on how many times generation was actually called, without an API
/// key or a live request.
class _FakeClaudeService extends ClaudeService {
  int generateCallCount = 0;
  List<WeakSpot>? lastWeakSpots;

  @override
  Future<List<DailyTestQuestion>> generateDailyTestQuestions({
    required int count,
    required List<WeakSpot> weakSpots,
  }) async {
    generateCallCount++;
    lastWeakSpots = weakSpots;
    return List.generate(
      count,
      (i) => DailyTestQuestion(
        item: PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question $i',
        ),
        topicId: 'tenseSelection',
        correctAnswer: 'answer$i',
        commonWrongAnswers: const [],
      ),
    );
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late StorageService storageService;
  late _FakeClaudeService claudeService;
  late DailyTestService dailyTestService;

  setUp(() async {
    final path = join(await getDatabasesPath(), 'grammar_lens.db');
    await databaseFactory.deleteDatabase(path);
    storageService = StorageService();
    claudeService = _FakeClaudeService();
    dailyTestService = DailyTestService(
      claudeService: claudeService,
      storageService: storageService,
    );
  });

  test('generates and caches a set on first open today', () async {
    final set = await dailyTestService.getTodaysSet();
    expect(claudeService.generateCallCount, 1);
    expect(set.questions, hasLength(DailyTestService.questionCount));
    expect(set.isCompleted, isFalse);
  });

  test('a repeat open the same day reuses the cached set, no regeneration',
      () async {
    final first = await dailyTestService.getTodaysSet();
    final second = await dailyTestService.getTodaysSet();

    expect(claudeService.generateCallCount, 1);
    expect(second.day, first.day);
    expect(
      second.questions.map((q) => q.item.id),
      first.questions.map((q) => q.item.id),
    );
  });

  test('a new user with no error profile generates with an empty weak-spot '
      'list', () async {
    await dailyTestService.getTodaysSet();
    expect(claudeService.lastWeakSpots, isEmpty);
  });

  test('an existing error profile is passed through to generation',
      () async {
    await storageService.insertErrors([
      ErrorEntry(
        topicId: 'articles',
        errorType: 'missing_article',
        timestamp: DateTime.now(),
      ),
    ]);

    await dailyTestService.getTodaysSet();

    expect(claudeService.lastWeakSpots, isNotEmpty);
    expect(claudeService.lastWeakSpots!.single.topicId, 'articles');
  });

  test('markCompleted flows through to the cached set', () async {
    await dailyTestService.getTodaysSet();
    await dailyTestService.markCompleted();

    final set = await storageService.getDailyTestSetForToday();
    expect(set!.isCompleted, isTrue);
  });
}
