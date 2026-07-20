class ErrorEntry {
  final int? id;
  final String topicId;
  final String errorType;
  final DateTime timestamp;

  const ErrorEntry({
    this.id,
    required this.topicId,
    required this.errorType,
    required this.timestamp,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'topic_id': topicId,
        'error_type': errorType,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ErrorEntry.fromMap(Map<String, Object?> map) => ErrorEntry(
        id: map['id'] as int?,
        topicId: map['topic_id'] as String,
        errorType: map['error_type'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
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
