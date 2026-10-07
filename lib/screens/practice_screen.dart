import 'package:flutter/material.dart';

import '../models/practice_set.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_messenger.dart';
import '../utils/loading_view.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/destructive_dialog_actions.dart';
import '../widgets/practice_step_footer.dart';
import '../widgets/question_app_bar.dart';
import '../widgets/question_view.dart';
import 'results_screen.dart';
import '../utils/content_width.dart';

class PracticeScreen extends StatefulWidget {
  final Topic topic;
  final PracticeSet practiceSet;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;

  const PracticeScreen({
    super.key,
    required this.topic,
    required this.practiceSet,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
  });

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final Map<String, String> _answers = {};
  late final AnswerDrafts _drafts;
  int _currentIndex = 0;
  bool _submitting = false;

  /// The proxy's limit on one answer (`proxy/src/validation.ts`,
  /// `MAX_TEXT_LENGTH`): a longer one would fail the whole scoring call.
  /// The count shows only past [_answerCounterFrom] (owner decision O6).
  static const int answerMaxLength = 2000;
  static const int _answerCounterFrom = 1800;

  @override
  void initState() {
    super.initState();
    _drafts = AnswerDrafts(widget.practiceSet.items.map((item) => item.id));
  }

  @override
  void dispose() {
    _drafts.dispose();
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

  /// Moves to another question. Local only: no request, no score, no quota.
  void _showQuestion(int index) {
    _drafts.leave(widget.practiceSet.items[_currentIndex].id);
    setState(() => _currentIndex = index);
    _drafts.restore(widget.practiceSet.items[index].id);
  }

  void _goBack() {
    if (_currentIndex == 0 || _submitting) return;
    _showQuestion(_currentIndex - 1);
  }

  void _advance() {
    // A second tap before the loading view replaces the buttons must not
    // send a second scoring request.
    if (_submitting) return;
    if (_isLastQuestion) {
      _submit();
    } else {
      _showQuestion(_currentIndex + 1);
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
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _submit() async {
    _drafts.focusNode.unfocus();
    setState(() => _submitting = true);
    try {
      final deviceId = await widget.storageService.getOrCreateDeviceId();
      final result = await widget.claudeService.scoreAnswers(
        deviceId: deviceId,
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
            analyticsService: widget.analyticsService,
            subscriptionService: widget.subscriptionService,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show('Could not score answers: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // Never "Skip" — see PracticeStepFooter's doc comment for why the
  // primary action must never invite abandoning the question. Skip is
  // its own separate, quiet action, always available regardless of this
  // label.
  String _primaryLabel() => _isLastQuestion ? 'Submit' : 'Next';

  @override
  Widget build(BuildContext context) {
    // P1: held to the centred content column on an iPad (`ContentWidth`);
    // the question screen's own 16 pt (14 under 360 pt) on a phone.
    final width = MediaQuery.sizeOf(context).width;
    final hPad =
        ContentWidth.sidePaddingOf(context, base: width < 360 ? 14 : 16);
    final total = widget.practiceSet.items.length;
    final item = widget.practiceSet.items[_currentIndex];

    return PopScope(
      // The top-right close icon isn't the only way to leave this screen —
      // the system back gesture/button reaches the same route, and would
      // otherwise abandon the session without the confirmation dialog.
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmExit();
      },
      child: BrandScaffold(
        // The status bar only: the header is in the page (Question V2), so
        // a long topic title wraps instead of being cut off.
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
        ),
        body: Column(
          children: [
            QuestionHeader(
              title: widget.topic.title,
              subtitle: 'Practice',
              onBack: _currentIndex == 0 || _submitting ? null : _goBack,
              onClose: _confirmExit,
            ),
            Expanded(
              child: _submitting
                  ? const LoadingView(message: 'Reviewing your answers…')
                  : GestureDetector(
                      // Tapping outside the text field is the standard
                      // mobile way to dismiss the keyboard.
                      behavior: HitTestBehavior.opaque,
                      onTap: () => FocusScope.of(context).unfocus(),
                      // The question and the answer are separate regions,
                      // and the page itself never scrolls: the keyboard
                      // cannot drag the question away to show the caret
                      // (see QuestionView).
                      child: QuestionView(
                        item: item,
                        index: _currentIndex,
                        total: total,
                        drafts: _drafts,
                        horizontalPadding: hPad,
                        maxLength: answerMaxLength,
                        counterThreshold: _answerCounterFrom,
                        onChanged: (value) =>
                            setState(() => _answers[item.id] = value),
                      ),
                    ),
            ),
            if (!_submitting)
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
}
