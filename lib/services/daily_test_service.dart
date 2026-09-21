import 'dart:async';

import '../data/day_zero_daily_test.dart';
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

  /// The generation (or cache read) currently running for each day. See
  /// [getTodaysSet].
  final Map<String, Future<DailyTestSet>> _inFlight = {};

  /// Returns today's Daily Test set, generating and caching one first if
  /// today's device hasn't already gotten one — so a repeat open the same
  /// day never triggers a second generation call.
  ///
  /// Single-flight per day: while a call for a day is still running, every
  /// other call for the same day gets that same [Future] instead of starting a
  /// second request, so a screen opened while another caller is already
  /// generating simply waits for that result. The in-flight slot is cleared as
  /// soon as the call finishes, success or failure, so a failure is never
  /// remembered: the next call is a real new attempt (and everyone who joined a
  /// failing call sees its error). A call for a different day (the clock
  /// crossed midnight while one was running) does not join it.
  Future<DailyTestSet> getTodaysSet() => _getSet(storageService.currentDayKey);

  Future<DailyTestSet> _getSet(String day) {
    final running = _inFlight[day];
    if (running != null) return running;

    final future = _loadOrGenerate(day);
    _inFlight[day] = future;
    // Registered before any caller's own listener, so by the time a caller
    // sees the result the slot is already free. Handles both outcomes, so it
    // never leaves an unhandled error behind.
    void release(Object? _, [StackTrace? __]) {
      if (identical(_inFlight[day], future)) _inFlight.remove(day);
    }

    future.then(release, onError: release);
    return future;
  }

  /// Makes sure [day]'s set exists, generating and caching it if it does not,
  /// and never reports a failure: nothing is waiting for the result, so there is
  /// nobody to tell, and the day's own first open simply generates as it always
  /// did. A day that already has a set (cached, or a generation already in
  /// flight) costs no request. Meant for the next day, right after the day's
  /// test is completed.
  Future<void> prefetchSet(String day) async {
    try {
      await _getSet(day);
    } catch (_) {}
  }

  /// Writes the fixed first-day set ([kDayZeroQuestions]) as today's set, unless
  /// today already has one, in which case nothing changes. Called by the
  /// first-launch flow before the profile is saved, so the Daily Test opens on
  /// a set that is already on disk: no generation, no wait, and the same
  /// questions whether the user goes on from onboarding or closes the app
  /// during the test and opens it from Home. It only ever fills an empty day,
  /// so it can never replace a generated or a completed set.
  Future<void> seedDayZeroSet() async {
    final day = storageService.currentDayKey;
    if (await storageService.getDailyTestSetForToday() != null) return;
    await storageService.saveDailyTestSet(
      kDayZeroQuestions,
      day: day,
      source: DailyTestSource.bundled,
    );
  }

  /// Deliberately generate-then-save, not save-as-you-go: `await` on
  /// [ClaudeService.generateDailyTestQuestions] means a failure there (bad
  /// API response, a parse error) throws before [StorageService.saveDailyTestSet]
  /// is ever reached, so a half/failed generation can never get cached as
  /// "today's test" — a retry always gets a real attempt, not a
  /// permanently broken cached row for the day.
  Future<DailyTestSet> _loadOrGenerate(String day) async {
    final cached = await storageService.getDailyTestSet(day);
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
  ///
  /// Once the completion is saved, the next day's set is prepared in the
  /// background ([prefetchSet]), so that day's test opens from the cache with no
  /// wait. That includes the day of the fixed first test. It is started only after
  /// a successful save (a failed one throws before this point), never delays the
  /// result, and its own failure is silent. A completion repeated for the same day
  /// finds the next day's set already there, or already being generated, and asks
  /// for nothing more.
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    final setDay = day ?? storageService.currentDayKey;
    final earned = await storageService.completeDailyTest(
        answers, errorEntries,
        day: setDay, completedAt: completedAt);
    unawaited(prefetchSet(StorageService.dayKeyAfter(setDay)));
    return earned;
  }
}
