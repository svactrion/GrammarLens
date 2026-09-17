import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import 'claude_service.dart';
import 'storage_service.dart';

/// Orchestrates the free-tier Daily Test (PRD v2 §12.2, §12.5, §12.8): get
/// today's cached set if one exists, otherwise generate exactly one —
/// personalized from the device's local error profile when it has one —
/// and cache it. Used by both Home and the Day-0 onboarding test.
class DailyTestService {
  /// 5 questions — enough to feel like a real test, short enough to finish
  /// in one sitting; matches the existing "Standard" Topic Practice length.
  static const int questionCount = 5;

  final ClaudeService claudeService;
  final StorageService storageService;

  DailyTestService({
    required this.claudeService,
    required this.storageService,
  });

  /// Returns today's Daily Test set, generating and caching one first if
  /// today's device hasn't already gotten one — so a repeat open the same
  /// day never triggers a second generation call.
  ///
  /// Deliberately generate-then-save, not save-as-you-go: `await` on
  /// [ClaudeService.generateDailyTestQuestions] means a failure there (bad
  /// API response, a parse error) throws before [StorageService.saveDailyTestSet]
  /// is ever reached, so a half/failed generation can never get cached as
  /// "today's test" — a retry always gets a real attempt, not a
  /// permanently broken cached row for the day.
  Future<DailyTestSet> getTodaysSet() async {
    final day = storageService.currentDayKey;
    final cached = await storageService.getDailyTestSetForToday();
    if (cached != null) return cached;

    // An empty profile (new user, nothing practiced yet) is exactly what
    // asks ClaudeService for a general/varied mix instead of a biased one
    // — see generateDailyTestQuestions' doc comment.
    final weakSpots = await storageService.getWeakSpots(limit: questionCount);
    final deviceId = await storageService.getOrCreateDeviceId();
    final questions = await claudeService.generateDailyTestQuestions(
      deviceId: deviceId,
      count: questionCount,
      weakSpots: weakSpots,
    );
    return storageService.saveDailyTestSet(questions, day: day);
  }

  /// Records today's set as completed once the learner finishes it —
  /// persisting [answers] and this session's wrong answers ([errorEntries],
  /// the same shape Topic Practice's ResultsScreen writes into the shared
  /// error profile, 2026-09-05 decision — see docs/build-log.md) together
  /// with the climb entry in one atomic write. See `StorageService.completeDailyTest`'s own doc
  /// comment for why these two used to be, and no longer are, independent
  /// calls.
  Future<void> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) =>
      storageService.completeDailyTest(answers, errorEntries,
          day: day, completedAt: completedAt);
}
