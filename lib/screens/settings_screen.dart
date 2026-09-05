import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../models/app_theme_mode.dart';
import '../models/avatar.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_messenger.dart';
import '../utils/layout_constants.dart';
import '../utils/page_title.dart';
import '../widgets/avatar_tile.dart';

/// The three choices shown in Settings' debug-only "Developer" section —
/// a UI-layer concept only. [SubscriptionService.debugAccessOverride]
/// itself is `bool?` (real/free/full collapses to null/false/true): see
/// that field's doc comment for why no third domain state exists.
enum _DebugAccessChoice {
  real,
  free,
  full;

  bool? get override => switch (this) {
        _DebugAccessChoice.real => null,
        _DebugAccessChoice.free => false,
        _DebugAccessChoice.full => true,
      };

  static _DebugAccessChoice fromOverride(bool? override) => switch (override) {
        null => _DebugAccessChoice.real,
        false => _DebugAccessChoice.free,
        true => _DebugAccessChoice.full,
      };
}

/// PRD v2 §4 — theme, name edit, data reset, and optional profile fields
/// (age, occupation) that onboarding deliberately left out. Learning goal
/// isn't editable here: nothing in scope needs it to change, and adding a
/// second place to set it risks drifting from onboarding's copy.
class SettingsScreen extends StatefulWidget {
  final AppThemeMode themeMode;
  final void Function(AppThemeMode mode) onSelectThemeMode;
  final UserProfile profile;
  final StorageService storageService;
  final ValueChanged<UserProfile> onProfileUpdated;
  final SubscriptionService subscriptionService;

  /// Debug-only: called after the profile is cleared in storage, so the
  /// app can drop back to the Welcome/Onboarding flow (app.dart sets its
  /// `_profile` back to null) without an app restart. Only ever invoked
  /// from the "Developer" section below, itself `if (kDebugMode)`-gated.
  final VoidCallback onResetOnboarding;

  SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onSelectThemeMode,
    required this.profile,
    required this.storageService,
    required this.onProfileUpdated,
    required this.onResetOnboarding,
    SubscriptionService? subscriptionService,
  }) : subscriptionService = subscriptionService ?? SubscriptionService();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _occupationController;
  late Avatar? _selectedAvatar;
  bool _savingProfile = false;
  bool _resetting = false;
  bool _resettingOnboarding = false;
  late _DebugAccessChoice _debugAccessChoice;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController =
        TextEditingController(text: widget.profile.age?.toString() ?? '');
    _occupationController =
        TextEditingController(text: widget.profile.occupation ?? '');
    _selectedAvatar = widget.profile.avatar;
    // Reads the already-loaded in-memory override (app.dart applies
    // whatever was persisted at app startup — see its own
    // _loadDebugAccessOverride) rather than re-reading storage here, so
    // this always reflects exactly what SubscriptionService is actually
    // enforcing right now, never a stale/independent copy of it.
    _debugAccessChoice = _DebugAccessChoice.fromOverride(
      widget.subscriptionService.debugAccessOverride,
    );
  }

  Future<void> _setDebugAccessChoice(_DebugAccessChoice choice) async {
    setState(() => _debugAccessChoice = choice);
    // Goes through the same hasFullAccess/addAccessListener path every
    // gated screen already uses (see SubscriptionService.setDebugAccessOverride)
    // — Home's card updates live, no separate gating logic here.
    await widget.subscriptionService.setDebugAccessOverride(choice.override);
    unawaited(
      widget.storageService
          .setDebugAccessOverride(choice.override)
          .catchError((_) {}),
    );
  }

  /// Debug-only: clears the saved profile and hands off to
  /// [SettingsScreen.onResetOnboarding] so app.dart drops back to the
  /// Welcome/Onboarding flow. No confirmation dialog, unlike "reset
  /// progress data" below — this is a developer convenience meant to be
  /// triggered repeatedly while reviewing those screens, and losing a
  /// throwaway dev profile isn't the same stakes as a real user losing
  /// practice history.
  Future<void> _resetOnboarding() async {
    setState(() => _resettingOnboarding = true);
    try {
      await widget.storageService.resetOnboarding();
      widget.onResetOnboarding();
    } catch (e) {
      AppMessenger.show('Could not reset onboarding: $e');
    } finally {
      if (mounted) setState(() => _resettingOnboarding = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  bool get _canSaveProfile => _nameController.text.trim().isNotEmpty;

  Future<void> _saveProfile() async {
    if (!_canSaveProfile) return;
    final ageText = _ageController.text.trim();
    final occupation = _occupationController.text.trim();
    final updated = widget.profile.copyWith(
      name: _nameController.text.trim(),
      age: int.tryParse(ageText),
      clearAge: ageText.isEmpty,
      occupation: occupation,
      clearOccupation: occupation.isEmpty,
      avatar: _selectedAvatar,
      clearAvatar: _selectedAvatar == null,
    );

    setState(() => _savingProfile = true);
    try {
      await widget.storageService.saveUserProfile(updated);
      widget.onProfileUpdated(updated);
      if (!mounted) return;
      AppMessenger.show('Profile saved.');
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
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
          SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(dialogContext).colorScheme.primary,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onPrimary,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor:
                        Theme.of(dialogContext).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Reset'),
                ),
              ],
            ),
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
    final width = MediaQuery.sizeOf(context).width;
    final hPad = (width * 0.045).clamp(16.0, 28.0);

    return Scaffold(
      appBar: AppBar(title: const PageTitle('Settings')),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, navBarClearance),
          children: [
            const _SectionLabel('Appearance'),
            const SizedBox(height: 8),
            SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(
                  value: AppThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_rounded),
                ),
                ButtonSegment(
                  value: AppThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_rounded),
                ),
                ButtonSegment(
                  value: AppThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_rounded),
                ),
              ],
              selected: {widget.themeMode},
              onSelectionChanged: (selection) =>
                  widget.onSelectThemeMode(selection.first),
            ),
            const SizedBox(height: 32),
            const _SectionLabel('Profile'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Avatar', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    // Local stock avatars only (PRD v2 §11) — no upload,
                    // just a small fixed set to pick from. Tapping the
                    // already-selected one clears it back to the generic
                    // placeholder rather than being a no-op, so there's a
                    // way out without hunting for a separate "remove"
                    // control.
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final avatar in Avatar.values)
                          GestureDetector(
                            onTap: () => setState(() {
                              _selectedAvatar =
                                  _selectedAvatar == avatar ? null : avatar;
                            }),
                            child: AvatarTile(
                              avatar: avatar,
                              selected: _selectedAvatar == avatar,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Name', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(hintText: 'Your name'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Age (optional)',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Age'),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Occupation (optional)',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _occupationController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration:
                          const InputDecoration(hintText: 'Occupation'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _canSaveProfile && !_savingProfile
                            ? _saveProfile
                            : null,
                        child: Text(_savingProfile ? 'Saving…' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const _SectionLabel('Data'),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reset progress',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Clears practice history and weak spots. Your name, '
                      'goal, and theme stay as they are.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: colorScheme.error,
                          side: BorderSide(color: colorScheme.error),
                        ),
                        onPressed: _resetting ? null : _confirmResetData,
                        child: Text(
                          _resetting ? 'Resetting…' : 'Reset progress data',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              const _SectionLabel('Developer'),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Entitlement override',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Debug builds only. Lets you preview Topic '
                        "Practice locked or unlocked without a real "
                        'subscription. Never has any effect in a release '
                        'build.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<_DebugAccessChoice>(
                        segments: const [
                          ButtonSegment(
                            value: _DebugAccessChoice.real,
                            label: Text('Real'),
                          ),
                          ButtonSegment(
                            value: _DebugAccessChoice.free,
                            label: Text('Free'),
                          ),
                          ButtonSegment(
                            value: _DebugAccessChoice.full,
                            label: Text('Full access'),
                          ),
                        ],
                        selected: {_debugAccessChoice},
                        onSelectionChanged: (selection) =>
                            _setDebugAccessChoice(selection.first),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'First-launch flow',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Clears the saved profile so the app shows Welcome/'
                        'Onboarding again — the only way to re-see the '
                        'Day-0 flow without reinstalling.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              _resettingOnboarding ? null : _resetOnboarding,
                          child: Text(
                            _resettingOnboarding
                                ? 'Resetting…'
                                : 'Reset first-launch state',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
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
