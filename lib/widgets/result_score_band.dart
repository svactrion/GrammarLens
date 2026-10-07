import 'package:flutter/material.dart';
import '../utils/content_width.dart';
import '../theme.dart';

/// The score line on a results screen's band — `BrandScaffold`'s
/// `bandBottom` slot, first used here (docs/design-audit.md §5 D1 Batch 4).
/// Shared by Daily Test Results and Topic Practice Results so "the score
/// sits in the band" is one decision enforced by one widget, not two
/// screens independently choosing to agree — the failure mode this
/// specifically avoids is one screen putting it in the band and the other
/// leaving it in the body, which would read as two different apps.
class ResultScoreBand extends StatelessWidget implements PreferredSizeWidget {
  final String text;

  /// The band's height: [_height] for one line, more when the score wraps.
  final double height;

  const ResultScoreBand({super.key, required this.text})
      : height = _height;

  /// The band sized for [text] on [context]'s screen: one line keeps the
  /// band's 52 pt; at a large text size on a narrow screen the score wraps
  /// and the band grows by the extra lines (1.2.0 final pass: the score is
  /// never cut short with an ellipsis).
  factory ResultScoreBand.sized(BuildContext context,
      {Key? key, required String text}) {
    final width = MediaQuery.sizeOf(context).width;
    final inset = ContentWidth.insetOf(context,
        edge: ContentWidth.basePadding(width));
    final maxWidth = width - 2 * inset - 2 * ContentWidth.basePadding(width);
    final style = _style(Theme.of(context));
    final scaler = MediaQuery.textScalerOf(context);
    double measure(String s, double maxWidth) {
      final painter = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout(maxWidth: maxWidth);
      final h = painter.height;
      painter.dispose();
      return h;
    }

    final extra = measure(text, maxWidth) - measure('0', double.infinity);
    return ResultScoreBand._(key: key, text: text, height: _height + extra);
  }

  const ResultScoreBand._(
      {super.key, required this.text, required this.height});

  static const double _height = 52;

  static TextStyle? _style(ThemeData theme) => theme.textTheme.headlineSmall
      ?.withWeight(FontWeight.w900)
      .copyWith(
          color: theme.appBarTheme.foregroundColor ??
              theme.colorScheme.onSurface);

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    // The band itself is moved in to the content column on an iPad
    // (`BrandScaffold`), so only the base padding here.
    final hPad = ContentWidth.basePadding(width);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: _style(theme)),
      ),
    );
  }
}
