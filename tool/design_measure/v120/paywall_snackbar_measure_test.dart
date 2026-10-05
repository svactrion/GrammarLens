// 1.2.0 final pass (4b): where a message lands on the paywall, against its
// fixed footer (the purchase button, the renewal terms, the links). Measuring
// only; prints the rectangles and writes `paywall_snackbar.txt`.
//
//   flutter test tool/design_measure/v120/paywall_snackbar_measure_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
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
import 'package:grammar_lens/utils/app_messenger.dart';
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

void main() {
  final out = StringBuffer();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('${outDir()}/paywall_snackbar.txt')
      .writeAsStringSync(out.toString()));
  for (final size in const [Size(390, 844), Size(375, 667), Size(320, 568)]) {
    for (final text in AppTextSize.values) {
      testWidgets('${size.width.toInt()}x${size.height.toInt()} ${text.name}',
          (tester) async {
        final safe = size.height >= 812 ? 34.0 : 0.0;
        final pad = FakeViewPadding(top: (safe > 0 ? 47 : 20) * 3, bottom: safe * 3);
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = pad;
        tester.view.viewPadding = pad;
        addTearDown(tester.view.reset);
        addTearDown(AppMessenger.clear);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light, textSize: text),
          scaffoldMessengerKey: AppMessenger.key,
          home: PremiumScreen(
            storageService: _Storage(),
            analyticsService: AnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _Service(TrialEligibility.eligible),
          ),
        ));
        await tester.pumpAndSettle();
        AppMessenger.show('Could not open Terms of Use.');
        await tester.pumpAndSettle();
        final snack = tester.getRect(find
            .descendant(
                of: find.byType(SnackBar), matching: find.byType(Material))
            .first);
        final cta = tester.getRect(find.byKey(PremiumScreen.ctaKey));
        final footer = tester.getRect(find.byKey(const Key('premiumFooter')));
        out.writeln('${size.width.toInt()}x${size.height.toInt()} '
            '${text.name}: message ${snack.top.toStringAsFixed(1)}–'
            '${snack.bottom.toStringAsFixed(1)}, footer top '
            '${footer.top.toStringAsFixed(1)}, button '
            '${cta.top.toStringAsFixed(1)}–${cta.bottom.toStringAsFixed(1)}; '
            'covers the button: ${snack.overlaps(cta)}');
        for (final e in find
            .descendant(
                of: find.byKey(const Key('premiumFooter')),
                matching: find.byType(RichText))
            .evaluate()) {
          final r = tester.getRect(find.byWidget(e.widget));
          final t = (e.widget as RichText).text.toPlainText();
          if (r.overlaps(snack)) {
            out.writeln('  covered: "${t.length > 50 ? '${t.substring(0, 50)}…' : t}" '
                '${r.top.toStringAsFixed(1)}–${r.bottom.toStringAsFixed(1)}');
          }
        }
      });
    }
  }
}
