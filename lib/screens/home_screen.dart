import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../data/topics.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import '../models/medal_tier.dart';
import '../models/pending_climb.dart';
import '../models/review_sort_order.dart';
import '../models/topic.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/daily_test_service.dart';
import '../services/month_transition.dart';
import '../services/monthly_medal_rules.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/answer_matching.dart';
import '../utils/greeting.dart';
import '../utils/text_format.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/section_title.dart';
import '../widgets/home_greeting.dart';
import '../widgets/launch_splash.dart';
import '../widgets/locked_premium_pill.dart';
import '../widgets/month_card_sheet.dart';
import '../widgets/monthly_climb/climb_card.dart';
import '../widgets/monthly_climb/climb_debug_month_card.dart';
import '../widgets/monthly_climb/climb_score_bar.dart';
import '../widgets/monthly_climb/climb_zoom.dart';
import '../widgets/monthly_climb/monthly_mountain.dart';
import '../widgets/weak_spot_card.dart';
import 'avatar_picker_screen.dart' show homeAvatarHeroTag;
import 'daily_test_result_screen.dart';
import 'daily_test_screen.dart';
import 'premium_screen.dart';
import 'topic_practice_screen.dart';
import 'weak_spot_detail_screen.dart';
import '../widgets/medal_celebration.dart';
import '../widgets/monthly_climb/climb_debug_milestone.dart';
import '../widgets/monthly_climb/climb_debug_theme.dart';
import '../widgets/monthly_climb/climb_debug_controls.dart';
import '../widgets/monthly_climb/climb_save_points.dart';

/// Home as a "today" screen, not a menu (PRD v2 §13.5). Replaces the old
/// mode-selection Home once Streak Mode and Voice Practice were removed and
/// left it looking empty — refilling that space with cards for features
/// that don't exist would repeat exactly the mistake removing them fixed
/// (docs/design-audit.md). The actual problem was that Home already had
/// real data (today's Daily Test state, the error profile) and showed none
/// of it; this screen shows it instead.
class HomeScreen extends StatefulWidget {
  final bool active;
  final String userName;
  final Avatar? avatar;
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;
  // Nullable, same as ReviewScreen's `onGoToPractice`: the bottom-nav tab
  // switch lives in app.dart's State, not here, so this is a hook rather
  // than HomeScreen owning navigation itself.
  final VoidCallback? onAvatarTap;

  /// Switches the bottom-nav to the Review tab (the Review call-out that
  /// ends Home for a free user, 1.2.0 Q15). Nullable for the same reason as
  /// [onAvatarTap]: the tab switch lives in app.dart.
  final VoidCallback? onGoToReview;
  // Test-only clock seam (defaults to the real DateTime.now) — the
  // time-of-day greeting's boundary tests need to construct exact
  // 04:59/05:00-style instants, not depend on whatever time the suite
  // happens to run at. No caller outside a test ever overrides this.
  final DateTime Function() clock;

  /// A Daily Test completion that finished before this Home existed (the
  /// first-launch flow's Day-0 test). Read once in `initState`; Home mounts
  /// the mountain at the position before that step and then animates it.
  final PendingClimb? initialPendingClimb;

  /// Called from `initState` once [initialPendingClimb] has been taken, so the
  /// owner can drop it and never hand the same completion to a later Home.
  final VoidCallback? onInitialPendingClimbTaken;

  /// True when this Home replaces a first-launch flow whose Day-0 Daily Test
  /// the user finished: Home then opens the Premium screen by itself, once,
  /// after the climb (see [_HomeScreenState._offerDay0Paywall]). Read once in
  /// `initState`, like [initialPendingClimb].
  final bool offerDay0Paywall;

  /// Called from `initState` once [offerDay0Paywall] has been taken, so the
  /// owner can drop it and never hand it to a later Home.
  final VoidCallback? onOfferDay0PaywallTaken;

  /// True when this Home replaces the first-launch flow (Batch 6, M2,
  /// M14): no month card; once, a zoom from the whole mountain to the
  /// avatar on START, before the Day-0 step and the first-day paywall.
  /// Read once in `initState`, like [offerDay0Paywall].
  final bool firstRunZoom;

  /// Called from `initState` once [firstRunZoom] has been taken.
  final VoidCallback? onFirstRunZoomTaken;

  HomeScreen({
    super.key,
    this.active = true,
    required this.userName,
    this.avatar,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    SubscriptionService? subscriptionService,
    this.onAvatarTap,
    this.onGoToReview,
    this.initialPendingClimb,
    this.onInitialPendingClimbTaken,
    this.offerDay0Paywall = false,
    this.onOfferDay0PaywallTaken,
    this.firstRunZoom = false,
    this.onFirstRunZoomTaken,
    DateTime Function()? clock,
  })  : subscriptionService = subscriptionService ?? SubscriptionService(),
        clock = clock ?? DateTime.now;

  /// Batch 6, M21: before the month card opens, Home scrolls until the
  /// Today card's last this-many points still show, so the Daily Test's
  /// entry stays on screen (and tappable) through the zoom that follows.
  /// 1.2.0: the entry is the card's button, not the whole card, so this is
  /// the button and the card's padding below it, 48 + 18 (it was 56 for
  /// the old whole-card tap target).
  static const monthCardTodayPeek = 66.0;

  /// The greeting word's size relative to a section title (titleLarge):
  /// 22 pt at the default text size.
  static const greetingScale = 1.1;

  /// Light mode's ground shadow under the hero, for tests.
  static const heroGroundKey = ValueKey('home_hero_ground');

  /// The soft light behind the hero, for tests.
  static const heroBacklightKey = ValueKey('home_hero_backlight');

  /// The Review call-out's tap target, for tests.
  static const reviewCalloutKey = ValueKey('home_review_callout');

  /// The Daily Test card, for tests that measure or tap it.
  static const dailyTestCardKey = ValueKey('home_daily_test_card');

  /// The clock the month card's open time is measured with; a test seam,
  /// like `StorageService.clockForTesting`. Never assigned outside a test.
  @visibleForTesting
  static DateTime Function() monthCardClockForTesting = DateTime.now;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Starts closed rather than "unknown/loading" — PRD v2 §12.2's default
  // for anyone not confirmed to have a trial/subscription is Free, and
  // fail-closed here matches SubscriptionService.hasFullAccess's own
  // fail-closed default (never grant access nobody paid for while a check
  // is still in flight).
  bool _hasFullAccess = false;

  // One service for everything Daily Test on this Home (opening the test, its
  // result, the completion): its single-flight generation and the next day's
  // preparation only work when they share an instance.
  late final DailyTestService _dailyTestService = DailyTestService(
    claudeService: widget.claudeService,
    storageService: widget.storageService,
  );

  int _dailyLoadGeneration = 0;
  bool _loadingToday = true;
  DailyTestSet? _todaysDailyTest;

  int _climbLoadGeneration = 0;
  int? _climbSteps;

  /// The month's theme ([_resolveClimbTheme]); Green Slope until it has loaded.
  ClimbTheme _climbTheme = ClimbThemes.greenSlope;

  /// The month's medal score (rule v1), shown by the score bar.
  int _climbScore = 0;
  late DateTime _climbMonth;
  bool _loadingClimb = true;
  bool _climbLoadFailed = false;
  final _mountainKey = GlobalKey();
  bool _dailyFlowActive = false;
  String? _pendingClimbDay;

  /// Steps the pending completion earned, known only when it arrived through
  /// [HomeScreen.initialPendingClimb]. It lets the first load derive the
  /// position to mount at (`progress.steps - step`) because, unlike a Home
  /// that was already showing the mountain, there is no earlier value to
  /// compare against.
  int _pendingClimbStep = 0;

  // The first-day paywall ([HomeScreen.offerDay0Paywall]). Pending until it is
  // shown or ruled out (premium, already claimed, unreadable storage); ready
  // once the climb has landed; and shown at most once per install through a
  // stored flag.
  bool _day0PaywallPending = false;
  bool _day0PaywallReady = false;
  bool _day0PaywallChecking = false;
  Timer? _day0PaywallTimer;

  /// Whether the pawn is still moving to a step this Home animates. While it
  /// is, a finished load must not open the paywall over the animation.
  bool _climbAnimating = false;

  /// How long the pawn stands on its new step before the paywall opens.
  static const Duration _day0PaywallDelay = Duration(milliseconds: 600);

  bool get _homeVisible =>
      widget.active &&
      !_dailyFlowActive &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true) &&
      WidgetsBinding.instance.lifecycleState != AppLifecycleState.paused;

  bool _loadingWeakSpots = true;
  List<WeakSpot> _weakSpots = const [];

  /// How many weak spots there are in all; Home shows at most three
  /// ([_weakSpots]). Read from `getTopicStats` (distinct error types per
  /// topic, the same grouping `getWeakSpots` uses), falling back to the
  /// number shown if that read fails.
  int _weakSpotTotal = 0;

  /// Batch 6: the zoom from the whole mountain (K-c) to the daily framing,
  /// after the month card or on the first run.
  late final ClimbZoomController _zoom;

  /// The month and step chips: hidden in K-c, fading in at the zoom's end.
  late final Animation<double> _chipOpacity;

  /// The first run's zoom (M2, M14): pending until it starts; then the run
  /// every climb load waits for before the Day-0 step.
  bool _firstRunZoomPending = false;
  Future<void>? _firstRunZoomRun;

  /// The month transition card (Batch 6, M1–M5): loaded with the climb, so
  /// the new month's mountain is first drawn in K-c behind it; shown once
  /// Home is visible and the launch splash has gone.
  MonthCardData? _pendingMonthCard;
  bool _monthCardShowing = false;

  /// `CLIMB_DEBUG_MONTH_CARD` (debug and profile builds, M17): replayed
  /// once per Home, so on every launch and hot restart; never reads or
  /// writes the "seen" records, and sends no events unless
  /// `CLIMB_DEBUG_MONTH_CARD_EVENTS` is on (M18).
  final ClimbDebugMonthCardValue? _debugMonthCard = ClimbDebugMonthCard.value;
  bool _debugMonthCardReplayed = false;

  /// `CLIMB_DEBUG_MILESTONE` on a tier (debug builds only, N22): the
  /// celebration over Home, once per Home (every launch and hot restart),
  /// after the month card if one replays. Reads and writes no record and
  /// sends no event. A save point value plays in the scene itself.
  final ClimbDebugMilestoneValue? _debugMilestone = ClimbDebugMilestone.value;
  bool _debugMilestoneReplayed = false;

  bool get _sendMonthEvents =>
      _debugMonthCard == null || ClimbDebugMonthCard.sendsEvents;

  /// The debug panel (N27): whether the waiting and the open month card
  /// are its replays, which read and write no record and send events only
  /// with the `CLIMB_DEBUG_MONTH_CARD_EVENTS` opt-in.
  bool _pendingCardIsReplay = false;

  /// A save point replay from the panel, handed to the scene.
  ({ClimbSavePoint point, int id})? _debugHop;

  /// How long the month card has been open in the foreground
  /// (`month_card_dismissed`'s `open_ms`): counting stops while the app is
  /// in the background, so a card left open overnight does not read as
  /// hours. [HomeScreen.monthCardClockForTesting] is the clock.
  Duration _monthCardOpenFor = Duration.zero;
  DateTime? _monthCardOpenSince;

  void _monthCardOpenStart() =>
      _monthCardOpenSince = HomeScreen.monthCardClockForTesting();

  void _monthCardOpenStop() {
    final since = _monthCardOpenSince;
    if (since == null) return;
    _monthCardOpenFor +=
        HomeScreen.monthCardClockForTesting().difference(since);
    _monthCardOpenSince = null;
  }

  final _todayKey = GlobalKey();

  void _onZoomChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _zoom = ClimbZoomController(vsync: this)..addListener(_onZoomChanged);
    _chipOpacity =
        CurvedAnimation(parent: _zoom.progress, curve: const Interval(.85, 1));
    WidgetsBinding.instance.addObserver(this);
    final initialClimb = widget.initialPendingClimb;
    if (initialClimb != null && initialClimb.step > 0) {
      _pendingClimbDay = initialClimb.day;
      _pendingClimbStep = initialClimb.step;
    }
    widget.onInitialPendingClimbTaken?.call();
    _day0PaywallPending = widget.offerDay0Paywall;
    widget.onOfferDay0PaywallTaken?.call();
    if (widget.firstRunZoom ||
        _debugMonthCard == ClimbDebugMonthCardValue.firstRun) {
      _firstRunZoomPending = true;
      // K-c from the first frame the mountain is drawn.
      _zoom.hold(ClimbZoomTrigger.firstRun);
    }
    widget.onFirstRunZoomTaken?.call();
    _checkAccess();
    // Live updates (PRD v2 §12.3/§12.6): a trial starting or expiring
    // should re-gate Topic Practice and the weak-spot rows without
    // requiring an app restart — this is what actually delivers that, not
    // [_checkAccess]'s one-shot read above (which only covers this
    // screen's own initial build).
    widget.subscriptionService.addAccessListener(_onAccessChanged);
    _loadTodaysDailyTest();
    _loadClimb();
    _loadWeakSpots();
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
    widget.subscriptionService.removeAccessListener(_onAccessChanged);
    _day0PaywallTimer?.cancel();
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A delayed save may finish while another route/tab covers Home.
    if (_pendingClimbDay != null && _homeVisible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _homeVisible) _loadClimb();
      });
    }
    // The splash has gone, or Home became visible again: a waiting month
    // card can open.
    if (_pendingMonthCard != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentMonthCard();
      });
    }
    if (_debugMilestone?.tier != null && !_debugMilestoneReplayed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _presentDebugMilestone();
      });
    }
    if (ClimbDebugControls.available &&
        ClimbDebugControls.instance.pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onDebugPlay());
    }
    // Home may just have become visible again (a route above it closed).
    if (_day0PaywallPending && _day0PaywallReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showDay0Paywall();
      });
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && _pendingClimbDay != null) {
      _loadClimb();
    }
    if (!oldWidget.active && widget.active) {
      _showDay0Paywall();
      _presentMonthCard();
      _presentDebugMilestone();
      // After the frame: this runs while the shell is building.
      WidgetsBinding.instance.addPostFrameCallback((_) => _onDebugPlay());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_monthCardShowing) {
      if (state == AppLifecycleState.paused) _monthCardOpenStop();
      if (state == AppLifecycleState.resumed && _monthCardOpenSince == null) {
        _monthCardOpenStart();
      }
    }
    if (state == AppLifecycleState.resumed) {
      // Refresh greeting and cached day after midnight/timezone changes.
      // This is a local read; resuming never generates another question set.
      setState(() => _loadingToday = true);
      _loadTodaysDailyTest();
      _loadClimb();
      _loadWeakSpots();
      _showDay0Paywall();
    }
  }

  Future<void> _checkAccess() async {
    final hasAccess = await widget.subscriptionService.hasFullAccess;
    if (!mounted) return;
    setState(() => _hasFullAccess = hasAccess);
  }

  /// The month's theme, recorded the first time the month is shown, not
  /// only when a Daily Test is completed (Batch 2: a month that was only
  /// viewed must not read as Green Slope afterwards). If storage cannot
  /// answer, the rotation's theme is shown and nothing is recorded.
  Future<ClimbTheme> _resolveClimbTheme(DateTime month) async {
    try {
      return ClimbThemes.byId(await widget.storageService
          .resolveClimbMonthTheme(month.year, month.month));
    } catch (_) {
      return ClimbThemeRotation.shownFor(month.year, month.month);
    }
  }

  Future<void> _loadClimb() async {
    if (!mounted) return;
    final generation = ++_climbLoadGeneration;
    // Persistence is already complete; only presentation waits for the return.
    if (_dailyFlowActive) return;
    final now = widget.clock();
    final month = DateTime(now.year, now.month);
    setState(() {
      if (_climbSteps == null || _climbMonth != month) _climbSteps = null;
      _climbMonth = month;
      _loadingClimb = true;
      _climbLoadFailed = false;
    });
    try {
      final progress =
          await widget.storageService.getClimbProgress(month.year, month.month);
      if (!mounted || generation != _climbLoadGeneration) return;
      final theme = await _resolveClimbTheme(month);
      if (!mounted || generation != _climbLoadGeneration) return;
      // M1: the month card is decided before this month's mountain is drawn,
      // so it is first drawn in K-c behind the card.
      final card = await _loadMonthCard(month);
      if (!mounted || generation != _climbLoadGeneration) return;
      if (card != null) {
        _pendingMonthCard = card;
        _zoom.hold(ClimbZoomTrigger.monthChange);
      }
      final pendingThisMonth = _pendingClimbDay != null &&
          _pendingClimbDay!.startsWith(
              '${month.year}-${month.month.toString().padLeft(2, '0')}-');
      if (pendingThisMonth && _climbSteps == null && _pendingClimbStep > 0) {
        // First load of a Home that never showed the mountain: mount it where
        // it stood before the pending step, so the step below has something
        // to animate from.
        final baseline =
            (progress.steps - _pendingClimbStep).clamp(0, progress.steps);
        if (progress.steps > baseline) {
          setState(() => _climbSteps = baseline);
        }
      }
      final showStep = pendingThisMonth &&
          _climbSteps != null &&
          progress.steps > _climbSteps!;
      if (showStep) {
        if (!_homeVisible) {
          setState(() => _loadingClimb = false);
          return;
        }
        // Keep the old position rendered while bringing the mountain into view.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted || generation != _climbLoadGeneration) return;
        final mountainContext = _mountainKey.currentContext;
        if (mountainContext != null && mountainContext.mounted) {
          await Scrollable.ensureVisible(mountainContext,
              alignment: 0.35,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250));
        }
        if (!mounted || generation != _climbLoadGeneration) return;
        if (!_homeVisible) {
          setState(() => _loadingClimb = false);
          return;
        }
        // M14: the first run's zoom comes before the Day-0 step.
        await _firstRunZoom(theme.id);
        if (!mounted || generation != _climbLoadGeneration) return;
      }
      setState(() {
        _climbTheme = theme;
        _climbSteps = progress.steps;
        _climbScore = MonthlyMedalRules.score(
            correct: progress.correct, wrong: progress.wrong);
        _loadingClimb = false;
        _pendingClimbDay = null;
        _pendingClimbStep = 0;
      });
      // With no step to show (the Day-0 test left, or all skipped), the first
      // run's zoom plays now, and the paywall below waits for it (M14).
      if (!showStep && (_firstRunZoomPending || _firstRunZoomRun != null)) {
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        final mountainContext = _mountainKey.currentContext;
        if (_firstRunZoomPending &&
            mountainContext != null &&
            mountainContext.mounted) {
          await Scrollable.ensureVisible(mountainContext,
              alignment: 0.35,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 250));
          if (!mounted) return;
        }
        await _firstRunZoom(theme.id);
        if (!mounted || generation != _climbLoadGeneration) return;
      }
      if (_pendingMonthCard != null) _presentMonthCard();
      _presentDebugMilestone();
      // A step is now animating and its end opens the paywall; with none (an
      // all-skipped test, or a step that belongs to another month) Home is
      // simply loaded.
      if (showStep) {
        _climbAnimating = true;
      } else if (!_climbAnimating) {
        _armDay0Paywall(Duration.zero);
      }
    } catch (_) {
      if (!mounted || generation != _climbLoadGeneration) return;
      setState(() {
        _loadingClimb = false;
        _climbLoadFailed = true;
      });
      if (!_climbAnimating) _armDay0Paywall(Duration.zero);
    }
  }

  /// The first run's zoom (M2, M14), started once and awaited by every
  /// climb load that follows: the Day-0 step and the paywall come after
  /// it. Ends however the zoom ends; if Home is not visible when it would
  /// start, it is dropped, so the chain never waits for it.
  Future<void> _firstRunZoom(String themeId) {
    if (!_firstRunZoomPending) return _firstRunZoomRun ?? Future.value();
    _firstRunZoomPending = false;
    if (!_homeVisible) {
      _zoom.release();
      return Future.value();
    }
    return _firstRunZoomRun = _runZoom(
        ClimbZoomTrigger.firstRun,
        _debugMonthCard == null ? StorageService.firstRunZoomFlag : null,
        themeId);
  }

  /// Plays a zoom on the month drawn with [themeId], claiming [flag] as it
  /// starts (M6: never twice; null for the debug replay, which claims
  /// nothing), and reports how it ended (M19).
  Future<void> _runZoom(ClimbZoomTrigger trigger, String? flag, String themeId,
      {bool replay = false}) async {
    final outcome = await _zoom.run(
        trigger: trigger,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        claim: flag == null
            ? () async => true
            : () => widget.storageService.claimOneTimeFlag(flag));
    // Null: it had already played and did not run, so nothing ended.
    final send = replay ? ClimbDebugMonthCard.eventsOptIn : _sendMonthEvents;
    if (outcome == null || !send) return;
    unawaited(widget.analyticsService.monthZoomEnded(
        themeId: themeId,
        outcome: outcome.wireName,
        trigger: trigger.wireName));
  }

  /// The theme of the month Home shows (M19): the loaded one, or, before
  /// the climb has loaded, the calendar's.
  String get _monthThemeId {
    if (_climbSteps != null) return _climbTheme.id;
    final now = widget.clock();
    return ClimbThemeRotation.shownFor(now.year, now.month).id;
  }

  /// This month's card, if one is due (`MonthTransition.load`): never on the
  /// first run's Home (M2), never while one is waiting or open.
  Future<MonthCardData?> _loadMonthCard(DateTime month) async {
    final debug = _debugMonthCard;
    if (debug != null) {
      // The replay instead of the real card: storage is not asked.
      if (_debugMonthCardReplayed || widget.firstRunZoom) return null;
      _debugMonthCardReplayed = true;
      return ClimbDebugMonthCard.sample(debug, widget.clock());
    }
    if (widget.firstRunZoom ||
        _firstRunZoomPending ||
        _firstRunZoomRun != null ||
        _pendingMonthCard != null ||
        _monthCardShowing) {
      return null;
    }
    final card = await MonthTransition.load(
        storage: widget.storageService,
        analytics: widget.analyticsService,
        now: widget.clock());
    // Only for the month this load shows.
    if (card == null || card.year != month.year || card.month != month.month) {
      return null;
    }
    return card;
  }

  /// Opens the waiting month card when Home can show it: visible, not
  /// under the launch splash, no Daily Test running. Tried again from
  /// `didChangeDependencies` and when the Home tab becomes active.
  Future<void> _presentMonthCard() async {
    final card = _pendingMonthCard;
    if (card == null || _monthCardShowing || !mounted) return;
    if (!_homeVisible ||
        _dailyFlowActive ||
        LaunchSplashScope.coveringOf(context)) {
      return;
    }
    _monthCardShowing = true;
    _pendingMonthCard = null;
    // A replay: from the define (every launch) or from the panel (N27).
    final replay = _debugMonthCard != null || _pendingCardIsReplay;
    _pendingCardIsReplay = false;
    final send = _pendingCardEvents(replay);
    try {
      // K-c behind the sheet (again, if a Daily Test released it).
      _zoom.hold(ClimbZoomTrigger.monthChange);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _scrollForMonthCard();
      if (send) {
        unawaited(widget.analyticsService.monthCardShown(
            themeId: card.theme.id,
            variant: card.variant.wireName,
            medalTier: card.tier,
            nearMissShown: card.nearMiss != null));
      }
      _monthCardOpenFor = Duration.zero;
      _monthCardOpenStart();
      final how = await showMonthCard(context,
          data: card, avatar: widget.avatar ?? Avatar.values.first);
      _monthCardOpenStop();
      if (!mounted) return;
      // All three ways of closing count as seen (M6), recorded on closing:
      // a card open when the app is closed shows again.
      if (!replay) {
        try {
          await MonthTransition.markSeen(
              widget.storageService, card.year, card.month);
        } catch (_) {}
        if (!mounted) return;
      }
      if (send) {
        unawaited(widget.analyticsService.monthCardDismissed(
            themeId: card.theme.id,
            variant: card.variant.wireName,
            method: how.wireName,
            openMs: _monthCardOpenFor.inMilliseconds));
      }
      await _runZoom(
          ClimbZoomTrigger.monthChange,
          replay ? null : StorageService.monthZoomFlag(card.year, card.month),
          card.theme.id,
          replay: replay && _debugMonthCard == null);
    } finally {
      _monthCardShowing = false;
    }
    _presentDebugMilestone();
    _onDebugPlay();
  }

  /// Whether the month card about to open sends its events: a real card
  /// does; a replay only with the opt-in (M18).
  bool _pendingCardEvents(bool replay) {
    if (!replay) return true;
    return _debugMonthCard != null
        ? ClimbDebugMonthCard.sendsEvents
        : ClimbDebugMonthCard.eventsOptIn;
  }

  /// The debug panel asked for a replay (N27): Home takes it once it is
  /// visible, after anything it is already showing. A milestone or a month
  /// card, with sample data; no record is read or written beyond Home's
  /// own load, and no event is sent (the month card's opt-in aside).
  void _onDebugPlay() {
    if (!mounted || !ClimbDebugControls.available) return;
    final controls = ClimbDebugControls.instance;
    if (controls.pending == null) return;
    if (_climbSteps == null ||
        _monthCardShowing ||
        _zoom.active ||
        !_homeVisible ||
        LaunchSplashScope.coveringOf(context)) {
      // Tried again when Home is shown (didChangeDependencies, didUpdateWidget).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controls.pending != null && _homeVisible) {
          Future<void>.delayed(const Duration(milliseconds: 100), _onDebugPlay);
        }
      });
      return;
    }
    final play = controls.takePlay()!;
    final milestone = play.milestone;
    if (milestone != null) {
      final tier = milestone.tier;
      if (tier != null) {
        _pushTierCelebration(tier);
      } else {
        _scrollMountainIntoView();
        setState(() => _debugHop = (point: milestone.savePoint!, id: play.id));
      }
      return;
    }
    final value = play.monthCard!;
    if (value == ClimbDebugMonthCardValue.firstRun) {
      _zoom.hold(ClimbZoomTrigger.firstRun);
      _scrollMountainIntoView();
      unawaited(_runZoom(ClimbZoomTrigger.firstRun, null, _monthThemeId,
          replay: true));
      return;
    }
    final card = ClimbDebugMonthCard.sample(value, widget.clock());
    if (card == null) return;
    _pendingMonthCard = card;
    _pendingCardIsReplay = true;
    _zoom.hold(ClimbZoomTrigger.monthChange);
    _presentMonthCard();
  }

  void _scrollMountainIntoView() {
    final mountainContext = _mountainKey.currentContext;
    if (mountainContext == null || !mountainContext.mounted) return;
    unawaited(Scrollable.ensureVisible(mountainContext,
        alignment: 0.35,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250)));
  }

  /// A tier's celebration over Home, for the current month and its theme
  /// (or `CLIMB_DEBUG_THEME`'s): the define's launch replay and the
  /// panel's. With the panel's "Celebrate last month" (P9), for last month
  /// and its theme, from the month card's `summary_gold` sample.
  Future<void> _pushTierCelebration(MedalTier tier) {
    var theme = ClimbDebugTheme.value ?? _climbTheme;
    var month = widget.clock().month;
    if (ClimbDebugMilestone.celebratesLastMonth) {
      final card = ClimbDebugMonthCard.sample(
          ClimbDebugMonthCardValue.summaryGold, widget.clock())!;
      theme = card.previousTheme;
      month = card.previousMonth;
    }
    return Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      pageBuilder: (routeContext, _, __) => MedalCelebration.tier(
        tier: tier,
        theme: theme,
        month: month,
        onClose: () => Navigator.of(routeContext).pop(),
      ),
    ));
  }

  /// `CLIMB_DEBUG_MILESTONE`'s tier celebration, when Home can show it:
  /// loaded, visible, not under the splash, after any month card and its
  /// zoom. The current month and its theme, or `CLIMB_DEBUG_THEME`'s.
  Future<void> _presentDebugMilestone() async {
    final tier = _debugMilestone?.tier;
    if (tier == null || _debugMilestoneReplayed || !mounted) return;
    if (_climbSteps == null ||
        _pendingMonthCard != null ||
        _monthCardShowing ||
        _zoom.active ||
        !_homeVisible ||
        LaunchSplashScope.coveringOf(context)) {
      return;
    }
    _debugMilestoneReplayed = true;
    await _pushTierCelebration(tier);
  }

  /// M21: scrolls Home so the Today card's last
  /// [HomeScreen.monthCardTodayPeek]
  /// points show at the top of the list, with the climb card below them.
  void _scrollForMonthCard() {
    final todayContext = _todayKey.currentContext;
    final box = todayContext?.findRenderObject();
    if (todayContext == null || box is! RenderBox || !box.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    final position = Scrollable.maybeOf(todayContext)?.position;
    if (viewport == null || position == null) return;
    final top = viewport.getOffsetToReveal(box, 0).offset;
    position.jumpTo((top + box.size.height - HomeScreen.monthCardTodayPeek)
        .clamp(position.minScrollExtent, position.maxScrollExtent));
  }

  void _onMountainMotionEnd() {
    _climbAnimating = false;
    _armDay0Paywall(_day0PaywallDelay);
  }

  /// The climb has landed, or there is none to wait for: opens the paywall
  /// after [delay] (or as soon as Home is visible, if it is not now).
  void _armDay0Paywall(Duration delay) {
    if (!_day0PaywallPending || _day0PaywallReady) return;
    _day0PaywallTimer?.cancel();
    _day0PaywallTimer = Timer(delay, () {
      _day0PaywallReady = true;
      _showDay0Paywall();
    });
  }

  /// Opens the Premium screen by itself, once, after the first climb. It waits
  /// (returns, to be tried again when Home is visible again) while another route
  /// or tab covers Home or the app is in the background, and it is dropped for
  /// good when the user already has full access, the flag was already claimed,
  /// or the flag cannot be read: a paywall that might show twice is worse than
  /// one that does not show. The flag is claimed right before the push, so an app
  /// closed on the paywall still counts as having seen it.
  Future<void> _showDay0Paywall() async {
    if (!_day0PaywallPending || !_day0PaywallReady || _day0PaywallChecking) {
      return;
    }
    _day0PaywallChecking = true;
    try {
      final hasAccess = await widget.subscriptionService.hasFullAccess;
      if (!mounted) return;
      if (hasAccess) {
        _day0PaywallPending = false;
        return;
      }
      // Covered now (or while the entitlement was being read): try again when
      // Home is visible again.
      if (!_homeVisible) return;
      final claimed = await widget.storageService
          .claimOneTimeFlag(StorageService.day0PaywallFlag);
      _day0PaywallPending = false;
      if (!claimed || !mounted) return;
      _pushPremium(context,
          source: AnalyticsService.paywallSourceDay0AfterClimb);
    } catch (_) {
      _day0PaywallPending = false;
    } finally {
      _day0PaywallChecking = false;
    }
  }

  void _refreshAfterDailyTest() {
    if (!mounted) return;
    _loadTodaysDailyTest();
    _loadClimb();
    _loadWeakSpots();
  }

  void _onAccessChanged(bool hasFullAccess) {
    if (!mounted) return;
    setState(() => _hasFullAccess = hasFullAccess);
  }

  /// Reads whatever today's Daily Test state already is — never triggers
  /// generation itself (that's DailyTestService.getTodaysSet's job, only
  /// called once the user actually opens Daily Test). Fails open to "not
  /// started" on a storage error, same posture as every other best-effort
  /// read in this app (theme, profile, session cap).
  Future<void> _loadTodaysDailyTest() async {
    final generation = ++_dailyLoadGeneration;
    try {
      final set = await widget.storageService.getDailyTestSetForToday();
      if (!mounted || generation != _dailyLoadGeneration) return;
      setState(() {
        _todaysDailyTest = set;
        _loadingToday = false;
      });
    } catch (_) {
      if (!mounted || generation != _dailyLoadGeneration) return;
      setState(() {
        _todaysDailyTest = null;
        _loadingToday = false;
      });
    }
  }

  /// The 2-3 most frequent weak spots (PRD v2 §13.5 item 4) — same
  /// aggregation ReviewScreen's own "Most frequent" sort already reads,
  /// just capped tighter. Fails open to an empty list on a storage error,
  /// which reads identically to "no weak spots yet" — the section simply
  /// doesn't render either way (see build()).
  Future<void> _loadWeakSpots() async {
    try {
      final spots = await widget.storageService.getWeakSpots(
        limit: 3,
        sortOrder: ReviewSortOrder.frequent,
      );
      int? total;
      try {
        final stats = await widget.storageService.getTopicStats();
        total = stats.values.fold<int>(0, (sum, s) => sum + s.weakSpotCount);
      } catch (_) {
        // The count is a label; the cards still show.
      }
      if (!mounted) return;
      setState(() {
        _weakSpots = spots;
        _weakSpotTotal = math.max(total ?? 0, spots.length);
        _loadingWeakSpots = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weakSpots = const [];
        _loadingWeakSpots = false;
      });
    }
  }

  Future<void> _openDailyTest(BuildContext context) async {
    if (_dailyFlowActive) return;
    // M16: a zoom jumps to its last frame.
    _zoom.dailyTestOpened();
    _dailyFlowActive = true;
    ++_climbLoadGeneration;
    widget.analyticsService
        .modeSelected(AnalyticsService.modeDailyTest, themeId: _monthThemeId);
    final navigator = Navigator.of(context);
    final result = await navigator.push<(DailyTestSet, Map<String, String>)>(
      MaterialPageRoute(
        builder: (_) => DailyTestScreen(
          analyticsService: widget.analyticsService,
          onFinished: (set, answers) => navigator.pop((set, answers)),
          dailyTestService: _dailyTestService,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      final resultRoute = MaterialPageRoute<void>(
        builder: (_) => DailyTestResultScreen(
          dailyTestSet: result.$1,
          answers: result.$2,
          analyticsService: widget.analyticsService,
          onCompletionSaved: () {
            if (!mounted) return;
            _pendingClimbDay = result.$1.day;
            _refreshAfterDailyTest();
          },
          dailyTestService: _dailyTestService,
        ),
      );
      await navigator.push(resultRoute);
      // push's future resolves at pop, before the reverse transition finishes.
      await resultRoute.completed;
    }
    if (!mounted) return;
    _dailyFlowActive = false;
    _refreshAfterDailyTest();
  }

  /// Replays the already-completed set through the same result screen a
  /// live finish would reach — reusing it rather than a second "summary"
  /// screen. [DailyTestResultScreen] itself skips re-marking completion
  /// when the set it's given is already completed (see its own doc
  /// comment), so viewing this again doesn't re-write anything.
  void _openDailyTestResult(BuildContext context, DailyTestSet set) {
    _zoom.dailyTestOpened();
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => DailyTestResultScreen(
              dailyTestSet: set,
              answers: set.answers ?? const {},
              analyticsService: widget.analyticsService,
              dailyTestService: _dailyTestService,
            ),
          ),
        )
        .then((_) => _refreshAfterDailyTest());
  }

  void _openTopicPractice(BuildContext context) {
    // Gated by entitlement (PRD v2 §12.2/§12.3): free tier doesn't include
    // Topic Practice at all — a locked tap goes to the Premium screen
    // instead of ever reaching the real screen, same "no fake it"
    // reasoning as the daily session cap already applies to generation
    // itself.
    if (!_hasFullAccess) {
      _openPremium(context);
      return;
    }
    widget.analyticsService.modeSelected(AnalyticsService.modeTopic);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TopicPracticeScreen(
              claudeService: widget.claudeService,
              storageService: widget.storageService,
              analyticsService: widget.analyticsService,
              subscriptionService: widget.subscriptionService,
            ),
          ),
        )
        .then((_) => _loadWeakSpots());
  }

  /// Unlocked: opens the same weak-spot detail flow Review uses. Locked:
  /// opens the Premium screen naming this specific weak spot — the first
  /// real caller of [PremiumScreen.sourceContext] (added in B-structure-1,
  /// unused until now).
  void _openWeakSpot(BuildContext context, WeakSpot spot) {
    if (!_hasFullAccess) {
      _openPremium(context, sourceContext: humanizeSlug(spot.errorType));
      return;
    }
    final topic = kTopics.firstWhere(
      (t) => t.id.name == spot.topicId,
      orElse: () => kTopics.first,
    );
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => WeakSpotDetailScreen(
              topic: topic,
              spot: spot,
              claudeService: widget.claudeService,
              storageService: widget.storageService,
              analyticsService: widget.analyticsService,
              subscriptionService: widget.subscriptionService,
            ),
          ),
        )
        .then((_) => _loadWeakSpots());
  }

  /// Single entry point to the merged Premium screen (PRD v2 §13.1) —
  /// reached from the locked Topic Practice card, a locked weak-spot row,
  /// or the quiet Premium row below. Logs the same `mode_selected` event
  /// every time now that all three land on the same screen.
  void _openPremium(BuildContext context, {String? sourceContext}) {
    widget.analyticsService.modeSelected(AnalyticsService.modePremium);
    _pushPremium(
      context,
      source: AnalyticsService.paywallSourceHome,
      sourceContext: sourceContext,
    );
  }

  /// The push itself, shared with the paywall Home opens on its own, which is
  /// not a user's choice of mode and so logs no `mode_selected`.
  void _pushPremium(
    BuildContext context, {
    required String source,
    String? sourceContext,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          analyticsSource: source,
          subscriptionService: widget.subscriptionService,
          sourceContext: sourceContext,
        ),
      ),
    );
  }

  // "Good {morning/afternoon/evening}, {name}" — same "$word, $name"
  // shape the old fixed "Welcome back, $name" copy always used, generalized
  // to a time-of-day word instead of a constant one, plus the one new case
  // that copy never needed: an empty name (`userName` is a required
  // `String`, never `null`, but nothing stops it being empty) renders the
  // greeting word alone, no dangling ", ". Built by HomeGreeting, which
  // also moves the name to a line of its own when one line does not fit.
  //
  // The time-of-day word is computed fresh on every build rather than cached in state — Home
  // already rebuilds for other reasons (Daily Test/weak-spot loads,
  // entitlement changes), so this rides along on those instead of needing
  // its own refresh mechanism. It intentionally does *not* refresh purely
  // from time passing while the app sits open with nothing else changing —
  // see docs/build-log.md for why that gap is accepted here rather than
  // patched with a new lifecycle hook or a Timer.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 1.2.0 Home (docs/design/1.2.0/CLAUDE-CODE-BRIEF.md, "Home"): the
    // brand and the greeting sit in the page and scroll with it, so the app
    // bar is only the status bar's height (page-coloured; content passes
    // under it).
    return BrandScaffold(
      isTabRoot: true,
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      ),
      children: [
        // Keep the small Home body mounted while covered/scrolled so the
        // mountain retains the pre-completion position and can be revealed.
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Semantics(
            container: true,
            header: true,
            child: BrandWordmark(
              style: theme.textTheme.displaySmall?.copyWith(
                letterSpacing: -1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // PRD v2 §11: an avatar next to the greeting, not floating
          // elsewhere on the page, so it reads as "whose home screen this
          // is" rather than a decorative icon. Greeting leads on the left,
          // avatar pinned to the far right edge — `spaceBetween` with a
          // `Flexible` (not `Expanded`) text so the avatar always lands
          // flush against the trailing edge while a long name never pushes
          // it off the row. The greeting is two lines ("Good evening," over
          // the name, the brief's layout); the name wraps rather than being
          // cut off, and the `Row` (no fixed height) grows to fit whichever
          // of the two is taller.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: HomeGreeting(
                  word: timeOfDayGreeting(widget.clock()),
                  name: widget.userName,
                  // 22 pt at Medium (owner, after Batch 3: larger): above
                  // the 20 pt section titles, below the name (24) and the
                  // brand (34). Derived from titleLarge so it follows the
                  // text size setting.
                  style: theme.textTheme.titleLarge
                      ?.withWeight(FontWeight.w600)
                      .copyWith(
                          fontSize:
                              (theme.textTheme.titleLarge?.fontSize ?? 20) *
                                  HomeScreen.greetingScale,
                          letterSpacing: -0.3,
                          color: colorScheme.onSurfaceVariant),
                  nameStyle: theme.textTheme.headlineSmall
                      ?.withWeight(FontWeight.w900)
                      .copyWith(
                          letterSpacing: -0.5, color: colorScheme.onSurface),
                ),
              ),
              // 8 pt (the mockup's 6, was 12): at 320 pt and Large text
              // "Good afternoon," (172.2 pt) then fits beside the hero
              // (176 pt) instead of breaking by a fraction of a point.
              const SizedBox(width: 8),
              _HeroButton(avatar: widget.avatar, onTap: widget.onAvatarTap),
            ],
          ),
          const SizedBox(height: 12),
          KeyedSubtree(
            key: HomeScreen.dailyTestCardKey,
            child: _DailyTestCard(
              key: _todayKey,
              loading: _loadingToday,
              dailyTestSet: _todaysDailyTest,
              onStart: () => _openDailyTest(context),
              onViewResult: (set) => _openDailyTestResult(context, set),
            ),
          ),
          const SizedBox(height: 24),
          _buildClimb(context),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Topic practice',
            trailing: _hasFullAccess
                ? null
                : const LockedPremiumPill(showChevron: false),
          ),
          const SizedBox(height: 12),
          _TopicStrip(onOpen: () => _openTopicPractice(context)),
          // Deliberately no empty state here (PRD v2 §13.5 item 4) — the
          // Review tab already covers "no weak spots yet", and repeating
          // that message on Home too would just be noise on a screen
          // that's supposed to lead with what's actually there.
          if (!_loadingWeakSpots && _weakSpots.isNotEmpty) ...[
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Your weak spots',
              trailing: _CountBadge(
                _weakSpotTotal == 1
                    ? '1 weak spot'
                    : '$_weakSpotTotal weak spots',
              ),
            ),
            const SizedBox(height: 12),
            for (final spot in _weakSpots) ...[
              WeakSpotCard(
                topic: kTopics.firstWhere(
                  (t) => t.id.name == spot.topicId,
                  orElse: () => kTopics.first,
                ),
                spot: spot,
                locked: !_hasFullAccess,
                // The mockup's Home card with its action line (owner,
                // Batch 5); the same tap as before.
                withAction: true,
                onTap: () => _openWeakSpot(context, spot),
              ),
              if (spot != _weakSpots.last) const SizedBox(height: 12),
            ],
            // 1.2.0 (owner decision Q15): the quiet Premium row that used to
            // end Home is replaced by a pointer to Review's free daily
            // practice. Free users only (premium has no quota to describe),
            // and only when there is a weak spot to choose.
            if (!_hasFullAccess) ...[
              const SizedBox(height: 16),
              _ReviewCallout(onTap: widget.onGoToReview),
            ],
          ],
        ]),
      ],
    );
  }

  Widget _buildClimb(BuildContext context) {
    final days = DateTime(_climbMonth.year, _climbMonth.month + 1, 0).day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The card carries the title on its plaque (design decision K3);
        // until the month's progress has loaded there is no card, so the
        // title stands alone above the progress indicator or the retry.
        if (_climbSteps == null) ...[
          Text('Mountain of Learning',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
        ],
        if (_climbSteps != null)
          // M6: during a zoom a tap on the card jumps it to its last frame;
          // otherwise the card takes no taps (a tappable card is parked for
          // 1.2, D5).
          GestureDetector(
              onTap: _zoom.running ? _zoom.skip : null,
              excludeFromSemantics: true,
              child: ClimbCard(
                key: _mountainKey,
                month: _climbMonth,
                steps: _climbSteps!,
                days: days,
                chipOpacity: _zoom.active ? _chipOpacity : null,
                mountain: MonthlyMountain(
                  key: ValueKey(_climbMonth),
                  days: days,
                  completedDays: _climbSteps!,
                  avatar: widget.avatar ?? Avatar.values.first,
                  theme: _climbTheme,
                  onMotionEnd: _onMountainMotionEnd,
                  zoom: _zoom.active ? _zoom.progress : null,
                  zoomCrossFade: _zoom.crossFade,
                  debugHop: _debugHop,
                  labelAvoid: (width) => ClimbCard.chipRects(context,
                      width: width,
                      month: _climbMonth,
                      steps: _climbSteps!,
                      days: days),
                ),
                // Under the window, not over the scene (design decision D9).
                scoreBar: ClimbScoreBar(
                  score: _climbScore,
                  maxScore: MonthlyMedalRules.maxScore(
                      _climbMonth.year, _climbMonth.month),
                  thresholds: {
                    for (final tier in MedalTier.values)
                      tier: MonthlyMedalRules.threshold(
                          _climbMonth.year, _climbMonth.month, tier),
                  },
                ),
              )),
        if (_loadingClimb)
          const LinearProgressIndicator(
              semanticsLabel: 'Loading monthly progress'),
        if (_climbLoadFailed) ...[
          const Text('Couldn’t load your monthly progress.',
              textAlign: TextAlign.center),
          TextButton(
              onPressed: _loadClimb, child: const Text('Retry progress')),
        ],
      ],
    );
  }
}

/// The avatar beside the greeting (the brief's hero picker): the user's
/// avatar, opening the avatar picker. A Hero, so it flies to the picker's
/// centred avatar and back. No edit badge (owner, after the Batch 3 device
/// check): the avatar alone is the control, named "Change your avatar".
class _HeroButton extends StatelessWidget {
  final Avatar? avatar;
  final VoidCallback? onTap;

  const _HeroButton({required this.avatar, required this.onTap});

  /// The brief's 108 pt hero; AvatarTile is sized by half its side.
  static const _size = 108.0;

  /// Light mode's ground shadow under the hero (Batch 7): the only shadow
  /// there, so it is drawn darker and tighter than Batch 6's 88 x 16 pt at
  /// 32 % with sigma 6, which sat on top of the avatar's own ellipse.
  static const _groundWidth = 80.0;
  static const _groundHeight = 16.0;
  static const _groundBlur = 5.0;
  static const _groundBottom = 4.0;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final backlight = palette.heroBacklight;
    final ground = palette.heroGround;
    // A node of its own (container): without it the label and the button
    // flag would merge into the Home list's node above.
    return Semantics(
      container: true,
      button: true,
      label: 'Change your avatar',
      child: InkWell(
        // Matches AvatarTile's own corner rounding (radius * 0.6).
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_size / 2 * 0.6),
        ),
        onTap: onTap,
        child: SizedBox.square(
          dimension: _size,
          child: Stack(clipBehavior: Clip.none, children: [
            // Dark mode's glow (owner, Batch 5–6): a radial gradient inside
            // the hero's own square, fading to nothing at its edge, so it is
            // never clipped by the screen edge and never reaches the
            // greeting. Light mode has none since Batch 7: only the ground
            // shadow below. Behind the Hero, not in it, so the flight to the
            // picker carries only the avatar.
            if (backlight != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    key: HomeScreen.heroBacklightKey,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(0, .25),
                        radius: .5,
                        colors: [
                          backlight,
                          backlight.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // Light mode's ground shadow (Batch 6, stronger in Batch 7): a
            // blurred ellipse under the hero's feet, 80 x 16 pt, its visible
            // blur (about 2 sigma) inside the square's sides and about 6 pt
            // below it — inside the 8 pt gap to the greeting, the 12 pt gap
            // to the Daily Test card, and well inside the screen. It replaces
            // the avatar's own ellipse here (`groundShadow: false` below),
            // so the feet get one shadow, not two.
            if (ground != null)
              Positioned(
                key: HomeScreen.heroGroundKey,
                left: (_size - _groundWidth) / 2,
                bottom: _groundBottom,
                width: _groundWidth,
                height: _groundHeight,
                child: IgnorePointer(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                        sigmaX: _groundBlur, sigmaY: _groundBlur),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: ground,
                        borderRadius: const BorderRadius.all(
                          Radius.elliptical(
                              _groundWidth / 2, _groundHeight / 2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            // `homeAvatarHeroTag` is its own tag, distinct from Settings'
            // `avatarHeroTag` — see that constant's doc comment for why
            // sharing one tag across both entry points would crash.
            Hero(
              tag: homeAvatarHeroTag,
              child: AvatarTile(
                avatar: avatar,
                radius: _size / 2,
                groundShadow: ground == null,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A section's title with an optional tag at its end.
class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: SectionTitle(title)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing!],
      ],
    );
  }
}

/// A small count on the info surface (the weak spots heading).
class _CountBadge extends StatelessWidget {
  final String text;

  const _CountBadge(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall
            ?.withWeight(FontWeight.w800)
            .copyWith(color: colorScheme.onSecondaryContainer),
      ),
    );
  }
}

/// The Daily Test card (PRD v2 §13.5 item 2; 1.2.0 brief, "Home"): its own
/// orange card, separate from the mountain. Two states only, read from what
/// is already cached ([DailyTestSet.isCompleted] and the persisted
/// [DailyTestSet.answers]): not started — the question count and "Start
/// daily test"; done — the real score and "Review results". No progress bar.
/// The navy button is the card's one tap target and calls the same two
/// handlers the whole card used to.
///
/// Text on the orange is `onPrimary` (#241200) in both themes: light text
/// on the dark-mode orange measures under 2.4:1.
class _DailyTestCard extends StatelessWidget {
  final bool loading;
  final DailyTestSet? dailyTestSet;
  final VoidCallback onStart;
  final ValueChanged<DailyTestSet> onViewResult;

  const _DailyTestCard({
    super.key,
    required this.loading,
    required this.dailyTestSet,
    required this.onStart,
    required this.onViewResult,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final ink = colorScheme.onPrimary;
    final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCardRadius));

    if (loading) {
      return Card(
        color: colorScheme.primary,
        shape: shape,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: ink),
            ),
          ),
        ),
      );
    }

    final set = dailyTestSet;
    final completed = set != null && set.isCompleted;
    final String title, description, amount, unit, action;
    if (completed) {
      final score = computeDailyTestScore(set.questions, set.answers ?? {});
      title = 'Daily test complete.';
      description = 'New test tomorrow. Review today’s answers.';
      amount = '${score.correct}/${score.total}';
      unit = 'correct';
      action = 'Review results';
    } else {
      title = 'Your next step.';
      description = 'Take today’s test and move your hero forward.';
      amount = '${set?.questions.length ?? DailyTestSet.questionCount}';
      unit = 'questions';
      action = 'Start daily test';
    }
    final small = theme.textTheme.labelSmall?.copyWith(color: ink);

    return Card(
      color: colorScheme.primary,
      shape: shape,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A Wrap, not a Row: at a large text size on a narrow screen
            // "Free every day" moves under the label instead of overflowing.
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('DAILY TEST',
                    style: small
                        ?.withWeight(FontWeight.w800)
                        .copyWith(letterSpacing: 0.8)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 13, color: ink),
                    const SizedBox(width: 4),
                    Flexible(child: Text('Free every day', style: small)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(color: ink)),
                      const SizedBox(height: 7),
                      Text(description,
                          style:
                              theme.textTheme.bodySmall?.copyWith(color: ink)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  constraints: const BoxConstraints(minWidth: 67),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: palette.brandTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // The label above the value (owner, after Batch 3), in
                  // labelMedium (12/700 at Medium), one step up from the
                  // card's 11 pt labels; the value in headlineMedium.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(unit,
                          style: theme.textTheme.labelMedium
                              ?.copyWith(color: ink)),
                      const SizedBox(height: 6),
                      Text(amount,
                          style: theme.textTheme.headlineMedium
                              ?.copyWith(color: ink, height: 1)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: completed ? () => onViewResult(set) : onStart,
              child: Row(
                children: [
                  Expanded(child: Text(action)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Topic Practice on Home (1.2.0 brief): one card with a line of copy, a
/// sideways strip of the real topics ([kTopics]) and "Explore all topics".
/// Every tile and the link open the existing Topic Practice screen through
/// [onOpen] — the same entry point the old single card used, so a free
/// user still gets the paywall there (owner decisions Q9, Q10: no new
/// route, no scroll arrows). The strip scrolls sideways only.
class _TopicStrip extends StatelessWidget {
  final VoidCallback onOpen;

  const _TopicStrip({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'Pick a topic. Build confidence where you need it.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            SingleChildScrollView(
              key: _topicStripKey,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 15, 18, 8),
              // Every tile as tall as the tallest: a long topic name at a
              // large text size wraps instead of being cut off.
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final topic in kTopics) ...[
                      _TopicTile(topic: topic, onTap: onOpen),
                      if (topic != kTopics.last) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: TextButton.icon(
                  onPressed: onOpen,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: const Text('Explore all topics'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _topicStripKey = ValueKey('home_topic_strip');

class _TopicTile extends StatelessWidget {
  final Topic topic;
  final VoidCallback onTap;

  const _TopicTile({required this.topic, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final link = colorScheme.secondary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
      side: BorderSide(color: colorScheme.outlineVariant),
    );
    return SizedBox(
      width: 146,
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 118),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(topic.icon, size: 21, color: link),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          topic.title,
                          style: theme.textTheme.titleSmall
                              ?.withWeight(FontWeight.w800)
                              .copyWith(
                                  height: 1.25, color: colorScheme.onSurface),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(Icons.north_east_rounded, size: 14, color: link),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The end of Home for a free user (1.2.0, owner decision Q15), replacing
/// the quiet Premium row: one free weak spot practice a day lives in
/// Review, and this switches to the Review tab. The whole card is the one
/// tap target and one semantics button (owner, Batch 5); "Go to Review" is
/// its label, not a second button.
class _ReviewCallout extends StatelessWidget {
  final VoidCallback? onTap;

  const _ReviewCallout({required this.onTap});

  static const _radius = 18.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onInfo = colorScheme.onSecondaryContainer;
    final link = colorScheme.secondary;
    return Semantics(
      container: true,
      button: true,
      child: Material(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(_radius),
        child: InkWell(
          key: HomeScreen.reviewCalloutKey,
          borderRadius: BorderRadius.circular(_radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child:
                      Icon(Icons.auto_awesome_rounded, size: 19, color: onInfo),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('One free practice. Every day.',
                          style: theme.textTheme.labelLarge
                              ?.copyWith(color: onInfo)),
                      const SizedBox(height: 5),
                      Text(
                        'Choose one weak spot in Review.\n'
                        'Get AI feedback on your answers.',
                        style:
                            theme.textTheme.bodySmall?.copyWith(color: onInfo),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Flexible(
                            child: Text('Go to Review',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: link)),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded,
                              size: 15, color: link),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
