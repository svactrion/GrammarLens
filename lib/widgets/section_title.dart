import 'package:flutter/material.dart';

/// A section's title on a page — "Today", "Medal collection" and the like
/// (1.2.0 brief: 20–21 / 800, textPrimary). The theme's `titleLarge` carries
/// the size, weight, line height and letter spacing. It replaces Home's and
/// Profile's private `_SectionLabel`s, which were a small accent-colored
/// label (14 / 700 in `secondary`).
class SectionTitle extends StatelessWidget {
  final String text;

  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A node of its own (container), so the header flag stays on the title
    // instead of merging into the enclosing node.
    return Semantics(
      container: true,
      header: true,
      child: Text(
        text,
        style: theme.textTheme.titleLarge
            ?.copyWith(color: theme.colorScheme.onSurface),
      ),
    );
  }
}
