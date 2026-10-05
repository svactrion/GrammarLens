import 'package:flutter/material.dart';

/// Flutter's own [BackButton] (its "Back" label and platform icon), drawn as
/// the 1.2.0 mockups' 44 pt bordered tile on the card surface. The back
/// button of every page whose header is in the page (Topic Practice, Data,
/// Credits).
class PageBackButton extends StatelessWidget {
  const PageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BackButton(
      style: IconButton.styleFrom(
        fixedSize: const Size(44, 44),
        minimumSize: const Size(44, 44),
        backgroundColor: scheme.surfaceContainerHigh,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// A pushed page's header in the page (1.2.0 final screens, Data and
/// Credits): the back tile, the title (displaySmall, the brief's 34 / 900)
/// as a heading, and its line.
class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const PageHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageBackButton(),
        const SizedBox(height: 18),
        Semantics(
          container: true,
          header: true,
          child: Text(
            title,
            style:
                theme.textTheme.displaySmall?.copyWith(color: scheme.onSurface),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
