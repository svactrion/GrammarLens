import 'daily_test_question.dart';

/// One calendar day's Daily Test — generated at most once per device per
/// day (PRD v2 §12.8) and cached locally, so re-opening the app the same
/// day reuses this instead of generating (and paying for) a new one.
///
/// [completedAt] is deliberately nullable rather than a hard single-attempt
/// lock: whether a completed set can be retaken is a UI-layer decision left
/// to the batch that builds the actual screens, not assumed here.
class DailyTestSet {
  /// Local calendar day this set belongs to, `YYYY-MM-DD` — same key shape
  /// as `StorageService`'s existing daily-session-cap tracking.
  final String day;

  final List<DailyTestQuestion> questions;
  final DateTime? completedAt;

  const DailyTestSet({
    required this.day,
    required this.questions,
    this.completedAt,
  });

  bool get isCompleted => completedAt != null;

  DailyTestSet copyWith({DateTime? completedAt}) => DailyTestSet(
        day: day,
        questions: questions,
        completedAt: completedAt ?? this.completedAt,
      );
}
