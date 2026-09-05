/// Where a logged mistake came from — Topic Practice (LLM-scored, richer
/// feedback) or Daily Test (deterministic, no LLM call). Both write into
/// the same `error_entries` table/weak-spot aggregation (2026-09-05
/// decision: the free tier diagnoses via Daily Test, the paid tier
/// treats via Topic Practice — see docs/build-log.md), so a record needs
/// to say which one produced it even though nothing reads that
/// distinction yet.
enum ErrorSource {
  topicPractice,
  dailyTest;

  String toJson() => switch (this) {
        ErrorSource.topicPractice => 'topic_practice',
        ErrorSource.dailyTest => 'daily_test',
      };

  /// Defaults to [topicPractice] for null/unrecognized values — every row
  /// written before this field existed really was from Topic Practice
  /// (the only writer at the time), so this default is a true fact about
  /// old data, not just a safe fallback.
  static ErrorSource fromJson(String? value) => switch (value) {
        'daily_test' => ErrorSource.dailyTest,
        _ => ErrorSource.topicPractice,
      };
}

class ErrorEntry {
  final int? id;
  final String topicId;
  final String errorType;
  final DateTime timestamp;
  final String? prompt;
  final String? userAnswer;
  final String? correctedAnswer;
  final String? explanation;
  final String? rule;
  final ErrorSource source;

  const ErrorEntry({
    this.id,
    required this.topicId,
    required this.errorType,
    required this.timestamp,
    this.prompt,
    this.userAnswer,
    this.correctedAnswer,
    this.explanation,
    this.rule,
    required this.source,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'topic_id': topicId,
        'error_type': errorType,
        'timestamp': timestamp.toIso8601String(),
        'prompt': prompt,
        'user_answer': userAnswer,
        'corrected_answer': correctedAnswer,
        'explanation': explanation,
        'rule': rule,
        'source': source.toJson(),
      };

  factory ErrorEntry.fromMap(Map<String, Object?> map) => ErrorEntry(
        id: map['id'] as int?,
        topicId: map['topic_id'] as String,
        errorType: map['error_type'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        prompt: map['prompt'] as String?,
        userAnswer: map['user_answer'] as String?,
        correctedAnswer: map['corrected_answer'] as String?,
        explanation: map['explanation'] as String?,
        rule: map['rule'] as String?,
        source: ErrorSource.fromJson(map['source'] as String?),
      );
}

/// Aggregated view of an error pattern: how often this topic × error type
/// combination has been logged and when it was last seen, driving the
/// Review tab. [latestExplanation]/[latestRule] come from the most recent
/// logged mistake in the group, so Review can lead with plain language
/// instead of the rule name (PRD §2.1, Theme 2 and 4).
class WeakSpot {
  final String topicId;
  final String errorType;
  final int frequency;
  final DateTime lastSeen;
  final String? latestExplanation;
  final String? latestRule;

  const WeakSpot({
    required this.topicId,
    required this.errorType,
    required this.frequency,
    required this.lastSeen,
    this.latestExplanation,
    this.latestRule,
  });
}
