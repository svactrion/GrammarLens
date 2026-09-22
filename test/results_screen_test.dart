import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/item_feedback.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/scoring_result.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/results_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/premium_copy.dart';
import 'package:grammar_lens/widgets/premium_offer_card.dart';
import 'package:grammar_lens/widgets/result_score_band.dart';

import 'support/recording_analytics_sink.dart';

class _FakeSubscriptionService extends SubscriptionService {
  final bool hasAccess;
  final bool throws;

  _FakeSubscriptionService({this.hasAccess = false, this.throws = false});

  @override
  Future<bool> get hasFullAccess async {
    if (throws) throw StateError('entitlement check failed');
    return hasAccess;
  }
}

class _FakeStorageService extends StorageService {
  final int freePracticeCount;
  final bool throws;
  int freePracticeReads = 0;

  _FakeStorageService({this.freePracticeCount = 0, this.throws = false});

  @override
  Future<int> getFreePracticeCountForToday() async {
    freePracticeReads++;
    if (throws) throw StateError('storage read failed');
    return freePracticeCount;
  }

  @override
  Future<void> recordPracticeCompletion(String topicId, int answered) async {}

  @override
  Future<void> insertErrors(List<ErrorEntry> entries) async {}

  @override
  Future<UserProfile?> getUserProfile() async => null;
}

final _topic = kTopics.first;

final _practiceSet = PracticeSet(
  topicId: _topic.id.name,
  items: const [
    PracticeItem(
      id: 'i1',
      type: PracticeItemType.fillInBlank,
      instruction: 'She ___ to the store yesterday.',
    ),
    PracticeItem(
      id: 'i2',
      type: PracticeItemType.fillInBlank,
      instruction: 'They ___ home early.',
    ),
  ],
);

// One correct, one skipped, no actual mistakes.
final _result = ScoringResult(
  topicId: _topic.id.name,
  feedback: const [
    ItemFeedback(
      itemId: 'i1',
      isCorrect: true,
      isSkipped: false,
      correctedAnswer: 'went',
      explanation: '',
    ),
    ItemFeedback(
      itemId: 'i2',
      isCorrect: false,
      isSkipped: true,
      correctedAnswer: 'went',
      explanation: '',
    ),
  ],
);

Future<RecordingAnalyticsSink> _pump(
  WidgetTester tester, {
  required StorageService storage,
  required SubscriptionService subscription,
  AppTextSize textSize = AppTextSize.medium,
}) async {
  final sink = RecordingAnalyticsSink();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(Brightness.light, textSize: textSize),
      home: ResultsScreen(
        topic: _topic,
        result: _result,
        practiceSet: _practiceSet,
        answers: const {'i1': 'went', 'i2': ''},
        storageService: storage,
        analyticsService: AnalyticsService(sink: sink),
        subscriptionService: subscription,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // The prompt sits at the end of a lazily built list, past the default
  // 800x600 test viewport; scroll to the end so absent means absent.
  await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
  await tester.pumpAndSettle();
  return sink;
}

List<String> _upsellEvents(RecordingAnalyticsSink sink) => [
      for (final e in sink.events)
        if (e.name.startsWith('practice_result_upsell')) e.name,
    ];

void _expectNoUpsell(RecordingAnalyticsSink sink) {
  expect(find.text(freePracticeUsedMessage), findsNothing);
  expect(find.byType(PremiumOfferCard), findsNothing);
  expect(find.text('See Premium'), findsNothing);
  expect(_upsellEvents(sink), isEmpty);
  // With no offer, "Back to topics" is the screen's only action and stays
  // the filled button.
  expect(find.widgetWithText(FilledButton, 'Back to topics'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, 'Back to topics'), findsNothing);
}

void main() {
  testWidgets('shows its score via the shared ResultScoreBand widget',
      (tester) async {
    await _pump(
      tester,
      storage: _FakeStorageService(),
      subscription: _FakeSubscriptionService(),
    );

    expect(find.byType(ResultScoreBand), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ResultScoreBand),
        matching: find.text('1/2 correct · 1 skipped'),
      ),
      findsOneWidget,
    );
  });

  group('Premium offer card above "Back to topics"', () {
    testWidgets('premium user: never shown, even with a used-up free count',
        (tester) async {
      final storage = _FakeStorageService(
        freePracticeCount: StorageService.freeDailyPracticeLimit,
      );
      final sink = await _pump(
        tester,
        storage: storage,
        subscription: _FakeSubscriptionService(hasAccess: true),
      );

      _expectNoUpsell(sink);
      // Premium has no free quota, so it is not even read.
      expect(storage.freePracticeReads, 0);
    });

    testWidgets('free user with free practice left: not shown', (tester) async {
      final sink = await _pump(
        tester,
        storage: _FakeStorageService(
          freePracticeCount: StorageService.freeDailyPracticeLimit - 1,
        ),
        subscription: _FakeSubscriptionService(),
      );

      _expectNoUpsell(sink);
    });

    testWidgets(
        'free user with free practice used up: the offer card after the '
        'results, "Back to topics" outlined below it, logged once, opens '
        'Premium with its own source', (tester) async {
      final sink = await _pump(
        tester,
        storage: _FakeStorageService(
          freePracticeCount: StorageService.freeDailyPracticeLimit,
        ),
        subscription: _FakeSubscriptionService(),
      );

      final card = find.byType(PremiumOfferCard);
      final back = find.widgetWithText(OutlinedButton, 'Back to topics');
      final cta = find.widgetWithText(FilledButton, 'See Premium');
      expect(card, findsOneWidget);
      expect(back, findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Back to topics'), findsNothing);
      expect(cta, findsOneWidget);
      expect(find.textContaining('nlimited'), findsNothing);

      // Everything the offer says sits inside the card, in order.
      Finder inCard(Finder f) => find.descendant(of: card, matching: f);
      final chip = inCard(find.text('PREMIUM'));
      final title = inCard(find.text('Keep practicing'));
      final body = inCard(find.text(freePracticeUsedMessage));
      final topic = inCard(find.text('Topic Practice'));
      final sessions = inCard(find.text('More Daily Sessions'));
      for (final f in [
        chip,
        title,
        body,
        topic,
        inCard(find.text('Focus on the areas you need')),
        sessions,
        inCard(find.text('Build your progress faster')),
        inCard(cta),
      ]) {
        expect(f, findsOneWidget);
      }
      double top(Finder f) => tester.getTopLeft(f).dy;
      double bottom(Finder f) => tester.getBottomLeft(f).dy;
      expect(top(title), greaterThan(bottom(chip)));
      expect(top(body), greaterThan(bottom(title)));
      expect(top(topic), greaterThan(bottom(body)));
      expect(top(sessions), greaterThan(bottom(body)));
      expect(top(cta), greaterThan(bottom(topic)));
      expect(top(cta), greaterThan(bottom(sessions)));

      // After every result card, aligned with them, and above "Back to
      // topics", which is outside it.
      final resultCards = find.byWidgetPredicate(
        (w) => w is Card && w.color != null,
      );
      // (Scrolled to the end, so only the last result card is still built.)
      expect(resultCards, findsWidgets);
      expect(top(card), greaterThan(bottom(resultCards.last)));
      expect(
          tester.getTopLeft(card).dx, tester.getTopLeft(resultCards.last).dx);
      expect(
          tester.getSize(card).width, tester.getSize(resultCards.last).width);
      expect(find.descendant(of: card, matching: back), findsNothing);
      expect(top(back), greaterThan(bottom(card)));
      expect(_upsellEvents(sink), ['practice_result_upsell_viewed']);

      // Rebuilds do not log it again.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(_upsellEvents(sink), ['practice_result_upsell_viewed']);

      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pumpAndSettle();

      expect(_upsellEvents(sink), [
        'practice_result_upsell_viewed',
        'practice_result_upsell_tapped',
      ]);
      final premium = tester.widget<PremiumScreen>(find.byType(PremiumScreen));
      expect(premium.analyticsSource,
          AnalyticsService.paywallSourcePracticeResult);
      expect(premium.analyticsSource, 'practice_result');
      expect(
        sink.events.where((e) => e.name == 'paywall_viewed').single.parameters,
        {'source': 'practice_result'},
      );
    });

    testWidgets('entitlement read throws: not shown', (tester) async {
      final storage = _FakeStorageService(
        freePracticeCount: StorageService.freeDailyPracticeLimit,
      );
      final sink = await _pump(
        tester,
        storage: storage,
        subscription: _FakeSubscriptionService(throws: true),
      );

      _expectNoUpsell(sink);
      expect(tester.takeException(), isNull);
    });

    testWidgets('free practice count read throws: not shown', (tester) async {
      final sink = await _pump(
        tester,
        storage: _FakeStorageService(throws: true),
        subscription: _FakeSubscriptionService(),
      );

      _expectNoUpsell(sink);
      expect(tester.takeException(), isNull);
    });
  });

  group('offer card fits', () {
    Future<void> pumpAt(
      WidgetTester tester, {
      required double width,
      required AppTextSize textSize,
      required double systemScale,
    }) async {
      tester.view.physicalSize = Size(width, 900) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      tester.platformDispatcher.textScaleFactorTestValue = systemScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(
        tester,
        storage: _FakeStorageService(
          freePracticeCount: StorageService.freeDailyPracticeLimit,
        ),
        subscription: _FakeSubscriptionService(),
        textSize: textSize,
      );
    }

    testWidgets(
        '320 pt wide, Large text, 2.0 system scale: no overflow, benefits '
        'stacked, everything inside the card', (tester) async {
      await pumpAt(
        tester,
        width: 320,
        textSize: AppTextSize.large,
        systemScale: 2.0,
      );

      expect(tester.takeException(), isNull);
      final card = find.byType(PremiumOfferCard);
      expect(card, findsOneWidget);
      expect(
          find.byKey(const Key('premiumOfferBenefitsColumn')), findsOneWidget);
      expect(find.byKey(const Key('premiumOfferBenefitsRow')), findsNothing);
      final cardRect = tester.getRect(card);
      for (final text in [
        'PREMIUM',
        'Keep practicing',
        freePracticeUsedMessage,
        'Topic Practice',
        'Focus on the areas you need',
        'More Daily Sessions',
        'Build your progress faster',
        'See Premium',
      ]) {
        final rect = tester.getRect(find.text(text));
        expect(
            cardRect.left <= rect.left && rect.right <= cardRect.right, isTrue,
            reason: '"$text" stays inside the card horizontally');
      }
      expect(
        tester.getTopLeft(find.text('More Daily Sessions')).dy,
        greaterThan(
            tester.getBottomLeft(find.text('Focus on the areas you need')).dy),
      );
      final back = find.widgetWithText(OutlinedButton, 'Back to topics');
      await tester.scrollUntilVisible(back, 200,
          scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(back).right, lessThanOrEqualTo(320));
    });

    testWidgets('a wide phone at Medium text: benefits side by side',
        (tester) async {
      await pumpAt(
        tester,
        width: 430,
        textSize: AppTextSize.medium,
        systemScale: 1.0,
      );

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('premiumOfferBenefitsRow')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Topic Practice')).dy,
        tester.getTopLeft(find.text('More Daily Sessions')).dy,
      );
    });
  });

  testWidgets(
      'without the offer, "Back to topics" (filled) returns to the '
      'first route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultsScreen(
                  topic: _topic,
                  result: _result,
                  practiceSet: _practiceSet,
                  answers: const {'i1': 'went', 'i2': ''},
                  storageService: _FakeStorageService(),
                  analyticsService: AnalyticsService(
                    sink: RecordingAnalyticsSink(),
                  ),
                  subscriptionService:
                      _FakeSubscriptionService(hasAccess: true),
                ),
              ),
            ),
            child: const Text('root'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Back to topics'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('"Back to topics" still returns to the first route',
      (tester) async {
    final sink = RecordingAnalyticsSink();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ResultsScreen(
                  topic: _topic,
                  result: _result,
                  practiceSet: _practiceSet,
                  answers: const {'i1': 'went', 'i2': ''},
                  storageService: _FakeStorageService(
                    freePracticeCount: StorageService.freeDailyPracticeLimit,
                  ),
                  analyticsService: AnalyticsService(sink: sink),
                  subscriptionService: _FakeSubscriptionService(),
                ),
              ),
            ),
            child: const Text('root'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('root'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(find.text('See Premium'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Back to topics'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
    expect(_upsellEvents(sink), ['practice_result_upsell_viewed']);
  });
}
