import 'dart:async';

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
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/daily_test_service.dart';
import '../services/month_transition.dart';
import '../services/monthly_medal_rules.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../utils/answer_matching.dart';
import '../utils/greeting.dart';
import '../utils/text_format.dart';
import '../widgets/avatar_tile.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/home_greeting.dart';
import '../widgets/launch_splash.dart';
import '../widgets/locked_premium_pill.dart';
import '../widgets/month_card_sheet.dart';
import '../widgets/monthly_climb/climb_card.dart';
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
  static const monthCardTodayPeek = 56.0;

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
    if (widget.firstRunZoom) {
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
  }

  @override
  void dispose() {
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
        ClimbZoomTrigger.firstRun, StorageService.firstRunZoomFlag, themeId);
  }

  /// Plays a zoom on the month drawn with [themeId], claiming [flag] as it
  /// starts (M6: never twice), and reports how it ended (M19).
  Future<void> _runZoom(
      ClimbZoomTrigger trigger, String flag, String themeId) async {
    final outcome = await _zoom.run(
        trigger: trigger,
        reduceMotion: MediaQuery.disableAnimationsOf(context),
        claim: () => widget.storageService.claimOneTimeFlag(flag));
    // Null: it had already played and did not run, so nothing ended.
    if (outcome == null) return;
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
    try {
      // K-c behind the sheet (again, if a Daily Test released it).
      _zoom.hold(ClimbZoomTrigger.monthChange);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _scrollForMonthCard();
      unawaited(widget.analyticsService.monthCardShown(
          themeId: card.theme.id,
          variant: card.variant.wireName,
          medalTier: card.tier,
          nearMissShown: card.nearMiss != null));
      _monthCardOpenFor = Duration.zero;
      _monthCardOpenStart();
      final how = await showMonthCard(context,
          data: card, avatar: widget.avatar ?? Avatar.values.first);
      _monthCardOpenStop();
      if (!mounted) return;
      // All three ways of closing count as seen (M6), recorded on closing:
      // a card open when the app is closed shows again.
      try {
        await MonthTransition.markSeen(
            widget.storageService, card.year, card.month);
      } catch (_) {}
      if (!mounted) return;
      unawaited(widget.analyticsService.monthCardDismissed(
          themeId: card.theme.id,
          variant: card.variant.wireName,
          method: how.wireName,
          openMs: _monthCardOpenFor.inMilliseconds));
      await _runZoom(ClimbZoomTrigger.monthChange,
          StorageService.monthZoomFlag(card.year, card.month), card.theme.id);
    } finally {
      _monthCardShowing = false;
    }
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
      if (!mounted) return;
      setState(() {
        _weakSpots = spots;
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
    final appBarFg = theme.appBarTheme.foregroundColor ?? colorScheme.onSurface;

    return BrandScaffold(
      isTabRoot: true,
      title: Text(
        'GrammarLens',
        style: theme.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: appBarFg,
        ),
      ),
      children: [
        // Keep the small Home body mounted while covered/scrolled so the
        // mountain retains the pre-completion position and can be revealed.
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // PRD v2 §11: an avatar next to the greeting, not floating
          // elsewhere on the page, so it reads as "whose home screen this
          // is" rather than a decorative icon. Greeting leads on the left,
          // avatar pinned to the far right edge (trailing, not centered
          // against the text) — `spaceBetween` with a `Flexible` (not
          // `Expanded`) text so the avatar always lands flush against the
          // trailing edge regardless of how short the greeting is, while a
          // long name never pushes the avatar off the visible row.
          // HomeGreeting is at most two lines, each capped at one line with
          // an ellipsis, which also keeps this row safe at large Dynamic
          // Type sizes: it never wraps into the avatar or grows without
          // bound; the avatar's own size never changes with text scale, and
          // the `Row` (no fixed height) grows to fit whichever of the two is
          // taller, so nothing clips vertically either.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: HomeGreeting(
                  word: timeOfDayGreeting(widget.clock()),
                  name: widget.userName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: appBarFg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // PRD v2 §11's natural follow-up: the avatar is the user's
              // own identity marker, and Settings is where it (and the
              // rest of the profile) is edited — tapping it jumps there
              // directly instead of requiring the Settings tab first.
              // Enlarged from the original radius: 22 (a 44pt tile — this
              // batch's own instruction to make it more prominent as the
              // "whose home screen this is" marker); 44pt was already
              // exactly at the ≥44pt touch-target minimum, so growing it
              // only makes that minimum more comfortably exceeded, never
              // at risk. This row lives in Home's own scrollable body
              // (BrandScaffold's `children`), not its app bar/band, so the
              // band's height is untouched by this change — confirmed by
              // reading BrandScaffold itself, not assumed.
              InkWell(
                // Matches AvatarTile's own corner rounding at radius: 30
                // (radius * 0.6) — a circular ripple would visibly mismatch
                // the tile's now-square shape.
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                onTap: widget.onAvatarTap,
                // Hero, not just AvatarTile: `app.dart`'s onAvatarTap now
                // pushes AvatarPickerScreen directly (a real route push, not
                // the tab switch this used to be), so this flies to the
                // carousel's centered avatar there and back. `homeAvatarHeroTag`
                // is its own tag, distinct from Settings' `avatarHeroTag` —
                // see that constant's own doc comment for why sharing one tag
                // across both entry points would crash (both routes' Heroes
                // stay mounted simultaneously, since Home and Settings are
                // both permanently alive inside app.dart's IndexedStack).
                child: Hero(
                  tag: homeAvatarHeroTag,
                  child: AvatarTile(avatar: widget.avatar, radius: 30),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Today'),
          const SizedBox(height: 8),
          _TodayCard(
            key: _todayKey,
            loading: _loadingToday,
            dailyTestSet: _todaysDailyTest,
            onStart: () => _openDailyTest(context),
            onViewResult: (set) => _openDailyTestResult(context, set),
          ),
          const SizedBox(height: 12),
          _buildClimb(context),
          const SizedBox(height: 24),
          _PracticeModeCard(
            icon: Icons.school_rounded,
            title: 'Topic Practice',
            description: _hasFullAccess
                ? 'Deep grammar practice with plain-language feedback.'
                : 'Try it free, then continue with a subscription.',
            locked: !_hasFullAccess,
            onTap: () => _openTopicPractice(context),
          ),
          // Deliberately no empty state here (PRD v2 §13.5 item 4) — the
          // Review tab already covers "no weak spots yet", and repeating
          // that message on Home too would just be noise on a screen
          // that's supposed to lead with what's actually there.
          if (!_loadingWeakSpots && _weakSpots.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Your weak spots'),
            const SizedBox(height: 8),
            for (final spot in _weakSpots) ...[
              WeakSpotCard(
                topic: kTopics.firstWhere(
                  (t) => t.id.name == spot.topicId,
                  orElse: () => kTopics.first,
                ),
                spot: spot,
                locked: !_hasFullAccess,
                onTap: () => _openWeakSpot(context, spot),
              ),
              if (spot != _weakSpots.last) const SizedBox(height: 10),
            ],
          ],
          // Quiet by design (PRD v2 §13.5 item 5) — a plain row, not the
          // solid-fill banner this used to be, and only for a free user:
          // someone already on a trial or subscribed doesn't need the
          // upsell repeated at them. Must never outweigh the Today card
          // above, which is why this has no Card/fill of its own.
          if (!_hasFullAccess) ...[
            const SizedBox(height: 8),
            _PremiumRow(onTap: () => _openPremium(context)),
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

/// The largest, topmost block (PRD v2 §13.5 item 2) — Daily Test's actual
/// state, read from what's already cached rather than a new tracking
/// mechanism: [DailyTestSet.completedAt] (has today's test been finished)
/// and [DailyTestSet.answers] (what the score was, persisted alongside it
/// — see docs/build-log.md for why that had to be added). Shares
/// `_PracticeModeCard`'s icon+title+description card shape rather than
/// inventing a new one; taller than that card simply because it carries
/// more content, not a different visual treatment.
class _TodayCard extends StatelessWidget {
  final bool loading;
  final DailyTestSet? dailyTestSet;
  final VoidCallback onStart;
  final ValueChanged<DailyTestSet> onViewResult;

  const _TodayCard({
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
    final muted = colorScheme.onSurfaceVariant;
    final set = dailyTestSet;
    final completed = set != null && set.isCompleted;

    if (loading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    String title;
    String description;
    if (completed) {
      final score = computeDailyTestScore(set.questions, set.answers ?? {});
      title = 'Today\'s test: ${score.correct}/${score.total} correct';
      description = 'New test tomorrow. Tap to see today\'s result again.';
    } else {
      title = 'Daily Test';
      description = "Today's ${DailyTestSet.questionCount}-question warm-up "
          'is ready — free, always.';
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: completed ? () => onViewResult(set) : onStart,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: Icon(
                  completed ? Icons.check_circle_rounded : Icons.today_rounded,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The single mode-selection card: a full-width row rather than the
/// icon-on-top grid tile this used to be alongside Streak Mode and Voice
/// Practice — with only one real mode left, a lone icon-on-top tile in a
/// now-empty 2-column grid would read as a layout bug, not a deliberate
/// choice.
class _PracticeModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  // Same lock-icon visual language the old Voice Practice grid tile used
  // (muted icon-avatar fill + a small lock glyph) before Streak/Voice were
  // removed from Home — reused here for Topic Practice's entitlement gate
  // (PRD v2 §12.2/§12.3) rather than inventing a new "locked" treatment.
  final bool locked;
  final VoidCallback onTap;

  const _PracticeModeCard({
    required this.icon,
    required this.title,
    required this.description,
    this.locked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final muted = colorScheme.onSurfaceVariant;
    final iconBg = locked
        ? colorScheme.surfaceContainerHighest
        : colorScheme.primaryContainer;
    final iconFg = locked ? muted : colorScheme.onPrimaryContainer;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: iconBg,
                foregroundColor: iconFg,
                child: Icon(icon, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: locked ? muted : null,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              locked
                  ? MediaQuery.textScalerOf(context).scale(14) > 20
                      ? Icon(Icons.lock_rounded,
                          color: muted, semanticLabel: 'Premium')
                      : const LockedPremiumPill()
                  : Icon(Icons.chevron_right_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// A quiet row (PRD v2 §13.5 item 5) — deliberately not a Card, not
/// filled, no elevation, so it can never outweigh the Today card or Topic
/// Practice above it. Replaces what used to be a solid deep-blue banner;
/// that treatment made sense when Premium was one of only three things on
/// the screen; it doesn't once Home actually leads with real data. Only
/// shown to a user without full access — see the build() call site.
///
/// Text color reuses `theme.appBarTheme.foregroundColor` (the band's own
/// foreground, docs/design-audit.md §5 D1) — a leftover from when this row
/// sat directly on the vivid-orange scaffold and `onSurfaceVariant`
/// measured ~3.6:1 there (failing AA). Since Home migrated onto
/// `BrandScaffold`, this row sits on the neutral body instead, where
/// `onSurfaceVariant` would work fine again — but the band foreground is
/// still comfortably legible here too (very dark on near-white in light
/// mode), so it was left as-is rather than switched for its own sake;
/// revisit if a future batch has a real reason to.
class _PremiumRow extends StatelessWidget {
  final VoidCallback onTap;

  const _PremiumRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.workspace_premium_outlined, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: fg, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Unlock targeted practice on your weak spots',
                    style: theme.textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: fg),
          ],
        ),
      ),
    );
  }
}
