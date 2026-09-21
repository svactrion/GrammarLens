import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
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
import '../utils/debug_tools.dart';
import '../utils/page_title.dart';
import '../widgets/app_segmented_button.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/monthly_medal_collection.dart';
import 'avatar_picker_screen.dart';
import 'credits_screen.dart';
import 'data_screen.dart';
import 'theme_preview_screen.dart';

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
  bool _resettingOnboarding = false;
  late _DebugAccessChoice _debugAccessChoice;
  late bool _previewPaywallPricing;
  WelcomeBadge? _welcomeBadge;
  MonthlyMedalProgress? _medalProgress;
  List<MonthlyMedalResult> _medalResults = const [];
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
      if (!mounted || generation != _medalsGeneration) return;
      setState(() {
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
    super.dispose();
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
      AppMessenger.show('Profile saved.');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: BrandScaffold(
        title: const PageTitle('Profile'),
        isTabRoot: true,
        children: [
          const _SectionLabel('Profile'),
          const SizedBox(height: 8),
          // No Card wrap (docs/design-audit.md, Batch 0 item 8): this
          // isn't a single tappable target the way Home's cards are, so
          // giving it the same card treatment implied a tap that does
          // nothing. Flush layout, like every other section here — the
          // section label plus this file's 32px section gap carries the
          // grouping instead of a container.
          Text('Avatar', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          // Local stock avatars only (PRD v2 §11) — no upload. Picking one
          // is a separate screen now (a swipeable carousel,
          // `AvatarPickerScreen`), not an inline grid here — this row is
          // just a preview of the current choice plus the way in. `Hero`
          // ties this tile to the picker's own centered avatar so leaving
          // that screen visibly flies the choice back here rather than
          // just popping.
          _NavRow(
            onTap: _openAvatarPicker,
            leading: Hero(
              tag: avatarHeroTag,
              child: AvatarTile(
                avatar: widget.profile.avatar ?? _fallbackAvatar,
                radius: 26,
              ),
            ),
            label: 'Change avatar',
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _canSaveProfile && !_savingProfile ? _saveProfile : null,
              child: Text(_savingProfile ? 'Saving…' : 'Save'),
            ),
          ),
          const SizedBox(height: 32),
          const _SectionLabel('Monthly medals'),
          const SizedBox(height: 8),
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
          else
            MonthlyMedalCollection(
              welcomeBadge: _welcomeBadge,
              currentProgress: _medalProgress,
              results: _medalResults,
            ),
          const SizedBox(height: 32),
          const _SectionLabel('Appearance'),
          const SizedBox(height: 8),
          AppSegmentedButton<AppThemeMode>(
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
          const SizedBox(height: 20),
          Text('Text size', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          AppSegmentedButton<AppTextSize>(
            segments: const [
              ButtonSegment(value: AppTextSize.small, label: Text('Small')),
              ButtonSegment(value: AppTextSize.medium, label: Text('Medium')),
              ButtonSegment(value: AppTextSize.large, label: Text('Large')),
            ],
            selected: {widget.textSize},
            onSelectionChanged: (selection) =>
                widget.onSelectTextSize(selection.first),
          ),
          const SizedBox(height: 32),
          _NavRow.icon(
            icon: Icons.storage_rounded,
            label: 'Data',
            onTap: _openData,
          ),
          _NavRow.icon(
            icon: Icons.info_outline_rounded,
            label: 'Credits',
            onTap: _openCredits,
          ),
          if (kDebugMode && DebugTools.enabledForTesting) ...[
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
                          ?.copyWith(fontWeight: FontWeight.w700),
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
                          ?.copyWith(fontWeight: FontWeight.w700),
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
        ],
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

/// A tappable row that opens another screen: [leading], a label and a
/// trailing chevron. The look of the avatar row above, shared with the other
/// rows here that open a screen of their own.
class _NavRow extends StatelessWidget {
  final Widget leading;
  final String label;
  final VoidCallback onTap;

  const _NavRow({
    required this.leading,
    required this.label,
    required this.onTap,
  });

  /// A row led by an [icon], centered in the same 52 pt box the avatar row's
  /// tile occupies so every label starts at the same x.
  _NavRow.icon({
    required IconData icon,
    required this.label,
    required this.onTap,
  }) : leading = SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, size: 28),
        );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
