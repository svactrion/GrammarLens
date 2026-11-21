import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/rendering.dart' show RenderAbstractViewport;

import '../app_colors.dart';
import '../l10n/l10n.dart';
import '../models/daily_test_completion.dart';
import '../utils/haptics.dart';
import '../widgets/daily_test_card.dart';
import '../widgets/home_practice.dart';
import '../widgets/rest_reminder_row.dart';
import '../widgets/rest_scene.dart';
import '../widgets/score_capsule.dart';
import '../widgets/ticket.dart';
import '../data/topics.dart';
import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../models/daily_test_set.dart';
import '../models/error_entry.dart';
import '../models/medal_tier.dart';
import '../models/pending_climb.dart';
import '../models/review_sort_order.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/daily_test_service.dart';
import '../services/month_transition.dart';
import '../services/monthly_medal_rules.dart';
import '../services/reminder_controller.dart';
import 'reminder_soft_ask.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../motion.dart';
import '../utils/greeting.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/brand_wordmark.dart';
import '../widgets/home_greeting.dart';
import '../widgets/launch_splash.dart';
import '../widgets/month_card_sheet.dart';
import '../widgets/monthly_climb/climb_card.dart';
import '../widgets/monthly_climb/climb_camera.dart';
import '../widgets/skeleton.dart';
import '../widgets/error_state.dart';
import '../widgets/floating_nav_shell.dart';
import '../widgets/monthly_climb/climb_debug_month_card.dart';
import '../widgets/monthly_climb/climb_zoom.dart';
import '../widgets/monthly_climb/monthly_mountain.dart';
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

  /// Switches the bottom-nav to the Review tab (the Review call-out that
  /// ends Home for a free user, 1.2.0 Q15). Nullable for the same reason as
  /// the Profile hook below: the tab switch lives in app.dart.
  final VoidCallback? onGoToReview;

  /// Switches to the Profile tab (the score capsule's tap: the month's
  /// progress, V14).
  final VoidCallback? onOpenProfile;

  /// Bumped by a `grammarlens://daily-test` link (a widget or reminder
  /// tap): Home opens today's Daily Test, or stays on Home when it is done.
  final ValueListenable<int>? dailyTestLinks;

  /// The reminder settings (N01, V24's switch); Home makes its own when
  /// none is given.
  final ReminderController? reminders;
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

  /// The first climb (V12) already played the first run's camera: Home
  /// still treats this as the first run's Home (no month card, M2) but does
  /// not zoom again.
  final bool firstRunZoomPlayed;

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
    this.onGoToReview,
    this.onOpenProfile,
    this.dailyTestLinks,
    this.reminders,
    this.initialPendingClimb,
    this.onInitialPendingClimbTaken,
    this.offerDay0Paywall = false,
    this.onOfferDay0PaywallTaken,
    this.firstRunZoom = false,
    this.firstRunZoomPlayed = false,
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

  /// The Daily Test card, for tests that measure or tap it.
  static const capsuleKey = ValueKey('home_score_capsule');
  static const restSceneKey = ValueKey('home_rest_scene');

  /// The rest scene's fade over Home after the day's step (fix round 6);
  /// present only while it fades in.
  static const restFadeKey = ValueKey('home_rest_fade');

  /// PW05r's practice, opened from the rest scene's paywall (tests).
  static const restPractiseKey = ValueKey('home_rest_practise');
  static const ticketKey = ValueKey('home_ticket');

  /// Fix round 6, item 1 (SPEC §1.8, v14): how long the pawn stands on the
  /// day's new step, with nothing else moving, before the rest scene comes.
  static const restBeat = Duration(seconds: 1);

  /// The cross-fade from Home to the rest scene after [restBeat]
  /// (`AppMotion.slow`; under Reduce Motion `AppMotion.fast`).
  static Duration restReveal(BuildContext context) =>
      AppMotion.entrance(context, AppMotion.slow);
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

  /// V24f's "· N days free": the store's trial on the paywall's preselected
  /// plan for this user, read once the free rest scene shows.
  int? _restTrialDays;
  bool _restTrialRequested = false;

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

  /// INTEGRATE 3b: the climb section (the card, or its skeleton) and the
  /// mountain window's height fitted to it on first view.
  final _climbSectionKey = GlobalKey();
  double _climbWindowHeight = ClimbCamera.fullWindowHeight;
  double? _navClearance;
  (double, int, double)? _climbFitInputs;
  bool _dailyFlowActive = false;

  /// A Daily Test link waits for today's set to be read.
  bool _dailyTestLinkPending = false;

  late final ReminderController _reminders =
      widget.reminders ?? ReminderController(storage: widget.storageService);

  /// N01 should open once Home is quiet (TASK-widgets fixed decision 5):
  /// the rest scene appeared, or a second Daily Test was finished.
  bool _softAskQueued = false;
  bool _restSceneSeen = false;

  /// A check of [_maybeShowSoftAsk] is scheduled for the end of this frame
  /// (fix round 3, A2: N01 opens on the first frame the rest scene is on
  /// screen, whatever path led there).
  bool _softAskCheckScheduled = false;
  String? _pendingClimbDay;

  /// Fix round 6, item 1: the rest scene waits for the day's step. Set when
  /// a Daily Test's completion is saved (with [_pendingClimbDay]); while it
  /// is set on a rest day, Home keeps its normal content: the step is
  /// pending (Home not visible yet), walking, or followed by what a step
  /// brings (a save point's light and name, a month card), then
  /// [HomeScreen.restBeat], then the cross-fade. Cleared when the scene has
  /// come, when there is no step to show, and when the user leaves Home
  /// once the walk has begun (the scene is then simply there on return).
  bool _restWaitsForStep = false;

  /// The pawn has landed and the mountain has nothing more to show for it
  /// (`MonthlyMountain.onArrivalEnd`); the beat starts once Home is quiet.
  bool _stepArrived = false;

  /// [HomeScreen.restBeat], then the cross-fade to the rest scene.
  late final AnimationController _restArrival;

  /// The rest scene's opacity over Home during [_restArrival]'s second part.
  Animation<double> _restOpacity = kAlwaysDismissedAnimation;

  /// Whether the cross-fade's part of [_restArrival] has begun: both Home
  /// and the rest scene are built.
  bool _restRevealing = false;

  /// Home's normal content, kept as one subtree (its scroll position, the
  /// mountain) when the rest scene fades in over it.
  final _homeContentKey = GlobalKey();

  /// The rest scene, one subtree from the first frame of its fade to the
  /// frame it stands alone (its loops do not restart).
  final _restContentKey = GlobalKey();

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

  List<WeakSpot> _weakSpots = const [];

  /// Today's practice use (V14's ticket, H04's sessions, V24's rule):
  /// free practices started today, and practice sessions today.
  int _freeUsedToday = 0;
  int _sessionsToday = 0;

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
    _restArrival = AnimationController(vsync: this)
      ..addListener(_onRestArrivalTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _endRestWait();
      });
    WidgetsBinding.instance.addObserver(this);
    final initialClimb = widget.initialPendingClimb;
    if (initialClimb != null && initialClimb.step > 0) {
      _restWaitsForStep = true;
      _pendingClimbDay = initialClimb.day;
      _pendingClimbStep = initialClimb.step;
    }
    widget.onInitialPendingClimbTaken?.call();
    _day0PaywallPending = widget.offerDay0Paywall;
    widget.onOfferDay0PaywallTaken?.call();
    if ((widget.firstRunZoom && !widget.firstRunZoomPlayed) ||
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
    widget.dailyTestLinks?.addListener(_onDailyTestLink);
    _reminders.addListener(_onRemindersChanged);
    _reminders.load();
    _loadTodaysDailyTest();
    _loadClimb();
    _loadWeakSpots();
    _loadPracticeUsage();
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
    widget.dailyTestLinks?.removeListener(_onDailyTestLink);
    _reminders.removeListener(_onRemindersChanged);
    if (widget.reminders == null) _reminders.dispose();
    widget.subscriptionService.removeAccessListener(_onAccessChanged);
    _day0PaywallTimer?.cancel();
    _restArrival.dispose();
    _zoom.removeListener(_onZoomChanged);
    _zoom.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A route was pushed above Home, or its tab's tickers stopped, after
    // the day's step began: the rest scene no longer waits (a build
    // follows).
    _dropRestWaitIfLeft(rebuild: false);
    // A route above Home closed, or Home's visibility changed: N01 may be
    // waiting for exactly this (A2).
    _scheduleSoftAskCheck();
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
    if (oldWidget.dailyTestLinks != widget.dailyTestLinks) {
      oldWidget.dailyTestLinks?.removeListener(_onDailyTestLink);
      widget.dailyTestLinks?.addListener(_onDailyTestLink);
    }
    if (oldWidget.active && !widget.active) {
      _dropRestWaitIfLeft(rebuild: false);
    }
    if (!oldWidget.active && widget.active && _pendingClimbDay != null) {
      _loadClimb();
    }
    if (!oldWidget.active && widget.active) {
      // Home is the visible tab again: what another tab did today (the free
      // ticket used on a practice from Review, A2) shows now, not at the
      // next resume.
      _loadTodaysDailyTest();
      _loadPracticeUsage();
      _scheduleSoftAskCheck();
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
    if (state == AppLifecycleState.paused) _dropRestWaitIfLeft();
    if (state == AppLifecycleState.resumed) {
      // Refresh greeting and cached day after midnight/timezone changes.
      // This is a local read; resuming never generates another question set.
      setState(() => _loadingToday = true);
      _loadTodaysDailyTest();
      _loadClimb();
      _loadWeakSpots();
      _loadPracticeUsage();
      _showDay0Paywall();
      _scheduleSoftAskCheck();
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
        _stepArrived = false;
      } else if (!_climbAnimating) {
        // No step to show: the rest scene has nothing to wait for.
        if (!_stepArrived) _endRestWait();
        _armDay0Paywall(Duration.zero);
      }
    } catch (_) {
      if (!mounted || generation != _climbLoadGeneration) return;
      setState(() {
        _loadingClimb = false;
        _climbLoadFailed = true;
      });
      if (!_climbAnimating) {
        if (!_stepArrived) _endRestWait();
        _armDay0Paywall(Duration.zero);
      }
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
    // The card and its zoom were the last thing after the day's step.
    _tryRestArrival();
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
        l10n: routeContext.l10n,
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
    _scheduleSoftAskCheck();
  }

  /// The pawn has landed and a save point it reached has shown its light
  /// and its name: on a rest day the beat before the rest scene can start.
  void _onMountainArrivalEnd() {
    if (!_restWaitsForStep) return;
    if (!_restDay) {
      // An ordinary day: nothing waits for this step.
      _restWaitsForStep = false;
      return;
    }
    _stepArrived = true;
    _tryRestArrival();
  }

  /// Whether the rest scene is held back for the day's step (fix round 6).
  bool get _restHeld => _restWaitsForStep && _restDay;

  /// Starts [HomeScreen.restBeat] and the cross-fade once the day's step
  /// and everything after it have ended and nothing is above Home. Asked
  /// when the pawn's arrival ends and when a month card closes.
  void _tryRestArrival() {
    if (!mounted || !_restWaitsForStep || !_stepArrived) return;
    if (_restArrival.isAnimating || _climbAnimating) return;
    if (_monthCardShowing || _pendingMonthCard != null || _zoom.active) return;
    if (!_restDay) {
      _restWaitsForStep = false;
      _stepArrived = false;
      return;
    }
    if (!_homeVisible) {
      _endRestWait();
      return;
    }
    final reveal = HomeScreen.restReveal(context);
    final total = HomeScreen.restBeat + reveal;
    _restOpacity = CurvedAnimation(
        parent: _restArrival,
        curve: Interval(
            HomeScreen.restBeat.inMicroseconds / total.inMicroseconds, 1,
            curve: AppMotion.enter));
    _restArrival
      ..duration = total
      ..forward(from: 0);
  }

  /// The beat has passed: from here Home and the rest scene are both built
  /// and the scene fades in.
  void _onRestArrivalTick() {
    final total = _restArrival.duration;
    if (total == null || !mounted) return;
    final revealing = _restArrival.isAnimating &&
        _restArrival.value * total.inMicroseconds >=
            HomeScreen.restBeat.inMicroseconds;
    if (revealing != _restRevealing) {
      setState(() => _restRevealing = revealing);
    }
  }

  /// The rest scene no longer waits: it has faded in, there was no step to
  /// show, or the user left Home. With [rebuild] false the caller is
  /// already in a build.
  void _endRestWait({bool rebuild = true}) {
    if (!_restWaitsForStep && !_stepArrived && !_restRevealing) return;
    _restWaitsForStep = false;
    _stepArrived = false;
    _restRevealing = false;
    if (_restArrival.isAnimating || _restArrival.value != 0) {
      _restArrival.stop();
      _restArrival.value = 0;
    }
    if (rebuild && mounted) setState(() {});
    // N01 follows the scene (A2): asked once it is fully on screen.
    _scheduleSoftAskCheck();
  }

  /// The user left Home (another tab, a route above, the app in the
  /// background) after the day's step had begun to walk: the rest scene is
  /// shown on return and the step is not replayed. A step that has not
  /// begun (Home was not visible when the test was saved) still waits for
  /// Home. A month card Home opened itself is not leaving.
  void _dropRestWaitIfLeft({bool rebuild = true}) {
    if (!_restWaitsForStep || !mounted) return;
    final begun = _climbAnimating || _stepArrived || _restArrival.isAnimating;
    if (!begun || _monthCardShowing || _homeVisible) return;
    _endRestWait(rebuild: rebuild);
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
    _loadPracticeUsage();
    _queueSoftAskAfterSecondTest();
  }

  void _onRemindersChanged() {
    if (mounted) setState(() {});
  }

  /// N01 after the second Daily Test: the first one on record was finished
  /// before today.
  Future<void> _queueSoftAskAfterSecondTest() async {
    try {
      if (!_reminders.mayAsk) return;
      final today = await widget.storageService.getDailyTestSetForToday();
      if (today?.isCompleted != true) return;
      final first = await widget.storageService.getFirstDailyTestCompletion();
      final now = widget.clock();
      if (first == null ||
          !first.isBefore(DateTime(now.year, now.month, now.day))) {
        return;
      }
      if (mounted) setState(() => _softAskQueued = true);
    } catch (_) {
      // Storage unavailable: asked another time.
    }
  }

  /// Runs [_maybeShowSoftAsk] at the end of the current frame, once per
  /// frame (A2): after a build that shows the rest scene, when Home becomes
  /// the visible tab, when a route above it closes, on resume and when the
  /// pawn lands. Does nothing when nothing is queued.
  void _scheduleSoftAskCheck() {
    if (_softAskCheckScheduled) return;
    _softAskCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _softAskCheckScheduled = false;
      if (mounted) _maybeShowSoftAsk();
    });
  }

  /// Opens N01 when it is queued and Home is quiet: visible, no flow, no
  /// step walking.
  void _maybeShowSoftAsk() {
    if (!_softAskQueued || !_reminders.mayAsk) return;
    if (!_homeVisible || _climbAnimating || _monthCardShowing) return;
    // Fix round 6: on a rest day N01 follows the delayed rest scene.
    if (_restHeld) return;
    _softAskQueued = false;
    _reminders.askOpened();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _reminders.askClosed();
      if (!mounted || !_reminders.mayAsk) return;
      await showReminderSoftAsk(context,
          controller: _reminders, hero: widget.avatar ?? Avatar.values.first);
    });
  }

  /// Today's free practices and practice sessions (best effort: a failed
  /// read shows the ticket free and no session, as before).
  Future<void> _loadPracticeUsage() async {
    try {
      final free = await widget.storageService.getFreePracticeCountForToday();
      final sessions = await widget.storageService.getSessionCountForToday();
      if (!mounted) return;
      setState(() {
        _freeUsedToday = free;
        _sessionsToday = sessions;
      });
    } catch (_) {}
  }

  /// Every daily right used (SPEC §1.8, V24): today's Daily Test done and
  /// the practice allowance used — the free ticket, or every Premium
  /// session.
  bool get _restDay {
    if (_todaysDailyTest?.isCompleted != true) return false;
    return _hasFullAccess
        ? _sessionsToday >= StorageService.dailySessionLimit
        : _freeUsedToday >= StorageService.freeDailyPracticeLimit;
  }

  /// Today's completed test, graded as the completion grades it.
  DailyTestCompletion? get _todaysCompletion {
    final set = _todaysDailyTest;
    if (set == null || !set.isCompleted) return null;
    return DailyTestCompletion(
      set: set,
      answers: set.answers ?? const {},
      completedAt: set.completedAt ?? widget.clock(),
    );
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
    _openDailyTestFromLink();
  }

  /// A `grammarlens://daily-test` link: today's set is read again (the
  /// link may come right after midnight), then [_openDailyTestFromLink].
  void _onDailyTestLink() {
    if (!mounted) return;
    _dailyTestLinkPending = true;
    setState(() => _loadingToday = true);
    _loadTodaysDailyTest();
  }

  /// Opens the Daily Test a link asked for, once today's set is known:
  /// not when it is done (Home is the answer) or already open.
  void _openDailyTestFromLink() {
    if (!_dailyTestLinkPending || !mounted || _loadingToday) return;
    _dailyTestLinkPending = false;
    if (_dailyFlowActive || _todaysDailyTest?.isCompleted == true) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDailyTest(context);
    });
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
      if (!mounted) return;
      setState(() => _weakSpots = spots);
    } catch (_) {
      if (!mounted) return;
      setState(() => _weakSpots = const []);
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
          hero: widget.avatar,
          userName: widget.userName,
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
          hero: widget.avatar,
          userName: widget.userName,
          dailyTestSet: result.$1,
          answers: result.$2,
          analyticsService: widget.analyticsService,
          onCompletionSaved: () {
            if (!mounted) return;
            _restWaitsForStep = true;
            _stepArrived = false;
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
              hero: widget.avatar,
              userName: widget.userName,
              dailyTestSet: set,
              answers: set.answers ?? const {},
              analyticsService: widget.analyticsService,
              dailyTestService: _dailyTestService,
            ),
          ),
        )
        .then((_) => _refreshAfterDailyTest());
  }

  void _openTopicPractice(BuildContext context, {bool afterPurchase = false}) {
    // Gated by entitlement (PRD v2 §12.2/§12.3): free tier doesn't include
    // Topic Practice at all — a locked tap goes to the Premium screen
    // instead of ever reaching the real screen, same "no fake it"
    // reasoning as the daily session cap already applies to generation
    // itself. Right after a purchase (PW05r) the screen checks the
    // entitlement itself; Home's flag may not have caught up yet.
    if (!_hasFullAccess && !afterPurchase) {
      _openPremium(context);
      return;
    }
    widget.analyticsService.modeSelected(AnalyticsService.modeTopic);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TopicPracticeScreen(
              hero: widget.avatar,
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
    final topic = topicOfWeakSpot(spot.topicId);
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => WeakSpotDetailScreen(
              topic: topic,
              spot: spot,
              hero: widget.avatar,
              claudeService: widget.claudeService,
              storageService: widget.storageService,
              analyticsService: widget.analyticsService,
              subscriptionService: widget.subscriptionService,
            ),
          ),
        )
        .then((_) => _loadWeakSpots());
  }

  /// Today's weak spot for the free rest scene (V24f): the most frequent.
  WeakSpot? get _restWeakSpot => _weakSpots.isEmpty ? null : _weakSpots.first;

  /// V24s → V13r: the paywall rises from the bottom (450 ms spring) with
  /// the rest scene's top; source `rest_scene`. After a trial, PW05r's
  /// "Practise <weak spot>" opens that weak spot's practice straight away
  /// (V18), or the topics without one. Closing it returns to the scene.
  Future<void> _openRestPaywall(BuildContext context) async {
    widget.analyticsService.modeSelected(AnalyticsService.modePremium);
    final spot = _restWeakSpot;
    final reduced = AppMotion.reduced(context);
    final practise = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        transitionDuration: reduced ? AppMotion.fast : AppMotion.sheet,
        reverseTransitionDuration: reduced ? AppMotion.fast : AppMotion.base,
        pageBuilder: (_, __, ___) => PremiumScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          analyticsSource: AnalyticsService.paywallSourceRestScene,
          subscriptionService: widget.subscriptionService,
          rest: PaywallRest(
            theme: _climbTheme,
            weakSpot: spot == null ? null : humanizeSlug(spot.errorType),
            hero: widget.avatar ?? Avatar.values.first,
            name: widget.userName,
          ),
        ),
        transitionsBuilder: (_, animation, __, child) => reduced
            ? FadeTransition(opacity: animation, child: child)
            : SlideTransition(
                position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(
                        parent: animation,
                        curve: AppMotion.spring,
                        reverseCurve: AppMotion.exit)),
                child: child,
              ),
      ),
    );
    if (practise != true || !mounted || !context.mounted) return;
    if (spot == null) {
      _openTopicPractice(context, afterPurchase: true);
      return;
    }
    final topic = topicOfWeakSpot(spot.topicId);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WeakSpotDetailScreen(
          key: HomeScreen.restPractiseKey,
          topic: topic,
          spot: spot,
          hero: widget.avatar,
          claudeService: widget.claudeService,
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          subscriptionService: widget.subscriptionService,
          startPractice: true,
        ),
      ),
    );
    if (mounted) _loadWeakSpots();
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
    final c = AppColors.of(context);
    final l10n = context.l10n;
    final completion = _todaysCompletion;
    final todayPoints = completion == null
        ? null
        : MonthlyMedalRules.score(
            correct: completion.correct, wrong: completion.wrong);
    final capsule = ScoreCapsule(
      key: HomeScreen.capsuleKey,
      points: _climbScore,
      year: _climbMonth.year,
      month: _climbMonth.month,
      today: todayPoints,
      onTap: widget.onOpenProfile,
    );
    final hero = widget.avatar ?? Avatar.values.first;
    _maybeShowSoftAsk();

    // V24 (SPEC §1.8): once every daily right is used, the rest scene
    // replaces Home's content. Fix round 6 (v14): after the day's step and
    // a short beat, not instead of them ([_restWaitsForStep]).
    final restDay = _restDay && _climbSteps != null && completion != null;
    Widget restScene({required bool primary}) {
      if (!_hasFullAccess && !_restTrialRequested) {
        _restTrialRequested = true;
        unawaited(paywallTrialDays(widget.subscriptionService).then((days) {
          if (mounted) setState(() => _restTrialDays = days);
        }));
      }
      final days = DateTime(_climbMonth.year, _climbMonth.month + 1, 0).day;
      // The rest scene replaces the mountain: a step that was still walking
      // never reports its end, so it no longer holds N01 back (A2).
      if (primary) _climbAnimating = false;
      // N01 the first time the rest scene is shown (once the stored answer
      // is known), checked after this frame, when the scene is on screen.
      if (!_restSceneSeen && _reminders.loaded) {
        _restSceneSeen = true;
        if (_reminders.mayAsk) _softAskQueued = true;
      }
      if (_softAskQueued) _scheduleSoftAskCheck();
      // Fix round 3, B1: the scene is full-bleed from the top of the screen
      // (behind the status bar), the night sheet attached under it; no
      // page padding. Light status bar text on the night sky.
      return AnnotatedRegion<SystemUiOverlayStyle>(
        key: _restContentKey,
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          // The night panel's colour (v13, both themes).
          backgroundColor: AppColors.restPanel,
          body: SingleChildScrollView(
            // While it fades in over Home, Home's list still holds the
            // route's primary scroll controller.
            primary: primary,
            child: RestScene(
              key: HomeScreen.restSceneKey,
              theme: _climbTheme,
              days: days,
              steps: _climbSteps!,
              hero: hero,
              name: widget.userName,
              clock: widget.clock,
              capsule: capsule,
              reminder: RestReminderRow(controller: _reminders, hero: hero),
              // V24's done tiles (fix round 5, its own board again): "4/5 ·
              // +9 points" and "5/5 sessions" (V24f shows the used ticket
              // instead).
              testLine: l10n.restTestLine(completion!.correct,
                  completion.results.length, todayPoints ?? 0),
              practiceLine: l10n.restSessionsLine(
                  _sessionsToday, StorageService.dailySessionLimit),
              // V24f (SPEC §1.15): free users' rest scene leads to Premium;
              // Premium users keep V24.
              offer: _hasFullAccess
                  ? null
                  : RestOffer(
                      weakSpot: _restWeakSpot == null
                          ? null
                          : humanizeSlug(_restWeakSpot!.errorType),
                      trialDays: _restTrialDays,
                      topics: practiceTopics().length,
                      onWake: () => _openRestPaywall(context),
                    ),
            ),
          ),
        ),
      );
    }

    if (restDay && !_restWaitsForStep) return restScene(primary: true);

    // INTEGRATE 3b: the mountain window is fitted above the floating nav
    // bar after each layout (there is no bar for a screen shown alone).
    _navClearance =
        context.dependOnInheritedWidgetOfExactType<NavBarClearance>()?.value;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitClimbWindow());

    final steps = _climbSteps;
    final topic =
        _weakSpots.isEmpty ? null : topicOfWeakSpot(_weakSpots.first.topicId);
    final ticketUsed = _freeUsedToday >= StorageService.freeDailyPracticeLimit;

    // 1.2.0 Home, UI polish V14 / V15: the brand with the score capsule,
    // the greeting, the Daily Test card, the month's mountain, the free
    // ticket (free users), and topic practice.
    final home = BrandScaffold(
      key: _homeContentKey,
      isTabRoot: true,
      appBar: AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      ),
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  header: true,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: BrandWordmark(
                        style: theme.textTheme.displaySmall?.copyWith(
                          letterSpacing: -1.4,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              capsule,
            ],
          ),
          const SizedBox(height: 10),
          HomeGreeting(
            word: timeOfDayGreeting(widget.clock(), l10n),
            name: widget.userName,
            withName: l10n.greetingWithName(
                timeOfDayGreeting(widget.clock(), l10n),
                l10n.greetingName(widget.userName)),
            addressedName: l10n.greetingName(widget.userName),
            lead: l10n.greetingLead(timeOfDayGreeting(widget.clock(), l10n)),
            style: theme.textTheme.titleLarge
                ?.withWeight(FontWeight.w500)
                .copyWith(
                    fontSize: (theme.textTheme.titleLarge?.fontSize ?? 20) *
                        HomeScreen.greetingScale,
                    letterSpacing: -0.3,
                    color: c.muted),
            nameStyle: theme.textTheme.titleLarge
                ?.withWeight(FontWeight.w900)
                .copyWith(
                    fontSize: (theme.textTheme.titleLarge?.fontSize ?? 20) *
                        HomeScreen.greetingScale,
                    letterSpacing: -0.3,
                    color: c.muted),
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: HomeScreen.dailyTestCardKey,
            child: DailyTestCard(
              key: _todayKey,
              state: _loadingToday
                  ? DailyTestCardState.loading
                  : (completion != null
                      ? DailyTestCardState.done
                      : DailyTestCardState.todo),
              hero: hero,
              title: completion == null
                  ? l10n.homeDailyNextTitle
                  : (steps == null || steps == 0
                      ? l10n.dailyResultDone
                      : l10n.dailyResultDayComplete(steps)),
              subtitle: completion == null
                  ? l10n.homeDailyTodoLine(DailyTestSet.questionCount, 2)
                  : l10n.homeDailyDoneLine(todayPoints ?? 0, steps ?? 0),
              results: [
                for (final r
                    in completion?.results ?? const <DailyTestAnswerResult>[])
                  r.isCorrect,
              ],
              questionCount:
                  completion?.results.length ?? DailyTestSet.questionCount,
              buttonLabel: completion == null
                  ? l10n.homeDailyStartToday
                  : l10n.homeDailyReviewAnswers,
              onSegmentFilled: (_) => HapticMap.light(),
              onPressed: completion == null
                  ? () => _openDailyTest(context)
                  : () => _openDailyTestResult(context, _todaysDailyTest!),
            ),
          ),
          const SizedBox(height: 24),
          _buildClimb(context,
              bubble: steps == null
                  ? null
                  : (completion != null
                      ? l10n.homeClimbNextTomorrow(steps + 1)
                      : l10n.homeClimbOneTestAway(steps + 1))),
          const SizedBox(height: 20),
          if (!_hasFullAccess) ...[
            Ticket(
              key: HomeScreen.ticketKey,
              compact: true,
              state: ticketUsed ? TicketState.used : TicketState.free,
              title: l10n.ticketFreeTitle,
              subtitle: ticketUsed
                  ? l10n.ticketUsedLine(widget.userName)
                  : (topic == null
                      ? l10n.ticketPickInReview
                      : l10n.ticketUseItOn(weakSpotTitle(
                          _weakSpots.first.errorType, topic, l10n))),
              nextIn: timeToMidnight(widget.clock()),
              onTap: () {
                HapticMap.light();
                widget.onGoToReview?.call();
              },
            ),
            const SizedBox(height: 20),
            TopicShowcase(
              picked: topic,
              onOpenPaywall: () => _openPremium(context),
            ),
          ] else
            PracticeCard(
              sessionsToday: _sessionsToday,
              sessionLimit: StorageService.dailySessionLimit,
              onOpenTopic: (_) => _openTopicPractice(context),
              onPracticeWeakSpot: () => _weakSpots.isEmpty
                  ? _openTopicPractice(context)
                  : _openWeakSpot(context, _weakSpots.first),
            ),
        ]),
      ],
    );
    if (!restDay || !_restRevealing) return home;
    // Fix round 6: the beat has passed; the rest scene fades in over Home,
    // which takes no more taps and is no longer read out.
    return Stack(fit: StackFit.expand, children: [
      IgnorePointer(child: ExcludeSemantics(child: home)),
      FadeTransition(
          key: HomeScreen.restFadeKey,
          opacity: _restOpacity,
          child: restScene(primary: false)),
    ]);
  }

  /// INTEGRATE 3b: on Home's first view (scrolled to the top) the pawn and
  /// the next step's ring stay [MonthlyMountain.firstViewClearance] above
  /// the floating nav bar, on every day of the month: the window gets
  /// shorter where its full height would put them under the bar (6.1" and
  /// 6.3" phones, the iPhone SE); 6.7" and 6.9" keep the full window.
  void _fitClimbWindow() {
    final clearance = _navClearance;
    final section = _climbSectionKey.currentContext;
    if (!mounted || clearance == null || section == null) return;
    if (_climbSteps == null && !_loadingClimb) return; // the error state
    final box = section.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;
    final scrolled = Scrollable.maybeOf(section)?.position.pixels ?? 0;
    // The window's top: under the card's plaque (half of it overlaps the
    // frame), or under the skeleton's 18 pt.
    final top = box.localToGlobal(Offset.zero).dy +
        scrolled +
        (_climbSteps != null ? ClimbCard.plaqueHeight(context) / 2 : 18);
    final barTop =
        MediaQuery.sizeOf(context).height - (clearance - NavBarClearance.gap);
    final room = barTop - MonthlyMountain.firstViewClearance - top;
    final days = DateTime(_climbMonth.year, _climbMonth.month + 1, 0).day;
    final inputs = (box.size.width, days, room.roundToDouble());
    if (inputs == _climbFitInputs) return;
    _climbFitInputs = inputs;
    final height = MonthlyMountain.fitWindowHeight(
        width: box.size.width, days: days, room: room);
    if ((height - _climbWindowHeight).abs() > .5) {
      setState(() => _climbWindowHeight = height);
    }
  }

  Widget _buildClimb(BuildContext context, {String? bubble}) {
    final days = DateTime(_climbMonth.year, _climbMonth.month + 1, 0).day;
    return Column(
      key: _climbSectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The card carries the title on its plaque (design decision K3);
        // until the month's progress has loaded there is no card, so the
        // title stands alone above the progress indicator or the retry.
        if (_climbSteps == null && _loadingClimb)
          // H03: the card's own shape as a skeleton until the month loads.
          Semantics(
            label: context.l10n.homeClimbLoading,
            child: _ClimbSkeleton(windowHeight: _climbWindowHeight),
          )
        else if (_climbSteps == null) ...[
          Text(context.l10n.homeClimbTitle,
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
                windowHeight: _climbWindowHeight,
                mountain: MonthlyMountain(
                  key: ValueKey(_climbMonth),
                  days: days,
                  completedDays: _climbSteps!,
                  avatar: widget.avatar ?? Avatar.values.first,
                  theme: _climbTheme,
                  onMotionEnd: _onMountainMotionEnd,
                  onArrivalEnd: _onMountainArrivalEnd,
                  zoom: _zoom.active ? _zoom.progress : null,
                  zoomCrossFade: _zoom.crossFade,
                  debugHop: _debugHop,
                  // V15: the next step pulses while today's test waits.
                  nextStepPulse: !_loadingToday &&
                      _todaysCompletion == null &&
                      !_zoom.active,
                  windowHeight: _climbWindowHeight,
                  labelAvoid: (width) => ClimbCard.chipRects(context,
                      width: width,
                      month: _climbMonth,
                      steps: _climbSteps!,
                      days: days),
                ),
                // The score bar moved to the capsule (V14).
                bubble: bubble,
              )),
        if (_loadingClimb && _climbSteps != null)
          LinearProgressIndicator(
              semanticsLabel: context.l10n.homeClimbLoading),
        // R11: one language for a load error — the sad companion, a calm
        // line, "Try again" with dots while it retries.
        if (_climbLoadFailed)
          ErrorState(
            hero: widget.avatar ?? Avatar.values.first,
            kind: ErrorKind.server,
            message: context.l10n.homeClimbFailed,
            onRetry: () async {
              await _loadClimb();
              return !_climbLoadFailed;
            },
          ),
      ],
    );
  }
}

/// H03: the mountain card while the month loads: its plaque and its window
/// as shimmering skeletons, the size of the real card, so nothing jumps
/// when it arrives.
class _ClimbSkeleton extends StatelessWidget {
  final double windowHeight;
  const _ClimbSkeleton({required this.windowHeight});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ExcludeSemantics(
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 18),
          height: windowHeight,
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(ClimbCard.frameRadius + 6),
            border: Border.all(color: c.line, width: 2),
          ),
          padding: const EdgeInsets.all(10),
          child: SkeletonBar(
              height: windowHeight - 24, radius: ClimbCard.frameRadius),
        ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Center(child: SkeletonBar(width: 190, height: 36)),
        ),
      ]),
    );
  }
}
