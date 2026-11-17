import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../utils/haptics.dart';
import '../widgets/companion_view.dart';
import '../widgets/english_content.dart';
import '../widgets/pressable_button.dart';
import '../widgets/score_ring.dart';
import '../widgets/step_bar.dart';

import '../l10n/l10n.dart';
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
import '../models/practice_item.dart';
import '../utils/answer_matching.dart';
import '../utils/blank_assembly.dart';
import '../utils/blanks.dart';
import '../utils/app_messenger.dart';
import '../widgets/medal_celebration.dart';
import '../widgets/mistake_breakdown.dart';

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

  /// The user's buddy and name (the companion, V11's "Welcome to the
  /// climb, <name>!").
  final Avatar? hero;
  final String? userName;

  static const primaryKey = Key('resultPrimary');

  /// One answer row of "Your answers" (V10), by question.
  static ValueKey<String> rowKey(int index) =>
      ValueKey('daily_result_row_$index');

  const DailyTestResultScreen({
    super.key,
    required this.dailyTestSet,
    required this.answers,
    required this.dailyTestService,
    required this.analyticsService,
    this.isDay0 = false,
    this.onCompletionSaved,
    this.onDone,
    this.hero,
    this.userName,
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

  /// This month's steps after this completion (V10's "Day N complete!");
  /// null until the save has landed.
  int? _monthSteps;

  /// For R05: this month's points and the next tier's line.
  ({int points, MedalTier? next, int? nextAt})? _medalLine;

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
      // SPEC §4 (v11): V10 Results → V11 Welcome badge → V12. The badge
      // no longer opens over the results when the save lands (fix round 3,
      // A1: the device showed it first); the results' "Climb my first step"
      // opens it, and its Continue goes on.
      if (welcomeBadgeJustEarned && mounted) {
        setState(() => _showWelcomeCelebration = true);
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
      if (milestones != null && mounted) {
        setState(() => _monthSteps = milestones.steps);
      }
      final tier = milestones?.tier;
      if (tier != null && !welcomeBadgeJustEarned && mounted) {
        final m = milestones!;
        final next = tier.index + 1 < MedalTier.values.length
            ? MedalTier.values[tier.index + 1]
            : null;
        setState(() {
          _medalLine = (
            points: m.score,
            next: next,
            nextAt: next == null
                ? null
                : MonthlyMedalRules.threshold(m.year, m.month, next),
          );
          _celebration = _Celebration.tier(tier, m.theme, m.month);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveFailed = true);
      AppMessenger.show(context.l10n.dailyResultSaveFailed('$e'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// V11 after V10 (SPEC §4, v11): the Welcome badge opens from the
  /// results' button; closing it leaves (the first climb, V12).
  void _openWelcomeBadge() {
    if (_celebration != null || _left || !mounted) return;
    setState(() => _celebration = const _Celebration.welcome());
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
    final arrow = Directionality.of(context) == TextDirection.rtl
        ? Icons.arrow_back_rounded
        : Icons.arrow_forward_rounded;
    if (_saving) {
      return PressableButton(
        key: DailyTestResultScreen.primaryKey,
        label: context.l10n.dailyResultSaving,
        onPressed: null,
      );
    }
    if (_saveFailed) {
      return PressableButton(
        key: DailyTestResultScreen.primaryKey,
        label: context.l10n.dailyResultRetrySave,
        onPressed: _saveCompletion,
      );
    }
    // The way on after the first step ever (the Welcome badge): "Climb my
    // first step" (V10).
    if (_showWelcomeCelebration) {
      return PressableButton(
        key: DailyTestResultScreen.primaryKey,
        label: context.l10n.dailyResultFirstStep,
        shine: true,
        trailingIcon: arrow,
        onPressed: _openWelcomeBadge,
      );
    }
    final seeClimb = !widget.isDay0 &&
        !widget.dailyTestSet.isCompleted &&
        _completion.step > 0;
    return PressableButton(
      key: DailyTestResultScreen.primaryKey,
      label: widget.isDay0
          ? context.l10n.commonContinue
          : seeClimb
              ? context.l10n.dailyResultSeeClimb
              : context.l10n.dailyResultBackHome,
      trailingIcon: seeClimb ? arrow : null,
      onPressed: _leave,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final correct = _completion.correct;
    final points =
        MonthlyMedalRules.score(correct: correct, wrong: _completion.wrong);
    final steps = _monthSteps;
    final title = steps == null || steps == 0 || _completion.step == 0
        ? l10n.dailyResultDone
        : l10n.dailyResultDayComplete(steps);
    final hero = widget.hero ?? Avatar.fox;

    final scaffold = Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.text, letterSpacing: -.8),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CompanionView(
                          hero: hero, mood: CompanionMood.cheer, size: 118),
                      const SizedBox(width: 18),
                      _StepwiseRing(results: _results),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    Text(l10n.dailyResultAnswers,
                        style: theme.textTheme.labelLarge!
                            .withWeight(FontWeight.w800)
                            .copyWith(color: c.muted)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StepBar(
                        segments: [
                          for (final r in _results)
                            r.isSkipped
                                ? c.track
                                : (r.isCorrect ? c.green : c.wrong),
                        ],
                        track: c.track,
                        height: 9,
                        gap: 5,
                        stagger: const Duration(milliseconds: 280),
                        animateOnMount: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CountUp(
                        value: points,
                        prefix: '+',
                        style: theme.textTheme.labelLarge!
                            .withWeight(FontWeight.w900)
                            .copyWith(color: c.goldDeep)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: _StatTile(
                        value: _CountUp(value: points, prefix: '+'),
                        label: l10n.dailyResultPointsLabel,
                        background: c.goldSoft,
                        foreground: c.goldDeep,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        value:
                            Text('${_completion.step}'), // l10n-guard: a number
                        label: l10n.dailyResultStepLabel,
                        background: c.cream,
                        foreground: c.orangeDeep,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        value: Text(
                            '${_completion.wrong}'), // l10n-guard: a number
                        label: l10n.dailyResultWeakLabel(_completion.wrong),
                        background: c.sky,
                        foreground: c.onSky,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 4,
                    child: _saving ? const LinearProgressIndicator() : null,
                  ),
                  if (_saveFailed) ...[
                    Text(l10n.dailyResultNotSaved),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: lipCard(c, radius: 26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.dailyResultYourAnswers,
                            style: theme.textTheme.titleMedium!
                                .withWeight(FontWeight.w900)
                                .copyWith(color: c.text)),
                        const SizedBox(height: 6),
                        for (final (i, result) in _results.indexed)
                          _RowEntrance(
                            index: i,
                            child: _AnswerRow(
                                key: DailyTestResultScreen.rowKey(i),
                                result: result),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      // In the Scaffold's bottom slot, so a message floats above it.
      bottomNavigationBar: SafeArea(
        child: Padding(
          key: const Key('resultFooter'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: _primaryButton(),
        ),
      ),
    );
    final celebration = _celebration;
    // Always one Stack, so opening or closing a celebration never rebuilds
    // the results under it (their scroll position and entrance stay put).
    if (celebration == null) return Stack(children: [scaffold]);
    void close() {
      setState(() => _celebration = null);
      // The Welcome badge is the step between the results and the first
      // climb: closing it goes on. A tier medal (R05) closes back to the
      // results, as before.
      if (celebration.tier == null) _leave();
    }

    const key = ValueKey('medal_celebration');
    final line = _medalLine;
    return Stack(children: [
      scaffold,
      Positioned.fill(
        child: celebration.tier == null
            ? MedalCelebration.welcome(
                key: key,
                onClose: close,
                l10n: context.l10n,
                hero: hero,
                name: widget.userName)
            : MedalCelebration.tier(
                key: key,
                tier: celebration.tier!,
                theme: celebration.theme!,
                month: celebration.month,
                onClose: close,
                l10n: context.l10n,
                hero: hero,
                points: line?.points,
                nextTier: line?.next,
                nextAt: line?.nextAt,
              ),
      ),
    ]);
  }
}

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

/// One answer in "Your answers" (V10): a status mark, the sentence with
/// the learner's answer, a chevron; tapped, it opens the answer, the
/// correction and the explanation (the card it replaces, word for word).
class _AnswerRow extends StatefulWidget {
  final DailyTestAnswerResult result;
  const _AnswerRow({super.key, required this.result});

  @override
  State<_AnswerRow> createState() => _AnswerRowState();
}

class _AnswerRowState extends State<_AnswerRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final isSkipped = result.isSkipped;
    final isCorrect = result.isCorrect;
    final (mark, markColor) = isSkipped
        ? (Icons.remove_rounded, c.muted)
        : isCorrect
            ? (Icons.check_rounded, c.green)
            : (Icons.close_rounded, c.red);
    final label = isSkipped
        ? l10n.resultSkipped
        : (isCorrect ? l10n.resultCorrect : l10n.resultNeedsWork);
    final questionExplanation = result.question.explanation;
    final explanation = switch (result.match?.kind) {
      AnswerMatchKind.commonWrong => result.match?.comment,
      AnswerMatchKind.keyboardVariant => [
          keyboardVariantNoteText(
              result.match?.keyboardNote ?? const KeyboardVariantNote(), l10n),
          questionExplanation,
        ].whereType<String>().join(' '),
      // An alternative the set accepts: shown as correct, with the key
      // named so the learner also sees the form the set expected.
      AnswerMatchKind.accepted => [
          l10n.dailyResultAlsoCorrect(result.question.correctAnswer),
          questionExplanation,
        ].whereType<String>().join(' '),
      AnswerMatchKind.fallback =>
        questionExplanation ?? l10n.dailyResultFallback,
      AnswerMatchKind.correct || null => questionExplanation,
    };

    final answer = (result.userAnswer ?? '').trim();
    final summary = isSkipped ? result.question.item.fullText : answer;
    // V10: a one-blank question reads as its sentence with the answer in
    // bold; other answers are the learner's sentence itself.
    final template = blankSourceText(result.question.item);
    final parts = template.split(blankPattern);
    final inSentence = !isSkipped &&
        result.question.item.type == PracticeItemType.fillInBlank &&
        parts.length == 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: c.line),
        Semantics(
          button: true,
          expanded: _open,
          label: '$label. $summary',
          excludeSemantics: true,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration:
                        BoxDecoration(color: markColor, shape: BoxShape.circle),
                    child: Icon(mark, size: 17, color: c.onNavy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: EnglishContent(
                      child: Text.rich(
                        inSentence
                            ? TextSpan(children: [
                                TextSpan(text: parts.first.trimLeft()),
                                TextSpan(
                                    text: answer,
                                    style: const TextStyle()
                                        .withWeight(FontWeight.w900)),
                                TextSpan(text: parts.last),
                              ])
                            : TextSpan(text: summary),
                        maxLines: _open ? null : 1,
                        overflow: _open
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge!
                            .withWeight(FontWeight.w500)
                            .copyWith(color: c.text),
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? .5 : 0,
                    duration: AppMotion.orInstant(context, AppMotion.fast),
                    child:
                        Icon(Icons.keyboard_arrow_down_rounded, color: c.muted),
                  ),
                ]),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.reduced(context)
              ? const Duration(milliseconds: 1)
              : AppMotion.base,
          child: _open
              ? Padding(
                  padding:
                      const EdgeInsetsDirectional.only(bottom: 12, start: 38),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label,
                          style: theme.textTheme.labelLarge!
                              .withWeight(FontWeight.w800)
                              .copyWith(color: markColor)),
                      const SizedBox(height: 8),
                      MistakeBreakdown(
                        prompt: result.question.item.fullText,
                        userAnswer: result.userAnswer,
                        correctedAnswer:
                            isCorrect ? null : result.question.correctAnswer,
                        explanation: explanation,
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// The score ring that fills one question at a time (V10): 280 ms a
/// question with a ±3° jiggle at the end of each step; a light haptic per
/// correct step, success on the last.
class _StepwiseRing extends StatefulWidget {
  final List<DailyTestAnswerResult> results;
  const _StepwiseRing({required this.results});

  @override
  State<_StepwiseRing> createState() => _StepwiseRingState();
}

class _StepwiseRingState extends State<_StepwiseRing>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 280);
  late final AnimationController _c;
  int _reported = 0;

  int get _n => widget.results.length;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _step * math.max(1, _n))
      ..addListener(_tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.value == 0 && !_c.isAnimating) {
      if (AppMotion.reduced(context)) {
        _c.value = 1;
      } else {
        _c.forward();
      }
    }
  }

  void _tick() {
    final done = (_c.value * _n).floor().clamp(0, _n);
    while (_reported < done) {
      final r = widget.results[_reported];
      _reported++;
      if (_reported == _n) {
        HapticMap.success();
      } else if (r.isCorrect) {
        HapticMap.light();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final correct = widget.results.where((r) => r.isCorrect).length;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * _n;
        final k = t.floor().clamp(0, _n);
        final within = t - k;
        var shown =
            widget.results.take(k).where((r) => r.isCorrect).length.toDouble();
        if (k < _n && widget.results[k].isCorrect) {
          shown += Curves.easeOut.transform(within.clamp(0.0, 1.0));
        }
        final jiggle = k < _n && within > .7
            ? math.sin((within - .7) / .3 * math.pi * 2) * 3 * math.pi / 180
            : 0.0;
        return Transform.rotate(
          angle: jiggle,
          child: ScoreRing(
            value: _n == 0 ? 0 : shown / _n,
            size: 132,
            stroke: 15,
            color: c.green,
            track: c.track,
            duration: Duration.zero,
            semanticLabel: context.l10n.dailyCardScoreSemantics(correct, _n),
            center: ScoreRing.fraction(context, correct, _n,
                color: c.text, fontSize: 34),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final Widget value;
  final String label;
  final Color background;
  final Color foreground;

  const _StatTile({
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        DefaultTextStyle.merge(
          style: theme.textTheme.headlineSmall!
              .withWeight(FontWeight.w900)
              .copyWith(color: foreground),
          child: value,
        ),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: theme.textTheme.labelMedium!
                .withWeight(FontWeight.w800)
                .copyWith(color: foreground)),
      ]),
    );
  }
}

/// A number counting up from 0 (600 ms).
class _CountUp extends StatelessWidget {
  final int value;
  final String prefix;
  final TextStyle? style;
  const _CountUp({required this.value, this.prefix = '', this.style});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<int>(
        tween: IntTween(begin: 0, end: value),
        duration:
            AppMotion.orInstant(context, const Duration(milliseconds: 600)),
        builder: (context, v, _) => Text('$prefix$v', // l10n-guard: a number
            style: style,
            textScaler: TextScaler.noScaling),
      );
}

/// An answer row entering from below, 40 ms after the one before.
class _RowEntrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _RowEntrance({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) return child;
    final delay = Duration(milliseconds: 600 + 40 * index);
    final total = delay + AppMotion.base;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(delay.inMilliseconds / total.inMilliseconds, 1,
          curve: AppMotion.enter),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child:
            Transform.translate(offset: Offset(0, 10 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
