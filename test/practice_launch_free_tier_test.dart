import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/practice_set.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/practice_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';

/// Proves `launchPracticeSet`'s entitlement/quota gate (added this batch to
/// close the free-tier "Practice this" leak — see docs/build-log.md) from
/// BOTH of its two real callers, TopicPracticeScreen and
/// WeakSpotDetailScreen, against the exact same in-memory fakes — the point
/// being that this is one shared choke point, not two screens each doing
/// their own thing that happen to agree today.
///
/// Widget-level, in-memory fakes throughout — same rationale as
/// practice_launch_daily_cap_test.dart's own header comment: real sqlite I/O
/// hangs inside `testWidgets`' fake-async zone.

class _FakeSubscriptionService extends SubscriptionService {
  final bool hasAccess;

  _FakeSubscriptionService({required this.hasAccess});

  @override
  Future<bool> get hasFullAccess async => hasAccess;
}

class _FakeStorageService extends StorageService {
  int sessionCount = 0;
  int freePracticeCount;
  int recordFreePracticeCalls = 0;

  _FakeStorageService({this.freePracticeCount = 0});

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};

  @override
  Future<int> getSessionCountForToday() async => sessionCount;

  @override
  Future<void> recordSessionStarted() async => sessionCount++;

  @override
  Future<int> getFreePracticeCountForToday() async => freePracticeCount;

  @override
  Future<void> recordFreePracticeStarted() async {
    freePracticeCount++;
    recordFreePracticeCalls++;
  }

  @override
  Future<PracticeLength> getPracticeLength() async => PracticeLength.standard;

  @override
  Future<void> setPracticeLength(PracticeLength length) async {}

  @override
  Future<String> getOrCreateDeviceId() async => 'test-device';

  @override
  Future<List<ErrorEntry>> getRecentMistakes(
    String topicId,
    String errorType, {
    int limit = 3,
  }) async =>
      const [];
}

/// Records every call instead of hitting the network — also lets a test
/// assert exactly how many questions were requested (proving the free tier
/// gets the shortest length, never the picker's choice) and, just as
/// importantly, that it was never called at all when the quota gate should
/// have stopped things first.
class _FakeClaudeService extends ClaudeService {
  int generateCalls = 0;
  int? lastCount;

  @override
  Future<PracticeSet> generatePracticeSet(
    Topic topic, {
    required String deviceId,
    int count = 5,
  }) async {
    generateCalls++;
    lastCount = count;
    return PracticeSet(
      topicId: topic.id.name,
      items: List.generate(
        count,
        (i) => PracticeItem(
          id: 'q$i',
          type: PracticeItemType.fillInBlank,
          instruction: 'Question $i',
        ),
      ),
    );
  }
}

WeakSpot _weakSpot() => WeakSpot(
      topicId: kTopics.first.id.name,
      errorType: 'missing_article',
      frequency: 3,
      lastSeen: DateTime.now(),
    );

void main() {
  group('quota available: generates directly, skips the picker', () {
    testWidgets('via TopicPracticeScreen', (tester) async {
      final storage = _FakeStorageService();
      final claude = _FakeClaudeService();
      await tester.pumpWidget(
        MaterialApp(
          home: TopicPracticeScreen(
            claudeService: claude,
            storageService: storage,
            analyticsService: AnalyticsService(),
            subscriptionService: _FakeSubscriptionService(hasAccess: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(find.text('How many questions?'), findsNothing);
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(claude.generateCalls, 1);
      // The shortest length (PracticeLength.quick), never the picker's own
      // remembered/default choice.
      expect(claude.lastCount, PracticeLength.quick.questionCount);
      expect(storage.freePracticeCount, 1);
      expect(storage.sessionCount, 1);
    });

    testWidgets('via WeakSpotDetailScreen\'s "Practice this"', (tester) async {
      final storage = _FakeStorageService();
      final claude = _FakeClaudeService();
      await tester.pumpWidget(
        MaterialApp(
          home: WeakSpotDetailScreen(
            topic: kTopics.first,
            spot: _weakSpot(),
            claudeService: claude,
            storageService: storage,
            analyticsService: AnalyticsService(),
            subscriptionService: _FakeSubscriptionService(hasAccess: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Practice this'));
      await tester.pumpAndSettle();

      expect(find.text('How many questions?'), findsNothing);
      expect(find.byType(PracticeScreen), findsOneWidget);
      expect(claude.generateCalls, 1);
      expect(claude.lastCount, PracticeLength.quick.questionCount);
      expect(storage.freePracticeCount, 1);
    });
  });

  group('quota exhausted: generation is never called, routes to Premium', () {
    testWidgets(
        'via TopicPracticeScreen — proves the internal gate itself, not '
        "just a screen that happens not to offer the button (Home's own "
        'lock UI is what normally prevents a free user from reaching this '
        'screen at all; this is the choke point catching it anyway)',
        (tester) async {
      final storage =
          _FakeStorageService(freePracticeCount: StorageService.freeDailyPracticeLimit);
      final claude = _FakeClaudeService();
      await tester.pumpWidget(
        MaterialApp(
          home: TopicPracticeScreen(
            claudeService: claude,
            storageService: storage,
            analyticsService: AnalyticsService(),
            subscriptionService: _FakeSubscriptionService(hasAccess: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      expect(claude.generateCalls, 0);
      expect(find.byType(PracticeScreen), findsNothing);
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets(
        'via WeakSpotDetailScreen — the locked row replaces the button '
        'entirely, and tapping it never reaches generation either',
        (tester) async {
      final storage =
          _FakeStorageService(freePracticeCount: StorageService.freeDailyPracticeLimit);
      final claude = _FakeClaudeService();
      await tester.pumpWidget(
        MaterialApp(
          home: WeakSpotDetailScreen(
            topic: kTopics.first,
            spot: _weakSpot(),
            claudeService: claude,
            storageService: storage,
            analyticsService: AnalyticsService(),
            subscriptionService: _FakeSubscriptionService(hasAccess: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // No enabled "Practice this" FilledButton at all in this state.
      expect(find.widgetWithText(FilledButton, 'Practice this'), findsNothing);
      expect(find.text('Practice this'), findsOneWidget);

      await tester.tap(find.text('Practice this'));
      await tester.pumpAndSettle();

      expect(claude.generateCalls, 0);
      expect(find.byType(PracticeScreen), findsNothing);
      expect(find.byType(PremiumScreen), findsOneWidget);
    });
  });

  testWidgets(
      'a premium user is unaffected even if the free-tier counter is '
      'already at/over its limit — the new check is a no-op for '
      'hasFullAccess', (tester) async {
    final storage =
        _FakeStorageService(freePracticeCount: StorageService.freeDailyPracticeLimit + 3);
    final claude = _FakeClaudeService();
    await tester.pumpWidget(
      MaterialApp(
        home: TopicPracticeScreen(
          claudeService: claude,
          storageService: storage,
          analyticsService: AnalyticsService(),
          subscriptionService: _FakeSubscriptionService(hasAccess: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    // Full access still gets the length picker, unchanged from before this
    // batch. `_FakeStorageService.getPracticeLength` returns `.standard`,
    // so the picker's confirm button reads its question count (5).
    expect(find.text('How many questions?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start 5 questions'));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumScreen), findsNothing);
    expect(find.byType(PracticeScreen), findsOneWidget);
    expect(claude.generateCalls, 1);
    expect(claude.lastCount, PracticeLength.standard.questionCount);
  });
}
