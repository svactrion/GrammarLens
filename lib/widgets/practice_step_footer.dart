import 'package:flutter/material.dart';

/// The Skip/primary-action row pinned above the keyboard on both
/// PracticeScreen's and DailyTestScreen's question screens — previously
/// built inline, identically, in both files, which is how they ended up
/// with the same bug (docs/design-audit.md D3): the primary button doubled
/// as "Skip" whenever the answer field was empty, so the single biggest,
/// most filled control on the screen was an invitation to abandon the
/// question rather than answer it (two consecutive audit runs on Daily
/// Test finished 0/5 correct, 5 skipped).
///
/// Fixed: [primaryLabel] is always Submit/Next/Finish, never "Skip", and
/// [onPrimary] only fires while [primaryEnabled] is true (empty answer ⇒
/// disabled). Skip sits beside it as its own outlined button at a fixed,
/// narrow width — visible and clearly tappable, but deliberately not as
/// wide as the primary action, so it reads as the secondary choice rather
/// than an equal alternative (D3 again: Skip must not be primary). Back
/// used to share this row too; it now lives in the app bar instead — see
/// QuestionAppBar.
class PracticeStepFooter extends StatelessWidget {
  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  const PracticeStepFooter({
    super.key,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
    required this.onSkip,
  });

  static const double _height = 52;
  // Wide enough for "Skip" with comfortable padding, clearly narrower than
  // the primary button's Expanded remainder on any phone width.
  static const double _skipWidth = 100;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: _skipWidth,
          height: _height,
          child: OutlinedButton(
            onPressed: onSkip,
            child: const Text('Skip'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: _height,
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
        ),
      ],
    );
  }
}
