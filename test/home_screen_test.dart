import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/paywall_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

/// Records `modeSelected` calls instead of the real (best-effort, silently
/// swallowed) Firebase call, so a test can assert which Home entry point a
/// tap actually reached — needed for Daily Test specifically, since unlike
/// Topic Practice/Early Access, DailyTestScreen's real initial load has
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
/// which this stands in for deterministically (see paywall_screen_test.dart
/// for the same pattern applied to PaywallScreen).
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

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    Avatar? avatar,
    VoidCallback? onAvatarTap,
    AnalyticsService? analyticsService,
    SubscriptionService? subscriptionService,
  }) async {
    // A phone-realistic size so every card is actually reachable by taps.
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          userName: 'Ada',
          avatar: avatar,
          claudeService: ClaudeService(),
          storageService: StorageService(),
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

  testWidgets(
      'shows the Daily Test and Topic Practice cards plus the Early Access '
      'banner', (tester) async {
    await pumpHome(tester);
    expect(find.text('Daily Test'), findsOneWidget);
    expect(find.text('Topic Practice'), findsOneWidget);
    expect(find.text('Early Access'), findsOneWidget);
    // Streak Mode and Voice Practice were removed from Home entirely (App
    // Store completeness risk + redundant with the Premium screen, which
    // already lists both as coming-soon premium features) — see
    // docs/roadmap.md.
    expect(find.text('Streak Mode'), findsNothing);
    expect(find.text('Voice Practice'), findsNothing);
  });

  testWidgets(
      'Daily Test and Topic Practice are both full-width cards, not grid '
      'tiles', (tester) async {
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
      'cards stack in order: Daily Test, then Topic Practice, then Early '
      'Access', (tester) async {
    await pumpHome(tester);

    final dailyTestTop = tester.getTopLeft(find.text('Daily Test')).dy;
    final topicTop = tester.getTopLeft(find.text('Topic Practice')).dy;
    final bannerTop = tester.getTopLeft(find.text('Early Access')).dy;

    expect(topicTop, greaterThan(dailyTestTop));
    expect(bannerTop, greaterThan(topicTop));
  });

  testWidgets(
      'Daily Test is wired to its own entry point, distinct from Topic '
      'Practice/Early Access', (tester) async {
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
      'Topic Practice shows locked and opens the paywall instead, with no '
      'entitlement active (PRD v2 §12.2/§12.3)', (tester) async {
    await pumpHome(tester); // default fake: hasAccess: false
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

    await tester.tap(find.text('Topic Practice'));
    await tester.pumpAndSettle();

    expect(find.byType(TopicPracticeScreen), findsNothing);
    expect(find.byType(PaywallScreen), findsOneWidget);
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

  testWidgets('Early Access opens the premium/early-access screen',
      (tester) async {
    await pumpHome(tester);
    await tester.tap(find.text('Early Access'));
    await tester.pumpAndSettle();
    expect(find.byType(PremiumScreen), findsOneWidget);
  });
}
