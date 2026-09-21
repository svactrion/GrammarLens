import 'package:flutter/material.dart';

import '../models/practice_item.dart';
import '../models/practice_set.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../utils/app_messenger.dart';
import '../utils/loading_view.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/destructive_dialog_actions.dart';
import '../widgets/practice_step_footer.dart';
import '../widgets/question_app_bar.dart';
import 'results_screen.dart';

class PracticeScreen extends StatefulWidget {
  final Topic topic;
  final PracticeSet practiceSet;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;

  const PracticeScreen({
    super.key,
    required this.topic,
    required this.practiceSet,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
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

  // Never "Skip" — see PracticeStepFooter's doc comment for why the
  // primary action must never invite abandoning the question. Skip is
  // its own separate, quiet action, always available regardless of this
  // label.
  String _primaryLabel() => _isLastQuestion ? 'Submit' : 'Next';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
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
        appBar: QuestionAppBar(
          title: widget.topic.title,
          currentIndex: _currentIndex,
          total: total,
          showBack: _currentIndex != 0,
          onBack: _goBack,
          onClose: _confirmExit,
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
                        // No Card here (docs/design-audit.md §5 D1's kart
                        // kuralı) — this text existed on a card only to stay
                        // legible on the old full-orange scaffold; the
                        // neutral BrandScaffold body it sits on now already
                        // does that job.
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
                                  height: 1, color: colorScheme.outlineVariant),
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
                    Padding(
                      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
                      child: TextField(
                        key: ValueKey(item.id),
                        controller: _controllers[item.id],
                        decoration:
                            const InputDecoration(hintText: 'Your answer'),
                        // The keyboard must not fix the learner's mistake: a
                        // corrected answer would measure the keyboard, not
                        // the learner.
                        autocorrect: false,
                        enableSuggestions: false,
                        smartQuotesType: SmartQuotesType.disabled,
                        smartDashesType: SmartDashesType.disabled,
                        onChanged: (value) =>
                            setState(() => _answers[item.id] = value),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
                        child: PracticeStepFooter(
                          primaryLabel: _primaryLabel(),
                          primaryEnabled: _currentHasAnswer,
                          onPrimary: _advance,
                          onSkip: _advance,
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
