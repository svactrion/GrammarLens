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

  /// The campfire's flame only (tool/scene_art/export_objects.py): drawn
  /// unfiltered over the filtered campfire in dark mode once reached (G6).
  static const flameAsset = 'assets/climb/objects/campfire_flame.webp';

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

  // G8: an unreached save point is faded, lower opacity and a slight
  // desaturation; reached, it takes its own colours.

  /// Opacity and saturation of an unreached save point.
  static const unreachedOpacity = .5;
  static const unreachedSaturation = .6;

  /// The colour matrix (Flutter's `ColorFilter.matrix`, 5 × 4) for a save
  /// point that is [lit] (0 unreached, 1 reached, in between while fading
  /// in), in dark mode with the theme's [darkGain] (G6), or null in light.
  static List<double> matrix(
      {required double lit, (double, double, double)? darkGain}) {
    final s = unreachedSaturation + (1 - unreachedSaturation) * lit;
    final a = unreachedOpacity + (1 - unreachedOpacity) * lit;
    const lr = .2126, lg = .7152, lb = .0722;
    final (gr, gg, gb) = darkGain ?? (1.0, 1.0, 1.0);
    List<double> row(double g, double r0, double g0, double b0) => [
          g * ((1 - s) * lr + s * r0),
          g * ((1 - s) * lg + s * g0),
          g * ((1 - s) * lb + s * b0),
          0,
          0,
        ];
    return [
      ...row(gr, 1, 0, 0),
      ...row(gg, 0, 1, 0),
      ...row(gb, 0, 0, 1),
      0, 0, 0, a, 0, //
    ];
  }

  /// [matrix] applied to [c] (for tests and measuring).
  static Color apply(List<double> m, Color c) {
    final v = [c.r, c.g, c.b, c.a];
    double ch(int row) {
      final o = row * 5;
      return (m[o] * v[0] + m[o + 1] * v[1] + m[o + 2] * v[2] + m[o + 3] * v[3])
              .clamp(0.0, 1.0) +
          m[o + 4] / 255;
    }

    return Color.from(alpha: ch(3), red: ch(0), green: ch(1), blue: ch(2));
  }
}
