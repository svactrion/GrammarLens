import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

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
            ),
          ];

          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final isDark = theme.brightness == Brightness.dark;
          // Same contrast-checked color the app bar uses for content sitting
          // directly on the orange (light) / near-black (dark) scaffold —
          // see theme.dart's `appBarFg` for the reasoning.
          final unselectedColor =
              theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;
          return Scaffold(
            // A real floating bar, not Scaffold's `bottomNavigationBar`
            // slot: that slot wraps its child in an opaque `Material`
            // spanning the FULL WIDTH of the bottom of the screen, so even
            // with a transparent/rounded child inside it, the slot itself
            // painted a solid strip behind the pill's rounded corners and
            // across the margins either side of it — exactly the "opaque
            // backdrop behind the whole bottom of the screen" bug this
            // rewrite fixes. A `Stack` with the bar as a `Positioned`
            // overlay has no such slot: nothing paints anything outside the
            // pill's own bounds, and screen content genuinely continues
            // underneath it (scrolling included) rather than stopping at an
            // invisible-but-present boundary.
            body: Stack(
              children: [
                IndexedStack(index: _tabIndex, children: screens),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(32),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              // Frosted glass: a translucent surface tint
                              // over the blur, not a solid fill — content
                              // scrolling behind the pill should still read
                              // through it, softened.
                              color: colorScheme.surfaceContainerLow
                                  .withValues(alpha: isDark ? 0.55 : 0.68),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      colorScheme.shadow.withValues(alpha: 0.18),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: _FloatingNavBar(
                              selectedIndex: _tabIndex,
                              onTabChange: _switchTab,
                              unselectedColor: unselectedColor,
                              activeColor: colorScheme.secondary,
                              labelStyle: theme.textTheme.labelMedium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NavTabData {
  const _NavTabData(this.icon, this.activeIcon, this.label);

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _navTabs = [
  _NavTabData(Icons.home_outlined, Icons.home, 'Home'),
  _NavTabData(Icons.history_outlined, Icons.history, 'Review'),
  _NavTabData(Icons.settings_outlined, Icons.settings, 'Settings'),
];

// Replaces the previous `google_nav_bar` GNav widget. GNav's active-tab
// indicator is a `tabBackgroundColor` block painted by its own internal
// `Button`/`GButton` layout (see the package source), which is built around
// an animated icon+label "chip" — there's no seam to customize that
// geometry from outside, and two rounds of trying to fix that block's
// alignment against the floating pill's edges didn't land (see
// docs/roadmap.md). A plain custom row gives full control over the
// active-tab treatment instead: icon swaps outline → filled and icon/label
// recolor to the accent — no background shape at all.
class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onTabChange,
    required this.unselectedColor,
    required this.activeColor,
    required this.labelStyle,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabChange;
  final Color unselectedColor;
  final Color activeColor;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _navTabs.length; i++)
            _NavTab(
              data: _navTabs[i],
              active: i == selectedIndex,
              unselectedColor: unselectedColor,
              activeColor: activeColor,
              labelStyle: labelStyle,
              onTap: () {
                if (i != selectedIndex) HapticFeedback.selectionClick();
                onTabChange(i);
              },
            ),
        ],
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.data,
    required this.active,
    required this.unselectedColor,
    required this.activeColor,
    required this.labelStyle,
    required this.onTap,
  });

  final _NavTabData data;
  final bool active;
  final Color unselectedColor;
  final Color activeColor;
  final TextStyle? labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : unselectedColor;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(active ? data.activeIcon : data.icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                data.label,
                style: labelStyle?.copyWith(
                  color: color,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
