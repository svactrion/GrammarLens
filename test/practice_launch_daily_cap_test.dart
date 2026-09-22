import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/ai_consent.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/models/topic_stats.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';

/// Real sqlite I/O (even via the ffi factory) doesn't play well inside
/// `testWidgets`' fake-async zone — a widget test exercising the daily-cap
/// gate against a real on-disk StorageService reliably hung the test runner
/// until it was killed. `storage_service_daily_cap_test.dart` already covers
/// the real persistence layer with plain (non-widget) `test()`s, which run
/// outside that zone; this fake keeps the widget-level test of
/// `launchPracticeSet`'s gating in memory only, matching how the rest of the
/// suite treats StorageService in a `testWidgets` context (see
/// widget_test.dart's note on the plugin-less test environment).
class _FakeStorageService extends StorageService {
  int sessionCount;

  _FakeStorageService({this.sessionCount = 0});

  // These tests are about the quota gates, so the user has already agreed to
  // send answers to the AI provider; the permission gate has its own file
  // (practice_launch_consent_test.dart).
  @override
  Future<AiConsent?> getAiConsent() async => AiConsent(
        granted: true,
        decidedAt: DateTime(2026, 1, 1),
        version: AiConsent.currentVersion,
      );

  @override
  Future<Map<String, TopicStats>> getTopicStats() async => const {};

  @override
  Future<int> getSessionCountForToday() async => sessionCount;

  @override
  Future<void> recordSessionStarted() async => sessionCount++;

  @override
  Future<PracticeLength> getPracticeLength() async => PracticeLength.standard;

  @override
  Future<void> setPracticeLength(PracticeLength length) async {}
}

/// A full-access user throughout this file — [StorageService.dailySessionLimit]
/// is the pre-existing global cost guardrail applied regardless of
/// entitlement (docs/build-log.md's PRD v2 §10.1), so these tests fix
/// entitlement at "full access" specifically to isolate that guardrail from
/// the free tier's own, separate `freeDailyPracticeLimit` gate — covered
/// instead by practice_launch_free_tier_test.dart.
class _FakeFullAccessSubscriptionService extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => true;
}

void main() {
  testWidgets('starting a session under the daily cap opens the length picker',
      (tester) async {
    final storageService = _FakeStorageService();
    await tester.pumpWidget(
      MaterialApp(
        home: TopicPracticeScreen(
          claudeService: ClaudeService(),
          storageService: storageService,
          analyticsService: AnalyticsService(),
          subscriptionService: _FakeFullAccessSubscriptionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text('How many questions?'), findsOneWidget);
    expect(find.text("That's all for today"), findsNothing);
  });

  testWidgets(
      'tapping a topic at the daily cap shows a gentle message instead of '
      'the length picker, and never reaches question generation',
      (tester) async {
    final storageService =
        _FakeStorageService(sessionCount: StorageService.dailySessionLimit);
    await tester.pumpWidget(
      MaterialApp(
        home: TopicPracticeScreen(
          claudeService: ClaudeService(),
          storageService: storageService,
          analyticsService: AnalyticsService(),
          subscriptionService: _FakeFullAccessSubscriptionService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();

    expect(find.text("That's all for today"), findsOneWidget);
    // The dialog must show the real cap: 5 since 2026-09-21 (PRD v2 §13.8),
    // pinned literally so a silent change of the constant fails here.
    expect(StorageService.dailySessionLimit, 5);
    expect(find.textContaining('all 5 practice sessions'), findsOneWidget);
    // Never got as far as asking how many questions — the cap is checked
    // before generation is even requested, per practice_launch.dart.
    expect(find.text('How many questions?'), findsNothing);
    expect(find.text('Preparing your questions…'), findsNothing);
  });
}
