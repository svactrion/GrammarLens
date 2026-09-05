import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/daily_test_question.dart';
import 'package:grammar_lens/models/daily_test_set.dart';
import 'package:grammar_lens/models/error_entry.dart';
import 'package:grammar_lens/models/practice_item.dart';
import 'package:grammar_lens/models/review_sort_order.dart';
import 'package:grammar_lens/screens/daily_test_result_screen.dart';
import 'package:grammar_lens/screens/daily_test_screen.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/screens/weak_spot_detail_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

/// Records `modeSelected` calls instead of the real (best-effort, silently
/// swallowed) Firebase call, so a test can assert which Home entry point a
/// tap actually reached — needed for Daily Test specifically, since unlike
/// Topic Practice/Premium, DailyTestScreen's real initial load has
/// nothing to succeed against in this test environment, landing on its own
/// in-screen error state (see daily_test_screen_test.dart) rather than
/// anything this file's simpler `tester.pump()`-only assertions could
/// reliably match against.
class _RecordingAnalyticsService extends AnalyticsService {
  final List<String> modesSelected = [];

  @override
  Future<void> modeSelected(String mode) async {
    modesSelected.add(mode);
  }
}

/// Controls [hasFullAccess] and lets a test fire a live update through
/// whatever listener Home actually registered — the real SubscriptionService
/// would need an actual RevenueCat project to ever change entitlement state,
/// which this stands in for deterministically (see premium_screen_test.dart
/// for the same pattern applied to PremiumScreen).
class _FakeSubscriptionService extends SubscriptionService {
  bool hasAccess;
  AccessListener? _listener;

  _FakeSubscriptionService({this.hasAccess = false});

  @override
  Future<bool> get hasFullAccess async => hasAccess;

  @override
  void addAccessListener(AccessListener listener) {
    _listener = listener;
  }

  @override
  void removeAccessListener(AccessListener listener) {
    if (identical(_listener, listener)) _listener = null;
  }

  /// Simulates RevenueCat reporting a change — a trial starting, expiring,
  /// or a restore completing — without needing a real project connected.
  void emitAccessChange(bool value) {
    hasAccess = value;
    _listener?.call(value);
  }
}

/// Real StorageService methods throw in this test environment (no
/// platform channel) — fine for tests that don't care what Home's "today"
/// card or weak-spot section show (they fail open to "nothing yet", same
/// as every other best-effort read in this app), but the tests that assert
/// on *specific* Daily Test/weak-spot content need deterministic data,
/// which this fake supplies.
class _FakeStorageService extends StorageService {
  DailyTestSet? todaysDailyTest;
  List<WeakSpot> weakSpots = const [];

  @override
  Future<DailyTestSet?> getDailyTestSetForToday() async => todaysDailyTest;

  @override
  Future<List<WeakSpot>> getWeakSpots({
    int limit = 10,
    ReviewSortOrder sortOrder = ReviewSortOrder.recent,
  }) async =>
      weakSpots;
}

DailyTestSet _completedDailyTestSet({required int correct, required int total}) {
  final questions = List.generate(
    total,
    (i) => DailyTestQuestion(
      item: PracticeItem(
        id: 'q$i',
        type: PracticeItemType.fillInBlank,
        instruction: 'Question $i',
      ),
      topicId: 'tenseSelection',
      correctAnswer: 'right$i',
      commonWrongAnswers: const [],
    ),
  );
  final answers = {
    for (var i = 0; i < total; i++) 'q$i': i < correct ? 'right$i' : 'wrong',
  };
  return DailyTestSet(
    day: '2026-01-01',
    questions: questions,
    completedAt: DateTime(2026, 1, 1),
    answers: answers,
  );
}

WeakSpot _weakSpot({String topicId = 'articles', int frequency = 5}) =>
    WeakSpot(
      topicId: topicId,
      errorType: 'missing_article',
      frequency: frequency,
      lastSeen: DateTime.now(),
      latestExplanation: 'You left out "the" before a specific noun.',
    );

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    Avatar? avatar,
    VoidCallback? onAvatarTap,
    AnalyticsService? analyticsService,
    SubscriptionService? subscriptionService,
    StorageService? storageService,
  }) async {
    // A phone-realistic size so every card is actually reachable by taps.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        // DailyTestResultScreen (reachable from the Today card once
        // completed) reads SemanticColors off the theme — the app's real
        // theme registers it, MaterialApp's default doesn't (same fix
        // first_launch_flow_test.dart already needed for the same
        // screen).
        theme: buildAppTheme(Brightness.light),
        home: HomeScreen(
          userName: 'Ada',
          avatar: avatar,
          claudeService: ClaudeService(),
          storageService: storageService ?? StorageService(),
          analyticsService: analyticsService ?? AnalyticsService(),
          subscriptionService: subscriptionService ?? _FakeSubscriptionService(),
          onAvatarTap: onAvatarTap,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('greets the user by their onboarding name', (tester) async {
    await pumpHome(tester);
    expect(find.text('Welcome back, Ada'), findsOneWidget);
  });

  testWidgets('shows a placeholder avatar when none has been picked',
      (tester) async {
    await pumpHome(tester);
    final circle = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(circle.avatar, isNull);
  });

  testWidgets('shows the picked avatar next to the greeting', (tester) async {
    await pumpHome(tester, avatar: Avatar.penguin);
    final circle = tester.widget<AvatarTile>(find.byType(AvatarTile));
    expect(circle.avatar, Avatar.penguin);
  });

  testWidgets(
      'avatar sits trailing at the far right, after the greeting text, not '
      'leading before it', (tester) async {
    await pumpHome(tester);

    final greetingLeft = tester.getTopLeft(find.text('Welcome back, Ada')).dx;
    final avatarRect = tester.getRect(find.byType(AvatarTile));
    final screenWidth = tester.view.physicalSize.width /
        tester.view.devicePixelRatio;

    // To the right of the greeting text, not before it.
    expect(avatarRect.left, greaterThan(greetingLeft));
    // Flush against the trailing screen edge (within the row's own
    // padding), not floating in the middle.
    expect(avatarRect.right, greaterThan(screenWidth - 60));
  });

  testWidgets('tapping the avatar calls onAvatarTap', (tester) async {
    var tapped = false;
    await pumpHome(tester, onAvatarTap: () => tapped = true);

    await tester.tap(find.byType(AvatarTile));
    await tester.pump();

    expect(tapped, isTrue);
  });

  group('Today (Daily Test state, PRD v2 §13.5 item 2)', () {
    testWidgets(
        'not yet done: shows an invitation, tapping opens Daily Test',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());

      expect(find.text('Daily Test'), findsOneWidget);
      expect(
        find.textContaining("ready — free, always"),
        findsOneWidget,
      );

      await tester.tap(find.text('Daily Test'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTestScreen), findsOneWidget);
    });

    testWidgets(
        'done: shows the score and "new test tomorrow", not the '
        'invitation', (tester) async {
      final storage = _FakeStorageService()
        ..todaysDailyTest = _completedDailyTestSet(correct: 3, total: 5);
      await pumpHome(tester, storageService: storage);

      expect(find.textContaining('3/5 correct'), findsOneWidget);
      expect(find.textContaining('New test tomorrow'), findsOneWidget);
      expect(find.text('Daily Test'), findsNothing);
    });

    testWidgets('done: tapping it views the result again, not a new test',
        (tester) async {
      final storage = _FakeStorageService()
        ..todaysDailyTest = _completedDailyTestSet(correct: 2, total: 5);
      await pumpHome(tester, storageService: storage);

      await tester.tap(find.textContaining('2/5 correct'));
      await tester.pumpAndSettle();

      expect(find.byType(DailyTestResultScreen), findsOneWidget);
      expect(find.byType(DailyTestScreen), findsNothing);
      // The real score, reconstructed from the persisted answers, not
      // recomputed from nothing.
      expect(find.textContaining('2/5 correct'), findsOneWidget);
    });
  });

  testWidgets('shows the Topic Practice card', (tester) async {
    await pumpHome(tester);
    expect(find.text('Topic Practice'), findsOneWidget);
    // Streak Mode and Voice Practice were removed from Home entirely (App
    // Store completeness risk at the time; both were also later dropped
    // from the Premium screen itself — PRD v2 §13.4, nothing unbuilt gets
    // sold) — see docs/roadmap.md.
    expect(find.text('Streak Mode'), findsNothing);
    expect(find.text('Voice Practice'), findsNothing);
  });

  testWidgets(
      'the Today card and Topic Practice card are both full-width, not '
      'grid tiles', (tester) async {
    await pumpHome(tester);
    expect(find.byType(GridView), findsNothing);

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    for (final title in ['Daily Test', 'Topic Practice']) {
      final cardRect = tester.getRect(
        find.ancestor(of: find.text(title), matching: find.byType(Card)),
      );
      expect(cardRect.left, closeTo(hPad, 1));
      expect(cardRect.right, closeTo(width - hPad, 1));
    }
  });

  testWidgets(
      'stacks in order: Today, then Topic Practice, then the Premium row',
      (tester) async {
    await pumpHome(tester);

    final todayTop = tester.getTopLeft(find.text('Daily Test')).dy;
    final topicTop = tester.getTopLeft(find.text('Topic Practice')).dy;
    final premiumTop = tester.getTopLeft(find.text('Premium')).dy;

    expect(topicTop, greaterThan(todayTop));
    expect(premiumTop, greaterThan(topicTop));
  });

  testWidgets(
      'Daily Test is wired to its own entry point, distinct from Topic '
      'Practice/Premium', (tester) async {
    final analyticsService = _RecordingAnalyticsService();
    await pumpHome(tester, analyticsService: analyticsService);

    await tester.tap(find.text('Daily Test'));
    await tester.pump();

    expect(analyticsService.modesSelected, [AnalyticsService.modeDailyTest]);
  });

  testWidgets(
      'Topic Practice opens the existing MVP loop when the entitlement is '
      'active', (tester) async {
    await pumpHome(
      tester,
      subscriptionService: _FakeSubscriptionService(hasAccess: true),
    );
    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsOneWidget);
  });

  testWidgets(
      'Topic Practice shows locked and opens the Premium screen instead, '
      'with no entitlement active (PRD v2 §12.2/§12.3)', (tester) async {
    await pumpHome(tester); // default fake: hasAccess: false
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();

    expect(find.byType(TopicPracticeScreen), findsNothing);
    expect(find.byType(PremiumScreen), findsOneWidget);
  });

  testWidgets(
      'reacts live to an entitlement change — a trial starting unlocks the '
      'card without rebuilding the screen', (tester) async {
    final subscriptionService = _FakeSubscriptionService();
    await pumpHome(tester, subscriptionService: subscriptionService);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    subscriptionService.emitAccessChange(true);
    await tester.pump();

    expect(find.byIcon(Icons.lock_rounded), findsNothing);

    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();
    expect(find.byType(TopicPracticeScreen), findsOneWidget);
  });

  group('weak spots (PRD v2 §13.5 item 4)', () {
    testWidgets('no section at all when there are none — no empty state',
        (tester) async {
      await pumpHome(tester, storageService: _FakeStorageService());
      expect(find.text('Your weak spots'), findsNothing);
    });

    testWidgets('shows up to the most frequent, tappable through when '
        'unlocked', (tester) async {
      final storage = _FakeStorageService()..weakSpots = [_weakSpot()];
      await pumpHome(
        tester,
        storageService: storage,
        subscriptionService: _FakeSubscriptionService(hasAccess: true),
      );

      expect(find.text('Your weak spots'), findsOneWidget);
      expect(
        find.text('You left out "the" before a specific noun.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.lock_rounded), findsNothing);

      await tester.tap(
        find.text('You left out "the" before a specific noun.'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeakSpotDetailScreen), findsOneWidget);
    });

    testWidgets(
        'shows locked when the entitlement is not active, and tapping '
        'opens the Premium screen naming that weak spot', (tester) async {
      final storage = _FakeStorageService()..weakSpots = [_weakSpot()];
      await pumpHome(tester, storageService: storage); // hasAccess: false

      expect(find.byIcon(Icons.lock_rounded), findsWidgets);

      await tester.tap(
        find.text('You left out "the" before a specific noun.'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WeakSpotDetailScreen), findsNothing);
      final premium = tester.widget<PremiumScreen>(
        find.byType(PremiumScreen),
      );
      expect(premium.sourceContext, 'Missing Article');
    });
  });

  group('Premium row (PRD v2 §13.5 item 5)', () {
    testWidgets('shown for a free user, opens the Premium screen',
        (tester) async {
      await pumpHome(tester);
      await tester.tap(find.text('Premium'));
      await tester.pumpAndSettle();
      expect(find.byType(PremiumScreen), findsOneWidget);
    });

    testWidgets('not shown once the entitlement is active — no repeated '
        'upsell to someone already subscribed', (tester) async {
      await pumpHome(
        tester,
        subscriptionService: _FakeSubscriptionService(hasAccess: true),
      );
      expect(find.text('Premium'), findsNothing);
    });

    testWidgets('states what it offers, not just the word "Premium"',
        (tester) async {
      await pumpHome(tester);
      expect(
        find.text('Unlock targeted practice on your weak spots'),
        findsOneWidget,
      );
    });

    testWidgets(
        'text color is the scaffold foreground, not the low-contrast '
        'onSurfaceVariant meant for a surface background — this row sits '
        'directly on the orange scaffold in light mode', (tester) async {
      await pumpHome(tester);

      final theme = Theme.of(tester.element(find.text('Premium')));
      final expectedFg =
          theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;

      final style = tester.widget<Text>(find.text('Premium')).style;
      expect(style?.color, expectedFg);
      expect(style?.color, isNot(theme.colorScheme.onSurfaceVariant));
    });
  });
}
