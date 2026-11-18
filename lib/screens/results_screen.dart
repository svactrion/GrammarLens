import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../app_colors.dart';
import '../models/avatar.dart';
import '../motion.dart';
import '../widgets/companion_view.dart';
import '../widgets/pressable_button.dart';
import '../models/error_entry.dart';
import '../models/practice_set.dart';
import '../models/scoring_result.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/app_messenger.dart';
import '../utils/blank_assembly.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/mistake_breakdown.dart';
import 'premium_screen.dart';

class ResultsScreen extends StatefulWidget {
  /// The fixed area with "Back to topics".
  static const footerKey = Key('resultsFooter');

  final Topic topic;
  final ScoringResult result;
  final PracticeSet practiceSet;
  final Map<String, String> answers;

  /// Per-box answers of the multi-blank questions, by item id (1.4.0 B8);
  /// a question without an entry shows its [answers] text.
  final Map<String, List<BlankAnswer>> blankAnswers;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  const ResultsScreen({
    super.key,
    required this.topic,
    required this.result,
    required this.practiceSet,
    required this.answers,
    this.blankAnswers = const {},
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  // The Premium offer card above "Back to topics": only for a free user whose
  // daily free practice is used up. Hidden until both reads succeed, and
  // hidden for good if either one throws: a prompt shown to someone who
  // might be paying is worse than one that doesn't show.
  bool _showUpsell = false;

  /// The user's buddy, cheering (V21); read once.
  Avatar? _hero;

  @override
  void initState() {
    super.initState();
    widget.storageService.getUserProfile().then((profile) {
      if (mounted && profile?.avatar != null) {
        setState(() => _hero = profile!.avatar);
      }
    }, onError: (_) {});
    _saveErrors();
    _recordCompletion();
    _loadUpsell();
    widget.analyticsService.practiceCompleted(
      topicId: widget.topic.id.name,
      questionCount: widget.result.totalCount,
    );
  }

  Future<void> _loadUpsell() async {
    bool show;
    try {
      final hasFullAccess = await widget.subscriptionService.hasFullAccess;
      show = !hasFullAccess &&
          await widget.storageService.getFreePracticeCountForToday() >=
              StorageService.freeDailyPracticeLimit;
    } catch (_) {
      show = false;
    }
    if (!show || !mounted) return;
    setState(() => _showUpsell = true);
    widget.analyticsService.practiceResultUpsellViewed();
  }

  void _backToTopics() => Navigator.of(context).popUntil((r) => r.isFirst);

  void _openPremium() {
    widget.analyticsService.practiceResultUpsellTapped();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          analyticsSource: AnalyticsService.paywallSourcePracticeResult,
          subscriptionService: widget.subscriptionService,
        ),
      ),
    );
  }

  Future<void> _recordCompletion() async {
    final answered = widget.result.totalCount - widget.result.skippedCount;
    try {
      await widget.storageService
          .recordPracticeCompletion(widget.topic.id.name, answered);
    } catch (_) {
      // Best-effort: the home screen's practiced count would just be a
      // session behind, not worth surfacing an error for over the results
      // the user is actually here to see.
    }
  }

  Future<void> _saveErrors() async {
    final now = DateTime.now();
    final entries = widget.result.feedback
        .where((f) => !f.isCorrect && !f.isSkipped && f.errorType != null)
        .map((f) => ErrorEntry(
              topicId: widget.topic.id.name,
              errorType: f.errorType!,
              timestamp: now,
              prompt: widget.practiceSet.items
                  .firstWhere((item) => item.id == f.itemId)
                  .fullText,
              userAnswer: widget.answers[f.itemId],
              correctedAnswer: f.correctedAnswer,
              explanation: f.explanation,
              rule: f.rule,
              source: ErrorSource.topicPractice,
              userBlanks: widget.blankAnswers[f.itemId],
              summary: f.summary,
              blankFeedback: f.blanks,
            ))
        .toList();
    if (entries.isEmpty) return;
    try {
      await widget.storageService.insertErrors(entries);
    } catch (e) {
      // Don't let a storage failure pass silently — without this the Review
      // tab looks broken later with no clue why (errors were never recorded).
      if (!mounted) return;
      AppMessenger.show(context.l10n.resultsSaveFailed('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final itemsById = {
      for (final item in widget.practiceSet.items) item.id: item,
    };
    final scoreText = result.skippedCount > 0
        ? l10n.resultsScoreSkipped(
            result.correctCount, result.totalCount, result.skippedCount)
        : l10n.resultsScore(result.correctCount, result.totalCount);
    return BrandScaffold(
      title: PageTitle(l10n.resultsTitle),
      bottomBar: BrandBottomBar(
        key: ResultsScreen.footerKey,
        child: PressableButton(
          label: l10n.resultsBackToTopics,
          tone: ButtonTone.navy,
          haptic: ButtonHaptic.light,
          onPressed: _backToTopics,
        ),
      ),
      children: [
        // V21: the companion cheers beside the score.
        Row(children: [
          CompanionView(
              hero: _hero ?? Avatar.fox,
              mood: CompanionMood.cheer,
              size: 76,
              decorative: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  label: scoreText,
                  child: ExcludeSemantics(
                    child: Text(
                      l10n.practiceResultsCorrect(
                          result.correctCount, result.totalCount),
                      style: theme.textTheme.headlineMedium!
                          .withWeight(FontWeight.w900)
                          .copyWith(color: c.text),
                    ),
                  ),
                ),
                if (result.skippedCount > 0)
                  ExcludeSemantics(
                    child: Text(scoreText,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: c.muted)),
                  ),
                Text(widget.topic.title(l10n),
                    style: theme.textTheme.labelLarge!
                        .withWeight(FontWeight.w800)
                        .copyWith(color: c.orangeDeep)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 18),
        for (final (i, item) in result.feedback.indexed) ...[
          // Feedback cards come in from below, 60 ms apart.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: AppMotion.reduced(context) ? 1 : 0, end: 1),
            duration: AppMotion.orInstant(
                context, AppMotion.slow + AppMotion.stagger * i),
            curve: Interval(
                (AppMotion.stagger.inMilliseconds * i) /
                    (AppMotion.slow.inMilliseconds +
                        AppMotion.stagger.inMilliseconds * i),
                1,
                curve: AppMotion.enter),
            builder: (context, t, child) => Opacity(
              opacity: t,
              child: Transform.translate(
                  offset: Offset(0, 24 * (1 - t)), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: lipCard(c, radius: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Verdict(
                    skipped: item.isSkipped,
                    correct: item.isCorrect,
                  ),
                  const SizedBox(height: 12),
                  MistakeBreakdown(
                    prompt: itemsById[item.itemId]?.fullText,
                    userAnswer: widget.answers[item.itemId],
                    blankAnswers: widget.blankAnswers[item.itemId],
                    correctedAnswer: item.correctedAnswer,
                    explanation: item.explanation,
                    blankFeedback: item.blanks,
                    summary: item.summary,
                  ),
                  if (item.rule != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      humanizeSlug(item.rule!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: c.muted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        // Free user out of today's practice (V21): another round is
        // Premium's.
        if (_showUpsell)
          Container(
            key: const ValueKey('results_more_premium'),
            padding: const EdgeInsets.all(16),
            decoration:
                lipCard(c, color: c.goldSoft, border: c.gold, lip: c.goldDeep),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  CompanionView(
                      hero: _hero ?? Avatar.fox,
                      // V21's board: the base pose (fix round 3, B8).
                      mood: CompanionMood.idle,
                      size: 48,
                      decorative: true),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.practiceResultsMore,
                            style: theme.textTheme.titleSmall!
                                .withWeight(FontWeight.w900)
                                .copyWith(color: c.text)),
                        Text(
                            l10n.practiceResultsMoreLine(
                                StorageService.dailySessionLimit),
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: c.muted)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                PressableButton(
                  label: l10n.reviewSeePremium,
                  tone: ButtonTone.orange,
                  height: 50,
                  haptic: ButtonHaptic.medium,
                  onPressed: _openPremium,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A feedback card's verdict (V21): Correct (green), Needs work (orange)
/// or Skipped (grey), with its icon.
class _Verdict extends StatelessWidget {
  final bool skipped;
  final bool correct;
  const _Verdict({required this.skipped, required this.correct});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final (bg, fg, icon, text) = skipped
        ? (
            c.track,
            c.muted,
            Icons.remove_circle_outline_rounded,
            l10n.resultSkipped
          )
        : correct
            ? (
                c.greenSoft,
                c.onGreenSoft,
                Icons.check_circle_rounded,
                l10n.resultCorrect
              )
            : (
                c.orangeSoft,
                c.orangeDeep,
                Icons.error_rounded,
                l10n.resultNeedsWork
              );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: fg),
        const SizedBox(width: 6),
        Flexible(
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: fg)),
        ),
      ]),
    );
  }
}
