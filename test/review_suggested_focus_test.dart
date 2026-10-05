import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/weak_spot_card.dart';

/// Premium Review's Suggested Focus (1.2.0 final screens, brief §2).
class _Subs extends SubscriptionService {
  final Completer<bool>? pending;
  final bool access;
  _Subs(this.access, {this.pending});

  @override
  Future<bool> get hasFullAccess =>
      pending?.future ?? Future<bool>.value(access);
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

class _Storage extends StorageService {
  List<WeakSpot> spots;
  int freeUsed;
  bool failAll = false;
  Completer<void>? pendingAll;
  final reads = <int>[];

  _Storage(this.spots, {this.freeUsed = 0});

  @override
  Future<List<WeakSpot>> getWeakSpots(
      {int limit = 10,
      ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async {
    reads.add(limit);
    if (limit == StorageService.allWeakSpots) {
      if (pendingAll != null) await pendingAll!.future;
      if (failAll) throw StateError('read failed');
    }
    final sorted = [...spots]..sort(sortOrder == ReviewSortOrder.frequent
        ? (a, b) => b.frequency.compareTo(a.frequency)
        : (a, b) => b.lastSeen.compareTo(a.lastSeen));
    return sorted.take(limit).toList();
  }

  @override
  Future<int> getFreePracticeCountForToday() async => freeUsed;
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};
  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => ReviewSortOrder.recent;
  @override
  Future<void> setReviewSortOrder(ReviewSortOrder order) async {}
  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      const [];
  @override
  Future<int> getSessionCountForToday() async => 0;
  @override
  Future<AiConsent?> getAiConsent() async => null;
}

WeakSpot _spot(String type, int count, DateTime lastSeen,
        {String topic = 'articles'}) =>
    WeakSpot(
        topicId: topic,
        errorType: type,
        frequency: count,
        lastSeen: lastSeen,
        latestExplanation: 'Use "the" for a specific noun.');

final _three = [
  _spot('gerund_after_enjoy', 1, DateTime(2026, 10, 5),
      topic: 'gerundVsInfinitive'),
  _spot('modal_past_form', 2, DateTime(2026, 10, 4), topic: 'modalVerbs'),
  _spot('missing_article', 1, DateTime(2026, 10, 3)),
];

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  Future<void> pump(WidgetTester tester,
      {required _Storage storage,
      required _Subs subs,
      Size size = const Size(390, 844),
      AppTextSize textSize = AppTextSize.medium,
      Brightness brightness = Brightness.light,
      bool settle = true}) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      theme: buildAppTheme(brightness, textSize: textSize),
      home: ReviewScreen(
        key: UniqueKey(),
        claudeService: ClaudeService(),
        storageService: storage,
        analyticsService: AnalyticsService(),
        subscriptionService: subs,
        active: true,
        onGoToPractice: () {},
      ),
    ));
    if (settle) await tester.pumpAndSettle();
  }

  final focus = find.byKey(SuggestedFocusCard.cardKey);

  group('visibility', () {
    testWidgets('Free (available and used): the daily card, no suggestion',
        (tester) async {
      await pump(tester, storage: _Storage(_three), subs: _Subs(false));
      expect(find.byKey(DailyPracticeCard.availableKey), findsOneWidget);
      expect(focus, findsNothing);
      await pump(tester,
          storage:
              _Storage(_three, freeUsed: StorageService.freeDailyPracticeLimit),
          subs: _Subs(false));
      expect(find.byKey(DailyPracticeCard.usedKey), findsOneWidget);
      expect(focus, findsNothing);
      expect(find.text('SUGGESTED FOCUS'), findsNothing);
    });

    testWidgets(
        'Premium: the suggestion, never tied to the free allowance '
        '(no daily card, no "tomorrow")', (tester) async {
      await pump(tester,
          storage:
              _Storage(_three, freeUsed: StorageService.freeDailyPracticeLimit),
          subs: _Subs(true));
      expect(focus, findsOneWidget);
      expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
      expect(find.byKey(DailyPracticeCard.usedKey), findsNothing);
      expect(find.textContaining('tomorrow'), findsNothing);
      expect(find.text('SUGGESTED FOCUS'), findsOneWidget);
      expect(find.text('Modal Past Form'), findsNWidgets(2)); // card + list
      expect(find.text('Saved 2 times · Most repeated'), findsOneWidget);
      expect(find.text('Practice this weak spot'), findsOneWidget);
      expect(find.textContaining('Premium'), findsNothing);
    });

    testWidgets('"Saved 1 time" for one', (tester) async {
      await pump(tester,
          storage: _Storage([_spot('a_vs_an', 1, DateTime(2026, 10, 1))]),
          subs: _Subs(true));
      expect(find.text('Saved 1 time · Most repeated'), findsOneWidget);
    });

    testWidgets(
        'while the entitlement is unknown, neither card shows; then the '
        'right one', (tester) async {
      final pending = Completer<bool>();
      await pump(tester,
          storage: _Storage(_three),
          subs: _Subs(false, pending: pending),
          settle: false);
      await tester.pump();
      await tester.pump();
      expect(focus, findsNothing);
      expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
      pending.complete(true);
      await tester.pumpAndSettle();
      expect(focus, findsOneWidget);
      expect(find.byKey(DailyPracticeCard.availableKey), findsNothing);
    });
  });

  group('selection', () {
    testWidgets(
        'from every saved weak spot, not the ten listed: a record the list '
        'does not show can be the suggestion', (tester) async {
      final recent = [
        for (var i = 0; i < 10; i++)
          _spot('recent_$i', 1, DateTime(2026, 10, 20 - i)),
      ];
      final older = _spot('older_one', 4, DateTime(2026, 1, 1));
      final storage = _Storage([...recent, older]);
      await pump(tester,
          storage: storage, subs: _Subs(true), size: const Size(390, 3000));
      expect(storage.reads, contains(StorageService.allWeakSpots));
      expect(find.byType(WeakSpotCard), findsNWidgets(10));
      expect(find.descendant(of: focus, matching: find.text('Older One')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(WeakSpotCard), matching: find.text('Older One')),
          findsNothing);
    });

    testWidgets('changing the list\'s sort does not change the suggestion',
        (tester) async {
      await pump(tester, storage: _Storage(_three), subs: _Subs(true));
      String title() => tester
          .widgetList<Text>(
              find.descendant(of: focus, matching: find.byType(Text)))
          .map((t) => t.data)
          .whereType<String>()
          .firstWhere((t) => t == 'Modal Past Form');
      expect(title(), 'Modal Past Form');
      await tester.tap(find.byTooltip('Sort weak spots'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ReviewSortOrder.frequent.label).last);
      await tester.pumpAndSettle();
      expect(title(), 'Modal Past Form');
    });

    testWidgets(
        'after the data changes (a deletion, a new count) the suggestion is '
        'read again, never kept', (tester) async {
      final storage = _Storage(_three);
      await pump(tester, storage: storage, subs: _Subs(true));
      expect(find.descendant(of: focus, matching: find.text('Modal Past Form')),
          findsOneWidget);
      // Back from a weak spot with different data underneath.
      storage.spots = [
        _spot('missing_article', 5, DateTime(2026, 10, 6)),
        _spot('gerund_after_enjoy', 1, DateTime(2026, 10, 5),
            topic: 'gerundVsInfinitive'),
      ];
      await tester.tap(find.byKey(SuggestedFocusCard.ctaKey));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(WeakSpotDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.descendant(of: focus, matching: find.text('Missing Article')),
          findsOneWidget);
      expect(find.text('Modal Past Form'), findsNothing);
    });
  });

  group('the call to action', () {
    testWidgets(
        'opens the chosen weak spot\'s own screen; its practice still asks '
        'for the AI permission first', (tester) async {
      await pump(tester, storage: _Storage(_three), subs: _Subs(true));
      await tester.tap(find.byKey(SuggestedFocusCard.ctaKey));
      await tester.pumpAndSettle();
      final detail = tester
          .widget<WeakSpotDetailScreen>(find.byType(WeakSpotDetailScreen));
      expect((detail.spot.topicId, detail.spot.errorType),
          ('modalVerbs', 'modal_past_form'));
      await tester.tap(find.text('Practice this'));
      await tester.pumpAndSettle();
      expect(find.byType(AiConsentScreen), findsOneWidget);
    });

    testWidgets('a double tap opens it once', (tester) async {
      await pump(tester, storage: _Storage(_three), subs: _Subs(true));
      await tester.tap(find.byKey(SuggestedFocusCard.ctaKey));
      await tester.tap(find.byKey(SuggestedFocusCard.ctaKey),
          warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(WeakSpotDetailScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(WeakSpotDetailScreen), findsNothing);
      expect(focus, findsOneWidget);
    });
  });

  group('states', () {
    testWidgets(
        'no saved weak spot (Premium): the practice prompt to Topic '
        'Practice; Free keeps its own empty state', (tester) async {
      await pump(tester, storage: _Storage(const []), subs: _Subs(true));
      expect(find.text('Your next step starts with practice.'), findsOneWidget);
      expect(
          find.text('As you practice, your mistakes will appear here so you '
              'can work on them again.'),
          findsOneWidget);
      expect(focus, findsNothing);
      await tester.tap(find.byKey(PremiumReviewEmpty.ctaKey));
      await tester.pumpAndSettle();
      expect(find.byType(TopicPracticeScreen), findsOneWidget);

      await pump(tester, storage: _Storage(const []), subs: _Subs(false));
      expect(find.text('No weak spots yet.'), findsOneWidget);
      expect(find.text('Your next step starts with practice.'), findsNothing);
    });

    testWidgets(
        'loading: the card\'s place is kept, with no topic or count shown',
        (tester) async {
      final storage = _Storage(_three)..pendingAll = Completer<void>();
      await pump(tester, storage: storage, subs: _Subs(true), settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(focus, findsOneWidget);
      expect(find.text('SUGGESTED FOCUS'), findsOneWidget);
      expect(find.textContaining('Most repeated'), findsNothing);
      expect(find.byKey(SuggestedFocusCard.ctaKey), findsNothing);
      storage.pendingAll!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(SuggestedFocusCard.ctaKey), findsOneWidget);
    });

    testWidgets(
        'a failed read says so with a retry, and is not shown as "no weak '
        'spots"', (tester) async {
      final storage = _Storage(_three)..failAll = true;
      await pump(tester, storage: storage, subs: _Subs(true));
      expect(find.text('Your suggestion could not be loaded.'), findsOneWidget);
      expect(find.text('Your next step starts with practice.'), findsNothing);
      expect(find.byType(WeakSpotCard), findsNWidgets(3));
      storage.failAll = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byKey(SuggestedFocusCard.ctaKey), findsOneWidget);
    });
  });

  testWidgets(
      'back from a weak spot: the scroll position and the sort are kept',
      (tester) async {
    final spots = [
      for (var i = 0; i < 10; i++)
        _spot('weak_spot_$i', 1 + i % 3, DateTime(2026, 10, 20 - i)),
    ];
    await pump(tester, storage: _Storage(spots), subs: _Subs(true));
    await tester.tap(find.byTooltip('Sort weak spots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ReviewSortOrder.frequent.label).last);
    await tester.pumpAndSettle();
    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(0));
    final card = find.byType(WeakSpotCard).hitTestable().first;
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(WeakSpotDetailScreen))).pop();
    await tester.pumpAndSettle();
    expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        offset);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(find.text(ReviewSortOrder.frequent.label), findsOneWidget);
  });

  group('the same size as the Free card (owner, 2026-10-06)', () {
    for (final width in const [320.0, 360.0, 390.0, 430.0]) {
      for (final size in AppTextSize.values) {
        testWidgets(
            '${width.toInt()} pt, ${size.name}: Free available and Premium '
            'have equal bounds; the list starts at the same place',
            (tester) async {
          await pump(tester,
              storage: _Storage(_three),
              subs: _Subs(false),
              size: Size(width, 1600),
              textSize: size);
          final free =
              tester.getRect(find.byKey(DailyPracticeCard.availableKey));
          final freeList = tester.getRect(find.byType(WeakSpotCard).first).top;
          await pump(tester,
              storage: _Storage(_three),
              subs: _Subs(true),
              size: Size(width, 1600),
              textSize: size);
          final premium =
              tester.getRect(find.byKey(SuggestedFocusCard.cardKey));
          expect(premium, free);
          expect(tester.getRect(find.byType(WeakSpotCard).first).top, freeList);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('the loading and failed cards hold the same height as well',
        (tester) async {
      await pump(tester, storage: _Storage(_three), subs: _Subs(false));
      final free = tester.getRect(find.byKey(DailyPracticeCard.availableKey));
      final pending = _Storage(_three)..pendingAll = Completer<void>();
      await pump(tester, storage: pending, subs: _Subs(true), settle: false);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(tester.getRect(focus), free);
      pending.pendingAll!.complete();
      await tester.pumpAndSettle();
      await pump(tester,
          storage: _Storage(_three)..failAll = true, subs: _Subs(true));
      expect(tester.getRect(focus), free);
    });

    testWidgets(
        '320 pt, Large, a long title: wraps and is read in full; the card '
        'grows rather than cutting it', (tester) async {
      await pump(tester,
          storage: _Storage([
            _spot(
                'subject_verb_agreement_with_collective_nouns_and_quantifiers',
                3,
                DateTime(2026, 10, 1)),
          ]),
          subs: _Subs(true),
          size: const Size(320, 1600),
          textSize: AppTextSize.large);
      final title = find.descendant(
          of: focus,
          matching: find.text(
              'Subject Verb Agreement With Collective Nouns And Quantifiers'));
      expect(title, findsOneWidget);
      expect(tester.takeException(), isNull);
      final card = tester.getRect(focus);
      expect(tester.getRect(title).bottom, lessThan(card.bottom));
      expect(tester.getRect(find.byKey(SuggestedFocusCard.ctaKey)).bottom,
          lessThan(card.bottom));
    });

    for (final brightness in Brightness.values) {
      testWidgets(
          '${brightness.name}: navy with the dark edge, an orange call to '
          'action', (tester) async {
        await pump(tester,
            storage: _Storage(_three),
            subs: _Subs(true),
            brightness: brightness);
        final context = tester.element(focus);
        final palette = AppPalette.of(context);
        final card = tester.widget<Card>(focus);
        expect(card.color, palette.button);
        final side = (card.shape! as RoundedRectangleBorder).side;
        expect(
            side,
            brightness == Brightness.dark
                ? BorderSide(color: palette.buttonEdge!)
                : BorderSide.none);
        final material = tester.widget<Material>(find
            .descendant(
                of: find.byKey(SuggestedFocusCard.ctaKey),
                matching: find.byType(Material))
            .first);
        expect(material.color, Theme.of(context).colorScheme.primary);
      });
    }
  });
}
