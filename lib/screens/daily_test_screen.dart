import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models/daily_test_question.dart';
import '../models/daily_test_set.dart';
import '../services/analytics_service.dart';
import '../services/daily_test_service.dart';
import '../utils/loading_view.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/destructive_dialog_actions.dart';
import '../widgets/empty_state.dart';
import '../widgets/practice_step_footer.dart';
import '../widgets/question_app_bar.dart';
import '../widgets/question_view.dart';
import '../utils/debug_tools.dart';
import 'daily_test_result_screen.dart';
import '../utils/content_width.dart';

/// One-question-at-a-time flow over today's cached Daily Test set (PRD v2
/// §12.2, §12.5). Shares PracticeScreen's layout — the same header,
/// [QuestionView] (the question and the answer as separate regions, a hard-won
/// fix for the keyboard dragging the question off screen) and Skip/primary
/// bar above the keyboard — but simpler: no length
/// picker (the set's size is fixed by the data layer) and no submit-time
/// API call, since grading is instant and local
/// ([checkDailyTestAnswer] in DailyTestResultScreen).
class DailyTestScreen extends StatefulWidget {
  final DailyTestService dailyTestService;
  final AnalyticsService analyticsService;

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
    required this.analyticsService,
    this.onFinished,
    this.onExit,
  });

  @override
  State<DailyTestScreen> createState() => _DailyTestScreenState();
}

class _DailyTestScreenState extends State<DailyTestScreen> {
  final Map<String, String> _answers = {};
  AnswerDrafts? _drafts;
  DailyTestSet? _dailyTestSet;
  bool _loading = true;
  Object? _error;
  int _currentIndex = 0;

  /// Set by the first Finish: a second tap during the route change must not
  /// finish (and hand over the answers) twice.
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// `DailyTestService.getTodaysSet` never fails over the network: a shared
  /// set that cannot be read gives way to the fallback. What can still throw
  /// here is local storage, and nothing is cached by a failed attempt, so
  /// re-entering this method — via the initial call or a "Try again" tap —
  /// is always a real attempt, never blocked by a stale/partial cache row.
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
        _drafts?.dispose();
        _drafts = AnswerDrafts(dailyTestSet.questions.map((q) => q.item.id));
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
    _drafts?.dispose();
    super.dispose();
  }

  bool get _isLastQuestion =>
      _currentIndex == _dailyTestSet!.questions.length - 1;

  bool get _currentHasAnswer {
    final question = _dailyTestSet!.questions[_currentIndex];
    return (_answers[question.item.id] ?? '').trim().isNotEmpty;
  }

  /// Moves to another question. Local only: grading happens on the result
  /// screen, so nothing is read, scored or counted here.
  void _showQuestion(int index) {
    final questions = _dailyTestSet!.questions;
    _drafts!.leave(questions[_currentIndex].item.id);
    setState(() => _currentIndex = index);
    _drafts!.restore(questions[index].item.id);
  }

  void _goBack() {
    if (_currentIndex == 0 || _finishing) return;
    _showQuestion(_currentIndex - 1);
  }

  void _advance() {
    if (_finishing) return;
    if (_isLastQuestion) {
      _finish();
    } else {
      _showQuestion(_currentIndex + 1);
    }
  }

  void _finish() {
    _finishing = true;
    _drafts?.focusNode.unfocus();
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
          analyticsService: widget.analyticsService,
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
          DestructiveDialogActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Leave',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (shouldLeave == true && mounted) {
      _leave();
    }
  }

  // Never "Skip" — see PracticeStepFooter's doc comment for why the
  // primary action must never invite abandoning the question. Skip is
  // its own separate, quiet action, always available regardless of this
  // label.
  String _primaryLabel() => _isLastQuestion ? 'Finish' : 'Next';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // P1: held to the centred content column on an iPad (`ContentWidth`);
    // the question screen's own 16 pt (14 under 360 pt) on a phone.
    final width = MediaQuery.sizeOf(context).width;
    final hPad =
        ContentWidth.sidePaddingOf(context, base: width < 360 ? 14 : 16);
    final set = _dailyTestSet;
    final showQuestion = !_loading && _error == null && set != null;

    return PopScope(
      // Same reasoning as PracticeScreen: the system back gesture reaches
      // this route too, and would otherwise abandon the session without
      // the confirmation dialog below.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: BrandScaffold(
        // The status bar only: the header is in the page (Question V2).
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
        ),
        body: Column(
          children: [
            // The same header while loading or on an error, so it does not
            // change once the questions appear; Back stays disabled until
            // there is a previous question.
            QuestionHeader(
              title: 'Daily Test',
              onBack: showQuestion && _currentIndex > 0 && !_finishing
                  ? _goBack
                  : null,
              onClose: _confirmExit,
              closeTooltip: 'Leave Daily Test',
            ),
            Expanded(
              child: _loading
                  ? const LoadingView(message: "Preparing today's test…")
                  : _error != null
                      ? _buildError(colorScheme)
                      : _buildQuestion(hPad),
            ),
            if (showQuestion)
              PracticeStepFooter(
                horizontalPadding: hPad,
                primaryLabel: _primaryLabel(),
                primaryEnabled: _currentHasAnswer,
                onPrimary: _advance,
                onSkip: _advance,
              ),
          ],
        ),
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
  ///
  /// There is no quota state: the shared set's read never spends quota, and
  /// any failure to read it opens the fallback instead
  /// (docs/1.1.0-shared-daily-test.md §5).
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
              description: 'Something went wrong generating it. Check your '
                  'connection and try again.',
              ctaLabel: 'Try again',
              onCta: _load,
            ),
            if (kDebugMode && DebugTools.enabledForTesting) ...[
              const SizedBox(height: 12),
              Text(
                '$_error',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(double hPad) {
    final DailyTestQuestion question = _dailyTestSet!.questions[_currentIndex];
    final item = question.item;

    // Same question/answer regions as PracticeScreen (see QuestionView).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: QuestionView(
        item: item,
        index: _currentIndex,
        total: _dailyTestSet!.questions.length,
        drafts: _drafts!,
        horizontalPadding: hPad,
        onChanged: (value) => setState(() => _answers[item.id] = value),
      ),
    );
  }
}
