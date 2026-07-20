import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/scoring_result.dart';
import '../models/topic.dart';
import '../services/storage_service.dart';

class ResultsScreen extends StatefulWidget {
  final Topic topic;
  final ScoringResult result;
  final StorageService storageService;

  const ResultsScreen({
    super.key,
    required this.topic,
    required this.result,
    required this.storageService,
  });

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  @override
  void initState() {
    super.initState();
    _saveErrors();
  }

  Future<void> _saveErrors() async {
    final now = DateTime.now();
    final entries = widget.result.feedback
        .where((f) => !f.isCorrect && f.errorType != null)
        .map((f) => ErrorEntry(
              topicId: widget.topic.id.name,
              errorType: f.errorType!,
              timestamp: now,
            ))
        .toList();
    if (entries.isNotEmpty) {
      await widget.storageService.insertErrors(entries);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${result.correctCount} / ${result.totalCount} correct',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          for (final item in result.feedback) ...[
            Card(
              color: item.isCorrect
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.red.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.isCorrect ? 'Correct' : 'Needs work',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    if (item.rule != null) Text('Rule: ${item.rule}'),
                    Text('Corrected: ${item.correctedAnswer}'),
                    const SizedBox(height: 4),
                    Text(item.explanation),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Back to topics'),
          ),
        ],
      ),
    );
  }
}
