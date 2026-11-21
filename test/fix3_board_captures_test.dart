import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/reminder_settings.dart';
import 'package:grammar_lens/screens/notification_settings_screen.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/services/native_bridge.dart';
import 'package:grammar_lens/services/reminder_controller.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/widgets/brand_wordmark.dart';
import 'package:grammar_lens/widgets/buddy_picker.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

import 'support/fake_native_bridge.dart';
import 'support/fix3_render.dart';

/// Fix round 3, §4: renders for the comparison table that no other test
/// writes, in light and dark (`FIX3_CAPTURE=1`): V01's two frames, V05 with
/// each goal selected, N03. Without the variable they still check that the
/// screens build without an exception.
class _Storage extends StorageService {
  ReminderSettings settings = const ReminderSettings();

  @override
  Future<ReminderSettings> getReminderSettings() async => settings;

  @override
  Future<void> setReminderSettings(ReminderSettings settings) async =>
      this.settings = settings;
}

class _Free extends SubscriptionService {
  @override
  Future<bool> get hasFullAccess async => false;
}

void main() {
  for (final b in Brightness.values) {
    final dark = b == Brightness.dark;
    final mode = dark ? 'dark' : 'light';

    testWidgets('V01 ($mode): the icon assembling, then the lens scanning',
        (tester) async {
      // The splash follows the phone's setting, like the launch screen.
      tester.platformDispatcher.platformBrightnessTestValue = b;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpFix3(
        tester,
        LaunchSplash(firstLaunch: Future.value(true)),
        size: const Size(402, 874),
        top: 62,
        brightness: b,
        settle: false,
      );
      await tester.pump(const Duration(milliseconds: 500));
      await fix3Capture(tester, 'V01-frame1-icon', dark: dark);
      await tester.pump(const Duration(milliseconds: 1100)); // 1.6 s
      expect(find.byType(BrandWordmark), findsOneWidget);
      await fix3Capture(tester, 'V01-frame2-scan', dark: dark);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('V05 ($mode): each goal selected', (tester) async {
      await pumpFix3(tester, OnboardingScreen(onComplete: (_) {}),
          size: const Size(390, 844), brightness: b);
      await tester.tap(find.byKey(BuddyPicker.confirmKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
      await tester.pump();
      await tester.tap(find.byKey(OnboardingScreen.continueKey));
      await tester.pumpAndSettle();
      for (final goal in LearningGoal.values) {
        await tester.tap(find.byKey(OnboardingScreen.goalKey(goal)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await fix3Capture(tester, 'V05-${goal.name}', dark: dark);
      }
    });

    testWidgets('N03 ($mode): the notification settings', (tester) async {
      final controller = ReminderController(
          storage: _Storage(),
          bridge: FakeNativeBridge()
            ..permission = NotificationPermission.authorized);
      addTearDown(controller.dispose);
      await pumpFix3(
        tester,
        NotificationSettingsScreen(
          controller: controller,
          hero: Avatar.fox,
          subscriptionService: _Free(),
        ),
        size: const Size(390, 844),
        brightness: b,
      );
      expect(tester.takeException(), isNull);
      await fix3Capture(tester, 'N03', dark: dark);
    });
  }
}
