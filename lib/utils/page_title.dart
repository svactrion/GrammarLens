import 'package:flutter/material.dart';

/// Centered, second-tier screen title for every AppBar except Home (which
/// has its own larger brand wordmark — see home_screen.dart). Shared here so
/// Review/Results/Practice/WeakSpotDetail titles can't drift apart in size
/// or weight, and so a long topic name ("Gerund vs. Infinitive") degrades to
/// an ellipsis instead of wrapping or overflowing the app bar on narrow
/// phones.
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
      style: theme.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: foreground,
      ),
    );
  }
}
