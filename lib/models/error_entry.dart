/// errorType values the LLM uses to mean "the user didn't answer this item"
/// rather than an actual grammar mistake. These are never written to the
/// error profile — an unanswered item says nothing about the user's grammar,
/// so counting it would pollute Review with false weak spots.
const Set<String> nonGrammarErrorTypes = {'no_response', 'missing_response'};

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
      );
}

/// Aggregated view of an error pattern: how often this topic × error type
/// combination has been logged, driving the Review tab.
class WeakSpot {
  final String topicId;
  final String errorType;
  final int frequency;

  const WeakSpot({
    required this.topicId,
    required this.errorType,
    required this.frequency,
  });
}
