import 'package:flutter/material.dart';

import '../theme.dart';

/// The two stacked actions of a confirm dialog that guards a destructive
/// step: a quiet [cancelLabel] text button on top and a filled
/// [confirmLabel] button in the destructive role below. The safe way out is
/// neutral (`onSurface`), so the only emphasis in the dialog is on the action
/// that cannot be undone. Both buttons keep the full-width, 52 pt stacked
/// layout the app's dialogs already use.
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
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.onSurface,
              minimumSize: const Size.fromHeight(52),
              // Same label style as the filled button below, from the one
              // theme entry that defines it.
              textStyle: theme.filledButtonTheme.style?.textStyle?.resolve({}),
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
