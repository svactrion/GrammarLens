import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';

import '../models/app_theme_mode.dart';
import '../models/app_text_size.dart';
import '../models/avatar.dart';
import '../models/monthly_medal.dart';
import '../models/user_profile.dart';
import '../models/welcome_badge.dart';
import '../services/analytics_service.dart';
import '../services/medal_finalization.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_messenger.dart';
import '../utils/debug_sample_collection.dart';
import '../utils/debug_tools.dart';
import '../widgets/app_segmented_button.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/section_title.dart';
import '../widgets/monthly_medal_collection.dart';
import 'avatar_picker_screen.dart';
import 'credits_screen.dart';
import 'data_screen.dart';
import 'theme_preview_screen.dart';
import 'debug_panel_screen.dart';
import '../theme.dart';

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

/// PRD v2 §4 — avatar, name edit, monthly medals, theme, text size and data
/// reset, in that order. Learning goal isn't editable here: nothing in scope needs it to
/// change, and adding a second place to set it risks drifting from
/// onboarding's copy.
class SettingsScreen extends StatefulWidget {
  final bool active;
  final AppThemeMode themeMode;
  final void Function(AppThemeMode mode) onSelectThemeMode;
  final AppTextSize textSize;
  final ValueChanged<AppTextSize> onSelectTextSize;
  final UserProfile profile;
  final StorageService storageService;
  final ValueChanged<UserProfile> onProfileUpdated;
  final SubscriptionService subscriptionService;
  final AnalyticsService analyticsService;

  /// Debug-only: called after the profile is cleared in storage, so the
  /// app can drop back to the Welcome/Onboarding flow (app.dart sets its
  /// `_profile` back to null) without an app restart. Only ever invoked
  /// from the "Developer" section below, itself `if (kDebugMode)`-gated.
  final VoidCallback onResetOnboarding;

  /// N27: the debug panel's "Reset local data": deletes the local database
  /// and puts the app back at its first launch. Reached only from the
  /// panel, which a release build does not have.
  final Future<void> Function()? onResetLocalData;

  /// The "Debug" row (N27).
  static const debugRowKey = ValueKey('settings_debug_row');

  /// The identity card, the saved name shown in it, and the medal count.
  static const identityCardKey = ValueKey('settings_identity_card');
  static const nameKey = ValueKey('settings_name');
  static const earnedCountKey = ValueKey('settings_medals_earned');

  SettingsScreen({
    super.key,
    required this.active,
    required this.themeMode,
    required this.onSelectThemeMode,
    required this.textSize,
    required this.onSelectTextSize,
    required this.profile,
    required this.storageService,
    required this.onProfileUpdated,
    required this.onResetOnboarding,
    this.onResetLocalData,
    SubscriptionService? subscriptionService,
    AnalyticsService? analyticsService,
  })  : subscriptionService = subscriptionService ?? SubscriptionService(),
        analyticsService = analyticsService ?? AnalyticsService();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;
  bool _savingProfile = false;

  /// N8: the name row is open for editing (the field with Save / Cancel).
  /// UI state only; the name is stored by Save, as before.
  bool _editingName = false;
  final _editButtonFocus = FocusNode(debugLabel: 'Edit name');
  bool _resettingOnboarding = false;
  late _DebugAccessChoice _debugAccessChoice;
  late bool _previewPaywallPricing;
  WelcomeBadge? _welcomeBadge;
  MonthlyMedalProgress? _medalProgress;
  List<MonthlyMedalResult> _medalResults = const [];
  Map<(int, int), String> _medalThemeIds = const {};
  bool _medalsLoading = true;
  bool _medalsFailed = false;

  /// Guards against `_loadMedals` calls overlapping and resolving out of
  /// order (mount + a fast repeated tab re-entry, both possible per
  /// `didUpdateWidget` below): incremented at the start of every call, and
  /// checked again after both awaits below finish, so a call whose
  /// generation is no longer current discards its own result instead of
  /// clobbering a newer call's — whichever call *started* last always
  /// wins, regardless of which one *finishes* last.
  int _medalsGeneration = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    // Reads the already-loaded in-memory override (app.dart applies
    // whatever was persisted at app startup — see its own
    // _loadDebugAccessOverride) rather than re-reading storage here, so
    // this always reflects exactly what SubscriptionService is actually
    // enforcing right now, never a stale/independent copy of it.
    _debugAccessChoice = _DebugAccessChoice.fromOverride(
      widget.subscriptionService.debugAccessOverride,
    );
    // Session-only by design (PRD ask: never written to persistent
    // storage) — reads whatever SubscriptionService currently holds in
    // memory rather than a separate stored preference, so this can never
    // disagree with what PremiumScreen would actually see right now.
    _previewPaywallPricing =
        widget.subscriptionService.debugFixtureOffering != null;
    unawaited(_loadMedals());
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.active && widget.active) ||
        oldWidget.storageService != widget.storageService) {
      unawaited(_loadMedals());
    }
  }

  /// `profile_medals_viewed` (docs/analytics-plan.md E5). Profile is built at
  /// launch inside the tab stack even while another tab is showing, so a load
  /// only counts as a view when this tab is the active one. The once-per-
  /// session limit lives in [AnalyticsService.profileMedalsViewed].
  void _reportProfileViewed() {
    if (!widget.active) return;
    unawaited(widget.analyticsService.profileMedalsViewed(
      finalizedMonths: _medalResults.length,
      medalsEarned: _medalResults.where((r) => r.tier != null).length,
      welcomeEarned: _welcomeBadge != null,
    ));
  }

  Future<void> _loadMedals() async {
    final generation = ++_medalsGeneration;
    // P6: the debug panel's sample collection, instead of storage. Only the
    // running month's progress is read (so it matches Home); nothing is
    // finalized or written, and no view is reported.
    if (DebugSampleCollection.enabled) {
      MonthlyMedalProgress? progress;
      try {
        progress = await widget.storageService.getCurrentMonthlyMedalProgress();
      } catch (_) {
        progress = null;
      }
      if (!mounted || generation != _medalsGeneration) return;
      final sample = DebugSampleCollection.current(progress: progress);
      setState(() {
        _medalThemeIds = sample.themeIds;
        _medalProgress = sample.progress;
        _medalResults = sample.results;
        _welcomeBadge = sample.welcomeBadge;
        _medalsLoading = false;
        _medalsFailed = false;
      });
      return;
    }
    if (mounted) {
      setState(() {
        _medalsLoading = true;
        _medalsFailed = false;
      });
    }
    try {
      await finalizePastMedalMonthsAndReport(
        storageService: widget.storageService,
        analyticsService: widget.analyticsService,
      );
      // No lazy backfill call here for the Welcome badge, deliberately —
      // its one and only retroactive award happens once, inside the v18
      // migration (docs/prd-gamification.md §M6.5). This is a plain read
      // of whatever is already on record, the same as the monthly medal
      // reads alongside it.
      final values = await Future.wait([
        widget.storageService.getCurrentMonthlyMedalProgress(),
        widget.storageService.getMonthlyMedalResults(),
        widget.storageService.getWelcomeBadge(),
      ]);
      // Each month's theme for its medals (N17). Not part of the reads
      // above: a theme read that fails draws Green Slope's medals rather
      // than hiding the collection.
      Map<(int, int), String> themeIds;
      try {
        themeIds = await widget.storageService.getClimbMonthThemes();
      } catch (_) {
        themeIds = const {};
      }
      if (!mounted || generation != _medalsGeneration) return;
      setState(() {
        _medalThemeIds = themeIds;
        _medalProgress = values[0] as MonthlyMedalProgress;
        _medalResults = values[1] as List<MonthlyMedalResult>;
        _welcomeBadge = values[2] as WelcomeBadge?;
        _medalsLoading = false;
      });
      _reportProfileViewed();
    } catch (_) {
      if (!mounted || generation != _medalsGeneration) return;
      setState(() {
        _medalsLoading = false;
        _medalsFailed = true;
      });
    }
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

  /// Debug-only, session-only (no `StorageService` write, unlike the
  /// entitlement override above) — see
  /// `SubscriptionService.setDebugFixtureOffering`'s own doc comment for
  /// why this substitutes a fixture rather than a real RevenueCat call.
  void _setPreviewPaywallPricing(bool enabled) {
    setState(() => _previewPaywallPricing = enabled);
    widget.subscriptionService.setDebugFixtureOffering(enabled: enabled);
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
    _editButtonFocus.dispose();
    super.dispose();
  }

  /// N8: opens the name for editing, starting from the saved name.
  void _startEditingName() {
    _nameController.text = widget.profile.name;
    setState(() => _editingName = true);
  }

  /// N8: closes the editor and puts the text back to the saved name; the
  /// focus returns to Edit.
  void _cancelEditingName() {
    _nameController.text = widget.profile.name;
    setState(() => _editingName = false);
    _editButtonFocus.requestFocus();
  }

  bool get _canSaveProfile => _nameController.text.trim().isNotEmpty;

  Future<void> _saveProfile() async {
    if (!_canSaveProfile) return;
    // Avatar is deliberately not part of this form any more — the
    // carousel picker autosaves on its own (see _changeAvatar below), so
    // this Save button only ever touches the fields still shown above it.
    final updated = widget.profile.copyWith(
      name: _nameController.text.trim(),
    );

    setState(() => _savingProfile = true);
    try {
      await widget.storageService.saveUserProfile(updated);
      widget.onProfileUpdated(updated);
      if (!mounted) return;
      setState(() => _editingName = false);
      AppMessenger.show('Name saved');
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show('Could not save profile: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  /// The picker's own silent autosave (debounced inside
  /// `AvatarPickerScreen` itself) — deliberately no snackbar, no
  /// `_savingProfile` flag: this is a background update, not a user
  /// action with its own explicit feedback loop the way the profile
  /// form's Save button has. A write failure is swallowed for the same
  /// reason it's silent on success — there's no in-flow place to surface
  /// it from a screen the user has likely already left.
  Future<void> _changeAvatar(Avatar avatar) async {
    final updated = widget.profile.copyWith(avatar: avatar);
    try {
      await widget.storageService.saveUserProfile(updated);
      widget.onProfileUpdated(updated);
    } catch (_) {
      // Silent by design — see the doc comment above.
    }
  }

  void _openAvatarPicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvatarPickerScreen(
          currentAvatar: widget.profile.avatar ?? _fallbackAvatar,
          onAvatarChanged: _changeAvatar,
          heroTag: avatarHeroTag,
        ),
      ),
    );
  }

  // Computed once per Settings visit (not per rebuild) so a legacy
  // profile with no avatar yet doesn't show a different random character
  // on every unrelated rebuild (e.g. a theme change) before the user ever
  // opens the picker — only real installs from before onboarding started
  // assigning one automatically ever hit this at all.
  late final Avatar _fallbackAvatar = Avatar.random();

  void _openCredits() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreditsScreen()),
    );
  }

  void _openData() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DataScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
        ),
      ),
    );
  }

  /// Whether the theme segments keep their icons at [width]: only while
  /// the longest label ("System", in the selected weight) fits beside its
  /// icon in a third of the control. At 320 pt with Large text inside the
  /// Appearance card it does not, and a label would break mid-word
  /// ("Syst-em"); the labels alone carry the choice there.
  static bool _themeIconsFit(BuildContext context, double width) {
    final style =
        Theme.of(context).textTheme.labelMedium?.withWeight(FontWeight.w800);
    final label = TextPainter(
      text: TextSpan(text: 'System', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    // Per segment (a third of the control): Material's 12 pt padding each
    // side, the 18 pt icon and its 8 pt gap.
    final segment = width / 3;
    final fits = label.width + 18 + 8 + 24 <= segment;
    label.dispose();
    return fits;
  }

  /// The page header (1.2.0 mockup, "Profile"): the title and its line in
  /// the page, so they scroll with it, as on Review.
  Widget _header(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            'Profile',
            style: theme.textTheme.displaySmall
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Your journey, your way.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final medals = MonthlyMedalCollection(
      welcomeBadge: _welcomeBadge,
      currentProgress: _medalProgress,
      results: _medalResults,
      themeIds: _medalThemeIds,
    );
    final progress = _medalProgress;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: BrandScaffold(
        // The status bar's height only: the header is in the page.
        appBar: AppBar(
          toolbarHeight: 0,
          automaticallyImplyLeading: false,
          scrolledUnderElevation: 0,
        ),
        isTabRoot: true,
        children: [
          _header(theme),
          const SizedBox(height: 20),
          _IdentityCard(
            avatar: Hero(
              tag: avatarHeroTag,
              child: AvatarTile(
                avatar: widget.profile.avatar ?? _fallbackAvatar,
                radius: _IdentityCard.heroSize / 2,
              ),
            ),
            onChangeAvatar: _openAvatarPicker,
            name: widget.profile.name,
            editing: _editingName,
            controller: _nameController,
            editButtonFocus: _editButtonFocus,
            saving: _savingProfile,
            canSave: _canSaveProfile,
            onEdit: _startEditingName,
            onChanged: () => setState(() {}),
            onSave: _saveProfile,
            onCancel: _cancelEditingName,
          ),
          const SizedBox(height: 23),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(child: SectionTitle('Medal collection')),
              if (!_medalsLoading && !_medalsFailed) ...[
                const SizedBox(width: 10),
                Text(
                  '${medals.earnedCount} earned',
                  key: SettingsScreen.earnedCountKey,
                  style: theme.textTheme.labelMedium
                      ?.withWeight(FontWeight.w400)
                      .copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (_medalsLoading)
            const Center(child: CircularProgressIndicator())
          else if (_medalsFailed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _loadMedals,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry medal history'),
              ),
            )
          else ...[
            medals,
            if (progress != null) ...[
              const SizedBox(height: 9),
              MonthlyProgressCard(
                progress: progress,
                theme: MonthlyMedalCollection.themeFor(
                    progress.year, progress.month, _medalThemeIds,
                    running: true),
              ),
            ],
          ],
          const SizedBox(height: 23),
          const SectionTitle('Appearance'),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SettingLabel(
                      icon: Icons.palette_outlined, text: 'Theme'),
                  const SizedBox(height: 9),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final icons =
                          _themeIconsFit(context, constraints.maxWidth);
                      return AppSegmentedButton<AppThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: AppThemeMode.system,
                            label: const Text('System'),
                            icon: icons
                                ? const Icon(Icons.brightness_auto_rounded)
                                : null,
                          ),
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: const Text('Light'),
                            icon: icons
                                ? const Icon(Icons.light_mode_rounded)
                                : null,
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: const Text('Dark'),
                            icon: icons
                                ? const Icon(Icons.dark_mode_rounded)
                                : null,
                          ),
                        ],
                        selected: {widget.themeMode},
                        onSelectionChanged: (selection) =>
                            widget.onSelectThemeMode(selection.first),
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  const _SettingLabel(
                      icon: Icons.text_fields_rounded, text: 'Text size'),
                  const SizedBox(height: 9),
                  AppSegmentedButton<AppTextSize>(
                    segments: const [
                      ButtonSegment(
                          value: AppTextSize.small, label: Text('Small')),
                      ButtonSegment(
                          value: AppTextSize.medium, label: Text('Medium')),
                      ButtonSegment(
                          value: AppTextSize.large, label: Text('Large')),
                    ],
                    selected: {widget.textSize},
                    onSelectionChanged: (selection) =>
                        widget.onSelectTextSize(selection.first),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'A little practice, every day.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 23),
          const SectionTitle('App information'),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavRow.icon(
                  icon: Icons.storage_rounded,
                  label: 'Data',
                  onTap: _openData,
                ),
                Divider(
                    height: 1, thickness: 1, color: colorScheme.outlineVariant),
                _NavRow.icon(
                  icon: Icons.info_outline_rounded,
                  label: 'Credits',
                  onTap: _openCredits,
                ),
              ],
            ),
          ),
          if (kDebugMode && DebugTools.enabledForTesting) ...[
            const SizedBox(height: 32),
            const SectionTitle('Developer'),
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
                          ?.withWeight(FontWeight.w700),
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
                    AppSegmentedButton<_DebugAccessChoice>(
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
                          ?.withWeight(FontWeight.w700),
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
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Preview paywall pricing',
                      style: theme.textTheme.titleSmall
                          ?.withWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Debug builds only, session-only (never saved). Shows '
                      "Premium's plan cards with fixture prices "
                      '(PRD v2 §13.2) since no App Store Connect product '
                      'exists yet. Never has any effect in a release build.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Preview pricing'),
                      value: _previewPaywallPricing,
                      onChanged: _setPreviewPaywallPricing,
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
                      'Theme preview',
                      style: theme.textTheme.titleSmall
                          ?.withWeight(FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Every color role, semantic result color, and core '
                      'component in one scroll — for checking a token '
                      'change before it ships.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ThemePreviewScreen(),
                          ),
                        ),
                        child: const Text('Open theme preview'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // N27: the debug panel, in debug and profile builds; a release
          // build compiles it out (kReleaseMode is a constant there).
          if (!kReleaseMode && DebugTools.enabledForTesting) ...[
            const SizedBox(height: 24),
            _NavRow.icon(
              key: SettingsScreen.debugRowKey,
              icon: Icons.bug_report_outlined,
              label: 'Debug',
              // The panel can switch the sample collection (P6): the
              // shelf is read again when it closes.
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                builder: (_) => DebugPanelScreen(
                    onResetLocalData: widget.onResetLocalData ?? () async {}),
              ))
                  .then((_) {
                if (mounted) unawaited(_loadMedals());
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// A link row that opens another screen (the mockup's "App information"
/// rows): a 34 pt icon tile in the link colour, a label and a trailing
/// chevron, at least 64 pt tall.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavRow.icon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: scheme.secondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelLarge
                      ?.copyWith(color: scheme.onSurface),
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// A setting's label with its icon ("Theme", "Text size").
class _SettingLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SettingLabel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall
                ?.withWeight(FontWeight.w800)
                .copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

/// The identity card (1.2.0 mockup): "Your companion", the hero large and
/// centred (158 pt), "Change your avatar"; under a rule, "Your name", the
/// name and Edit. Edit opens the name in place (N8): the field, Save and
/// Cancel. Save is off while the name is empty or only spaces; Cancel puts
/// the saved name back. The hero ([avatar]) carries the `Hero` the picker
/// flies to and from.
class _IdentityCard extends StatelessWidget {
  final Widget avatar;
  final VoidCallback onChangeAvatar;
  final String name;
  final bool editing;
  final TextEditingController controller;
  final FocusNode editButtonFocus;
  final bool saving;
  final bool canSave;
  final VoidCallback onEdit;
  final VoidCallback onChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const _IdentityCard({
    required this.avatar,
    required this.onChangeAvatar,
    required this.name,
    required this.editing,
    required this.controller,
    required this.editButtonFocus,
    required this.saving,
    required this.canSave,
    required this.onEdit,
    required this.onChanged,
    required this.onSave,
    required this.onCancel,
  });

  /// The hero's box (the brief: 158 × 158).
  static const heroSize = 158.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final link = theme.textTheme.labelLarge
        ?.withWeight(FontWeight.w800)
        .copyWith(color: scheme.secondary);
    final caption = theme.textTheme.labelSmall
        ?.withWeight(FontWeight.w400)
        .copyWith(color: scheme.onSurfaceVariant);

    return Card(
      key: SettingsScreen.identityCardKey,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 13),
            child: Column(
              children: [
                Text(
                  'Your companion',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: scheme.onSurface, letterSpacing: -.2),
                ),
                const SizedBox(height: 3),
                // The picture itself opens the picker too; the labelled
                // control for assistive technology is the button below.
                ExcludeSemantics(
                  child: GestureDetector(
                    onTap: onChangeAvatar,
                    child: SizedBox.square(dimension: heroSize, child: avatar),
                  ),
                ),
                TextButton(
                  onPressed: onChangeAvatar,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.secondary,
                    minimumSize: const Size(44, 44),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text('Change your avatar',
                            textAlign: TextAlign.center, style: link),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.chevron_right_rounded, size: 19),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          if (!editing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your name', style: caption),
                        const SizedBox(height: 2),
                        Text(
                          name,
                          key: SettingsScreen.nameKey,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    focusNode: editButtonFocus,
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.secondary,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text('Edit',
                        style: theme.textTheme.bodySmall
                            ?.withWeight(FontWeight.w800)
                            .copyWith(color: scheme.secondary)),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 14, 17, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your name',
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurface)),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          autofocus: true,
                          // When the keyboard opens the list scrolls the
                          // field into view; the extra bottom room brings
                          // the Cancel row under it into view too.
                          scrollPadding:
                              const EdgeInsets.fromLTRB(20, 20, 20, 88),
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          decoration:
                              const InputDecoration(hintText: 'Your name'),
                          onChanged: (_) => onChanged(),
                          onSubmitted: (_) {
                            if (canSave && !saving) onSave();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        // The theme's buttons are full width; this one sits
                        // beside the field.
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(64, 48)),
                        onPressed: canSave && !saving ? onSave : null,
                        child: Text(saving ? 'Saving…' : 'Save'),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: saving ? null : onCancel,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.secondary,
                      minimumSize: const Size(44, 44),
                      padding: EdgeInsets.zero,
                    ),
                    child: Text('Cancel', style: link),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
