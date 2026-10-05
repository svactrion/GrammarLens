import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/weak_spot_card.dart';

/// 1.2.0 Batch 4: Review's layout, the daily free practice card (its two
/// states, read from the existing free practice count, hidden for premium),
/// the empty state and the sort order.

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

  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      const [];
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
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the page title and its line are in the page', (tester) async {
    await pump(tester, storage: _Storage(weakSpots: _twoSpots));
    expect(find.text('Review'), findsOneWidget);
    expect(find.text('Turn your mistakes into progress.'), findsOneWidget);
  });

  group('daily free practice card', () {
    testWidgets(
        'available: orange, says any saved weak spot can take it and how '
        'many are left today', (tester) async {
      await pump(tester, storage: _Storage(weakSpots: _twoSpots));
      final card = find.byKey(DailyPracticeCard.availableKey);
      expect(card, findsOneWidget);
      expect(find.byKey(DailyPracticeCard.usedKey), findsNothing);
      expect(find.text('One weak spot. One step forward.'), findsOneWidget);
      expect(find.text('1 free practice available today'), findsOneWidget);
      final theme = Theme.of(tester.element(card));
      expect(tester.widget<Card>(card).color, theme.colorScheme.primary);
      expect(
          tester
              .widget<Text>(find.text('One weak spot. One step forward.'))
              .style!
              .color,
          theme.colorScheme.onPrimary);
      expect(find.textContaining('unlimited'), findsNothing);
    });

    testWidgets(
        'used today: a different card, text and icon; no free-practice call '
        'to action', (tester) async {
      await pump(tester,
          storage: _Storage(
              weakSpots: _twoSpots,
              freePracticeCount: StorageService.freeDailyPracticeLimit));
      final card = find.byKey(DailyPracticeCard.usedKey);
      expect(card, findsOneWidget);
      expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
      expect(find.text('Today’s practice is complete.'), findsOneWidget);
      expect(find.text('Next free practice tomorrow'), findsOneWidget);
      expect(find.textContaining('available today'), findsNothing);
      expect(find.text('Start free practice'), findsNothing);
      expect(
          find.descendant(of: card, matching: find.byType(ButtonStyleButton)),
          findsNothing);
      // Not by color alone: the icon differs too.
      expect(
          find.descendant(
              of: card, matching: find.byIcon(Icons.schedule_rounded)),
          findsOneWidget);
      expect(
          find.descendant(
              of: card, matching: find.byIcon(Icons.check_circle_rounded)),
          findsNothing);
    });

    testWidgets('hidden for a premium user (Q13)', (tester) async {
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots),
          subscription: _Subscription(hasAccess: true));
      expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
      expect(find.byKey(DailyPracticeCard.usedKey), findsNothing);
    });

    testWidgets(
        're-read when the tab becomes visible again: a practice used '
        'elsewhere shows as used', (tester) async {
      final storage = _Storage(weakSpots: _twoSpots);
      await pump(tester, storage: storage);
      expect(find.byKey(DailyPracticeCard.availableKey), findsOneWidget);

      storage.freePracticeCount = StorageService.freeDailyPracticeLimit;
      await pump(tester, storage: storage, active: false);
      await pump(tester, storage: storage, active: true);
      expect(find.byKey(DailyPracticeCard.usedKey), findsOneWidget);
    });

    testWidgets(
        're-read when a weak spot\'s screen closes; opening it spends '
        'nothing', (tester) async {
      final storage = _Storage(weakSpots: _twoSpots);
      await pump(tester, storage: storage);
      await tester.tap(find.byType(WeakSpotCard).first);
      await tester.pumpAndSettle();
      expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
      // Opening a weak spot does not use the free practice.
      expect(storage.freePracticeCount, 0);

      storage.freePracticeCount = StorageService.freeDailyPracticeLimit;
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(DailyPracticeCard.usedKey), findsOneWidget);
    });

    testWidgets('a trial starting hides it without a restart', (tester) async {
      final subscription = _Subscription();
      await pump(tester,
          storage: _Storage(weakSpots: _twoSpots), subscription: subscription);
      expect(find.byKey(DailyPracticeCard.availableKey), findsOneWidget);
      subscription.emit(true);
      await tester.pumpAndSettle();
      expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
    });
  });

  testWidgets(
      'empty: the empty state and a way back to the Daily Test, and no '
      'allowance card for a weak spot that does not exist', (tester) async {
    var toHome = 0;
    await pump(tester, storage: _Storage(), onGoToPractice: () => toHome++);
    expect(find.text('No weak spots yet.'), findsOneWidget);
    expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
    expect(find.byKey(DailyPracticeCard.usedKey), findsNothing);
    await tester.tap(find.text('Go to Daily Test'));
    await tester.pump();
    expect(toHome, 1);
  });

  testWidgets('the list: every saved weak spot as a card, with the total',
      (tester) async {
    await pump(tester,
        storage: _Storage(weakSpots: _twoSpots, topicStats: const {
          'articles': TopicStats(practiced: 4, weakSpotCount: 2),
        }));
    expect(find.text('Saved weak spots'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byType(WeakSpotCard), findsNWidgets(2));
  });

  group('sort order (unchanged behaviour, moved to the list heading)', () {
    testWidgets('the stored order is read and shown', (tester) async {
      final storage =
          _Storage(weakSpots: _twoSpots, storedSort: ReviewSortOrder.frequent);
      await pump(tester, storage: storage);
      expect(find.text(ReviewSortOrder.frequent.label), findsOneWidget);
      expect(storage.weakSpotReads.last, ReviewSortOrder.frequent);
    });

    testWidgets('a new choice reloads the list and is saved', (tester) async {
      final storage = _Storage(weakSpots: _twoSpots);
      await pump(tester, storage: storage);
      await tester.tap(find.text(ReviewSortOrder.recent.label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ReviewSortOrder.frequent.label).last);
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
