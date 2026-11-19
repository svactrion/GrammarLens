import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../app_colors.dart';
import '../models/avatar.dart';
import '../models/topic.dart';
import '../motion.dart';
import '../utils/loading_view.dart';
import '../utils/text_format.dart';
import '../widgets/error_state.dart';
import '../widgets/home_practice.dart' show PremiumChip;
import '../widgets/pressable_button.dart';
import '../widgets/rest_scene.dart' show timeToMidnight;
import '../widgets/review_parts.dart';
import '../widgets/ticket.dart';
import 'practice_launch.dart';
import '../l10n/l10n.dart';
import '../models/error_entry.dart';
import '../models/review_sort_order.dart';
import '../services/analytics_service.dart';
import '../services/app_link.dart' show WeakSpotLink;
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/content_width.dart';
import '../utils/suggested_focus.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/review_top_card.dart';
import '../widgets/section_title.dart';
import 'premium_screen.dart';
import 'topic_practice_screen.dart';
import 'weak_spot_detail_screen.dart';

/// Resurfaces the user's weak spots and lets them launch a freshly
/// generated set targeting the same error type (PRD §4 step 5 — the
/// differentiator: revision without rewriting).
///
/// Deliberately never gates or locks this list itself (this batch's own
/// decision): reading your own past mistakes is genuinely free, no
/// entitlement or quota involved — only the "Practice this" action on the
/// detail screen it leads to is. `WeakSpotCard` here stays unlocked the
/// same way it always has, unlike Home's copy of the same widget.
class ReviewScreen extends StatefulWidget {
  final ClaudeService claudeService;
  final StorageService storageService;
  final AnalyticsService analyticsService;
  final SubscriptionService subscriptionService;
  final bool active;
  final VoidCallback onGoToPractice;

  /// The user's name (the used ticket's "Nice work, <name>.") and buddy
  /// (the empty state).
  final String userName;
  final Avatar? hero;

  /// The clock for the used ticket's countdown; tests pin it.
  final DateTime Function() clock;

  /// W01 v12: the tip widget's weak spot was tapped; Review opens it (R03).
  final ValueListenable<WeakSpotLink?>? weakSpotLinks;

  const ReviewScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
    required this.active,
    required this.onGoToPractice,
    this.userName = '',
    this.hero,
    this.clock = DateTime.now,
    this.weakSpotLinks,
  });

  static const ticketKey = ValueKey('review_ticket');
  static const sortKey = ValueKey('review_sort');
  static const practiceWithTicketKey = ValueKey('review_practice_ticket');
  static const moreKey = ValueKey('review_more_premium');

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late Future<List<WeakSpot>> _weakSpots;
  ReviewSortOrder _sortOrder = ReviewSortOrder.recent;

  // The daily free practice allowance (1.2.0, batch0-report.md §6 N1): read
  // from what already exists — the entitlement and today's free practice
  // count against `StorageService.freeDailyPracticeLimit` — on load, when
  // the tab becomes visible again and when a weak spot's screen closes. It
  // is only shown: the count still changes only when a free practice set is
  // actually generated (`launchPracticeSet`), never on a tap here. Starts
  // closed the way Home's own access flag does, and the card stays hidden
  // until the first read has answered.
  bool _statusLoaded = false;
  bool _hasFullAccess = false;
  int _freePracticeUsedToday = 0;

  /// All weak spots (the list shows up to [StorageService.getWeakSpots]'s
  /// default 10); null until read or if the read failed, then the list's
  /// own length is shown.
  int? _weakSpotTotal;

  /// Premium only (final screens, brief §2): every saved weak spot, read
  /// again with the entitlement (load, the tab shown again, a weak spot or
  /// Topic Practice closed), so the suggestion is never stale. Null for a
  /// free user and until the entitlement has answered.
  Future<List<WeakSpot>>? _allSpots;

  /// True while a weak spot (or Topic Practice) is being opened, so a
  /// second tap does not push it twice.
  bool _opening = false;

  /// Each weak spot's latest mistake (V16's inline line), by
  /// `topic|errorType`; filled after the list loads.
  final Map<String, ErrorEntry?> _latest = {};

  /// The ticket is tearing (V16b) for this weak spot; practice starts when
  /// the tear has played.
  WeakSpot? _tearingFor;
  bool _generating = false;
  int? _preparingCount;

  /// The used ticket's countdown, updated every minute while shown.
  Timer? _minute;

  @override
  void initState() {
    super.initState();
    _weakSpots = _readSpots(_sortOrder);
    _loadSortOrder();
    _loadStatus();
    widget.subscriptionService.addAccessListener(_onAccessChanged);
    widget.weakSpotLinks?.addListener(_onWeakSpotLink);
    // A link that arrived before this tab was built.
    if (widget.weakSpotLinks?.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onWeakSpotLink());
    }
    _minute = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && _statusLoaded && !_hasFullAccess && _ticketUsed) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _minute?.cancel();
    widget.subscriptionService.removeAccessListener(_onAccessChanged);
    widget.weakSpotLinks?.removeListener(_onWeakSpotLink);
    super.dispose();
  }

  /// W01 v12: opens the weak spot the tip widget showed, if it is still
  /// saved (else Review stays as it is).
  Future<void> _onWeakSpotLink() async {
    final link = widget.weakSpotLinks?.value;
    if (link == null || !mounted) return;
    final spots = await widget.storageService
        .getWeakSpots(limit: StorageService.allWeakSpots);
    if (!mounted) return;
    for (final spot in spots) {
      if (spot.topicId == link.topicId && spot.errorType == link.errorType) {
        await _openWeakSpot(spot);
        return;
      }
    }
  }

  bool get _ticketUsed =>
      _freePracticeUsedToday >= StorageService.freeDailyPracticeLimit;

  static String _spotKey(WeakSpot s) => '${s.topicId}|${s.errorType}';

  /// The list, then each weak spot's latest mistake (best effort: a failed
  /// read shows the card without its inline line).
  Future<List<WeakSpot>> _readSpots(ReviewSortOrder order) {
    final spots = widget.storageService.getWeakSpots(sortOrder: order);
    spots.then((list) async {
      for (final spot in list) {
        final key = _spotKey(spot);
        if (_latest.containsKey(key)) continue;
        ErrorEntry? latest;
        try {
          final recent = await widget.storageService
              .getRecentMistakes(spot.topicId, spot.errorType, limit: 1);
          latest = recent.isEmpty ? null : recent.first;
        } catch (_) {}
        if (!mounted) return;
        setState(() => _latest[key] = latest);
      }
    }, onError: (_) {});
    return spots;
  }

  void _onAccessChanged(bool hasAccess) {
    if (!mounted) return;
    setState(() => _hasFullAccess = hasAccess);
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    bool hasFullAccess;
    try {
      hasFullAccess = await widget.subscriptionService.hasFullAccess;
    } catch (_) {
      hasFullAccess = false;
    }
    var usedToday = 0;
    if (!hasFullAccess) {
      try {
        usedToday = await widget.storageService.getFreePracticeCountForToday();
      } catch (_) {
        usedToday = 0;
      }
    }
    int? total;
    try {
      final stats = await widget.storageService.getTopicStats();
      total = stats.values.fold<int>(0, (sum, s) => sum + s.weakSpotCount);
    } catch (_) {
      total = null;
    }
    if (!mounted) return;
    setState(() {
      _hasFullAccess = hasFullAccess;
      _freePracticeUsedToday = usedToday;
      _weakSpotTotal = total;
      _statusLoaded = true;
      _allSpots = hasFullAccess ? _readAllSpots() : null;
    });
  }

  /// Every saved weak spot. Marked as handled at once: it may fail before
  /// the card that shows the failure is built (the list still loading).
  Future<List<WeakSpot>> _readAllSpots() {
    final all =
        widget.storageService.getWeakSpots(limit: StorageService.allWeakSpots);
    all.ignore();
    return all;
  }

  void _retryAllSpots() {
    // A block body: an arrow body would hand setState the Future.
    setState(() {
      _allSpots = _readAllSpots();
    });
  }

  Future<void> _loadSortOrder() async {
    // Nothing awaits this call, so an error here would otherwise become an
    // unhandled Future error instead of surfacing in the (already-handled)
    // weak-spots FutureBuilder. Falling back to the default order is a safe
    // failure mode for a preference read — worst case Review just opens
    // sorted by "Recent" instead of remembering the last choice.
    ReviewSortOrder stored;
    try {
      stored = await widget.storageService.getReviewSortOrder();
    } catch (_) {
      return;
    }
    if (!mounted || stored == _sortOrder) return;
    setState(() {
      _sortOrder = stored;
      _weakSpots = _readSpots(stored);
    });
  }

  @override
  void didUpdateWidget(covariant ReviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _reloadWeakSpots();
      _loadStatus();
    }
  }

  void _reloadWeakSpots() {
    // Block body, NOT `=> _weakSpots = ...`: an arrow body's value is the
    // assignment's value (a Future here), and setState() asserts in debug
    // mode if its callback returns one — "setState() callback argument
    // returned a Future." A block body with the assignment as a statement
    // has no return value, so the assert never sees the Future.
    setState(() {
      _latest.clear();
      _weakSpots = _readSpots(_sortOrder);
    });
  }

  Future<void> _changeSortOrder(ReviewSortOrder order) async {
    if (order == _sortOrder) return;
    setState(() {
      _sortOrder = order;
      _weakSpots = _readSpots(order);
    });
    await widget.storageService.setReviewSortOrder(order);
  }

  /// RV06: the sort sheet.
  Future<void> _openSort() async {
    final order = await showReviewSortSheet(context, _sortOrder);
    if (order != null) await _changeSortOrder(order);
  }

  Topic _topicOf(WeakSpot spot) => topicOfWeakSpot(spot.topicId);

  /// "Practice with my ticket" (V16 → V16b): the ticket tears, then the
  /// weak spot's practice starts through `launchPracticeSet` (the AI
  /// permission, the quota and the generation as they are; the free count
  /// changes only when a set is generated).
  void _useTicket(WeakSpot spot) {
    if (_tearingFor != null || _opening) return;
    setState(() => _tearingFor = spot);
  }

  Future<void> _onTorn() async {
    final spot = _tearingFor;
    if (spot == null || !mounted) return;
    _opening = true;
    try {
      await launchPracticeSet(
        context: context,
        topic: _topicOf(spot),
        claudeService: widget.claudeService,
        storageService: widget.storageService,
        analyticsService: widget.analyticsService,
        subscriptionService: widget.subscriptionService,
        setGenerating: (value) {
          if (mounted) setState(() => _generating = value);
        },
        onQuestionCount: (count) => _preparingCount = count,
        errorPrefix: context.l10n.weakSpotGenerateFailed,
      );
    } finally {
      _opening = false;
    }
    if (!mounted) return;
    setState(() => _tearingFor = null);
    _reloadWeakSpots();
    _loadStatus();
  }

  /// The weak spot's own screen (also Suggested Focus's "Practice this
  /// weak spot"): its practice goes through `launchPracticeSet` there, with
  /// the AI permission, the length picker, the quota and the generation as
  /// they are.
  Future<void> _openWeakSpot(WeakSpot spot) async {
    if (_opening) return;
    _opening = true;
    final topic = topicOfWeakSpot(spot.topicId);
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WeakSpotDetailScreen(
            topic: topic,
            spot: spot,
            hero: widget.hero,
            claudeService: widget.claudeService,
            storageService: widget.storageService,
            analyticsService: widget.analyticsService,
            subscriptionService: widget.subscriptionService,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
    if (!mounted) return;
    _reloadWeakSpots();
    _loadStatus();
  }

  /// Premium with no saved weak spot: the existing Topic Practice screen
  /// (a Premium user's topic choice).
  Future<void> _openTopicPractice() async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TopicPracticeScreen(
            hero: widget.hero,
            claudeService: widget.claudeService,
            storageService: widget.storageService,
            analyticsService: widget.analyticsService,
            subscriptionService: widget.subscriptionService,
          ),
        ),
      );
    } finally {
      _opening = false;
    }
    if (!mounted) return;
    _reloadWeakSpots();
    _loadStatus();
  }

  /// The used card's "See Premium": the existing Premium screen, with its
  /// own paywall source (`review_quota`); the entitlement is read again when
  /// it closes, so a purchase hides the card.
  Future<void> _openPremium() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PremiumScreen(
          storageService: widget.storageService,
          analyticsService: widget.analyticsService,
          analyticsSource: AnalyticsService.paywallSourceReviewQuota,
          subscriptionService: widget.subscriptionService,
        ),
      ),
    );
    _loadStatus();
  }

  /// The page header (V16, R12): the title (with the Premium chip for a
  /// Premium user) and its line, in the page so they scroll with the list.
  Widget _header(ThemeData theme) {
    final c = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Flexible(
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                context.l10n.featureReview,
                style: theme.textTheme.displaySmall?.copyWith(color: c.text),
              ),
            ),
          ),
          if (_statusLoaded && _hasFullAccess) ...[
            const SizedBox(width: 10),
            const PremiumChip(check: true),
          ],
        ]),
        const SizedBox(height: 7),
        Text(
          context.l10n.reviewSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: c.muted),
        ),
      ],
    );
  }

  /// The status bar's height only: the header is in the page.
  PreferredSizeWidget get _statusBarOnly => AppBar(
        toolbarHeight: 0,
        automaticallyImplyLeading: false,
        scrolledUnderElevation: 0,
      );

  /// A single centred state (loading, error) under the header.
  Widget _centred(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    final hPad = ContentWidth.sidePaddingOf(context);
    return BrandScaffold(
      appBar: _statusBarOnly,
      body: Padding(
        padding: EdgeInsets.fromLTRB(hPad, 20, hPad, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(theme),
            Expanded(child: Center(child: SingleChildScrollView(child: child))),
          ],
        ),
      ),
    );
  }

  /// The free user's ticket (V16, V16b, V22, RV05): free and "Pick a weak
  /// spot below", tearing, used with the next ticket's countdown, or
  /// waiting for the first weak spot.
  Widget _ticket(List<WeakSpot> spots) {
    final l10n = context.l10n;
    if (_tearingFor != null) {
      return Ticket(
        key: ReviewScreen.ticketKey,
        state: TicketState.tearing,
        title: l10n.ticketTearingTitle,
        subtitle: l10n.ticketTearingBody,
        onTorn: _onTorn,
      );
    }
    if (_ticketUsed) {
      return Ticket(
        key: ReviewScreen.ticketKey,
        state: TicketState.used,
        title: l10n.ticketUsedTitle,
        subtitle: l10n.ticketUsedLine(widget.userName),
        nextIn: timeToMidnight(widget.clock()),
      );
    }
    return Ticket(
      key: ReviewScreen.ticketKey,
      state: TicketState.free,
      title: l10n.ticketFreeTitle,
      subtitle:
          spots.isEmpty ? l10n.reviewTicketWaiting : l10n.reviewTicketPick,
      onTap: spots.isEmpty ? null : () => _useTicket(spots.first),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = AppColors.of(context);
    final l10n = context.l10n;
    if (_generating) {
      return PageLoading(
        header: Text(
          weakSpotTitle(
              _tearingFor?.errorType ?? '', _topicOf(_tearingFor!), l10n),
          style: theme.textTheme.headlineMedium?.copyWith(color: c.text),
        ),
        message: l10n.weakSpotPreparing,
        topic: _tearingFor == null ? null : _topicOf(_tearingFor!),
        hero: widget.hero,
        questionCount: _preparingCount,
      );
    }

    return FutureBuilder<List<WeakSpot>>(
      future: _weakSpots,
      builder: (context, snapshot) {
        // A reload (back from a weak spot, the tab shown again, a new sort)
        // keeps the list on screen until the new one arrives, so the scroll
        // position and the sort survive; only the first read shows the
        // spinner.
        if (snapshot.connectionState != ConnectionState.done &&
            !snapshot.hasData) {
          return _centred(context, const CircularProgressIndicator());
        }
        if (snapshot.hasError &&
            snapshot.connectionState == ConnectionState.done) {
          return _centred(
            context,
            Padding(
              padding: const EdgeInsets.all(24),
              child: ErrorState(
                hero: widget.hero ?? Avatar.fox,
                kind: ErrorKind.server,
                message: l10n.reviewLoadFailed('${snapshot.error}'),
                onRetry: () async {
                  _reloadWeakSpots();
                  return true;
                },
              ),
            ),
          );
        }
        final spots = snapshot.data ?? const <WeakSpot>[];
        if (!_statusLoaded) {
          // Free and Premium differ from the top: nothing until the
          // entitlement has answered.
          return _centred(context, const CircularProgressIndicator());
        }
        final free = !_hasFullAccess;
        final total = _weakSpotTotal == null
            ? spots.length
            : math.max(_weakSpotTotal!, spots.length);
        final canUseTicket = free && !_ticketUsed && _tearingFor == null;
        return BrandScaffold(
          appBar: _statusBarOnly,
          isTabRoot: true,
          children: [
            _header(theme),
            const SizedBox(height: 18),
            if (free) _ticket(spots),
            // Premium: the Suggested Focus (R12).
            if (!free && spots.isNotEmpty && _allSpots != null)
              FutureBuilder<List<WeakSpot>>(
                future: _allSpots,
                builder: (context, all) {
                  final done = all.connectionState == ConnectionState.done;
                  if (done && all.hasError) {
                    return SuggestedFocusCard.failed(onRetry: _retryAllSpots);
                  }
                  if (!all.hasData) return const SuggestedFocusCard.loading();
                  final spot = suggestedFocus(all.data!);
                  if (spot == null) {
                    return PremiumReviewEmpty(onExplore: _openTopicPractice);
                  }
                  return SuggestedFocusCard(
                    spot: spot,
                    onPractice: () => _openWeakSpot(spot),
                  );
                },
              ),
            if (spots.isEmpty) ...[
              const SizedBox(height: 26),
              if (free)
                ReviewEmpty(
                  hero: widget.hero ?? Avatar.fox,
                  onGoToDailyTest: widget.onGoToPractice,
                )
              else
                PremiumReviewEmpty(onExplore: _openTopicPractice),
            ] else ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        SectionTitle(l10n.reviewSavedWeakSpots),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.track,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$total', // l10n-guard: a count
                            style: theme.textTheme.labelMedium
                                ?.withWeight(FontWeight.w900)
                                .copyWith(color: c.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: l10n.reviewSortTooltip,
                    excludeSemantics: true,
                    child: PressableCard(
                      key: ReviewScreen.sortKey,
                      haptic: ButtonHaptic.selection,
                      onTap: _openSort,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.sort_rounded, size: 18, color: c.navyText),
                          const SizedBox(width: 4),
                          Text(
                            _sortOrder.label(l10n),
                            style: theme.textTheme.labelLarge
                                ?.withWeight(FontWeight.w900)
                                .copyWith(color: c.navyText),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: AppMotion.orInstant(context, AppMotion.base),
                child: Column(
                  key: ValueKey(_sortOrder),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (i, spot) in spots.indexed) ...[
                      ReviewSpotCard(
                        topic: _topicOf(spot),
                        spot: spot,
                        mistake: _latest[_spotKey(spot)],
                        now: widget.clock(),
                        onTap: () => _openWeakSpot(spot),
                        actionKey:
                            i == 0 ? ReviewScreen.practiceWithTicketKey : null,
                        actionLabel: canUseTicket && i == 0
                            ? l10n.reviewPracticeWithTicket
                            : null,
                        onAction: () => _useTicket(spot),
                      ),
                      if (i < spots.length - 1) const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              // V22: the ticket is used; Premium's sessions, to the paywall.
              if (free && _ticketUsed) ...[
                const SizedBox(height: 16),
                PressableCard(
                  key: ReviewScreen.moreKey,
                  haptic: ButtonHaptic.light,
                  onTap: _openPremium,
                  semanticLabel: '${l10n.reviewWantMore} '
                      '${l10n.reviewPremiumMore(StorageService.dailySessionLimit)}',
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: lipCard(c,
                        color: c.goldSoft, border: c.gold, lip: c.goldDeep),
                    child: Row(children: [
                      Icon(Icons.auto_awesome_rounded, color: c.goldText),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l10n.reviewWantMore,
                                style: theme.textTheme.titleSmall
                                    ?.withWeight(FontWeight.w900)
                                    .copyWith(color: c.text)),
                            Text(
                                l10n.reviewPremiumMore(
                                    StorageService.dailySessionLimit),
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: c.muted)),
                          ],
                        ),
                      ),
                      Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.arrow_back_rounded
                              : Icons.arrow_forward_rounded,
                          color: c.text),
                    ]),
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

/// Premium Review's top card (1.2.0 final screens, brief §2): the saved
/// weak spot to work on next ([suggestedFocus]), in the shared
/// [ReviewTopCard] shell — navy with white text, the dark mode edge, an
/// orange call to action. At least as tall as the Free "available" card at
/// the same width and text size ([MatchHeight]), so the list starts in the
/// same place for Free and Premium; it grows only when its own text needs
/// more (a long title at a large size).
///
/// Three states: [spot] (the suggestion), loading (the eyebrow and a quiet
/// progress mark, no invented topic or count) and [failed] (says so and
/// offers [onRetry]; never shown as "no weak spots").
class SuggestedFocusCard extends StatelessWidget {
  final WeakSpot? spot;
  final bool failed;
  final VoidCallback? onPractice;
  final VoidCallback? onRetry;

  const SuggestedFocusCard({
    super.key,
    required this.spot,
    this.onPractice,
  })  : failed = false,
        onRetry = null;

  const SuggestedFocusCard.loading({super.key})
      : spot = null,
        failed = false,
        onPractice = null,
        onRetry = null;

  const SuggestedFocusCard.failed({super.key, required this.onRetry})
      : spot = null,
        failed = true,
        onPractice = null;

  static const cardKey = ValueKey('review_suggested_focus');
  static const ctaKey = ValueKey('review_suggested_focus_cta');

  /// "Saved N times · Most repeated", "Saved 1 time" for one.
  static String countLine(int count, AppLocalizations l10n) =>
      l10n.reviewFocusCount(count);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final ink = palette.onButton;
    final muted = palette.onButtonMuted;
    final spot = this.spot;

    final eyebrow = Row(
      children: [
        Icon(Icons.center_focus_strong_rounded,
            size: 16, color: colorScheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            context.l10n.reviewFocusEyebrow,
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w800)
                .copyWith(color: muted, letterSpacing: 1),
          ),
        ),
      ],
    );

    final Widget content;
    if (spot != null) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              eyebrow,
              const SizedBox(height: 12),
              // The record's own title, as the list below names it; it
              // wraps, never cut short.
              Text(
                switch (topicByName(spot.topicId)) {
                  final topic? =>
                    weakSpotTitle(spot.errorType, topic, context.l10n),
                  null => humanizeSlug(spot.errorType),
                },
                style: theme.textTheme.headlineSmall?.copyWith(color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                countLine(spot.frequency, context.l10n),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
            ],
          ),
          FilledButton(
            key: ctaKey,
            onPressed: onPractice,
            style: forwardButtonStyle(context),
            child: Row(
              children: [
                Expanded(child: Text(context.l10n.reviewFocusPractice)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
          ),
        ],
      );
    } else if (failed) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eyebrow,
          const SizedBox(height: 12),
          Text(
            context.l10n.reviewFocusFailed,
            style: theme.textTheme.bodyMedium
                ?.withWeight(FontWeight.w700)
                .copyWith(color: ink),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: ink,
              padding: EdgeInsets.zero,
              minimumSize: const Size(44, 44),
            ),
            child: Text(context.l10n.commonTryAgain),
          ),
        ],
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          eyebrow,
          const SizedBox(height: 20),
          Semantics(
            label: context.l10n.reviewFocusLoading,
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: muted),
            ),
          ),
        ],
      );
    }

    return ReviewTopCard(
      cardKey: cardKey,
      color: palette.button,
      edge: palette.buttonEdge,
      // R12: the focus card glints every 3.6 s.
      glint: spot != null,
      child: content,
    );
  }
}

/// Premium Review with no saved weak spot (brief §2, "Kayıt yok"): no
/// suggestion is made up. A plain card that sends the user to Topic
/// Practice ([onExplore]). The Free empty state is unchanged.
class PremiumReviewEmpty extends StatelessWidget {
  final VoidCallback onExplore;

  const PremiumReviewEmpty({super.key, required this.onExplore});

  static const ctaKey = ValueKey('review_premium_empty_cta');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.edit_note_rounded,
                size: 32, color: colorScheme.secondary),
            const SizedBox(height: 15),
            Semantics(
              header: true,
              child: Text(
                context.l10n.reviewNextStepTitle,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.reviewNextStepBody,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: ctaKey,
              onPressed: onExplore,
              style: forwardButtonStyle(context),
              child: Row(
                children: [
                  Expanded(
                      child: Text(context.l10n.reviewExploreTopicPractice)),
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
