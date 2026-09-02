import '../models/daily_test_question.dart';

/// Case/whitespace/punctuation-insensitive form of an answer for comparison
/// purposes — collapses runs of internal whitespace to a single space,
/// trims, lowercases, and drops a single trailing sentence-ending mark
/// (`.`/`!`/`?`) so "He goes." and "he goes" match but internal punctuation
/// (which can be part of the actual answer, e.g. a contraction) is left
/// alone.
String normalizeAnswer(String raw) {
  final collapsed = raw.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  return collapsed.replaceFirst(RegExp(r'[.!?]$'), '');
}

/// How a checked Daily Test answer matched, from most to least specific.
enum AnswerMatchKind {
  /// Matched the question's correct answer.
  correct,

  /// Matched one of the question's predicted [CommonWrongAnswer]s — show
  /// that answer's own canned comment.
  commonWrong,

  /// Matched neither — a real free-text answer the generation step didn't
  /// predict. Callers show a generic "not quite" message alongside
  /// [correctAnswer]; no canned comment applies.
  fallback,
}

class AnswerMatchResult {
  final AnswerMatchKind kind;
  final String correctAnswer;

  /// Only set when [kind] is [AnswerMatchKind.commonWrong] — the matched
  /// wrong answer's pre-written comment.
  final String? comment;

  const AnswerMatchResult({
    required this.kind,
    required this.correctAnswer,
    this.comment,
  });
}

/// Deterministic Daily Test grading (PRD v2 §12.5) — no LLM call. Checks
/// [userAnswer] against [question]'s correct answer, then each predicted
/// common wrong answer, normalizing both sides the same way so surface
/// differences (case, extra spaces, a trailing period) don't cause a false
/// mismatch.
AnswerMatchResult checkDailyTestAnswer(
  DailyTestQuestion question,
  String userAnswer,
) {
  final normalizedUser = normalizeAnswer(userAnswer);

  if (normalizedUser == normalizeAnswer(question.correctAnswer)) {
    return AnswerMatchResult(
      kind: AnswerMatchKind.correct,
      correctAnswer: question.correctAnswer,
    );
  }

  for (final wrong in question.commonWrongAnswers) {
    if (normalizedUser == normalizeAnswer(wrong.answer)) {
      return AnswerMatchResult(
        kind: AnswerMatchKind.commonWrong,
        correctAnswer: question.correctAnswer,
        comment: wrong.comment,
      );
    }
  }

  return AnswerMatchResult(
    kind: AnswerMatchKind.fallback,
    correctAnswer: question.correctAnswer,
  );
}
