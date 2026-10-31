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
  ///
  /// [hasUnfilledBlank] is decided the same way: a partial multi-blank
  /// answer keeps a `____` for each box left empty (1.4.0 B8, owner
  /// 2026-10-31), and such an answer is never correct whatever the model
  /// says, so [isCorrect] is forced false. The model's error type is kept
  /// as returned; when it gave none, no error entry is saved.
  factory ItemFeedback.fromJson(
    Map<String, dynamic> json, {
    required bool isSkipped,
    bool hasUnfilledBlank = false,
  }) =>
      ItemFeedback(
        itemId: json['itemId'] as String,
        isCorrect: !hasUnfilledBlank && json['isCorrect'] as bool,
        isSkipped: isSkipped,
        errorType: json['errorType'] as String?,
        rule: json['rule'] as String?,
        correctedAnswer: json['correctedAnswer'] as String,
        explanation: json['explanation'] as String,
      );
}
