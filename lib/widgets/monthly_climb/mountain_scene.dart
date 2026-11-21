import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app_colors.dart';
import '../../models/avatar.dart';
import '../../models/climb_theme.dart';
import '../../motion.dart';
import '../companion_view.dart';
import 'climb_route.dart';
import 'climb_summit_table.dart';
import 'climb_trail_table.dart';

/// Maps the scene's image units ([ClimbRoute]: image widths) to a box the
/// image covers (`BoxFit.cover`, aligned by [alignment]).
class SceneMap {
  final Size box;
  final Alignment alignment;

  /// Extra zoom on top of cover (V12's camera); 1 = cover.
  final double zoom;

  /// The scene point at the box's centre when [zoom] > 1 (image widths),
  /// or null for the cover's own framing.
  final Offset? focus;

  SceneMap(this.box,
      {this.alignment = Alignment.center, this.zoom = 1, this.focus});

  /// The image's displayed width (points per image width).
  double get scale {
    final cover = math.max(box.width, box.height * climbImageAspect);
    return cover * zoom;
  }

  Size get imageSize => Size(scale, scale / climbImageAspect);

  /// The image's top left in the box.
  Offset get origin {
    final img = imageSize;
    if (focus != null && zoom > 1) {
      final f = focus!;
      final x = (box.width / 2 - f.dx * scale)
          .clamp(box.width - img.width, 0.0)
          .toDouble();
      final y = (box.height / 2 - f.dy * scale)
          .clamp(box.height - img.height, 0.0)
          .toDouble();
      return Offset(x, y);
    }
    final dx = (box.width - img.width) * (alignment.x + 1) / 2;
    final dy = (box.height - img.height) * (alignment.y + 1) / 2;
    return Offset(dx, dy);
  }

  /// A scene point (image widths) in the box.
  Offset toBox(Offset p) => origin + p * scale;
}

/// A month's whole mountain (V06, V12, R04, R04b, V24): the theme's
/// illustration covering the box (no empty band at any edge), the summit
/// flag (v2 pole and pennant) on the art's apex, and the avatar standing
/// on the trail at [avatarDay] (fractional while walking). [overlay] draws
/// more on top with the same mapping (the camp, labels).
///
/// The pennant waves from its left edge (1.6 s, ±6°) as an ambient loop.
class MountainScene extends StatefulWidget {
  final ClimbTheme theme;
  final int days;
  final Avatar? avatar;
  final double avatarDay;
  final double avatarSize;

  /// The avatar's mood (idle on the mountain; sleep at the camp).
  final CompanionMood avatarMood;

  /// The avatar's lift above the trail (hops), in points.
  final double avatarLift;

  /// The flag's pop (0 → 1); 1 = standing.
  final double flagPop;
  final bool showFlag;
  final Alignment alignment;
  final double zoom;
  final Offset? focus;

  /// The painted share of the trail up to the avatar (V12: 0 → 1 as it
  /// walks); null draws no trail.
  final double? trailPaint;
  final Color? trailColor;
  final Widget Function(BuildContext context, SceneMap map)? overlay;

  const MountainScene({
    super.key,
    required this.theme,
    required this.days,
    this.avatar,
    this.avatarDay = 0,
    this.avatarSize = 56,
    this.avatarMood = CompanionMood.idle,
    this.avatarLift = 0,
    this.flagPop = 1,
    this.showFlag = true,
    this.alignment = Alignment.center,
    this.zoom = 1,
    this.focus,
    this.trailPaint,
    this.trailColor,
    this.overlay,
  });

  /// The summit flag's foot on [theme]'s art in [brightness]: the image's
  /// own apex (fix round 3, B6), [poleSink] into the rock or snow so the
  /// pole stands in it rather than on its outline. Fix round 2 stood it on
  /// the trail's last point, which is under the peak (some 0.02 image
  /// widths left of it and 0.07 below): the owner's device showed the pole
  /// where the trail ends. Art without a measured apex falls back to the
  /// trail's last point.
  static Offset flagPointFor(ClimbTheme theme, Brightness brightness) {
    final apex = apexFor(theme, brightness);
    return apex == null ? ClimbRoute.summit : apex + const Offset(0, poleSink);
  }

  /// The highest point of [theme]'s art in [brightness], in image widths
  /// ([ClimbRoute]'s units), or null when the art was not measured
  /// (`climb_summit_table.dart`, `tool/scene_art/summit_apex.py`).
  static Offset? apexFor(ClimbTheme theme, Brightness brightness) {
    final a = climbSummitApex[theme.backgroundFor(brightness)];
    return a == null ? null : Offset(a.$1, a.$2 / climbImageAspect);
  }

  /// How far the pole's foot stands below the measured apex (the first
  /// non-sky pixel), in image widths: 6 px of the 1536 px art, about 1.6 pt
  /// on V06.
  static const double poleSink = 6 / 1536;

  /// The summit flag (tests read where it stands).
  static const flagKey = ValueKey('mountain_scene_flag');

  /// The pole image's opaque foot, as a share of its height
  /// (`summit_flag_pole_v2.webp`: rows 25–997 of 1024 are opaque).
  static const double poleFoot = 997 / 1024;

  @override
  State<MountainScene> createState() => _MountainSceneState();
}

class _MountainSceneState extends State<MountainScene>
    with SingleTickerProviderStateMixin {
  AnimationController? _wave;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final on = AppMotion.loopsOn(context) && widget.showFlag;
    if (on && _wave == null) {
      _wave = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 1600))
        ..repeat();
    } else if (!on && _wave != null) {
      _wave!.dispose();
      _wave = null;
    }
  }

  @override
  void dispose() {
    _wave?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LayoutBuilder(builder: (context, box) {
      final map = SceneMap(box.biggest,
          alignment: widget.alignment, zoom: widget.zoom, focus: widget.focus);
      final img = map.imageSize;
      final origin = map.origin;
      final route = ClimbRoute(widget.days.clamp(28, 31));
      final avatarAt = map.toBox(route.pointAt(widget.avatarDay));
      final flag =
          map.toBox(MountainScene.flagPointFor(widget.theme, brightness));
      // The flag's size follows the image's scale (about a fifteenth of
      // its width on V06).
      final poleH = img.width * .14;
      final poleW = poleH / 4;
      final pennantW = poleH * .72;
      final children = <Widget>[
        Positioned(
          left: origin.dx,
          top: origin.dy,
          width: img.width,
          height: img.height,
          child: Image.asset(
            widget.theme.backgroundFor(brightness),
            fit: BoxFit.fill,
            excludeFromSemantics: true,
            gaplessPlayback: true,
          ),
        ),
      ];
      if (widget.trailPaint != null && widget.trailPaint! > 0) {
        children.add(Positioned.fill(
          child: CustomPaint(
            painter: _TrailPainter(
              map: map,
              route: route,
              upTo: widget.avatarDay,
              share: widget.trailPaint!,
              color: widget.trailColor ?? AppColors.of(context).gold,
            ),
          ),
        ));
      }
      if (widget.showFlag && widget.flagPop > 0) {
        final pop = AppMotion.pop.transform(widget.flagPop.clamp(0.0, 1.0));
        children.add(Positioned(
          key: MountainScene.flagKey,
          left: flag.dx - poleW / 2,
          // The pole's opaque foot on the art's apex.
          top: flag.dy - poleH * MountainScene.poleFoot,
          width: poleW + pennantW,
          height: poleH,
          child: Transform.scale(
            scale: pop,
            // Grows from the pole's foot.
            alignment: Alignment(-1 + poleW / (poleW + pennantW),
                MountainScene.poleFoot * 2 - 1),
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                top: 0,
                width: poleW,
                height: poleH,
                child: Image.asset('assets/ui/summit_flag_pole_v2.webp',
                    fit: BoxFit.contain, excludeFromSemantics: true),
              ),
              Positioned(
                left: poleW * .55,
                top: poleH * .03,
                width: pennantW,
                height: pennantW * 2 / 3,
                child: _Pennant(wave: _wave),
              ),
            ]),
          ),
        ));
      }
      if (widget.avatar != null) {
        final s = widget.avatarSize;
        children.add(Positioned(
          left: avatarAt.dx - s / 2,
          top: avatarAt.dy - s * .9 - widget.avatarLift,
          width: s,
          height: s,
          child: CompanionView(
              hero: widget.avatar!, mood: widget.avatarMood, size: s),
        ));
        children.insert(
          children.length - 1,
          Positioned(
            left: avatarAt.dx - s * .32,
            top: avatarAt.dy - s * .08,
            width: s * .64,
            height: s * .16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(
                    alpha: .22 * (1 - (widget.avatarLift / 40).clamp(0.0, .6))),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        );
      }
      if (widget.overlay != null) {
        children.add(Positioned.fill(child: widget.overlay!(context, map)));
      }
      return ClipRect(
        child: Stack(clipBehavior: Clip.hardEdge, children: children),
      );
    });
  }
}

/// The pennant, waving from its left edge (skewY + scaleX, 1.6 s).
class _Pennant extends StatelessWidget {
  final Animation<double>? wave;
  const _Pennant({required this.wave});

  @override
  Widget build(BuildContext context) {
    const image = Image(
      image: AssetImage('assets/ui/summit_flag_pennant_v2.webp'),
      fit: BoxFit.contain,
      alignment: Alignment.centerLeft,
      excludeFromSemantics: true,
    );
    final w = wave;
    if (w == null) return image;
    return AnimatedBuilder(
      animation: w,
      builder: (context, child) {
        final t = (1 - math.cos(2 * math.pi * w.value)) / 2;
        return Transform(
          alignment: Alignment.centerLeft,
          transform: Matrix4.identity()
            ..setEntry(1, 0, math.tan(-6 * math.pi / 180 * t))
            ..scaleByDouble(1 - .07 * t, 1, 1, 1),
          child: child,
        );
      },
      child: image,
    );
  }
}

/// The trail painted from the foot to the avatar ([share] of the way).
class _TrailPainter extends CustomPainter {
  final SceneMap map;
  final ClimbRoute route;
  final double upTo;
  final double share;
  final Color color;

  _TrailPainter({
    required this.map,
    required this.route,
    required this.upTo,
    required this.share,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final end = route.arcAt(upTo) * share.clamp(0.0, 1.0);
    if (end <= 0) return;
    final path = Path();
    const steps = 80;
    for (var i = 0; i <= steps; i++) {
      final p = map.toBox(ClimbRoute.at(end * i / steps));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: .85)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = map.scale * .012);
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.share != share || old.upTo != upTo || old.map.box != map.box;
}
