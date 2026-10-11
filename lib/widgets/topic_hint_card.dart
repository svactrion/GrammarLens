import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../models/topic.dart';
import '../theme.dart';

/// A topic's hint card (docs/question-screen-plan.md, item 2): the topic's
/// title and the owner's short points, on the warm surface (`warm` /
/// `onWarm`, 7.96:1 light and 7.82:1 dark), never the correct/incorrect
/// colours. As wide as it is given; as tall as its text.
class TopicHintCard extends StatelessWidget {
  final Topic topic;
  final List<String> points;

  const TopicHintCard({super.key, required this.topic, required this.points});

  static const EdgeInsets padding = EdgeInsets.fromLTRB(14, 8, 14, 8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final pointStyle = theme.textTheme.bodySmall
        ?.copyWith(color: palette.onWarm, height: 1.45);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.warm,
        borderRadius: BorderRadius.circular(17),
        boxShadow: palette.cardShadow,
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              topic.title,
              style: theme.textTheme.labelMedium
                  ?.withWeight(FontWeight.w800)
                  .copyWith(color: palette.onWarm),
            ),
            for (final point in points) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 14, child: Text('•', style: pointStyle)),
                  Expanded(child: Text(point, style: pointStyle)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The Daily Test's hint slider (docs/question-screen-plan.md, item 2, the
/// B2 rework): a "slide to unlock" track between the question card and the
/// "Your answer" row, and the topic's [TopicHintCard] that opens inline
/// below it.
///
/// **Track.** A 48 pt pill in the light brand tint (`warm`), "Slide for a
/// hint" centred in `onWarm`, a round knob at its left end in the brand
/// colour (`primary`) with right chevrons in `onPrimary`. As the knob moves
/// right a filled trail follows it and the label fades out.
///
/// **Reveal.** Dragging the knob right (horizontal only, so it never
/// competes with the question's vertical scroll) opens the card below the
/// track, its height in proportion to the knob's position, fully open at
/// the end of the track. The card is part of the page: it pushes the "Your
/// answer" row down and never covers or moves the question card. On release
/// the knob springs back and the card collapses (instant under Reduce
/// Motion). A long-press on the knob shows the card whole while held.
/// Nothing stays open, and nothing else changes: nothing is scored,
/// counted or logged.
///
/// The screen leaves the slider out while the keyboard is up and on screens
/// narrower than [minScreenWidth] (see `DailyTestScreen`); it comes back
/// closed.
class TopicHintSlider extends StatefulWidget {
  final Topic topic;
  final List<String> points;

  const TopicHintSlider({super.key, required this.topic, required this.points});

  static const knobKey = ValueKey('topic_hint_knob');
  static const cardKey = ValueKey('topic_hint_card');
  static const trackKey = ValueKey('topic_hint_track');
  static const labelKey = ValueKey('topic_hint_label');

  static const double trackHeight = 48;

  /// Space above the track, under the question card.
  static const double gap = 8;

  /// Space between the track and the open card (owner, 2026-10-12: 4, not
  /// 8, with the card's 8 pt top and bottom padding, so the open card fits
  /// above the Skip/Next bar at 375 × 667, Large, under a realistic
  /// question).
  static const double cardGap = 4;

  /// The slider's height when closed: what the layout keeps for it.
  static const double closedHeight = gap + trackHeight;

  /// No slider below this screen width (owner decision, 2026-10-12): on
  /// 320 pt phones an open card does not fit between the question and the
  /// Skip/Next bar (plan §3).
  static const double minScreenWidth = 375;

  @override
  State<TopicHintSlider> createState() => _TopicHintSliderState();
}

class _TopicHintSliderState extends State<TopicHintSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  double _travel = 0;
  double _dragDistance = 0;
  bool _holding = false;

  /// Read here, not in the gesture callbacks: a cancel can arrive while the
  /// widget is being taken down, when its context may no longer be used.
  bool _reduceMotion = false;

  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 500, ratio: 1);

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _reveal.dispose();
    super.dispose();
  }

  void _springTo(double target) {
    if (_reduceMotion) {
      _reveal.value = target;
      return;
    }
    // A spring ends within a tolerance of its target, not on it.
    _reveal
        .animateWith(SpringSimulation(_spring, _reveal.value, target, 0))
        .whenComplete(() {
      if (mounted) _reveal.value = target;
    });
  }

  void _begin() {
    _holding = true;
    _reveal.stop();
  }

  void _end() {
    if (!_holding) return;
    _holding = false;
    _springTo(0);
  }

  void _onDragStart(DragStartDetails details) {
    _begin();
    _dragDistance = _reveal.value * _travel;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_holding || _travel <= 0) return;
    _dragDistance += details.delta.dx;
    _reveal.value = (_dragDistance / _travel).clamp(0.0, 1.0);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _begin();
    _springTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final label =
        'Slide for a hint. ${widget.topic.title}: ${widget.points.join('. ')}.';
    return Padding(
      padding: const EdgeInsets.only(top: TopicHintSlider.gap),
      child: AnimatedBuilder(
        animation: _reveal,
        builder: (context, _) {
          final value = _reveal.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: label,
                hint: 'Touch and hold to show',
                excludeSemantics: true,
                child: _track(context, value),
              ),
              if (value > 0)
                ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: value,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: TopicHintSlider.cardGap),
                      child: TopicHintCard(
                        key: TopicHintSlider.cardKey,
                        topic: widget.topic,
                        points: widget.points,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _track(BuildContext context, double value) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    const height = TopicHintSlider.trackHeight;
    return SizedBox(
      key: TopicHintSlider.trackKey,
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        _travel = constraints.maxWidth - height;
        final knobLeft = value * _travel;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: palette.warm,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: Stack(
            children: [
              // The trail behind the knob.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: knobLeft + height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.32),
                    borderRadius: BorderRadius.circular(height / 2),
                  ),
                ),
              ),
              Positioned.fill(
                left: height,
                right: height / 2,
                child: Center(
                  child: Opacity(
                    opacity: (1 - value * 2).clamp(0.0, 1.0),
                    child: Text(
                      'Slide for a hint',
                      key: TopicHintSlider.labelKey,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: theme.textTheme.labelLarge
                          ?.withWeight(FontWeight.w800)
                          .copyWith(color: palette.onWarm),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: knobLeft,
                top: 0,
                width: height,
                height: height,
                child: GestureDetector(
                  key: TopicHintSlider.knobKey,
                  behavior: HitTestBehavior.opaque,
                  // Taken here, so a tap on the knob does nothing.
                  onTap: () {},
                  onHorizontalDragStart: _onDragStart,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: (_) => _end(),
                  onHorizontalDragCancel: _end,
                  onLongPressStart: _onLongPressStart,
                  onLongPressEnd: (_) => _end(),
                  onLongPressCancel: _end,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_double_arrow_right_rounded,
                        size: 22,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
