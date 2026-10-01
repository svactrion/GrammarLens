import 'dart:ui';

import 'climb_route.dart';
import 'climb_save_point_table.dart';
import 'climb_trail_table.dart';

/// One save point (scene art G4, G9): an object on a clearing beside a
/// bend, the same in every month.
class ClimbSavePoint {
  /// The clearing, `C1`–`C4` (Scene Art Batch 0).
  final String clearing;

  /// The object: `tent`, `cabin`, `fountain` or `campfire`.
  final String object;

  /// The object's box, in image widths (`ClimbRoute`'s unit); its bottom
  /// edge is the object's base.
  final Rect rect;

  /// How far along the trail the save point is: the arc length, in image
  /// widths, of the trail point nearest its clearing's centre.
  final double arc;

  const ClimbSavePoint(
      {required this.clearing,
      required this.object,
      required this.rect,
      required this.arc});

  String get asset => ClimbSavePoints.assetFor(object);

  /// G8's "reached": the avatar's arc along the trail is at least [arc].
  bool reachedAt(double avatarArc) => avatarArc >= arc - 1e-9;

  /// The first step of a [days]-day month that reaches it.
  int reachedOn(int days) {
    final route = ClimbRoute(days);
    for (var d = 0; d <= days; d++) {
      if (reachedAt(route.arcAt(d.toDouble()))) return d;
    }
    return days;
  }
}

abstract final class ClimbSavePoints {
  static String assetFor(String object) => 'assets/climb/objects/$object.webp';

  /// The four save points, from the generated table.
  static final List<ClimbSavePoint> all = [
    for (final (clearing, object, cx, cy, bw, bh, ratio) in climbSavePointTable)
      _place(clearing, object, cx, cy, bw, bh, ratio),
  ];

  static ClimbSavePoint _place(String clearing, String object, double cx,
      double cy, double bw, double bh, double ratio) {
    final width = bw * ratio;
    final height = width * climbObjectAspects[object]!;
    final base = (cy + climbSavePointBaseDrop * bh) / climbImageAspect;
    final centre = Offset(cx, cy / climbImageAspect);
    var arc = 0.0, nearest = double.infinity;
    for (var s = 0.0; s <= ClimbRoute.length; s += ClimbRoute.length / 2000) {
      final d = (ClimbRoute.at(s) - centre).distance;
      if (d < nearest) {
        nearest = d;
        arc = s;
      }
    }
    return ClimbSavePoint(
        clearing: clearing,
        object: object,
        rect:
            Rect.fromLTRB(cx - width / 2, base - height, cx + width / 2, base),
        arc: arc);
  }

  /// The summit flag's box, in image widths: beside the trail's end, in
  /// themes whose summit suits it (`ClimbTheme.hasSummitFlag`).
  static final Rect summitFlag = () {
    final (x, y, w) = climbSummitFlag;
    final h = w * climbObjectAspects['summit_flag']!;
    final base = y / climbImageAspect;
    return Rect.fromLTRB(x - w / 2, base - h, x + w / 2, base);
  }();

  /// The colour matrix that leaves an object as it is.
  static const identity = <double>[
    1, 0, 0, 0, 0, //
    0, 1, 0, 0, 0, //
    0, 0, 1, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}
