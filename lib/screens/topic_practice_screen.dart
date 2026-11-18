import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../app_colors.dart';
import '../models/review_sort_order.dart';
import '../widgets/home_practice.dart';
import '../widgets/pressable_button.dart';
import '../data/topics.dart';
import '../models/avatar.dart';
import '../models/topic.dart';
import '../models/topic_stats.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/loading_view.dart';
import '../utils/text_format.dart';
import '../theme.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/page_header.dart';
import 'practice_launch.dart';

/// The MVP's original core loop, now one mode reached from the v2 Home
/// mode-selection screen rather than the app's top level (PRD v2 §4) — per-
/// topic progress stats live here instead of on Home.
class TopicPracticeScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  /// Whether the first-wave topics show (SPEC §1.11); by default the
  /// switch, [kFirstWaveTopicsEnabled] (off). Tests set both states.
  final bool firstWaveTopics;

  /// The user's buddy, thinking while questions are prepared (V18).
  final Avatar? hero;

  const TopicPracticeScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
    this.firstWaveTopics = kFirstWaveTopicsEnabled,
    this.hero,
  });

  /// The topic count beside "Grammar topics", the "Premium access" label,
  /// and each topic's card and status line.
  static const topicCountKey = ValueKey('topic_practice_count');
  static const accessLabelKey = ValueKey('topic_practice_access');
  static const pickedKey = ValueKey('topic_practice_picked');
  static ValueKey<String> cardKey(Topic topic) =>
      ValueKey('topic_card_${topic.id.name}');
  static ValueKey<String> statusKey(Topic topic) =>
      ValueKey('topic_status_${topic.id.name}');

  @override
  State<TopicPracticeScreen> createState() => _TopicPracticeScreenState();
}

class _TopicPracticeScreenState extends State<TopicPracticeScreen> {
  bool _generating = false;
  int? _preparingCount;
  Topic? _preparing;
  late Future<Map<String, TopicStats>> _statsFuture;

  /// The topic of the most repeated weak spot ("Picked for you"), or null.
  Topic? _picked;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.storageService.getTopicStats();
    _loadPicked();
  }

  Future<void> _loadPicked() async {
    try {
      final spots = await widget.storageService
          .getWeakSpots(limit: 1, sortOrder: ReviewSortOrder.frequent);
      if (!mounted || spots.isEmpty) return;
      final topic = topicByName(spots.first.topicId);
      if (topic == null) return;
      setState(() => _picked = topic);
    } catch (_) {}
  }

  void _reloadStats() {
    setState(() {
      _statsFuture = widget.storageService.getTopicStats();
    });
  }

  Future<void> _startPractice(Topic topic) {
    _preparing = topic;
    return launchPracticeSet(
      context: context,
      topic: topic,
      claudeService: widget.claudeService,
      storageService: widget.storageService,
      analyticsService: widget.analyticsService,
      subscriptionService: widget.subscriptionService,
      setGenerating: (value) {
        if (mounted) setState(() => _generating = value);
      },
      onQuestionCount: (count) => _preparingCount = count,
      errorPrefix: context.l10n.topicPracticeGenerateFailed,
      // A completed practice set changes this topic's stats (and possibly
      // its weak spots), so refresh the cards once the user is back here.
      onReturned: _reloadStats,
    );
  }

  PreferredSizeWidget get _statusBarOnly => AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // The page's own header stays while the set is generated (final
    // screens A3; was a centred app bar title the page does not have).
    if (_generating) {
      return PageLoading(
        appBar: _statusBarOnly,
        header: _Header(theme: theme),
        message: context.l10n.weakSpotPreparing,
        topic: _preparing,
        hero: widget.hero,
        questionCount: _preparingCount,
      );
    }
    final topics = practiceTopics(firstWave: widget.firstWaveTopics);
    final picked = _picked != null && topics.contains(_picked) ? _picked : null;
    final others = [
      for (final t in topics)
        if (t != picked) t
    ];
    return FutureBuilder<Map<String, TopicStats>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final statsByTopic = snapshot.data ?? const <String, TopicStats>{};
        TopicStats statsOf(Topic t) =>
            statsByTopic[t.id.name] ?? TopicStats.empty;
        return BrandScaffold(
          // The status bar's height only: the back button, the title and
          // its line are in the page (R01).
          appBar: _statusBarOnly,
          children: [
            _Header(theme: theme),
            const SizedBox(height: 18),
            if (picked != null) ...[
              _PickedCard(
                topic: picked,
                onTap: () => _startPractice(picked),
              ),
              const SizedBox(height: 12),
            ],
            // Two topics a row, each row as tall as its taller card.
            for (var r = 0; r < others.length; r += 2) ...[
              if (r > 0) const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = r; i < r + 2; i++) ...[
                      if (i > r) const SizedBox(width: 12),
                      Expanded(
                        child: i < others.length
                            ? FloatingTile(
                                index: i,
                                child: _TopicCard(
                                  topic: others[i],
                                  stats: statsOf(others[i]),
                                  onTap: () => _startPractice(others[i]),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The page header (1.2.0 mockup): the back button and the "Premium
/// access" label on one row, then the title (32 / 900 at Small) and its
/// line.
class _Header extends StatelessWidget {
  final ThemeData theme;

  const _Header({required this.theme});

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            PageBackButton(),
            Spacer(),
            KeyedSubtree(
              key: TopicPracticeScreen.accessLabelKey,
              child: PremiumChip(check: true),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          container: true,
          header: true,
          child: Text(
            context.l10n.featureTopicPractice,
            style: theme.textTheme.headlineLarge
                ?.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.topicPracticeSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// "Picked for you" (R01): the topic of the user's most repeated weak
/// spot, full width, navy.
class _PickedCard extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;
  const _PickedCard({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PressableCard(
      key: TopicPracticeScreen.pickedKey,
      onTap: onTap,
      haptic: ButtonHaptic.light,
      semanticLabel:
          '${l10n.homePickedForYou}. ${topic.title(l10n)}. ${l10n.homePickedLine}',
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: lipCard(c,
            color: c.navy, border: c.navy, lip: c.navyDeep, radius: 22),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(topic.icon, color: c.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.homePickedForYou.toUpperCase(),
                    style: theme.textTheme.labelSmall!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.gold, letterSpacing: 1.1)),
                Text(topic.title(l10n),
                    style: theme.textTheme.titleMedium!
                        .withWeight(FontWeight.w900)
                        .copyWith(color: c.onNavy)),
                Text(l10n.homePickedLine,
                    style: theme.textTheme.labelMedium!
                        .copyWith(color: c.onNavyMuted)),
              ],
            ),
          ),
          Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.arrow_back_rounded
                  : Icons.arrow_forward_rounded,
              color: c.onNavy),
        ]),
      ),
    );
  }
}

/// A topic (R01): its colour, its icon, the title and the real status
/// ("Not started yet", or [formatTopicStatsLine], N18). One tap target that
/// presses 2 pt (light haptic), then the length step.
class _TopicCard extends StatelessWidget {
  final Topic topic;
  final TopicStats stats;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.stats,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final (bg, fg) = topicTileColors(c, topic.id);
    final status = stats.isStarted
        ? formatTopicStatsLine(
            stats.practiced, stats.weakSpotCount, context.l10n)
        : context.l10n.topicPracticeNotStarted;
    return PressableCard(
      key: TopicPracticeScreen.cardKey(topic),
      onTap: onTap,
      haptic: ButtonHaptic.light,
      semanticLabel: '${topic.title(context.l10n)}. $status',
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: lipCard(c, color: bg, border: bg, lip: c.lip, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(topic.icon, color: fg, size: 24),
            const SizedBox(height: 12),
            const Spacer(),
            Text(
              topic.title(context.l10n),
              style: theme.textTheme.titleSmall!
                  .withWeight(FontWeight.w900)
                  .copyWith(color: c.text),
            ),
            const SizedBox(height: 4),
            Text(
              status,
              key: TopicPracticeScreen.statusKey(topic),
              style: theme.textTheme.labelSmall!
                  .withWeight(FontWeight.w700)
                  .copyWith(color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}
