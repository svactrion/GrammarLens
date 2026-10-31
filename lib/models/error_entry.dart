import 'dart:convert';

import '../utils/blank_assembly.dart';
import 'item_feedback.dart';

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

  /// On a multi-blank Practice question, what each answer box held, in
  /// blank order (1.4.0 B8): [userAnswer] is the assembled sentence and
  /// cannot be split back into boxes reliably. Null for a single-box answer
  /// and for every row written before the column existed; those render as
  /// the assembled sentence.
  final List<BlankAnswer>? userBlanks;

  /// The scorer's short overall lesson (1.4.0 D11); null for a record from
  /// the old proxy and for every row written before the column existed.
  /// [explanation] keeps the full text either way (owner, 2026-10-31).
  final String? summary;

  /// The scorer's per-blank verdicts (1.4.0 D11), paired with [userBlanks]
  /// by index; null as [summary] is. Stored with it as one JSON object in
  /// `feedback_json`.
  final List<BlankFeedback>? blankFeedback;

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
    this.userBlanks,
    this.summary,
    this.blankFeedback,
  });

  /// `{"summary": …, "blanks": [...]}` for `feedback_json`, each part only
  /// when present; null when neither is.
  static String? encodeFeedback(String? summary, List<BlankFeedback>? blanks) {
    if (summary == null && blanks == null) return null;
    return jsonEncode({
      if (summary != null) 'summary': summary,
      if (blanks != null) 'blanks': [for (final b in blanks) b.toJson()],
    });
  }

  /// The inverse of [encodeFeedback]. Null, an empty string and anything
  /// that is not a JSON object read as nothing, and a malformed `blanks`
  /// list reads as null on its own ([BlankFeedback.listFromJson]), so an
  /// old or odd row never fails to load.
  static ({String? summary, List<BlankFeedback>? blanks}) decodeFeedback(
      String? encoded) {
    if (encoded == null || encoded.isEmpty) {
      return (summary: null, blanks: null);
    }
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return (summary: null, blanks: null);
      final summary = decoded['summary'];
      return (
        summary: summary is String && summary.trim().isNotEmpty
            ? summary.trim()
            : null,
        blanks: BlankFeedback.listFromJson(decoded['blanks']),
      );
    } on FormatException {
      return (summary: null, blanks: null);
    }
  }

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
        'user_blanks':
            userBlanks == null ? null : BlankAnswer.encodeList(userBlanks!),
        'feedback_json': encodeFeedback(summary, blankFeedback),
      };

  factory ErrorEntry.fromMap(Map<String, Object?> map) {
    final feedback = decodeFeedback(map['feedback_json'] as String?);
    return ErrorEntry(
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
      userBlanks: BlankAnswer.decodeList(map['user_blanks'] as String?),
      summary: feedback.summary,
      blankFeedback: feedback.blanks,
    );
  }
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
