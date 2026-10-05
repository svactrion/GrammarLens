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
import '../widgets/brand_scaffold.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_title.dart';
import '../widgets/weak_spot_card.dart';
import 'premium_screen.dart';
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

  Future<void> _openWeakSpot(WeakSpot spot) async {
    final topic = kTopics.firstWhere(
      (t) => t.id.name == spot.topicId,
      orElse: () => kTopics.first,
    );
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
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.secondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );

    return FutureBuilder<List<WeakSpot>>(
      future: _weakSpots,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _centred(context, const CircularProgressIndicator());
        }
        if (snapshot.hasError) {
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
            if (_statusLoaded && !_hasFullAccess) ...[
              const SizedBox(height: 20),
              DailyPracticeCard(
                remaining: remaining,
                onSeePremium: _openPremium,
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
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = AppPalette.of(context);
    final available = remaining > 0;
    final ink = available ? colorScheme.onPrimary : palette.onButton;
    final muted = available ? colorScheme.onPrimary : palette.onButtonMuted;
    final edge = available ? null : palette.buttonEdge;

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

    return Card(
      key: available ? availableKey : usedKey,
      color: available ? colorScheme.primary : palette.button,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCardRadius),
        side: edge == null ? BorderSide.none : BorderSide(color: edge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'YOUR DAILY PRACTICE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
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
                      : theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900))
                  ?.copyWith(color: ink),
            ),
            const SizedBox(height: 8),
            Text(description,
                style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(
                  available
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  size: 15,
                  color: ink,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    status,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            if (!available) ...[
              const SizedBox(height: 16),
              Text(
                'Want more practice today?',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              // brandOrange with onOrange text: 6.93:1 (light), 7.71:1
              // (dark); its edge against the navy card 3.95 / 4.39:1.
              FilledButton(
                onPressed: onSeePremium,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  // Not the dark button's blue edge: this is not the navy
                  // button, and its own edge already measures above.
                ).copyWith(side: const WidgetStatePropertyAll(BorderSide.none)),
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
        ),
      ),
    );
  }
}
