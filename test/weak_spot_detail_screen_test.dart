import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/widgets/locked_premium_pill.dart';

/// The bottom action's own visual states (this batch's UI spec) — separate
/// from practice_launch_free_tier_test.dart, which proves the *gating
/// behavior* through both real entry points. This file is only concerned
/// with what's actually on screen: the caption text, the locked row's
/// visual language, and that premium shows neither.

class _FakeSubscriptionService extends SubscriptionService {
  final bool hasAccess;

  _FakeSubscriptionService({required this.hasAccess});

  @override
  Future<bool> get hasFullAccess async => hasAccess;
}

class _FakeStorageService extends StorageService {
  int freePracticeCount;

  _FakeStorageService({this.freePracticeCount = 0});

  @override
  Future<int> getFreePracticeCountForToday() async => freePracticeCount;

  @override
  Future<List<ErrorEntry>> getRecentMistakes(
    String topicId,
    String errorType, {
    int limit = 3,
  }) async =>
      const [];
}

WeakSpot _weakSpot() => WeakSpot(
      topicId: kTopics.first.id.name,
      errorType: 'missing_article',
      frequency: 3,
      lastSeen: DateTime.now(),
    );

Future<void> _pump(
  WidgetTester tester, {
  required bool hasAccess,
  int freePracticeCount = 0,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: WeakSpotDetailScreen(
        topic: kTopics.first,
        spot: _weakSpot(),
        claudeService: ClaudeService(),
        storageService:
            _FakeStorageService(freePracticeCount: freePracticeCount),
        analyticsService: AnalyticsService(),
        subscriptionService: _FakeSubscriptionService(hasAccess: hasAccess),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'free user with quota available: enabled button plus a caption '
      'naming the remaining count — never "unlimited"', (tester) async {
    await _pump(tester, hasAccess: false, freePracticeCount: 0);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Practice this'),
    );
    expect(button.onPressed, isNotNull);
    expect(
      find.text(
        '${StorageService.freeDailyPracticeLimit} free practice'
        '${StorageService.freeDailyPracticeLimit == 1 ? '' : 's'} today',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('unlimited'), findsNothing);
    expect(find.byType(LockedPremiumPill), findsNothing);
  });

  testWidgets(
      'free user with quota exhausted: no enabled button at all — a '
      'locked row using the same LockedPremiumPill Home already uses',
      (tester) async {
    await _pump(
      tester,
      hasAccess: false,
      freePracticeCount: StorageService.freeDailyPracticeLimit,
    );

    expect(find.widgetWithText(FilledButton, 'Practice this'), findsNothing);
    expect(find.byType(LockedPremiumPill), findsOneWidget);
    // Still names "Practice this" — muted, not hidden.
    expect(find.text('Practice this'), findsOneWidget);
    expect(
      find.textContaining("You've used today's free practice"),
      findsOneWidget,
    );
    expect(find.textContaining('unlimited'), findsNothing);

    await tester.tap(find.text('Practice this'));
    await tester.pumpAndSettle();

    expect(find.byType(PremiumScreen), findsOneWidget);
    final premium = tester.widget<PremiumScreen>(find.byType(PremiumScreen));
    expect(premium.sourceContext, 'Missing Article');
  });

  testWidgets(
      'premium user: plain enabled button, no caption at all — nothing to '
      'name since there is no quota', (tester) async {
    await _pump(tester, hasAccess: true);

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Practice this'),
    );
    expect(button.onPressed, isNotNull);
    expect(find.textContaining('free practice'), findsNothing);
    expect(find.byType(LockedPremiumPill), findsNothing);
  });
}
