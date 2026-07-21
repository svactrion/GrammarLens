import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/error_entry.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/text_format.dart';
import 'weak_spot_detail_screen.dart';

/// Resurfaces the user's weak spots and lets them launch a freshly
/// generated set targeting the same error type (PRD §4 step 5 — the
/// differentiator: revision without rewriting).
class ReviewScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final bool active;

  const ReviewScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.active,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<WeakSpot>> _weakSpots;

  @override
  void initState() {
    super.initState();
    _weakSpots = widget.storageService.getWeakSpots();
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
      _weakSpots = widget.storageService.getWeakSpots();
    });
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
        ),
      ),
    );
    _reloadWeakSpots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
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
                    const Icon(Icons.error_outline, size: 40),
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
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No weak spots yet. Complete a practice set to '
                  'start building your error profile.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: spots.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final spot = spots[index];
              final topic = kTopics.firstWhere(
                (t) => t.id.name == spot.topicId,
                orElse: () => kTopics.first,
              );
              return Card(
                child: ListTile(
                  title: Text(humanizeSlug(spot.errorType)),
                  subtitle: Text('${topic.title} · seen ${spot.frequency}x'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openWeakSpot(spot),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
