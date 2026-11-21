import '../models/daily_test_completion.dart';
import '../models/daily_test_question.dart';
import '../utils/answer_matching.dart';
import '../utils/blank_assembly.dart';
import '../utils/blanks.dart';
import 'monthly_medal_rules.dart';

/// One question's "Check" in the Daily Test (SPEC §1.5): graded on the
/// device against the set's own answer key — the same rules the completion
/// uses ([DailyTestAnswerResult.from]: `checkDailyTestAnswer`, accepted
/// answers, keyboard variants), with no request and no wait.
///
/// The points it shows are display-only and equal what the completion
/// awards for the same answer ([MonthlyMedalRules]: +2 correct, +1 wrong,
/// 0 skipped); when and how points are stored does not change.
class QuestionCheck {
  final DailyTestAnswerResult result;

  /// Per blank of a multi-blank question: whether that blank matches the
  /// key's word(s) there (Q04's per-blank colours), or null when the
  /// question has one blank or the key cannot be split by blank.
  final List<bool>? blanks;

  const QuestionCheck._(this.result, this.blanks);

  /// Grades [answer] (the assembled answer the screen keeps) for
  /// [question]; [blankAnswers] are the multi-blank boxes, in order.
  factory QuestionCheck.of(DailyTestQuestion question, String answer,
      {List<BlankAnswer>? blankAnswers}) {
    final result = DailyTestAnswerResult.from(question, answer);
    List<bool>? blanks;
    if (blankAnswers != null && blankAnswers.length > 1) {
      blanks = blankResults(question, blankAnswers, overall: result.isCorrect);
    }
    return QuestionCheck._(result, blanks);
  }

  bool get isCorrect => result.isCorrect;
  bool get isSkipped => result.isSkipped;

  /// The points this answer shows now (and earns at the completion).
  int get points => pointsFor(result);

  /// The set's own explanation, or null (then only the correct answer is
  /// shown, V08).
  String? get explanation {
    final e = result.question.explanation?.trim();
    if (e != null && e.isNotEmpty) return e;
    final comment = result.match?.comment?.trim();
    return comment == null || comment.isEmpty ? null : comment;
  }

  String get correctAnswer => result.question.correctAnswer;

  /// The points of one graded answer, by the completion's own rule.
  static int pointsFor(DailyTestAnswerResult r) {
    if (r.isSkipped) return 0;
    return MonthlyMedalRules.score(
        correct: r.isCorrect ? 1 : 0, wrong: r.isCorrect ? 0 : 1);
  }

  /// The points shown after these checks: the same sum the completion's
  /// score gives.
  static int displayTotal(Iterable<QuestionCheck> checks) =>
      checks.fold(0, (sum, c) => sum + c.points);

  /// Each blank's result: the key's sentence is split at the template's
  /// fixed text to find the word(s) each blank expects; a blank is right
  /// when the learner's box matches them (case and spacing as
  /// [normalizeAnswer]; "no article" matches an empty spot). When the key
  /// cannot be split, every blank takes the question's own result.
  static List<bool> blankResults(
      DailyTestQuestion question, List<BlankAnswer> answers,
      {required bool overall}) {
    final expected = expectedBlanks(question);
    if (expected == null || expected.length != answers.length) {
      return List.filled(answers.length, overall);
    }
    return [
      for (var i = 0; i < answers.length; i++)
        answers[i].noArticle
            ? expected[i].trim().isEmpty
            : normalizeAnswer(answers[i].text) == normalizeAnswer(expected[i]),
    ];
  }

  /// The key's word(s) at each blank, or null when the key does not follow
  /// the template.
  static List<String>? expectedBlanks(DailyTestQuestion question) {
    final template = blankSourceText(question.item);
    final parts = template.split(blankPattern);
    if (parts.length < 3) return null;
    final key = question.correctAnswer;
    final lowerKey = key.toLowerCase();
    var at = 0;
    final first = parts.first.trim().toLowerCase();
    if (first.isNotEmpty) {
      final i = lowerKey.indexOf(first);
      if (i < 0) return null;
      at = i + first.length;
    }
    final out = <String>[];
    for (var p = 1; p < parts.length; p++) {
      final fixed = parts[p].trim().toLowerCase();
      if (fixed.isEmpty) {
        // The last blank runs to the end of the key.
        if (p != parts.length - 1) return null;
        out.add(_clean(key.substring(at)));
        at = key.length;
        continue;
      }
      final next = lowerKey.indexOf(fixed, at);
      if (next < 0) return null;
      out.add(_clean(key.substring(at, next)));
      at = next + fixed.length;
    }
    return out;
  }

  static String _clean(String s) =>
      s.trim().replaceAll(RegExp(r'^[\s,.;:!?]+|[\s,.;:!?]+$'), '');
}
