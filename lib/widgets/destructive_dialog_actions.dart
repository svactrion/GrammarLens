import 'package:flutter/material.dart';

import '../theme.dart';

/// The two stacked actions of a confirm dialog that guards a destructive
/// step: an outlined [cancelLabel] button on top and a filled [confirmLabel]
/// button in the destructive role below. The safe way out is neutral
/// (`onSurface` label, no fill), so the only fill in the dialog is on the
/// action that cannot be undone, yet it still reads as a button beside it.
/// Both keep the full-width, 52 pt stacked layout the app's dialogs already
/// use (the 52 pt height comes from the theme's button styles).
class DestructiveDialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const DestructiveDialogActions({
    super.key,
    required this.cancelLabel,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              // `onSurfaceVariant`, not `outline` (the card-border role):
              // measured against the dialog surface (`surfaceContainerHigh`)
              // it is 7.42:1 in light and 8.39:1 in dark, while `outline` is
              // 2.72:1 in light, under the 3:1 a component boundary needs
              // (4.20:1 in dark). Re-measure if either role changes.
              side: BorderSide(color: colorScheme.onSurfaceVariant),
            ),
            onPressed: onCancel,
            child: Text(cancelLabel),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.destructive,
              foregroundColor: colorScheme.onDestructive,
            ),
            onPressed: onConfirm,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
