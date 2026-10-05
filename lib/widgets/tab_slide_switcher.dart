import 'package:flutter/cupertino.dart';

/// The shell's tab screens and the motion between them (1.2.0 Batch 7,
/// owner: the app's own page transition, the slide Premium opens with).
/// It replaces Batch 6's `TabFadeThrough` over an `IndexedStack`, and does
/// the stack's job itself, because a slide has to draw two tabs at once.
///
/// Every tab is built once and stays in the tree in a fixed, keyed slot;
/// a tab not in view is [Offstage], as in an `IndexedStack`: still laid
/// out, its State kept and its tickers running, but not painted, not hit
/// and not in the semantics tree (finders in tests skip it, too). Only the
/// order of the slots changes, so nothing is rebuilt from scratch: State,
/// scroll position and loaded data are kept.
///
/// When [index] changes, the new tab slides in over the old one and the old
/// one moves away under it, with the values of the iOS page route every
/// pushed screen uses (`CupertinoPageTransitionsBuilder`, the platform
/// default for `MaterialPageRoute` on iOS; Premium is pushed with one):
/// [duration] (500 ms), the new tab from a full width away with
/// [incomingCurve], the old one a third of the width the other way with
/// [outgoingCurve]. The direction follows the tab order: to a tab further
/// right the new content comes in from the right and the old leaves to the
/// left; going left, the mirror image. The route's edge shadow is not
/// copied.
///
/// - Only the content moves: this is the shell's body; the nav bar sits
///   above it and does not move, and its selection updates at once.
/// - Taps on the tab being left are swallowed until the slide ends.
/// - A switch during a slide starts a new one from the tab selected last,
///   so a second tap lands on the tab tapped.
/// - With reduce motion (`MediaQuery.disableAnimations`) the switch is
///   immediate.
/// - No edge swipe back: tabs are not routes.
///
/// Every way of switching tabs changes the same [index] (the nav bar,
/// Home's Review call-out, Review's "Go to Daily Test"), so all of them get
/// the same slide.
class TabSlideSwitcher extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const TabSlideSwitcher(
      {super.key, required this.index, required this.children});

  /// The iOS page route's duration and curves (`CupertinoPageTransition`).
  static const duration = CupertinoRouteTransitionMixin.kTransitionDuration;
  static const incomingCurve = Curves.fastEaseInToSlowEaseOut;
  static const outgoingCurve = Curves.linearToEaseOut;

  /// How far the tab being left moves, as a share of the width (the
  /// route's parallax).
  static const outgoingShift = 1 / 3;

  /// The slot of tab [i], for tests.
  static ValueKey<String> slotKey(int i) => ValueKey('tab_slot_$i');

  @override
  State<TabSlideSwitcher> createState() => _TabSlideSwitcherState();
}

class _TabSlideSwitcherState extends State<TabSlideSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _incoming;
  late final Animation<double> _outgoing;

  /// The tab being left while a slide runs; null otherwise.
  int? _from;

  /// +1 when the new tab is to the right of the old one, −1 when left.
  double _direction = 1;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _from != null) {
      setState(() => _from = null);
    }
  }

  @override
  void initState() {
    super.initState();
    // Starts complete: the first tab is shown without a transition.
    _controller = AnimationController(
      vsync: this,
      duration: TabSlideSwitcher.duration,
      value: 1,
    )..addStatusListener(_onStatus);
    _incoming = CurvedAnimation(
        parent: _controller, curve: TabSlideSwitcher.incomingCurve);
    _outgoing = CurvedAnimation(
        parent: _controller, curve: TabSlideSwitcher.outgoingCurve);
  }

  @override
  void didUpdateWidget(TabSlideSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _from = null;
      _controller.value = 1;
      return;
    }
    _from = oldWidget.index;
    _direction = widget.index > oldWidget.index ? 1 : -1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<Offset> _offsetFor(int i) {
    if (i == widget.index && _from != null) {
      return Tween(begin: Offset(_direction, 0), end: Offset.zero)
          .animate(_incoming);
    }
    if (i == _from) {
      return Tween(
              begin: Offset.zero,
              end: Offset(-_direction * TabSlideSwitcher.outgoingShift, 0))
          .animate(_outgoing);
    }
    return const AlwaysStoppedAnimation(Offset.zero);
  }

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
            key: TabSlideSwitcher.slotKey(i),
            child: SlideTransition(
              position: _offsetFor(i),
              child: AbsorbPointer(
                absorbing: i == from,
                child: Offstage(
                  offstage: i != widget.index && i != from,
                  child: widget.children[i],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
