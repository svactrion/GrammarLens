import 'package:flutter/material.dart';

/// The score line on a results screen's band — `BrandScaffold`'s
/// `bandBottom` slot, first used here (docs/design-audit.md §5 D1 Batch 4).
/// Shared by Daily Test Results and Topic Practice Results so "the score
/// sits in the band" is one decision enforced by one widget, not two
/// screens independently choosing to agree — the failure mode this
/// specifically avoids is one screen putting it in the band and the other
/// leaving it in the body, which would read as two different apps.
class ResultScoreBand extends StatelessWidget implements PreferredSizeWidget {
  final String text;

  const ResultScoreBand({super.key, required this.text});

  static const double _height = 52;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
