import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// A skeleton bar with a shimmer that crosses it every 1.4 s (H03, X05,
/// V18). The shimmer is an ambient loop: it stops under Reduce Motion.
class SkeletonBar extends StatefulWidget {
  final double? width;
  final double height;
  final double? radius;

  /// A fraction of the parent's width instead of [width].
  final double? widthFactor;
  final Color? color;
  final Color? highlight;

  const SkeletonBar({
    super.key,
    this.width,
    required this.height,
    this.radius,
    this.widthFactor,
    this.color,
    this.highlight,
  });

  @override
  State<SkeletonBar> createState() => _SkeletonBarState();
}

class _SkeletonBarState extends State<SkeletonBar>
    with SingleTickerProviderStateMixin {
  AnimationController? _loop;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = AppMotion.loopsOn(context);
    if (on && _loop == null) {
      _loop = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1400))
        ..repeat();
    } else if (!on && _loop != null) {
      _loop!.dispose();
      _loop = null;
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final base = widget.color ?? c.skeleton;
    final high = widget.highlight ?? c.skeletonHighlight;
    final radius = BorderRadius.circular(widget.radius ?? widget.height / 2);
    Widget bar(double t) => DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 4 * t - 1.5, 0),
              end: Alignment(-1 + 4 * t + .5, 0),
              colors: [base, high, base],
            ),
          ),
          child: SizedBox(width: widget.width, height: widget.height),
        );
    Widget child = _loop == null
        ? DecoratedBox(
            decoration: BoxDecoration(color: base, borderRadius: radius),
            child: SizedBox(width: widget.width, height: widget.height),
          )
        : AnimatedBuilder(
            animation: _loop!, builder: (context, _) => bar(_loop!.value));
    if (widget.widthFactor != null) {
      child = FractionallySizedBox(
        alignment: AlignmentDirectional.centerStart,
        widthFactor: widget.widthFactor,
        child: child,
      );
    }
    return ExcludeSemantics(child: child);
  }
}
