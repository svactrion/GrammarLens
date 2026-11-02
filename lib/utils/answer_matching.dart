import '../models/daily_test_question.dart';

/// Case/whitespace/punctuation-insensitive form of an answer for comparison
/// purposes — collapses runs of internal whitespace to a single space,
/// trims, lowercases, and drops a single trailing sentence-ending mark
/// (`.`/`!`/`?`) so "He goes." and "he goes" match but internal punctuation
/// (which can be part of the actual answer, e.g. a contraction) is left
/// alone.
///
/// Curly quotes and apostrophes (’ ‘ “ ”) become their straight
/// counterparts first: a phone keyboard's smart punctuation types "isn’t"
/// where the answer key says "isn't", and that is the same answer, not a
/// mistake.
String normalizeAnswer(String raw) {
  final straightened = raw
      .replaceAll('\u2019', "'")
      .replaceAll('\u2018', "'")
      .replaceAll('\u201C', '"')
      .replaceAll('\u201D', '"');
  final collapsed =
      straightened.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  return collapsed.replaceFirst(RegExp(r'[.!?]$'), '');
}

/// Characters a learner's keyboard or autocorrect produces for a plain
/// character, mapped to that character (1.4.0 D3, owner 2026-10-31;
/// docs/1.4.0-server-batch0-report.md §2.2; client half in B3). A closed
/// table in eight classes, not fuzzy matching: every entry is a variant of
/// the same letter or mark, never a different word. Full-width ASCII and
/// the two Arabic digit rows are handled by range in [_foldRune].
///
/// The same table as the proxy's `KEYBOARD_VARIANT_FOLD`
/// (`proxy/src/shared_daily_test.ts`); `proxy/test/fixtures/keyboard_folding.json`
/// is the contract both sides are tested against
/// (`test/shared_grading_fixture_test.dart` here). Every key is plain ASCII
/// English (the proxy gate's `correct_answer_not_plain` rule), so a fold
/// only ever moves a learner's text towards a key, never between two
/// English answers.
///
/// Applied *after* [normalizeAnswer], which already lowercases (Dart's
/// `toLowerCase` collapses `İ` to plain `i`) and turns every Unicode space
/// (non-breaking, ideographic, the byte-order mark) into a plain one; the
/// space entries are kept anyway so the table matches the proxy's.
const Map<String, String> _keyboardVariantFold = {
  // Dotless i (tr): not a decomposition, so listed on its own.
  'ı': 'i',
  // Precomposed Latin letters with a diacritic (es, pt-BR, de, tr, and the
  // long-press pop-ups of every iOS keyboard).
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', //
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', //
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', //
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', //
  'ý': 'y', 'ÿ': 'y', 'ñ': 'n', 'ç': 'c', 'ş': 's', 'ğ': 'g', //
  'ß': 'ss', 'æ': 'ae', 'œ': 'oe',
  // Quotation marks and apostrophes [normalizeAnswer] does not straighten.
  '\u02BC': "'", '\u2032': "'", '\u00B4': "'", '`': "'", //
  '«': '"', '»': '"', '「': '"', '」': '"', '『': '"', '』': '"',
  // Dashes (hyphen, non-breaking hyphen, figure dash, en and em dash, bar).
  '\u2010': '-', '\u2011': '-', '\u2012': '-', '\u2013': '-', //
  '\u2014': '-', '\u2015': '-',
  // Arabic comma and question mark (ar); the ideographic full stop (ja).
  '\u060C': ',', '\u061F': '?', '\u3002': '.',
  // Spanish inverted marks (es): nothing to match them against.
  '¿': '', '¡': '',
  // Non-breaking and ideographic spaces (ja, ko, ar; iOS after a stop).
  '\u00A0': ' ', '\u3000': ' ',
  // Zero-width characters, direction marks and the byte-order mark.
  '\u200B': '', '\u200C': '', '\u200D': '', '\u200E': '', '\u200F': '', //
  '\uFEFF': '',
};

/// A full-width `.`, `!` or `?`, the ideographic full stop or the Arabic
/// question mark at the end: the full-width form of the one trailing mark
/// [normalizeAnswer] already drops.
final RegExp _trailingFullWidthMark =
    RegExp('[\u3002\uFF0E\uFF01\uFF1F\u061F]\$');

String _foldRune(int rune) {
  final char = String.fromCharCode(rune);
  final mapped = _keyboardVariantFold[char];
  if (mapped != null) return mapped;
  // Full-width ASCII (ja, ko): ！ … ～ → ! … ~.
  if (rune >= 0xFF01 && rune <= 0xFF5E) {
    return String.fromCharCode(rune - 0xFF01 + 0x21);
  }
  // Arabic-Indic and Eastern Arabic-Indic digits (ar).
  if (rune >= 0x0660 && rune <= 0x0669) {
    return String.fromCharCode(rune - 0x0660 + 0x30);
  }
  if (rune >= 0x06F0 && rune <= 0x06F9) {
    return String.fromCharCode(rune - 0x06F0 + 0x30);
  }
  return char;
}

/// The keyboard-variant fold, the same rule as the proxy's: every variant
/// character mapped ([_keyboardVariantFold], [_foldRune]), runs of spaces a
/// mapping may have doubled collapsed, the ends trimmed, and the one
/// trailing mark dropped when it was full-width (and so survived
/// [normalizeAnswer]). Code points, not UTF-16 units, are folded. The
/// result can be shorter or longer than the input (`ß`, removed marks).
String foldKeyboardVariants(String input) {
  final mapped =
      input.runes.map(_foldRune).join().replaceAll(RegExp(' {2,}'), ' ').trim();
  return _trailingFullWidthMark.hasMatch(input)
      ? mapped.replaceFirst(RegExp(r'[.!?]$'), '')
      : mapped;
}

/// Characters with no visible form of their own (zero-width and direction
/// marks, the byte-order mark, the special spaces), named as such in the
/// note rather than quoted.
bool _isInvisible(String char) {
  final rune = char.runes.first;
  return (rune >= 0x200B && rune <= 0x200F) ||
      rune == 0xFEFF ||
      rune == 0x00A0 ||
      rune == 0x3000;
}

/// How many character pairs the note names before it shortens to "…".
const int _noteMaxPairs = 3;

/// The short, non-accusatory note shown when an answer differs from the
/// correct one only by [foldKeyboardVariants]: it names the characters of
/// the learner's [normalizedUser] whose fold differs from themselves, in
/// order, each once, with what they fold to, so a learner still notices
/// their keyboard typed something different, just not something wrong.
///
/// The fold can change length (`ß`, removed marks), so characters are not
/// paired by position (1.4.0 B3; report §5.2). Two clauses: one for
/// characters typed in another form, one for characters the keyboard added
/// (Spanish inverted marks, invisible marks). When the learner's answer
/// has no such character (only a non-plain key could cause that, and keys
/// are plain), a general sentence.
String _keyboardVariantNote(String normalizedUser) {
  final typed = <String, String>{};
  final added = <String>[];
  var invisible = false;
  for (final rune in normalizedUser.runes) {
    final char = String.fromCharCode(rune);
    final folded = _foldRune(rune);
    if (folded == char) continue;
    if (folded.trim().isEmpty) {
      if (_isInvisible(char)) {
        invisible = true;
      } else if (!added.contains(char)) {
        added.add(char);
      }
    } else {
      typed.putIfAbsent(char, () => folded);
    }
  }
  String quoted(Iterable<String> chars) {
    final list = chars.toList();
    final shown = list.take(_noteMaxPairs).map((c) => '"$c"').join(', ');
    return list.length > _noteMaxPairs ? '$shown …' : shown;
  }

  final addedParts = [
    if (added.isNotEmpty) quoted(added),
    if (invisible) 'an invisible character',
  ];
  final addedClause = addedParts.isEmpty
      ? null
      : 'Your keyboard added ${addedParts.join(' and ')}';
  if (typed.isEmpty && addedClause == null) {
    return 'Your answer matches apart from keyboard characters. Not a '
        'grammar mistake.';
  }
  if (typed.isEmpty) return '$addedClause — not a grammar mistake.';
  final versions = typed.length == 1 ? 'version' : 'versions';
  final typedClause = 'You typed ${quoted(typed.keys)} — your keyboard\'s '
      '$versions of ${quoted(typed.values)}.';
  if (addedClause == null) return '$typedClause Not a grammar mistake.';
  return '$typedClause $addedClause — not a grammar mistake.';
}

/// How a checked Daily Test answer matched, from most to least specific.
enum AnswerMatchKind {
  /// Matched the question's correct answer exactly.
  correct,

  /// Matched the correct answer once keyboard variants
  /// ([foldKeyboardVariants]: full-width letters, accented letters, dotless
  /// ı, look-alike quotes and dashes, Arabic digits, inverted marks,
  /// invisible marks) are folded to the plain character —
  /// substantively correct, kept as its own kind (rather than merged into
  /// [correct]) only so callers can show [AnswerMatchResult.comment] as a
  /// short explanatory note instead of silently passing over the
  /// difference. Never written to the error profile, never shown as
  /// "Needs work" — this is not a grammar mistake.
  keyboardVariant,

  /// Matched one of the question's [DailyTestQuestion.acceptedAnswers] — an
  /// alternative the shared set's check marked as also right — exactly or
  /// once keyboard variants are folded. Counts as correct; callers show the
  /// key alongside it ([AnswerMatchResult.acceptedAnswer] is the alternative
  /// that matched). Only reachable when a set carries alternatives: no shared
  /// set does before the proxy's check call (docs/1.1.0-shared-daily-test-quality.md
  /// §8, §16.4); fallback pool questions can, from the owner's corrections
  /// (roadmap P13).
  accepted,

  /// Matched one of the question's predicted [CommonWrongAnswer]s — show
  /// that answer's own canned comment.
  commonWrong,

  /// Matched neither — a real free-text answer the generation step didn't
  /// predict. Callers show a generic "not quite" message alongside
  /// [correctAnswer]; no canned comment applies.
  fallback;

  /// Whether this kind counts as a correct answer: never "Needs work", never
  /// written to the error profile, counted in the score.
  bool get isCorrect =>
      this == correct || this == keyboardVariant || this == accepted;
}

class AnswerMatchResult {
  final AnswerMatchKind kind;
  final String correctAnswer;

  /// Set when [kind] is [AnswerMatchKind.commonWrong] (the matched wrong
  /// answer's pre-written comment) or [AnswerMatchKind.keyboardVariant]
  /// (the short note naming which keyboard characters differed). Null for
  /// [AnswerMatchKind.correct] and [AnswerMatchKind.fallback].
  final String? comment;

  /// The alternative from [DailyTestQuestion.acceptedAnswers] that matched;
  /// set only when [kind] is [AnswerMatchKind.accepted].
  final String? acceptedAnswer;

  const AnswerMatchResult({
    required this.kind,
    required this.correctAnswer,
    this.comment,
    this.acceptedAnswer,
  });
}

/// Deterministic Daily Test grading (PRD v2 §12.5) — no LLM call. Checks
/// [userAnswer] against [question]'s correct answer, then its accepted
/// alternatives, then each predicted common wrong answer, normalizing both
/// sides the same way so surface differences (case, extra spaces, a trailing
/// period) don't cause a false mismatch.
///
/// The order is a contract shared with the proxy
/// (`proxy/test/fixtures/daily_test_grading.json`, docs/1.1.0-shared-daily-test-quality.md
/// §8.2): correct → keyboard variant of correct → accepted (exact, then
/// keyboard variant) → predicted wrong (exact) → fallback. A question without
/// [DailyTestQuestion.acceptedAnswers] grades exactly as before the field
/// existed.
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
      comment: _keyboardVariantNote(normalizedUser),
    );
  }

  final foldedUser = foldKeyboardVariants(normalizedUser);
  for (final folded in [false, true]) {
    for (final alternative in question.acceptedAnswers) {
      final normalizedAlternative = normalizeAnswer(alternative);
      final matches = folded
          ? foldedUser == foldKeyboardVariants(normalizedAlternative)
          : normalizedUser == normalizedAlternative;
      if (matches) {
        return AnswerMatchResult(
          kind: AnswerMatchKind.accepted,
          correctAnswer: question.correctAnswer,
          acceptedAnswer: alternative,
        );
      }
    }
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
      if (checkDailyTestAnswer(question, raw).kind.isCorrect) correct++;
    }
  }
  return (correct: correct, total: questions.length, skipped: skipped);
}
