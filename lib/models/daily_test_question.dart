import 'practice_item.dart';

/// One pre-written wrong answer the model predicted a learner might give,
/// paired with a canned explanation of why it's tempting and why it's
/// wrong — generated once alongside the question (PRD v2 §12.5), not
/// computed at check time. Lets a free-text answer get feedback that reads
/// as personalized without an LLM call or a multiple-choice UI (§2.2 Theme
/// 1 — MC was conclusively rejected in user research).
class CommonWrongAnswer {
  final String answer;
  final String comment;

  const CommonWrongAnswer({required this.answer, required this.comment});

  factory CommonWrongAnswer.fromJson(Map<String, dynamic> json) =>
      CommonWrongAnswer(
        answer: json['answer'] as String,
        comment: json['comment'] as String,
      );

  Map<String, dynamic> toJson() => {'answer': answer, 'comment': comment};
}

/// One Daily Test question: an existing [PracticeItem] (fill-in-the-blank
/// or error-correction only — Daily Test is checked deterministically, and
/// only those two types have a single canonical correct answer;
/// sentence_writing doesn't) plus the answer key and predicted-wrong-answer
/// comments needed to grade it locally, with no LLM call.
class DailyTestQuestion {
  final PracticeItem item;

  /// [TopicId.name] of the grammar category this question targets — drives
  /// weak-spot-biased generation and could tag a wrong answer back into the
  /// error profile later. A plain string, matching how topic ids are
  /// already stored everywhere else (`ErrorEntry.topicId`,
  /// `PracticeSet.topicId`), not the enum itself.
  final String topicId;

  final String correctAnswer;

  /// 2-3 predicted common wrong answers, each with its own canned comment.
  final List<CommonWrongAnswer> commonWrongAnswers;

  DailyTestQuestion({
    required this.item,
    required this.topicId,
    required this.correctAnswer,
    required this.commonWrongAnswers,
  }) : assert(
          item.type == PracticeItemType.fillInBlank ||
              item.type == PracticeItemType.errorCorrection,
          'Daily Test only supports fill-in-the-blank and error-correction '
          '— those are the only types with a single deterministic correct '
          'answer to check against.',
        );

  factory DailyTestQuestion.fromJson(Map<String, dynamic> json) =>
      DailyTestQuestion(
        item: PracticeItem.fromJson(json['item'] as Map<String, dynamic>),
        topicId: json['topicId'] as String,
        correctAnswer: json['correctAnswer'] as String,
        commonWrongAnswers: (json['commonWrongAnswers'] as List)
            .map((e) =>
                CommonWrongAnswer.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'item': item.toJson(),
        'topicId': topicId,
        'correctAnswer': correctAnswer,
        'commonWrongAnswers':
            commonWrongAnswers.map((c) => c.toJson()).toList(),
      };
}
