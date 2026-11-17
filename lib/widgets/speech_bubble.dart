import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../theme.dart';

/// Where a [SpeechBubble]'s pointer sits: towards the companion.
enum BubblePointer { start, bottomStart, bottom, none }

/// A companion's speech bubble (V04, V05, V05b, V07): a white card with a
/// 2 px border and a 4 px lip, bold text, a pointer towards the speaker.
/// Pops in (0.8 → 1, easeOutBack) when it appears or its text changes.
class SpeechBubble extends StatelessWidget {
  final String text;
  final BubblePointer pointer;
  final bool compact;

  const SpeechBubble({
    super.key,
    required this.text,
    this.pointer = BubblePointer.bottomStart,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    final bubble = Container(
      padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16, vertical: compact ? 8 : 12),
      decoration: lipCard(c, radius: 20, lipHeight: 4),
      child: Text(
        text,
        style: (compact
                ? theme.textTheme.labelLarge!
                : theme.textTheme.titleSmall!)
            .withWeight(FontWeight.w800)
            .copyWith(color: c.text, height: 1.3, fontSize: compact ? 14 : 16),
      ),
    );
    final Widget withPointer = switch (pointer) {
      BubblePointer.none => bubble,
      BubblePointer.start => Stack(clipBehavior: Clip.none, children: [
          bubble,
          PositionedDirectional(
            start: -7,
            top: 0,
            bottom: 0,
            child: Center(child: _Tip(c: c, angle: .785)),
          ),
        ]),
      BubblePointer.bottomStart => Stack(clipBehavior: Clip.none, children: [
          bubble,
          PositionedDirectional(
              start: 26, bottom: -7, child: _Tip(c: c, angle: .785)),
        ]),
      BubblePointer.bottom => Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            bubble,
            Positioned(bottom: -7, child: _Tip(c: c, angle: .785)),
          ],
        ),
    };
    return TweenAnimationBuilder<double>(
      key: ValueKey(text),
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.entrance(context, AppMotion.base),
      curve: AppMotion.reduced(context) ? Curves.linear : AppMotion.pop,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: AppMotion.reduced(context) ? 1 : .8 + .2 * t,
          alignment: AlignmentDirectional.bottomStart,
          child: child,
        ),
      ),
      child: withPointer,
    );
  }
}

/// The bubble's small square tip, rotated 45°, bordered on its two outer
/// sides.
class _Tip extends StatelessWidget {
  final AppColors c;
  final double angle;
  const _Tip({required this.c, required this.angle});

  @override
  Widget build(BuildContext context) => Transform.rotate(
        angle: angle,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: c.card,
            border: Border(
              bottom: BorderSide(color: c.line, width: 2),
              left: BorderSide(color: c.line, width: 2),
            ),
          ),
        ),
      );
}
