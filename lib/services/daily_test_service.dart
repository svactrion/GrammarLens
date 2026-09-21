import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import 'claude_service.dart';
import 'storage_service.dart';

/// Orchestrates the free-tier Daily Test (PRD v2 §12.2, §12.5, §12.8): get
/// today's cached set if one exists, otherwise generate exactly one — a
/// general mix, the same request for every user — and cache it. Used by both
/// Home and the Day-0 onboarding test.
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

  /// The generation (or cache read) currently running, and the day it is for.
  /// See [getTodaysSet].
  Future<DailyTestSet>? _inFlight;
  String? _inFlightDay;

  /// Returns today's Daily Test set, generating and caching one first if
  /// today's device hasn't already gotten one — so a repeat open the same
  /// day never triggers a second generation call.
  ///
  /// Single-flight per day: while a call for a day is still running, every
  /// other call for the same day gets that same [Future] instead of starting a
  /// second request. This is what lets the first-launch flow start generating
  /// early ([preloadTodaysSet]) and have the Daily Test screen simply wait for
  /// it. The in-flight slot is cleared as soon as the call finishes, success or
  /// failure, so a failure is never remembered: the next call is a real new
  /// attempt (and everyone who joined a failing call sees its error). A call
  /// for a different day (the clock crossed midnight while one was running)
  /// does not join it.
  Future<DailyTestSet> getTodaysSet() {
    final day = storageService.currentDayKey;
    final running = _inFlight;
    if (running != null && _inFlightDay == day) return running;

    final future = _loadOrGenerate(day);
    _inFlight = future;
    _inFlightDay = day;
    // Registered before any caller's own listener, so by the time a caller
    // sees the result the slot is already free. Handles both outcomes, so it
    // never leaves an unhandled error behind.
    void release(Object? _, [StackTrace? __]) {
      if (identical(_inFlight, future)) {
        _inFlight = null;
        _inFlightDay = null;
      }
    }

    future.then(release, onError: release);
    return future;
  }

  /// Starts [getTodaysSet] without waiting for it, for a caller that expects
  /// to need the set soon. Any failure is dropped here on purpose: nothing has
  /// asked for the result yet, so there is nobody to tell, and the screen that
  /// eventually needs the set makes its own attempt and shows its own error.
  void preloadTodaysSet() {
    getTodaysSet().then((_) {}, onError: (Object _) {});
  }

  /// Deliberately generate-then-save, not save-as-you-go: `await` on
  /// [ClaudeService.generateDailyTestQuestions] means a failure there (bad
  /// API response, a parse error) throws before [StorageService.saveDailyTestSet]
  /// is ever reached, so a half/failed generation can never get cached as
  /// "today's test" — a retry always gets a real attempt, not a
  /// permanently broken cached row for the day.
  Future<DailyTestSet> _loadOrGenerate(String day) async {
    final cached = await storageService.getDailyTestSetForToday();
    if (cached != null) return cached;

    final deviceId = await storageService.getOrCreateDeviceId();
    final questions = await claudeService.generateDailyTestQuestions(
      deviceId: deviceId,
      count: questionCount,
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
  ///
  /// Returns whether this call just earned the Welcome badge — see
  /// `StorageService.completeDailyTest`'s own doc comment.
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) =>
      storageService.completeDailyTest(answers, errorEntries,
          day: day, completedAt: completedAt);
}
