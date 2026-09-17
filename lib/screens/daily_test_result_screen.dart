import 'package:flutter/material.dart';

import '../models/daily_test_completion.dart';
import '../models/daily_test_set.dart';
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
  late final DailyTestCompletion _completion;
  List<DailyTestAnswerResult> get _results => _completion.results;
  bool _saving = false;
  bool _saveFailed = false;

  @override
  void initState() {
    super.initState();
    _completion = DailyTestCompletion(
        set: widget.dailyTestSet,
        answers: widget.answers,
        completedAt: DateTime.now());
    if (!widget.dailyTestSet.isCompleted) _saveCompletion();
  }

  Future<void> _saveCompletion() async {
    if (_saving || widget.dailyTestSet.isCompleted) return;
    setState(() {
      _saving = true;
      _saveFailed = false;
    });
    try {
      await widget.dailyTestService.completeDailyTest(
        _completion.answers,
        _completion.errors,
        day: _completion.set.day,
        completedAt: _completion.completedAt,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveFailed = true);
      AppMessenger.show('Could not save your Daily Test results: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        if (_saving) const LinearProgressIndicator(),
        if (_saveFailed) ...[
          const Text('Your result could not be saved. Please try again.'),
          TextButton(
              onPressed: _saveCompletion,
              child: const Text('Try saving again')),
        ],
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

const _fallbackComment = "Not quite — here's the correct answer.";

class _QuestionResultCard extends StatelessWidget {
  final DailyTestAnswerResult result;
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
