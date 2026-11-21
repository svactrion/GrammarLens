import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:grammar_lens/data/topic_hints.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/review_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/services/widget_payload.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/home_practice.dart';

import 'support/l10n_support.dart';

/// The first-wave topics switched on for 1.5.0 (docs/TOPICS.md phase D,
/// owner decisions 2026-11-19): ten cards on Topic Practice at the device
/// sizes and the largest text size, the copy that counts topics, a new
/// topic's weak spot on Review, on Home and in the tip widget, and an empty
/// practice set treated as a failed generation.
class _Subs extends SubscriptionService {
  final bool access;
  _Subs(this.access);

  @override
  Future<bool> get hasFullAccess async => access;
  @override
  void addAccessListener(AccessListener listener) {}
  @override
  void removeAccessListener(AccessListener listener) {}
}

class _Storage extends StorageService {
  final List<WeakSpot> spots;
  int sessions = 0;
  int freeStarted = 0;
  _Storage([this.spots = const []]);

  @override
  Future<List<WeakSpot>> getWeakSpots(
          {int limit = 10,
          ReviewSortOrder sortOrder = ReviewSortOrder.recent}) async =>
      spots.take(limit).toList();
  @override
  Future<Map<String, TopicStats>> getTopicStats() async => {
        for (final t in practiceTopics())
          t.id.name: const TopicStats(practiced: 128, weakSpotCount: 14),
      };
  @override
  Future<AiConsent?> getAiConsent() async => AiConsent(
        granted: true,
        decidedAt: DateTime(2026, 1, 1),
        version: AiConsent.currentVersion,
      );
  @override
  Future<int> getSessionCountForToday() async => sessions;
  @override
  Future<void> recordSessionStarted() async => sessions++;
  @override
  Future<int> getFreePracticeCountForToday() async => 0;
  @override
  Future<void> recordFreePracticeStarted() async => freeStarted++;
  @override
  Future<PracticeLength> getPracticeLength() async => PracticeLength.standard;
  @override
  Future<void> setPracticeLength(PracticeLength length) async {}
  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';
  @override
  Future<ReviewSortOrder> getReviewSortOrder() async => ReviewSortOrder.recent;
  @override
  Future<void> setReviewSortOrder(ReviewSortOrder order) async {}
  @override
  Future<List<ErrorEntry>> getRecentMistakes(String topicId, String errorType,
          {int limit = 3}) async =>
      const [];
}

WeakSpot _spot(String topicId, String errorType) => WeakSpot(
    topicId: topicId,
    errorType: errorType,
    frequency: 3,
    lastSeen: DateTime(2026, 11, 18),
    latestExplanation: 'A note.');

/// The handoff's five sizes (PROGRESS.md) and the SE.
const _sizes = [
  Size(375, 667),
  Size(390, 844),
  Size(393, 852),
  Size(402, 874),
  Size(428, 926),
  Size(440, 956),
];

void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  group('Topic Practice with ten cards (R01)', () {
    Future<void> pump(WidgetTester tester,
        {required Size size,
        AppTextSize textSize = AppTextSize.large,
        _Storage? storage}) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light, textSize: textSize),
        home: TopicPracticeScreen(
          claudeService: ClaudeService(),
          storageService: storage ?? _Storage(),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subs(true),
        ),
      ));
      await tester.pumpAndSettle();
    }

    for (final size in _sizes) {
      testWidgets(
          '${size.width.toInt()} × ${size.height.toInt()}, the largest text '
          'size: ten cards, nothing cut, nothing off the screen',
          (tester) async {
        await pump(tester, size: size);
        expect(tester.takeException(), isNull);
        final scrollable = find.byType(Scrollable).first;
        final seen = <TopicId>{};
        for (var i = 0; i < 24; i++) {
          for (final t in practiceTopics()) {
            if (find
                .byKey(TopicPracticeScreen.cardKey(t))
                .evaluate()
                .isNotEmpty) {
              seen.add(t.id);
            }
          }
          for (final e in find.byType(Text).evaluate()) {
            final text = e.widget as Text;
            expect(text.overflow, isNot(TextOverflow.ellipsis),
                reason: text.data);
            final rect = tester.getRect(find.byWidget(text));
            expect(rect.left, greaterThanOrEqualTo(-.01), reason: text.data);
            expect(rect.right, lessThanOrEqualTo(size.width + .01),
                reason: text.data);
          }
          await tester.drag(scrollable, const Offset(0, -260));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(seen, TopicId.values.toSet());
        // The end of the list is the last first-wave topic.
        expect(find.byKey(TopicPracticeScreen.cardKey(kFirstWaveTopics.last)),
            findsOneWidget);
      });
    }

    testWidgets('the ten are in order, two a row, the count says 10',
        (tester) async {
      await pump(tester,
          size: const Size(390, 3200), textSize: AppTextSize.medium);
      final topics = practiceTopics();
      expect(topics, hasLength(10));
      Offset? last;
      for (final (i, topic) in topics.indexed) {
        final card = find.byKey(TopicPracticeScreen.cardKey(topic));
        expect(find.descendant(of: card, matching: find.text(topic.title(en))),
            findsOneWidget,
            reason: topic.id.name);
        final at = tester.getTopLeft(card);
        if (last != null) {
          if (i.isOdd) {
            expect(at.dy, closeTo(last.dy, 1), reason: topic.id.name);
            expect(at.dx, greaterThan(last.dx));
          } else {
            expect(at.dy, greaterThan(last.dy), reason: topic.id.name);
          }
        }
        last = at;
      }
      final count = find.byKey(TopicPracticeScreen.topicCountKey);
      if (count.evaluate().isNotEmpty) {
        expect(tester.widget<Text>(count).data, en.topicPracticeCount(10));
      }
    });

    testWidgets(
        'a weak spot in a new topic: that topic is "Picked for you", the '
        'other nine follow', (tester) async {
      await pump(tester,
          size: const Size(390, 3200),
          textSize: AppTextSize.medium,
          storage: _Storage([_spot('conditionals', 'mixed_conditional')]));
      final picked = find.byKey(TopicPracticeScreen.pickedKey);
      expect(picked, findsOneWidget);
      expect(find.descendant(of: picked, matching: find.text('Conditionals')),
          findsOneWidget);
      for (final t in practiceTopics()) {
        if (t.id == TopicId.conditionals) continue;
        expect(find.byKey(TopicPracticeScreen.cardKey(t)), findsOneWidget,
            reason: t.id.name);
      }
    });
  });

  group('copy that counts topics says 10, in every language', () {
    const locales = ['en', 'tr', 'de', 'es', 'pt', 'ja', 'ko', 'ar'];

    test('the count the app passes is the number of practice topics', () {
      expect(practiceTopics().length, 10);
    });

    for (final code in locales) {
      test('$code: the paywall, the table, Home, the rest scene', () {
        final l10n = lookupAppLocalizations(Locale(code));
        final n = practiceTopics().length;
        final lines = [
          l10n.paywallBenefitTopicsBody(n, '3 / 5 / 10', 5),
          l10n.paywallCompareTopics(n),
          l10n.homeUnlockTopics(n),
          l10n.paywallOnTopics(n),
          l10n.restDeckAnyTopic(n),
          l10n.paywallRestTopicsTitle(n),
          l10n.topicPracticeCount(n),
        ];
        for (final line in lines) {
          expect(line, contains('10'), reason: '$code: $line');
        }
        // Without the lengths and the sessions, no line still says 5.
        for (final line in lines.skip(1)) {
          expect(line, isNot(contains('5')), reason: '$code: $line');
        }
      });
    }

    test('English, word for word', () {
      expect(en.paywallCompareTopics(10), 'All 10 topics');
      expect(en.homeUnlockTopics(10), 'Unlock all 10 topics');
      expect(en.paywallOnTopics(10), 'All 10 topics in Topic Practice');
      expect(en.restDeckAnyTopic(10), 'Any of 10 topics');
      expect(en.paywallRestTopicsTitle(10), 'All 10 grammar topics');
      expect(en.topicPracticeCount(10), '10 topics');
    });
  });

  group('Home\'s showcase for a free user', () {
    testWidgets('lists every topic: the picked one and the other nine',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final picked = topicOfWeakSpot('passiveVoice');
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
              child: TopicShowcase(picked: picked, onOpenPaywall: () {})),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Passive Voice'), findsOneWidget);
      expect(find.text('Unlock all 10 topics'), findsOneWidget);
      // The other nine are tiles of a row that scrolls sideways.
      final row = find.byWidgetPredicate(
          (w) => w is ListView && w.scrollDirection == Axis.horizontal);
      expect(tester.widget<ListView>(row).semanticChildCount, 9);
      await tester.drag(row, const Offset(-2000, 0));
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          find.descendant(
              of: row, matching: find.text('Comparatives & Superlatives')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('a weak spot in a new topic', () {
    testWidgets('Review opens it with its own topic, not the first one',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: ReviewScreen(
          claudeService: ClaudeService(),
          storageService:
              _Storage([_spot('relativeClauses', 'who_instead_of_which')]),
          analyticsService: AnalyticsService(),
          subscriptionService: _Subs(true),
          active: true,
          onGoToPractice: () {},
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(SuggestedFocusCard.ctaKey));
      await tester.pumpAndSettle();
      final detail = tester
          .widget<WeakSpotDetailScreen>(find.byType(WeakSpotDetailScreen));
      expect(detail.topic.id, TopicId.relativeClauses);
      expect(detail.spot.topicId, 'relativeClauses');
    });

    test('the tip widget shows that topic\'s own card', () {
      for (final t in kFirstWaveTopics) {
        final lines = kTopicHints[t.id]!;
        for (var day = 0; day < 4; day++) {
          final tip = widgetTipFor(t.id.name, day);
          expect(tip.personal, isTrue, reason: t.id.name);
          expect(tip.topic, t);
          final line = lines[day % lines.length];
          expect(tip.example.isEmpty ? tip.rule : '${tip.rule}: ${tip.example}',
              line);
        }
      }
      // Without a weak spot the daily tip stays on the Daily Test's five.
      for (var day = 0; day < 20; day++) {
        expect(kTopics, contains(widgetTipFor(null, day).topic));
      }
    });
  });

  group('an empty practice set is a failed generation', () {
    ClaudeService serviceAnswering(Object body) => ClaudeService(
          client: MockClient((_) async => http.Response(jsonEncode(body), 200)),
          proxyBaseUrl: 'https://proxy.test',
          appToken: 'test-token',
        );

    test('the service throws; the screen shows the app\'s general sentence',
        () async {
      Object? thrown;
      try {
        await serviceAnswering({'items': []})
            .generatePracticeSet(kTopics.first, deviceId: 'd1');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isA<ClaudeApiException>());
      final error = thrown! as ClaudeApiException;
      expect(error.reason, ClaudeApiErrorReason.emptySet);
      expect(error.kind, ClaudeApiErrorKind.upstream);
      expect(userFacingErrorMessage(error, en), en.errorGeneral);
      final tr = lookupAppLocalizations(const Locale('tr'));
      expect(userFacingErrorMessage(error, tr), tr.errorGeneral);
      expect(userFacingErrorMessage(error, tr), isNot(error.message));
    });

    test('a set with a question is served as it was', () async {
      final set = await serviceAnswering({
        'items': [
          {'id': 'q1', 'type': 'fill_in_blank', 'instruction': 'A ___.'},
        ]
      }).generatePracticeSet(kFirstWaveTopics.first, deviceId: 'd1');
      expect(set.items, hasLength(1));
      expect(set.topicId, 'conditionals');
    });

    testWidgets(
        'from Topic Practice: no practice screen, no session counted, the '
        'topics are back', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final storage = _Storage();
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: TopicPracticeScreen(
          claudeService: serviceAnswering({'items': []}),
          storageService: storage,
          analyticsService: AnalyticsService(),
          // A free user goes straight to the generation (no length step).
          subscriptionService: _Subs(false),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await tester
            .tap(find.byKey(TopicPracticeScreen.cardKey(kTopics.first)));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
      expect(find.byType(PracticeScreen), findsNothing);
      expect(storage.sessions, 0);
      expect(storage.freeStarted, 0);
      expect(find.byKey(TopicPracticeScreen.cardKey(kTopics.first)),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
