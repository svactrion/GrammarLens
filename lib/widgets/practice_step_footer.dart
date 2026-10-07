import 'package:flutter/material.dart';

import '../theme.dart';

/// The Skip/primary-action bar at the bottom of PracticeScreen's and
/// DailyTestScreen's question screens, above the keyboard while it is open.
/// Shared since docs/design-audit.md D3 found both screens with the same
/// bug: the primary button doubled as "Skip" whenever the answer was empty,
/// so the biggest control on the screen invited abandoning the question
/// (two audit runs on Daily Test finished 0/5 correct, 5 skipped).
///
/// Still fixed: [primaryLabel] is Next/Submit/Finish, never "Skip", and
/// [onPrimary] only fires while [primaryEnabled] is true (an empty answer
/// disables it). Skip is its own quiet action beside it.
///
/// Question V2 look (the additional screens package): a card-surface bar
/// with a 1 px `border` line on top, Skip as a link-coloured text button at
/// least 63 wide, and the primary action in the brand orange with the
/// onOrange text (the mockup's colour: 6.93:1 light, 7.71:1 dark), 900
/// weight, at least 48 tall (the mockup's 45 raised to the brief's 48).
/// Disabled, it takes the app's opaque disabled pairing (`AppPalette`). No
/// dark-mode navy edge: that belongs to the navy button only.
class PracticeStepFooter extends StatelessWidget {
  final String primaryLabel;
  final bool primaryEnabled;
  final VoidCallback onPrimary;
  final VoidCallback onSkip;

  /// The content column's side padding (the question screen's own, so the
  /// buttons line up with the cards above).
  final double horizontalPadding;

  const PracticeStepFooter({
    super.key,
    required this.primaryLabel,
    required this.primaryEnabled,
    required this.onPrimary,
    required this.onSkip,
    this.horizontalPadding = 16,
  });

  static const skipKey = ValueKey('practice_step_skip');
  static const primaryKey = ValueKey('practice_step_primary');

  static const double height = 48;
  static const double skipMinWidth = 63;
  static const double gap = 10;

  /// The primary action's style: brandOrange / onOrange, the disabled
  /// pairing, no edge.
  static ButtonStyle primaryStyle(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    return FilledButton.styleFrom(
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      disabledBackgroundColor: palette.disabledFill,
      disabledForegroundColor: palette.disabledLabel,
      minimumSize: const Size.fromHeight(height),
      textStyle: theme.textTheme.labelLarge?.withWeight(FontWeight.w900),
    ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              EdgeInsets.fromLTRB(horizontalPadding, 9, horizontalPadding, 10),
          child: Row(
            children: [
              TextButton(
                key: skipKey,
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  minimumSize: const Size(skipMinWidth, height),
                  foregroundColor: colorScheme.secondary,
                  textStyle:
                      theme.textTheme.labelLarge?.withWeight(FontWeight.w800),
                ),
                child: const Text('Skip'),
              ),
              const SizedBox(width: gap),
              Expanded(
                child: FilledButton(
                  key: primaryKey,
                  style: primaryStyle(context),
                  onPressed: primaryEnabled ? onPrimary : null,
                  child: Text(primaryLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
