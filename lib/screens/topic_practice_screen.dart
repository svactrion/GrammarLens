import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/topic.dart';
import '../models/topic_stats.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/loading_view.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import 'practice_launch.dart';

/// The MVP's original core loop, now one mode reached from the v2 Home
/// mode-selection screen rather than the app's top level (PRD v2 §4) — per-
/// topic progress stats live here instead of on Home.
class TopicPracticeScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;

  const TopicPracticeScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
  });

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
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    return Scaffold(
      appBar: AppBar(title: const PageTitle('Topic Practice')),
      body: _generating
          ? const LoadingView(message: 'Preparing your questions…')
          : FutureBuilder<Map<String, TopicStats>>(
              future: _statsFuture,
              builder: (context, snapshot) {
                final statsByTopic =
                    snapshot.data ?? const <String, TopicStats>{};
                return ListView.separated(
                  padding:
                      EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
                  itemCount: kTopics.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final topic = kTopics[index];
                    final stats =
                        statsByTopic[topic.id.name] ?? TopicStats.empty;
                    return _TopicCard(
                      topic: topic,
                      stats: stats,
                      onTap: () => _startPractice(topic),
                    );
                  },
                );
              },
            ),
    );
  }
}

/// A topic card showing the icon, title, description, and — pulled from the
/// error profile — a small "practiced / weak spots" line with a thin
/// activity bar, so the home screen reflects progress instead of staying a
/// static list.
class _TopicCard extends StatelessWidget {
  final Topic topic;
  final TopicStats stats;
  final VoidCallback onTap;

  const _TopicCard({
    required this.topic,
    required this.stats,
    required this.onTap,
  });

  // Questions-practiced count at which the activity bar reads as "full" —
  // just a visual ceiling for a relative sense of activity, not a real
  // mastery threshold.
  static const _activityCap = 20;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                child: Icon(topic.icon),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topic.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      topic.description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildStatsLine(theme),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsLine(ThemeData theme) {
    final mutedColor = theme.colorScheme.onSurfaceVariant;
    if (!stats.isStarted) {
      return Text(
        'Not started yet',
        style: theme.textTheme.bodySmall?.copyWith(
          color: mutedColor,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final fraction = stats.practiced / _activityCap;
    return Row(
      children: [
        Flexible(
          child: Text(
            formatTopicStatsLine(stats.practiced, stats.weakSpotCount),
            style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: 'Practice activity level',
          child: _ActivityBar(
            fraction: fraction,
            trackColor: theme.colorScheme.outlineVariant,
            fillColor: theme.colorScheme.secondary,
          ),
        ),
      ],
    );
  }
}

/// A small thin bar filled proportionally to practice activity — the
/// "simple attempt metric" progress indicator alongside the stats line.
class _ActivityBar extends StatelessWidget {
  final double fraction;
  final Color trackColor;
  final Color fillColor;

  const _ActivityBar({
    required this.fraction,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        width: 40,
        height: 5,
        child: Stack(
          children: [
            Container(color: trackColor),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(color: fillColor),
            ),
          ],
        ),
      ),
    );
  }
}
