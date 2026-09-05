import 'package:flutter/material.dart';

/// The Back/primary-action row pinned above the keyboard on both
/// PracticeScreen's and DailyTestScreen's question screens — previously
/// built inline, identically, in both files, which is how they ended up
/// with the same bug (docs/design-audit.md): the primary button doubled
/// as "Skip" whenever the answer field was empty, so the single biggest,
/// most filled control on the screen was an invitation to abandon the
/// question rather than answer it (two consecutive audit runs on Daily
/// Test finished 0/5 correct, 5 skipped).
///
/// Fixed: [primaryLabel] is always Submit/Next/Finish, never "Skip", and
/// [onPrimary] only fires while [primaryEnabled] is true (empty answer ⇒
/// disabled). Skip is its own quiet text action below the primary row —
/// always shown, so it's never actually gone, but never the loud default
/// either. The disabled primary button gets an explicit, checked-contrast
/// color pairing rather than relying on Material's default translucent
/// disabled treatment, which (composited over this app's saturated orange
/// scaffold) is exactly what made onboarding's disabled "Continue" button
/// nearly invisible (docs/design-audit.md) — not repeating that here.
class PracticeStepFooter extends StatelessWidget {
  final bool showBack;
  final VoidCallback onBack;
  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  const PracticeStepFooter({
    super.key,
    required this.showBack,
    required this.onBack,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (showBack) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: FilledButton(
                onPressed: primaryEnabled ? onPrimary : null,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  // Same neutral, opaque pairing _PracticeModeCard already
                  // uses for its locked state — proven legible on this
                  // app's orange scaffold, not a new color decision.
                  disabledBackgroundColor: colorScheme.surfaceContainerHighest,
                  disabledForegroundColor: colorScheme.onSurfaceVariant,
                ),
                child: Text(primaryLabel),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Center(
          child: TextButton(
            onPressed: onSkip,
            // An unstyled TextButton defaults to colorScheme.primary,
            // which in light mode *is* this app's page-background orange
            // (the exact bug already fixed once for Restore Purchases —
            // see docs/roadmap.md) — explicit here so Skip doesn't repeat
            // it.
            style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }
}
