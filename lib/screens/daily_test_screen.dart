import 'package:flutter/material.dart';

import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../models/practice_item.dart';
import '../services/daily_test_service.dart';
import '../utils/error_banner.dart';
import '../utils/loading_view.dart';
import 'daily_test_result_screen.dart';

/// One-question-at-a-time flow over today's cached Daily Test set (PRD v2
/// §12.2, §12.5). Deliberately mirrors PracticeScreen's layout — same
/// progress bar, same split "question header in its own scroll region,
/// answer field + button pinned above the keyboard" structure (a real,
/// hard-won fix for the keyboard covering/dragging the question off screen
/// — see PracticeScreen's body comment — not something worth regressing
/// here just because this is a different flow) — but simpler: no length
/// picker (the set's size is fixed by the data layer) and no submit-time
/// API call, since grading is instant and local
/// ([checkDailyTestAnswer] in DailyTestResultScreen).
class DailyTestScreen extends StatefulWidget {
  final DailyTestService dailyTestService;

  const DailyTestScreen({super.key, required this.dailyTestService});

  @override
  State<DailyTestScreen> createState() => _DailyTestScreenState();
}

class _DailyTestScreenState extends State<DailyTestScreen> {
  final Map<String, String> _answers = {};
  Map<String, TextEditingController>? _controllers;
  DailyTestSet? _dailyTestSet;
  bool _loading = true;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dailyTestSet = await widget.dailyTestService.getTodaysSet();
      if (!mounted) return;
      setState(() {
        _dailyTestSet = dailyTestSet;
        _controllers = {
          for (final question in dailyTestSet.questions)
            question.item.id: TextEditingController(),
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, "Could not load today's test: $e");
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers?.values ??
        const <TextEditingController>[]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool get _isLastQuestion =>
      _currentIndex == _dailyTestSet!.questions.length - 1;

  bool get _currentHasAnswer {
    final question = _dailyTestSet!.questions[_currentIndex];
    return (_answers[question.item.id] ?? '').trim().isNotEmpty;
  }

  void _goBack() {
    if (_currentIndex == 0) return;
    setState(() => _currentIndex--);
  }

  void _advance() {
    if (_isLastQuestion) {
      _finish();
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => DailyTestResultScreen(
          dailyTestSet: _dailyTestSet!,
          answers: Map.of(_answers),
          dailyTestService: widget.dailyTestService,
        ),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave Daily Test?'),
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
      Navigator.of(context).pop();
    }
  }

  String _itemLabel(PracticeItemType type) {
    switch (type) {
      case PracticeItemType.fillInBlank:
        return 'Fill in the blank';
      case PracticeItemType.errorCorrection:
        return 'Find and correct the error';
      case PracticeItemType.sentenceWriting:
        // Never generated for Daily Test (fixed-answer types only — see
        // DailyTestQuestion's doc comment); kept only for switch
        // exhaustiveness over the shared PracticeItemType enum.
        return 'Write a sentence';
    }
  }

  String _primaryLabel() {
    if (_isLastQuestion) return 'Finish';
    return _currentHasAnswer ? 'Next' : 'Skip';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final appBarFg =
        theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return PopScope(
      // Same reasoning as PracticeScreen: the system back gesture reaches
      // this route too, and would otherwise abandon the session without
      // the confirmation dialog below.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Leave Daily Test',
            onPressed: _confirmExit,
          ),
          title: _loading
              ? null
              : Text(
                  '${_currentIndex + 1}/${_dailyTestSet!.questions.length}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: appBarFg),
                ),
          bottom: _loading
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(58),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
                    child: Column(
                      children: [
                        Text(
                          'Daily Test',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: appBarFg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: (_currentIndex + 1) /
                                  _dailyTestSet!.questions.length,
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
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
        body: _loading
            ? const LoadingView(message: "Preparing today's test…")
            : _buildQuestion(theme, colorScheme, hPad),
      ),
    );
  }

  Widget _buildQuestion(
    ThemeData theme,
    ColorScheme colorScheme,
    double hPad,
  ) {
    final DailyTestQuestion question =
        _dailyTestSet!.questions[_currentIndex];
    final item = question.item;
    final controller = _controllers![item.id]!;

    // Same header/input split as PracticeScreen, for the same reason — see
    // this screen's class doc comment.
    return GestureDetector(
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
                        Text(item.context!, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: colorScheme.outlineVariant),
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
                          style: theme.textTheme.bodySmall?.copyWith(
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
              controller: controller,
              decoration: const InputDecoration(hintText: 'Your answer'),
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
    );
  }
}
