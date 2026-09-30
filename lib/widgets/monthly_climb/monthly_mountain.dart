import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../models/avatar.dart';
import '../../models/climb_theme.dart';
import '../avatar_tile.dart';
import 'climb_camera.dart';
import 'climb_route.dart';
import 'climb_scene.dart';

/// Presentation only: no storage, scoring, services or test completion writes.
class MonthlyMountain extends StatefulWidget {
  /// How high the pawn hops between two steps, in scene units (design
  /// decision D8): one arc per step; none with Reduce Motion.
  static const hopHeight = 14.0;

  final int days;
  final int completedDays;
  final Avatar avatar;

  /// Home lets vertical drags reach the page; the standalone preview can
  /// still explore the full trail. Programmatic pawn tracking works in both.
  final bool allowUserScroll;

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
      this.allowUserScroll = true,
      this.onMotionEnd});

  @override
  State<MonthlyMountain> createState() => _MonthlyMountainState();
}

class _MonthlyMountainState extends State<MonthlyMountain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  final _scroll = ScrollController();
  late ClimbRoute _route;
  static const _camera = ClimbCamera();
  double _from = 0, _to = 0;
  double? _width;
  bool _reduceMotion = false;
  double get _day =>
      _from + (_to - _from) * Curves.easeInOut.transform(_motion.value);

  /// The hop's height now: an arc between each two whole days, zero on a
  /// step. Measured from whole days, not from where the move started, so a
  /// move that interrupts another continues the arc and still lands. Reduce
  /// Motion never animates, so it is always zero there.
  double get _hopLift {
    final day = _day;
    return MonthlyMountain.hopHeight * math.sin(math.pi * (day - day.floor()));
  }

  @override
  void initState() {
    super.initState();
    _route = ClimbRoute(widget.days);
    _from = _to = widget.completedDays.clamp(0, widget.days).toDouble();
    _motion = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850), value: 1)
      ..addListener(_follow);
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
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
    }
  }

  void _motionEnded() {
    if (mounted) widget.onMotionEnd?.call();
  }

  void _follow() {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_camera.scrollFor(_route.pointAt(_day),
        _scroll.position.viewportDimension, _scroll.position.maxScrollExtent));
  }

  @override
  void dispose() {
    _motion.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette =
        ClimbThemes.greenSlope.paletteFor(Theme.of(context).brightness);
    return Semantics(
      label: 'Green Slope. ${widget.completedDays} of ${widget.days} steps. '
          '${widget.avatar.semanticLabel} avatar. Milestones: '
          '${_route.markers.map((m) => 'day ${m.day} ${ClimbRoute.markerNames[ClimbRoute.markerDays.indexOf(m.day)]}').join(', ')}. '
          'Summit at ${widget.days} steps.',
      child: LayoutBuilder(builder: (context, constraints) {
        final width = constraints.maxWidth;
        final scale = _camera.scale;
        if (_width != width || !_scroll.hasClients) {
          _width = width;
          WidgetsBinding.instance.addPostFrameCallback((_) => _follow());
        }
        return SizedBox(
            height: ClimbCamera.windowHeight,
            child: ColoredBox(
              color: palette.sky,
              child: Scrollbar(
                  notificationPredicate: (_) => widget.allowUserScroll,
                  interactive: widget.allowUserScroll,
                  controller: _scroll,
                  child: SingleChildScrollView(
                    physics: widget.allowUserScroll
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    controller: _scroll,
                    child: SizedBox(
                      width: width,
                      height: _camera.sceneHeight,
                      child: ExcludeSemantics(
                          child: AnimatedBuilder(
                        animation: _motion,
                        builder: (context, _) {
                          final point =
                              _camera.toScreen(_route.pointAt(_day), width);
                          return Stack(children: [
                            // Mountain space, placed by the camera; it paints
                            // past its box, so wide windows show the flanks.
                            Positioned(
                                left: _camera.sceneLeft(width),
                                top: 0,
                                width: ClimbRoute.sceneSize.width * scale,
                                height: _camera.sceneHeight,
                                child: CustomPaint(
                                    painter: _MountainPainter(
                                        route: _route,
                                        palette: palette,
                                        progress: _day))),
                            Positioned(
                                left: point.dx - 29 * scale,
                                // The camera follows the trail point, not the
                                // hop, so the view does not bob.
                                top: point.dy - (55 + _hopLift) * scale,
                                child: AvatarTile(
                                    avatar: widget.avatar, radius: 29 * scale)),
                          ]);
                        },
                      )),
                    ),
                  )),
            ));
      }),
    );
  }
}

class _MountainPainter extends CustomPainter {
  final ClimbRoute route;
  final ClimbPalette palette;
  final double progress;
  _MountainPainter(
      {required this.route, required this.palette, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 320);
    void shape(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(path, Paint()..color = color);
    }

    // The mountain's layers, back to front, in flat colors (Batch 3c e).
    final tones = ClimbSceneTones.of(palette);
    shape(ClimbScene.farRidge, tones.farRidge);
    shape(ClimbScene.midRidge, tones.midRidge);
    shape(ClimbScene.body, tones.litFace);
    shape(ClimbScene.shadowFace, tones.shadowFace);
    shape(ClimbScene.cap, tones.cap);
    for (final hill in ClimbScene.foothills) {
      canvas.drawOval(hill, Paint()..color = tones.foothill);
    }
    // Environment items, behind the trail (Batch 3c f).
    for (final item in ClimbScene.environment) {
      canvas.save();
      canvas.translate(item.base.dx, item.base.dy);
      if (item.kind == 'pine') {
        _pine(canvas, tones);
      } else {
        _shrub(canvas, tones);
      }
      canvas.restore();
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        route.path,
        stroke
          ..color = palette.ridge
          ..strokeWidth = 26);
    canvas.drawPath(
        route.path,
        stroke
          ..color = palette.trail
          ..strokeWidth = 21);
    // Pills turned with the trail (Batch 3c d).
    for (var day = 0; day <= route.days; day++) {
      final point = route.stepAt(day);
      canvas.save();
      canvas.translate(point.dx, point.dy);
      canvas.rotate(route.stepAngle(day));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: ClimbRoute.stepMarkerSize.width,
                  height: ClimbRoute.stepMarkerSize.height),
              Radius.circular(ClimbRoute.stepMarkerSize.height / 2)),
          Paint()..color = day <= progress ? palette.accent : palette.stone);
      canvas.restore();
    }
    // Only the markers the table lists: D2 leaves out a marker within the
    // month's last 2 steps.
    for (final marker in route.markers) {
      canvas.save();
      canvas.translate(marker.origin.dx, marker.origin.dy);
      _landmark(canvas, ClimbRoute.markerDays.indexOf(marker.day));
      canvas.restore();
    }
    // The flag stands on the trail's end: the last day is the summit.
    final summit = ClimbRoute.summit;
    canvas.drawLine(
        summit + const Offset(0, 1),
        summit + const Offset(0, -36),
        stroke
          ..color = palette.ink
          ..strokeWidth = 2.5);
    shape([
      summit + const Offset(1, -35),
      summit + const Offset(26, -34),
      summit + const Offset(19, -26),
      summit + const Offset(26, -20),
      summit + const Offset(1, -21)
    ], palette.accent);
    canvas.restore();
  }

  /// A pine: a trunk and three stacked tiers, 32 × 58 units above its base.
  void _pine(Canvas canvas, ClimbSceneTones tones) {
    canvas.drawRect(
        const Rect.fromLTRB(-3, -12, 3, 0), Paint()..color = tones.trunk);
    final paint = Paint()..color = tones.pine;
    for (final (top, halfWidth, height) in const [
      (-58.0, 12.0, 22.0),
      (-46.0, 16.0, 24.0),
      (-32.0, 16.0, 22.0),
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(0, top)
            ..lineTo(halfWidth, top + height)
            ..lineTo(-halfWidth, top + height)
            ..close(),
          paint);
    }
  }

  /// A shrub with a few wildflowers, 44 × 22 units above its base.
  void _shrub(Canvas canvas, ClimbSceneTones tones) {
    final paint = Paint()..color = tones.shrub;
    canvas.drawOval(const Rect.fromLTRB(-22, -16, 2, 0), paint);
    canvas.drawOval(const Rect.fromLTRB(-8, -22, 16, 0), paint);
    canvas.drawOval(const Rect.fromLTRB(6, -14, 22, 0), paint);
    for (final o in const [Offset(-14, -12), Offset(2, -17), Offset(13, -8)]) {
      canvas.drawCircle(o, 3, Paint()..color = tones.flower);
      canvas.drawCircle(o, 1.1, Paint()..color = tones.flowerCenter);
    }
  }

  void _landmark(Canvas canvas, int index) {
    final fill = Paint()..color = palette.stone;
    final line = Paint()
      ..color = palette.ridge
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawOval(const Rect.fromLTRB(-28, 7, 28, 20),
        Paint()..color = palette.ridge.withValues(alpha: .3));
    switch (index) {
      case 0:
        canvas.drawLine(const Offset(-13, 12), const Offset(12, 2), line);
        canvas.drawLine(const Offset(-12, 2), const Offset(13, 12), line);
        canvas.drawPath(
            Path()
              ..moveTo(1, -25)
              ..cubicTo(20, -8, 12, 14, -7, 7)
              ..cubicTo(-20, -1, -9, -13, -7, -13)
              ..quadraticBezierTo(-4, -5, 1, -25),
            fill..color = palette.accent);
      case 1:
        canvas.drawPath(
            Path()
              ..moveTo(-25, 12)
              ..lineTo(-6, -23)
              ..lineTo(30, 12)
              ..close(),
            fill..color = palette.accent);
        canvas.drawPath(
            Path()
              ..moveTo(-16, 12)
              ..lineTo(-6, -8)
              ..lineTo(3, 12)
              ..close(),
            fill..color = palette.ridge);
      case 2:
        canvas.drawRect(const Rect.fromLTRB(-21, -8, 22, 18), fill);
        canvas.drawPath(
            Path()
              ..moveTo(-28, -7)
              ..lineTo(0, -30)
              ..lineTo(30, -7)
              ..close(),
            Paint()..color = palette.ridge);
        canvas.drawRect(
            const Rect.fromLTRB(-5, 1, 5, 18), Paint()..color = palette.ridge);
        canvas.drawRect(const Rect.fromLTRB(-16, 0, -9, 8),
            Paint()..color = palette.accent);
        canvas.drawRect(
            const Rect.fromLTRB(11, 0, 18, 8), Paint()..color = palette.accent);
      case 3:
        canvas.drawRect(const Rect.fromLTRB(-27, 4, 28, 12), fill);
        for (final x in [-24.0, 0.0, 24.0]) {
          canvas.drawLine(Offset(x, 4), Offset(x, -12), line);
        }
        canvas.drawLine(const Offset(-24, -10), const Offset(24, -10), line);
        canvas.drawLine(const Offset(0, 3), const Offset(7, -16), line);
        canvas.drawLine(
            const Offset(7, -16),
            const Offset(20, -22),
            line
              ..color = palette.ink
              ..strokeWidth = 6);
    }
  }

  @override
  bool shouldRepaint(_MountainPainter oldDelegate) =>
      oldDelegate.route != route ||
      oldDelegate.progress != progress ||
      oldDelegate.palette != palette;
}
