import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../models/climb_theme.dart';
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

  /// Its name (Batch 5, N6), the same in every theme: shown in the label
  /// when the avatar reaches it.
  String get name => ClimbSavePoints.names[object]!;

  /// The `save_point` value of `save_point_reached` (N21): the name in
  /// snake case.
  String get eventId => name.toLowerCase().replaceAll(' ', '_');

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

  /// N6: the save points' names, by object, the same in all four themes.
  /// The signpost has none: it is decoration (N11).
  static const names = {
    'tent': 'First Camp',
    'cabin': 'Halfway Hut',
    'fountain': 'Mountain Spring',
    'campfire': 'High Camp',
    'summit_flag': 'Summit',
  };

  /// G10: the flag split in two, for a theme that recolours the pennant:
  /// the pennant alone, and the flag without it (their alphas add up to the
  /// flag's, so together they fade like one object).
  static const pennantAsset = 'assets/climb/objects/summit_flag_pennant.webp';
  static const flagBaseAsset = 'assets/climb/objects/summit_flag_base.webp';

  static Color? _pennantForTesting;

  /// Debug builds only: stands in for a recolouring theme's pennant colour
  /// in tests and measuring tools (renders of candidate colours). Themes
  /// that keep the orange pennant are not affected. Ignored in profile and
  /// release builds.
  static set debugPennantColorOverride(Color? value) =>
      _pennantForTesting = value;

  /// The pennant colour [theme] draws, or null for the asset's own.
  static Color? pennantColorFor(ClimbTheme theme) =>
      theme.flagPennantColor == null
          ? null
          : (kDebugMode ? _pennantForTesting : null) ?? theme.flagPennantColor;

  /// The colour matrix that turns the pennant into [colour], keeping its
  /// shading: each pixel becomes [colour] scaled by its luminance over the
  /// pennant's median luminance ([climbPennantLuminance]).
  static List<double> pennantMatrix(Color colour) {
    const lr = .2126, lg = .7152, lb = .0722;
    List<double> row(double c) => [
          c * lr / climbPennantLuminance,
          c * lg / climbPennantLuminance,
          c * lb / climbPennantLuminance,
          0,
          0,
        ];
    return [
      ...row(colour.r),
      ...row(colour.g),
      ...row(colour.b),
      0, 0, 0, 1, 0, //
    ];
  }

  /// [outer] applied after [inner], as one colour matrix (5 × 4, offsets
  /// in 0–255 like Flutter's).
  static List<double> compose(List<double> outer, List<double> inner) {
    final out = List<double>.filled(20, 0);
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += outer[r * 5 + k] * inner[k * 5 + c];
        }
        out[r * 5 + c] = sum;
      }
      var offset = outer[r * 5 + 4];
      for (var k = 0; k < 4; k++) {
        offset += outer[r * 5 + k] * inner[k * 5 + 4];
      }
      out[r * 5 + 4] = offset;
    }
    return out;
  }

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

  /// The flag (the summit_flag asset), in themes that have one
  /// (`ClimbTheme.hasSummitFlag`): the month's goal, on its own clearing
  /// (C6, under the summit) by the save points' rule, but reached only on
  /// the month's last step, the summit (its arc is the whole trail's).
  static final ClimbSavePoint flag = () {
    final (clearing, object, cx, cy, bw, bh, ratio) = climbFlag;
    final p = _place(clearing, object, cx, cy, bw, bh, ratio);
    return ClimbSavePoint(
        clearing: p.clearing,
        object: p.object,
        rect: p.rect,
        arc: ClimbRoute.length);
  }();

  /// Decoration (Batch 5, N11, N18): the C5 signpost, from the generated
  /// table. Not a save point: never reached, never named, no label, always
  /// drawn lit (in dark mode through the theme's relighting like the rest).
  static final List<ClimbSavePoint> decor = [
    for (final (clearing, object, cx, cy, bw, bh, ratio) in climbDecorTable)
      _place(clearing, object, cx, cy, bw, bh, ratio),
  ];

  // G8: an unreached save point is faded, lower opacity and a slight
  // desaturation; reached, it takes its own colours.

  /// G6's strength in dark mode: 0 leaves the objects as they are, 1 is the
  /// full relighting measured from the clearings; in between, a linear mix.
  /// On the device (2026-10-01) the full filter made every object but the
  /// campfire darker than the scene; 0.6, 0.4 and 0.5 were tried there and
  /// 0.5 chosen (measured strengths: docs/design/scene-art/stage2/
  /// fix_dark_strength.txt). The flame layer is never filtered.
  static const defaultDarkFilterStrength = .5;

  static double? _strengthForTesting;

  /// Debug builds only: stands in for [defaultDarkFilterStrength] in tests
  /// and measuring tools (renders at other strengths). Ignored in profile
  /// and release builds.
  static set debugDarkFilterStrengthOverride(double? value) =>
      _strengthForTesting = value;

  static double get darkFilterStrength =>
      (kDebugMode ? _strengthForTesting : null) ?? defaultDarkFilterStrength;

  /// Opacity and saturation of an unreached save point.
  static const unreachedOpacity = .5;
  static const unreachedSaturation = .6;

  /// The colour matrix (Flutter's `ColorFilter.matrix`, 5 × 4) for a save
  /// point that is [lit] (0 unreached, 1 reached, in between while fading
  /// in), in dark mode with the theme's [darkGain] (G6), or null in light.
  static List<double> matrix(
      {required double lit,
      (double, double, double)? darkGain,
      double? strength}) {
    final s = unreachedSaturation + (1 - unreachedSaturation) * lit;
    final a = unreachedOpacity + (1 - unreachedOpacity) * lit;
    const lr = .2126, lg = .7152, lb = .0722;
    // The gain is diagonal, so mixing the object's own colour and the
    // filtered one linearly is the gain moved toward 1.
    final k = strength ?? darkFilterStrength;
    double mix(double g) => 1 + k * (g - 1);
    final (gr, gg, gb) = darkGain == null
        ? (1.0, 1.0, 1.0)
        : (mix(darkGain.$1), mix(darkGain.$2), mix(darkGain.$3));
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
