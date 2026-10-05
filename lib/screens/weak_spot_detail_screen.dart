import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/loading_view.dart';
import '../utils/page_title.dart';
import '../utils/premium_copy.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_title.dart';
import '../widgets/mistake_breakdown.dart';
import 'practice_launch.dart';
import 'premium_screen.dart';
import '../theme.dart';

/// Shown before targeted practice starts (Iteration 1 P0, from user testing:
/// tapping a weak spot used to jump straight into fresh questions with no
/// reminder of what was actually wrong). Summarizes the rule, how often it's
/// come up, and recent mistakes, then hands off to the same generation path
/// as every other practice launch.
class WeakSpotDetailScreen extends StatefulWidget {
  final Topic topic;
  final WeakSpot spot;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  const WeakSpotDetailScreen({
    super.key,
    required this.topic,
    required this.spot,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
  });

  @override
  State<WeakSpotDetailScreen> createState() => _WeakSpotDetailScreenState();
}

class _WeakSpotDetailScreenState extends State<WeakSpotDetailScreen> {
  late Future<List<ErrorEntry>> _mistakes;
  bool _generating = false;

  // Starts closed/zero the same way HomeScreen's own `_hasFullAccess` does
  // (fail-closed default while a check is in flight) — this screen only
  // needs a one-shot read, not HomeScreen's addAccessListener live-update
  // wiring: `launchPracticeSet` re-checks both entitlement and quota fresh
  // at the moment of the actual tap regardless, so a value that's gone
  // stale during the brief time this screen is open is a cosmetic risk,
  // not an enforcement one.
  bool _loadingAccess = true;
  bool _hasFullAccess = false;
  int _freePracticeUsedToday = 0;

  @override
  void initState() {
    super.initState();
    _mistakes = _loadMistakes();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    bool hasFullAccess;
    try {
      hasFullAccess = await widget.subscriptionService.hasFullAccess;
    } catch (_) {
      hasFullAccess = false;
    }
    var usedToday = 0;
    if (!hasFullAccess) {
      try {
        usedToday = await widget.storageService.getFreePracticeCountForToday();
      } catch (_) {
        usedToday = 0;
      }
    }
    if (!mounted) return;
    setState(() {
      _hasFullAccess = hasFullAccess;
      _freePracticeUsedToday = usedToday;
      _loadingAccess = false;
    });
  }

  Future<List<ErrorEntry>> _loadMistakes() {
    return widget.storageService.getRecentMistakes(
      widget.spot.topicId,
      widget.spot.errorType,
    );
  }

  void _reloadMistakes() {
    setState(() {
      _mistakes = _loadMistakes();
    });
  }

  Future<void> _practice() {
    return launchPracticeSet(
      context: context,
      topic: widget.topic,
      claudeService: widget.claudeService,
      storageService: widget.storageService,
      analyticsService: widget.analyticsService,
      subscriptionService: widget.subscriptionService,
      setGenerating: (value) {
        if (mounted) setState(() => _generating = value);
      },
      errorPrefix: 'Could not generate review set',
    );
  }

  /// The exhausted-quota row's tap target — same mechanism
  /// `HomeScreen._openWeakSpot` already uses to name what prompted the
  /// paywall, via `PremiumScreen.sourceContext`. Logs the same
  /// "quota → paywall" event `launchPracticeSet`'s own backstop check would
  /// log if this row didn't exist — this is the path that actually fires in
  /// practice, since the row is shown specifically to stop the tap from
  /// ever reaching `launchPracticeSet` in the first place.
  void _openPremium() {
    widget.analyticsService.freePracticeQuotaExhausted();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          analyticsSource: AnalyticsService.paywallSourceWeakSpotQuota,
          subscriptionService: widget.subscriptionService,
          sourceContext: humanizeSlug(widget.spot.errorType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruleTitle = humanizeSlug(widget.spot.errorType);
    // A Daily Test-sourced weak spot stores its topic id as the error type
    // (it has no finer classification), so its humanized rule title *is*
    // the topic title. Same rule as WeakSpotCard's topic subtitle: name the
    // topic once, and drop the rule line and the rule half of the recap
    // sentence when they would only repeat it.
    final ruleRepeatsTopic = ruleTitle == widget.topic.title;
    final theme = Theme.of(context);
    // Not migrated onto BrandScaffold — LoadingView fills the whole screen
    // with its own scaffold-colored background (still the pre-D1 band
    // color everywhere) and is explicitly Batch 3's job, not this one's.
    if (_generating) {
      return Scaffold(
        appBar: AppBar(title: PageTitle(widget.topic.title)),
        body: const LoadingView(message: 'Preparing your questions…'),
      );
    }
    final colorScheme = theme.colorScheme;
    // 1.2.0 (brief, "Review"; Q14: still a pushed screen, restyled): the
    // topic as a small eyebrow, the weak spot's name as the page's title,
    // then its frequency on the info surface. The topic is named once: when
    // the rule title is the topic's own name, the eyebrow is left out.
    return BrandScaffold(
      title: const SizedBox.shrink(),
      children: [
        if (!ruleRepeatsTopic) ...[
          Text(
            widget.topic.title,
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w800)
                .copyWith(color: colorScheme.secondary, letterSpacing: 0.8),
          ),
          const SizedBox(height: 7),
        ],
        Semantics(
          container: true,
          header: true,
          child: Text(
            ruleTitle,
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              formatFrequencyStat(widget.spot.frequency, widget.spot.lastSeen),
              style: theme.textTheme.labelSmall
                  ?.withWeight(FontWeight.w800)
                  .copyWith(color: colorScheme.onSecondaryContainer),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FutureBuilder<List<ErrorEntry>>(
          future: _mistakes,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Could not load your recent mistakes.\n${snapshot.error}',
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _reloadMistakes,
                    child: const Text('Retry'),
                  ),
                ],
              );
            }
            final mistakes = snapshot.data ?? const <ErrorEntry>[];
            final recap = mistakes.isNotEmpty
                ? (mistakes.first.explanation ?? mistakes.first.rule)
                : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The brief's "Saved feedback" panel: the subtle surface with
                // a small link-coloured label above the recorded feedback.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 15, color: colorScheme.secondary),
                          const SizedBox(width: 6),
                          Text(
                            'Saved feedback',
                            style: theme.textTheme.labelMedium
                                ?.withWeight(FontWeight.w800)
                                .copyWith(color: colorScheme.secondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        recap ??
                            (ruleRepeatsTopic
                                ? 'You\'ve had trouble with $ruleTitle. '
                                    'Practicing it again will help '
                                    'reinforce it.'
                                : 'You\'ve had trouble with $ruleTitle in '
                                    '${widget.topic.title}. Practicing it '
                                    'again will help reinforce it.'),
                        style: theme.textTheme.bodyLarge,
                      ),
                      if (mistakes.isNotEmpty &&
                          mistakes.first.rule != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          humanizeSlug(mistakes.first.rule!),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const SectionTitle('Recent mistakes'),
                const SizedBox(height: 12),
                if (mistakes.isEmpty)
                  const EmptyState(
                    icon: Icons.history_toggle_off_rounded,
                    description: 'No detailed history stored for these '
                        'mistakes yet.',
                    dense: true,
                  )
                else
                  for (final mistake in mistakes) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: MistakeBreakdown(
                          prompt: mistake.prompt,
                          userAnswer: mistake.userAnswer,
                          correctedAnswer: mistake.correctedAnswer,
                          explanation: mistake.explanation,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _PracticeAction(
          loadingAccess: _loadingAccess,
          hasFullAccess: _hasFullAccess,
          freePracticeUsedToday: _freePracticeUsedToday,
          onPractice: _practice,
          onLockedTap: _openPremium,
        ),
      ],
    );
  }
}

/// The bottom action, across the three states this screen can be in.
/// Deliberately never hidden, even when the free quota is exhausted — this
/// batch's explicit call — there's always something to tap: either into
/// the practice session, or into Premium.
class _PracticeAction extends StatelessWidget {
  final bool loadingAccess;
  final bool hasFullAccess;
  final int freePracticeUsedToday;
  final VoidCallback onPractice;
  final VoidCallback onLockedTap;

  const _PracticeAction({
    required this.loadingAccess,
    required this.hasFullAccess,
    required this.freePracticeUsedToday,
    required this.onPractice,
    required this.onLockedTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingAccess) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final remaining =
        StorageService.freeDailyPracticeLimit - freePracticeUsedToday;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (!hasFullAccess && remaining <= 0) {
      // Used up today (N3): no free-practice button. The way on is
      // Premium, through the same paywall entry as before, with the same
      // message about today's free practice.
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLockedTap,
              icon: const Icon(Icons.lock_rounded, size: 17),
              label: const Text('Practice with Premium'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            freePracticeUsedMessage,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      );
    }
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPractice,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                      hasFullAccess ? 'Practice this' : 'Start free practice'),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
          ),
        ),
        // Premium has no caption at all — no quota to name (PRD v2 §12.2,
        // and this batch's own "unlimited" ban: the honest thing to say
        // about a premium session here is nothing, not an inflated claim).
        if (!hasFullAccess) ...[
          const SizedBox(height: 10),
          Text(
            '$remaining free practice${remaining == 1 ? '' : 's'} today',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ],
    );
  }
}
