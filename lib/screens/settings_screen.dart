import 'package:flutter/material.dart';

import '../models/app_theme_mode.dart';
import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../utils/error_banner.dart';
import '../utils/page_title.dart';

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

  const SettingsScreen({
    super.key,
    required this.themeMode,
    required this.onSelectThemeMode,
    required this.profile,
    required this.storageService,
    required this.onProfileUpdated,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _ageController;
  late final TextEditingController _occupationController;
  bool _savingProfile = false;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _ageController =
        TextEditingController(text: widget.profile.age?.toString() ?? '');
    _occupationController =
        TextEditingController(text: widget.profile.occupation ?? '');
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
    );

    setState(() => _savingProfile = true);
    try {
      await widget.storageService.saveUserProfile(updated);
      widget.onProfileUpdated(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved.')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not save profile: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress reset.')),
      );
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Could not reset progress: $e');
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
          padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 20),
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
