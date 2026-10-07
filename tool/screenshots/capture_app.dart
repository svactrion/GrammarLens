// App Store screenshots (1.2.0): the real app, run in the simulator by
// `flutter drive` with `capture_driver.dart` steering it.
// Not part of the app: nothing in lib/ imports tool/
// (`test/tool_import_guard_test.dart`).
//
// Before the app starts, on a fresh install, it seeds the fictional
// learner of `seed.dart` ("Sam", the Fox, Glacier Peak; see there).
// Firebase and RevenueCat are not started, and every analytics event is
// dropped: a capture run sends nothing to the production project and
// makes no purchase call. The paywall shows the debug price fixture
// (`buildDebugFixtureOffering`: $5.99 a month with 3 free days, $49.99 a
// year with 1 free week, both eligible), so its trial line shows.
//
// Defines:
//   CAPTURE_WELCOME=true  nothing is seeded: the app opens on Welcome, and
//                         the first climb's month is still Glacier Peak
//                         (the same theme seam the seed uses).
//   CAPTURE_PREMIUM=true  Sam is premium (the debug entitlement override).
//   CAPTURE_PRACTICE_USED=true  Sam (free) has used today's free practice,
//                         so Review shows its Premium offer.
// All are debug-build only, as is everything this file switches on.
//
// Run through tool/screenshots/capture.sh, not on its own.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:grammar_lens/app.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/utils/app_orientation.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

import 'seed.dart';

/// Drops every event.
class _NoAnalytics implements AnalyticsSink {
  const _NoAnalytics();
  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {}
  @override
  Future<void> setUserProperty(String name, String? value) async {}
}

/// `--dart-define=CAPTURE_WELCOME=true`: no seeding, so the app opens on
/// Welcome as a fresh install does.
const _welcomeOnly = bool.fromEnvironment('CAPTURE_WELCOME');

/// `--dart-define=CAPTURE_PREMIUM=true`: Sam has Premium.
const _premium = bool.fromEnvironment('CAPTURE_PREMIUM');

/// `--dart-define=CAPTURE_PRACTICE_USED=true`: today's free practice used.
const _practiceUsed = bool.fromEnvironment('CAPTURE_PRACTICE_USED');

Future<void> main() async {
  enableFlutterDriverExtension(handler: (request) async {
    if (request == 'answers') return jsonEncode(screenshotTodayAnswers);
    if (request == 'mode') {
      return _welcomeOnly ? 'welcome' : (_practiceUsed ? 'practice' : 'full');
    }
    if (request == 'access') return _premium ? 'premium' : 'free';
    // The driver switches between flutter_driver's text-entry emulation and
    // the real iOS keyboard (frame 06): a field opens its text input
    // connection, to whichever is active, only when it gains focus.
    if (request == 'unfocus') {
      FocusManager.instance.primaryFocus?.unfocus();
      return 'ok';
    }
    if (request == 'release_look') {
      // From here on the screens show what a release build shows (no
      // Developer section on Profile). The screens are rebuilt, not
      // reloaded. The debug panel is not reachable after this, and the
      // debug overrides end with it: Premium (CAPTURE_PREMIUM) and the
      // paywall's price fixture. The stored Glacier theme stays.
      DebugTools.enabledForTesting = false;
      await WidgetsBinding.instance.reassembleApplication();
      return 'ok';
    }
    return '';
  });
  WidgetsFlutterBinding.ensureInitialized();
  await lockAppOrientation();
  final storage = StorageService();
  if (_welcomeOnly) {
    // ignore: invalid_use_of_visible_for_testing_member
    StorageService.themeForNewMonthForTesting = (_, __) => screenshotTheme;
  } else {
    await seedScreenshotData(storage, now: DateTime.now(), premium: _premium);
    if (_practiceUsed) await storage.recordFreePracticeStarted();
  }
  // The paywall's prices: the debug fixture (no store connection here).
  SubscriptionService().setDebugFixtureOffering(enabled: true);
  runApp(LaunchGate(
    initialize: () async {},
    app: (_) => GrammarLensApp(
      // Today at 9:41, the status bar's time: Home greets "Good morning"
      // whatever the hour of the run. The date is today's, so the data
      // seeded for today is the data Home shows.
      clock: () {
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, 9, 41);
      },
      storageService: storage,
      analyticsService: AnalyticsService(sink: const _NoAnalytics()),
    ),
  ));
}
