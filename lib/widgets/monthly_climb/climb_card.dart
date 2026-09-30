import 'package:flutter/material.dart';

import '../../models/climb_theme.dart';

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

  const ClimbCard({
    super.key,
    required this.mountain,
    required this.scoreBar,
    required this.month,
    required this.steps,
    required this.days,
  });

  /// English month names: the app has no localization setup (roadmap,
  /// "Turkish UI copy"), and `MaterialLocalizations` only formats a month
  /// together with its year.
  static const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July', //
    'August', 'September', 'October', 'November', 'December',
  ];

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

  static TextStyle? _plaqueStyle(BuildContext context) => Theme.of(context)
      .textTheme
      .titleMedium
      ?.copyWith(fontWeight: FontWeight.w700);

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
          // The B-polish card border (CardThemeData): `outline`, radius 20.
          decoration: BoxDecoration(
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                  ),
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
                  shape: _TrailSignBorder(BorderSide(color: scheme.outline))),
              child: SizedBox(
                height: plaqueH,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: plaqueH * _TrailSignBorder.pointDepth + 12),
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

/// A trail sign: a flat board whose ends come to a point.
class _TrailSignBorder extends ShapeBorder {
  /// How far in, as a share of the height, each point reaches.
  static const pointDepth = .38;

  final BorderSide side;
  const _TrailSignBorder(this.side);

  Path _path(Rect r) {
    final p = r.height * pointDepth;
    return Path()
      ..moveTo(r.left + p, r.top)
      ..lineTo(r.right - p, r.top)
      ..lineTo(r.right, r.center.dy)
      ..lineTo(r.right - p, r.bottom)
      ..lineTo(r.left + p, r.bottom)
      ..lineTo(r.left, r.center.dy)
      ..close();
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
  ShapeBorder scale(double t) => _TrailSignBorder(side.scale(t));
}
