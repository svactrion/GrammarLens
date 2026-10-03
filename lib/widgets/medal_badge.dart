import 'package:flutter/material.dart';

import '../models/climb_theme.dart';
import '../models/medal_tier.dart';

/// The medal images (Batch 5, N1–N3, N23): composed ahead of time by
/// tool/medals/export_medal_assets.py, one per theme and tier plus the
/// Welcome badge. The app only picks one; it never layers a medal.
abstract final class MedalArt {
  /// [themeId]'s medal for [tier]; an unknown id draws Green Slope's, as
  /// the scene does (`ClimbThemes.byId`).
  static String monthly(String themeId, MedalTier tier) =>
      'assets/medals/medal_${ClimbThemes.byId(themeId).id}_${tier.name}.webp';

  static const welcome = 'assets/medals/medal_welcome.webp';

  /// The image's square canvas over the body's disc
  /// (docs/design/batch5/medal_assets.txt: a 681.95 px disc on a 768 px
  /// canvas, centred on it to within 0.2 % of the diameter).
  static const canvasOverDisc = 768 / 681.95;

  /// How far a monthly medal's stars stand above the disc, as a share of
  /// its diameter (up to 0.054 measured; Gold's three). The Welcome ribbon
  /// stays inside the disc's bounding square, so it needs none.
  static const starsAbove = .056;
}

/// A medal (Batch 5): the composed image for a theme and tier, or the
/// Welcome badge. The caller gives the body's disc diameter, [disc]; the
/// widget lays itself out [disc] wide and, for a monthly medal,
/// `disc × (1 + MedalArt.starsAbove)` tall, the stars' room above the disc,
/// so nothing it draws leaves its box. Shared by Profile, the month card and
/// the celebration (M8: the medal is drawn in one place).
///
/// Not earned, it is faded (N10): [unearnedOpacity] and
/// [unearnedSaturation], with no separate image. Decorative: the caller
/// says what it is.
class MedalBadge extends StatelessWidget {
  /// The asset drawn ([MedalArt]).
  final String asset;

  /// The body's disc, in points.
  final double disc;

  final bool earned;

  /// Whether the stars' room is reserved above the disc (a monthly medal).
  final bool _stars;

  MedalBadge.monthly({
    super.key,
    required String themeId,
    required MedalTier tier,
    required this.disc,
    this.earned = true,
  })  : asset = MedalArt.monthly(themeId, tier),
        _stars = true;

  const MedalBadge.welcome({
    super.key,
    required this.disc,
    this.earned = true,
  })  : asset = MedalArt.welcome,
        _stars = false;

  /// N10: an unearned medal's opacity and saturation.
  static const unearnedOpacity = .5;
  static const unearnedSaturation = .6;

  /// The box a medal with [disc] takes: its width and height.
  static Size boxFor(double disc, {bool stars = true}) =>
      Size(disc, stars ? disc * (1 + MedalArt.starsAbove) : disc);

  /// The colour matrix of an unearned medal (Flutter's 5 × 4): toward the
  /// Rec. 709 grey by 1 − [unearnedSaturation], at [unearnedOpacity].
  static List<double> get unearnedMatrix {
    const s = unearnedSaturation, a = unearnedOpacity;
    const lr = .2126, lg = .7152, lb = .0722;
    List<double> row(double r0, double g0, double b0) => [
          (1 - s) * lr + s * r0,
          (1 - s) * lg + s * g0,
          (1 - s) * lb + s * b0,
          0,
          0,
        ];
    return [
      ...row(1, 0, 0),
      ...row(0, 1, 0),
      ...row(0, 0, 1),
      0, 0, 0, a, 0, //
    ];
  }

  @override
  Widget build(BuildContext context) {
    final box = boxFor(disc, stars: _stars);
    final side = disc * MedalArt.canvasOverDisc;
    Widget image = Image.asset(asset,
        width: side,
        height: side,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        excludeFromSemantics: true,
        gaplessPlayback: true);
    if (!earned) {
      image = ColorFiltered(
          colorFilter: ColorFilter.matrix(unearnedMatrix), child: image);
    }
    // The disc sits at the box's bottom; the canvas is centred on it and
    // its transparent margin may reach past the box (nothing visible does).
    final discTop = box.height - disc;
    return SizedBox.fromSize(
      size: box,
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
            left: disc / 2 - side / 2,
            top: discTop + disc / 2 - side / 2,
            width: side,
            height: side,
            child: image),
      ]),
    );
  }
}
