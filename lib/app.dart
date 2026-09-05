import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'models/app_theme_mode.dart';
import 'models/user_profile.dart';
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
  int _tabIndex = 0;
  AppThemeMode _themeMode = AppThemeMode.system;

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
      await SubscriptionService().setDebugAccessOverride(override);
    } catch (_) {
      // No persisted override (or storage unavailable) — leave unset.
    }
  }

  void _setThemeMode(AppThemeMode mode) {
    setState(() => _themeMode = mode);
    unawaited(_storageService.setThemeMode(mode).catchError((_) {}));
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
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
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
              userName: _profile!.name,
              avatar: _profile!.avatar,
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
              onAvatarTap: () => _switchTab(2),
            ),
            ReviewScreen(
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
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
              themeMode: _themeMode,
              onSelectThemeMode: _setThemeMode,
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
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings,
    label: 'Settings',
  ),
];
