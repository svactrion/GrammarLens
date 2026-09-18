import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'models/app_theme_mode.dart';
import 'models/app_text_size.dart';
import 'models/avatar.dart';
import 'models/user_profile.dart';
import 'screens/avatar_picker_screen.dart';
import 'screens/first_launch_flow.dart';
import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'services/analytics_service.dart';
import 'services/claude_service.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'theme.dart';
import 'utils/app_messenger.dart';
import 'utils/loading_view.dart';
import 'widgets/floating_nav_shell.dart';

class GrammarLensApp extends StatefulWidget {
  const GrammarLensApp({super.key});

  @override
  State<GrammarLensApp> createState() => _GrammarLensAppState();
}

class _GrammarLensAppState extends State<GrammarLensApp> {
  final ClaudeService _claudeService = ClaudeService();
  final StorageService _storageService = StorageService();
  final AnalyticsService _analyticsService = AnalyticsService();
  // Shared explicitly with both HomeScreen and ReviewScreen (rather than
  // each defaulting to its own `SubscriptionService()`) so both go through
  // one instance at this level, matching how the other three services
  // above are already shared — `SubscriptionService`'s own entitlement/
  // override state is static regardless, but there's no reason for this
  // one to be the odd one out.
  final SubscriptionService _subscriptionService = SubscriptionService();
  int _tabIndex = 0;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppTextSize _textSize = AppTextSize.medium;

  // Null while loading and stays null until onboarding completes — that's
  // the app's whole "returning vs. first launch" signal (PRD v2 §4), no
  // separate flag. `_profileLoading` only exists to avoid a one-frame flash
  // of the onboarding flow before the local sqlite read resolves.
  UserProfile? _profile;
  bool _profileLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
    _loadTextSize();
    _loadProfile();
    if (kDebugMode) _loadDebugAccessOverride();
  }

  Future<void> _loadThemeMode() async {
    try {
      final mode = await _storageService.getThemeMode();
      if (mounted) setState(() => _themeMode = mode);
    } catch (_) {
      // No persisted preference to read (or storage unavailable) — keep
      // following the system theme.
    }
  }

  Future<void> _loadProfile() async {
    UserProfile? profile;
    try {
      profile = await _storageService.getUserProfile();
    } catch (_) {
      // Storage unavailable — fall through to onboarding rather than
      // blocking app launch entirely.
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _profileLoading = false;
      });
    }
  }

  Future<void> _loadTextSize() async {
    try {
      final size = await _storageService.getTextSize();
      if (mounted) setState(() => _textSize = size);
    } catch (_) {
      // Keep the readable medium default if storage is unavailable.
    }
  }

  /// Applies whatever debug entitlement override a developer set last
  /// session (Settings' "Developer" section) before any screen has a
  /// chance to check `SubscriptionService.hasFullAccess` — so Home's
  /// Topic Practice card reflects it immediately on launch, not only
  /// after Settings happens to be opened. Debug builds only; a no-op call
  /// either way since `SubscriptionService.setDebugAccessOverride` itself
  /// is release-gated (see docs/build-log.md).
  Future<void> _loadDebugAccessOverride() async {
    try {
      final override = await _storageService.getDebugAccessOverride();
      await _subscriptionService.setDebugAccessOverride(override);
    } catch (_) {
      // No persisted override (or storage unavailable) — leave unset.
    }
  }

  void _setThemeMode(AppThemeMode mode) {
    setState(() => _themeMode = mode);
    unawaited(_storageService.setThemeMode(mode).catchError((_) {}));
  }

  void _setTextSize(AppTextSize size) {
    setState(() => _textSize = size);
    unawaited(_storageService.setTextSize(size).catchError((_) {}));
  }

  /// Every bottom-nav tab switch goes through this instead of setting
  /// `_tabIndex` directly, so a message left showing on the tab being left
  /// (e.g. an error banner) doesn't visually follow the user to the next
  /// one — this is an `IndexedStack` swap, not a Navigator route change,
  /// so `AppMessenger.navigatorObserver` never sees it and can't clear it
  /// on its own.
  void _switchTab(int index) {
    AppMessenger.clear();
    setState(() => _tabIndex = index);
  }

  // Mirrors SettingsScreen's own `_fallbackAvatar`: `AvatarPickerScreen`
  // requires a non-null starting avatar (PRD v2 §13.5's "no empty state"
  // rule), but `_profile!.avatar` is nullable — only a legacy profile from
  // before onboarding started auto-assigning one can actually be null in
  // practice. Computed once, not per tap, so a legacy profile doesn't show
  // a different random character on every open before the user ever
  // settles on one.
  late final Avatar _fallbackAvatarForPicker = Avatar.random();

  /// Persists an avatar change and updates in-memory state — the same two
  /// steps `SettingsScreen._changeAvatar` already does for its own entry
  /// point, written again here rather than shared: the two call sites read
  /// from different state shapes (`SettingsScreen` has `widget.profile`/
  /// `widget.onProfileUpdated`; this class has `_profile`/`setState`
  /// directly), so sharing would cost more in indirection than the ~5
  /// lines it would save.
  Future<void> _changeAvatar(Avatar avatar) async {
    final updated = _profile!.copyWith(avatar: avatar);
    try {
      await _storageService.saveUserProfile(updated);
      setState(() => _profile = updated);
    } catch (_) {
      // Silent by design, matching SettingsScreen's own posture for this
      // exact failure mode: a failed background save shouldn't surface an
      // error over what's otherwise a cosmetic preference.
    }
  }

  /// Home's avatar now opens the same full-screen picker Settings does,
  /// via a real route push (not `_switchTab`) so the `Hero` flight in
  /// `HomeScreen`/`AvatarPickerScreen` has an actual route transition to
  /// animate across — a tab switch is an `IndexedStack` swap, which Hero
  /// cannot animate through at all: it has no push/pop transition for a
  /// flight to run during. `MediaQuery.disableAnimationsOf` is checked
  /// explicitly, the same manual-gating pattern this app already uses
  /// everywhere else motion appears (e.g. `AvatarCarousel`'s own pop
  /// animation) — Flutter's route transitions don't automatically shorten
  /// themselves for reduced-motion settings.
  void _openAvatarPickerFromHome(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final picker = AvatarPickerScreen(
      currentAvatar: _profile!.avatar ?? _fallbackAvatarForPicker,
      onAvatarChanged: _changeAvatar,
      heroTag: homeAvatarHeroTag,
    );
    Navigator.of(context).push(
      reduceMotion
          ? PageRouteBuilder(
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              pageBuilder: (_, __, ___) => picker,
            )
          : MaterialPageRoute(builder: (_) => picker),
    );
  }

  ThemeMode get _flutterThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GrammarLens',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      navigatorObservers: [AppMessenger.navigatorObserver],
      theme: buildAppTheme(Brightness.light, textSize: _textSize),
      darkTheme: buildAppTheme(Brightness.dark, textSize: _textSize),
      themeMode: _flutterThemeMode,
      // `Builder` gets a context nested under the `MaterialApp` above, so
      // `Theme.of` here resolves the light/dark scheme we just set via
      // `theme`/`darkTheme` instead of whatever theme sits above this
      // widget in the tree.
      home: Builder(
        builder: (context) {
          if (_profileLoading) {
            return const LoadingView(message: 'Loading…');
          }
          if (_profile == null) {
            return FirstLaunchFlow(
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
              onComplete: (profile) => setState(() => _profile = profile),
            );
          }

          final screens = [
            HomeScreen(
              active: _tabIndex == 0,
              userName: _profile!.name,
              avatar: _profile!.avatar,
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
              subscriptionService: _subscriptionService,
              onAvatarTap: () => _openAvatarPickerFromHome(context),
            ),
            ReviewScreen(
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
              subscriptionService: _subscriptionService,
              // IndexedStack keeps this screen's State alive across tab
              // switches instead of recreating it, so initState alone won't
              // pick up errors saved while a different tab (e.g. after a
              // Home practice session) was active. Passing whether this tab
              // is currently selected lets ReviewScreen detect "just became
              // visible" and reload then.
              active: _tabIndex == 1,
              onGoToPractice: () => _switchTab(0),
            ),
            SettingsScreen(
              active: _tabIndex == 2,
              themeMode: _themeMode,
              onSelectThemeMode: _setThemeMode,
              textSize: _textSize,
              onSelectTextSize: _setTextSize,
              profile: _profile!,
              storageService: _storageService,
              onProfileUpdated: (profile) => setState(() => _profile = profile),
              // Debug-only action inside SettingsScreen's own
              // `if (kDebugMode)`-gated "Developer" section — this
              // callback itself is harmless either way, since it's never
              // invoked unless that section rendered in the first place.
              onResetOnboarding: () => setState(() => _profile = null),
            ),
          ];

          return Scaffold(
            body: FloatingNavShell(
              body: IndexedStack(index: _tabIndex, children: screens),
              tabs: _navTabs,
              selectedIndex: _tabIndex,
              onTabChange: _switchTab,
            ),
          );
        },
      ),
    );
  }
}

const _navTabs = [
  NavShellTab(
    icon: Icons.home_outlined,
    activeIcon: Icons.home,
    label: 'Home',
  ),
  NavShellTab(
    icon: Icons.history_outlined,
    activeIcon: Icons.history,
    label: 'Review',
  ),
  NavShellTab(
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    label: 'Profile',
  ),
];
