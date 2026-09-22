import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/practice_set.dart';
import '../models/scoring_result.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/app_messenger.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/mistake_breakdown.dart';
import '../widgets/premium_offer_card.dart';
import '../widgets/result_score_band.dart';
import 'premium_screen.dart';

class ResultsScreen extends StatefulWidget {
  final Topic topic;
  final ScoringResult result;
  final PracticeSet practiceSet;
  final Map<String, String> answers;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  const ResultsScreen({
    super.key,
    required this.topic,
    required this.result,
    required this.practiceSet,
    required this.answers,
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

  @override
  void initState() {
    super.initState();
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
            ))
        .toList();
    if (entries.isEmpty) return;
    try {
      await widget.storageService.insertErrors(entries);
    } catch (e) {
      // Don't let a storage failure pass silently — without this the Review
      // tab looks broken later with no clue why (errors were never recorded).
      if (!mounted) return;
      AppMessenger.show('Could not save this to your error profile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final theme = Theme.of(context);
    final semantic = theme.extension<SemanticColors>()!;
    final itemsById = {
      for (final item in widget.practiceSet.items) item.id: item,
    };
    final scoreText = result.skippedCount > 0
        ? '${result.correctCount}/${result.totalCount} correct '
            '· ${result.skippedCount} skipped'
        : '${result.correctCount}/${result.totalCount} correct';
    return BrandScaffold(
      title: const PageTitle('Results'),
      bandBottom: ResultScoreBand(text: scoreText),
      children: [
        for (final item in result.feedback) ...[
          Card(
            color: item.isSkipped
                ? semantic.skippedBackground
                : item.isCorrect
                    ? semantic.correctBackground
                    : semantic.incorrectBackground,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        item.isSkipped
                            ? Icons.remove_circle_outline_rounded
                            : item.isCorrect
                                ? Icons.check_circle_rounded
                                : Icons.cancel_rounded,
                        size: 20,
                        color: item.isSkipped
                            ? semantic.onSkippedBackground
                            : item.isCorrect
                                ? semantic.onCorrectBackground
                                : semantic.onIncorrectBackground,
                      ),
                      const SizedBox(width: 8),
                      // Flexible: at 320 pt with Large text and a 2.0 system
                      // scale the label is wider than the card and would
                      // overflow; it wraps instead.
                      Flexible(
                        child: Text(
                          item.isSkipped
                              ? 'Skipped'
                              : item.isCorrect
                                  ? 'Correct'
                                  : 'Needs work',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: item.isSkipped
                                ? semantic.onSkippedBackground
                                : item.isCorrect
                                    ? semantic.onCorrectBackground
                                    : semantic.onIncorrectBackground,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  MistakeBreakdown(
                    prompt: itemsById[item.itemId]?.fullText,
                    userAnswer: widget.answers[item.itemId],
                    correctedAnswer: item.correctedAnswer,
                    explanation: item.explanation,
                  ),
                  if (item.rule != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      humanizeSlug(item.rule!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        // Free user out of today's practice: the offer card, then "Back to
        // topics" as a secondary button under it. Everyone else: "Back to
        // topics" is the screen's only action, so it stays the filled one.
        if (_showUpsell) ...[
          PremiumOfferCard(onSeePremium: _openPremium),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _backToTopics,
              child: const Text('Back to topics'),
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _backToTopics,
              child: const Text('Back to topics'),
            ),
          ),
        ],
      ],
    );
  }
}
