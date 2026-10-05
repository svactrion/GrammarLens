import 'package:flutter/material.dart';

/// Centered, second-tier screen title for every AppBar except Home (which
/// has its own larger brand wordmark — see home_screen.dart). Shared here so
/// Review/Results/Practice/WeakSpotDetail titles can't drift apart in size
/// or weight, and so a long topic name ("Gerund vs. Infinitive") degrades to
/// an ellipsis instead of wrapping or overflowing the app bar on narrow
/// phones.
///
/// 1.2.0: the theme's `headlineMedium` (26/900 at the default text size)
/// on the page-colored app bar. The brief's larger page titles (34/900,
/// `displaySmall`) belong to titles that sit in the page body, which the
/// screen batches introduce; in a centered one-line app bar title they
/// would cut "Topic Practice" short on a 320 pt screen.
class PageTitle extends StatelessWidget {
  final String text;

  const PageTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.headlineMedium?.copyWith(color: foreground),
    );
  }
}
