import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/topic.dart';
import '../models/topic_stats.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/loading_view.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import '../theme.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/section_title.dart';
import 'practice_launch.dart';

/// The MVP's original core loop, now one mode reached from the v2 Home
/// mode-selection screen rather than the app's top level (PRD v2 §4) — per-
/// topic progress stats live here instead of on Home.
class TopicPracticeScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  const TopicPracticeScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
  });

  /// The topic count beside "Grammar topics", the "Premium access" label,
  /// and each topic's card and status line.
  static const topicCountKey = ValueKey('topic_practice_count');
  static const accessLabelKey = ValueKey('topic_practice_access');
  static ValueKey<String> cardKey(Topic topic) =>
      ValueKey('topic_card_${topic.id.name}');
  static ValueKey<String> statusKey(Topic topic) =>
      ValueKey('topic_status_${topic.id.name}');

  @override
  State<TopicPracticeScreen> createState() => _TopicPracticeScreenState();
}

class _TopicPracticeScreenState extends State<TopicPracticeScreen> {
  bool _generating = false;
  late Future<Map<String, TopicStats>> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = widget.storageService.getTopicStats();
  }

  void _reloadStats() {
    setState(() {
      _statsFuture = widget.storageService.getTopicStats();
    });
  }

  Future<void> _startPractice(Topic topic) {
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
      errorPrefix: 'Could not generate practice',
      // A completed practice set changes this topic's stats (and possibly
      // its weak spots), so refresh the cards once the user is back here.
      onReturned: _reloadStats,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Not migrated onto BrandScaffold — LoadingView fills the whole screen
    // with its own scaffold-colored background (still the pre-D1 band
    // color everywhere) and is explicitly Batch 3's job, not this one's.
    if (_generating) {
      return Scaffold(
        appBar: AppBar(title: const PageTitle('Topic Practice')),
        body: const LoadingView(message: 'Preparing your questions…'),
      );
    }
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, TopicStats>>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final statsByTopic = snapshot.data ?? const <String, TopicStats>{};
        return BrandScaffold(
          // The status bar's height only: the back button, the title and
          // its line are in the page (the 1.2.0 mockup), as on Review.
          appBar: AppBar(
            toolbarHeight: 0,
            automaticallyImplyLeading: false,
            scrolledUnderElevation: 0,
          ),
          children: [
            _Header(theme: theme),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(child: SectionTitle('Grammar topics')),
                const SizedBox(width: 10),
                Text(
                  kTopics.length == 1 ? '1 topic' : '${kTopics.length} topics',
                  key: TopicPracticeScreen.topicCountKey,
                  style: theme.textTheme.labelSmall
                      ?.withWeight(FontWeight.w400)
                      .copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final topic in kTopics) ...[
              _TopicCard(
                topic: topic,
                stats: statsByTopic[topic.id.name] ?? TopicStats.empty,
                onTap: () => _startPractice(topic),
              ),
              if (topic != kTopics.last) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// The page header (1.2.0 mockup): the back button and the "Premium
/// access" label on one row, then the title (32 / 900 at Medium) and its
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
        Row(
          children: [
            // Flutter's own BackButton (its "Back" label and platform icon),
            // drawn as the mockup's 44 pt bordered tile.
            BackButton(
              style: IconButton.styleFrom(
                fixedSize: const Size(44, 44),
                minimumSize: const Size(44, 44),
                backgroundColor: scheme.surfaceContainerHigh,
                foregroundColor: scheme.onSurface,
                side: BorderSide(color: scheme.outlineVariant),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const Spacer(),
            const _AccessLabel(),
          ],
        ),
        const SizedBox(height: 18),
        Semantics(
          container: true,
          header: true,
          child: Text(
            'Topic Practice',
            style: theme.textTheme.headlineLarge
                ?.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose a topic to work on.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// "Premium access" (N19): a status, not a call to action. Nothing here
/// reacts to a tap, and the screen shows no paywall or lock: who may open
/// it is decided before it opens (Home's guard), not by this label.
class _AccessLabel extends StatelessWidget {
  const _AccessLabel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: TopicPracticeScreen.accessLabelKey,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 14, color: scheme.onPrimary),
          const SizedBox(width: 6),
          Text(
            'Premium access',
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w800)
                .copyWith(color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}

/// A topic (1.2.0 mockup): one tap target holding the 38 pt icon tile, the
/// title (17 / 800), the description (13 / 400), the status line (11 / 600)
/// and a chevron. Padding 17 × 15, radius 22. The status is the real one:
/// "Not started yet" with no history, otherwise
/// [formatTopicStatsLine] (N18). Q8: no activity bar.
class _TopicCard extends StatelessWidget {
  final Topic topic;
  final TopicStats stats;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.stats,
    required this.onTap,
  });

  static const _radius = 22.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final cardShape = theme.cardTheme.shape;
    return Card(
      key: TopicPracticeScreen.cardKey(topic),
      margin: EdgeInsets.zero,
      shape: cardShape is RoundedRectangleBorder
          ? cardShape.copyWith(borderRadius: BorderRadius.circular(_radius))
          : RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_radius)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),
          // Top-aligned (docs/design-audit.md, Batch 0 item 9): the icon
          // sits by the title, not the middle of three lines; the chevron
          // is centred on the whole card, as in the mockup.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(topic.icon, size: 20, color: scheme.secondary),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 1),
                      Text(
                        topic.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                            color: scheme.onSurface, letterSpacing: -.25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        topic.description,
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              stats.isStarted
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.circle_outlined,
                              size: 12,
                              color: muted,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              stats.isStarted
                                  ? formatTopicStatsLine(
                                      stats.practiced, stats.weakSpotCount)
                                  : 'Not started yet',
                              key: TopicPracticeScreen.statusKey(topic),
                              style: theme.textTheme.labelSmall
                                  ?.copyWith(color: muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                Center(
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: scheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
