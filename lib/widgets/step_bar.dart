import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';

/// The segmented bar (SPEC §3.6): a row of rounded segments, each either
/// empty (the [track] colour) or filled with its own colour. When a segment
/// becomes filled it fills from the start edge, one segment after another
/// ([stagger] apart), with a small jiggle at the end of each.
///
/// Used by the Daily Test card (5 questions), the question progress, the
/// mastery strips (3), the sessions counter (5) and the daily limit.
class StepBar extends StatefulWidget {
  /// One entry per segment: its fill colour, or null for empty.
  final List<Color?> segments;
  final Color track;
  final double height;
  final double gap;

  /// Delay between two segments filling.
  final Duration stagger;

  /// Whether segments already filled on the first build animate in (true:
  /// a strip that fills on entry; false: shown as they are).
  final bool animateOnMount;

  /// Called when a segment finishes filling (for a light haptic per
  /// segment).
  final ValueChanged<int>? onFilled;

  /// An empty segment drawn in [highlightColor] instead of the track (the
  /// question being answered, V07).
  final int? highlight;
  final Color? highlightColor;

  const StepBar({
    super.key,
    required this.segments,
    required this.track,
    this.height = 8,
    this.gap = 5,
    this.stagger = const Duration(milliseconds: 100),
    this.animateOnMount = false,
    this.onFilled,
    this.highlight,
    this.highlightColor,
  });

  @override
  State<StepBar> createState() => _StepBarState();
}

class _StepBarState extends State<StepBar> with SingleTickerProviderStateMixin {
  static const _fillDuration = Duration(milliseconds: 280);

  late final AnimationController _controller;

  /// Segments filling in the current run: segment index → its order in the
  /// run (0, 1, 2, …).
  Map<int, int> _filling = {};
  final Set<int> _reported = {};
  List<Color?> _shown = const [];
  bool _first = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this)..addListener(_onTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_first) {
      _first = false;
      _shown = widget.animateOnMount
          ? List<Color?>.filled(widget.segments.length, null)
          : List.of(widget.segments);
      _sync();
    }
  }

  @override
  void didUpdateWidget(StepBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final next = widget.segments;
    final newly = <int>[
      for (var i = 0; i < next.length; i++)
        if ((i >= _shown.length || _shown[i] == null) && next[i] != null) i,
    ];
    _shown = List.of(next);
    if (newly.isEmpty) return;
    if (AppMotion.reduced(context)) {
      newly.forEach(widget.onFilled?.call ?? (_) {});
      return;
    }
    _filling = {for (var k = 0; k < newly.length; k++) newly[k]: k};
    _reported.clear();
    _controller.duration = widget.stagger * (newly.length - 1) + _fillDuration;
    _controller.forward(from: 0);
  }

  /// This segment's own progress (0–1) in the current run.
  double _progressOf(int i) {
    final order = _filling[i];
    if (order == null) return 1;
    final total = _controller.duration!.inMicroseconds;
    if (total == 0) return 1;
    final start = (widget.stagger * order).inMicroseconds / total;
    final span = _fillDuration.inMicroseconds / total;
    return ((_controller.value - start) / span).clamp(0.0, 1.0);
  }

  void _onTick() {
    for (final i in _filling.keys) {
      if (!_reported.contains(i) && _progressOf(i) >= 1) {
        _reported.add(i);
        widget.onFilled?.call(i);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.circular(widget.height / 2);
    return SizedBox(
      height: widget.height,
      child: Row(
        children: [
          for (var i = 0; i < widget.segments.length; i++) ...[
            if (i > 0) SizedBox(width: widget.gap),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                    color:
                        i == widget.highlight && widget.highlightColor != null
                            ? widget.highlightColor
                            : widget.track,
                    borderRadius: radius),
                child: widget.segments[i] == null
                    ? const SizedBox.expand()
                    : _segment(i, widget.segments[i]!, radius, rtl),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _segment(int i, Color color, BorderRadius radius, bool rtl) {
    final fill = DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: radius),
      child: const SizedBox.expand(),
    );
    if (!_filling.containsKey(i)) return fill;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _progressOf(i);
        // Fill (0–70 %), then a jiggle: ±1.2° and a 1 px bump.
        final grow = Curves.easeOutCubic.transform((t / .7).clamp(0.0, 1.0));
        final j =
            t < .7 || t >= 1 ? 0.0 : math.sin((t - .7) / .3 * math.pi * 2);
        return Transform.translate(
          offset: Offset(0, -1.0 * j),
          child: Transform.rotate(
            angle: j * 1.2 * math.pi / 180,
            child: FractionallySizedBox(
              alignment: rtl ? Alignment.centerRight : Alignment.centerLeft,
              widthFactor: grow,
              child: child,
            ),
          ),
        );
      },
      child: fill,
    );
  }
}
