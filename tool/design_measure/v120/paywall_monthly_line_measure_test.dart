// The annual card's "≈ $4.17 per month" line: does it overflow or wrap, how
// much taller is the card, and does the footer change? Real font. Each case
// is laid out twice, with the line and without it (the same offering with an
// empty currency code, which hides the line), so the difference is the line's.
// Prints one line per case.
//
//   flutter test tool/design_measure/v120/paywall_monthly_line_measure_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/screens/premium_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/storage_service.dart';
import 'package:grammar_lens/services/subscription_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../layouts.dart' show loadFont;

class _Service extends SubscriptionService {
  final bool withLine;
  _Service({required this.withLine});

  @override
  Future<Offering?> getOfferings() async {
    final currency = withLine ? 'USD' : '';
    const context = PresentedOfferingContext('default', null, null);
    final monthly = Package(
        '\$rc_monthly',
        PackageType.monthly,
        StoreProduct('grammarlens_premium_monthly', '', 'Monthly', 5.99,
            '\$5.99', currency,
            introductoryPrice: const IntroductoryPrice(
                0, '\$0.00', 'P3D', 1, PeriodUnit.day, 3),
            subscriptionPeriod: 'P1M'),
        context);
    final annual = Package(
        '\$rc_annual',
        PackageType.annual,
        StoreProduct('grammarlens_premium_annual', '', 'Annual', 49.99,
            '\$49.99', currency,
            introductoryPrice: const IntroductoryPrice(
                0, '\$0.00', 'P1W', 1, PeriodUnit.week, 1),
            subscriptionPeriod: 'P1Y'),
        context);
    return Offering('default', '', const {}, [monthly, annual],
        monthly: monthly, annual: annual);
  }

  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: TrialEligibility.eligible};
}

void main() {
  setUpAll(loadFont);

  // (width, height, bottom inset, AppTextSize, system text scale)
  final cases = <(double, double, double, AppTextSize, double)>[
    (390, 844, 34, AppTextSize.medium, 1),
    (390, 844, 34, AppTextSize.large, 1),
    (375, 667, 0, AppTextSize.medium, 1),
    (375, 667, 0, AppTextSize.large, 1),
    (320, 568, 0, AppTextSize.medium, 1),
    (320, 568, 0, AppTextSize.large, 1),
    (390, 844, 34, AppTextSize.medium, 1.3),
    (390, 844, 34, AppTextSize.medium, 2),
    (390, 844, 34, AppTextSize.medium, 3),
    (375, 667, 0, AppTextSize.large, 3),
  ];

  for (final (w, h, inset, textSize, scale) in cases) {
    testWidgets('${w.toInt()}x${h.toInt()} ${textSize.name} x$scale',
        (tester) async {
      Future<
          ({
            Rect card,
            Rect footer,
            double lineHeight,
            double rightWidth,
            bool wraps,
            String? error
          })> layout(bool withLine) async {
        tester.view.physicalSize = Size(w, h) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding =
            FakeViewPadding(top: (inset > 0 ? 47 : 20) * 3, bottom: inset * 3);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light, textSize: textSize),
          home: PremiumScreen(
            storageService: StorageService(),
            analyticsService: AnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _Service(withLine: withLine),
          ),
        ));
        await tester.pumpAndSettle();
        final error = tester.takeException()?.toString().split('\n').first;
        final card = find.byKey(const ValueKey('planCard_Annual'));
        final line = find.textContaining('per month');
        var lineHeight = 0.0;
        var wraps = false;
        var rightWidth = 0.0;
        {
          final price = tester.getRect(
              find.descendant(of: card, matching: find.text('\$49.99')));
          final perYear = tester.getRect(
              find.descendant(of: card, matching: find.text('per year')));
          var left = price.left < perYear.left ? price.left : perYear.left;
          final strike =
              find.descendant(of: card, matching: find.text('\$71.88'));
          if (withLine) {
            expect(strike, findsOneWidget);
            final r = tester.getRect(strike);
            if (r.left < left) left = r.left;
            // Struck through, above the price, smaller than it.
            expect(r.bottom, lessThanOrEqualTo(price.top + 1));
            expect(r.height, lessThan(price.height));
          }
          rightWidth = price.right - left;
        }
        if (withLine) {
          final inCard =
              find.descendant(of: card, matching: find.textContaining('≈'));
          final perYear =
              find.descendant(of: card, matching: find.text('per year'));
          lineHeight = tester.getRect(inCard).height;
          // Wrapped: taller than one line of the detail text above it.
          wraps = lineHeight > tester.getRect(perYear).height + .5;
          expect(line, findsWidgets);
        }
        return (
          card: tester.getRect(card),
          footer: tester.getRect(find.byKey(const Key('premiumFooter'))),
          lineHeight: lineHeight,
          rightWidth: rightWidth,
          wraps: wraps,
          error: error,
        );
      }

      final without = await layout(false);
      await tester.pumpWidget(const SizedBox());
      final with_ = await layout(true);
      String f(double v) => v.toStringAsFixed(1);
      // ignore: avoid_print
      print('MEASURE ${w.toInt()}x${h.toInt()} ${textSize.name} x$scale: '
          'card ${f(without.card.height)} -> ${f(with_.card.height)} '
          '(+${f(with_.card.height - without.card.height)}); '
          'footer ${f(without.footer.height)} -> ${f(with_.footer.height)}; '
          'right column ${f(without.rightWidth)} -> ${f(with_.rightWidth)}; '
          'line height ${f(with_.lineHeight)} wraps=${with_.wraps}; '
          'overflow: ${with_.error ?? 'none'} (before: ${without.error ?? 'none'})');
    });
  }
}
