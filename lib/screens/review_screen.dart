import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/error_entry.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import 'practice_screen.dart';

/// Resurfaces the user's weak spots and lets them launch a freshly
/// generated set targeting the same error type (PRD §4 step 5 — the
/// differentiator: revision without rewriting).
class ReviewScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;

  const ReviewScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<WeakSpot>> _weakSpots;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _weakSpots = widget.storageService.getWeakSpots();
  }

  Future<void> _practiceWeakSpot(WeakSpot spot) async {
    final topic = kTopics.firstWhere(
      (t) => t.id.name == spot.topicId,
      orElse: () => kTopics.first,
    );
    setState(() => _generating = true);
    try {
      final practiceSet = await widget.claudeService.generatePracticeSet(topic);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PracticeScreen(
            topic: topic,
            practiceSet: practiceSet,
            claudeService: widget.claudeService,
            storageService: widget.storageService,
          ),
        ),
      );
      setState(() => _weakSpots = widget.storageService.getWeakSpots());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate review set: $e')),
      );
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: _generating
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<List<WeakSpot>>(
              future: _weakSpots,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final spots = snapshot.data!;
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
                    return Card(
                      child: ListTile(
                        title: Text(spot.errorType),
                        subtitle: Text('${spot.topicId} · seen ${spot.frequency}x'),
                        trailing: const Icon(Icons.refresh),
                        onTap: () => _practiceWeakSpot(spot),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
