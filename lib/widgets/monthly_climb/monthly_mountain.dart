import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import '../../models/avatar.dart';
import '../../models/climb_theme.dart';
import '../avatar_tile.dart';
import 'climb_camera.dart';
import 'climb_debug_controls.dart';
import 'climb_debug_day.dart';
import 'climb_debug_milestone.dart';
import 'climb_debug_theme.dart';
import 'climb_route.dart';
import 'climb_save_point_table.dart';
import 'climb_save_points.dart';
import 'climb_zoom.dart';

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

  /// N6, N19: the name label of a save point just reached: it fades in
  /// with the light-up at the hop's end, stays, and fades out. Under
  /// Reduce Motion it appears and goes without animation and stays
  /// [labelShownReduceMotion].
  static const labelFadeIn = Duration(milliseconds: 200);
  static const labelShown = Duration(milliseconds: 2500);
  static const labelFadeOut = Duration(milliseconds: 400);
  static const labelShownReduceMotion = Duration(seconds: 3);

  /// The label's gap above what it stands over, and its inset from the
  /// window's sides.
  static const labelGap = 4.0;
  static const labelInset = 6.0;

  /// The top of an avatar's art in its tile, as a share of the tile: the
  /// highest of the 16 (alpha > 40; Batch 5 Batch 0 §3). N19 puts the label
  /// above the object and the avatar together, so the arriving avatar's
  /// head stays in view.
  static const avatarArtTop = .045;

  static const labelKey = ValueKey('climb_save_point_label');

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

  /// The month's theme: its images, its dark-mode object filter and
  /// whether it draws the flag. Home passes the month's recorded theme
  /// (`StorageService.resolveClimbMonthTheme`).
  final ClimbTheme theme;

  /// Batch 6 (M6): a zoom's progress, 0 the K-c framing (the whole image)
  /// to 1 the daily one; null shows the daily framing as always. The scene
  /// is drawn once, in the daily framing, behind a repaint boundary, and
  /// only a transform above it follows the zoom: no relayout or repaint of
  /// the scene while it plays.
  final Animation<double>? zoom;

  /// With [zoom]: Reduce Motion's cross-fade, the K-c frame fading out
  /// over the daily one, instead of the zoom.
  final bool zoomCrossFade;

  /// The boxes the label must not touch, in the window's points, for a
  /// window of the given width (N19): the card's month and step chips
  /// (`ClimbCard.chipRects`). A label that would touch one moves down below
  /// it; the chips are never hidden. Null: none.
  final List<Rect> Function(double width)? labelAvoid;

  /// The debug panel's save point replay (N27): a new [id] mounts the scene
  /// one step before [point]'s step and hops onto it, as
  /// `CLIMB_DEBUG_MILESTONE` does at launch. Display only.
  final ({ClimbSavePoint point, int id})? debugHop;

  const MonthlyMountain(
      {super.key,
      required this.days,
      required this.completedDays,
      required this.avatar,
      this.theme = ClimbThemes.greenSlope,
      this.showPassedDayDots = passedDayDots,
      this.onMotionEnd,
      this.zoom,
      this.zoomCrossFade = false,
      this.labelAvoid,
      this.debugHop});

  /// The repaint boundary around the scene (tests count its paints).
  static const sceneKey = ValueKey('climb_scene_layer');

  /// The K-c blurred backdrop (M22), present only during a zoom.
  static const kcBackdropKey = ValueKey('climb_kc_backdrop');

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

  /// N6, N19: the save point whose name label shows now, and its run.
  late final AnimationController _label;
  ClimbSavePoint? _labelled;

  /// Under Reduce Motion the label is not animated at all: it shows, and
  /// this ends it.
  Timer? _labelTimer;
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
  /// The theme the scene draws: the month's, or, in debug builds only,
  /// `CLIMB_DEBUG_THEME` ([ClimbDebugTheme]). Display only.
  ClimbTheme get _theme => ClimbDebugTheme.value ?? widget.theme;

  int get _shownSteps =>
      (_debugMilestoneStep ?? ClimbDebugDay.value ?? widget.completedDays)
          .clamp(0, widget.days);

  /// `CLIMB_DEBUG_MILESTONE` on a save point (debug builds only): the step
  /// the scene shows, first the one before the save point's, then, once
  /// [_debugHop] has run, the save point's own. Display only.
  int? _debugMilestoneStep;
  Timer? _debugHopTimer;

  /// How long the debug hop waits after the scene is shown without a zoom,
  /// so Home has settled when it plays.
  static const _debugHopDelay = Duration(milliseconds: 600);

  @override
  void initState() {
    super.initState();
    _debugHopTarget =
        widget.debugHop?.point ?? ClimbDebugMilestone.value?.savePoint;
    if (_debugHopTarget case final target?) {
      _debugMilestoneStep = target.reachedOn(widget.days) - 1;
      _scheduleDebugHop();
    }
    if (ClimbDebugControls.available) {
      ClimbDebugControls.instance.settingsRevision
          .addListener(_onDebugSettingsChanged);
    }
    _route = ClimbRoute(widget.days);
    _from = _to = _shownSteps.toDouble();
    _motion = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 850), value: 1);
    _fade = AnimationController(
        vsync: this, duration: MonthlyMountain.savePointFade);
    _label = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _labelled = null);
        }
      });
    // The position the scene mounts at shows no label: only a step taken
    // while it is shown does (N6).
    _lit.addAll(_reached());
  }

  /// The theme's objects: the save points, and the flag where the theme
  /// has one (lit only on the month's last step).
  List<ClimbSavePoint> get _objects => [
        ...ClimbSavePoints.all,
        if (_theme.hasSummitFlag) ClimbSavePoints.flag,
      ];

  /// The objects reached at the step the pawn is going to (G8).
  Set<String> _reached() => {
        for (final p in _objects)
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
    // A step forward onto a save point: its name, with or without Reduce
    // Motion. A step back or a new month changes states without one.
    if (keep) _showLabel(added);
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

  /// `CLIMB_DEBUG_MILESTONE`: hops onto the save point once no zoom runs
  /// (the label is not shown during one), as a Daily Test's step would.
  void _scheduleDebugHop() {
    if (_debugHopTimer != null || widget.zoom != null) return;
    final milestone = _debugHopTarget;
    if (milestone == null) return;
    _debugHopTimer = Timer(_debugHopDelay, () {
      if (!mounted) return;
      setState(() => _debugMilestoneStep = milestone.reachedOn(widget.days));
      _from = _day;
      _to = _shownSteps.toDouble();
      if (_reduceMotion) {
        _from = _to;
        _motion.value = 1;
        WidgetsBinding.instance.addPostFrameCallback((_) => _motionEnded());
      } else {
        _motion.forward(from: 0).then((_) => _motionEnded());
      }
    });
  }

  /// The save point a debug hop goes to (the define's or the panel's).
  ClimbSavePoint? _debugHopTarget;

  /// Shows the scene's current step at once: no hop, no fade, no label.
  void _jumpToShownStep() {
    _motion.value = 1;
    _from = _to = _shownSteps.toDouble();
    _fade.stop();
    _label.stop();
    _labelTimer?.cancel();
    _labelled = null;
    _fading.clear();
    _lit
      ..clear()
      ..addAll(_reached());
  }

  /// The debug panel changed the day or the theme (N27): the latest
  /// setting wins over a debug hop, and the scene shows it at once.
  void _onDebugSettingsChanged() {
    if (!mounted) return;
    _debugHopTimer?.cancel();
    _debugHopTimer = null;
    setState(() {
      _debugMilestoneStep = null;
      _debugHopTarget = null;
      _jumpToShownStep();
    });
  }

  /// The panel's save point replay: one step before, then the hop.
  void _startDebugHop(ClimbSavePoint point) {
    _debugHopTimer?.cancel();
    _debugHopTimer = null;
    setState(() {
      _debugHopTarget = point;
      _debugMilestoneStep = point.reachedOn(widget.days) - 1;
      _jumpToShownStep();
    });
    _scheduleDebugHop();
  }

  /// N6, N19: the label of the furthest save point in [clearings], once.
  /// None during a zoom: the label stands in the daily framing.
  void _showLabel(Set<String> clearings) {
    if (widget.zoom != null) return;
    final reached = [
      for (final p in _objects)
        if (clearings.contains(p.clearing)) p
    ]..sort((a, b) => a.arc.compareTo(b.arc));
    if (reached.isEmpty) return;
    setState(() => _labelled = reached.last);
    _labelTimer?.cancel();
    if (_reduceMotion) {
      _label.stop();
      _labelTimer = Timer(MonthlyMountain.labelShownReduceMotion, () {
        if (mounted) setState(() => _labelled = null);
      });
      return;
    }
    _label.duration = MonthlyMountain.labelFadeIn +
        MonthlyMountain.labelShown +
        MonthlyMountain.labelFadeOut;
    _label.forward(from: 0);
  }

  /// The label's opacity now: in, shown, out; always 1 under Reduce Motion.
  double get _labelOpacity {
    if (_reduceMotion) return 1;
    final t = _label.value * _label.duration!.inMicroseconds;
    final fadeIn = MonthlyMountain.labelFadeIn.inMicroseconds;
    final fadeOut = MonthlyMountain.labelFadeOut.inMicroseconds;
    final total = _label.duration!.inMicroseconds;
    if (t < fadeIn) return t / fadeIn;
    if (t > total - fadeOut) return ((total - t) / fadeOut).clamp(0.0, 1.0);
    return 1;
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
    if (oldWidget.zoom != null && widget.zoom == null) _scheduleDebugHop();
    final hop = widget.debugHop;
    if (hop != null && hop.id != oldWidget.debugHop?.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startDebugHop(hop.point);
      });
    }
    if (oldWidget.theme != widget.theme) {
      // Another theme can draw another set of objects (the flag): states
      // follow at once, without a fade.
      _fade.stop();
      _fading.clear();
      _lit
        ..clear()
        ..addAll(_reached());
    }
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
    _label.dispose();
    _labelTimer?.cancel();
    _debugHopTimer?.cancel();
    if (ClimbDebugControls.available) {
      ClimbDebugControls.instance.settingsRevision
          .removeListener(_onDebugSettingsChanged);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    // The month's theme, light or dark image with the app's mode.
    final theme = _theme;
    final palette = theme.paletteFor(brightness);
    // G6: in dark mode the objects take the theme's relighting.
    final darkGain =
        brightness == Brightness.dark ? climbObjectDarkGain[theme.id] : null;
    final savePoints = [
      for (final p in ClimbSavePoints.all)
        '${p.name} at step ${p.reachedOn(widget.days)}'
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
                // Shown only until the images have decoded.
                color: palette.sky,
                child: ExcludeSemantics(
                    child: AnimatedBuilder(
                  animation: Listenable.merge([_motion, _fade, _label]),
                  builder: (context, _) {
                    final pawn = _route.pointAt(_day) * camera.scale;
                    // The camera follows the trail point, not the hop, so
                    // the view does not bob.
                    final offset = camera.offsetFor(_route.pointAt(_day));
                    final tile = camera.avatarTileAt(_route.arcAt(_day));
                    // One layer, the image and the avatar in the image's
                    // own points, moved by the camera.
                    Widget scene() => Stack(clipBehavior: Clip.none, children: [
                          Positioned(
                            left: -offset.dx,
                            top: -offset.dy,
                            width: image.width,
                            height: image.height,
                            child: RepaintBoundary(
                              key: MonthlyMountain.sceneKey,
                              child: Stack(clipBehavior: Clip.none, children: [
                                // M22: during a zoom, the blurred copy fills
                                // the K-c window behind the sharp image (a
                                // pre-made asset, part of this layer: no blur
                                // at run time). Outside the image's bounds,
                                // so the daily framing never shows it.
                                if (widget.zoom != null)
                                  Positioned.fromRect(
                                    key: MonthlyMountain.kcBackdropKey,
                                    rect: ClimbOverview.backdropRect(camera),
                                    child: Image(
                                        image: ClimbOverview.backdropImage(
                                            theme, brightness),
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.low,
                                        gaplessPlayback: true),
                                  ),
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
                                    // One dot per completed step left behind:
                                    // with n steps done, on steps 0 to n − 1
                                    // (step n is under the avatar). Step 0 is
                                    // the trail's foot by the START flag.
                                    for (var d = 0; d < _day; d++)
                                      _route.stepAt(d) * camera.scale
                                  ], color: palette.ink))),
                                // The C5 signpost (N11, N18): decoration,
                                // always lit, under the save points.
                                for (final p in ClimbSavePoints.decor)
                                  Positioned.fromRect(
                                      rect: _scaled(p.rect, camera.scale),
                                      child: ClimbObjectLayer(
                                          key: ValueKey(
                                              'climb_decor_${p.clearing}'),
                                          asset: p.asset,
                                          matrix: ClimbSavePoints.matrix(
                                              lit: 1, darkGain: darkGain))),
                                // The save points and the flag, between the
                                // dots and the avatar.
                                for (final p in _objects)
                                  Positioned.fromRect(
                                      rect: _scaled(p.rect, camera.scale),
                                      child:
                                          _savePoint(p, _litFor(p), darkGain)),
                                Positioned(
                                    left: pawn.dx - tile / 2,
                                    // The feet on the step: the tile's top is
                                    // 55/58 of its side above it (AvatarTile's
                                    // art).
                                    top: pawn.dy -
                                        tile * 55 / 58 -
                                        _hopLift(tile),
                                    child: AvatarTile(
                                        avatar: widget.avatar,
                                        radius: tile / 2)),
                              ]),
                            ),
                          ),
                        ]);
                    final zoom = widget.zoom;
                    final labelled = _labelled;
                    if (zoom == null && labelled != null) {
                      // N19: in the window's points, above the object and
                      // the avatar's art together, kept inside the window
                      // and below the chips' band.
                      final object =
                          _scaled(labelled.rect, camera.scale).shift(-offset);
                      final avatarTop = pawn.dy -
                          tile * 55 / 58 -
                          _hopLift(tile) +
                          MonthlyMountain.avatarArtTop * tile -
                          offset.dy;
                      return Stack(children: [
                        scene(),
                        Positioned.fill(
                          child: CustomSingleChildLayout(
                            delegate: ClimbLabelLayout(
                                object: object,
                                avatarTop: avatarTop,
                                avoid: widget.labelAvoid
                                        ?.call(constraints.maxWidth) ??
                                    const []),
                            child: Opacity(
                              opacity: _labelOpacity,
                              child: ClimbSavePointLabel(labelled.name,
                                  key: MonthlyMountain.labelKey),
                            ),
                          ),
                        ),
                      ]);
                    }
                    if (zoom == null) return scene();
                    Matrix4 at(double t) =>
                        ClimbOverview.transform(camera, offset, t);
                    if (widget.zoomCrossFade) {
                      // Reduce Motion (M6): no zoom; the K-c frame, its
                      // blurred backdrop included, fades out over the daily
                      // one.
                      return Stack(children: [
                        scene(),
                        FadeTransition(
                          opacity: ReverseAnimation(zoom),
                          child: ColoredBox(
                              color: palette.sky,
                              child:
                                  Transform(transform: at(0), child: scene())),
                        ),
                      ]);
                    }
                    // Only the transform follows the zoom; the scene below
                    // is the builder's child, built once.
                    return AnimatedBuilder(
                      animation: zoom,
                      child: scene(),
                      builder: (context, child) =>
                          Transform(transform: at(zoom.value), child: child),
                    );
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
    final matrix = ClimbSavePoints.matrix(lit: lit, darkGain: darkGain);
    // G10: a theme that recolours the flag's pennant draws the flag in two
    // parts, the flag without its pennant and the pennant recoloured, both
    // through the same state and dark-mode matrix.
    final pennant = p.object == 'summit_flag'
        ? ClimbSavePoints.pennantColorFor(_theme)
        : null;
    if (pennant != null) {
      return Stack(fit: StackFit.expand, children: [
        ClimbObjectLayer(
            key: ValueKey('climb_save_point_${p.clearing}'),
            asset: ClimbSavePoints.flagBaseAsset,
            matrix: matrix),
        ClimbObjectLayer(
            key: const ValueKey('climb_flag_pennant'),
            asset: ClimbSavePoints.pennantAsset,
            matrix: ClimbSavePoints.compose(
                matrix, ClimbSavePoints.pennantMatrix(pennant))),
      ]);
    }
    final body = ClimbObjectLayer(
        key: ValueKey('climb_save_point_${p.clearing}'),
        asset: p.asset,
        matrix: matrix);
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

/// Where a save point's label stands (N19), in the window's points: its
/// bottom [MonthlyMountain.labelGap] above the object and the avatar's
/// art together, centred on the object, moved sideways to stay
/// [MonthlyMountain.labelInset] inside the window; if it would then touch a
/// box in [avoid] (the chips), just below it.
class ClimbLabelLayout extends SingleChildLayoutDelegate {
  final Rect object;
  final double avatarTop;
  final List<Rect> avoid;

  const ClimbLabelLayout(
      {required this.object, required this.avatarTop, this.avoid = const []});

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    const inset = MonthlyMountain.labelInset, gap = MonthlyMountain.labelGap;
    final left = (object.center.dx - childSize.width / 2)
        .clamp(inset, math.max(inset, size.width - inset - childSize.width))
        .toDouble();
    var top = math.min(object.top, avatarTop) - gap - childSize.height;
    top = math.max(top, inset);
    for (final r in avoid) {
      if ((Offset(left, top) & childSize).overlaps(r)) {
        top = math.max(top, r.bottom + gap);
      }
    }
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(ClimbLabelLayout old) =>
      old.object != object ||
      old.avatarTop != avatarTop ||
      !listEquals(old.avoid, avoid);
}

/// A save point's name (N6, N19): an opaque chip in the month and step
/// chips' style (K4), so it reads over any part of the scene.
class ClimbSavePointLabel extends StatelessWidget {
  final String name;
  const ClimbSavePointLabel(this.name, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ClimbThemes.greenSlope.paletteFor(theme.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
          color: palette.sky, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(name,
            maxLines: 1,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// One object image through a colour matrix (G6, G8, G10): [matrix] is
/// `ClimbSavePoints.matrix` (composed with the pennant's recolour for a
/// recoloured pennant), kept so it can be read back.
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
