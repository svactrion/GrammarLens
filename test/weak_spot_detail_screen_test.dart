import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/topic.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
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
  final List<ErrorEntry> mistakes;

  _FakeStorageService({this.freePracticeCount = 0, this.mistakes = const []});

  @override
  Future<int> getFreePracticeCountForToday() async => freePracticeCount;

  @override
  Future<List<ErrorEntry>> getRecentMistakes(
    String topicId,
    String errorType, {
    int limit = 3,
  }) async =>
      mistakes;
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

Topic get _modalPastForms =>
    kTopics.firstWhere((t) => t.id == TopicId.modalPastForms);

/// Pumps the detail screen for [spot] under [topic], with [mistakes] as its
/// recent mistakes — for the recap-sentence tests, which care about the
/// text, not the access state.
Future<void> _pumpSpot(
  WidgetTester tester, {
  required Topic topic,
  required WeakSpot spot,
  List<ErrorEntry> mistakes = const [],
}) async {
  await tester.pumpWidget(
    MaterialApp(
      // The recent-mistake cards read SemanticColors off the theme.
      theme: buildAppTheme(Brightness.light),
      home: WeakSpotDetailScreen(
        topic: topic,
        spot: spot,
        claudeService: ClaudeService(),
        storageService: _FakeStorageService(mistakes: mistakes),
        analyticsService: AnalyticsService(),
        subscriptionService: _FakeSubscriptionService(hasAccess: true),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('recap sentence and rule line', () {
    // Shaped exactly like a Daily Test record: the topic id stands in as
    // the error type, and an unpredicted wrong answer has no explanation
    // and no rule — so the screen falls back to its template sentence.
    WeakSpot dailyTestSpot() => WeakSpot(
          topicId: 'modalPastForms',
          errorType: 'modalPastForms',
          frequency: 2,
          lastSeen: DateTime.now(),
        );
    final dailyTestMistake = ErrorEntry(
      topicId: 'modalPastForms',
      errorType: 'modalPastForms',
      timestamp: DateTime(2026, 9, 24),
      prompt: 'Tom said he ___ call me the next day.',
      userAnswer: 'shall',
      correctedAnswer: 'would',
      source: ErrorSource.dailyTest,
    );

    testWidgets(
        'a Daily Test weak spot names its topic once in the sentence and '
        'drops the repeated rule line', (tester) async {
      await _pumpSpot(
        tester,
        topic: _modalPastForms,
        spot: dailyTestSpot(),
        mistakes: [dailyTestMistake],
      );

      expect(
        find.text("You've had trouble with Modal Past Forms. Practicing it "
            'again will help reinforce it.'),
        findsOneWidget,
      );
      expect(find.textContaining('Modal Past Forms in Modal Past Forms'),
          findsNothing);
      // Only the page title is left as a standalone "Modal Past Forms":
      // the rule line under the frequency pill would have been a second.
      expect(find.text('Modal Past Forms'), findsOneWidget);
    });

    testWidgets(
        'a weak spot whose rule differs from its topic keeps both in the '
        'sentence and keeps the rule line', (tester) async {
      await _pumpSpot(
        tester,
        topic: _modalPastForms,
        spot: WeakSpot(
          topicId: 'modalPastForms',
          errorType: 'reported_speech_backshift',
          frequency: 2,
          lastSeen: DateTime.now(),
        ),
      );

      expect(
        find.text("You've had trouble with Reported Speech Backshift in "
            'Modal Past Forms. Practicing it again will help reinforce it.'),
        findsOneWidget,
      );
      expect(find.text('Reported Speech Backshift'), findsOneWidget);
    });

    testWidgets(
        'a recorded explanation still replaces the template, whatever the '
        'error type', (tester) async {
      const comment = "After 'said', 'will' moves back to 'would'.";
      await _pumpSpot(
        tester,
        topic: _modalPastForms,
        spot: dailyTestSpot(),
        mistakes: [
          ErrorEntry(
            topicId: 'modalPastForms',
            errorType: 'modalPastForms',
            timestamp: DateTime(2026, 9, 24),
            userAnswer: 'will',
            correctedAnswer: 'would',
            explanation: comment,
            source: ErrorSource.dailyTest,
          ),
        ],
      );

      expect(find.text(comment), findsWidgets);
      expect(find.textContaining("You've had trouble"), findsNothing);
    });
  });

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
