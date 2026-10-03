import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// P1 (1.1.0 release preparation): on a wide screen (an iPad) the content
/// column is centred and capped at [maxContentWidth]; on a narrower screen
/// (every iPhone) nothing changes. Backgrounds, the top band, the nav bar's
/// surface and dimming layers stay full width; only what sits on them is
/// held to the column.
///
/// The one place the rule lives: `BrandScaffold` applies it to every list
/// screen and to the band, and the screens that lay out their own body
/// pass their side padding through [sidePadding] instead of using it raw.
abstract final class ContentWidth {
  /// A screen whose shortest side is at least this is wide.
  static const wideShortestSide = 600.0;

  /// The content column's largest width on a wide screen.
  static const maxContentWidth = 640.0;

  /// For the measuring tools only (the 560 / 640 / 720 pt comparison).
  @visibleForTesting
  static double? debugMaxContentWidthOverride;

  static double get _cap => debugMaxContentWidthOverride ?? maxContentWidth;

  /// The screen-edge padding most screens use: 4.5 % of the width, 16-28 pt.
  static double basePadding(double width) =>
      (width * 0.045).clamp(16.0, 28.0).toDouble();

  /// The padding on each side for a screen of [size] whose own padding is
  /// [base]: [base] on a narrow screen; on a wide one, at least what keeps
  /// the column within [maxContentWidth], centred.
  static double sidePadding(Size size, double base) {
    if (size.shortestSide < wideShortestSide) return base;
    return math.max(base, (size.width - _cap) / 2);
  }

  /// [sidePadding] with [base] defaulting to [basePadding], for [context]'s
  /// screen.
  static double sidePaddingOf(BuildContext context, {double? base}) {
    final size = MediaQuery.sizeOf(context);
    return sidePadding(size, base ?? basePadding(size.width));
  }

  /// What an element that already sits [edge] pt in from each side must
  /// add to keep its content in the column: 0 on a narrow screen.
  static double insetOf(BuildContext context, {double edge = 0}) {
    final size = MediaQuery.sizeOf(context);
    if (size.shortestSide < wideShortestSide) return 0;
    return math.max(0.0, (size.width - _cap) / 2 - edge);
  }
}
