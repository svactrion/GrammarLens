import 'package:flutter/material.dart';

import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../services/daily_test_service.dart';
import '../theme.dart';
import '../utils/answer_matching.dart';
import '../utils/page_title.dart';
import '../widgets/mistake_breakdown.dart';

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
    _markCompleted();
  }

  Future<void> _markCompleted() async {
    try {
      await widget.dailyTestService.markCompleted();
    } catch (_) {
      // Best-effort, same reasoning as ResultsScreen._recordCompletion:
      // not worth surfacing an error for over the results the user is
      // actually here to see.
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);

    final correctCount = _results.where((r) => r.isCorrect).length;
    final skippedCount = _results.where((r) => r.isSkipped).length;
    final totalCount = _results.length;

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Daily Test Results')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
        children: [
          Text(
            skippedCount > 0
                ? '$correctCount/$totalCount correct · $skippedCount skipped'
                : '$correctCount/$totalCount correct',
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 20),
          for (final result in _results) ...[
            _QuestionResultCard(result: result, semantic: semantic),
            const SizedBox(height: 14),
          ],
          if (widget.bottomBuilder != null) ...[
            const SizedBox(height: 6),
            widget.bottomBuilder!(context),
          ],
        ],
      ),
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

  bool get isCorrect => match?.kind == AnswerMatchKind.correct;
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
    final label = isSkipped ? 'Skipped' : (isCorrect ? 'Correct' : 'Needs work');

    // Only the specific matched wrong answer's comment (or the generic
    // fallback) explains anything — a correct answer needs no commentary,
    // and a skipped one just shows the correct answer via MistakeBreakdown.
    final explanation = (!isSkipped && !isCorrect)
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
              correctedAnswer:
                  isCorrect ? null : result.question.correctAnswer,
              explanation: explanation,
            ),
          ],
        ),
      ),
    );
  }
}
