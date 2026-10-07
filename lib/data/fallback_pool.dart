import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/daily_test_question.dart';
import '../models/practice_item.dart';
import '../models/topic.dart';
import '../utils/answer_matching.dart';
import 'day_zero_daily_test.dart';

/// The Daily Test's fallback: what a day gets when its shared set cannot be
/// read (docs/1.1.0-shared-daily-test.md §5). A pool of sets that ships inside
/// the app as an asset ([assetPath]), chosen by date, with the fixed first-day
/// questions ([kDayZeroQuestions]) as the last resort, so the Daily Test is
/// never empty.
///
/// The pool's content is sets the live cron published (prompt v2, generator
/// `claude-sonnet-5-5` at `low` effort, passed the proxy's gate), exported
/// from KV, reviewed and corrected by the owner (other accepted answers, a
/// predicted wrong answer or a hint removed; roadmap P13):
/// `scripts/fallback_pool.sh` writes the asset. Until that happens the asset holds no sets and every fallback day
/// gets the day-0 questions.
class FallbackPool {
  static const String assetPath = 'assets/daily_test_fallback/pool.json';

  /// The asset's shape; a file with another version is not read.
  static const int formatVersion = 1;

  /// Questions in every set, the same as a shared set.
  static const int questionCount = 5;

  final AssetBundle _bundle;
  Future<List<List<DailyTestQuestion>>>? _sets;

  FallbackPool({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  /// A pool that already holds [sets] (tests, and any caller that loaded
  /// them some other way); the asset is never read.
  FallbackPool.withSets(List<List<DailyTestQuestion>> sets)
      : _bundle = rootBundle,
        _sets = Future.value(sets);

  /// The usable sets in the asset, loaded once. A missing or unreadable
  /// asset, or one of another [formatVersion], is an empty pool; a set that
  /// fails [problemWithSet] is left out and the rest are kept.
  Future<List<List<DailyTestQuestion>>> sets() => _sets ??= _load();

  Future<List<List<DailyTestQuestion>>> _load() async {
    try {
      return parse(await _bundle.loadString(assetPath, cache: false));
    } catch (_) {
      return const [];
    }
  }

  /// The fallback questions for [day] (`YYYY-MM-DD`): the pool set
  /// [indexFor] picks, or [kDayZeroQuestions] when the pool is empty. Never
  /// throws.
  Future<List<DailyTestQuestion>> questionsFor(String day) async {
    final pool = await sets();
    final index = indexFor(day, pool.length);
    return index == null ? kDayZeroQuestions : pool[index];
  }

  /// Which of [count] pool sets [day] gets: a rotation over the calendar, so
  /// the same day always gets the same set and consecutive days get different
  /// ones (with 7 sets, one per weekday). Depends on [day] alone, never on a
  /// set's own origin date. Null for an empty pool or a malformed day.
  static int? indexFor(String day, int count) {
    if (count <= 0) return null;
    final dayNumber = _dayNumber(day);
    if (dayNumber == null) return null;
    return dayNumber % count;
  }

  /// Days since 1970-01-01 for a `YYYY-MM-DD` calendar date, or null.
  static int? _dayNumber(String day) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(day);
    if (match == null) return null;
    final y = int.parse(match[1]!), m = int.parse(match[2]!);
    final d = int.parse(match[3]!);
    final date = DateTime.utc(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return null;
    return date.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
  }

  /// Reads the asset's JSON: `{"formatVersion": 1, "sets": [{"questions":
  /// [...]}]}`, each question in the shape [DailyTestQuestion.fromJson]
  /// reads. Throws [FormatException] for a file that is not that shape at
  /// all; a single bad set is only left out.
  static List<List<DailyTestQuestion>> parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic> ||
        json['formatVersion'] != formatVersion ||
        json['sets'] is! List) {
      throw const FormatException('not a fallback pool');
    }
    final sets = <List<DailyTestQuestion>>[];
    for (final entry in json['sets'] as List) {
      final questions = _readSet(entry);
      if (questions != null && problemWithSet(questions) == null) {
        sets.add(questions);
      }
    }
    return sets;
  }

  static List<DailyTestQuestion>? _readSet(Object? entry) {
    try {
      final questions = (entry as Map<String, dynamic>)['questions'] as List;
      return questions
          .map((q) => DailyTestQuestion.fromJson(q as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Why [questions] cannot be a Daily Test the app grades correctly, or null
  /// when it can. The content rules of the proxy's gate
  /// (`validateSharedSet` in `proxy/src/shared_daily_test.ts`) that the app
  /// itself depends on, applied again at load time; the export script runs
  /// the proxy's own function before a set ever reaches the asset.
  static String? problemWithSet(List<DailyTestQuestion> questions) {
    if (questions.length != questionCount) return 'wrong_question_count';
    final ids = questions.map((q) => q.item.id).toSet();
    if (ids.length != questions.length) return 'duplicate_id';
    final topics = TopicId.values.map((t) => t.name).toSet();
    if (!topics.containsAll(questions.map((q) => q.topicId)) ||
        questions.map((q) => q.topicId).toSet().length != questions.length) {
      return 'topic_mismatch';
    }
    for (final q in questions) {
      final problem = problemWithQuestion(q);
      if (problem != null) return problem;
    }
    return null;
  }

  /// See [problemWithSet]; the codes are the proxy gate's where one applies.
  static String? problemWithQuestion(DailyTestQuestion q) {
    final item = q.item;
    if (item.instruction.trim().isEmpty) return 'missing_field';
    if (q.explanation == null) return 'missing_field';
    switch (item.type) {
      case PracticeItemType.fillInBlank:
        final blanks = blankCount(item.context, item.instruction);
        if (blanks == 0) return 'fill_in_blank_missing_blank';
        if (blanks > 1) return 'fill_in_blank_multiple_blanks';
      case PracticeItemType.errorCorrection:
        if (!hasSentenceToCorrect(item.context)) {
          return 'error_correction_missing_sentence';
        }
        if (normalizeAnswer(item.context!) ==
            normalizeAnswer(q.correctAnswer)) {
          return 'unchanged_error_correction';
        }
      case PracticeItemType.sentenceWriting:
        return 'plan_mismatch';
    }
    if (normalizeAnswer(q.correctAnswer).isEmpty) {
      return 'blank_correct_answer';
    }
    if (q.commonWrongAnswers.length < 2 || q.commonWrongAnswers.length > 3) {
      return 'wrong_answer_count';
    }
    // Read the way a learner's answer is graded: the key must be correct and
    // every predicted wrong answer must reach its own comment.
    if (checkDailyTestAnswer(q, q.correctAnswer).kind !=
        AnswerMatchKind.correct) {
      return 'blank_correct_answer';
    }
    final seen = <String>{};
    for (final wrong in q.commonWrongAnswers) {
      if (wrong.comment.trim().isEmpty) return 'missing_field';
      final result = checkDailyTestAnswer(q, wrong.answer);
      if (result.kind != AnswerMatchKind.commonWrong) {
        return 'wrong_answer_matches_correct';
      }
      if (!seen.add(normalizeAnswer(wrong.answer))) {
        return 'duplicate_wrong_answer';
      }
    }
    return null;
  }

  /// Blanks a `fill_in_blank` question shows: runs of two or more
  /// underscores in [context] and [instruction] (not the hint). The proxy's
  /// `blankCount`; exactly one is required.
  static int blankCount(String? context, String instruction) =>
      RegExp(r'_{2,}').allMatches('${context ?? ''}\n$instruction').length;

  /// Whether an `error_correction` [context] holds a sentence to correct: at
  /// least three words with a letter. The proxy's `hasSentenceToCorrect`.
  static bool hasSentenceToCorrect(String? context) =>
      context != null &&
      context
              .trim()
              .split(RegExp(r'\s+'))
              .where((w) => RegExp(r'\p{L}', unicode: true).hasMatch(w))
              .length >=
          3;
}
