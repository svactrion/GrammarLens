import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/practice_set.dart';
import '../models/scoring_result.dart';
import '../models/topic.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';

class ResultsScreen extends StatefulWidget {
  final Topic topic;
  final ScoringResult result;
  final PracticeSet practiceSet;
  final Map<String, String> answers;
  final StorageService storageService;

  const ResultsScreen({
    super.key,
    required this.topic,
    required this.result,
    required this.practiceSet,
    required this.answers,
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
        .where((f) =>
            !f.isCorrect &&
            f.errorType != null &&
            !nonGrammarErrorTypes.contains(f.errorType))
        .map((f) => ErrorEntry(
              topicId: widget.topic.id.name,
              errorType: f.errorType!,
              timestamp: now,
              prompt: widget.practiceSet.items
                  .firstWhere((item) => item.id == f.itemId)
                  .prompt,
              userAnswer: widget.answers[f.itemId],
              correctedAnswer: f.correctedAnswer,
              explanation: f.explanation,
              rule: f.rule,
            ))
        .toList();
    if (entries.isEmpty) return;
    try {
      await widget.storageService.insertErrors(entries);
    } catch (e) {
      // Don't let a storage failure pass silently — without this the Review
      // tab looks broken later with no clue why (errors were never recorded).
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not save this to your error profile: $e');
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
