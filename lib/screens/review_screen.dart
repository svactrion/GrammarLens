import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/error_entry.dart';
import '../models/review_sort_order.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import '../widgets/empty_state.dart';
import 'weak_spot_detail_screen.dart';

/// Resurfaces the user's weak spots and lets them launch a freshly
/// generated set targeting the same error type (PRD §4 step 5 — the
/// differentiator: revision without rewriting).
class ReviewScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final bool active;
  final VoidCallback onGoToPractice;

  const ReviewScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.active,
    required this.onGoToPractice,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<WeakSpot>> _weakSpots;
  ReviewSortOrder _sortOrder = ReviewSortOrder.recent;

  @override
  void initState() {
    super.initState();
    _weakSpots = widget.storageService.getWeakSpots(sortOrder: _sortOrder);
    _loadSortOrder();
  }

  Future<void> _loadSortOrder() async {
    // Nothing awaits this call, so an error here would otherwise become an
    // unhandled Future error instead of surfacing in the (already-handled)
    // weak-spots FutureBuilder. Falling back to the default order is a safe
    // failure mode for a preference read — worst case Review just opens
    // sorted by "Recent" instead of remembering the last choice.
    ReviewSortOrder stored;
    try {
      stored = await widget.storageService.getReviewSortOrder();
    } catch (_) {
      return;
    }
    if (!mounted || stored == _sortOrder) return;
    setState(() {
      _sortOrder = stored;
      _weakSpots = widget.storageService.getWeakSpots(sortOrder: stored);
    });
  }

  @override
  void didUpdateWidget(covariant ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _reloadWeakSpots();
    }
  }

  void _reloadWeakSpots() {
    // Block body, NOT `=> _weakSpots = ...`: an arrow body's value is the
    // assignment's value (a Future here), and setState() asserts in debug
    // mode if its callback returns one — "setState() callback argument
    // returned a Future." A block body with the assignment as a statement
    // has no return value, so the assert never sees the Future.
    setState(() {
      _weakSpots = widget.storageService.getWeakSpots(sortOrder: _sortOrder);
    });
  }

  Future<void> _changeSortOrder(ReviewSortOrder order) async {
    if (order == _sortOrder) return;
    setState(() {
      _sortOrder = order;
      _weakSpots = widget.storageService.getWeakSpots(sortOrder: order);
    });
    await widget.storageService.setReviewSortOrder(order);
  }

  Future<void> _openWeakSpot(WeakSpot spot) async {
    final topic = kTopics.firstWhere(
      (t) => t.id.name == spot.topicId,
      orElse: () => kTopics.first,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeakSpotDetailScreen(
          topic: topic,
          spot: spot,
          claudeService: widget.claudeService,
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
        ),
      ),
    );
    _reloadWeakSpots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const PageTitle('Review'),
        actions: [
          PopupMenuButton<ReviewSortOrder>(
            initialValue: _sortOrder,
            onSelected: _changeSortOrder,
            itemBuilder: (context) => ReviewSortOrder.values
                .map(
                  (order) => PopupMenuItem(
                    value: order,
                    child: Text(order.label),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded),
                  const SizedBox(width: 4),
                  Text(_sortOrder.label),
                ],
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<WeakSpot>>(
        future: _weakSpots,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load your error profile.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _reloadWeakSpots,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          final spots = snapshot.data ?? const <WeakSpot>[];
          if (spots.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.fact_check_outlined,
                  title: 'No weak spots yet.',
                  description:
                      'Practice a topic and your mistakes will show up here.',
                  ctaLabel: 'Start practicing',
                  onCta: widget.onGoToPractice,
                ),
              ),
            );
          }
          final width = MediaQuery.sizeOf(context).width;
          final hPad = (width * 0.045).clamp(16.0, 28.0);
          return ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
            itemCount: spots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final spot = spots[index];
              final topic = kTopics.firstWhere(
                (t) => t.id.name == spot.topicId,
                orElse: () => kTopics.first,
              );
              final theme = Theme.of(context);
              return Card(
                child: InkWell(
                  onTap: () => _openWeakSpot(spot),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spot.latestExplanation ??
                                    humanizeSlug(spot.errorType),
                                style: theme.textTheme.bodyLarge,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${topic.title} · ${humanizeSlug(spot.errorType)}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  formatFrequencyStat(
                                    spot.frequency,
                                    spot.lastSeen,
                                  ),
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
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
            },
          );
        },
      ),
    );
  }
}
