import 'dart:ui';

import 'climb_route.dart';

/// How mountain space is placed in the Home window: the camera, a layer of
/// its own (design decision D3), so a change of framing never touches the
/// step table.
///
/// Framing F1 (decision D5, Batch 3b report R2): the window shows
/// [unitsTall] scene units of height **at every width**, centered on the
/// mountain, with the pawn at [pawnAt] of the window's height. 1.0 scaled the
/// scene to the card's width instead, so wider phones saw less mountain and
/// the first days of a month showed no edge or summit at all. Accepted cost:
/// on a 320 pt phone the avatar is 42 pt instead of 52, a day's step 17 pt
/// instead of 21.
class ClimbCamera {
  /// The Home window's height, unchanged from 1.0.
  static const windowHeight = 350.0;
  static const unitsTall = 480.0;
  static const pawnAt = .72;

  const ClimbCamera();

  /// Points per scene unit, the same at every width.
  double get scale => windowHeight / unitsTall;

  /// The scene's height on screen: the scroll extent the pawn is followed in.
  double get sceneHeight => ClimbRoute.sceneSize.height * scale;

  /// Where the scene's left edge sits in a window [width] wide, so the scene
  /// is centered; wider windows show sky beside the mountain.
  double sceneLeft(double width) =>
      (width - ClimbRoute.sceneSize.width * scale) / 2;

  /// Screen position, within the scrolled scene, of the scene point [p].
  Offset toScreen(Offset p, double width) =>
      Offset(sceneLeft(width) + p.dx * scale, p.dy * scale);

  /// Scroll offset that keeps [pawn] at [pawnAt] of a [viewport]-tall window,
  /// clamped to the scene.
  double scrollFor(Offset pawn, double viewport, double maxExtent) =>
      (pawn.dy * scale - viewport * pawnAt).clamp(0.0, maxExtent).toDouble();
}
