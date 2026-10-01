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
  /// G2: 1.3× for the daily view. One constant, so the owner can compare
  /// K-a (1.0, the image just fitted to the width) on a device. At least 1:
  /// below that the image would not cover the window's width.
  static const zoom = 1.3;

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
}
