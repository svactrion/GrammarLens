import 'item_feedback.dart';

class ScoringResult {
  final String topicId;
  final List<ItemFeedback> feedback;

  const ScoringResult({required this.topicId, required this.feedback});

  int get correctCount =>
      feedback.where((f) => f.isCorrect && !f.isSkipped).length;
  int get skippedCount => feedback.where((f) => f.isSkipped).length;
  int get totalCount => feedback.length;
}
