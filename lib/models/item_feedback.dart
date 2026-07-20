class ItemFeedback {
  final String itemId;
  final bool isCorrect;
  final String? errorType;
  final String? rule;
  final String correctedAnswer;
  final String explanation;

  const ItemFeedback({
    required this.itemId,
    required this.isCorrect,
    this.errorType,
    this.rule,
    required this.correctedAnswer,
    required this.explanation,
  });

  factory ItemFeedback.fromJson(Map<String, dynamic> json) => ItemFeedback(
        itemId: json['itemId'] as String,
        isCorrect: json['isCorrect'] as bool,
        errorType: json['errorType'] as String?,
        rule: json['rule'] as String?,
        correctedAnswer: json['correctedAnswer'] as String,
        explanation: json['explanation'] as String,
      );
}
