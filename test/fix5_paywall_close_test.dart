import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'support/fix3_render.dart';
import 'support/paywall_close.dart';

/// Fix round 5, item 4 (SPEC V13 "Closing (v13)", §1.29): the paywall as
/// each entry point opens it — a page route (Home's topic cards and weak
/// spot, the paywall after the first climb, Review's used ticket, the weak
/// spot's locked row, the practice launch, the practice results) or V13r's
/// own route from the rest scene's Wake — stays after an edge swipe, a drag
/// down and a system back, in iOS's behaviour; the X closes it (V13b first,
/// with the store's offer). The real flows are tested where each entry
/// point lives (home_screen, home_day0_paywall, review_screen,
/// practice_launch_free_tier, results_screen); this file renders the
/// paywall after the attempts (`FIX5_CAPTURE=1`:
/// `build/fix5-captures/(dark/)V13-after-swipe-<source>.png`).
void main() {
  const entries = [
    (AnalyticsService.paywallSourceHome, null, false),
    (AnalyticsService.paywallSourceDay0AfterClimb, null, false),
    (AnalyticsService.paywallSourceReviewQuota, null, false),
    (AnalyticsService.paywallSourceWeakSpotQuota, 'Missing Article', false),
    (AnalyticsService.paywallSourcePracticeLaunch, 'Articles', false),
    (AnalyticsService.paywallSourcePracticeResult, null, false),
    (AnalyticsService.paywallSourceRestScene, null, true),
  ];

  for (final brightness in Brightness.values) {
    for (final (source, context, rest) in entries) {
      testWidgets(
          '$source (${brightness.name}): stays after the gestures; X '
          '→ V13b → closed', (tester) async {
        PremiumScreen.resetExitReminder();
        Widget paywall() => PremiumScreen(
              storageService: _Storage(),
              analyticsService: AnalyticsService(),
              analyticsSource: source,
              subscriptionService: _Subscriptions(),
              sourceContext: context,
              rest: rest
                  ? const PaywallRest(
                      theme: ClimbThemes.emberPeak,
                      weakSpot: 'Missing Article',
                      hero: Avatar.fox,
                      name: 'Ada')
                  : null,
            );
        await pumpFix3(
            tester,
            Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    key: const ValueKey('open'),
                    onPressed: () => Navigator.of(context).push<Object?>(rest
                        // V13r's own route, as Home pushes it.
                        ? PageRouteBuilder<Object?>(
                            pageBuilder: (_, __, ___) => paywall(),
                            transitionsBuilder: (_, a, __, child) =>
                                SlideTransition(
                                    position: Tween(
                                            begin: const Offset(0, 1),
                                            end: Offset.zero)
                                        .animate(a),
                                    child: child),
                          )
                        : MaterialPageRoute<Object?>(
                            builder: (_) => paywall())),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
            brightness: brightness);
        await tester.tap(find.byKey(const ValueKey('open')));
        await tester.pumpAndSettle();
        await expectPaywallHolds(tester);
        await _capture(tester, 'V13-after-swipe-$source',
            dark: brightness == Brightness.dark);
        await closeWithX(tester, reminder: true);
        expect(find.byKey(const ValueKey('open')), findsOneWidget);
      }, variant: iOSOnly);
    }
  }
}

/// The paywall's route as it is on screen (its own repaint boundary), with
/// `FIX5_CAPTURE=1`.
Future<void> _capture(WidgetTester tester, String name,
    {required bool dark}) async {
  // The route's own boundary holds the whole page.
  await fix5Capture(tester, name, dark: dark);
}

class _Storage extends StorageService {
  @override
  Future<UserProfile?> getUserProfile() async => const UserProfile(
      name: 'Ada', learningGoal: LearningGoal.work, avatar: Avatar.fox);
}

class _Subscriptions extends SubscriptionService {
  @override
  Future<Offering?> getOfferings() async => buildDebugFixtureOffering();

  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: TrialEligibility.eligible};
}
