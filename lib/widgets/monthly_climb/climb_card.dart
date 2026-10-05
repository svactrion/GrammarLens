import 'package:flutter/material.dart';

import '../../models/climb_theme.dart';
import '../../theme.dart';

/// The Monthly Climb card on Home (1.1.0 design decision K3, Batch 3c
/// a–c): a thin frame around the mountain and the score bar, "Mountain of
/// Learning" on a plaque that sits on the frame's top line, and
/// inside the frame the month (without the year) at the top left and the
/// steps at the top right, each on a small sky-colored chip (K4) so the
/// text keeps its contrast over any part of the scene.
///
/// Replaces Batch 3b's two header rows (D10). The medals keep their
/// month-and-year label; only Home drops the year.
///
/// 1.2.0 (owner decision Q16): the plaque is a stadium on the neutral card
/// surface with a 1.5 pt `AppPalette.pathOutline` edge, replacing the
/// 2026-10-02 trail sign; the frame has the same 1.5 pt edge and the list
/// card radius (22). Neither takes a color from the month's map theme.
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

  /// The frame's corner radius: the brief's list card radius (22), not
  /// the large card's 24 ([appCardRadius]).
  static const frameRadius = 22.0;

  /// The frame's and the plaque's edge width (the brief: 1.5).
  static const outlineWidth = 1.5;

  /// The plaque's padding inside its edge (the brief: 8 above and below,
  /// 16 at the sides).
  static const _plaquePadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  static const plaqueKey = ValueKey('climb_card_plaque');
  static const monthKey = ValueKey('climb_card_month');
  static const stepsKey = ValueKey('climb_card_steps');

  /// The plaque's height: its text, the padding and the edge.
  static double plaqueHeight(BuildContext context) {
    final painter = TextPainter(
      text:
          TextSpan(text: 'Mountain of Learning', style: _plaqueStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final height = painter.height + _plaquePadding.vertical + 2 * outlineWidth;
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

  /// The plaque's text: the brief's 16/900, line height 1.25, letter
  /// spacing −0.3 (16 pt at the default text size: `bodyLarge`'s size).
  static TextStyle? _plaqueStyle(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w900,
      height: 1.25,
      letterSpacing: -0.3,
      color: theme.colorScheme.onSurface,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final outline = BorderSide(
        color: AppPalette.of(context).pathOutline, width: outlineWidth);
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
          decoration: BoxDecoration(
              border: Border.fromBorderSide(outline),
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
                  shape: StadiumBorder(side: outline)),
              child: SizedBox(
                height: plaqueH,
                child: Padding(
                  padding: _plaquePadding + const EdgeInsets.all(outlineWidth),
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
