import 'package:flutter/material.dart';

import '../models/error_entry.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/loading_view.dart';
import '../utils/page_title.dart';
import '../utils/text_format.dart';
import '../widgets/empty_state.dart';
import '../widgets/mistake_breakdown.dart';
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
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    return Scaffold(
      appBar: AppBar(title: PageTitle(widget.topic.title)),
      body: _generating
          ? const LoadingView(message: 'Preparing your questions…')
          : ListView(
              padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    formatFrequencyStat(
                        widget.spot.frequency, widget.spot.lastSeen),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  ruleTitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
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
                            padding: const EdgeInsets.all(18),
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
                                  const SizedBox(height: 8),
                                  Text(
                                    humanizeSlug(mistakes.first.rule!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Recent mistakes',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 12),
                        if (mistakes.isEmpty)
                          const EmptyState(
                            icon: Icons.history_toggle_off_rounded,
                            description:
                                'No detailed history stored for these '
                                'mistakes yet.',
                            dense: true,
                          )
                        else
                          for (final mistake in mistakes) ...[
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: MistakeBreakdown(
                                  prompt: mistake.prompt,
                                  userAnswer: mistake.userAnswer,
                                  correctedAnswer: mistake.correctedAnswer,
                                  explanation: mistake.explanation,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _practice,
                    child: const Text('Practice this'),
                  ),
                ),
              ],
            ),
    );
  }
}
