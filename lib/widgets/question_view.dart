import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/practice_item.dart';
import '../theme.dart';

/// The answer drafts of one question session (PracticeScreen, DailyTestScreen):
/// one [TextEditingController] per question ID, made once and kept until the
/// screen goes, so going back to a question brings back its text and its
/// selection. Also the session's single answer [focusNode] and answer
/// [scrollController], which the one answer field keeps across questions
/// (only its controller is swapped), so an open keyboard stays open on Next
/// and Back. The answer field's scroll offset is saved per question in
/// [leave] and put back in [restore].
class AnswerDrafts {
  AnswerDrafts(Iterable<String> ids)
      : _controllers = {
          // A valid collapsed selection from the start: the field keeps its
          // input connection across questions, and an empty controller's
          // default (-1) selection is not one to hand to the keyboard.
          for (final id in ids)
            id: TextEditingController.fromValue(const TextEditingValue(
                selection: TextSelection.collapsed(offset: 0))),
        };

  final Map<String, TextEditingController> _controllers;
  final Map<String, double> _offsets = {};
  final FocusNode focusNode = FocusNode(debugLabel: 'answer');
  final ScrollController scrollController = ScrollController();

  TextEditingController controllerFor(String id) => _controllers[id]!;

  /// Call before the visible question changes away from [id].
  void leave(String id) {
    if (scrollController.hasClients) {
      _offsets[id] = scrollController.offset;
    }
  }

  /// Call after the visible question changed to [id]: once the field has
  /// laid out the new text, its own saved offset comes back (0 for a
  /// question not seen yet).
  void restore(String id) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      final position = scrollController.position;
      final target = (_offsets[id] ?? 0)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      if (target != position.pixels) scrollController.jumpTo(target);
    });
  }

  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    focusNode.dispose();
    scrollController.dispose();
  }
}

/// The question type's label above the question.
String questionTypeLabel(PracticeItemType type) {
  switch (type) {
    case PracticeItemType.fillInBlank:
      return 'Fill in the blank';
    case PracticeItemType.errorCorrection:
      return 'Find and correct the error';
    case PracticeItemType.sentenceWriting:
      return 'Write a sentence';
  }
}

/// The question and its answer field (Question V2, the additional screens
/// package): the question card, then "Your answer" with the keyboard
/// control, then a multiline answer field that wraps, grows as the learner
/// writes and shrinks as they delete. Shared by PracticeScreen and
/// DailyTestScreen; the header and the Skip/primary bar are theirs.
///
/// **Space.** The question comes first: it gets its whole height whenever
/// that leaves the answer its minimum (its first lines). The answer then
/// grows only into what is left and, past that, scrolls inside itself
/// (`maxLines: null` in a bounded box); the question and the action bar
/// below are never pushed out. A question taller than its share (a long
/// question, a small phone, large text, the keyboard open) scrolls in its
/// own card, with a scroll bar and a fade that shows there is more. The
/// text is never shrunk or cut. When the answer's minimum would leave the
/// question less than [minQuestionHeight] (a tiny height: a small phone,
/// large text and the keyboard), the answer starts at one line for every
/// type and the question keeps what is left, scrolling in its card;
/// "Read full question" closes the keyboard to show it. Nothing overflows.
///
/// The page itself does not scroll, so the keyboard can never drag the
/// question out of view to show the caret; only the answer field scrolls to
/// keep its caret visible.
///
/// **Keyboard control.** While the answer has focus, "Review answer" (or
/// "Read full question" when the question does not fit) closes the
/// keyboard without touching the answer, giving the space back.
class QuestionView extends StatefulWidget {
  final PracticeItem item;
  final int index;
  final int total;
  final AnswerDrafts drafts;
  final ValueChanged<String> onChanged;

  /// The answer's character limit, or null for none. The count shows only
  /// past [counterThreshold].
  final int? maxLength;
  final int counterThreshold;

  final double horizontalPadding;

  const QuestionView({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.drafts,
    required this.onChanged,
    required this.horizontalPadding,
    this.maxLength,
    this.counterThreshold = 0,
  });

  static const questionCardKey = ValueKey('question_card');
  static const questionScrollKey = ValueKey('question_scroll');
  static const answerFieldKey = ValueKey('question_answer_field');
  static const keyboardControlKey = ValueKey('question_keyboard_control');
  static const moreBelowKey = ValueKey('question_more_below');

  /// Space between the question card and "Your answer", and between that
  /// line and the field. The line itself is 44 tall (the control's target),
  /// its text centred, so these are smaller than the mockup's 12 and 4
  /// around its 29 pt line: the visible spacing is about the same.
  static const double questionGap = 4;
  static const double headGap = 0;

  /// "Your answer" and its control: a 44 pt target.
  static const double headHeight = 44;

  /// The least of the question the answer's full minimum may leave it;
  /// below this the answer drops to one line (see the class comment).
  static const double minQuestionHeight = 72;

  /// The answer field's text: 16 at Medium on 25 pt lines (the brief).
  static TextStyle answerStyle(ThemeData theme) =>
      theme.textTheme.bodyLarge!.copyWith(
        color: theme.colorScheme.onSurface,
        height: 25 / 16,
      );

  static const EdgeInsets answerPadding =
      EdgeInsets.symmetric(horizontal: 13, vertical: 12);

  /// Fill in the blank starts at one line, the full-sentence types at two
  /// (owner decision O12); every type wraps and grows.
  static int minLinesFor(PracticeItemType type, {bool compact = false}) =>
      compact || type == PracticeItemType.fillInBlank ? 1 : 2;

  /// The answer field's height at its minimum lines, from the style and the
  /// text scaler: lines × line height and the padding, plus 1 pt for the
  /// font's rounding (measured: 74 pt for two lines at Medium).
  static double answerMinHeight(
      ThemeData theme, TextScaler scaler, PracticeItemType type,
      {bool compact = false}) {
    final style = answerStyle(theme);
    final line = scaler.scale(style.fontSize!) * style.height!;
    return minLinesFor(type, compact: compact) * line +
        answerPadding.vertical +
        1;
  }

  @override
  State<QuestionView> createState() => _QuestionViewState();
}

class _QuestionViewState extends State<QuestionView> {
  final ScrollController _questionScroll = ScrollController();
  bool _questionOverflows = false;
  bool _questionAtEnd = true;
  bool _answerFocused = false;

  @override
  void initState() {
    super.initState();
    widget.drafts.focusNode.addListener(_onFocusChange);
    _answerFocused = widget.drafts.focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(QuestionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.drafts != widget.drafts) {
      oldWidget.drafts.focusNode.removeListener(_onFocusChange);
      widget.drafts.focusNode.addListener(_onFocusChange);
    }
    // A new question is read from its start.
    if (oldWidget.item.id != widget.item.id && _questionScroll.hasClients) {
      _questionScroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    widget.drafts.focusNode.removeListener(_onFocusChange);
    _questionScroll.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = widget.drafts.focusNode.hasFocus;
    if (focused != _answerFocused) setState(() => _answerFocused = focused);
  }

  /// Reads whether the question card has more than it shows, after layout.
  void _checkQuestionMetrics() {
    if (!mounted || !_questionScroll.hasClients) return;
    final p = _questionScroll.position;
    if (!p.hasContentDimensions) return;
    final overflows = p.maxScrollExtent > 0.5;
    final atEnd = p.pixels >= p.maxScrollExtent - 0.5;
    if (overflows != _questionOverflows || atEnd != _questionAtEnd) {
      setState(() {
        _questionOverflows = overflows;
        _questionAtEnd = atEnd;
      });
    }
  }

  void _closeKeyboard() => widget.drafts.focusNode.unfocus();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    SchedulerBinding.instance
        .addPostFrameCallback((_) => _checkQuestionMetrics());

    final head = _AnswerHead(
      focused: _answerFocused,
      questionClipped: _questionOverflows,
      onCloseKeyboard: _closeKeyboard,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
          widget.horizontalPadding, 14, widget.horizontalPadding, 12),
      child: LayoutBuilder(builder: (context, constraints) {
        final type = widget.item.type;
        final room = constraints.maxHeight -
            QuestionView.questionGap -
            QuestionView.headHeight -
            QuestionView.headGap;
        final compact =
            room - QuestionView.answerMinHeight(theme, scaler, type) <
                QuestionView.minQuestionHeight;
        return CustomMultiChildLayout(
          delegate: _QuestionLayoutDelegate(
              answerMin: QuestionView.answerMinHeight(theme, scaler, type,
                  compact: compact)),
          children: [
            LayoutId(id: _Slot.question, child: _questionCard(theme)),
            LayoutId(id: _Slot.head, child: head),
            LayoutId(
                id: _Slot.answer,
                child: _answerField(theme,
                    minLines:
                        QuestionView.minLinesFor(type, compact: compact))),
          ],
        );
      }),
    );
  }

  Widget _questionCard(ThemeData theme) {
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
      child: _QuestionContent(
        item: widget.item,
        index: widget.index,
        total: widget.total,
      ),
    );
    final radius = BorderRadius.circular(21);
    return DecoratedBox(
      key: QuestionView.questionCardKey,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: radius,
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: palette.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _checkQuestionMetrics();
                return false;
              },
              child: Scrollbar(
                controller: _questionScroll,
                thumbVisibility: _questionOverflows,
                child: SingleChildScrollView(
                  key: QuestionView.questionScrollKey,
                  controller: _questionScroll,
                  child: content,
                ),
              ),
            ),
            if (_questionOverflows && !_questionAtEnd)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: _MoreBelow(color: colorScheme.surfaceContainerHigh),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _answerField(ThemeData theme, {required int minLines}) {
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final radius = BorderRadius.circular(17);
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: color, width: width),
        );
    final maxLength = widget.maxLength;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: palette.cardShadow,
      ),
      child: TextField(
        key: QuestionView.answerFieldKey,
        controller: widget.drafts.controllerFor(widget.item.id),
        focusNode: widget.drafts.focusNode,
        scrollController: widget.drafts.scrollController,
        style: QuestionView.answerStyle(theme),
        // Multiline (the cause of the sideways scroll was the default single
        // line): words wrap, Return adds a line and never submits.
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        minLines: minLines,
        maxLines: null,
        maxLength: maxLength,
        // The keyboard must not fix the learner's mistake: a corrected
        // answer would measure the keyboard, not the learner (owner
        // decision O4). Return, composing and selection behave as usual.
        autocorrect: false,
        enableSuggestions: false,
        smartQuotesType: SmartQuotesType.disabled,
        smartDashesType: SmartDashesType.disabled,
        decoration: InputDecoration(
          hintText: 'Write your answer…',
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh,
          contentPadding: QuestionView.answerPadding,
          isDense: true,
          // The Q3 edge (3:1), 1.5 pt as in the mockup; the link colour
          // while typing.
          enabledBorder: border(palette.inputBorder, 1.5),
          border: border(palette.inputBorder, 1.5),
          focusedBorder: border(colorScheme.secondary, 2),
        ),
        buildCounter: maxLength == null
            ? null
            : (context,
                    {required currentLength,
                    required isFocused,
                    required maxLength}) =>
                currentLength <= widget.counterThreshold
                    ? null
                    : Text(
                        '$currentLength / $maxLength',
                        style: theme.textTheme.labelSmall
                            ?.withWeight(FontWeight.w600)
                            .copyWith(color: colorScheme.onSurfaceVariant),
                      ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

/// The question card's content: the type label and the counter, then the
/// item's own text exactly as the data has it. With a `context`, that is
/// the main text (17 / 700) and the instruction and hint go under a line in
/// the muted 13; without one, the instruction is the main text. Nothing is
/// added: no heading, no step labels.
class _QuestionContent extends StatelessWidget {
  final PracticeItem item;
  final int index;
  final int total;

  const _QuestionContent({
    required this.item,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mainStyle = theme.textTheme.titleMedium
        ?.withWeight(FontWeight.w700)
        .copyWith(color: colorScheme.onSurface, height: 1.45, letterSpacing: 0);
    final secondaryStyle = theme.textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.5);
    final scene = item.context?.trim();
    final hasContext = scene != null && scene.isNotEmpty;
    final main = hasContext ? item.context! : item.instruction;
    final secondary = <Widget>[
      if (hasContext) Text(item.instruction, style: secondaryStyle),
      if (item.hint != null) ...[
        if (hasContext) const SizedBox(height: 6),
        Text(item.hint!,
            style: secondaryStyle?.copyWith(fontStyle: FontStyle.italic)),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                questionTypeLabel(item.type),
                style: theme.textTheme.labelMedium
                    ?.withWeight(FontWeight.w800)
                    .copyWith(color: colorScheme.secondary),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: 'Question ${index + 1} of $total',
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Text(
                    '${index + 1} / $total',
                    style: theme.textTheme.labelSmall
                        ?.withWeight(FontWeight.w900)
                        .copyWith(color: colorScheme.onPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(main, style: mainStyle),
        if (secondary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: colorScheme.outlineVariant),
          const SizedBox(height: 10),
          ...secondary,
        ],
      ],
    );
  }
}

/// "Your answer", and while the answer has focus the control that closes
/// the keyboard: "Review answer", or "Read full question" when the
/// question does not fit. The row keeps its 44 pt height either way, so
/// the field never jumps when the control appears.
class _AnswerHead extends StatelessWidget {
  final bool focused;
  final bool questionClipped;
  final VoidCallback onCloseKeyboard;

  const _AnswerHead({
    required this.focused,
    required this.questionClipped,
    required this.onCloseKeyboard,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: QuestionView.headHeight),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Your answer',
              style: theme.textTheme.bodySmall
                  ?.withWeight(FontWeight.w800)
                  .copyWith(color: colorScheme.onSurface),
            ),
          ),
          if (focused)
            TextButton.icon(
              key: QuestionView.keyboardControlKey,
              onPressed: onCloseKeyboard,
              style: TextButton.styleFrom(
                minimumSize: const Size(44, QuestionView.headHeight),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: colorScheme.secondary,
                textStyle:
                    theme.textTheme.labelSmall?.withWeight(FontWeight.w700),
              ),
              icon: Icon(
                questionClipped
                    ? Icons.unfold_more_rounded
                    : Icons.keyboard_hide_rounded,
                size: 15,
              ),
              label: Text(
                  questionClipped ? 'Read full question' : 'Review answer'),
            ),
        ],
      ),
    );
  }
}

/// The fade at the foot of a question that scrolls, with a chevron: there
/// is more below.
class _MoreBelow extends StatelessWidget {
  final Color color;

  const _MoreBelow({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: QuestionView.moreBelowKey,
      height: 30,
      alignment: Alignment.bottomRight,
      padding: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color],
        ),
      ),
      child: Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 20,
        color: Theme.of(context).colorScheme.secondary,
      ),
    );
  }
}

enum _Slot { question, head, answer }

/// Lays out the question first, capped so the answer keeps [answerMin];
/// then "Your answer"; then the answer in whatever height is left (never
/// less than [answerMin] while the area holds it).
class _QuestionLayoutDelegate extends MultiChildLayoutDelegate {
  final double answerMin;

  _QuestionLayoutDelegate({required this.answerMin});

  @override
  void performLayout(Size size) {
    final width = size.width;
    final head = layoutChild(_Slot.head, BoxConstraints.tightFor(width: width));
    final questionCap = math.max(
        0.0,
        size.height -
            QuestionView.questionGap -
            head.height -
            QuestionView.headGap -
            answerMin);
    final question = layoutChild(
        _Slot.question,
        BoxConstraints(
            minWidth: width, maxWidth: width, maxHeight: questionCap));
    final answerTop = question.height +
        QuestionView.questionGap +
        head.height +
        QuestionView.headGap;
    layoutChild(
        _Slot.answer,
        BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: math.max(0.0, size.height - answerTop)));
    positionChild(_Slot.question, Offset.zero);
    positionChild(
        _Slot.head, Offset(0, question.height + QuestionView.questionGap));
    positionChild(_Slot.answer, Offset(0, answerTop));
  }

  @override
  bool shouldRelayout(_QuestionLayoutDelegate oldDelegate) =>
      oldDelegate.answerMin != answerMin;
}
