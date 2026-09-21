import 'dart:async';

import 'package:flutter/material.dart';

import '../models/daily_test_completion.dart';
import '../models/daily_test_set.dart';
import '../services/analytics_service.dart';
import '../services/daily_test_service.dart';
import '../services/welcome_badge_rules.dart';
import '../theme.dart';
import '../utils/answer_matching.dart';
import '../utils/app_messenger.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/mistake_breakdown.dart';
import '../widgets/result_score_band.dart';

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
  /// the `day0` parameter of `daily_test_completed`.
  final bool isDay0;

  /// Day-0 owns its onboarding CTA. Other result routes get a Home action.
  final WidgetBuilder? bottomBuilder;

  const DailyTestResultScreen({
    super.key,
    required this.dailyTestSet,
    required this.answers,
    required this.dailyTestService,
    required this.analyticsService,
    this.isDay0 = false,
    this.onCompletionSaved,
    this.bottomBuilder,
  });

  @override
  State<DailyTestResultScreen> createState() => _DailyTestResultScreenState();
}

/// How long the Welcome banner takes to ease in.
const Duration _bannerDuration = Duration(milliseconds: 350);

class _DailyTestResultScreenState extends State<DailyTestResultScreen> {
  late final DailyTestCompletion _completion;
  List<DailyTestAnswerResult> get _results => _completion.results;
  bool _saving = false;
  bool _saveFailed = false;

  /// Set at most once per screen instance, only on a genuine live earn
  /// (docs/prd-gamification.md §M6.5) — never re-derived from storage, so
  /// a reopened already-completed set (whose `_saveCompletion` never even
  /// runs, see `initState` below) or a backfilled badge (which this screen
  /// never earns) cannot show it. Purely additive to the existing
  /// save-aware CTA row: it doesn't gate, delay or replace "See your
  /// climb"/"Back to Home".
  bool _showWelcomeCelebration = false;

  /// Set the moment the confetti is decided (played or skipped), so it can run
  /// at most once per screen instance whatever rebuilds, scrolls or retries
  /// happen afterwards. Separate from [_showWelcomeCelebration]: the banner
  /// stays for the life of the screen, the confetti is a one-off.
  bool _confettiDecided = false;
  OverlayEntry? _confettiEntry;
  final _celebrationKey = GlobalKey();

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
        setState(() => _showWelcomeCelebration = true);
        // After this frame, when the banner has a position to throw from.
        WidgetsBinding.instance.addPostFrameCallback((_) => _playConfetti());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveFailed = true);
      AppMessenger.show('Could not save your Daily Test results: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// The one-time confetti for the Welcome badge: thrown from the banner into
  /// an overlay above the screen, about 1.8 s, in the theme's colors. Never
  /// under reduced motion (the banner alone is the celebration then), and never
  /// twice: see [_confettiDecided]. Leaving the screen ends it at once.
  void _playConfetti() {
    if (_confettiDecided || !mounted) return;
    _confettiDecided = true;
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context);
    final banner = _celebrationKey.currentContext?.findRenderObject();
    if (overlay == null || banner is! RenderBox || !banner.hasSize) return;
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final origin = overlayBox.globalToLocal(
      banner.localToGlobal(Offset(banner.size.width / 2, 48)),
    );
    final colors = Theme.of(context).colorScheme;
    final entry = OverlayEntry(
      builder: (_) => ConfettiBurst(
        origin: origin,
        colors: [colors.primary, colors.secondary, colors.tertiary],
        onFinished: _removeConfetti,
      ),
    );
    _confettiEntry = entry;
    overlay.insert(entry);
  }

  void _removeConfetti() {
    final entry = _confettiEntry;
    if (entry == null) return;
    _confettiEntry = null;
    entry.remove();
    entry.dispose();
  }

  @override
  void dispose() {
    _removeConfetti();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

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
        // Eases in (size and fade) instead of shoving the results down when the
        // save lands. Under reduced motion it simply appears, and without an
        // AnimatedSize at all (a zero-duration one mutates its own layout).
        // If the list rebuilds this item later (scrolled away and back) it is
        // created already in its final state, so nothing replays.
        KeyedSubtree(
          key: _celebrationKey,
          child: reduceMotion
              ? (_showWelcomeCelebration
                  ? const _WelcomeCelebration()
                  : const SizedBox.shrink())
              : AnimatedSize(
                  duration: _bannerDuration,
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: AnimatedOpacity(
                    duration: _bannerDuration,
                    opacity: _showWelcomeCelebration ? 1 : 0,
                    child: _showWelcomeCelebration
                        ? const _WelcomeCelebration()
                        : const SizedBox(width: double.infinity),
                  ),
                ),
        ),
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
        ] else ...[
          const SizedBox(height: 6),
          if (_saveFailed)
            TextButton(
              onPressed: _saveCompletion,
              child: const Text('Retry saving'),
            ),
          FilledButton(
            onPressed: _saving || _saveFailed
                ? null
                : () => Navigator.of(context).pop(),
            child: Text(_saving
                ? 'Saving your results…'
                : _saveFailed
                    ? 'Save results to continue'
                    : !widget.dailyTestSet.isCompleted && _completion.step > 0
                        ? 'See your climb'
                        : 'Back to Home'),
          ),
        ],
      ],
    );
  }
}

/// The banner and the gap under it, as one block for the animation above.
class _WelcomeCelebration extends StatelessWidget {
  const _WelcomeCelebration();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _WelcomeCelebrationBanner(),
        SizedBox(height: 14),
      ],
    );
  }
}

/// The one-time Welcome badge win moment (docs/prd-gamification.md §M6.5).
/// Copy is deliberately audience-neutral — no "first test" language — since
/// the same badge, and the same wording, is earned identically by a brand
/// new user and by a pre-existing v2 user completing their first Daily
/// Test after updating. Visual is a temporary placeholder; real artwork
/// lands with the rest of the medal collection's own design pass later.
class _WelcomeCelebrationBanner extends StatelessWidget {
  const _WelcomeCelebrationBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.celebration_rounded,
                color: colorScheme.onSecondaryContainer,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to the climb',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Answer at least one question a day to keep moving "
                      "up this month's mountain.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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
