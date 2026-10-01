import 'dart:ui';

import 'climb_route.dart';

/// How the scene's image is placed in the Home window: the camera, a layer
/// of its own (design decision D3), so a change of framing never touches
/// the step table.
///
/// The image fits the window's width and the camera follows the pawn
/// vertically, the pawn at [pawnAt] of the window's height, clamped so the
/// window never shows past the image.
class ClimbCamera {
  /// The Home window's height, unchanged from 1.0.
  static const windowHeight = 350.0;
  static const pawnAt = .72;

  /// The window's width, in points.
  final double width;

  const ClimbCamera(this.width);

  /// Points per image width ([ClimbRoute]'s unit).
  double get scale => width;

  /// The image's size on screen.
  Size get imageSize => Size(
      ClimbRoute.sceneSize.width * scale, ClimbRoute.sceneSize.height * scale);

  /// The image's point (in points, from its top left) at the window's top
  /// left, with the pawn at [pawn] (image widths).
  Offset offsetFor(Offset pawn) {
    final maxY = imageSize.height - windowHeight;
    return Offset(0,
        (pawn.dy * scale - windowHeight * pawnAt).clamp(0.0, maxY).toDouble());
  }

  /// Where the image point [p] (image widths) is in the window, with the
  /// window at [offset].
  Offset toWindow(Offset p, Offset offset) => p * scale - offset;
}
