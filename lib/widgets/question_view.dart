import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/practice_item.dart';
import '../data/topic_hints.dart';
import '../models/topic.dart';
import '../theme.dart';
import 'topic_hint_card.dart';

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

  /// The question's topic, shown as a tag after the type label; null shows
  /// none (a Daily Test question whose topic id is not a known topic).
  final Topic? topic;

  /// Whether [topic]'s hint slider sits between the question card and the
  /// "Your answer" row (the Daily Test with the keyboard down, on a wide
  /// enough screen; see [TopicHintSlider]). No slider without a topic.
  final bool showTopicHint;

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
    this.topic,
    this.showTopicHint = false,
    this.maxLength,
    this.counterThreshold = 0,
  });

  static const questionCardKey = ValueKey('question_card');
  static const topicTagKey = ValueKey('question_topic_tag');
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

  /// The answer field's text: 16 at Small on 25 pt lines (the brief).
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

  /// Sentence answers start with a capital; a blank's word does not.
  static TextCapitalization capitalizationFor(PracticeItemType type) =>
      type == PracticeItemType.fillInBlank
          ? TextCapitalization.none
          : TextCapitalization.sentences;

  /// The answer field's height at its minimum lines, from the style and the
  /// text scaler: lines × line height and the padding, plus 1 pt for the
  /// font's rounding (measured: 74 pt for two lines at Small, the old Medium).
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

class _QuestionViewState extends State<QuestionView>
    with SingleTickerProviderStateMixin {
  final ScrollController _questionScroll = ScrollController();
  bool _questionOverflows = false;
  bool _questionAtEnd = true;
  bool _answerFocused = false;

  /// How far the topic hint slider is out from under the question card: 1
  /// out, 0 tucked away. It goes in when the answer takes focus and comes
  /// out when it loses it: the moments the keyboard starts to open and to
  /// close, so it moves with the keyboard. (The keyboard's inset cannot
  /// drive it: its final height is unknown while it opens, and it reaches 0
  /// only at the end of closing.) [hintSlideDuration] and [hintSlideCurve]
  /// approximate the iOS keyboard's own animation.
  late final AnimationController _hintOut;
  late final CurvedAnimation _hintOutCurved;
  bool _reduceMotion = false;

  static const Duration hintSlideDuration = Duration(milliseconds: 250);

  /// The space under the answer, above the Skip/Next bar.
  static const double bottomPadding = 12;
  static const Curve hintSlideCurve = Curves.easeOutCubic;

  @override
  void initState() {
    super.initState();
    widget.drafts.focusNode.addListener(_onFocusChange);
    _answerFocused = widget.drafts.focusNode.hasFocus;
    _hintOut = AnimationController(
      vsync: this,
      duration: hintSlideDuration,
      value: _answerFocused ? 0 : 1,
    );
    // Fast at the start both ways, as the keyboard is.
    _hintOutCurved = CurvedAnimation(
        parent: _hintOut,
        curve: hintSlideCurve,
        reverseCurve: hintSlideCurve.flipped);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
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
    _hintOutCurved.dispose();
    _hintOut.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final focused = widget.drafts.focusNode.hasFocus;
    if (focused == _answerFocused) return;
    setState(() => _answerFocused = focused);
    if (_reduceMotion) {
      _hintOut.value = focused ? 0 : 1;
    } else if (focused) {
      // reverse(), not animateTo(0): only a reverse run takes the
      // reverse curve.
      _hintOut.reverse();
    } else {
      _hintOut.forward();
    }
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

    final topic = widget.topic;
    final hintPoints = topic == null ? null : kTopicHints[topic.id];
    final hasHint = widget.showTopicHint && hintPoints != null;
    final head = _AnswerHead(
      focused: _answerFocused,
      questionClipped: _questionOverflows,
      onCloseKeyboard: _closeKeyboard,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.horizontalPadding, 14,
          widget.horizontalPadding, bottomPadding),
      child: AnimatedBuilder(
        animation: _hintOutCurved,
        builder: (context, _) => LayoutBuilder(builder: (context, constraints) {
          final type = widget.item.type;
          final out = hasHint ? _hintOutCurved.value : 0.0;
          // Tucked all the way: no slot, and the slider (with any open card)
          // is gone; it is made again, closed, when it comes back out.
          final hint = out > 0
              ? _TuckUnder(
                  out: out,
                  child: TopicHintSlider(
                    // A new question's slider starts closed.
                    key: ValueKey(widget.item.id),
                    topic: topic!,
                    points: hintPoints!,
                    collapsed: _answerFocused,
                  ),
                )
              : null;
          final hintReserve = TopicHintSlider.closedHeight * out;
          final room = constraints.maxHeight -
              hintReserve -
              QuestionView.questionGap -
              QuestionView.headHeight -
              QuestionView.headGap;
          final compact =
              room - QuestionView.answerMinHeight(theme, scaler, type) <
                  QuestionView.minQuestionHeight;
          // An open hint card pushes the answer down past the bottom; it is
          // cut at the top of the Skip/Next bar (the bottom padding is free
          // room for it), and only there (the question card's shadow
          // stays).
          return ClipRect(
            clipper: const _BottomEdgeClipper(extra: bottomPadding),
            child: CustomMultiChildLayout(
              delegate: _QuestionLayoutDelegate(
                  answerMin: QuestionView.answerMinHeight(theme, scaler, type,
                      compact: compact),
                  hintReserve: hintReserve),
              children: [
                // Painted first, so the question card is drawn over a slider
                // that is tucking under it.
                if (hint != null) LayoutId(id: _Slot.hint, child: hint),
                LayoutId(id: _Slot.question, child: _questionCard(theme)),
                LayoutId(id: _Slot.head, child: head),
                LayoutId(
                    id: _Slot.answer,
                    child: _answerField(theme,
                        minLines:
                            QuestionView.minLinesFor(type, compact: compact))),
              ],
            ),
          );
        }),
      ),
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
        topic: widget.topic,
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
        // A capital at the start of each sentence for the types answered
        // with a sentence (owner, after Batch 10); not for fill in the
        // blank, whose answer usually goes into the middle of one. Grading
        // ignores case either way (`normalizeAnswer` lowercases).
        textCapitalization: QuestionView.capitalizationFor(widget.item.type),
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
  final Topic? topic;

  const _QuestionContent({
    required this.item,
    required this.index,
    required this.total,
    required this.topic,
  });

  static const EdgeInsets _badgePadding =
      EdgeInsets.symmetric(horizontal: 8, vertical: 3);

  /// [child] centred in a line at least [height] tall, as wide as itself.
  static Widget _line(double height, Widget child) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Align(
            alignment: Alignment.centerLeft, widthFactor: 1, child: child),
      );

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
    final badgeStyle = theme.textTheme.labelSmall
        ?.withWeight(FontWeight.w900)
        .copyWith(color: colorScheme.onPrimary);
    // The badge's height: one line of its text and its padding.
    final badgeLine = TextPainter(
      text: TextSpan(text: '0', style: badgeStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final lineHeight = badgeLine.height + _badgePadding.vertical;
    badgeLine.dispose();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The type label, then the topic tag, wrapping to a second line
        // when the tag does not fit; the badge stays top right. Each piece
        // sits in a line as tall as the badge, centred, so a one-line row
        // looks exactly as it did before the tag.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _line(
                    lineHeight,
                    Text(
                      questionTypeLabel(item.type),
                      style: theme.textTheme.labelMedium
                          ?.withWeight(FontWeight.w800)
                          .copyWith(color: colorScheme.secondary),
                    ),
                  ),
                  if (topic != null) _line(lineHeight, _TopicTag(topic!)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _line(
              lineHeight,
              Semantics(
                label: 'Question ${index + 1} of $total',
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Padding(
                    padding: _badgePadding,
                    child: Text(
                      '${index + 1} / $total',
                      style: badgeStyle,
                    ),
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

/// The question's topic as a small neutral chip (the question screen plan,
/// item 1): the subtle surface with the card border's edge and the
/// secondary text colour, 8.23:1 (light) and 7.75:1 (dark). Never the
/// correct/incorrect colours. A title too long for its line wraps inside
/// the chip; it is never cut.
class _TopicTag extends StatelessWidget {
  final Topic topic;

  const _TopicTag(this.topic);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Semantics(
      label: 'Topic: ${topic.title}',
      excludeSemantics: true,
      child: DecoratedBox(
        key: QuestionView.topicTagKey,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
          child: Text(
            topic.title,
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w700)
                .copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
      ),
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
                // Its own 44 pt is the target: Material's padded 48 pt tap
                // area grew the row by 4 pt when the control appeared and
                // dropped the answer field with it.
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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

enum _Slot { question, hint, head, answer }

/// Lays out the question first, capped so the answer keeps [answerMin]
/// and a closed hint slider keeps [hintReserve]; then the hint slider (the
/// Daily Test), as tall as it is at the moment; then "Your answer"; then
/// the answer in whatever height is left (never less than [answerMin]). The
/// question's cap ignores how far the hint card is open, so opening it
/// never moves or resizes the question: it pushes "Your answer" and the
/// answer down, past the bottom if it must.
class _QuestionLayoutDelegate extends MultiChildLayoutDelegate {
  final double answerMin;
  final double hintReserve;

  _QuestionLayoutDelegate({required this.answerMin, this.hintReserve = 0});

  @override
  void performLayout(Size size) {
    final width = size.width;
    final head = layoutChild(_Slot.head, BoxConstraints.tightFor(width: width));
    final questionCap = math.max(
        0.0,
        size.height -
            hintReserve -
            QuestionView.questionGap -
            head.height -
            QuestionView.headGap -
            answerMin);
    final question = layoutChild(
        _Slot.question,
        BoxConstraints(
            minWidth: width, maxWidth: width, maxHeight: questionCap));
    positionChild(_Slot.question, Offset.zero);
    var y = question.height;
    if (hasChild(_Slot.hint)) {
      final hint = layoutChild(
          _Slot.hint, BoxConstraints(minWidth: width, maxWidth: width));
      positionChild(_Slot.hint, Offset(0, y));
      y += hint.height;
    }
    y += QuestionView.questionGap;
    positionChild(_Slot.head, Offset(0, y));
    final answerTop = y + head.height + QuestionView.headGap;
    layoutChild(
        _Slot.answer,
        BoxConstraints(
            minWidth: width,
            maxWidth: width,
            maxHeight: math.max(answerMin, size.height - answerTop)));
    positionChild(_Slot.answer, Offset(0, answerTop));
  }

  @override
  bool shouldRelayout(_QuestionLayoutDelegate oldDelegate) =>
      oldDelegate.answerMin != answerMin ||
      oldDelegate.hintReserve != hintReserve;
}

/// The hint slider [out] of the way out from under the question card: its
/// slot is [out] of its height, and the slider sits at the slot's bottom,
/// so the rest of it reaches up under the card (drawn behind it, see the
/// layout's paint order). It takes no touches until it is all the way out.
class _TuckUnder extends StatelessWidget {
  final double out;
  final Widget child;

  const _TuckUnder({required this.out, required this.child});

  @override
  Widget build(BuildContext context) {
    // The same shape at every step, so the slider keeps its state.
    return IgnorePointer(
      ignoring: out < 1,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: out,
        child: child,
      ),
    );
  }
}

/// Clips only what goes more than [extra] past the bottom edge.
class _BottomEdgeClipper extends CustomClipper<Rect> {
  final double extra;

  const _BottomEdgeClipper({this.extra = 0});

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
      -size.width, -size.height, size.width * 2, size.height + extra);

  @override
  bool shouldReclip(_BottomEdgeClipper oldClipper) => oldClipper.extra != extra;
}
