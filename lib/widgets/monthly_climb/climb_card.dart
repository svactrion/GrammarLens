import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../models/climb_theme.dart';
import '../../theme.dart';

/// The Monthly Climb card on Home (1.1.0 design decision K3, Batch 3c
/// a–c): a thin frame around the mountain and the score bar, "Mountain of
/// Learning" on a trail-sign plaque that sits on the frame's top line, and
/// inside the frame the month (without the year) at the top left and the
/// steps at the top right, each on a small sky-colored chip (K4) so the
/// text keeps its contrast over any part of the scene.
///
/// Replaces Batch 3b's two header rows (D10). The medals keep their
/// month-and-year label; only Home drops the year.
class ClimbCard extends StatelessWidget {
  /// The mountain window (`MonthlyMountain`).
  final Widget mountain;

  /// Under the window, inside the frame (`ClimbScoreBar`).
  final Widget scoreBar;

  final DateTime month;
  final int steps;
  final int days;

  /// Batch 6: the month and step chips' opacity during a zoom. They cover
  /// the top of the image in the K-c framing, so they are hidden there and
  /// fade in at the zoom's end. Null: always shown.
  final Animation<double>? chipOpacity;

  const ClimbCard({
    super.key,
    required this.mountain,
    required this.scoreBar,
    required this.month,
    required this.steps,
    required this.days,
    this.chipOpacity,
  });

  static const chipsKey = ValueKey('climb_card_chips');

  /// English month names: the app has no localization setup (roadmap,
  /// "Turkish UI copy"), and `MaterialLocalizations` only formats a month
  /// together with its year.
  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

  /// The frame's corner radius: 20, the app's card radius before 1.2.0
  /// (B-polish `CardThemeData`). 1.2.0 raised the card radius to 24
  /// ([appCardRadius]); the frame and the plaque derived from it keep 20
  /// until the plaque's own redesign (owner decision Q16, a later batch),
  /// so the theme batch leaves the mountain card exactly as it was.
  static const frameRadius = 20.0;

  /// The plaque's corner radius as a share of [frameRadius]: every corner
  /// of the trail sign, its two points included, is rounded with
  /// `frameRadius × plaqueRadiusShare` (14 pt at 0.7, owner 2026-10-02;
  /// 0.4 before). **The one setting** to try on a device. A corner never
  /// takes more than half of either edge it joins, so the sign keeps its
  /// silhouette at any value.
  static const plaqueRadiusShare = .7;

  static double? _plaqueShareForTesting;

  /// Debug builds only: stands in for [plaqueRadiusShare] in measuring
  /// tools (renders at other shares). Ignored in profile and release.
  static set debugPlaqueRadiusShareOverride(double? value) =>
      _plaqueShareForTesting = value;

  static double get _plaqueShare =>
      (kDebugMode ? _plaqueShareForTesting : null) ?? plaqueRadiusShare;

  static const plaqueKey = ValueKey('climb_card_plaque');
  static const monthKey = ValueKey('climb_card_month');
  static const stepsKey = ValueKey('climb_card_steps');

  /// The plaque's height: its text plus 6 pt above and below.
  static double plaqueHeight(BuildContext context) {
    final painter = TextPainter(
      text:
          TextSpan(text: 'Mountain of Learning', style: _plaqueStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height + 12;
    painter.dispose();
    return height;
  }

  /// The month and step chips' boxes in the mountain window's points, for a
  /// window [width] wide: the save point label moves below a chip it would
  /// touch (Batch 5, N19). Each chip is its text in labelLarge bold, 6 pt
  /// either side and 2 pt above and below, 10 pt in from the window's
  /// side, its top at the plaque's lower half plus 6 pt.
  static List<Rect> chipRects(BuildContext context,
      {required double width,
      required DateTime month,
      required int steps,
      required int days}) {
    final style = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(fontWeight: FontWeight.w700);
    Size measure(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final size = Size(painter.width + 12, painter.height + 4);
      painter.dispose();
      return size;
    }

    final top = plaqueHeight(context) / 2 + 6;
    final monthChip = measure(monthNames[month.month - 1]);
    final stepsChip = measure('$steps / $days');
    return [
      Offset(10, top) & monthChip,
      Offset(width - 10 - stepsChip.width, top) & stepsChip,
    ];
  }

  /// The plaque's text, held to its pre-1.2.0 metrics (Material's
  /// titleMedium: 16 pt × the text size, line height 1.35, letter spacing
  /// 0.15) until the plaque's redesign (Q16): its height, and so its 14 pt
  /// corners, stay as the owner approved them at every text size.
  static TextStyle? _plaqueStyle(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium;
    final size = style?.fontSize;
    return style?.copyWith(
      fontSize: size == null ? null : size * preRedesignTitleMediumRatio,
      fontWeight: FontWeight.w700,
      height: 1.35,
      letterSpacing: 0.15,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = ClimbThemes.greenSlope.paletteFor(theme.brightness);
    final plaqueH = plaqueHeight(context);
    final labelStyle = theme.textTheme.labelLarge
        ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700);

    Widget chip(Widget child) => DecoratedBox(
          decoration: BoxDecoration(
              color: palette.sky, borderRadius: BorderRadius.circular(8)),
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: child),
        );

    return Stack(clipBehavior: Clip.none, children: [
      Padding(
        // The plaque sits on the frame's top line: half above it.
        padding: EdgeInsets.only(top: plaqueH / 2),
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          // The B-polish card border (CardThemeData): `outline`,
          // [frameRadius].
          decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(frameRadius)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(frameRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(children: [
                  mountain,
                  Positioned(
                      left: 10,
                      right: 10,
                      top: plaqueH / 2 + 6,
                      // Each chip scales down only if the row cannot hold it:
                      // never at the app's text sizes, only under a very
                      // large system text size (Dynamic Type).
                      child: FadeTransition(
                        key: chipsKey,
                        opacity: chipOpacity ?? kAlwaysCompleteAnimation,
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: chip(Text(monthNames[month.month - 1],
                                      key: monthKey, style: labelStyle)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Semantics(
                                    liveRegion: true,
                                    container: true,
                                    label: steps == days
                                        ? 'Summit reached. $steps of $days steps.'
                                        : '$steps of $days steps.',
                                    excludeSemantics: true,
                                    child: chip(Text('$steps / $days',
                                        key: stepsKey, style: labelStyle)),
                                  ),
                                ),
                              ),
                            ]),
                      )),
                ]),
                scoreBar,
              ],
            ),
          ),
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Center(
          child: Semantics(
            header: true,
            child: DecoratedBox(
              key: plaqueKey,
              decoration: ShapeDecoration(
                  color: scheme.surfaceContainerHigh,
                  shape: TrailSignBorder(BorderSide(color: scheme.outline),
                      radius: frameRadius * _plaqueShare)),
              child: SizedBox(
                height: plaqueH,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: plaqueH * TrailSignBorder.pointDepth + 12),
                  child: Center(
                      widthFactor: 1,
                      child: Text('Mountain of Learning',
                          style: _plaqueStyle(context))),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// A trail sign: a flat board whose ends come to a point, every corner
/// rounded with [radius].
class TrailSignBorder extends ShapeBorder {
  /// How far in, as a share of the height, each point reaches.
  static const pointDepth = .38;

  final BorderSide side;

  /// Each corner's radius, in points; 0 draws the sharp sign.
  final double radius;
  const TrailSignBorder(this.side, {this.radius = 0});

  /// The sign's six corners, clockwise from the top left.
  static List<Offset> corners(Rect r) {
    final p = r.height * pointDepth;
    return [
      Offset(r.left + p, r.top),
      Offset(r.right - p, r.top),
      Offset(r.right, r.center.dy),
      Offset(r.right - p, r.bottom),
      Offset(r.left + p, r.bottom),
      Offset(r.left, r.center.dy),
    ];
  }

  /// Half the angle between the corner's edges toward [a] and [b].
  static double _halfAngle(Offset a, Offset b) =>
      math.acos(((a.dx * b.dx + a.dy * b.dy) / (a.distance * b.distance))
          .clamp(-1.0, 1.0)) /
      2;

  /// The radius a corner is drawn with: [r], made smaller where the arc
  /// would take more than half of an edge it joins.
  static double fittedRadius(Offset prev, Offset at, Offset next, double r) {
    final a = prev - at, b = next - at;
    final half = _halfAngle(a, b);
    final reach =
        math.min(r / math.tan(half), math.min(a.distance, b.distance) / 2);
    return reach * math.tan(half);
  }

  Path _path(Rect rect) {
    final c = corners(rect);
    if (radius <= 0) return Path()..addPolygon(c, true);
    final path = Path();
    for (var i = 0; i < c.length; i++) {
      final prev = c[(i + c.length - 1) % c.length];
      final at = c[i];
      final next = c[(i + 1) % c.length];
      final a = prev - at, b = next - at;
      final r = fittedRadius(prev, at, next, radius);
      // Where the arc meets each edge, measured from the corner.
      final reach = r / math.tan(_halfAngle(a, b));
      final from = at + a / a.distance * reach;
      final to = at + b / b.distance * reach;
      if (i == 0) {
        path.moveTo(from.dx, from.dy);
      } else {
        path.lineTo(from.dx, from.dy);
      }
      path.arcToPoint(to, radius: Radius.circular(r));
    }
    return path..close();
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);
  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);
  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) =>
      canvas.drawPath(_path(rect), side.toPaint());
  @override
  ShapeBorder scale(double t) =>
      TrailSignBorder(side.scale(t), radius: radius * t);
}
