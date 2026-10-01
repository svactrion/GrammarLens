import 'dart:math' as math;
import 'dart:ui';

import 'climb_route.dart';

/// How the scene's image is placed in the Home window: the camera, a layer
/// of its own (design decision D3), so a change of framing never touches
/// the step table.
///
/// Framing K-b (scene art G2): the image is fitted to the window's width
/// and zoomed [zoom] times; the camera follows the pawn on both axes, the
/// pawn centered across and at [pawnAt] of the window's height, clamped so
/// the window never shows past the image.
class ClimbCamera {
  /// G2: 1.1× for the daily view, chosen on a device after trying 1.3, 1.0
  /// and 1.1 (2026-10-01). One constant, so framings can be compared on a
  /// device. At least 1: below that the image would not cover the window's
  /// width.
  static const zoom = 1.1;

  /// The Home window's height, unchanged from 1.0.
  static const windowHeight = 350.0;
  static const pawnAt = .72;

  /// The window's width, in points.
  final double width;

  const ClimbCamera(this.width) : assert(zoom >= 1);

  /// Points per image width ([ClimbRoute]'s unit).
  double get scale => width * zoom;

  /// The image's size on screen.
  Size get imageSize => Size(
      ClimbRoute.sceneSize.width * scale, ClimbRoute.sceneSize.height * scale);

  /// The image's point (in points, from its top left) at the window's top
  /// left, with the pawn at [pawn] (image widths).
  Offset offsetFor(Offset pawn) {
    final maxX = imageSize.width - width;
    final maxY = imageSize.height - windowHeight;
    return Offset((pawn.dx * scale - width / 2).clamp(0.0, maxX).toDouble(),
        (pawn.dy * scale - windowHeight * pawnAt).clamp(0.0, maxY).toDouble());
  }

  /// Where the image point [p] (image widths) is in the window, with the
  /// window at [offset].
  Offset toWindow(Offset p, Offset offset) => p * scale - offset;

  // The avatar's size (scene art G3): its ground shadow fits the trail.

  /// Batch 3b's tile, 42.3 pt (29 units × 2 at 350 / 480 pt per unit): the
  /// avatar is never larger than it was.
  static const maxAvatarTile = 58 * 350 / 480;

  /// The avatar's ground shadow, its footprint: 1.3 × the radius, so 0.65
  /// of the tile (`AvatarTile`).
  static const footprintShare = .65;

  /// Where along the trail (a share of its length) the avatar starts to
  /// shrink toward the summit, and the share of its size it ends at there.
  /// Chosen from the trail's narrowing (Stage 1, `build-log.md`): below
  /// 85 % the trail is at least 121 px of 2172 wide; above it, it narrows
  /// to 101 px in the last bends and 63 px at the tip. 85 % is the latest
  /// start for which a linear shrink to 0.6 keeps the footprint inside the
  /// trail up to 99 % of its length; only the tip is narrower than the
  /// floor. In a 31-day month the shrink spans the last 4.7 days, in a
  /// 28-day month the last 4.2.
  static const shrinkFrom = .85;
  static const shrinkFloor = .6;

  /// The tile on the trail's body: the largest whose footprint fits the
  /// trail's narrowest width before [shrinkFrom], never above
  /// [maxAvatarTile].
  double get baseAvatarTile => math.min(maxAvatarTile,
      ClimbRoute.narrowestChord(shrinkFrom) * scale / footprintShare);

  /// The tile [s] image widths along the trail: [baseAvatarTile], shrinking
  /// linearly from [shrinkFrom] of the trail to [shrinkFloor] at the summit.
  double avatarTileAt(double s) {
    final share = (s / ClimbRoute.length).clamp(0.0, 1.0);
    if (share <= shrinkFrom) return baseAvatarTile;
    final t = (share - shrinkFrom) / (1 - shrinkFrom);
    return baseAvatarTile * (1 - t * (1 - shrinkFloor));
  }
}
