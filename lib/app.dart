import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'l10n/l10n.dart';
import 'models/app_theme_mode.dart';
import 'models/app_text_size.dart';
import 'models/pending_climb.dart';
import 'models/user_profile.dart';
import 'screens/first_launch_flow.dart';
import 'screens/home_screen.dart';
import 'screens/review_screen.dart';
import 'screens/settings_screen.dart';
import 'services/analytics_service.dart';
import 'services/app_link.dart';
import 'services/claude_service.dart';
import 'services/device_sync.dart';
import 'services/medal_finalization.dart';
import 'services/native_bridge.dart';
import 'services/reminder_controller.dart';
import 'services/reminder_sync.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'services/widget_sync.dart';
import 'theme.dart';
import 'utils/app_messenger.dart';
import 'utils/debug_tools.dart';
import 'utils/loading_view.dart';
import 'widgets/floating_nav_shell.dart';
import 'widgets/tab_switcher.dart';
import 'widgets/monthly_climb/climb_debug_controls.dart';

class GrammarLensApp extends StatefulWidget {
  /// Optional overrides exist so tests can observe launch/resume behavior
  /// without a real database or Firebase; production passes neither.
  final StorageService? storageService;
  final AnalyticsService? analyticsService;
  final ClaudeService? claudeService;

  /// The iOS bridge (widgets, links, reminders); tests pass a fake.
  final NativeBridge? nativeBridge;

  /// Test-only clock forwarded to [HomeScreen] (and the first-launch flow's
  /// month) so a day rollover can be driven end to end through the app's
  /// lifecycle handling.
  final DateTime Function()? clock;

  const GrammarLensApp({
    super.key,
    this.storageService,
    this.analyticsService,
    this.claudeService,
    this.nativeBridge,
    this.clock,
  });

  @override
  State<GrammarLensApp> createState() => _GrammarLensAppState();
}

class _GrammarLensAppState extends State<GrammarLensApp>
    with WidgetsBindingObserver {
  late final ClaudeService _claudeService =
      widget.claudeService ?? ClaudeService();
  late final StorageService _storageService =
      widget.storageService ?? StorageService();
  late final AnalyticsService _analyticsService =
      widget.analyticsService ?? AnalyticsService();
  // Shared explicitly with both HomeScreen and ReviewScreen (rather than
  // each defaulting to its own `SubscriptionService()`) so both go through
  // one instance at this level, matching how the other three services
  // above are already shared — `SubscriptionService`'s own entitlement/
  // override state is static regardless, but there's no reason for this
  // one to be the odd one out.
  final SubscriptionService _subscriptionService = SubscriptionService();
  late final NativeBridge _bridge =
      widget.nativeBridge ?? NativeBridge.instance;

  /// Widget and reminder taps (`grammarlens://…`, DW0-3).
  late final AppLinkRouter _linkRouter = AppLinkRouter(_bridge);

  /// Whether the router is attached to the tab shell (null: not decided
  /// yet, the profile is loading).
  bool? _linksAttached;

  /// The root navigator: a link is dropped while a route is pushed on it
  /// (a Daily Test, practice, the paywall, a sheet), DW0-3.
  final _navigatorKey = GlobalKey<NavigatorState>();

  /// Bumped by a `grammarlens://daily-test` link; Home opens the Daily Test.
  final ValueNotifier<int> _dailyTestLinks = ValueNotifier(0);

  /// W01 v12: the tip widget's weak spot, for Review to open (R03).
  final ValueNotifier<WeakSpotLink?> _weakSpotLinks = ValueNotifier(null);

  /// The widgets' payload (W3) and the reminder plan (W4), kept in step
  /// with the app: at launch, on resume, and after every storage write that
  /// changes them (`StorageService.onChanged`).
  late final DeviceSync _deviceSync = DeviceSync([
    WidgetSync(
      storage: _storageService,
      bridge: _bridge,
      locale: _interfaceLocale,
      clock: widget.clock,
    ).run,
    ReminderSync(
      storage: _storageService,
      bridge: _bridge,
      locale: _interfaceLocale,
      hasFullAccess: () => _subscriptionService.hasFullAccess,
      clock: widget.clock,
    ).run,
  ]);

  /// The reminder settings, shared by Home (N01, V24) and Settings (N03).
  late final ReminderController _reminders =
      ReminderController(storage: _storageService, bridge: _bridge);

  /// The locale the interface shows now (the widgets and reminders use it).
  Locale _interfaceLocale() => effectiveAppLocale(
      _language, WidgetsBinding.instance.platformDispatcher.locales);
  int _tabIndex = 0;

  /// The look of the last tab switch (`_switchTab`).
  TabTransition _tabTransition = TabTransition.fade;
  AppThemeMode _themeMode = AppThemeMode.system;
  AppTextSize _textSize = AppTextSize.medium;

  /// The interface-language choice (1.4.0 B3): System default until the
  /// stored one loads or the user picks one in Profile.
  AppLanguage _language = AppLanguage.system;

  // Null while loading and stays null until onboarding completes — that's
  // the app's whole "returning vs. first launch" signal (PRD v2 §4), no
  // separate flag. `_profileLoading` only exists to avoid a one-frame flash
  // of the onboarding flow before the local sqlite read resolves.
  UserProfile? _profile;
  bool _profileLoading = true;

  // The first-launch flow's saved-but-not-yet-shown climb step, handed to the
  // Home that replaces it. Home takes it in `initState` and clears it here, so
  // it can only ever animate once.
  PendingClimb? _initialPendingClimb;

  // Whether Home should offer the first-day paywall: true only when the user
  // finished the Day-0 Daily Test. Given to the Home that replaces the flow and
  // cleared by it in `initState`, like [_initialPendingClimb].
  bool _offerDay0Paywall = false;

  // Whether Home plays the first run's zoom (Batch 6, M2): true for the Home
  // that replaces the first-launch flow, however it ended. Cleared by that
  // Home in `initState`, like [_offerDay0Paywall].
  bool _firstRunZoom = false;

  // The first climb (V12) already played the first run's camera, so Home
  // skips its in-card zoom; read once, like [_firstRunZoom].
  bool _firstRunZoomPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _finalizeMedalMonths();
    _deleteStaleDailyTestSets();
    _loadThemeMode();
    _loadTextSize();
    _loadLanguage();
    _loadProfile();
    unawaited(_linkRouter.start());
    DeviceSync.current = _deviceSync;
    StorageService.onChanged = DeviceSync.requestUpdate;
    // Premium starting or ending changes "Free ticket is back".
    _subscriptionService.addAccessListener(_onAccessChanged);
    if (kDebugMode && DebugTools.enabledForTesting) _loadDebugAccessOverride();
    if (ClimbDebugControls.available) {
      ClimbDebugControls.instance.addListener(_onDebugPlay);
    }
  }

  @override
  void dispose() {
    if (ClimbDebugControls.available) {
      ClimbDebugControls.instance.removeListener(_onDebugPlay);
    }
    WidgetsBinding.instance.removeObserver(this);
    _linkRouter.dispose();
    _dailyTestLinks.dispose();
    _weakSpotLinks.dispose();
    _subscriptionService.removeAccessListener(_onAccessChanged);
    _reminders.dispose();
    if (identical(DeviceSync.current, _deviceSync)) {
      DeviceSync.current = null;
      StorageService.onChanged = null;
    }
    super.dispose();
  }

  void _onAccessChanged(bool _) => _deviceSync.request();

  /// Attaches the link router once the tab shell exists and detaches it
  /// while onboarding runs (DW0-3). Called from [build]; acts after the
  /// frame so Home is mounted when a waiting link arrives.
  void _syncLinkRouter() {
    if (_profileLoading) return;
    final shell = _profile != null;
    if (shell == _linksAttached) return;
    _linksAttached = shell;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (shell) {
        _linkRouter.attach(_openLink);
      } else {
        _linkRouter.detach();
      }
    });
  }

  /// A widget or reminder tap. Dropped while anything is pushed above the
  /// tab shell, so a running flow is never thrown away (DW0-3).
  void _openLink(AppLink link) {
    if (!mounted || _profile == null) return;
    if (_navigatorKey.currentState?.canPop() ?? false) return;
    switch (link) {
      case AppLink.home:
        _switchTab(0);
      case AppLink.review:
        _switchTab(1);
      case AppLink.dailyTest:
        _switchTab(0);
        _dailyTestLinks.value++;
      case AppLink.weakSpot:
        _switchTab(1);
        // Null first, so the same weak spot twice still notifies.
        _weakSpotLinks.value = null;
        _weakSpotLinks.value = _linkRouter.weakSpot;
    }
  }

  // Resume work is split by owner, never duplicated: this observer runs the
  // app-wide jobs (analytics, medal finalization) that must happen even
  // before Home exists; `HomeScreen`'s own observer refreshes what only Home
  // shows (Daily Test day, greeting, climb month, weak spots). One resume
  // triggers each job exactly once — see test/app_resume_test.dart.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _analyticsService.appPaused();
    if (state == AppLifecycleState.resumed) {
      _analyticsService.appResumed();
      _finalizeMedalMonths();
      // A new day or month while away: the widgets and reminders follow.
      _deviceSync.request();
    }
  }

  /// The device's language changed in Settings while the app ran. When the
  /// locale is not pinned (System default, or a choice this build has no
  /// strings for) the interface follows it, MaterialApp resolving the
  /// locale on its own; `ui_language` follows too.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (_fixedLocale == null) {
      _reportUiLanguage(locales);
      // The device's language is the interface's: widgets and reminders too.
      _deviceSync.request();
    }
  }

  /// Launch only, never on resume: old unfinished Daily Test sets
  /// (`StorageService.deleteStaleDailyTestSets`). Best effort; a failure
  /// just leaves them for the next launch.
  Future<void> _deleteStaleDailyTestSets() async {
    try {
      await _storageService.deleteStaleDailyTestSets();
    } catch (_) {}
  }

  /// Freezes past medal months at launch and on every resume, not only when
  /// Profile is opened, so `medal_month_finalized` also counts users who
  /// never visit Profile. Idempotent by construction (see
  /// `finalizePastMedalMonthsAndReport`): a month frozen by one trigger is
  /// not finalized or reported again by another.
  Future<void> _finalizeMedalMonths() async {
    try {
      await finalizePastMedalMonthsAndReport(
        storageService: _storageService,
        analyticsService: _analyticsService,
      );
    } catch (_) {
      // Storage unavailable — Profile retries when it is opened.
    }
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
      _deviceSync.request();
    }
  }

  Future<void> _loadTextSize() async {
    try {
      final size = await _storageService.getTextSize();
      if (mounted) setState(() => _textSize = size);
      unawaited(_analyticsService.setTextSizeProperty(size));
    } catch (_) {
      // Keep the readable medium default if storage is unavailable.
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final language = await _storageService.getLanguage();
      if (mounted) setState(() => _language = language);
    } catch (_) {
      // Keep following the device's language if storage is unavailable.
    }
    _reportUiLanguage();
  }

  /// The locale [MaterialApp] is pinned to: the chosen language when this
  /// build has its strings, else null, so the device's language is resolved
  /// ([resolveAppLocale]).
  Locale? get _fixedLocale {
    final locale = _language.locale;
    if (locale == null) return null;
    final supported = AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
    return supported ? locale : null;
  }

  /// `ui_language` (docs/analytics-plan.md §3): the language the interface
  /// is shown in now, the resolved one on System default.
  void _reportUiLanguage([List<Locale>? deviceLocales]) {
    final locale = effectiveAppLocale(_language,
        deviceLocales ?? WidgetsBinding.instance.platformDispatcher.locales);
    unawaited(
        _analyticsService.setUiLanguageProperty(AppLanguage.forLocale(locale)));
  }

  void _setLanguage(AppLanguage language) {
    if (language == _language) return;
    setState(() => _language = language);
    // Also after the stored write (StorageService.onChanged); this one
    // covers a storage failure.
    _deviceSync.request();
    unawaited(_storageService.setLanguage(language).catchError((_) {}));
    _reportUiLanguage();
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

  /// N27: a replay asked for from the debug panel plays on Home, so the
  /// app shows the Home tab; Home takes the replay once it is visible.
  void _onDebugPlay() {
    if (ClimbDebugControls.instance.pending != null && _profile != null) {
      _switchTab(0);
    }
  }

  /// N27: the debug panel's "Reset local data". The whole local database
  /// goes (`StorageService.resetAllLocalData`), and the app's in-memory
  /// state returns to a first launch: no profile (so the first-launch
  /// flow), the default appearance and text size, the Home tab, no
  /// entitlement override. The panel's own theme and day settings stay
  /// (memory only, debug tools).
  Future<void> _resetLocalData() async {
    await _storageService.resetAllLocalData();
    await _subscriptionService.setDebugAccessOverride(null);
    if (!mounted) return;
    setState(() {
      _profile = null;
      _themeMode = AppThemeMode.system;
      _textSize = AppTextSize.medium;
      _language = AppLanguage.system;
      _tabIndex = 0;
      _initialPendingClimb = null;
      _offerDay0Paywall = false;
      _firstRunZoom = false;
      _firstRunZoomPlayed = false;
    });
    // No profile any more: the reminders are removed.
    _deviceSync.request();
  }

  void _setThemeMode(AppThemeMode mode) {
    setState(() => _themeMode = mode);
    unawaited(_storageService.setThemeMode(mode).catchError((_) {}));
  }

  void _setTextSize(AppTextSize size) {
    final previous = _textSize;
    setState(() => _textSize = size);
    if (size != previous) {
      unawaited(
          _analyticsService.textSizeChanged(size: size, previous: previous));
      unawaited(_analyticsService.setTextSizeProperty(size));
    }
    unawaited(_storageService.setTextSize(size).catchError((_) {}));
  }

  /// Every bottom-nav tab switch goes through this instead of setting
  /// `_tabIndex` directly, so a message left showing on the tab being left
  /// (e.g. an error banner) doesn't visually follow the user to the next
  /// one — this is a `TabSwitcher` swap, not a Navigator route change,
  /// so `AppMessenger.navigatorObserver` never sees it and can't clear it
  /// on its own.
  ///
  /// [transition] is the look of the switch (`TabSwitcher`): the
  /// fade-through everywhere, the slide only from Home's "Go to Review"
  /// card (owner, 1.2.0 Batch 9).
  void _switchTab(int index, {TabTransition transition = TabTransition.fade}) {
    AppMessenger.clear();
    setState(() {
      _tabIndex = index;
      _tabTransition = transition;
    });
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
    _syncLinkRouter();
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'GrammarLens', // l10n-guard: the brand
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppMessenger.key,
      navigatorObservers: [AppMessenger.navigatorObserver],
      theme: buildAppTheme(Brightness.light, textSize: _textSize),
      darkTheme: buildAppTheme(Brightness.dark, textSize: _textSize),
      themeMode: _flutterThemeMode,
      // 1.4.0 B3: the interface strings. A fixed choice pins the locale;
      // System default leaves it null and the device's preferred locales
      // are resolved against the languages this build has strings for.
      // A change rebuilds from here: every widget that reads
      // `context.l10n` in `build` follows.
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: _fixedLocale,
      localeListResolutionCallback: (locales, supported) =>
          resolveAppLocale(locales, supported),
      // `Builder` gets a context nested under the `MaterialApp` above, so
      // `Theme.of` here resolves the light/dark scheme we just set via
      // `theme`/`darkTheme` instead of whatever theme sits above this
      // widget in the tree.
      home: Builder(
        builder: (context) {
          if (_profileLoading) {
            // The app's first frame, built under the launch splash
            // (LaunchGate) and usually replaced before the splash fades.
            // Nothing else paints behind it, so it paints its own
            // background, the same `surfaceContainerLow` as the splash and
            // the native launch screen (`LaunchBackground` in
            // ios/Runner/Assets.xcassets), so there is no flash between
            // them. `Material` also gives the text a real text style.
            return Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: LoadingView(message: context.l10n.appLoading),
            );
          }
          if (_profile == null) {
            return FirstLaunchFlow(
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
              clock: widget.clock ?? DateTime.now,
              onComplete: (profile,
                      {pendingClimb,
                      dayZeroCompleted = false,
                      firstClimbShown = false}) =>
                  setState(() {
                _deviceSync.request();
                _profile = profile;
                _initialPendingClimb = pendingClimb;
                _offerDay0Paywall = dayZeroCompleted;
                _firstRunZoom = true;
                _firstRunZoomPlayed = firstClimbShown;
              }),
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
              clock: widget.clock,
              initialPendingClimb: _initialPendingClimb,
              onInitialPendingClimbTaken: () => _initialPendingClimb = null,
              offerDay0Paywall: _offerDay0Paywall,
              onOfferDay0PaywallTaken: () => _offerDay0Paywall = false,
              firstRunZoom: _firstRunZoom,
              firstRunZoomPlayed: _firstRunZoomPlayed,
              onFirstRunZoomTaken: () {
                _firstRunZoom = false;
                _firstRunZoomPlayed = false;
              },
              dailyTestLinks: _dailyTestLinks,
              reminders: _reminders,
              onOpenProfile: () => _switchTab(2),
              onGoToReview: () =>
                  _switchTab(1, transition: TabTransition.slide),
            ),
            ReviewScreen(
              claudeService: _claudeService,
              storageService: _storageService,
              analyticsService: _analyticsService,
              subscriptionService: _subscriptionService,
              // TabSwitcher keeps this screen's State alive across tab
              // switches instead of recreating it, so initState alone won't
              // pick up errors saved while a different tab (e.g. after a
              // Home practice session) was active. Passing whether this tab
              // is currently selected lets ReviewScreen detect "just became
              // visible" and reload then.
              active: _tabIndex == 1,
              onGoToPractice: () => _switchTab(0),
              userName: _profile!.name,
              hero: _profile!.avatar,
              clock: widget.clock ?? DateTime.now,
              weakSpotLinks: _weakSpotLinks,
            ),
            SettingsScreen(
              active: _tabIndex == 2,
              themeMode: _themeMode,
              onSelectThemeMode: _setThemeMode,
              textSize: _textSize,
              onSelectTextSize: _setTextSize,
              language: _language,
              onSelectLanguage: _setLanguage,
              profile: _profile!,
              storageService: _storageService,
              analyticsService: _analyticsService,
              onProfileUpdated: (profile) => setState(() => _profile = profile),
              // Debug-only action inside SettingsScreen's own
              // `if (kDebugMode)`-gated "Developer" section — this
              // callback itself is harmless either way, since it's never
              // invoked unless that section rendered in the first place.
              onResetOnboarding: () => setState(() => _profile = null),
              onResetLocalData: _resetLocalData,
              reminders: _reminders,
            ),
          ];

          // The shell brings its own Scaffold (see FloatingNavShell: it
          // must not resize for the keyboard).
          return FloatingNavShell(
            body: TabSwitcher(
              index: _tabIndex,
              transition: _tabTransition,
              children: screens,
            ),
            tabs: _navTabs(context.l10n),
            selectedIndex: _tabIndex,
            onTabChange: (index) => _switchTab(index),
          );
        },
      ),
    );
  }
}

/// The bottom navigation's tabs. "Review" is a feature name and stays
/// English in every language (1.4.0 D6).
List<NavShellTab> _navTabs(AppLocalizations l10n) => [
      NavShellTab(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: l10n.navHome,
      ),
      NavShellTab(
        icon: Icons.history_outlined,
        activeIcon: Icons.history,
        label: l10n.featureReview,
      ),
      NavShellTab(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: l10n.navProfile,
      ),
    ];
