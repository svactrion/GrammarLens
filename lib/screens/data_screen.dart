import 'package:flutter/material.dart';

import '../services/storage_service.dart';
import '../utils/app_messenger.dart';
import '../theme.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/destructive_dialog_actions.dart';

/// Profile → Data. Holds "Reset progress data" one screen away from Profile,
/// so the destructive option is never sitting directly on the page the user
/// scrolls past every day; the confirmation dialog below is the second layer.
class DataScreen extends StatefulWidget {
  final StorageService storageService;

  const DataScreen({super.key, required this.storageService});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _resetting = false;

  Future<void> _confirmResetData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This clears your practice history and weak spots. Your name, '
          'goal, and theme are kept. This can\'t be undone.',
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          DestructiveDialogActions(
            cancelLabel: 'Cancel',
            confirmLabel: 'Reset',
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onConfirm: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resetting = true);
    try {
      await widget.storageService.resetProgressData();
      if (!mounted) return;
      AppMessenger.show('Progress reset.');
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show('Could not reset progress: $e');
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BrandScaffold(
      title: const PageTitle('Data'),
      children: [
        Text(
          'Reset progress',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Clears practice history and weak spots. Your name, goal, and '
          'theme stay as they are.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.destructive,
              foregroundColor: colorScheme.onDestructive,
            ),
            onPressed: _resetting ? null : _confirmResetData,
            child: Text(_resetting ? 'Resetting…' : 'Reset progress data'),
          ),
        ),
      ],
    );
  }
}
