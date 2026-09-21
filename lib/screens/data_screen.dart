import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_consent.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/app_messenger.dart';
import '../theme.dart';
import '../utils/page_title.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/destructive_dialog_actions.dart';
import 'ai_consent_screen.dart';

/// Profile → Data. Holds the permission to send Topic Practice answers to the
/// AI provider, and "Reset progress data" one screen away from Profile, so the
/// destructive option is never sitting directly on the page the user scrolls
/// past every day; the confirmation dialog below is the second layer.
class DataScreen extends StatefulWidget {
  final StorageService storageService;
  final AnalyticsService analyticsService;

  DataScreen({
    super.key,
    required this.storageService,
    AnalyticsService? analyticsService,
  }) : analyticsService = analyticsService ?? AnalyticsService();

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _resetting = false;

  /// Null until the stored decision is read; an unreadable decision counts as
  /// "off", the same fail-closed reading `ensureAiConsent` uses.
  bool? _aiAllowed;
  bool _aiBusy = false;

  @override
  void initState() {
    super.initState();
    _loadAiConsent();
  }

  Future<void> _loadAiConsent() async {
    bool allowed;
    try {
      allowed =
          (await widget.storageService.getAiConsent())?.allowsSending ?? false;
    } catch (_) {
      allowed = false;
    }
    if (!mounted) return;
    setState(() => _aiAllowed = allowed);
  }

  /// Turning it on shows the permission screen (never a bare switch flip, so
  /// the wording is always seen); turning it off takes effect at once.
  Future<void> _setAiAllowed(bool wanted) async {
    if (_aiBusy) return;
    setState(() => _aiBusy = true);
    try {
      if (wanted) {
        final granted = await requestAiConsent(
          context: context,
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          source: AiConsentSource.dataSettings,
        );
        if (!mounted) return;
        setState(() => _aiAllowed = granted);
      } else {
        await widget.storageService.setAiConsent(granted: false);
        unawaited(widget.analyticsService.aiConsentResult(
          outcome: AiConsentOutcome.revoked,
          source: AiConsentSource.dataSettings,
          consentVersion: AiConsent.currentVersion,
        ));
        if (!mounted) return;
        setState(() => _aiAllowed = false);
        AppMessenger.show('Topic Practice will ask again.');
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show('Could not change this setting: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

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
          'AI feedback',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Topic Practice sends your typed answers and the questions to '
          'Anthropic (Claude) to write your feedback. The Daily Test does '
          'not.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Send my practice answers to Anthropic (Claude)'),
          subtitle: const Text(
              'Needed for Topic Practice. Daily Test works without it.'),
          value: _aiAllowed ?? false,
          onChanged: _aiAllowed == null || _aiBusy ? null : _setAiAllowed,
        ),
        const SizedBox(height: 24),
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
