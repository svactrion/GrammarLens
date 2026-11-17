import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;
import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../app_colors.dart';
import '../utils/haptics.dart';
import '../widgets/app_sheet.dart';
import '../widgets/companion_view.dart';
import '../widgets/medals_layer.dart';
import '../widgets/pressable_button.dart';
import '../widgets/profile_stage.dart';
import '../widgets/speech_bubble.dart';
import '../models/app_theme_mode.dart';
import '../models/app_text_size.dart';
import '../models/avatar.dart';
import '../models/monthly_medal.dart';
import '../models/user_profile.dart';
import '../models/welcome_badge.dart';
import '../services/analytics_service.dart';
import '../services/medal_finalization.dart';
import '../services/reminder_controller.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/app_links.dart';
import '../utils/app_messenger.dart';
import '../utils/debug_sample_collection.dart';
import '../utils/debug_tools.dart';
import '../widgets/app_segmented_button.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/legal_link.dart';
import '../widgets/section_title.dart';
import '../widgets/monthly_medal_collection.dart';
import 'avatar_picker_screen.dart';
import 'credits_screen.dart';
import 'data_screen.dart';
import 'notification_settings_screen.dart';
import 'language_picker_screen.dart';
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

  /// The interface-language choice (1.4.0 B3) and where a new one goes;
  /// the app root persists it and rebuilds in the new language.
  final AppLanguage language;
  final ValueChanged<AppLanguage>? onSelectLanguage;
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

  /// The reminder settings (N03); the screen makes its own when none is
  /// given.
  final ReminderController? reminders;

  /// The "Notifications" row (N03).
  static const notificationsRowKey = ValueKey('settings_notifications_row');

  /// The "Debug" row (N27).
  static const debugRowKey = ValueKey('settings_debug_row');

  /// App information's links to the hosted legal pages.
  static const privacyRowKey = ValueKey('settings_privacy_row');
  static const termsRowKey = ValueKey('settings_terms_row');
  static const languageRowKey = ValueKey('settings_language_row');

  /// The identity card, the saved name shown in it, and the medal count.
  static const identityCardKey = ValueKey('settings_identity_card');
  static const nameKey = ValueKey('settings_name');

  /// V23's medal card: the title, "See all" and the shelf.
  static const medalCardKey = ValueKey('settings_medal_card');
  static const seeAllMedalsKey = ValueKey('settings_medals_see_all');
  static const nameFieldKey = ValueKey('settings_name_field');
  static const saveNameKey = ValueKey('settings_save_name');

  SettingsScreen({
    super.key,
    required this.active,
    required this.themeMode,
    required this.onSelectThemeMode,
    required this.textSize,
    required this.onSelectTextSize,
    this.language = AppLanguage.system,
    this.onSelectLanguage,
    required this.profile,
    required this.storageService,
    required this.onProfileUpdated,
    required this.onResetOnboarding,
    this.onResetLocalData,
    this.reminders,
    SubscriptionService? subscriptionService,
    AnalyticsService? analyticsService,
  })  : subscriptionService = subscriptionService ?? SubscriptionService(),
        analyticsService = analyticsService ?? AnalyticsService();

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

  /// N8: the name row is open for editing (the field with Save / Cancel).
  /// UI state only; the name is stored by Save, as before.
  bool _resettingOnboarding = false;
  late _DebugAccessChoice _debugAccessChoice;
  late bool _previewPaywallPricing;
  WelcomeBadge? _welcomeBadge;
  MonthlyMedalProgress? _medalProgress;
  List<MonthlyMedalResult> _medalResults = const [];
  Map<(int, int), String> _medalThemeIds = const {};
  bool _medalsLoading = true;
  bool _medalsFailed = false;

  /// The weak spots saved (V23's third tile); null until read.
  int? _weakSpotCount;

  /// The first Daily Test's completion (V23's "since"); null until read,
  /// with none, or if the read fails.
  DateTime? _firstCompletion;

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

  Future<void> _loadWeakSpotCount() async {
    try {
      final stats = await widget.storageService.getTopicStats();
      final count =
          stats.values.fold<int>(0, (sum, s) => sum + s.weakSpotCount);
      if (mounted) setState(() => _weakSpotCount = count);
    } catch (_) {}
  }

  Future<void> _loadFirstCompletion() async {
    try {
      final first = await widget.storageService.getFirstDailyTestCompletion();
      if (mounted) setState(() => _firstCompletion = first);
    } catch (_) {}
  }

  Future<void> _loadMedals() async {
    unawaited(_loadWeakSpotCount());
    unawaited(_loadFirstCompletion());
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
      // l10n-guard: debug builds only (the Developer section)
      AppMessenger.show('Could not reset onboarding: $e');
    } finally {
      if (mounted) setState(() => _resettingOnboarding = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    if (widget.reminders == null) _reminders.dispose();
    super.dispose();
  }

  /// N8: opens the name for editing, starting from the saved name.
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

  void _openLanguagePicker() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LanguagePickerScreen(
          current: widget.language,
          onSelected: (language) => widget.onSelectLanguage?.call(language),
        ),
      ),
    );
  }

  late final ReminderController _reminders =
      widget.reminders ?? ReminderController(storage: widget.storageService);

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationSettingsScreen(
          controller: _reminders,
          hero: widget.profile.avatar ?? Avatar.values.first,
          subscriptionService: widget.subscriptionService,
        ),
      ),
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
  /// the longest label ("System" in English, in the selected weight; the
  /// longest of the three in any language) fits beside its icon in a third
  /// of the control. At 320 pt with Large text inside the
  /// Appearance card it does not, and a label would break mid-word
  /// ("Syst-em"); the labels alone carry the choice there.
  static bool _themeIconsFit(BuildContext context, double width) {
    final style =
        Theme.of(context).textTheme.labelMedium?.withWeight(FontWeight.w800);
    final l10n = context.l10n;
    var widest = 0.0;
    for (final text in [
      l10n.settingsThemeSystem,
      l10n.settingsThemeLight,
      l10n.settingsThemeDark,
    ]) {
      final label = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      if (label.width > widest) widest = label.width;
      label.dispose();
    }
    // Per segment (a third of the control): Material's 12 pt padding each
    // side, the 18 pt icon and its 8 pt gap.
    final segment = width / 3;
    return widest + 18 + 8 + 24 <= segment;
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
            context.l10n.settingsTitle,
            style: theme.textTheme.displaySmall
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          context.l10n.settingsSubtitle,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  /// PF04: the name in a sheet above the keyboard; the companion asks.
  Future<void> _openNameSheet() async {
    HapticMap.light();
    _nameController.text = widget.profile.name;
    final name = await showAppSheet<String>(
      context: context,
      builder: (sheetContext) => _NameSheet(
        hero: widget.profile.avatar ?? _fallbackAvatar,
        controller: _nameController,
      ),
    );
    if (name == null || !mounted) return;
    await _saveName(name, undoable: true);
  }

  /// Saves [name]; "Name saved" with Undo (SY02) puts the previous one
  /// back the same way.
  Future<void> _saveName(String name, {required bool undoable}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == widget.profile.name) return;
    final previous = widget.profile.name;
    final updated = widget.profile.copyWith(name: trimmed);
    try {
      await widget.storageService.saveUserProfile(updated);
      widget.onProfileUpdated(updated);
      if (!mounted) return;
      AppMessenger.show(
        context.l10n.settingsNameSaved,
        kind: MessageKind.success,
        actionLabel: undoable ? context.l10n.commonUndo : null,
        onAction: undoable ? () => _saveName(previous, undoable: false) : null,
      );
    } catch (e) {
      if (!mounted) return;
      AppMessenger.show(context.l10n.settingsProfileSaveFailed('$e'),
          kind: MessageKind.error);
    }
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
          // V23: the companion's stage, the ribbon with the name and the
          // pencil (→ PF04), the three stat tiles.
          KeyedSubtree(
            key: SettingsScreen.identityCardKey,
            child: ProfileStage(
              hero: widget.profile.avatar ?? _fallbackAvatar,
              name: widget.profile.name,
              onChange: _openAvatarPicker,
              onEditName: _openNameSheet,
              points: progress?.score,
              step: progress?.activeDays,
              weakSpots: _weakSpotCount,
              since: _firstCompletion,
            ),
          ),
          const SizedBox(height: 23),
          // V23: "Medal collection" and "See all" (→ PF02) on a card, the
          // shelf with at most three medals under them.
          Container(
            key: SettingsScreen.medalCardKey,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: lipCard(AppColors.of(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Expanded(
                      child:
                          SectionTitle(context.l10n.settingsMedalCollection)),
                  if (!_medalsLoading && !_medalsFailed)
                    TextButton(
                      key: SettingsScreen.seeAllMedalsKey,
                      onPressed: () => showAllMedals(context, medals),
                      child: Text(context.l10n.profileSeeAll),
                    ),
                ]),
                const SizedBox(height: 10),
                if (_medalsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_medalsFailed)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _loadMedals,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(context.l10n.settingsMedalsRetry),
                    ),
                  )
                else
                  medals,
              ],
            ),
          ),
          if (!_medalsLoading && !_medalsFailed && progress != null) ...[
            const SizedBox(height: 14),
            MonthlyProgressCard(
              progress: progress,
              theme: MonthlyMedalCollection.themeFor(
                  progress.year, progress.month, _medalThemeIds,
                  running: true),
            ),
          ],
          const SizedBox(height: 23),
          SectionTitle(context.l10n.settingsAppearance),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SettingLabel(
                      icon: Icons.palette_outlined,
                      text: context.l10n.settingsThemeLabel),
                  const SizedBox(height: 9),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final icons =
                          _themeIconsFit(context, constraints.maxWidth);
                      return AppSegmentedButton<AppThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: AppThemeMode.system,
                            label: Text(context.l10n.settingsThemeSystem),
                            icon: icons
                                ? const Icon(Icons.brightness_auto_rounded)
                                : null,
                          ),
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: Text(context.l10n.settingsThemeLight),
                            icon: icons
                                ? const Icon(Icons.light_mode_rounded)
                                : null,
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: Text(context.l10n.settingsThemeDark),
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
                  _SettingLabel(
                      icon: Icons.text_fields_rounded,
                      text: context.l10n.settingsTextSizeLabel),
                  const SizedBox(height: 9),
                  AppSegmentedButton<AppTextSize>(
                    segments: [
                      ButtonSegment(
                          value: AppTextSize.small,
                          label: Text(context.l10n.settingsTextSizeSmall)),
                      ButtonSegment(
                          value: AppTextSize.medium,
                          label: Text(context.l10n.settingsTextSizeMedium)),
                      ButtonSegment(
                          value: AppTextSize.large,
                          label: Text(context.l10n.settingsTextSizeLarge)),
                    ],
                    selected: {widget.textSize},
                    onSelectionChanged: (selection) =>
                        widget.onSelectTextSize(selection.first),
                  ),
                  const SizedBox(height: 18),
                  _SettingLabel(
                      icon: Icons.language_rounded,
                      text: context.l10n.settingsLanguageLabel),
                  const SizedBox(height: 9),
                  _LanguageField(
                    key: SettingsScreen.languageRowKey,
                    value: widget.language == AppLanguage.system
                        ? context.l10n.settingsLanguageSystemDefault
                        : widget.language.endonym,
                    label: context.l10n.settingsLanguageLabel,
                    onTap: _openLanguagePicker,
                  ),
                  const SizedBox(height: 13),
                  Text(
                    context.l10n.settingsAppearanceFooter,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 23),
          SectionTitle(context.l10n.settingsAppInformation),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _NavRow.icon(
                  key: SettingsScreen.notificationsRowKey,
                  icon: Icons.notifications_none_rounded,
                  label: context.l10n.notifTitle,
                  onTap: _openNotifications,
                ),
                Divider(
                    height: 1, thickness: 1, color: colorScheme.outlineVariant),
                _NavRow.icon(
                  icon: Icons.storage_rounded,
                  label: context.l10n.settingsDataRow,
                  onTap: _openData,
                ),
                Divider(
                    height: 1, thickness: 1, color: colorScheme.outlineVariant),
                // App Review 5.1.1(i): the privacy policy reachable from
                // inside the app at any time, not only from the paywall and
                // the AI permission screen; the terms beside it, as on the
                // paywall.
                _NavRow.icon(
                  key: SettingsScreen.privacyRowKey,
                  icon: Icons.privacy_tip_outlined,
                  label: context.l10n.commonPrivacyPolicy,
                  opensBrowser: true,
                  onTap: () => openLegalLink(
                      label: context.l10n.commonPrivacyPolicy,
                      url: AppLinks.privacyPolicyUrl,
                      failedMessage: context.l10n
                          .legalLinkFailed(context.l10n.commonPrivacyPolicy)),
                ),
                Divider(
                    height: 1, thickness: 1, color: colorScheme.outlineVariant),
                _NavRow.icon(
                  key: SettingsScreen.termsRowKey,
                  icon: Icons.description_outlined,
                  label: context.l10n.commonTermsOfService,
                  opensBrowser: true,
                  onTap: () => openLegalLink(
                      label: context.l10n.commonTermsOfService,
                      url: AppLinks.termsUrl,
                      failedMessage: context.l10n
                          .legalLinkFailed(context.l10n.commonTermsOfService)),
                ),
                Divider(
                    height: 1, thickness: 1, color: colorScheme.outlineVariant),
                _NavRow.icon(
                  icon: Icons.info_outline_rounded,
                  label: context.l10n.settingsCreditsRow,
                  onTap: _openCredits,
                ),
              ],
            ),
          ),
          // l10n-guard-begin: debug builds only, never translated
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
              label: 'Debug', // l10n-guard-end
              // The panel can switch the sample collection (P6): the
              // shelf is read again when it closes.
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(
                builder: (_) => DebugPanelScreen(
                  onResetLocalData: widget.onResetLocalData ?? () async {},
                  storageService: widget.storageService,
                  analyticsService: widget.analyticsService,
                  subscriptionService: widget.subscriptionService,
                ),
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
/// chevron, at least 64 pt tall. A row that leaves the app for the browser
/// ([opensBrowser]) ends in an "open in new" icon instead of the chevron.
class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool opensBrowser;

  const _NavRow.icon({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.opensBrowser = false,
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
              Icon(
                  opensBrowser
                      ? Icons.open_in_new_rounded
                      : Icons.chevron_right_rounded,
                  size: opensBrowser ? 18 : 20,
                  color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// The interface-language choice in the Appearance card (1.4.0 B3): the
/// current value on the segmented buttons' surface, height and radius
/// ([AppSegmentedButton]), with a chevron; a tap opens the picker.
class _LanguageField extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback onTap;

  const _LanguageField({
    super.key,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      button: true,
      label: label,
      value: value,
      excludeSemantics: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppSegmentedButton.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: AppSegmentedButton.height),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.labelMedium
                          ?.withWeight(FontWeight.w800)
                          .copyWith(color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
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

/// PF04: the name sheet. The companion asks; Save (light haptic) pops the
/// trimmed name; the field starts with the current one.
class _NameSheet extends StatefulWidget {
  final Avatar hero;
  final TextEditingController controller;
  const _NameSheet({required this.hero, required this.controller});

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final canSave = widget.controller.text.trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            CompanionView(
                hero: widget.hero,
                mood: CompanionMood.think,
                size: 64,
                decorative: true),
            const SizedBox(width: 8),
            Expanded(
              child: SpeechBubble(
                text: l10n.onboardingNameQuestion,
                pointer: BubblePointer.start,
                compact: true,
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextField(
            key: SettingsScreen.nameFieldKey,
            controller: widget.controller,
            autofocus: true,
            maxLength: UserProfile.maxNameLength,
            buildCounter: (_,
                    {required currentLength, required isFocused, maxLength}) =>
                null,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(hintText: l10n.settingsNameLabel),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) {
              if (canSave) {
                Navigator.of(context).pop(widget.controller.text.trim());
              }
            },
          ),
          const SizedBox(height: 8),
          PressableButton(
            key: SettingsScreen.saveNameKey,
            label: l10n.commonSave,
            tone: ButtonTone.navy,
            haptic: ButtonHaptic.light,
            onPressed: canSave
                ? () => Navigator.of(context).pop(widget.controller.text.trim())
                : null,
          ),
          const SizedBox(height: 4),
          Text(l10n.onboardingNameNote,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: c.muted)),
        ],
      ),
    );
  }
}
