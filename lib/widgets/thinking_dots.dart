import 'package:flutter/material.dart';

import '../motion.dart';

/// Three dots pulsing one after another (the boards' `gl-dots`: 1.2 s,
/// 0.2 s apart): V18 under the thinking companion, V04's bubble while the
/// companion listens. Still (full colour) with the loops off.
class ThinkingDots extends StatefulWidget {
  final Color color;
  final double size;
  final double gap;

  const ThinkingDots({
    super.key,
    required this.color,
    this.size = 9,
    this.gap = 5,
  });

  @override
  State<ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<ThinkingDots>
    with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loop == null && AppMotion.loopsOn(context)) {
      _loop = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  double _alpha(int i) {
    final loop = _loop;
    if (loop == null) return 1;
    final t = (loop.value - i * .2 / 1.2) % 1;
    return t < .4
        ? .2 + .8 * t / .4
        : t < .8
            ? 1 - .8 * (t - .4) / .4
            : .2;
  }

  @override
  Widget build(BuildContext context) {
    Widget dots() => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: widget.size,
                height: widget.size,
                margin: EdgeInsetsDirectional.only(end: i < 2 ? widget.gap : 0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: _alpha(i)),
                ),
              ),
          ],
        );
    final loop = _loop;
    return ExcludeSemantics(
      child: loop == null
          ? dots()
          : AnimatedBuilder(animation: loop, builder: (context, _) => dots()),
    );
  }
}
