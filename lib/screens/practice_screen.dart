import 'package:flutter/material.dart';

import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/topic.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';
import '../utils/loading_view.dart';
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
  late final Map<String, TextEditingController> _controllers;
  int _currentIndex = 0;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final item in widget.practiceSet.items)
        item.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isLastQuestion =>
      _currentIndex == widget.practiceSet.items.length - 1;

  bool get _currentHasAnswer {
    final item = widget.practiceSet.items[_currentIndex];
    // Same empty/whitespace predicate the scoring path uses to detect a
    // skipped item — the button label must never disagree with what
    // submitting will actually record.
    return (_answers[item.id] ?? '').trim().isNotEmpty;
  }

  void _goBack() {
    if (_currentIndex == 0) return;
    setState(() => _currentIndex--);
  }

  void _advance() {
    if (_isLastQuestion) {
      _submit();
    } else {
      setState(() => _currentIndex++);
    }
  }

  Future<void> _confirmExit() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave practice?'),
        content: const Text('Your progress will be lost.'),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(dialogContext).colorScheme.primary,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onPrimary,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Leave'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

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

  String _primaryLabel() {
    if (_isLastQuestion) return 'Submit';
    return _currentHasAnswer ? 'Next' : 'Skip';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final total = widget.practiceSet.items.length;
    final item = widget.practiceSet.items[_currentIndex];
    final appBarFg = theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return PopScope(
      // The top-left close icon isn't the only way to leave this screen —
      // the system back gesture/button reaches the same route, and would
      // otherwise abandon the session without the confirmation dialog.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave practice',
            onPressed: _confirmExit,
          ),
          title: Text(
            '${_currentIndex + 1}/$total',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, color: appBarFg),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(58),
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
              child: Column(
                children: [
                  Text(
                    widget.topic.title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: appBarFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    // A plain `LinearProgressIndicator` jumps straight to a
                    // new `value` on rebuild; wrapping it lets the fill
                    // animate smoothly to the new fraction each time the
                    // question advances.
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: (_currentIndex + 1) / total,
                      ),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerLow,
                        color: colorScheme.secondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // The question header (context/instruction/hint) and the answer
        // input are split into separate regions on purpose. Putting the
        // TextField at the bottom of one tall scrollable Card meant that
        // when the keyboard opened, Flutter's own "scroll the focused field
        // into view" behaviour had to drag the whole card up to clear the
        // keyboard + button — often scrolling the instruction text half off
        // screen in the process. Keeping the header in its own (rarely
        // scrolling) region and pinning input+button directly above the
        // keyboard means neither one depends on that automatic scroll to
        // stay visible.
        body: _submitting
            ? const LoadingView(message: 'Reviewing your answers…')
            : GestureDetector(
                // Tapping anywhere outside the text field is the standard
                // mobile way to dismiss the keyboard.
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 12),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _itemLabel(item.type),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: colorScheme.secondary,
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
                                      color: colorScheme.outlineVariant),
                                  const SizedBox(height: 16),
                                ] else
                                  const SizedBox(height: 14),
                                Text(
                                  item.instruction,
                                  style: theme.textTheme.bodyLarge
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (item.hint != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.hint!,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
                      child: TextField(
                        key: ValueKey(item.id),
                        controller: _controllers[item.id],
                        decoration:
                            const InputDecoration(hintText: 'Your answer'),
                        onChanged: (value) =>
                            setState(() => _answers[item.id] = value),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                        child: _currentIndex == 0
                            ? SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _advance,
                                  child: Text(_primaryLabel()),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _goBack,
                                      child: const Text('Back'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _advance,
                                      child: Text(_primaryLabel()),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
