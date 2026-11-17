import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

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

final _more = find.byKey(const ValueKey('results_more_premium'));

void _expectNoUpsell(RecordingAnalyticsSink sink) {
  expect(_more, findsNothing);
  expect(find.text('See Premium'), findsNothing);
  expect(_upsellEvents(sink), isEmpty);
  expect(
      find.widgetWithText(PressableButton, 'Back to topics'), findsOneWidget);
}

void main() {
  testWidgets(
      'V21: the score as "N/M correct", the skipped count beside it, the '
      'companion cheering', (tester) async {
    await _pump(
      tester,
      storage: _FakeStorageService(),
      subscription: _FakeSubscriptionService(),
    );
    // Back to the top (the harness scrolls to the end).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(find.text('1/2 correct'), findsOneWidget);
    expect(find.text('1/2 correct · 1 skipped'), findsOneWidget);
    expect(find.byType(CompanionView), findsWidgets);
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

      // V21: "Want another round today?", Premium's sessions, See Premium;
      // "Back to topics" stays in the bar.
      final cta = find.widgetWithText(PressableButton, 'See Premium');
      expect(_more, findsOneWidget);
      expect(find.text('Want another round today?'), findsOneWidget);
      expect(find.text('Premium: up to 5 sessions a day, every topic.'),
          findsOneWidget);
      expect(find.descendant(of: _more, matching: cta), findsOneWidget);
      expect(find.widgetWithText(PressableButton, 'Back to topics'),
          findsOneWidget);
      expect(find.textContaining('nlimited'), findsNothing);
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

  testWidgets(
      '320 pt wide, Large text, 2.0 system scale: the offer fits, no '
      'overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 900) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      storage: _FakeStorageService(
        freePracticeCount: StorageService.freeDailyPracticeLimit,
      ),
      subscription: _FakeSubscriptionService(),
      textSize: AppTextSize.large,
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(_more, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
    expect(tester.getRect(_more).right, lessThanOrEqualTo(320));
  });

  testWidgets(
      'without the offer, "Back to topics" returns to the '
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

    await tester.tap(find.widgetWithText(PressableButton, 'Back to topics'));
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

    await tester.tap(find.widgetWithText(PressableButton, 'Back to topics'));
    await tester.pumpAndSettle();

    expect(find.byType(ResultsScreen), findsNothing);
    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.text('root'), findsOneWidget);
    expect(_upsellEvents(sink), ['practice_result_upsell_viewed']);
  });
}
