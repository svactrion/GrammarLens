import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_test_completion.dart';
import '../models/climb_theme.dart';
import '../models/daily_test_set.dart';
import '../models/medal_tier.dart';
import '../services/analytics_service.dart';
import '../services/climb_milestones.dart';
import '../services/daily_test_service.dart';
import '../services/monthly_medal_rules.dart';
import '../services/welcome_badge_rules.dart';
import '../theme.dart';
import '../utils/answer_matching.dart';
import '../utils/app_messenger.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/medal_celebration.dart';
import '../widgets/mistake_breakdown.dart';
import '../widgets/result_score_band.dart';
import '../utils/content_width.dart';

/// Shown after the last Daily Test question. Grading is entirely local —
/// [checkDailyTestAnswer] against the answer key the data layer generated
/// up front — there's no live evaluation call the way Topic Practice's
/// ResultsScreen has one. Visually mirrors that screen (same summary line,
/// same per-item `SemanticColors` card treatment, same [MistakeBreakdown]
/// layout) so this reads as the same app, not a bolted-on separate flow.
class DailyTestResultScreen extends StatefulWidget {
  /// Refreshes the owning Home even if the user leaves while saving.
  final VoidCallback? onCompletionSaved;
  final DailyTestSet dailyTestSet;
  final Map<String, String> answers;
  final DailyTestService dailyTestService;
  final AnalyticsService analyticsService;

  /// True only for the Day-0 first-launch flow's result screen; reported as
  /// the `day0` parameter of `daily_test_completed`, and it makes the button
  /// read "Continue" instead of "Back to Home" (there is no Home to go back to
  /// yet).
  final bool isDay0;

  /// How the screen is left. Null (a route pushed from Home) pops it; the
  /// Day-0 flow is not a route, so it passes the callback that ends the flow.
  final VoidCallback? onDone;

  const DailyTestResultScreen({
    super.key,
    required this.dailyTestSet,
    required this.answers,
    required this.dailyTestService,
    required this.analyticsService,
    this.isDay0 = false,
    this.onCompletionSaved,
    this.onDone,
  });

  @override
  State<DailyTestResultScreen> createState() => _DailyTestResultScreenState();
}

class _DailyTestResultScreenState extends State<DailyTestResultScreen> {
  late final DailyTestCompletion _completion;
  List<DailyTestAnswerResult> get _results => _completion.results;
  bool _saving = false;
  bool _saveFailed = false;

  /// Set at most once per screen instance, only on a genuine live earn
  /// (docs/prd-gamification.md §M6.5) — never re-derived from storage, so
  /// a reopened already-completed set (whose `_saveCompletion` never even
  /// runs, see `initState` below) or a backfilled badge (which this screen
  /// never earns) cannot show it. It opens the celebration and turns the
  /// button into "Start my climb"; it does not delay the save or anything
  /// else.
  bool _showWelcomeCelebration = false;

  /// The celebration layer showing now (Batch 5, N15), or null: the Welcome
  /// badge or a tier just secured, opened when the save lands, closed by
  /// one tap. Only `_saveCompletion` sets it, so a reopened result or a
  /// relaunch never plays it again.
  _Celebration? _celebration;

  /// [_leave] has run: the screen is left at most once, whatever taps get
  /// there.
  bool _left = false;

  /// Guards `daily_test_completed`/Welcome analytics to at most once per
  /// screen instance, on top of `_saveCompletion`'s own already-completed
  /// early return — a reopened finished result never reports, and a failed
  /// save that is retried reports only when a save actually succeeds.
  bool _analyticsReported = false;

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
      final welcomeBadgeJustEarned =
          await widget.dailyTestService.completeDailyTest(
        _completion.answers,
        _completion.errors,
        day: _completion.set.day,
        completedAt: _completion.completedAt,
      );
      _reportCompletion(welcomeBadgeJustEarned);
      widget.onCompletionSaved?.call();
      if (welcomeBadgeJustEarned && mounted) {
        setState(() {
          _showWelcomeCelebration = true;
          _celebration = const _Celebration.welcome();
        });
      }
      // What this completion reached in its month (N12, N15, N24): its
      // events, and a tier's celebration. The Welcome badge and a tier
      // never come together: the badge is the first step ever, worth at
      // most 10 points, and Bronze is at least 70; nor does that first
      // step reach a save point (the first is on step 7).
      final milestones = await ClimbMilestones.afterCompletion(
        storage: widget.dailyTestService.storageService,
        day: _completion.set.day,
        step: _completion.step,
        points: MonthlyMedalRules.score(
            correct: _completion.correct, wrong: _completion.wrong),
      );
      if (milestones != null) _reportMilestones(milestones);
      final tier = milestones?.tier;
      if (tier != null && !welcomeBadgeJustEarned && mounted) {
        setState(() => _celebration =
            _Celebration.tier(tier, milestones!.theme, milestones.month));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveFailed = true);
      AppMessenger.show('Could not save your Daily Test results: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The way out: pops this route, or, for the Day-0 flow (not a route), calls
  /// [DailyTestResultScreen.onDone]. At most once.
  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// Analytics for a save that just succeeded (docs/analytics-plan.md E1/E3):
  /// counts and the ledger day only, never question or answer text. The
  /// Welcome events and the `first_step_dom` user property fire only on a
  /// live earn, so they are set exactly once per user.
  void _reportCompletion(bool welcomeBadgeJustEarned) {
    if (_analyticsReported) return;
    _analyticsReported = true;
    final analytics = widget.analyticsService;
    unawaited(analytics.dailyTestCompleted(
      correctCount: _completion.correct,
      wrongCount: _completion.wrong,
      skippedCount: _completion.skipped,
      stepEarned: _completion.step == 1,
      day0: widget.isDay0,
      setSource: widget.dailyTestSet.source.name,
      setDate: widget.dailyTestSet.day,
    ));
    if (!welcomeBadgeJustEarned) return;
    // The ledger day, not the wall clock: the same authority the step
    // itself is attributed to across midnight and timezone changes.
    final ledgerDay = DateTime.tryParse(_completion.set.day);
    if (ledgerDay == null) return;
    unawaited(analytics.welcomeBadgeEarned(
      ruleVersion: WelcomeBadgeRules.ruleVersion,
      dayOfMonth: ledgerDay.day,
      daysInMonth: DateTime(ledgerDay.year, ledgerDay.month + 1, 0).day,
    ));
    unawaited(analytics.setFirstStepDayOfMonth(ledgerDay.day));
  }

  /// `save_point_reached` and `medal_tier_reached` (N21) for what this
  /// completion reached: after the durable save, once per screen instance
  /// (only `_saveCompletion` calls it, after a success). The theme is the
  /// set's month's.
  void _reportMilestones(ClimbMilestones milestones) {
    final analytics = widget.analyticsService;
    final days = DateTime(milestones.year, milestones.month + 1, 0).day;
    for (final p in milestones.savePoints) {
      unawaited(analytics.savePointReached(
        themeId: milestones.theme.id,
        savePoint: p.eventId,
        step: p.reachedOn(days),
        daysInMonth: days,
      ));
    }
    final tier = milestones.tier;
    if (tier == null) return;
    final ledgerDay = DateTime.tryParse(_completion.set.day);
    if (ledgerDay == null) return;
    unawaited(analytics.medalTierReached(
      themeId: milestones.theme.id,
      tier: tier,
      dayOfMonth: ledgerDay.day,
      daysInMonth: days,
      activeDays: milestones.steps,
      ruleVersion: MonthlyMedalRules.ruleVersion,
    ));
  }

  /// What the one primary button says and does, from the screen's own state.
  /// It lives in the fixed footer, so it is on screen however far the results
  /// are scrolled.
  Widget _primaryButton() {
    if (_saving) {
      return const FilledButton(
        onPressed: null,
        child: Text('Saving your results…'),
      );
    }
    if (_saveFailed) {
      return FilledButton(
        onPressed: _saveCompletion,
        child: const Text('Try saving again'),
      );
    }
    if (_showWelcomeCelebration) {
      return FilledButton(
        // N36: no exit confetti any more (the celebration is in the
        // layer); the label and the way on stay.
        onPressed: _leave,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_rounded, size: 20),
            SizedBox(width: 8),
            Flexible(child: Text('Start my climb')),
          ],
        ),
      );
    }
    return FilledButton(
      onPressed: _leave,
      child: Text(widget.isDay0
          ? 'Continue'
          : !widget.dailyTestSet.isCompleted && _completion.step > 0
              ? 'See your climb'
              : 'Back to Home'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>()!;
    // P1: held to the centred content column on an iPad (`ContentWidth`).
    final hPad = ContentWidth.sidePaddingOf(context);

    final correctCount = _results.where((r) => r.isCorrect).length;
    final skippedCount = _results.where((r) => r.isSkipped).length;
    final totalCount = _results.length;
    final scoreText = skippedCount > 0
        ? '$correctCount/$totalCount correct · $skippedCount skipped'
        : '$correctCount/$totalCount correct';

    final celebration = _celebration;
    final scaffold = BrandScaffold(
      title: const PageTitle('Daily Test Results'),
      bandBottom: ResultScoreBand.sized(context, text: scoreText),
      // Fixed, like Premium's footer: a hard edge (not a shadow that only
      // appears once scrolled) between the results and the one button.
      bottomBar: DecoratedBox(
        key: const Key('resultFooter'),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
            child: SizedBox(
              width: double.infinity,
              child: _primaryButton(),
            ),
          ),
        ),
      ),
      children: [
        // A slot of its own height, so the results do not shift by the bar's
        // height when the save lands.
        SizedBox(
          height: 4,
          child: _saving ? const LinearProgressIndicator() : null,
        ),
        if (_saveFailed) ...[
          const Text('Your result could not be saved. Please try again.'),
          const SizedBox(height: 14),
        ],
        for (final result in _results) ...[
          _QuestionResultCard(result: result, semantic: semantic),
          const SizedBox(height: 14),
        ],
      ],
    );
    if (celebration == null) return scaffold;
    void close() => setState(() => _celebration = null);
    const key = ValueKey('medal_celebration');
    return Stack(children: [
      scaffold,
      Positioned.fill(
        child: celebration.tier == null
            ? MedalCelebration.welcome(key: key, onClose: close)
            : MedalCelebration.tier(
                key: key,
                tier: celebration.tier!,
                theme: celebration.theme!,
                month: celebration.month,
                onClose: close),
      ),
    ]);
  }
}

/// Which celebration shows (N15): the Welcome badge, or a tier with its
/// month and that month's theme.
class _Celebration {
  final MedalTier? tier;
  final ClimbTheme? theme;
  final int month;

  const _Celebration.welcome()
      : tier = null,
        theme = null,
        month = 0;

  const _Celebration.tier(
      MedalTier this.tier, ClimbTheme this.theme, this.month);
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

    // Mirrors Topic Practice's ResultsScreen, where every card — correct,
    // skipped or wrong — carries its explanation. Priority, most specific
    // first: a predicted wrong answer keeps its own comment (it speaks to
    // that exact mistake); a keyboard-variant match keeps its note —
    // "doğru sayılsın ama sessizce geçilmesin" — followed by the question's
    // explanation; everything else (correct, skipped, or a wrong answer
    // nobody predicted) gets the question's own explanation. A set cached
    // before `explanation` existed has none: a real mistake then still gets
    // the generic fallback line, and a correct or skipped card stays
    // without commentary as before — never an empty line.
    final questionExplanation = result.question.explanation;
    final explanation = switch (result.match?.kind) {
      AnswerMatchKind.commonWrong => result.match?.comment,
      AnswerMatchKind.keyboardVariant => [
          result.match?.comment,
          questionExplanation,
        ].whereType<String>().join(' '),
      // An alternative the set accepts: shown as correct, with the key
      // named so the learner also sees the form the set expected.
      AnswerMatchKind.accepted => [
          'Also correct: "${result.question.correctAnswer}".',
          questionExplanation,
        ].whereType<String>().join(' '),
      AnswerMatchKind.fallback => questionExplanation ?? _fallbackComment,
      AnswerMatchKind.correct || null => questionExplanation,
    };

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
                  style: theme.textTheme.labelLarge
                      ?.withWeight(FontWeight.w600)
                      .copyWith(color: onBackground),
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
