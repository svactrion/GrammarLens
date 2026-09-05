import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../models/practice_item.dart';
import '../services/daily_test_service.dart';
import '../utils/loading_view.dart';
import '../widgets/empty_state.dart';
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

  /// Called with the finished set + answers instead of the default
  /// pushReplacement-to-results navigation, when non-null. Exists for the
  /// Day-0 first-launch flow (see `first_launch_flow.dart`), which shows
  /// this screen without ever pushing it as a route — there, replacing the
  /// "current route" with results via Navigator would actually replace
  /// the app's root route, breaking the reactive `home:` swap that flow
  /// relies on to reach the tabbed shell afterward. Null (the default) for
  /// every other caller (Home's `_openDailyTest`, which does push this
  /// screen normally) keeps today's Navigator-based transition unchanged.
  final void Function(DailyTestSet, Map<String, String>)? onFinished;

  /// Called instead of `Navigator.of(context).pop()` when the user leaves
  /// (confirms exit, or the initial load fails) — same Day-0 reasoning as
  /// [onFinished]: this screen isn't a pushed route there, so there's
  /// nothing to pop. Null (the default) keeps the existing pop behavior.
  final VoidCallback? onExit;

  const DailyTestScreen({
    super.key,
    required this.dailyTestService,
    this.onFinished,
    this.onExit,
  });

  @override
  State<DailyTestScreen> createState() => _DailyTestScreenState();
}

class _DailyTestScreenState extends State<DailyTestScreen> {
  final Map<String, String> _answers = {};
  Map<String, TextEditingController>? _controllers;
  DailyTestSet? _dailyTestSet;
  bool _loading = true;
  Object? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Generation failing here never leaves anything cached as "today's
  /// test" — `DailyTestService.getTodaysSet` only calls `saveDailyTestSet`
  /// after a full, successful generation, so a thrown error here always
  /// means nothing was saved (see its own doc comment). Re-entering this
  /// method — via the initial call or a "Try again" tap — is always a
  /// real attempt, never blocked by a stale/partial cache row.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  void _leave() {
    if (widget.onExit != null) {
      widget.onExit!();
    } else {
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
    if (widget.onFinished != null) {
      widget.onFinished!(_dailyTestSet!, Map.of(_answers));
      return;
    }
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
      _leave();
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
          // Guarded on `_dailyTestSet` rather than `!_loading`: the error
          // state below also has `_loading == false` but no set to read
          // `.questions.length` from.
          title: _dailyTestSet == null
              ? null
              : Text(
                  '${_currentIndex + 1}/${_dailyTestSet!.questions.length}',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700, color: appBarFg),
                ),
          bottom: _dailyTestSet == null
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
            : _error != null
                ? _buildError(colorScheme)
                : _buildQuestion(theme, colorScheme, hPad),
      ),
    );
  }

  /// In-screen error state instead of a SnackBar (this used to show a raw
  /// exception via SnackBar, then leave the screen entirely — surfacing a
  /// cast/API-key error to a first-time user with no way to retry). Reuses
  /// EmptyState's existing icon+title/description+CTA pattern rather than
  /// inventing a new visual treatment. The raw error detail is debug-only:
  /// a real user gets one human sentence, never a stack-trace-shaped
  /// string; a developer chasing a bug still sees exactly what failed.
  Widget _buildError(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            EmptyState(
              icon: Icons.error_outline_rounded,
              title: "Couldn't load today's test",
              description:
                  'Something went wrong generating it. Check your '
                  'connection and try again.',
              ctaLabel: 'Try again',
              onCta: _load,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              Text(
                '$_error',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
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
