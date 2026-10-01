import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../models/avatar.dart';
import '../../models/climb_theme.dart';
import '../avatar_tile.dart';
import 'climb_camera.dart';
import 'climb_debug_day.dart';
import 'climb_route.dart';
import 'climb_save_point_table.dart';
import 'climb_save_points.dart';

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

  /// G8: how long a reached save point takes to light, after the hop.
  static const savePointFade = Duration(milliseconds: 400);

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
    with TickerProviderStateMixin {
  late final AnimationController _motion;

  /// G8: a save point the avatar has just reached fades in when the hop
  /// ends.
  late final AnimationController _fade;

  /// Save points shown as reached, and those fading in now (by clearing).
  final _lit = <String>{};
  final _fading = <String>{};
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

  /// The step the scene shows: the real progress, or, in debug builds
  /// only, `CLIMB_DEBUG_DAY` ([ClimbDebugDay]). Display only.
  int get _shownSteps =>
      (ClimbDebugDay.value ?? widget.completedDays).clamp(0, widget.days);

  @override
  void initState() {
    super.initState();
    _route = ClimbRoute(widget.days);
    _from = _to = _shownSteps.toDouble();
    _motion = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850), value: 1);
    _fade = AnimationController(
        vsync: this, duration: MonthlyMountain.savePointFade);
    _lit.addAll(_reached());
  }

  /// The save points reached at the step the pawn is going to (G8).
  Set<String> _reached() => {
        for (final p in ClimbSavePoints.all)
          if (p.reachedAt(_route.arcAt(_to))) p.clearing
      };

  /// Brings the save points' states up to the pawn's step: a newly reached
  /// one fades in, unless Reduce Motion is on; a step back (or a new month)
  /// changes them at once.
  void _updateSavePoints() {
    final reached = _reached();
    final added = reached.difference(_lit).difference(_fading);
    final keep = reached.containsAll(_lit) && reached.containsAll(_fading);
    if (added.isEmpty && keep) return;
    if (!keep || _reduceMotion) {
      _fade.stop();
      setState(() {
        _fading.clear();
        _lit
          ..clear()
          ..addAll(reached);
      });
      return;
    }
    setState(() => _fading.addAll(added));
    _fade.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _lit.addAll(_fading);
        _fading.clear();
      });
    }, onError: (_) {});
  }

  /// 0 unreached, 1 reached, in between while fading in.
  double _litFor(ClimbSavePoint p) {
    if (_lit.contains(p.clearing)) return 1;
    if (_fading.contains(p.clearing)) {
      return Curves.easeOut.transform(_fade.value);
    }
    return 0;
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
      _to = _shownSteps.toDouble();
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
    if (!mounted) return;
    _updateSavePoints();
    widget.onMotionEnd?.call();
  }

  @override
  void dispose() {
    _motion.dispose();
    _fade.dispose();
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
    // G6: in dark mode the objects take the theme's relighting.
    final darkGain =
        brightness == Brightness.dark ? climbObjectDarkGain[theme.id] : null;
    final savePoints = [
      for (final p in ClimbSavePoints.all)
        '${p.object} at step ${p.reachedOn(widget.days)}'
    ].join(', ');
    return Semantics(
      label: '${theme.name}. $_shownSteps of ${widget.days} steps. '
          '${widget.avatar.semanticLabel} avatar. '
          'Save points: $savePoints. '
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
                  animation: Listenable.merge([_motion, _fade]),
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
                              // One dot per completed step left behind: with n
                              // steps done, on steps 0 to n − 1 (step n is
                              // under the avatar). Step 0 is the trail's
                              // foot by the START flag.
                              for (var d = 0; d < _day; d++)
                                _route.stepAt(d) * camera.scale
                            ], color: palette.ink))),
                          // The save points and the summit flag, between
                          // the dots and the avatar.
                          for (final p in ClimbSavePoints.all)
                            Positioned.fromRect(
                                rect: _scaled(p.rect, camera.scale),
                                child: _savePoint(p, _litFor(p), darkGain)),
                          if (theme.hasSummitFlag)
                            Positioned.fromRect(
                                rect: _scaled(
                                    ClimbSavePoints.summitFlag, camera.scale),
                                child: ClimbObjectLayer(
                                    key: const ValueKey('climb_summit_flag'),
                                    asset:
                                        ClimbSavePoints.assetFor('summit_flag'),
                                    matrix: ClimbSavePoints.matrix(
                                        lit: 1, darkGain: darkGain))),
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

  static Rect _scaled(Rect r, double scale) => Rect.fromLTRB(
      r.left * scale, r.top * scale, r.right * scale, r.bottom * scale);

  static Widget _asset(String path) => Image.asset(path,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true);

  /// G8 and G6: the object faded until reached; in dark mode relit by the
  /// theme's gain. The campfire's flame keeps its own colours once reached
  /// in dark mode: drawn unfiltered over the filtered fire, fading in with
  /// it (unreached, the flame is filtered and faded like the rest).
  Widget _savePoint(
      ClimbSavePoint p, double lit, (double, double, double)? darkGain) {
    final body = ClimbObjectLayer(
        key: ValueKey('climb_save_point_${p.clearing}'),
        asset: p.asset,
        matrix: ClimbSavePoints.matrix(lit: lit, darkGain: darkGain));
    if (p.object != 'campfire' || darkGain == null || lit == 0) return body;
    return Stack(fit: StackFit.expand, children: [
      body,
      Opacity(
          key: const ValueKey('climb_campfire_flame'),
          opacity: lit,
          child: _asset(ClimbSavePoints.flameAsset)),
    ]);
  }
}

/// One object image through a colour matrix (G6, G8): [matrix] is
/// `ClimbSavePoints.matrix`, kept so it can be read back.
class ClimbObjectLayer extends StatelessWidget {
  final String asset;
  final List<double> matrix;

  const ClimbObjectLayer(
      {super.key, required this.asset, required this.matrix});

  @override
  Widget build(BuildContext context) => ColorFiltered(
      colorFilter: ColorFilter.matrix(matrix),
      child: Image.asset(asset,
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true));
}

/// Scene art G5: a faint dot on each step the avatar has left behind, in
/// the image's points. Small and see-through, so the painted trail stays the trail.
class ClimbTrailDots extends CustomPainter {
  /// A dot's diameter, in points.
  static const diameter = 4.0;

  /// The dots' opacity: faint on the trail in both modes. Chosen on a
  /// device (scene art G5): 0.22 was too faint to see; 0.30 and 0.40 were
  /// tried, 0.40 kept (2.06:1 against the trail in light mode, 1.72:1 in
  /// dark).
  static const opacity = .40;

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
