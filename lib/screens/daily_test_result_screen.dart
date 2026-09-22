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

/// How long the Welcome card takes to ease in.
const Duration _bannerDuration = Duration(milliseconds: 350);

/// The longest the screen waits for the confetti to finish before it moves on
/// anyway. The burst takes 1.8 s ([ConfettiBurst.duration]); this only matters
/// if something stops its animation (a paused ticker, a torn-down overlay), so
/// a stuck burst can never trap the user on this screen.
const Duration _climbFallback = Duration(milliseconds: 2500);

class _DailyTestResultScreenState extends State<DailyTestResultScreen> {
  late final DailyTestCompletion _completion;
  List<DailyTestAnswerResult> get _results => _completion.results;
  bool _saving = false;
  bool _saveFailed = false;

  /// Set at most once per screen instance, only on a genuine live earn
  /// (docs/prd-gamification.md §M6.5) — never re-derived from storage, so
  /// a reopened already-completed set (whose `_saveCompletion` never even
  /// runs, see `initState` below) or a backfilled badge (which this screen
  /// never earns) cannot show it. It turns the card on and the button into
  /// "Start my climb"; it does not delay the save or anything else.
  bool _showWelcomeCelebration = false;

  /// The "Start my climb" button was tapped. From then on the button is
  /// disabled, the confetti plays on this screen for its whole run, and only
  /// then does the screen move on ([_leave]), so the two never overlap.
  bool _climbStarted = false;

  /// [_leave] has run: the screen is left at most once, whatever combination of
  /// finished burst, fallback timer and taps gets there.
  bool _left = false;

  OverlayEntry? _confettiEntry;
  Timer? _fallbackTimer;
  final _climbButtonKey = GlobalKey();

  /// Keeps the card's element alive when the list above it changes length (the
  /// saving bar and the failure text come and go), so it eases in from where it
  /// was instead of being rebuilt already in its final state.
  final _cardKey = GlobalKey();

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
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saveFailed = true);
      AppMessenger.show('Could not save your Daily Test results: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// "Start my climb": the badge is earned and the user chose to move on. The
  /// confetti plays here, on the results, for its whole run, and [_leave] runs
  /// when it ends. Where there is no confetti (reduced motion, no overlay to
  /// draw on) the screen is left at once.
  void _startClimb() {
    if (_climbStarted) return;
    setState(() => _climbStarted = true);
    if (!_playConfetti()) {
      _leave();
      return;
    }
    _fallbackTimer = Timer(_climbFallback, _leave);
  }

  /// Throws the confetti from the top of the button into an overlay above the
  /// screen, about 1.8 s, in the theme's colors. False when it was not played:
  /// never under reduced motion (the card alone is the celebration then).
  bool _playConfetti() {
    if (MediaQuery.disableAnimationsOf(context)) return false;
    final overlay = Overlay.maybeOf(context);
    final button = _climbButtonKey.currentContext?.findRenderObject();
    if (overlay == null || button is! RenderBox || !button.hasSize) {
      return false;
    }
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final origin = overlayBox.globalToLocal(
      button.localToGlobal(Offset(button.size.width / 2, 0)),
    );
    final colors = Theme.of(context).colorScheme;
    final entry = OverlayEntry(
      builder: (_) => ConfettiBurst(
        origin: origin,
        colors: [colors.primary, colors.secondary, colors.tertiary],
        onFinished: _leave,
      ),
    );
    _confettiEntry = entry;
    overlay.insert(entry);
    return true;
  }

  void _removeConfetti() {
    final entry = _confettiEntry;
    if (entry == null) return;
    _confettiEntry = null;
    entry.remove();
    entry.dispose();
  }

  /// The way out: pops this route, or, for the Day-0 flow (not a route), calls
  /// [DailyTestResultScreen.onDone]. At most once.
  void _leave() {
    if (_left || !mounted) return;
    _left = true;
    _fallbackTimer?.cancel();
    _removeConfetti();
    final onDone = widget.onDone;
    if (onDone != null) {
      onDone();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
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
      setSource: widget.dailyTestSet.source.name,
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
        key: _climbButtonKey,
        onPressed: _climbStarted ? null : _startClimb,
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
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final hPad = (MediaQuery.sizeOf(context).width * 0.045).clamp(16.0, 28.0);

    final correctCount = _results.where((r) => r.isCorrect).length;
    final skippedCount = _results.where((r) => r.isSkipped).length;
    final totalCount = _results.length;
    final scoreText = skippedCount > 0
        ? '$correctCount/$totalCount correct · $skippedCount skipped'
        : '$correctCount/$totalCount correct';

    return BrandScaffold(
      title: const PageTitle('Daily Test Results'),
      bandBottom: ResultScoreBand(text: scoreText),
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
        // Below the results, so it never pushes them down when the save
        // lands, and it eases in (size and fade) instead of jumping. Under
        // reduced motion it simply appears, and without an AnimatedSize at all
        // (a zero-duration one mutates its own layout). If the list rebuilds
        // this item later (scrolled away and back) it is created already in
        // its final state, so nothing replays.
        if (reduceMotion)
          KeyedSubtree(
            key: _cardKey,
            child: _showWelcomeCelebration
                ? const _WelcomeBadgeCard()
                : const SizedBox.shrink(),
          )
        else
          AnimatedSize(
            key: _cardKey,
            duration: _bannerDuration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedOpacity(
              duration: _bannerDuration,
              opacity: _showWelcomeCelebration ? 1 : 0,
              child: _showWelcomeCelebration
                  ? const _WelcomeBadgeCard()
                  : const SizedBox(width: double.infinity),
            ),
          ),
      ],
    );
  }
}

/// The one-time Welcome badge win moment (docs/prd-gamification.md §M6.5), a
/// large card under the results: the badge, its name and what earns the next
/// step. Copy is deliberately audience-neutral — no "first test" language —
/// since the same badge, and the same wording, is earned identically by a brand
/// new user and by a pre-existing v2 user completing their first Daily Test
/// after updating. Visual is a temporary placeholder; real artwork lands with
/// the rest of the medal collection's own design pass later.
class _WelcomeBadgeCard extends StatelessWidget {
  const _WelcomeBadgeCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onContainer = colorScheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Card(
        color: colorScheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onContainer.withValues(alpha: 0.12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.emoji_events_rounded,
                    color: onContainer,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome to the climb',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: onContainer,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Answer at least one question a day to keep moving "
                "up this month's mountain.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: onContainer),
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
