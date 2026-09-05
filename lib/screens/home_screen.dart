import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/avatar.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import '../models/review_sort_order.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/daily_test_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/answer_matching.dart';
import '../utils/layout_constants.dart';
import '../utils/text_format.dart';
import '../widgets/avatar_tile.dart';
import 'daily_test_result_screen.dart';
import 'daily_test_screen.dart';
import 'premium_screen.dart';
import 'topic_practice_screen.dart';
import 'weak_spot_detail_screen.dart';

/// Home as a "today" screen, not a menu (PRD v2 §13.5). Replaces the old
/// mode-selection Home once Streak Mode and Voice Practice were removed and
/// left it looking empty — refilling that space with cards for features
/// that don't exist would repeat exactly the mistake removing them fixed
/// (docs/design-audit.md). The actual problem was that Home already had
/// real data (today's Daily Test state, the error profile) and showed none
/// of it; this screen shows it instead.
class HomeScreen extends StatefulWidget {
  final String userName;
  final Avatar? avatar;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;
  // Nullable, same as ReviewScreen's `onGoToPractice`: the bottom-nav tab
  // switch lives in app.dart's State, not here, so this is a hook rather
  // than HomeScreen owning navigation itself.
  final VoidCallback? onAvatarTap;

  HomeScreen({
    super.key,
    required this.userName,
    this.avatar,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    SubscriptionService? subscriptionService,
    this.onAvatarTap,
  }) : subscriptionService = subscriptionService ?? SubscriptionService();

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Starts closed rather than "unknown/loading" — PRD v2 §12.2's default
  // for anyone not confirmed to have a trial/subscription is Free, and
  // fail-closed here matches SubscriptionService.hasFullAccess's own
  // fail-closed default (never grant access nobody paid for while a check
  // is still in flight).
  bool _hasFullAccess = false;

  bool _loadingToday = true;
  DailyTestSet? _todaysDailyTest;

  bool _loadingWeakSpots = true;
  List<WeakSpot> _weakSpots = const [];

  @override
  void initState() {
    super.initState();
    _checkAccess();
    // Live updates (PRD v2 §12.3/§12.6): a trial starting or expiring
    // should re-gate Topic Practice and the weak-spot rows without
    // requiring an app restart — this is what actually delivers that, not
    // [_checkAccess]'s one-shot read above (which only covers this
    // screen's own initial build).
    widget.subscriptionService.addAccessListener(_onAccessChanged);
    _loadTodaysDailyTest();
    _loadWeakSpots();
  }

  @override
  void dispose() {
    widget.subscriptionService.removeAccessListener(_onAccessChanged);
    super.dispose();
  }

  Future<void> _checkAccess() async {
    final hasAccess = await widget.subscriptionService.hasFullAccess;
    if (!mounted) return;
    setState(() => _hasFullAccess = hasAccess);
  }

  void _onAccessChanged(bool hasFullAccess) {
    if (!mounted) return;
    setState(() => _hasFullAccess = hasFullAccess);
  }

  /// Reads whatever today's Daily Test state already is — never triggers
  /// generation itself (that's DailyTestService.getTodaysSet's job, only
  /// called once the user actually opens Daily Test). Fails open to "not
  /// started" on a storage error, same posture as every other best-effort
  /// read in this app (theme, profile, session cap).
  Future<void> _loadTodaysDailyTest() async {
    try {
      final set = await widget.storageService.getDailyTestSetForToday();
      if (!mounted) return;
      setState(() {
        _todaysDailyTest = set;
        _loadingToday = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _todaysDailyTest = null;
        _loadingToday = false;
      });
    }
  }

  /// The 2-3 most frequent weak spots (PRD v2 §13.5 item 4) — same
  /// aggregation ReviewScreen's own "Most frequent" sort already reads,
  /// just capped tighter. Fails open to an empty list on a storage error,
  /// which reads identically to "no weak spots yet" — the section simply
  /// doesn't render either way (see build()).
  Future<void> _loadWeakSpots() async {
    try {
      final spots = await widget.storageService.getWeakSpots(
        limit: 3,
        sortOrder: ReviewSortOrder.frequent,
      );
      if (!mounted) return;
      setState(() {
        _weakSpots = spots;
        _loadingWeakSpots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weakSpots = const [];
        _loadingWeakSpots = false;
      });
    }
  }

  void _openDailyTest(BuildContext context) {
    widget.analyticsService.modeSelected(AnalyticsService.modeDailyTest);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DailyTestScreen(
              dailyTestService: DailyTestService(
                claudeService: widget.claudeService,
                storageService: widget.storageService,
              ),
            ),
          ),
        )
        .then((_) => _loadTodaysDailyTest());
  }

  /// Replays the already-completed set through the same result screen a
  /// live finish would reach — reusing it rather than a second "summary"
  /// screen. [DailyTestResultScreen] itself skips re-marking completion
  /// when the set it's given is already completed (see its own doc
  /// comment), so viewing this again doesn't re-write anything.
  void _openDailyTestResult(BuildContext context, DailyTestSet set) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyTestResultScreen(
          dailyTestSet: set,
          answers: set.answers ?? const {},
          dailyTestService: DailyTestService(
            claudeService: widget.claudeService,
            storageService: widget.storageService,
          ),
        ),
      ),
    );
  }

  void _openTopicPractice(BuildContext context) {
    // Gated by entitlement (PRD v2 §12.2/§12.3): free tier doesn't include
    // Topic Practice at all — a locked tap goes to the Premium screen
    // instead of ever reaching the real screen, same "no fake it"
    // reasoning as the daily session cap already applies to generation
    // itself.
    if (!_hasFullAccess) {
      _openPremium(context);
      return;
    }
    widget.analyticsService.modeSelected(AnalyticsService.modeTopic);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TopicPracticeScreen(
              claudeService: widget.claudeService,
              storageService: widget.storageService,
              analyticsService: widget.analyticsService,
            ),
          ),
        )
        .then((_) => _loadWeakSpots());
  }

  /// Unlocked: opens the same weak-spot detail flow Review uses. Locked:
  /// opens the Premium screen naming this specific weak spot — the first
  /// real caller of [PremiumScreen.sourceContext] (added in B-structure-1,
  /// unused until now).
  void _openWeakSpot(BuildContext context, WeakSpot spot) {
    if (!_hasFullAccess) {
      _openPremium(context, sourceContext: humanizeSlug(spot.errorType));
      return;
    }
    final topic = kTopics.firstWhere(
      (t) => t.id.name == spot.topicId,
      orElse: () => kTopics.first,
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => WeakSpotDetailScreen(
              topic: topic,
              spot: spot,
              claudeService: widget.claudeService,
              storageService: widget.storageService,
              analyticsService: widget.analyticsService,
            ),
          ),
        )
        .then((_) => _loadWeakSpots());
  }

  /// Single entry point to the merged Premium screen (PRD v2 §13.1) —
  /// reached from the locked Topic Practice card, a locked weak-spot row,
  /// or the quiet Premium row below. Logs the same `mode_selected` event
  /// every time now that all three land on the same screen.
  void _openPremium(BuildContext context, {String? sourceContext}) {
    widget.analyticsService.modeSelected(AnalyticsService.modePremium);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          subscriptionService: widget.subscriptionService,
          sourceContext: sourceContext,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          'GrammarLens',
          style: theme.textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: appBarFg,
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, navBarClearance),
        children: [
          // PRD v2 §11: an avatar next to the greeting, not floating
          // elsewhere on the page, so it reads as "whose home screen this
          // is" rather than a decorative icon. Greeting leads on the left,
          // avatar pinned to the far right edge (trailing, not centered
          // against the text) — `spaceBetween` with a `Flexible` (not
          // `Expanded`) text so the avatar always lands flush against the
          // trailing edge regardless of how short the greeting is, while a
          // long name still truncates instead of pushing the avatar off
          // the visible row.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  'Welcome back, ${widget.userName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: appBarFg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // PRD v2 §11's natural follow-up: the avatar is the user's
              // own identity marker, and Settings is where it (and the
              // rest of the profile) is edited — tapping it jumps there
              // directly instead of requiring the Settings tab first.
              InkWell(
                // Matches AvatarTile's own corner rounding at radius: 22
                // (radius * 0.6) — a circular ripple would visibly mismatch
                // the tile's now-square shape.
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
                onTap: widget.onAvatarTap,
                child: AvatarTile(avatar: widget.avatar, radius: 22),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Today'),
          const SizedBox(height: 8),
          _TodayCard(
            loading: _loadingToday,
            dailyTestSet: _todaysDailyTest,
            onStart: () => _openDailyTest(context),
            onViewResult: (set) => _openDailyTestResult(context, set),
          ),
          const SizedBox(height: 24),
          _PracticeModeCard(
            icon: Icons.school_rounded,
            title: 'Topic Practice',
            description: _hasFullAccess
                ? 'Deep grammar practice with plain-language feedback.'
                : 'Try it free for ${SubscriptionService.trialLengthDays} '
                    'days, then continue with a subscription.',
            locked: !_hasFullAccess,
            onTap: () => _openTopicPractice(context),
          ),
          // Deliberately no empty state here (PRD v2 §13.5 item 4) — the
          // Review tab already covers "no weak spots yet", and repeating
          // that message on Home too would just be noise on a screen
          // that's supposed to lead with what's actually there.
          if (!_loadingWeakSpots && _weakSpots.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Your weak spots'),
            const SizedBox(height: 8),
            for (final spot in _weakSpots) ...[
              _WeakSpotRow(
                topic: kTopics.firstWhere(
                  (t) => t.id.name == spot.topicId,
                  orElse: () => kTopics.first,
                ),
                spot: spot,
                locked: !_hasFullAccess,
                onTap: () => _openWeakSpot(context, spot),
              ),
              if (spot != _weakSpots.last) const SizedBox(height: 10),
            ],
          ],
          // Quiet by design (PRD v2 §13.5 item 5) — a plain row, not the
          // solid-fill banner this used to be, and only for a free user:
          // someone already on a trial or subscribed doesn't need the
          // upsell repeated at them. Must never outweigh the Today card
          // above, which is why this has no Card/fill of its own.
          if (!_hasFullAccess) ...[
            const SizedBox(height: 8),
            _PremiumRow(onTap: () => _openPremium(context)),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// The largest, topmost block (PRD v2 §13.5 item 2) — Daily Test's actual
/// state, read from what's already cached rather than a new tracking
/// mechanism: [DailyTestSet.completedAt] (has today's test been finished)
/// and [DailyTestSet.answers] (what the score was, persisted alongside it
/// — see docs/build-log.md for why that had to be added). Shares
/// `_PracticeModeCard`'s icon+title+description card shape rather than
/// inventing a new one; taller than that card simply because it carries
/// more content, not a different visual treatment.
class _TodayCard extends StatelessWidget {
  final bool loading;
  final DailyTestSet? dailyTestSet;
  final VoidCallback onStart;
  final ValueChanged<DailyTestSet> onViewResult;

  const _TodayCard({
    required this.loading,
    required this.dailyTestSet,
    required this.onStart,
    required this.onViewResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final set = dailyTestSet;
    final completed = set != null && set.isCompleted;

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    String title;
    String description;
    if (completed) {
      final score = computeDailyTestScore(set.questions, set.answers ?? {});
      title = 'Today\'s test: ${score.correct}/${score.total} correct';
      description = 'New test tomorrow. Tap to see today\'s result again.';
    } else {
      title = 'Daily Test';
      description = "Today's 5-question warm-up is ready — free, always.";
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: completed ? () => onViewResult(set) : onStart,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Icon(
                  completed ? Icons.check_circle_rounded : Icons.today_rounded,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single mode-selection card: a full-width row rather than the
/// icon-on-top grid tile this used to be alongside Streak Mode and Voice
/// Practice — with only one real mode left, a lone icon-on-top tile in a
/// now-empty 2-column grid would read as a layout bug, not a deliberate
/// choice.
class _PracticeModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  // Same lock-icon visual language the old Voice Practice grid tile used
  // (muted icon-avatar fill + a small lock glyph) before Streak/Voice were
  // removed from Home — reused here for Topic Practice's entitlement gate
  // (PRD v2 §12.2/§12.3) rather than inventing a new "locked" treatment.
  final bool locked;
  final VoidCallback onTap;

  const _PracticeModeCard({
    required this.icon,
    required this.title,
    required this.description,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final iconBg =
        locked ? colorScheme.surfaceContainerHighest : colorScheme.primaryContainer;
    final iconFg = locked ? muted : colorScheme.onPrimaryContainer;

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
                backgroundColor: iconBg,
                foregroundColor: iconFg,
                child: Icon(icon, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: locked ? muted : null,
                            ),
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_rounded, size: 16, color: muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style:
                          theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of Home's 2-3 most frequent weak spots (PRD v2 §13.5 item 4) —
/// deliberately the same card shape ReviewScreen's own list already uses
/// (explanation as the lead line, topic/error-type + frequency stat below)
/// rather than a condensed variant, so this reads as "the same weak spot
/// you'd see in Review", not a different summary of it. [locked] reuses
/// `_PracticeModeCard`'s lock-badge treatment for the same reason.
class _WeakSpotRow extends StatelessWidget {
  final Topic topic;
  final WeakSpot spot;
  final bool locked;
  final VoidCallback onTap;

  const _WeakSpotRow({
    required this.topic,
    required this.spot,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            spot.latestExplanation ??
                                humanizeSlug(spot.errorType),
                            style: theme.textTheme.bodyLarge,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (locked) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_rounded, size: 16, color: muted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${topic.title} · ${humanizeSlug(spot.errorType)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formatFrequencyStat(spot.frequency, spot.lastSeen),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet single-line row (PRD v2 §13.5 item 5) — deliberately not a
/// Card, not filled, no elevation, so it can never outweigh the Today
/// card or Topic Practice above it. Replaces what used to be a solid
/// deep-blue banner; that treatment made sense when Premium was one of
/// only three things on the screen; it doesn't once Home actually leads
/// with real data. Only shown to a user without full access — see the
/// build() call site.
class _PremiumRow extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, size: 18, color: muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Premium',
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: muted),
          ],
        ),
      ),
    );
  }
}
