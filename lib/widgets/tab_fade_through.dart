import 'package:flutter/material.dart';

/// The tab switch transition (1.2.0 Batch 6, owner: Review "appeared like a
/// teleport" from Home's call-out). Wraps the shell's `IndexedStack`, which
/// keeps every tab's State, scroll position and loaded data exactly as
/// before: nothing is rebuilt or re-keyed here. When [index] changes, the
/// tab that is now shown fades in from the page and settles from a 2 %
/// smaller scale over [duration] with an ease-out curve; the tab being left
/// goes at once, as the IndexedStack always did — a fade through the page
/// colour rather than a cross-fade, so two tabs are never drawn together.
///
/// Every way of switching tabs goes through the same `IndexedStack` index
/// (the nav bar, Home's Review call-out, Review's "Go to Daily Test"), so
/// all of them get the same transition. A switch during a transition
/// simply restarts it for the new tab. With reduce motion
/// (`MediaQuery.disableAnimations`) the switch is immediate.
class TabFadeThrough extends StatefulWidget {
  final int index;
  final Widget child;

  const TabFadeThrough({super.key, required this.index, required this.child});

  static const duration = Duration(milliseconds: 220);
  static const curve = Curves.easeOut;
  static const startScale = 0.98;

  @override
  State<TabFadeThrough> createState() => _TabFadeThroughState();
}

class _TabFadeThroughState extends State<TabFadeThrough>
    with SingleTickerProviderStateMixin {
  // Starts complete: the first tab is shown without a transition.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TabFadeThrough.duration,
    value: 1,
  );
  late final Animation<double> _curved =
      CurvedAnimation(parent: _controller, curve: TabFadeThrough.curve);
  late final Animation<double> _scale =
      Tween(begin: TabFadeThrough.startScale, end: 1.0).animate(_curved);

  @override
  void didUpdateWidget(TabFadeThrough oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index == widget.index) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
