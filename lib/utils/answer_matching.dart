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

/// Maps each Latin letter a Turkish keyboard types as a visually distinct
/// character — dotless ı, dotted İ, ş, ğ, ç, ö, ü — to the plain-ASCII
/// letter it's a variant of. None of these are ever a grammatical
/// distinction in English ("cookıng" and "cooking" are the same word), so
/// folding them lets an exact-match comparison treat the two as identical
/// instead of a spelling mismatch.
///
/// Applied *after* [normalizeAnswer], which already lowercases — Dart's own
/// `String.toLowerCase()` already collapses İ/I to plain `i` (verified: it
/// does not produce the two-codepoint "i + combining dot" some other
/// runtimes give Turkish `İ`), so this table only needs the already-lower
/// Turkish letters that survive that step.
///
/// Deliberately a small, fixed, closed set — NOT a general edit-distance or
/// fuzzy match. A real one-character grammar difference ("stay" vs.
/// "stays") must still count as wrong; only these specific keyboard-layout
/// substitutions fold, nothing else.
const Map<String, String> _keyboardVariantFold = {
  'ı': 'i',
  'ş': 's',
  'ğ': 'g',
  'ç': 'c',
  'ö': 'o',
  'ü': 'u',
};

/// Folds the Turkish-keyboard letter variants in [_keyboardVariantFold],
/// leaving every other character untouched. See that table's doc comment
/// for why this specific, closed set and nothing broader.
String foldKeyboardVariants(String input) =>
    input.split('').map((ch) => _keyboardVariantFold[ch] ?? ch).join();

/// Builds the short, non-accusatory note shown when an answer only differs
/// from the correct one by [foldKeyboardVariants]-equivalent letters —
/// naming the specific letter(s) involved rather than a generic "close
/// enough" message, since a learner should still notice their keyboard
/// typed something different, just not something wrong. [normalizedUser]
/// and [normalizedCorrect] must already be equal length (guaranteed by the
/// fold-equality check that calls this — folding never changes length).
String _keyboardVariantNote(String normalizedUser, String normalizedCorrect) {
  final userChars = normalizedUser.split('');
  final correctChars = normalizedCorrect.split('');
  final pairs = <String, String>{};
  for (var i = 0; i < userChars.length; i++) {
    if (userChars[i] != correctChars[i]) {
      pairs[userChars[i]] = correctChars[i];
    }
  }
  final plural = pairs.length > 1;
  final typed = pairs.keys.join('", "');
  final same = pairs.values.join('", "');
  return 'You typed "$typed" — that\'s the same letter${plural ? 's' : ''} '
      'as "$same" here, just a different keyboard character. Not a '
      'grammar mistake.';
}

/// How a checked Daily Test answer matched, from most to least specific.
enum AnswerMatchKind {
  /// Matched the question's correct answer exactly.
  correct,

  /// Matched the correct answer once Turkish-keyboard letter variants
  /// (ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u) are folded to the same letter —
  /// substantively correct, kept as its own kind (rather than merged into
  /// [correct]) only so callers can show [AnswerMatchResult.comment] as a
  /// short explanatory note instead of silently passing over the
  /// difference. Never written to the error profile, never shown as
  /// "Needs work" — this is not a grammar mistake.
  keyboardVariant,

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

  /// Set when [kind] is [AnswerMatchKind.commonWrong] (the matched wrong
  /// answer's pre-written comment) or [AnswerMatchKind.keyboardVariant]
  /// (the short note naming which keyboard characters differed). Null for
  /// [AnswerMatchKind.correct] and [AnswerMatchKind.fallback].
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
  final normalizedCorrect = normalizeAnswer(question.correctAnswer);

  if (normalizedUser == normalizedCorrect) {
    return AnswerMatchResult(
      kind: AnswerMatchKind.correct,
      correctAnswer: question.correctAnswer,
    );
  }

  // Checked against the correct answer specifically, before the predicted
  // wrong answers below: this is about the user's answer being
  // substantively right (just typed with different keyboard characters),
  // not about it happening to resemble a wrong prediction once folded.
  if (foldKeyboardVariants(normalizedUser) ==
      foldKeyboardVariants(normalizedCorrect)) {
    return AnswerMatchResult(
      kind: AnswerMatchKind.keyboardVariant,
      correctAnswer: question.correctAnswer,
      comment: _keyboardVariantNote(normalizedUser, normalizedCorrect),
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

/// Aggregate score only (no per-question detail) — for a summary line
/// (Home's "today" card, PRD v2 §13.5) that doesn't need the full
/// per-item breakdown `DailyTestResultScreen` builds for itself. Same
/// empty-answer-is-skipped, not-scored rule as everywhere else Daily Test
/// answers are graded.
({int correct, int total, int skipped}) computeDailyTestScore(
  List<DailyTestQuestion> questions,
  Map<String, String> answers,
) {
  var correct = 0;
  var skipped = 0;
  for (final question in questions) {
    final raw = (answers[question.item.id] ?? '').trim();
    if (raw.isEmpty) {
      skipped++;
    } else {
      final kind = checkDailyTestAnswer(question, raw).kind;
      if (kind == AnswerMatchKind.correct ||
          kind == AnswerMatchKind.keyboardVariant) {
        correct++;
      }
    }
  }
  return (correct: correct, total: questions.length, skipped: skipped);
}
