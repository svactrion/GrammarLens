import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/text_format.dart';
import 'practice_launch.dart';

/// Shown before targeted practice starts (Iteration 1 P0, from user testing:
/// tapping a weak spot used to jump straight into fresh questions with no
/// reminder of what was actually wrong). Summarizes the rule, how often it's
/// come up, and recent mistakes, then hands off to the same generation path
/// as every other practice launch.
class WeakSpotDetailScreen extends StatefulWidget {
  final Topic topic;
  final WeakSpot spot;
  final ClaudeService claudeService;
  final StorageService storageService;

  const WeakSpotDetailScreen({
    super.key,
    required this.topic,
    required this.spot,
    required this.claudeService,
    required this.storageService,
  });

  @override
  State<WeakSpotDetailScreen> createState() => _WeakSpotDetailScreenState();
}

class _WeakSpotDetailScreenState extends State<WeakSpotDetailScreen> {
  late Future<List<ErrorEntry>> _mistakes;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _mistakes = _loadMistakes();
  }

  Future<List<ErrorEntry>> _loadMistakes() {
    return widget.storageService.getRecentMistakes(
      widget.spot.topicId,
      widget.spot.errorType,
    );
  }

  void _reloadMistakes() {
    setState(() {
      _mistakes = _loadMistakes();
    });
  }

  Future<void> _practice() {
    return launchPracticeSet(
      context: context,
      topic: widget.topic,
      claudeService: widget.claudeService,
      storageService: widget.storageService,
      setGenerating: (value) {
        if (mounted) setState(() => _generating = value);
      },
      errorPrefix: 'Could not generate review set',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ruleTitle = humanizeSlug(widget.spot.errorType);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.topic.title)),
      body: _generating
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  formatFrequencyStat(widget.spot.frequency, widget.spot.lastSeen),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ruleTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<ErrorEntry>>(
                  future: _mistakes,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Could not load your recent mistakes.\n${snapshot.error}',
                          ),
                          const SizedBox(height: 8),
                          FilledButton(
                            onPressed: _reloadMistakes,
                            child: const Text('Retry'),
                          ),
                        ],
                      );
                    }
                    final mistakes = snapshot.data ?? const <ErrorEntry>[];
                    final recap = mistakes.isNotEmpty
                        ? (mistakes.first.explanation ?? mistakes.first.rule)
                        : null;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  recap ??
                                      'You\'ve had trouble with $ruleTitle in '
                                          '${widget.topic.title}. Practicing it '
                                          'again will help reinforce it.',
                                  style: theme.textTheme.bodyLarge,
                                ),
                                if (mistakes.isNotEmpty &&
                                    mistakes.first.rule != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    mistakes.first.rule!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Recent mistakes',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        if (mistakes.isEmpty)
                          const Text(
                            'No detailed history stored for these mistakes yet.',
                          )
                        else
                          for (final mistake in mistakes) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (mistake.prompt != null)
                                      Text(mistake.prompt!),
                                    if (mistake.userAnswer != null &&
                                        mistake.userAnswer!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text('You wrote: ${mistake.userAnswer}'),
                                    ],
                                    if (mistake.correctedAnswer != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Corrected: ${mistake.correctedAnswer}',
                                      ),
                                    ],
                                    if (mistake.explanation != null) ...[
                                      const SizedBox(height: 4),
                                      Text(mistake.explanation!),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _practice,
                  child: const Text('Practice this'),
                ),
              ],
            ),
    );
  }
}
