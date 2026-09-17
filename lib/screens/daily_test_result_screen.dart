import 'package:flutter/material.dart';

import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import '../services/daily_test_service.dart';
import '../theme.dart';
import '../utils/answer_matching.dart';
import '../utils/app_messenger.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/mistake_breakdown.dart';
import '../widgets/result_score_band.dart';

/// Shown after the last Daily Test question. Grading is entirely local —
/// [checkDailyTestAnswer] against the answer key the data layer generated
/// up front — there's no live evaluation call the way Topic Practice's
/// ResultsScreen has one. Visually mirrors that screen (same summary line,
/// same per-item `SemanticColors` card treatment, same [MistakeBreakdown]
/// layout) so this reads as the same app, not a bolted-on separate flow.
class DailyTestResultScreen extends StatefulWidget {
  final DailyTestSet dailyTestSet;
  final Map<String, String> answers;
  final DailyTestService dailyTestService;

  /// Extension point for the next batch: a call-to-action (the trial/
  /// paywall pitch) rendered below the per-question breakdown. Deliberately
  /// not a hardcoded "Back to Home" button — leaving this null renders
  /// nothing here rather than assuming what that ending should be.
  final WidgetBuilder? bottomBuilder;

  const DailyTestResultScreen({
    super.key,
    required this.dailyTestSet,
    required this.answers,
    required this.dailyTestService,
    this.bottomBuilder,
  });

  @override
  State<DailyTestResultScreen> createState() => _DailyTestResultScreenState();
}

class _DailyTestResultScreenState extends State<DailyTestResultScreen> {
  late final List<_QuestionResult> _results;

  @override
  void initState() {
    super.initState();
    _results = [
      for (final question in widget.dailyTestSet.questions)
        _QuestionResult.from(question, widget.answers[question.item.id]),
    ];
    _completeDailyTest();
  }

  /// Marks today's set completed and records this session's wrong answers
  /// together, in the one atomic `DailyTestService.completeDailyTest` write
  /// (`StorageService.completeDailyTest`'s doc comment has the full
  /// reasoning): either both land or neither does, so a failure here can
  /// never leave a completed day with its mistakes silently lost, or a
  /// still-not-completed day whose mistakes get logged twice on retake.
  ///
  /// Guarded by `isCompleted` — a re-view of an already-completed set
  /// (e.g. Home's "view result again") must not re-log the same mistakes a
  /// second time and inflate their frequency, nor re-run the completion
  /// write at all.
  Future<void> _completeDailyTest() async {
    if (widget.dailyTestSet.isCompleted) return;
    try {
      await widget.dailyTestService.completeDailyTest(
        widget.answers,
        _errorEntries(),
      );
    } catch (e) {
      // Unlike ResultsScreen's best-effort completion write, a failure here
      // means NEITHER half of the write landed (the transaction rolled
      // back) — the day is still genuinely not completed, so this is a
      // real, actionable failure, not a background stat falling a session
      // behind. Surfaced via the same AppMessenger toast this screen
      // already uses for a save failure elsewhere; there is no dedicated
      // retry affordance on this screen to show instead.
      if (!mounted) return;
      AppMessenger.show('Could not save your Daily Test results: $e');
    }
  }

  /// Wrong (never skipped, never a [AnswerMatchKind.keyboardVariant] match —
  /// see [_QuestionResult.isCorrect]) answers, in the shape fed into the
  /// same error profile Topic Practice's ResultsScreen writes to —
  /// 2026-09-05 decision: the free tier diagnoses via Daily Test, the paid
  /// tier treats via Topic Practice (see docs/build-log.md). A
  /// Turkish-keyboard letter substitution is real content the user got
  /// right, not a grammar weak spot — writing it here would corrupt the
  /// exact data this profile exists to be honest about (docs/build-log.md,
  /// 2026-09-07). [ErrorEntry.explanation] is only ever
  /// [AnswerMatchResult.comment] — genuinely null when the wrong answer
  /// didn't match a predicted common mistake, never the screen's own
  /// generic "Not quite" display fallback and never an invented one: Daily
  /// Test has no LLM call to generate a real explanation from, so a
  /// thinner record is the honest one. [ErrorEntry.errorType] is the
  /// question's topicId — Daily Test has no finer per-mistake
  /// classification the way Topic Practice's LLM scoring does, so this is
  /// the coarsest-but-true category available, not a fabricated one.
  List<ErrorEntry> _errorEntries() {
    final now = DateTime.now();
    return _results
        .where((r) => !r.isSkipped && !r.isCorrect)
        .map((r) => ErrorEntry(
              topicId: r.question.topicId,
              errorType: r.question.topicId,
              timestamp: now,
              prompt: r.question.item.fullText,
              userAnswer: r.userAnswer,
              correctedAnswer: r.question.correctAnswer,
              explanation: r.match?.comment,
              source: ErrorSource.dailyTest,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;

    final correctCount = _results.where((r) => r.isCorrect).length;
    final skippedCount = _results.where((r) => r.isSkipped).length;
    final totalCount = _results.length;
    final scoreText = skippedCount > 0
        ? '$correctCount/$totalCount correct · $skippedCount skipped'
        : '$correctCount/$totalCount correct';

    return BrandScaffold(
      title: const PageTitle('Daily Test Results'),
      bandBottom: ResultScoreBand(text: scoreText),
      children: [
        for (final result in _results) ...[
          _QuestionResultCard(result: result, semantic: semantic),
          const SizedBox(height: 14),
        ],
        if (widget.bottomBuilder != null) ...[
          const SizedBox(height: 6),
          widget.bottomBuilder!(context),
        ],
      ],
    );
  }
}

/// One question's outcome — [isSkipped] takes priority over matching (an
/// empty answer is never run through [checkDailyTestAnswer], mirroring how
/// ClaudeService.scoreAnswers keeps "skipped" a locally-detected fact
/// rather than something scored) — [match] is only set otherwise.
class _QuestionResult {
  final DailyTestQuestion question;
  final String? userAnswer;
  final bool isSkipped;
  final AnswerMatchResult? match;

  const _QuestionResult._({
    required this.question,
    required this.userAnswer,
    required this.isSkipped,
    this.match,
  });

  factory _QuestionResult.from(DailyTestQuestion question, String? rawAnswer) {
    final trimmed = (rawAnswer ?? '').trim();
    if (trimmed.isEmpty) {
      return _QuestionResult._(
        question: question,
        userAnswer: rawAnswer,
        isSkipped: true,
      );
    }
    return _QuestionResult._(
      question: question,
      userAnswer: rawAnswer,
      isSkipped: false,
      match: checkDailyTestAnswer(question, rawAnswer!),
    );
  }

  /// True for an exact match and for [AnswerMatchKind.keyboardVariant] —
  /// a Turkish-keyboard letter substitution is not a grammar mistake, so
  /// it counts as correct: never "Needs work", never written to the error
  /// profile (see [_QuestionResultCard]/[_saveErrors] below).
  bool get isCorrect =>
      match?.kind == AnswerMatchKind.correct ||
      match?.kind == AnswerMatchKind.keyboardVariant;

  bool get isKeyboardVariant => match?.kind == AnswerMatchKind.keyboardVariant;
}

const _fallbackComment = "Not quite — here's the correct answer.";

class _QuestionResultCard extends StatelessWidget {
  final _QuestionResult result;
  final SemanticColors semantic;

  const _QuestionResultCard({required this.result, required this.semantic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSkipped = result.isSkipped;
    final isCorrect = result.isCorrect;

    final background = isSkipped
        ? semantic.skippedBackground
        : isCorrect
            ? semantic.correctBackground
            : semantic.incorrectBackground;
    final onBackground = isSkipped
        ? semantic.onSkippedBackground
        : isCorrect
            ? semantic.onCorrectBackground
            : semantic.onIncorrectBackground;
    final icon = isSkipped
        ? Icons.remove_circle_outline_rounded
        : isCorrect
            ? Icons.check_circle_rounded
            : Icons.cancel_rounded;
    final label =
        isSkipped ? 'Skipped' : (isCorrect ? 'Correct' : 'Needs work');

    // A keyboard-variant match is correct but still gets its note shown —
    // "doğru sayılsın ama sessizce geçilmesin" — so it's checked before the
    // usual "no commentary on a correct answer" rule. Otherwise: the
    // specific matched wrong answer's comment (or the generic fallback)
    // explains a real mistake; a genuinely correct or skipped answer needs
    // no commentary.
    final explanation = result.isKeyboardVariant
        ? result.match?.comment
        : (!isSkipped && !isCorrect)
            ? (result.match?.comment ?? _fallbackComment)
            : null;

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: onBackground),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            MistakeBreakdown(
              prompt: result.question.item.fullText,
              userAnswer: result.userAnswer,
              correctedAnswer: isCorrect ? null : result.question.correctAnswer,
              explanation: explanation,
            ),
          ],
        ),
      ),
    );
  }
}
