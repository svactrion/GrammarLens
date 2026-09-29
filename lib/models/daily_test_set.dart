import 'daily_test_question.dart';

/// Where a day's set came from. Stored as the enum's name and reported as
/// `set_source` on `daily_test_completed`
/// (docs/1.1.0-shared-daily-test.md §9).
enum DailyTestSource {
  /// Generated for this device by the legacy per-device route: 1.0.0, and
  /// rows a 1.1.0 install cached before it updated. 1.1.0 never writes it.
  generated,

  /// The fixed first-day set that ships inside the app (day 0).
  bundled,

  /// The date's shared set, read from the proxy
  /// (`GET /v1/shared-daily-test/{date}`): the same questions for everyone
  /// on that date.
  shared,

  /// Shown because the shared set could not be read (offline, timeout, not
  /// published, a bad response): content that ships inside the app. Its
  /// share of completions is the health of the shared pipeline.
  fallback,
}

/// One calendar day's Daily Test — fetched at most once per device per day
/// (PRD v2 §12.8) and cached locally, so re-opening the app the same day
/// reuses this instead of asking again.
///
/// [completedAt] is deliberately nullable rather than a hard single-attempt
/// lock: whether a completed set can be retaken is a UI-layer decision left
/// to the batch that builds the actual screens, not assumed here.
class DailyTestSet {
  /// The number of questions in a day's set ([Q]): 5 — enough to feel like
  /// a real test, short enough to finish in one sitting; matches the
  /// "Standard" Topic Practice length. The one source for everything that
  /// depends on it: generation, the medal maximum, Home's card copy. The
  /// bundled Day-0 set is checked against it by a test; the proxy's shared
  /// set has its own copy (`SHARED_SET_QUESTION_COUNT`).
  static const int questionCount = 5;

  /// Local calendar day this set belongs to, `YYYY-MM-DD` — same key shape
  /// as `StorageService`'s existing daily-session-cap tracking.
  final String day;

  final List<DailyTestQuestion> questions;
  final DateTime? completedAt;

  /// The user's answers at the moment of completion, keyed by
  /// `DailyTestQuestion.item.id` — null until [completedAt] is set. This
  /// is the only persisted record of what was actually answered; without
  /// it neither a score nor "view the result again" (PRD v2 §13.5) can be
  /// reconstructed once the live session that computed them is gone.
  final Map<String, String>? answers;

  final DailyTestSource source;

  const DailyTestSet({
    required this.day,
    required this.questions,
    this.completedAt,
    this.answers,
    this.source = DailyTestSource.generated,
  });

  bool get isCompleted => completedAt != null;

  DailyTestSet copyWith({
    DateTime? completedAt,
    Map<String, String>? answers,
  }) =>
      DailyTestSet(
        day: day,
        questions: questions,
        completedAt: completedAt ?? this.completedAt,
        answers: answers ?? this.answers,
        source: source,
      );
}
