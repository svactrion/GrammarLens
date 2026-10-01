import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../models/avatar.dart';
import '../../models/climb_theme.dart';
import '../avatar_tile.dart';
import 'climb_camera.dart';
import 'climb_route.dart';

/// The Monthly Climb scene (1.1.0 design, scene art S1–S2): the theme's
/// illustration, with the trail painted in, and the avatar on its step.
///
/// Presentation only: no storage, scoring, services or test completion writes.
class MonthlyMountain extends StatefulWidget {
  /// How high the pawn hops between two steps, as a share of its tile
  /// (design decision D8): one arc per step; none with Reduce Motion. 1.0
  /// to 1.1.0's coded mountain hopped 14 scene units with a 58-unit tile;
  /// keeping the ratio keeps the hop's feel whatever the avatar's size
  /// (scene art G3: it shrinks toward the summit).
  static const hopShare = 14 / 58;

  /// Scene art G5: faint dots on the days already walked, like a trail
  /// left behind; future days are not marked. **The one switch:** false
  /// shows only the image's trail, the fallback if the dots are not liked
  /// on a device.
  static const passedDayDots = true;

  final int days;
  final int completedDays;
  final Avatar avatar;

  /// Whether to draw [ClimbTrailDots]; defaults to [passedDayDots].
  final bool showPassedDayDots;

  /// Called when the pawn has finished moving to a new position: at the end of
  /// the animation, or right after the frame when there is none (reduced
  /// motion, a changed month length). Not called for the position the mountain
  /// mounts at, and not for a move that another move interrupts.
  final VoidCallback? onMotionEnd;
  const MonthlyMountain(
      {super.key,
      required this.days,
      required this.completedDays,
      required this.avatar,
      this.showPassedDayDots = passedDayDots,
      this.onMotionEnd});

  @override
  State<MonthlyMountain> createState() => _MonthlyMountainState();
}

class _MonthlyMountainState extends State<MonthlyMountain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late ClimbRoute _route;
  double _from = 0, _to = 0;
  bool _reduceMotion = false;
  double get _day =>
      _from + (_to - _from) * Curves.easeInOut.transform(_motion.value);

  /// The hop's height now, for a [tile]-point avatar: an arc between each
  /// two whole days, zero on a step. Measured from whole days, not from
  /// where the move started, so a move that interrupts another continues
  /// the arc and still lands. Reduce Motion never animates, so it is always
  /// zero there.
  double _hopLift(double tile) {
    final day = _day;
    return MonthlyMountain.hopShare *
        tile *
        math.sin(math.pi * (day - day.floor()));
  }

  @override
  void initState() {
    super.initState();
    _route = ClimbRoute(widget.days);
    _from = _to = widget.completedDays.clamp(0, widget.days).toDouble();
    _motion = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850), value: 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion && _motion.isAnimating) {
      // Cutting the animation short cancels its future, so report the end here.
      _motion.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => _motionEnded());
    }
  }

  @override
  void didUpdateWidget(MonthlyMountain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days ||
        oldWidget.completedDays != widget.completedDays) {
      _from = _day;
      _to = widget.completedDays.clamp(0, widget.days).toDouble();
      _route = ClimbRoute(widget.days);
      if (_reduceMotion || oldWidget.days != widget.days) {
        _from = _to;
        _motion.value = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) => _motionEnded());
      } else {
        // Completes only if this animation runs to its end: a newer one that
        // restarts the controller cancels it, and so does dispose.
        _motion.forward(from: 0).then((_) => _motionEnded());
      }
    }
  }

  void _motionEnded() {
    if (mounted) widget.onMotionEnd?.call();
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // Every month shows Green Slope's image, light or dark with the app's
    // mode, until the other themes have images (scene art, Stage 1): none
    // of them is ready, so the rotation shows and records Green Slope for
    // every month too (`ClimbThemeRotation.shownFor`).
    const theme = ClimbThemes.greenSlope;
    final palette = theme.paletteFor(brightness);
    return Semantics(
      label: '${theme.name}. ${widget.completedDays} of ${widget.days} steps. '
          '${widget.avatar.semanticLabel} avatar. '
          'Summit at ${widget.days} steps.',
      child: LayoutBuilder(builder: (context, constraints) {
        final camera = ClimbCamera(constraints.maxWidth);
        final image = camera.imageSize;
        return SizedBox(
            height: ClimbCamera.windowHeight,
            child: ClipRect(
              child: ColoredBox(
                // Shown only until the image has decoded.
                color: palette.sky,
                child: ExcludeSemantics(
                    child: AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) {
                    final pawn = _route.pointAt(_day) * camera.scale;
                    // The camera follows the trail point, not the hop, so
                    // the view does not bob.
                    final offset = camera.offsetFor(_route.pointAt(_day));
                    final tile = camera.avatarTileAt(_route.arcAt(_day));
                    // One layer, the image and the avatar in the image's
                    // own points, moved by the camera.
                    return Stack(clipBehavior: Clip.none, children: [
                      Positioned(
                        left: -offset.dx,
                        top: -offset.dy,
                        width: image.width,
                        height: image.height,
                        child: Stack(clipBehavior: Clip.none, children: [
                          Positioned.fill(
                              child: Image.asset(
                                  theme.backgroundFor(brightness),
                                  fit: BoxFit.fill,
                                  filterQuality: FilterQuality.medium,
                                  gaplessPlayback: true)),
                          if (widget.showPassedDayDots)
                            Positioned.fill(
                                child: CustomPaint(
                                    painter: ClimbTrailDots(points: [
                              // Days the pawn has left behind: on day n,
                              // 1 to n − 1 (day n is under the avatar,
                              // day 0 is the START mat).
                              for (var d = 1; d < _day; d++)
                                _route.stepAt(d) * camera.scale
                            ], color: palette.ink))),
                          Positioned(
                              left: pawn.dx - tile / 2,
                              // The feet on the step: the tile's top is
                              // 55/58 of its side above it (AvatarTile's
                              // art).
                              top: pawn.dy - tile * 55 / 58 - _hopLift(tile),
                              child: AvatarTile(
                                  avatar: widget.avatar, radius: tile / 2)),
                        ]),
                      ),
                    ]);
                  },
                )),
              ),
            ));
      }),
    );
  }
}

/// Scene art G5: a faint dot on each passed day's step, in the image's
/// points. Small and see-through, so the painted trail stays the trail.
class ClimbTrailDots extends CustomPainter {
  /// A dot's diameter, in points.
  static const diameter = 4.0;

  /// The dots' opacity: faint on the trail in both modes.
  static const opacity = .22;

  final List<Offset> points;

  /// The theme palette's `ink`: dark on the light trail, light on the dusk
  /// one.
  final Color color;

  const ClimbTrailDots({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    for (final p in points) {
      canvas.drawCircle(p, diameter / 2, paint);
    }
  }

  @override
  bool shouldRepaint(ClimbTrailDots oldDelegate) =>
      oldDelegate.color != color || !listEquals(oldDelegate.points, points);
}
