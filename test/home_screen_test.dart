import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/screens/topic_practice_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

void main() {
  Future<void> pumpHome(
    WidgetTester tester, {
    Avatar? avatar,
    VoidCallback? onAvatarTap,
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
          analyticsService: AnalyticsService(),
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

  testWidgets('shows the Topic Practice card plus the Early Access banner',
      (tester) async {
    await pumpHome(tester);
    expect(find.text('Topic Practice'), findsOneWidget);
    expect(find.text('Early Access'), findsOneWidget);
    // Streak Mode and Voice Practice were removed from Home entirely (App
    // Store completeness risk + redundant with the Premium screen, which
    // already lists both as coming-soon premium features) — see
    // docs/roadmap.md.
    expect(find.text('Streak Mode'), findsNothing);
    expect(find.text('Voice Practice'), findsNothing);
  });

  testWidgets('Topic Practice is a single full-width card, not a grid tile',
      (tester) async {
    await pumpHome(tester);
    expect(find.byType(GridView), findsNothing);

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final hPad = (width * 0.045).clamp(16.0, 28.0);
    final cardRect = tester.getRect(
      find.ancestor(of: find.text('Topic Practice'), matching: find.byType(Card)),
    );
    expect(cardRect.left, closeTo(hPad, 1));
    expect(cardRect.right, closeTo(width - hPad, 1));
  });

  testWidgets(
      'Early Access sits below Topic Practice, not beside it as another '
      'card', (tester) async {
    await pumpHome(tester);

    final topicBottom = tester.getBottomLeft(find.text('Topic Practice')).dy;
    final bannerTop = tester.getTopLeft(find.text('Early Access')).dy;
    expect(bannerTop, greaterThan(topicBottom));
  });

  testWidgets('Topic Practice opens the existing MVP loop', (tester) async {
    await pumpHome(tester);
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
