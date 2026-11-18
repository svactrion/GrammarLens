import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/services/app_link.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/home_practice.dart';
import 'package:grammar_lens/widgets/review_parts.dart';
import 'package:grammar_lens/widgets/ticket.dart';

import 'support/l10n_support.dart';
import 'support/paywall_close.dart';

/// Review (UI polish V16, V16b, V22, RV05, RV06): the free ticket (read
/// from the existing free practice count, hidden for Premium), the weak
/// spot cards, the empty state and the sort sheet.

class _Subscription extends SubscriptionService {
  bool hasAccess;
  AccessListener? _listener;

  _Subscription({this.hasAccess = false});

  @override
  Future<bool> get hasFullAccess async => hasAccess;

  @override
  void addAccessListener(AccessListener listener) => _listener = listener;

  @override
  void removeAccessListener(AccessListener listener) {
    if (identical(_listener, listener)) _listener = null;
  }

  void emit(bool value) {
    hasAccess = value;
    _listener?.call(value);
  }
}

class _Storage extends StorageService {
  List<WeakSpot> weakSpots;
  int freePracticeCount;
  Map<String, TopicStats> topicStats;
  ReviewSortOrder storedSort;
  final savedSorts = <ReviewSortOrder>[];
  final weakSpotReads = <ReviewSortOrder>[];

  _Storage({
    this.weakSpots = const [],
    this.freePracticeCount = 0,
    this.topicStats = const {},
    this.storedSort = ReviewSortOrder.recent,
  });

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async {
    weakSpotReads.add(sortOrder);
    return weakSpots.take(limit).toList();
  }

  @override
  Future<int> getFreePracticeCountForToday() async => freePracticeCount;

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => topicStats;

  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => storedSort;

  @override
  Future<void> setReviewSortOrder(ReviewSortOrder order) async {
    storedSort = order;
    savedSorts.add(order);
  }

  /// The latest mistake each weak spot shows inline.
  ErrorEntry? latest;

  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      latest == null ? const [] : [latest!];
}

WeakSpot _spot(String errorType, {int frequency = 1}) => WeakSpot(
      topicId: 'articles',
      errorType: errorType,
      frequency: frequency,
      lastSeen: DateTime.now(),
      latestExplanation: 'You left out "the" before a specific noun.',
    );

final _twoSpots = [_spot('missing_article', frequency: 3), _spot('a_vs_an')];

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required _Storage storage,
    _Subscription? subscription,
    bool active = true,
    VoidCallback? onGoToPractice,
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    ValueListenable<WeakSpotLink?>? weakSpotLinks,
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: ReviewScreen(
        claudeService: ClaudeService(),
        storageService: storage,
        analyticsService: AnalyticsService(),
        subscriptionService: subscription ?? _Subscription(),
        active: active,
        onGoToPractice: onGoToPractice ?? () {},
        userName: 'Ada',
        clock: () => DateTime(2026, 11, 17, 3, 19),
        weakSpotLinks: weakSpotLinks,
      ),
    ));
    await tester.pumpAndSettle();
  }

  // Fix round 4, item 3 (W01 v12): the tip widget's weak spot opens R03.
  group('the tip widget\'s weak spot link', () {
    testWidgets('opens that weak spot (R03)', (tester) async {
      final links = ValueNotifier<WeakSpotLink?>(null);
      addTearDown(links.dispose);
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots), weakSpotLinks: links);
      expect(find.byType(WeakSpotDetailScreen), findsNothing);
      links.value = const WeakSpotLink('articles', 'a_vs_an');
      await tester.pumpAndSettle();
      final detail = tester
          .widget<WeakSpotDetailScreen>(find.byType(WeakSpotDetailScreen));
      expect(detail.spot.errorType, 'a_vs_an');
    });

    testWidgets('a link that came before the tab was built opens it too',
        (tester) async {
      final links = ValueNotifier<WeakSpotLink?>(
          const WeakSpotLink('articles', 'missing_article'));
      addTearDown(links.dispose);
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots), weakSpotLinks: links);
      expect(
          tester
              .widget<WeakSpotDetailScreen>(find.byType(WeakSpotDetailScreen))
              .spot
              .errorType,
          'missing_article');
    });

    testWidgets('a weak spot no longer saved leaves Review as it is',
        (tester) async {
      final links = ValueNotifier<WeakSpotLink?>(null);
      addTearDown(links.dispose);
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots), weakSpotLinks: links);
      links.value = const WeakSpotLink('articles', 'gone');
      await tester.pumpAndSettle();
      expect(find.byType(WeakSpotDetailScreen), findsNothing);
      expect(find.text('Review'), findsOneWidget);
    });
  });

  final ticket = find.byKey(ReviewScreen.ticketKey);
  TicketState ticketState(WidgetTester tester) =>
      tester.widget<Ticket>(ticket).state;

  testWidgets('the page title and its line are in the page', (tester) async {
    await pump(tester, storage: _Storage(weakSpots: _twoSpots));
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Your mistakes, turned into practice.'), findsOneWidget);
  });

  group('the free ticket (V16, V22)', () {
    testWidgets(
        'free: "1 free practice", the line, and "Practice with my ticket" on '
        'the first weak spot only', (tester) async {
      await pump(tester, storage: _Storage(weakSpots: _twoSpots));
      expect(ticketState(tester), TicketState.free);
      expect(find.text('1 free practice'), findsOneWidget);
      expect(find.text('Pick a weak spot below. AI feedback included.'),
          findsOneWidget);
      expect(find.text('Practice with my ticket'), findsOneWidget);
      expect(find.byKey(ReviewScreen.moreKey), findsNothing);
      expect(find.textContaining('unlimited'), findsNothing);
    });

    testWidgets(
        'used today: "Used today", the name, the next ticket at midnight; no '
        'ticket button; Premium\'s sessions to the paywall', (tester) async {
      await pump(tester,
          storage: _Storage(
              weakSpots: _twoSpots,
              freePracticeCount: StorageService.freeDailyPracticeLimit));
      expect(ticketState(tester), TicketState.used);
      expect(find.text('Used today'), findsOneWidget);
      expect(find.text('Nice work, Ada.'), findsOneWidget);
      // 03:19 → 20 h 41 min to midnight.
      expect(tester.widget<Ticket>(ticket).nextIn,
          const Duration(hours: 20, minutes: 41));
      expect(find.text('Practice with my ticket'), findsNothing);
      expect(find.text('Want more practice today?'), findsOneWidget);
      expect(find.text('Premium: up to 5 sessions a day'), findsOneWidget);
      await tester.ensureVisible(find.byKey(ReviewScreen.moreKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReviewScreen.moreKey));
      await tester.pumpAndSettle();
      final premium = tester.widget<PremiumScreen>(find.byType(PremiumScreen));
      expect(
          premium.analyticsSource, AnalyticsService.paywallSourceReviewQuota);
      // Fix round 5, item 4: it closes only with its X.
      PremiumScreen.resetExitReminder();
      await expectPaywallHolds(tester);
      // No store offer in this fake: V13b (it states the trial) stays shut.
      await closeWithX(tester, reminder: false);
      expect(find.byKey(ReviewScreen.moreKey), findsOneWidget);
    }, variant: iOSOnly);

    testWidgets(
        '"Practice with my ticket": medium tap, the ticket tears ("Ticket '
        'used!"), then practice starts (the AI permission first)',
        (tester) async {
      await pump(tester, storage: _Storage(weakSpots: _twoSpots));
      HapticMap.log = [];
      await tester.tap(find.byKey(ReviewScreen.practiceWithTicketKey));
      await tester.pump();
      expect(HapticMap.log!.first, 'medium');
      expect(ticketState(tester), TicketState.tearing);
      expect(find.text('Ticket used!'), findsOneWidget);
      await tester.pump(Ticket.tearDuration);
      await tester.pumpAndSettle();
      expect(find.byType(AiConsentScreen), findsOneWidget);
    });

    testWidgets('no ticket for a Premium user (R12), the Premium chip instead',
        (tester) async {
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots),
          subscription: _Subscription(hasAccess: true));
      expect(ticket, findsNothing);
      expect(find.byType(PremiumChip), findsOneWidget);
      expect(find.text('Practice with my ticket'), findsNothing);
    });

    testWidgets(
        're-read when the tab becomes visible again: a practice used '
        'elsewhere shows as used', (tester) async {
      final storage = _Storage(weakSpots: _twoSpots);
      await pump(tester, storage: storage);
      expect(ticketState(tester), TicketState.free);

      storage.freePracticeCount = StorageService.freeDailyPracticeLimit;
      await pump(tester, storage: storage, active: false);
      await pump(tester, storage: storage, active: true);
      expect(ticketState(tester), TicketState.used);
    });

    testWidgets(
        're-read when a weak spot\'s screen closes; opening it spends '
        'nothing', (tester) async {
      final storage = _Storage(weakSpots: _twoSpots);
      await pump(tester, storage: storage);
      await tester.ensureVisible(find.byType(ReviewSpotCard).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ReviewSpotCard).last);
      await tester.pumpAndSettle();
      expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
      expect(storage.freePracticeCount, 0);

      storage.freePracticeCount = StorageService.freeDailyPracticeLimit;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ticketState(tester), TicketState.used);
    });

    testWidgets('a trial starting hides it without a restart', (tester) async {
      final subscription = _Subscription();
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots), subscription: subscription);
      expect(ticket, findsOneWidget);
      subscription.emit(true);
      await tester.pumpAndSettle();
      expect(ticket, findsNothing);
    });
  });

  testWidgets(
      'empty (RV05): the ticket waits for the first weak spot, the companion '
      'cheers, one way to the Daily Test', (tester) async {
    var toHome = 0;
    await pump(tester, storage: _Storage(), onGoToPractice: () => toHome++);
    expect(ticketState(tester), TicketState.free);
    expect(find.text('Waiting for your first weak spot.'), findsOneWidget);
    expect(tester.widget<Ticket>(ticket).onTap, isNull);
    expect(find.text('No weak spots yet!'), findsOneWidget);
    await tester.tap(find.text('Take today’s Daily Test'));
    await tester.pump();
    expect(toHome, 1);
  });

  testWidgets(
      'the list: every saved weak spot as a card with its latest mistake '
      'inline, and the total', (tester) async {
    await pump(tester,
        storage: _Storage(weakSpots: _twoSpots, topicStats: const {
          'articles': TopicStats(practiced: 4, weakSpotCount: 2),
        })
          ..latest = ErrorEntry(
            topicId: 'articles',
            errorType: 'missing_article',
            timestamp: DateTime(2026, 11, 17),
            source: ErrorSource.dailyTest,
            userAnswer: 'She is a tallest girl in her class.',
            correctedAnswer: 'She is the tallest girl in her class.',
          ));
    expect(find.text('Weak spots'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(ReviewSpotCard), findsNWidgets(2));
    expect(find.byType(InlineMistake), findsNWidgets(2));
    final parts = InlineMistake.parts(
        tester.widget<InlineMistake>(find.byType(InlineMistake).first).entry)!;
    expect(parts.map((p) => p.$1).join(),
        'She is a the tallest girl in her class.');
  });

  group('sort order (unchanged behaviour, moved to the list heading)', () {
    testWidgets('the stored order is read and shown', (tester) async {
      final storage =
          _Storage(weakSpots: _twoSpots, storedSort: ReviewSortOrder.frequent);
      await pump(tester, storage: storage);
      expect(find.text(ReviewSortOrder.frequent.label(en)), findsOneWidget);
      expect(storage.weakSpotReads.last, ReviewSortOrder.frequent);
    });

    testWidgets(
        'the sort sheet (RV06): two options, the current one checked; a new '
        'choice reloads the list and is saved', (tester) async {
      final storage = _Storage(weakSpots: _twoSpots);
      await pump(tester, storage: storage);
      await tester.ensureVisible(find.byKey(ReviewScreen.sortKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ReviewScreen.sortKey));
      await tester.pumpAndSettle();
      expect(find.text('Sort weak spots'), findsOneWidget);
      expect(find.text('Newest mistakes first'), findsOneWidget);
      expect(find.text('The ones you miss most'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('review_sort_frequent')));
      await tester.pumpAndSettle();
      expect(storage.savedSorts, [ReviewSortOrder.frequent]);
      expect(storage.weakSpotReads.last, ReviewSortOrder.frequent);
    });
  });

  for (final width in [320.0, 390.0, 430.0]) {
    for (final brightness in Brightness.values) {
      for (final used in [false, true]) {
        testWidgets(
            '${width.toInt()} pt, Large text, ${brightness.name}, '
            '${used ? 'used' : 'available'}: no overflow', (tester) async {
          await pump(tester,
              size: Size(width, 844),
              brightness: brightness,
              textSize: AppTextSize.large,
              storage: _Storage(
                  weakSpots: _twoSpots,
                  freePracticeCount:
                      used ? StorageService.freeDailyPracticeLimit : 0));
          expect(tester.takeException(), isNull);
          final page = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          while (page.pixels < page.maxScrollExtent) {
            page.jumpTo((page.pixels + 300)
                .clamp(0.0, page.maxScrollExtent)
                .toDouble());
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        });
      }
    }
  }
}
