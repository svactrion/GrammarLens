import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/loading_view.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/locked_premium_pill.dart';
import '../widgets/mistake_breakdown.dart';
import 'practice_launch.dart';
import 'premium_screen.dart';

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
          subscriptionService: widget.subscriptionService,
          sourceContext: humanizeSlug(widget.spot.errorType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruleTitle = humanizeSlug(widget.spot.errorType);
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
    return BrandScaffold(
      title: PageTitle(widget.topic.title),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            formatFrequencyStat(widget.spot.frequency, widget.spot.lastSeen),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          ruleTitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recap ??
                              'You\'ve had trouble with $ruleTitle in '
                                  '${widget.topic.title}. Practicing it '
                                  'again will help reinforce it.',
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (mistakes.isNotEmpty &&
                            mistakes.first.rule != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            humanizeSlug(mistakes.first.rule!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recent mistakes',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
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
    if (!hasFullAccess && remaining <= 0) {
      return _LockedPracticeRow(onTap: onLockedTap);
    }

    final theme = Theme.of(context);
    return Column(
      children: [
        // Premium has no caption at all — no quota to name (PRD v2 §12.2,
        // and this batch's own "unlimited" ban: the honest thing to say
        // about a premium session here is nothing, not an inflated claim).
        if (!hasFullAccess) ...[
          Text(
            '$remaining free practice${remaining == 1 ? '' : 's'} today',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onPractice,
            child: const Text('Practice this'),
          ),
        ),
      ],
    );
  }
}

/// The exhausted-quota state — the exact visual language Home's locked
/// Topic Practice card already uses (`_PracticeModeCard` in
/// home_screen.dart): a muted icon avatar, a muted title, a subtitle
/// explaining why, and the shared [LockedPremiumPill] trailing it. Same
/// widget shape as that card, not a new "locked" treatment invented for
/// this screen. Still a real tap target, not a disabled button — tapping
/// opens Premium instead of generating.
class _LockedPracticeRow extends StatelessWidget {
  final VoidCallback onTap;

  const _LockedPracticeRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.surfaceContainerHighest,
                foregroundColor: muted,
                child: const Icon(Icons.edit_note_rounded, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Practice this',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "You've used today's free practice. Premium unlocks "
                      'Topic Practice and more sessions each day.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LockedPremiumPill(),
            ],
          ),
        ),
      ),
    );
  }
}
