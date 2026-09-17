import 'daily_test_question.dart';
import 'daily_test_set.dart';
import 'error_entry.dart';
import '../utils/answer_matching.dart';

/// Immutable local evaluation shared by display and the atomic persistence path.
/// Rule v1: any non-blank answer earns one step; correctness affects raw counts
/// only. Medal weights and thresholds remain a separate product decision.
class DailyTestCompletion {
  static const ruleVersion = 1;
  final DailyTestSet set;
  final Map<String, String> answers;
  final DateTime completedAt;
  final List<DailyTestAnswerResult> results;

  DailyTestCompletion(
      {required this.set,
      required Map<String, String> answers,
      required this.completedAt})
      : answers = Map.unmodifiable(answers),
        results = List.unmodifiable([
          for (final question in set.questions)
            DailyTestAnswerResult.from(question, answers[question.item.id]),
        ]);

  int get correct => results.where((r) => r.isCorrect).length;
  int get skipped => results.where((r) => r.isSkipped).length;
  int get wrong => results.length - correct - skipped;
  int get step => results.any((r) => !r.isSkipped) ? 1 : 0;

  List<ErrorEntry> get errors => results
      .where((r) => !r.isSkipped && !r.isCorrect)
      .map((r) => ErrorEntry(
            topicId: r.question.topicId,
            errorType: r.question.topicId,
            timestamp: completedAt,
            prompt: r.question.item.fullText,
            userAnswer: r.userAnswer,
            correctedAnswer: r.question.correctAnswer,
            explanation: r.match?.comment,
            source: ErrorSource.dailyTest,
          ))
      .toList();
}

/// One question's outcome — [isSkipped] takes priority over matching (an
/// empty answer is never run through [checkDailyTestAnswer], mirroring how
/// ClaudeService.scoreAnswers keeps "skipped" a locally-detected fact
/// rather than something scored) — [match] is only set otherwise.
class DailyTestAnswerResult {
  final DailyTestQuestion question;
  final String? userAnswer;
  final bool isSkipped;
  final AnswerMatchResult? match;

  const DailyTestAnswerResult._({
    required this.question,
    required this.userAnswer,
    required this.isSkipped,
    this.match,
  });

  factory DailyTestAnswerResult.from(
      DailyTestQuestion question, String? rawAnswer) {
    final trimmed = (rawAnswer ?? '').trim();
    if (trimmed.isEmpty) {
      return DailyTestAnswerResult._(
        question: question,
        userAnswer: rawAnswer,
        isSkipped: true,
      );
    }
    return DailyTestAnswerResult._(
      question: question,
      userAnswer: rawAnswer,
      isSkipped: false,
      match: checkDailyTestAnswer(question, rawAnswer!),
    );
  }

  /// True for an exact match and for [AnswerMatchKind.keyboardVariant] —
  /// a Turkish-keyboard letter substitution is not a grammar mistake, so
  /// it counts as correct: never "Needs work", never written to the error
  /// profile (see the result screen and completion snapshot below).
  bool get isCorrect =>
      match?.kind == AnswerMatchKind.correct ||
      match?.kind == AnswerMatchKind.keyboardVariant;

  bool get isKeyboardVariant => match?.kind == AnswerMatchKind.keyboardVariant;
}
