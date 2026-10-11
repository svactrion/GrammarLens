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

  static const EdgeInsets padding = EdgeInsets.fromLTRB(14, 12, 14, 12);

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

/// The handle in the "Your answer" row that reveals the topic's hint card
/// (Daily Test only). A 44 × 44 target.
///
/// **Reveal.** A sideways drag (horizontal only, so it never competes with
/// the question's vertical scroll) shows the card above the row in
/// proportion to how far the finger has moved, either way; on release it
/// springs closed. A long-press shows it whole while held and closes it on
/// release. Nothing stays open, and nothing else changes: the answer, its
/// focus and the keyboard are untouched (the keyboard stays up, owner
/// decision Q2 as revised), and nothing is scored, counted or logged.
///
/// **Place.** The card is drawn in the app's overlay, held to the row's
/// width, its bottom just above the row, so the finger on the handle is
/// below what it reveals. The cards are short enough to fit there with the
/// keyboard up on a 375 pt phone at Medium and Large, even under the
/// shortest question. Where one does not fit, it reaches down over the row
/// (a safety net on any phone), and on the smallest phones also over the
/// answer field and the Skip/Next bar, so it is always whole on screen
/// (see `_CardPlacement`). The handle is drawn again on top, so it stays
/// visible under the finger.
class TopicHintHandle extends StatefulWidget {
  final Topic topic;
  final List<String> points;

  /// The "Your answer" row: the card's width and the line it sits above.
  final GlobalKey rowKey;

  const TopicHintHandle({
    super.key,
    required this.topic,
    required this.points,
    required this.rowKey,
  });

  static const handleKey = ValueKey('topic_hint_handle');
  static const cardKey = ValueKey('topic_hint_card');
  static const coverKey = ValueKey('topic_hint_cover');

  /// The share of the row's width a drag must travel to show the whole card.
  static const double travelShare = 0.6;

  /// Space between the card and the row, and between the card and the
  /// status bar.
  static const double gap = 6;

  @override
  State<TopicHintHandle> createState() => _TopicHintHandleState();
}

class _TopicHintHandleState extends State<TopicHintHandle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal;
  final OverlayPortalController _portal = OverlayPortalController();
  final GlobalKey _handleKey = GlobalKey();

  /// Where the row and the handle are in the overlay, read when a reveal
  /// starts (nothing moves while one is under way).
  Rect? _row;
  Rect? _handle;
  double _top = 0;
  double _bottom = 0;

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

  Rect? _rectInOverlay(GlobalKey key, RenderBox overlay) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final topLeft = overlay.globalToLocal(box.localToGlobal(Offset.zero));
    return topLeft & box.size;
  }

  void _begin() {
    final overlayContext = Overlay.of(context).context;
    final overlay = overlayContext.findRenderObject()! as RenderBox;
    final row = _rectInOverlay(widget.rowKey, overlay);
    final handle = _rectInOverlay(_handleKey, overlay);
    if (row == null || handle == null) return;
    _holding = true;
    _row = row;
    _handle = handle;
    // The overlay's own MediaQuery: the Scaffold removes the status bar and
    // the keyboard from its body's, where this handle sits.
    final media = MediaQuery.of(overlayContext);
    _top = overlay.globalToLocal(Offset(0, media.padding.top)).dy +
        TopicHintHandle.gap;
    // The keyboard's top, or the screen's safe bottom without one.
    final bottomInset = media.viewInsets.bottom > media.padding.bottom
        ? media.viewInsets.bottom
        : media.padding.bottom;
    _bottom =
        overlay.globalToLocal(Offset(0, media.size.height - bottomInset)).dy -
            TopicHintHandle.gap;
    _reveal.stop();
    _portal.show();
  }

  void _end() {
    if (!_holding) return;
    _holding = false;
    if (_reduceMotion) {
      _reveal.value = 0;
      _portal.hide();
      return;
    }
    if (_reveal.value == 0) {
      _portal.hide();
      return;
    }
    // A spring ends within a tolerance of its target, not on it: the card
    // is put away once it has settled, unless a new reveal took over.
    _reveal
        .animateWith(SpringSimulation(_spring, _reveal.value, 0, 0))
        .whenCompleteOrCancel(() {
      if (!mounted || _holding) return;
      _reveal.value = 0;
      _portal.hide();
    });
  }

  void _onDragStart(DragStartDetails details) {
    _dragDistance = 0;
    _begin();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final row = _row;
    if (!_holding || row == null) return;
    _dragDistance += details.delta.dx;
    _reveal.value =
        (_dragDistance.abs() / (row.width * TopicHintHandle.travelShare))
            .clamp(0.0, 1.0);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    _begin();
    if (!_holding) return;
    if (_reduceMotion) {
      _reveal.value = 1;
    } else {
      _reveal
          .animateWith(SpringSimulation(_spring, _reveal.value, 1, 0))
          .whenComplete(() {
        if (mounted && _holding) _reveal.value = 1;
      });
    }
  }

  Widget _handleFace(BuildContext context) {
    final palette = AppPalette.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.warm,
            borderRadius: BorderRadius.circular(10),
          ),
          child: SizedBox(
            width: 36,
            height: 28,
            child: Icon(Icons.tips_and_updates_rounded,
                size: 17, color: palette.onWarm),
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context) {
    final row = _row;
    final handle = _handle;
    if (row == null || handle == null) return const SizedBox.shrink();
    final roomAbove = row.top - TopicHintHandle.gap - _top;
    final rowBottom = row.bottom - _top;
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: row.left,
            width: row.width,
            top: _top,
            height: _bottom - _top,
            child: ClipRect(
              child: CustomSingleChildLayout(
                delegate:
                    _CardPlacement(roomAbove: roomAbove, rowBottom: rowBottom),
                child: AnimatedBuilder(
                  animation: _reveal,
                  builder: (context, child) =>
                      _Revealed(fraction: _reveal.value, child: child!),
                  child: TopicHintCard(
                    key: TopicHintHandle.cardKey,
                    topic: widget.topic,
                    points: widget.points,
                  ),
                ),
              ),
            ),
          ),
          // The handle again, over a card that reaches down over the row.
          Positioned.fromRect(rect: handle, child: _handleFace(context)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = '${widget.topic.title} tip. ${widget.points.join('. ')}.';
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _overlay,
      child: Semantics(
        label: label,
        hint: 'Touch and hold to show',
        excludeSemantics: true,
        child: GestureDetector(
          key: TopicHintHandle.handleKey,
          behavior: HitTestBehavior.opaque,
          // Taken here, so a tap on the handle does not reach the screen's
          // tap-to-close-the-keyboard behind it.
          onTap: () {},
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: (_) => _end(),
          onHorizontalDragCancel: _end,
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: (_) => _end(),
          onLongPressCancel: _end,
          child: KeyedSubtree(key: _handleKey, child: _handleFace(context)),
        ),
      ),
    );
  }
}

/// The card's place in the area from the status bar down to the keyboard
/// (or the screen's safe bottom), first choice first:
///
/// 1. above the row, its bottom [TopicHintHandle.gap] over it ([roomAbove]);
/// 2. a safety net, on any phone: reaching down over the row, its bottom on
///    the row's bottom ([rowBottom]);
/// 3. the smallest phones (owner decision, 2026-10-12): from the top of the
///    area down over the answer field and the Skip/Next bar, as far as the
///    card needs. Only a card taller than the whole area would be cut, at
///    its bottom; none is (`test/topic_hint_card_test.dart`).
class _CardPlacement extends SingleChildLayoutDelegate {
  final double roomAbove;
  final double rowBottom;

  _CardPlacement({required this.roomAbove, required this.rowBottom});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tightFor(width: constraints.maxWidth);

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final height = childSize.height;
    if (height <= roomAbove) return Offset(0, roomAbove - height);
    if (height <= rowBottom) return Offset(0, rowBottom - height);
    return Offset.zero;
  }

  @override
  bool shouldRelayout(_CardPlacement oldDelegate) =>
      oldDelegate.roomAbove != roomAbove || oldDelegate.rowBottom != rowBottom;
}

/// The card with its cover slid aside: the first [fraction] of its width
/// shows, the rest is covered.
class _Revealed extends StatelessWidget {
  final double fraction;
  final Widget child;

  const _Revealed({required this.fraction, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(17),
      child: Stack(
        children: [
          child,
          if (fraction < 1)
            Positioned.fill(
              child: FractionallySizedBox(
                alignment: Alignment.centerRight,
                widthFactor: 1 - fraction,
                child: DecoratedBox(
                  key: TopicHintHandle.coverKey,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    border: Border(
                      left: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
