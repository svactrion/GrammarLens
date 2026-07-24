class ItemFeedback {
  final String itemId;
  final bool isCorrect;
  final bool isSkipped;
  final String? errorType;
  final String? rule;
  final String correctedAnswer;
  final String explanation;

  const ItemFeedback({
    required this.itemId,
    required this.isCorrect,
    required this.isSkipped,
    this.errorType,
    this.rule,
    required this.correctedAnswer,
    required this.explanation,
  });

  /// [isSkipped] is decided by our own code from the user's actual answer
  /// text, not parsed from the model's response — the model's wording for
  /// "left blank" varies run to run (e.g. "You left this one blank",
  /// "Nothing was written here"), so it can't be matched reliably. See
  /// ClaudeService.scoreAnswers, which computes it before calling this.
  factory ItemFeedback.fromJson(
    Map<String, dynamic> json, {
    required bool isSkipped,
  }) =>
      ItemFeedback(
        itemId: json['itemId'] as String,
        isCorrect: json['isCorrect'] as bool,
        isSkipped: isSkipped,
        errorType: json['errorType'] as String?,
        rule: json['rule'] as String?,
        correctedAnswer: json['correctedAnswer'] as String,
        explanation: json['explanation'] as String,
      );
}
