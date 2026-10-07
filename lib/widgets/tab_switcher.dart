import 'package:flutter/material.dart';

/// How a tab switch looks ([TabSwitcher]).
enum TabTransition {
  /// Batch 6's fade-through: the new tab fades in and settles from 0.98
  /// scale; the tab being left goes at once. Every switch but one.
  fade,

  /// The content slides left: the old tab leaves to the left, the new one
  /// comes in from the right. Only Home's "Go to Review" card (owner,
  /// 1.2.0 Batch 9).
  slide,
}

/// The shell's tab screens and the motion between them: the one place a
/// tab switch is drawn (1.2.0 Batch 9). It replaces Batch 6's
/// `TabFadeThrough` over an `IndexedStack`, and Batch 7's `TabSlideSwitcher`
/// (removed in Batch 8, the base of this widget), so the fade and the slide
/// are two looks of one mechanism, picked per switch by [transition].
///
/// Every tab is built once and stays in the tree in a fixed, keyed slot; a
/// tab not in view is [Offstage], as in an `IndexedStack`: still laid out,
/// its State kept and its tickers running, but not painted, not hit and not
/// in the semantics tree (test finders skip it, too). Only the order of the
/// slots changes, so nothing is rebuilt from scratch: State, scroll
/// position and loaded data are kept.
///
/// - [TabTransition.fade]: [fadeDuration] (220 ms) with [fadeCurve]; the
///   new tab fades in from [fadeStartScale]; the old one goes at once, so
///   two tabs are never drawn together.
/// - [TabTransition.slide]: [slideDuration] (320 ms) with [slideCurve]; both
///   tabs move a full width together, in the direction of the tab order
///   (to a tab on the right the content moves left). Taps on the tab being
///   left are swallowed until the slide ends. Shorter than Batch 7's
///   500 ms iOS route slide, which the owner found exaggerated for a tab.
///
/// Only the content moves: this is the shell's body; the nav bar sits above
/// it and does not move, and its selection updates at once. A switch during
/// a transition starts a new one from the tab selected last, so a second
/// tap lands on the tab tapped. With reduce motion
/// (`MediaQuery.disableAnimations`) every switch is immediate. No edge
/// swipe back: tabs are not routes.
class TabSwitcher extends StatefulWidget {
  final int index;

  /// The look of the switch to [index]; read when [index] changes.
  final TabTransition transition;
  final List<Widget> children;

  const TabSwitcher({
    super.key,
    required this.index,
    this.transition = TabTransition.fade,
    required this.children,
  });

  static const fadeDuration = Duration(milliseconds: 220);
  static const fadeCurve = Curves.easeOut;
  static const fadeStartScale = 0.98;

  static const slideDuration = Duration(milliseconds: 320);
  static const slideCurve = Curves.easeOutCubic;

  /// The slot of tab [i], for tests.
  static ValueKey<String> slotKey(int i) => ValueKey('tab_slot_$i');

  @override
  State<TabSwitcher> createState() => _TabSwitcherState();
}

class _TabSwitcherState extends State<TabSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _fade;
  late final CurvedAnimation _slide;

  /// The running transition's look.
  TabTransition _transition = TabTransition.fade;

  /// The tab being left while a slide runs; null otherwise (a fade drops
  /// the old tab at once).
  int? _from;

  /// +1 when the new tab is to the right of the old one, −1 when left.
  double _direction = 1;

  @override
  void initState() {
    super.initState();
    // Starts complete: the first tab is shown without a transition.
    _controller = AnimationController(
      vsync: this,
      duration: TabSwitcher.fadeDuration,
      value: 1,
    )..addStatusListener(_onStatus);
    _fade = CurvedAnimation(parent: _controller, curve: TabSwitcher.fadeCurve);
    _slide =
        CurvedAnimation(parent: _controller, curve: TabSwitcher.slideCurve);
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _from != null) {
      setState(() => _from = null);
    }
  }

  @override
  void didUpdateWidget(TabSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = null;
      _controller.value = 1;
      return;
    }
    _transition = widget.transition;
    final slide = _transition == TabTransition.slide;
    _from = slide ? oldWidget.index : null;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _controller.duration =
        slide ? TabSwitcher.slideDuration : TabSwitcher.fadeDuration;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    _slide.dispose();
    _controller.dispose();
    super.dispose();
  }

  Animation<Offset> _offsetFor(int i) {
    if (_from == null) return const AlwaysStoppedAnimation(Offset.zero);
    if (i == widget.index) {
      return Tween(begin: Offset(_direction, 0), end: Offset.zero)
          .animate(_slide);
    }
    if (i == _from) {
      return Tween(begin: Offset.zero, end: Offset(-_direction, 0))
          .animate(_slide);
    }
    return const AlwaysStoppedAnimation(Offset.zero);
  }

  bool get _fading => _transition == TabTransition.fade;

  Animation<double> _opacityFor(int i) =>
      _fading && i == widget.index ? _fade : const AlwaysStoppedAnimation(1);

  Animation<double> _scaleFor(int i) => _fading && i == widget.index
      ? Tween(begin: TabSwitcher.fadeStartScale, end: 1.0).animate(_fade)
      : const AlwaysStoppedAnimation(1);

  @override
  Widget build(BuildContext context) {
    final from = _from;
    // Paint order: the hidden tabs, the tab being left, the new tab on top.
    final order = [
      for (var i = 0; i < widget.children.length; i++)
        if (i != widget.index && i != from) i,
      if (from != null) from,
      widget.index,
    ];
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final i in order)
          KeyedSubtree(
            key: TabSwitcher.slotKey(i),
            child: SlideTransition(
              position: _offsetFor(i),
              child: FadeTransition(
                opacity: _opacityFor(i),
                child: ScaleTransition(
                  scale: _scaleFor(i),
                  child: AbsorbPointer(
                    absorbing: i == from,
                    child: Offstage(
                      offstage: i != widget.index && i != from,
                      child: widget.children[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
