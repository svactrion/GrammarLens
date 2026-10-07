import 'dart:async';

import 'package:flutter/material.dart';

import '../models/ai_consent.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../utils/app_messenger.dart';
import '../theme.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/destructive_dialog_actions.dart';
import '../widgets/page_header.dart';
import 'ai_consent_screen.dart';

/// Profile → Data. Holds the permission to send practice answers to the AI
/// provider, and "Reset progress data" one screen away from Profile, so the
/// destructive option is never sitting directly on the page the user scrolls
/// past every day; the confirmation dialog below is the second layer.
///
/// 1.2.0 final screens (brief §3): the header in the page, two cards (AI
/// feedback, Reset progress), a low-intensity reset button. The permission
/// is the one every practice session checks (`launchPracticeSet`: Topic
/// Practice and a weak spot's practice alike), so the copy says "practice
/// sessions", not the brief's "Topic Practice" alone.
class DataScreen extends StatefulWidget {
  final StorageService storageService;
  final AnalyticsService analyticsService;

  DataScreen({
    super.key,
    required this.storageService,
    AnalyticsService? analyticsService,
  }) : analyticsService = analyticsService ?? AnalyticsService();

  static const aiCardKey = ValueKey('data_ai_card');
  static const resetCardKey = ValueKey('data_reset_card');
  static const resetKey = ValueKey('data_reset');

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  bool _resetting = false;

  /// True while the confirmation is open, so a second tap cannot stack a
  /// second dialog.
  bool _confirming = false;

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
        // The switch shows what is stored, not what was answered: the
        // consent flow saves best effort (a launch still goes ahead), so a
        // yes that could not be saved shows off here, with a message.
        bool stored;
        try {
          stored =
              (await widget.storageService.getAiConsent())?.allowsSending ??
                  false;
        } catch (_) {
          stored = false;
        }
        if (!mounted) return;
        setState(() => _aiAllowed = stored);
        if (granted && !stored) {
          AppMessenger.show('Could not save this setting. Please try again.');
        }
      } else {
        await widget.storageService.setAiConsent(granted: false);
        unawaited(widget.analyticsService.aiConsentResult(
          outcome: AiConsentOutcome.revoked,
          source: AiConsentSource.dataSettings,
          consentVersion: AiConsent.currentVersion,
        ));
        if (!mounted) return;
        setState(() => _aiAllowed = false);
        AppMessenger.show('Practice sessions will ask again.');
      }
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show('Could not change this setting: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  Future<void> _confirmResetData() async {
    if (_confirming || _resetting) return;
    _confirming = true;
    final bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Reset your progress?'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('This clears your practice history and saved weak spots.'),
              SizedBox(height: 10),
              Text('Your name, goal and theme will stay as they are.'),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            DestructiveDialogActions(
              cancelLabel: 'Keep my progress',
              confirmLabel: 'Reset progress data',
              onCancel: () => Navigator.of(dialogContext).pop(false),
              onConfirm: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        ),
      );
    } finally {
      _confirming = false;
    }
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
    // The brief's page edge: 20, 16 under 360 pt (held to the iPad column
    // by BrandScaffold).
    final hPad = MediaQuery.sizeOf(context).width < 360 ? 16.0 : 20.0;
    final allowed = _aiAllowed ?? false;
    final body = theme.textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant, height: 1.6);
    final strong = TextStyle(
      color: colorScheme.onSurface,
    ).withWeight(FontWeight.w700);

    return BrandScaffold(
      // The status bar's height only: the back button, the title and its
      // line are in the page.
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      ),
      horizontalPadding: hPad,
      children: [
        const PageHeader(
            title: 'Data', subtitle: 'Your practice. Your choices.'),
        const SizedBox(height: 24),
        _DataCard(
          key: DataScreen.aiCardKey,
          icon: Icons.auto_awesome_rounded,
          title: 'AI feedback',
          children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Practice sessions send your '),
                TextSpan(
                    text: 'typed answers and the questions', style: strong),
                const TextSpan(text: ' to '),
                TextSpan(text: 'Anthropic (Claude)', style: strong),
                const TextSpan(text: ' to create feedback.'),
              ]),
              style: body,
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Allow AI feedback',
                style: theme.textTheme.bodyMedium
                    ?.withWeight(FontWeight.w800)
                    .copyWith(color: colorScheme.onSurface),
              ),
              subtitle: Text(
                allowed
                    ? 'On · Required for practice sessions'
                    : 'Off · Practice sessions need permission',
                style: theme.textTheme.labelMedium
                    ?.withWeight(FontWeight.w600)
                    .copyWith(color: colorScheme.onSurfaceVariant),
              ),
              value: allowed,
              onChanged: _aiAllowed == null || _aiBusy ? null : _setAiAllowed,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(Icons.info_outline_rounded,
                        size: 16, color: colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Daily Test works without this permission.',
                      style: theme.textTheme.labelMedium
                          ?.withWeight(FontWeight.w600)
                          .copyWith(color: colorScheme.onSecondaryContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DataCard(
          key: DataScreen.resetCardKey,
          icon: Icons.restart_alt_rounded,
          warning: true,
          title: 'Reset progress',
          children: [
            Text('Clear your practice history and saved weak spots.',
                style: body),
            const SizedBox(height: 12),
            Divider(height: 1, color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.shield_outlined,
                      size: 15, color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Your name, goal and theme stay as they are.',
                      style: body),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: DataScreen.resetKey,
                style: resetButtonStyle(colorScheme),
                onPressed: _resetting ? null : _confirmResetData,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: Text(_resetting ? 'Resetting…' : 'Reset progress data'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The main screen's reset action, low-intensity (brief §3): the error
  /// role as a 8 % tint over the card with a 40 % edge and an error label.
  /// The label measures 5.47:1 (light) and 7.61:1 (dark) on its fill; the
  /// edge is under 3:1 (2.07 / 2.63), the label naming the button. The
  /// full-strength red stays for the confirmation's own button.
  static ButtonStyle resetButtonStyle(ColorScheme colorScheme) {
    final card = colorScheme.surfaceContainerHigh;
    return OutlinedButton.styleFrom(
      foregroundColor: colorScheme.error,
      backgroundColor:
          Color.alphaBlend(colorScheme.error.withValues(alpha: 0.08), card),
      side: BorderSide(
          color: Color.alphaBlend(
              colorScheme.error.withValues(alpha: 0.40), card)),
      minimumSize: const Size.fromHeight(48),
    );
  }
}

/// One of Data's two cards: the theme's card with the brief's 19 pt padding,
/// an icon tile (the info surface, or an error tint for [warning]) and a
/// section title, then [children].
class _DataCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool warning;
  final List<Widget> children;

  const _DataCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tileColor = warning
        ? Color.alphaBlend(
            scheme.error.withValues(alpha: 0.10), scheme.surfaceContainerHigh)
        : scheme.secondaryContainer;
    final iconColor = warning ? scheme.error : scheme.onSecondaryContainer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, size: 20, color: iconColor),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: scheme.onSurface),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
