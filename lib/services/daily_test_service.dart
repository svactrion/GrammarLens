import '../models/daily_test_set.dart';
import 'claude_service.dart';
import 'storage_service.dart';

/// Orchestrates the free-tier Daily Test (PRD v2 §12.2, §12.5, §12.8): get
/// today's cached set if one exists, otherwise generate exactly one —
/// personalized from the device's local error profile when it has one —
/// and cache it. This is the entry point a future paywall-free "always
/// accessible" Daily Test screen will call; no screen calls it yet.
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
    final cached = await storageService.getDailyTestSetForToday();
    if (cached != null) return cached;

    // An empty profile (new user, nothing practiced yet) is exactly what
    // asks ClaudeService for a general/varied mix instead of a biased one
    // — see generateDailyTestQuestions' doc comment.
    final weakSpots = await storageService.getWeakSpots(limit: questionCount);
    final questions = await claudeService.generateDailyTestQuestions(
      count: questionCount,
      weakSpots: weakSpots,
    );
    return storageService.saveDailyTestSet(questions);
  }

  /// Records today's set as completed once the learner finishes it.
  Future<void> markCompleted() => storageService.markDailyTestCompleted();
}
