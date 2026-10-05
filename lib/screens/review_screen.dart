import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/topics.dart';
import '../models/error_entry.dart';
import '../models/review_sort_order.dart';
import '../services/analytics_service.dart';
import '../services/claude_service.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';
import '../theme.dart';
import '../utils/content_width.dart';
import '../utils/suggested_focus.dart';
import '../utils/text_format.dart';
import '../widgets/brand_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/review_top_card.dart';
import '../widgets/section_title.dart';
import '../widgets/weak_spot_card.dart';
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

  const ReviewScreen({
    super.key,
    required this.claudeService,
    required this.storageService,
    required this.analyticsService,
    required this.subscriptionService,
    required this.active,
    required this.onGoToPractice,
  });

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

  @override
  void initState() {
    super.initState();
    _weakSpots = widget.storageService.getWeakSpots(sortOrder: _sortOrder);
    _loadSortOrder();
    _loadStatus();
    widget.subscriptionService.addAccessListener(_onAccessChanged);
  }

  @override
  void dispose() {
    widget.subscriptionService.removeAccessListener(_onAccessChanged);
    super.dispose();
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
      _weakSpots = widget.storageService.getWeakSpots(sortOrder: stored);
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
      _weakSpots = widget.storageService.getWeakSpots(sortOrder: _sortOrder);
    });
  }

  Future<void> _changeSortOrder(ReviewSortOrder order) async {
    if (order == _sortOrder) return;
    setState(() {
      _sortOrder = order;
      _weakSpots = widget.storageService.getWeakSpots(sortOrder: order);
    });
    await widget.storageService.setReviewSortOrder(order);
  }

  /// The weak spot's own screen (also Suggested Focus's "Practice this
  /// weak spot"): its practice goes through `launchPracticeSet` there, with
  /// the AI permission, the length picker, the quota and the generation as
  /// they are.
  Future<void> _openWeakSpot(WeakSpot spot) async {
    if (_opening) return;
    _opening = true;
    final topic = kTopics.firstWhere(
      (t) => t.id.name == spot.topicId,
      orElse: () => kTopics.first,
    );
    try {
      await Navigator.of(context).push(
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

  /// The page header (1.2.0 brief, "Review"): the title and its line, in
  /// the page rather than the app bar, so they scroll with the list.
  Widget _header(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            'Review',
            style: theme.textTheme.displaySmall
                ?.copyWith(color: theme.colorScheme.onSurface),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Turn your mistakes into progress.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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

  /// A single centred state (loading, error, empty) under the header.
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final sortAction = PopupMenuButton<ReviewSortOrder>(
      initialValue: _sortOrder,
      onSelected: _changeSortOrder,
      tooltip: 'Sort weak spots',
      itemBuilder: (context) => ReviewSortOrder.values
          .map(
            (order) => PopupMenuItem(
              value: order,
              child: Text(order.label),
            ),
          )
          .toList(),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort_rounded, size: 16, color: colorScheme.secondary),
            const SizedBox(width: 4),
            Text(
              _sortOrder.label,
              style: theme.textTheme.labelMedium
                  ?.withWeight(FontWeight.w800)
                  .copyWith(color: colorScheme.secondary),
            ),
          ],
        ),
      ),
    );

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Could not load your error profile.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _reloadWeakSpots,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final spots = snapshot.data ?? const <WeakSpot>[];
        if (spots.isEmpty && !_statusLoaded) {
          // Free and Premium have different empty states: neither is shown
          // until the entitlement has answered.
          return _centred(context, const CircularProgressIndicator());
        }
        // Premium with no saved weak spot (final screens, brief §2): no
        // suggestion, a way to Topic Practice instead.
        if (spots.isEmpty && _hasFullAccess) {
          return BrandScaffold(
            appBar: _statusBarOnly,
            isTabRoot: true,
            children: [
              _header(theme),
              const SizedBox(height: 20),
              PremiumReviewEmpty(onExplore: _openTopicPractice),
            ],
          );
        }
        // No weak spot, no allowance card: there is nothing to spend a free
        // practice on (brief, "Veri, uç durumlar").
        if (spots.isEmpty) {
          return _centred(
            context,
            Padding(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'No weak spots yet.',
                description: 'Mistakes from your Daily Test and practice '
                    'will show up here.',
                ctaLabel: 'Go to Daily Test',
                onCta: widget.onGoToPractice,
                ctaStyle: forwardButtonStyle(context),
              ),
            ),
          );
        }
        final total = _weakSpotTotal == null
            ? spots.length
            : math.max(_weakSpotTotal!, spots.length);
        final remaining =
            StorageService.freeDailyPracticeLimit - _freePracticeUsedToday;
        return BrandScaffold(
          appBar: _statusBarOnly,
          isTabRoot: true,
          children: [
            _header(theme),
            // Q13: free users only; premium has no allowance to describe.
            // Neither card until the entitlement has answered, so the wrong
            // one never shows for a moment.
            if (_statusLoaded && !_hasFullAccess) ...[
              const SizedBox(height: 20),
              DailyPracticeCard(
                remaining: remaining,
                onSeePremium: _openPremium,
              ),
            ],
            // Premium: the Suggested Focus, in the same place and size.
            if (_statusLoaded && _hasFullAccess && _allSpots != null) ...[
              const SizedBox(height: 20),
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
            ],
            const SizedBox(height: 23),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.end,
                    spacing: 6,
                    children: [
                      const SectionTitle('Saved weak spots'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Text(
                          '$total',
                          style: theme.textTheme.bodySmall
                              ?.withWeight(FontWeight.w600)
                              .copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                sortAction,
              ],
            ),
            const SizedBox(height: 12),
            for (final spot in spots) ...[
              WeakSpotCard(
                topic: kTopics.firstWhere(
                  (t) => t.id.name == spot.topicId,
                  orElse: () => kTopics.first,
                ),
                spot: spot,
                onTap: () => _openWeakSpot(spot),
              ),
              if (spot != spots.last) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

/// Review's daily free practice card (1.2.0 brief, "Review"; free users
/// only). Two states that differ in text and icon as well as color:
/// - available: brandOrange with onOrange text in both themes, saying any
///   saved weak spot below can take it;
/// - used today (owner, Batch 5): the button navy (`AppPalette.button`)
///   with white text, and in dark mode the button's #5C7CFA edge (the navy
///   is 1.77:1 on the dark page). No free-practice call to action: it says
///   when the next one comes, then offers Premium with an orange button
///   ([onSeePremium], the existing Premium screen).
///
/// Drawn in the shared [ReviewTopCard] shell (final screens), which
/// Premium's [SuggestedFocusCard] uses too.
class DailyPracticeCard extends StatelessWidget {
  /// Free practices left today (`freeDailyPracticeLimit` minus today's
  /// count); 0 or less is "used today".
  final int remaining;

  /// Opens the Premium screen; shown only in the used state.
  final VoidCallback? onSeePremium;

  const DailyPracticeCard(
      {super.key, required this.remaining, this.onSeePremium});

  static const availableKey = ValueKey('review_daily_practice_available');
  static const usedKey = ValueKey('review_daily_practice_used');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final palette = AppPalette.of(context);
    final available = remaining > 0;
    return ReviewTopCard(
      cardKey: available ? availableKey : usedKey,
      color: available ? colorScheme.primary : palette.button,
      edge: available ? null : palette.buttonEdge,
      child: DailyPracticeContent(
          remaining: remaining, onSeePremium: onSeePremium),
    );
  }
}

/// The inside of [DailyPracticeCard]. Also Premium's height reference: the
/// Suggested Focus card is at least as tall as this content in its
/// "available" state at the same width and text size.
class DailyPracticeContent extends StatelessWidget {
  final int remaining;
  final VoidCallback? onSeePremium;

  const DailyPracticeContent(
      {super.key, required this.remaining, this.onSeePremium});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final available = remaining > 0;
    final ink = available ? colorScheme.onPrimary : palette.onButton;
    final muted = available ? colorScheme.onPrimary : palette.onButtonMuted;

    final title = available
        ? 'One weak spot. One step forward.'
        : 'Today’s practice is complete.';
    final description = available
        ? 'Choose any saved weak spot below. Practice for free and get AI '
            'feedback.'
        : 'Keep reviewing your saved feedback. Your next free practice is '
            'available tomorrow.';
    final status = available
        ? '$remaining free practice${remaining == 1 ? '' : 's'} available '
            'today'
        : 'Next free practice tomorrow';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'YOUR DAILY PRACTICE',
                style: theme.textTheme.labelSmall
                    ?.withWeight(FontWeight.w800)
                    .copyWith(color: ink, letterSpacing: 1),
              ),
            ),
            Icon(Icons.auto_awesome_rounded, size: 19, color: ink),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: (available
                  ? theme.textTheme.headlineSmall
                  : theme.textTheme.titleLarge?.withWeight(FontWeight.w900))
              ?.copyWith(color: ink),
        ),
        const SizedBox(height: 8),
        Text(description,
            style: theme.textTheme.bodySmall?.copyWith(color: muted)),
        const SizedBox(height: 13),
        Row(
          children: [
            Icon(
              available ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 15,
              color: ink,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                status,
                style: theme.textTheme.labelMedium
                    ?.withWeight(FontWeight.w800)
                    .copyWith(color: ink),
              ),
            ),
          ],
        ),
        if (!available) ...[
          const SizedBox(height: 16),
          Text(
            'Want more practice today?',
            style: theme.textTheme.bodySmall
                ?.withWeight(FontWeight.w700)
                .copyWith(color: ink),
          ),
          const SizedBox(height: 10),
          // brandOrange with onOrange text: 6.93:1 (light), 7.71:1
          // (dark); its edge against the navy card 3.95 / 4.39:1.
          FilledButton(
            onPressed: onSeePremium,
            style: forwardButtonStyle(context),
            child: const Row(
              children: [
                Expanded(child: Text('See Premium')),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 17),
              ],
            ),
          ),
        ],
      ],
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
  static String countLine(int count) =>
      'Saved $count ${count == 1 ? 'time' : 'times'} · Most repeated';

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
            'SUGGESTED FOCUS',
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
                humanizeSlug(spot.errorType),
                style: theme.textTheme.headlineSmall?.copyWith(color: ink),
              ),
              const SizedBox(height: 8),
              Text(
                countLine(spot.frequency),
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 16),
            ],
          ),
          FilledButton(
            key: ctaKey,
            onPressed: onPractice,
            style: forwardButtonStyle(context),
            child: const Row(
              children: [
                Expanded(child: Text('Practice this weak spot')),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 17),
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
            'Your suggestion could not be loaded.',
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
            child: const Text('Try again'),
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
            label: 'Loading your suggestion',
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
      child: MatchHeight(
        reference: const DailyPracticeContent(
            remaining: StorageService.freeDailyPracticeLimit),
        child: content,
      ),
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
                'Your next step starts with practice.',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'As you practice, your mistakes will appear here so you can '
              'work on them again.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: ctaKey,
              onPressed: onExplore,
              style: forwardButtonStyle(context),
              child: const Row(
                children: [
                  Expanded(child: Text('Explore Topic Practice')),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 17),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
