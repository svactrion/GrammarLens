// Additional screens Batch 12: the 1.2.0 paywall with the real font, light
// and dark: annual selected, monthly selected, the comparison open, and the
// not-eligible wording; Batch 13 adds Large text at 390 and 375 × 667 (the
// footer's rhythm). Prices are the live App Store prices with the
// configured trials (annual 1 week, monthly 3 days); nothing from the store.
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_paywall \
//     flutter test tool/design_measure/v120/paywall_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/models/user_profile.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

class _Storage extends StorageService {
  @override
  Future<UserProfile?> getUserProfile() async => UserProfile(
      name: 'Ada', learningGoal: LearningGoal.work, avatar: Avatar.values[13]);
}

class _Service extends SubscriptionService {
  final TrialEligibility eligibility;
  _Service(this.eligibility);

  @override
  Future<Offering?> getOfferings() async => _offering();

  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: eligibility};
}

Offering _offering() {
  const context = PresentedOfferingContext('default', null, null);
  const monthly = Package(
      '\$rc_monthly',
      PackageType.monthly,
      StoreProduct(
          'grammarlens_premium_monthly', '', 'Monthly', 5.99, '\$5.99', 'USD',
          introductoryPrice:
              IntroductoryPrice(0, '\$0.00', 'P3D', 1, PeriodUnit.day, 3),
          subscriptionPeriod: 'P1M'),
      context);
  const annual = Package(
      '\$rc_annual',
      PackageType.annual,
      StoreProduct(
          'grammarlens_premium_annual', '', 'Annual', 49.99, '\$49.99', 'USD',
          introductoryPrice:
              IntroductoryPrice(0, '\$0.00', 'P1W', 1, PeriodUnit.week, 1),
          subscriptionPeriod: 'P1Y',
          pricePerMonth: 4.16,
          pricePerMonthString: '\$4.16'),
      context);
  return const Offering('default', '', {}, [monthly, annual],
      monthly: monthly, annual: annual);
}

typedef _Case = ({
  String name,
  Size size,
  bool monthly,
  bool compare,
  TrialEligibility eligibility,
  double scrollTo,
  AppTextSize text,
});

const List<_Case> _cases = [
  (
    name: '390_annual_large',
    size: Size(390, 844),
    monthly: false,
    compare: false,
    eligibility: TrialEligibility.eligible,
    scrollTo: 0,
    text: AppTextSize.large
  ),
  (
    name: '375x667_annual_large',
    size: Size(375, 667),
    monthly: false,
    compare: false,
    eligibility: TrialEligibility.eligible,
    scrollTo: 0,
    text: AppTextSize.large
  ),
  (
    name: '390_annual',
    size: Size(390, 844),
    monthly: false,
    compare: false,
    eligibility: TrialEligibility.eligible,
    scrollTo: 0,
    text: AppTextSize.medium,
  ),
  (
    name: '390_annual_cards',
    size: Size(390, 844),
    monthly: false,
    compare: false,
    eligibility: TrialEligibility.eligible,
    scrollTo: 400,
    text: AppTextSize.medium,
  ),
  (
    name: '390_monthly_cards',
    size: Size(390, 844),
    monthly: true,
    compare: false,
    eligibility: TrialEligibility.eligible,
    scrollTo: 400,
    text: AppTextSize.medium,
  ),
  (
    name: '390_compare_open',
    size: Size(390, 844),
    monthly: false,
    compare: true,
    eligibility: TrialEligibility.eligible,
    scrollTo: 330,
    text: AppTextSize.medium,
  ),
  (
    name: '390_not_eligible_cards',
    size: Size(390, 844),
    monthly: false,
    compare: false,
    eligibility: TrialEligibility.ineligible,
    scrollTo: 400,
    text: AppTextSize.medium,
  ),
  (
    name: '375x667_annual',
    size: Size(375, 667),
    monthly: false,
    compare: false,
    eligibility: TrialEligibility.eligible,
    scrollTo: 0,
    text: AppTextSize.medium,
  ),
];

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  for (final c in _cases) {
    for (final b in Brightness.values) {
      final file = 'paywall_${c.name}_${b.name}';
      testWidgets(file, (tester) async {
        tester.view.physicalSize = c.size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(
            top: (c.size.height < 700 ? 20 : 47) * 3,
            bottom: (c.size.height < 700 ? 0 : 34) * 3);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(b, textSize: c.text),
            home: PremiumScreen(
              storageService: _Storage(),
              analyticsService: AnalyticsService(),
              analyticsSource: AnalyticsService.paywallSourceHome,
              subscriptionService: _Service(c.eligibility),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.runAsync(() => Future.wait([
              for (final a in Avatar.values)
                precacheImage(AssetImage(a.assetPath), key.currentContext!),
            ]));
        await tester.pumpAndSettle();
        if (c.compare) {
          await tester
              .ensureVisible(find.byKey(PremiumScreen.compareToggleKey));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(PremiumScreen.compareToggleKey));
          await tester.pumpAndSettle();
        }
        if (c.monthly) {
          await tester.ensureVisible(find.text('Monthly'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Monthly'));
          await tester.pumpAndSettle();
        }
        final scroll =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        scroll.position.jumpTo(
            c.scrollTo.clamp(0, scroll.position.maxScrollExtent).toDouble());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final img = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$file.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
