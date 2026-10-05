// Additional screens Batch 13: the paywall footer's visible gaps and
// targets, real font, at 390 × 844 (34 pt home indicator) and 375 × 667
// (none), Medium and Large. Prints one line per case.
//
//   flutter test tool/design_measure/v120/paywall_footer_measure_test.dart
import 'package:flutter/gestures.dart' show HitTestResult;
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
  @override
  Future<Offering?> getOfferings() async => buildDebugFixtureOffering();
  @override
  Future<Map<String, TrialEligibility>> checkTrialEligibility(
          List<String> productIds) async =>
      {for (final id in productIds) id: TrialEligibility.eligible};
}

void main() {
  setUpAll(loadFont);
  for (final (size, bottomInset) in [
    (const Size(390, 844), 34.0),
    (const Size(375, 667), 0.0),
    (const Size(320, 568), 0.0),
  ]) {
    for (final textSize in [AppTextSize.medium, AppTextSize.large]) {
      testWidgets(
          '${size.width.toInt()}x${size.height.toInt()} ${textSize.name}',
          (tester) async {
        tester.view.physicalSize = size * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(
            top: (bottomInset > 0 ? 47 : 20) * 3, bottom: bottomInset * 3);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: buildAppTheme(Brightness.light, textSize: textSize),
          home: PremiumScreen(
            storageService: StorageService(),
            analyticsService: AnalyticsService(),
            analyticsSource: AnalyticsService.paywallSourceHome,
            subscriptionService: _Service(),
          ),
        ));
        await tester.pumpAndSettle();
        final footer = tester.getRect(find.byKey(const Key('premiumFooter')));
        final cta = tester.getRect(find.byKey(PremiumScreen.ctaKey));
        final terms = tester.getRect(find.textContaining('auto-renews'));
        final links = tester.getRect(find.text('Terms of Service'));
        final later = tester.getRect(find.text('Maybe later'));
        // The tappable span, found by hit-testing (the drawn button is
        // shorter where the target reaches into the space around it).
        Rect tapSpan(String label) {
          final button = tester.renderObject(find.ancestor(
              of: find.text(label), matching: find.byType(TextButton)));
          final text = tester.getRect(find.text(label));
          bool hits(double y) {
            final result = HitTestResult();
            tester.binding.hitTestInView(
                result, Offset(text.center.dx, y), tester.view.viewId);
            return result.path.any((e) => e.target == button);
          }

          var top = text.center.dy, bottom = text.center.dy;
          while (hits(top - .5)) {
            top -= .5;
          }
          while (hits(bottom + .5)) {
            bottom += .5;
          }
          final box = tester.getRect(find.ancestor(
              of: find.text(label), matching: find.byType(TextButton)));
          return Rect.fromLTRB(box.left, top, box.right, bottom + .5);
        }

        final laterTarget = tapSpan('Maybe later');
        final termsTarget = tapSpan('Terms of Service');
        // ignore: avoid_print
        print('LINKS ${[
          'Restore Purchases',
          'Terms of Service',
          'Privacy Policy',
          'Maybe later'
        ].map((l) => '$l ${tester.getRect(find.text(l))} tap ${tapSpan(l)}').join(' | ')}');
        String f(double v) => v.toStringAsFixed(1);
        // ignore: avoid_print
        print('MEASURE ${size.width.toInt()}x${size.height.toInt()} '
            '${textSize.name}: footer ${f(footer.height)}; '
            'button→terms ${f(terms.top - cta.bottom)}; '
            'terms→links ${f(links.top - terms.bottom)}; '
            'links→"Maybe later" ${f(later.top - links.bottom)}; '
            '"Maybe later"→screen bottom ${f(size.height - later.bottom)}; '
            '"Maybe later" target ${f(laterTarget.width)}×${f(laterTarget.height)} '
            '(${f(laterTarget.top)}–${f(laterTarget.bottom)}); '
            'Terms target ${f(termsTarget.width)}×${f(termsTarget.height)} '
            '(${f(termsTarget.top)}–${f(termsTarget.bottom)})');
      });
    }
  }
}
