import 'package:flutter/material.dart';

/// Shared icon + text treatment for "nothing here yet" screens/sections, so
/// every empty state in the app looks and reads the same way instead of each
/// screen hand-rolling its own Column/Row of Icon+Text.
///
/// The default layout is a centered block (icon, optional title, optional
/// description, optional CTA button) for empty states that own the whole
/// screen body. Set [dense] for a smaller inline treatment (icon + text in a
/// row) when the empty state is just one section within a screen that
/// already has its own call to action elsewhere.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String? title;
  final String? description;
  final String? ctaLabel;
  final VoidCallback? onCta;
  final bool dense;

  const EmptyState({
    super.key,
    required this.icon,
    this.title,
    this.description,
    this.ctaLabel,
    this.onCta,
    this.dense = false,
  }) : assert(
          title != null || description != null,
          'EmptyState needs a title and/or a description to show.',
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = theme.colorScheme.onSurfaceVariant;

    if (dense) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: mutedColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description ?? title!,
              style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 40, color: mutedColor),
        const SizedBox(height: 12),
        if (title != null)
          Text(
            title!,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        if (title != null && description != null) const SizedBox(height: 6),
        if (description != null)
          Text(
            description!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(color: mutedColor),
          ),
        if (ctaLabel != null && onCta != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
        ],
      ],
    );
  }
}
