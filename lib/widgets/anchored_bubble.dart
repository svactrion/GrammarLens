import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../theme.dart';

/// A speech bubble placed from its speaker's place on screen (V12, v11):
/// [gap] points above [anchor] (the companion's box), its tail under the
/// anchor's centre, at least [edge] points from the screen's sides. When
/// there is no room above (it would cross [minTop]) it opens below the
/// anchor with the tail pointing up. Fills its parent (a screen-sized
/// `Stack`); only the bubble paints.
class AnchoredBubble extends StatelessWidget {
  final Rect anchor;
  final String text;

  /// The highest the bubble may reach (under the screen's top chips).
  final double minTop;

  /// The lowest the bubble may reach (above the screen's button).
  final double maxBottom;

  static const double gap = 12;
  static const double edge = 16;

  /// The tail: a 14 pt square turned 45°, its centre on the bubble's edge.
  static const double tailSize = 14;

  /// How far the tail's tip reaches past the bubble's edge.
  static double get tailReach => tailSize * math.sqrt2 / 2;

  /// The tail stays this far from the bubble's sides (its rounded corners).
  static const double tailInset = 22;

  static const bodyKey = ValueKey('anchored_bubble_body');
  static const tailDownKey = ValueKey('anchored_bubble_tail_down');
  static const tailUpKey = ValueKey('anchored_bubble_tail_up');

  const AnchoredBubble({
    super.key,
    required this.anchor,
    required this.text,
    required this.minTop,
    required this.maxBottom,
  });

  /// Whether a [height]-tall bubble opens above [anchor]: above when it
  /// stays under [minTop], else below when it stays over [maxBottom], else
  /// on the side with more room.
  static bool opensAbove(
      Rect anchor, double height, double minTop, double maxBottom) {
    final room = gap + tailReach + height;
    if (anchor.top - room >= minTop) return true;
    if (anchor.bottom + room <= maxBottom) return false;
    return anchor.top - minTop >= maxBottom - anchor.bottom;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return CustomMultiChildLayout(
      delegate: _Layout(anchor: anchor, minTop: minTop, maxBottom: maxBottom),
      children: [
        LayoutId(
          id: _Part.body,
          child: Container(
            key: bodyKey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: lipCard(c, radius: 20, lipHeight: 4),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall!
                  .withWeight(FontWeight.w800)
                  .copyWith(color: c.text, height: 1.3, fontSize: 16),
            ),
          ),
        ),
        // Over the body: the tail's inner half hides the body's border
        // where they meet.
        LayoutId(
            id: _Part.tailDown,
            child: _Tail(key: tailDownKey, c: c, pointsDown: true)),
        LayoutId(
            id: _Part.tailUp,
            child: _Tail(key: tailUpKey, c: c, pointsDown: false)),
      ],
    );
  }
}

enum _Part { body, tailDown, tailUp }

class _Layout extends MultiChildLayoutDelegate {
  final Rect anchor;
  final double minTop;
  final double maxBottom;

  _Layout(
      {required this.anchor, required this.minTop, required this.maxBottom});

  @override
  void performLayout(Size size) {
    const edge = AnchoredBubble.edge;
    final body = layoutChild(_Part.body,
        BoxConstraints(maxWidth: math.max(0, size.width - 2 * edge)));
    final down = layoutChild(_Part.tailDown, BoxConstraints.loose(size));
    final up = layoutChild(_Part.tailUp, BoxConstraints.loose(size));
    final reach = AnchoredBubble.tailReach;
    final above =
        AnchoredBubble.opensAbove(anchor, body.height, minTop, maxBottom);
    final cx = anchor.center.dx;
    final x = (cx - body.width / 2)
        .clamp(edge, math.max(edge, size.width - edge - body.width))
        .toDouble();
    final y = above
        ? anchor.top - AnchoredBubble.gap - reach - body.height
        : anchor.bottom + AnchoredBubble.gap + reach;
    positionChild(_Part.body, Offset(x, y));
    // The tail under (or over) the anchor's centre, off the corners; the
    // other one is put out of sight.
    final inset = math.min(AnchoredBubble.tailInset, body.width / 2);
    final tx = cx.clamp(x + inset, x + body.width - inset).toDouble();
    const away = Offset(-10000, -10000);
    if (above) {
      positionChild(_Part.tailDown,
          Offset(tx - down.width / 2, y + body.height - down.height / 2));
      positionChild(_Part.tailUp, away);
    } else {
      positionChild(_Part.tailUp, Offset(tx - up.width / 2, y - up.height / 2));
      positionChild(_Part.tailDown, away);
    }
  }

  @override
  bool shouldRelayout(_Layout old) =>
      old.anchor != anchor ||
      old.minTop != minTop ||
      old.maxBottom != maxBottom;
}

/// The tail: a square turned 45°, bordered on the two sides that face the
/// speaker (down: right and bottom; up: left and top).
class _Tail extends StatelessWidget {
  final AppColors c;
  final bool pointsDown;
  const _Tail({super.key, required this.c, required this.pointsDown});

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: c.line, width: 2);
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: AnchoredBubble.tailSize,
        height: AnchoredBubble.tailSize,
        decoration: BoxDecoration(
          color: c.card,
          border: pointsDown
              ? Border(right: side, bottom: side)
              : Border(left: side, top: side),
        ),
      ),
    );
  }
}
