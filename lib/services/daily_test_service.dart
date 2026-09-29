import 'dart:async';

import '../data/day_zero_daily_test.dart';
import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import 'claude_service.dart';
import 'storage_service.dart';

/// Orchestrates the free-tier Daily Test (PRD v2 §12.2, §12.5, §12.8) on
/// 1.1.0's shared sets (docs/1.1.0-shared-daily-test.md §5, §7): a day's set
/// is today's cached one if it exists, otherwise the date's shared set read
/// from the proxy — the same questions for everyone on that date — and if
/// that cannot be read, a set that ships inside the app. The Daily Test is
/// never empty, and nothing here ever asks the proxy to generate a set: that
/// happens once per date on the proxy's own schedule. Used by both Home and
/// the Day-0 onboarding test.
class DailyTestService {
  /// 5 questions — enough to feel like a real test, short enough to finish
  /// in one sitting; matches the existing "Standard" Topic Practice length.
  /// Every shared set has exactly this many (the proxy's gate).
  static const int questionCount = 5;

  final ClaudeService claudeService;
  final StorageService storageService;

  DailyTestService({
    required this.claudeService,
    required this.storageService,
  });

  /// What a day gets when its shared set cannot be read. For now the fixed
  /// first-day questions (marked [DailyTestSource.fallback], so the two stay
  /// apart in analytics); the pool of hand-checked fallback sets replaces it
  /// in batch C2 (docs/1.1.0-shared-daily-test.md §5, §11).
  static List<DailyTestQuestion> get fallbackQuestions => kDayZeroQuestions;

  /// The load (cache, shared read, fallback) currently running for each day.
  /// See [getTodaysSet].
  final Map<String, Future<DailyTestSet>> _inFlight = {};

  /// Background reads of a coming day's shared set ([prefetchSet]).
  final Map<String, Future<void>> _prefetching = {};

  /// Returns today's Daily Test set: the cached one, else today's shared set
  /// (cached once read, so a repeat open the same day makes no request),
  /// else the fallback (also cached, so the day keeps the same questions
  /// until midnight). Only a failure to read or write local storage can
  /// throw.
  ///
  /// Single-flight per day: while a call for a day is still running, every
  /// other call for the same day gets that same [Future] instead of starting a
  /// second request, so a screen opened while another caller is already
  /// loading simply waits for that result. The in-flight slot is cleared as
  /// soon as the call finishes, success or failure, so a failure is never
  /// remembered: the next call is a real new attempt (and everyone who joined a
  /// failing call sees its error). A call for a different day (the clock
  /// crossed midnight while one was running) does not join it.
  Future<DailyTestSet> getTodaysSet() => _getSet(storageService.currentDayKey);

  Future<DailyTestSet> _getSet(String day) {
    final running = _inFlight[day];
    if (running != null) return running;

    final future = _load(day);
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

  /// Reads [day]'s shared set ahead of time and caches it, so that day's
  /// test opens from the cache with no wait, offline included. A read only —
  /// it costs no generation — and it never reports a failure: nothing is
  /// waiting for the result. A date that has no shared set yet (404), or any
  /// failure, leaves the day untouched; that day's first open simply tries
  /// the shared set again, then the fallback. It never writes the fallback,
  /// so a coming day is never pinned to it. A day that already has a set, or
  /// whose load or prefetch is already running, costs no request. Meant for
  /// the next day, right after the day's test is completed.
  Future<void> prefetchSet(String day) {
    if (_inFlight.containsKey(day)) return Future.value();
    final running = _prefetching[day];
    if (running != null) return running;
    final future = _prefetch(day);
    _prefetching[day] = future;
    future.whenComplete(() {
      if (identical(_prefetching[day], future)) _prefetching.remove(day);
    });
    return future;
  }

  Future<void> _prefetch(String day) async {
    try {
      if (await storageService.getDailyTestSet(day) != null) return;
      final questions = await claudeService.fetchSharedDailyTest(day);
      if (questions == null) return;
      await storageService.saveDailyTestSet(questions,
          day: day, source: DailyTestSource.shared);
    } catch (_) {}
  }

  /// Writes the fixed first-day set ([kDayZeroQuestions]) as today's set, unless
  /// today already has one, in which case nothing changes. Called by the
  /// first-launch flow before the profile is saved, so the Daily Test opens on
  /// a set that is already on disk: no request, no wait, and the same
  /// questions whether the user goes on from onboarding or closes the app
  /// during the test and opens it from Home. It only ever fills an empty day,
  /// so it can never replace a shared or a completed set.
  Future<void> seedDayZeroSet() async {
    final day = storageService.currentDayKey;
    if (await storageService.getDailyTestSetForToday() != null) return;
    await storageService.saveDailyTestSet(
      kDayZeroQuestions,
      day: day,
      source: DailyTestSource.bundled,
    );
  }

  /// Cache → shared set → fallback, for [day]. A shared set is saved only
  /// after it was read and parsed in full ([ClaudeService.fetchSharedDailyTest]
  /// throws on anything less), so a broken response is never cached as the
  /// day's test; it just falls through to the fallback.
  Future<DailyTestSet> _load(String day) async {
    // A read of this day started ahead of time (the clock crossed midnight
    // right after a completion) finishes first, so the two never race to
    // write the same day. It never throws.
    final prefetch = _prefetching[day];
    if (prefetch != null) await prefetch;

    final cached = await storageService.getDailyTestSet(day);
    if (cached != null) return cached;

    List<DailyTestQuestion>? shared;
    try {
      shared = await claudeService.fetchSharedDailyTest(day);
    } catch (_) {
      shared = null;
    }
    if (shared != null) {
      return storageService.saveDailyTestSet(shared,
          day: day, source: DailyTestSource.shared);
    }
    return storageService.saveDailyTestSet(fallbackQuestions,
        day: day, source: DailyTestSource.fallback);
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
  /// Once the completion is saved, the next day's shared set is read in the
  /// background ([prefetchSet]), so that day's test opens from the cache with no
  /// wait. That includes the day of the fixed first test. It is started only after
  /// a successful save (a failed one throws before this point), never delays the
  /// result, and its own failure is silent. A completion repeated for the same day
  /// finds the next day's set already there, or already being read, and asks
  /// for nothing more.
  Future<bool> completeDailyTest(
    Map<String, String> answers,
    List<ErrorEntry> errorEntries, {
    String? day,
    DateTime? completedAt,
  }) async {
    final setDay = day ?? storageService.currentDayKey;
    final earned = await storageService.completeDailyTest(answers, errorEntries,
        day: setDay, completedAt: completedAt);
    unawaited(prefetchSet(StorageService.dayKeyAfter(setDay)));
    return earned;
  }
}
