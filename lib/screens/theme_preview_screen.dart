import 'package:flutter/material.dart';

import '../spacing.dart';
import '../theme.dart';
import '../utils/page_title.dart';
import '../widgets/app_segmented_button.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/floating_nav_shell.dart';

/// Debug-only design reference: every [ColorScheme] role, [SemanticColors],
/// and the core components that consume them, all in one scroll. Reached
/// from Settings' "Developer" section (see `settings_screen.dart`), the
/// only place this is linked from — never shown in a release build.
///
/// Written alongside the D2 single-blue fix (docs/design-audit.md §5) so
/// the next token change has somewhere to check "does this still read" in
/// both themes without hunting across every screen for where a role landed.
class ThemePreviewScreen extends StatelessWidget {
  const ThemePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>()!;

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Theme Preview')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          NavBarClearance.of(context),
        ),
        children: [
          const _SectionLabel('Color roles'),
          const SizedBox(height: Spacing.sm),
          _ColorRoleGrid(colorScheme: colorScheme),
          const SizedBox(height: Spacing.xxl),
          const _SectionLabel('Semantic colors'),
          const SizedBox(height: Spacing.sm),
          _SemanticColorRow(
            label: 'Correct',
            background: semantic.correctBackground,
            onBackground: semantic.onCorrectBackground,
          ),
          const SizedBox(height: Spacing.sm),
          _SemanticColorRow(
            label: 'Incorrect',
            background: semantic.incorrectBackground,
            onBackground: semantic.onIncorrectBackground,
          ),
          const SizedBox(height: Spacing.sm),
          _SemanticColorRow(
            label: 'Skipped',
            background: semantic.skippedBackground,
            onBackground: semantic.onSkippedBackground,
          ),
          const SizedBox(height: Spacing.xxl),
          const _SectionLabel('Components'),
          const SizedBox(height: Spacing.sm),
          const _ComponentGallery(),
          const SizedBox(height: Spacing.xxl),
          const _SectionLabel('BrandScaffold (D1 header band)'),
          const SizedBox(height: Spacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const _BrandScaffoldDemo()),
              ),
              child: const Text('Open BrandScaffold example'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A live example, not a static mockup — pushes a real `BrandScaffold` so
/// the band (orange in light, neutral in dark) and a card sitting on its
/// neutral body are exercised through the actual widget, not a
/// description of it. Reached only from this debug screen.
class _BrandScaffoldDemo extends StatelessWidget {
  const _BrandScaffoldDemo();

  @override
  Widget build(BuildContext context) {
    return const BrandScaffold(
      title: PageTitle('BrandScaffold example'),
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Text(
              'A card inside a BrandScaffold body — should still read as '
              'a distinct, elevated surface in both themes, not blend '
              'into the neutral background behind it.',
            ),
          ),
        ),
        SizedBox(height: Spacing.lg),
        Card(
          child: Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Text('A second card, to compare spacing and elevation.'),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: theme.colorScheme.secondary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// One row per [ColorScheme] field this app's hand-built theme actually
/// sets (see `theme.dart`'s `_buildColorScheme`) — not just the roles a
/// grep of current screen code happens to touch today, since the point of
/// this screen is to catch a bad token before it ships to a new use site,
/// not just re-describe existing ones.
class _ColorRoleGrid extends StatelessWidget {
  final ColorScheme colorScheme;

  const _ColorRoleGrid({required this.colorScheme});

  List<(String, Color)> get _roles => [
        ('primary', colorScheme.primary),
        ('onPrimary', colorScheme.onPrimary),
        ('primaryContainer', colorScheme.primaryContainer),
        ('onPrimaryContainer', colorScheme.onPrimaryContainer),
        ('secondary', colorScheme.secondary),
        ('onSecondary', colorScheme.onSecondary),
        ('secondaryContainer', colorScheme.secondaryContainer),
        ('onSecondaryContainer', colorScheme.onSecondaryContainer),
        ('tertiary', colorScheme.tertiary),
        ('onTertiary', colorScheme.onTertiary),
        ('tertiaryContainer', colorScheme.tertiaryContainer),
        ('onTertiaryContainer', colorScheme.onTertiaryContainer),
        ('error', colorScheme.error),
        ('onError', colorScheme.onError),
        ('errorContainer', colorScheme.errorContainer),
        ('onErrorContainer', colorScheme.onErrorContainer),
        ('surface', colorScheme.surface),
        ('onSurface', colorScheme.onSurface),
        ('onSurfaceVariant', colorScheme.onSurfaceVariant),
        ('surfaceContainerLow', colorScheme.surfaceContainerLow),
        ('surfaceContainer', colorScheme.surfaceContainer),
        ('surfaceContainerHigh', colorScheme.surfaceContainerHigh),
        ('surfaceContainerHighest', colorScheme.surfaceContainerHighest),
        ('outline', colorScheme.outline),
        ('outlineVariant', colorScheme.outlineVariant),
        ('inverseSurface', colorScheme.inverseSurface),
        ('onInverseSurface', colorScheme.onInverseSurface),
        ('inversePrimary', colorScheme.inversePrimary),
        ('shadow', colorScheme.shadow),
      ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Spacing.sm,
      crossAxisSpacing: Spacing.sm,
      childAspectRatio: 1.6,
      children: [
        for (final (name, color) in _roles)
          _ColorRoleTile(name: name, color: color),
      ],
    );
  }
}

class _ColorRoleTile extends StatelessWidget {
  final String name;
  final Color color;

  const _ColorRoleTile({required this.name, required this.color});

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            name,
            style: theme.textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            _hex(color),
            style: theme.textTheme.labelSmall
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SemanticColorRow extends StatelessWidget {
  final String label;
  final Color background;
  final Color onBackground;

  const _SemanticColorRow({
    required this.label,
    required this.background,
    required this.onBackground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.md,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: onBackground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ComponentGallery extends StatelessWidget {
  const _ComponentGallery();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child:
                  FilledButton(onPressed: () {}, child: const Text('Enabled')),
            ),
            const SizedBox(width: Spacing.sm),
            const Expanded(
              child: FilledButton(onPressed: null, child: Text('Disabled')),
            ),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            child: const Text('Outlined button'),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        SizedBox(
          width: double.infinity,
          child: TextButton(onPressed: () {}, child: const Text('Text button')),
        ),
        const SizedBox(height: Spacing.lg),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(Spacing.lg),
            child: Text('Card content sits on surfaceContainerLow.'),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        const TextField(
          decoration: InputDecoration(hintText: 'Text field'),
        ),
        const SizedBox(height: Spacing.lg),
        // The real selected/unselected pill pattern already used in
        // Settings (theme, entitlement override) and Premium (plan
        // period) — reused here rather than a one-off pill mockup, so
        // this preview reflects exactly what those screens render.
        AppSegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Unselected')),
            ButtonSegment(value: true, label: Text('Selected')),
          ],
          selected: const {true},
          onSelectionChanged: (_) {},
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.star_rounded, size: 26),
            ),
            const SizedBox(width: Spacing.md),
            CircleAvatar(
              radius: 26,
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: const Icon(Icons.star_rounded, size: 26),
            ),
          ],
        ),
      ],
    );
  }
}
