import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion.dart';
import 'medal_celebration.dart' show CelebrationRays;

/// Turning celebration rays (SPEC §3.6; V11, R05, PW05, V05b): a soft glow
/// and light wedges in [color], one turn per [period] (R05: 40 s). Under
/// Reduce Motion (and while loops are off) they stand still.
class Rays extends StatefulWidget {
  final Color color;
  final double size;
  final Duration period;

  const Rays({
    super.key,
    required this.color,
    this.size = 320,
    this.period = const Duration(seconds: 40),
  });

  @override
  State<Rays> createState() => _RaysState();
}

class _RaysState extends State<Rays> with SingleTickerProviderStateMixin {
  AnimationController? _turn;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = AppMotion.loopsOn(context);
    if (on && _turn == null) {
      _turn = AnimationController(vsync: this, duration: widget.period)
        ..repeat();
    } else if (!on && _turn != null) {
      _turn!.dispose();
      _turn = null;
    }
  }

  @override
  void dispose() {
    _turn?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget paint(double t) => CustomPaint(
          size: Size.square(widget.size),
          painter: CelebrationRays(colour: widget.color, turn: t * 2 * math.pi),
        );
    final turn = _turn;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: turn == null
              ? paint(0)
              : AnimatedBuilder(
                  animation: turn, builder: (context, _) => paint(turn.value)),
        ),
      ),
    );
  }
}
