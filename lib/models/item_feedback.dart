import 'error_entry.dart';

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

  /// True when the user left this item blank rather than answering it
  /// incorrectly — blank isn't wrong, so it shouldn't score or display as
  /// a mistake (mirrors the exclusion already applied to the error profile,
  /// see [nonGrammarErrorTypes]).
  bool get isSkipped =>
      errorType != null && nonGrammarErrorTypes.contains(errorType);

  factory ItemFeedback.fromJson(Map<String, dynamic> json) => ItemFeedback(
        itemId: json['itemId'] as String,
        isCorrect: json['isCorrect'] as bool,
        errorType: json['errorType'] as String?,
        rule: json['rule'] as String?,
        correctedAnswer: json['correctedAnswer'] as String,
        explanation: json['explanation'] as String,
      );
}
