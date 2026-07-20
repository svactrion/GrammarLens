import 'package:flutter/material.dart';

import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import 'results_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Topic topic;
  final PracticeSet practiceSet;
  final ClaudeService claudeService;
  final StorageService storageService;

  const PracticeScreen({
    super.key,
    required this.topic,
    required this.practiceSet,
    required this.claudeService,
    required this.storageService,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final Map<String, String> _answers = {};
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await widget.claudeService.scoreAnswers(
        practiceSet: widget.practiceSet,
        answers: _answers,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultsScreen(
            topic: widget.topic,
            result: result,
            storageService: widget.storageService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not score answers: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _itemLabel(PracticeItemType type) {
    switch (type) {
      case PracticeItemType.fillInBlank:
        return 'Fill in the blank';
      case PracticeItemType.errorCorrection:
        return 'Find and correct the error';
      case PracticeItemType.sentenceWriting:
        return 'Write a sentence';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final item in widget.practiceSet.items) ...[
            Text(_itemLabel(item.type), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(item.prompt, style: Theme.of(context).textTheme.bodyLarge),
            if (item.hint != null) ...[
              const SizedBox(height: 4),
              Text(item.hint!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Your answer',
              ),
              onChanged: (value) => _answers[item.id] = value,
            ),
            const SizedBox(height: 24),
          ],
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
