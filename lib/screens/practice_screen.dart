import 'package:flutter/material.dart';

import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';
import '../utils/loading_view.dart';
import '../utils/page_title.dart';
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
            practiceSet: widget.practiceSet,
            answers: Map.of(_answers),
            storageService: widget.storageService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not score answers: $e');
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
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    return Scaffold(
      appBar: AppBar(title: PageTitle(widget.topic.title)),
      body: _submitting
          ? const LoadingView(message: 'Reviewing your answers…')
          : ListView(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
              children: [
                for (final item in widget.practiceSet.items) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _itemLabel(item.type),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (item.context != null &&
                              item.context!.trim().isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Text(item.context!,
                                style: theme.textTheme.bodyLarge),
                            const SizedBox(height: 16),
                            Divider(
                                height: 1,
                                color: theme.colorScheme.outlineVariant),
                            const SizedBox(height: 16),
                          ] else
                            const SizedBox(height: 14),
                          Text(
                            item.instruction,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (item.hint != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              item.hint!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          TextField(
                            decoration:
                                const InputDecoration(hintText: 'Your answer'),
                            onChanged: (value) => _answers[item.id] = value,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
    );
  }
}
