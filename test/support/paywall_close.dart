import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/screens/premium_screen.dart';

/// Fix round 5, item 4 (SPEC V13 "Closing (v13)", §1.29): the paywall
/// closes only with its X, wherever it is opened. Run the test with iOS's
/// behaviour (`variant: iOSOnly`: the edge swipe back is iOS's gesture):
/// a swipe from the left edge (slow, then flung), a drag down from the top
/// and a system back (Android's back) each leave it open.
final iOSOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

Future<void> expectPaywallHolds(WidgetTester tester) async {
  final paywall = find.byType(PremiumScreen);
  expect(paywall, findsOneWidget, reason: 'the paywall is open');
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  final y = size.height * .5;

  // The iOS edge swipe back, dragged slowly across …
  final swipe = await tester.startGesture(Offset(2, y));
  for (var i = 0; i < 12; i++) {
    await swipe.moveBy(Offset(size.width * .07, 0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await swipe.up();
  await tester.pumpAndSettle();
  expect(paywall, findsOneWidget, reason: 'a slow swipe from the left edge');

  // … and flung.
  await tester.flingFrom(Offset(2, y), Offset(size.width * .6, 0), 1500);
  await tester.pumpAndSettle();
  expect(paywall, findsOneWidget, reason: 'a fling from the left edge');

  // A drag down from the top, as a sheet is closed.
  await tester.flingFrom(
      Offset(size.width * .6, 90), Offset(0, size.height * .7), 1500);
  await tester.pumpAndSettle();
  expect(paywall, findsOneWidget, reason: 'a drag down');

  // A system back (Android's back button, a pop from the platform).
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  expect(paywall, findsOneWidget, reason: 'a system back');
}

/// The X closes it. With the store's offer loaded, its first tap in a
/// session opens V13b ([reminder]), whose "Continue with free" closes the
/// paywall; without an offer (V13b states the trial) or after the first
/// time, it closes at once — as before fix round 5.
Future<void> closeWithX(WidgetTester tester, {required bool reminder}) async {
  await tester.ensureVisible(find.byKey(PremiumScreen.closeKey));
  await tester.tap(find.byKey(PremiumScreen.closeKey));
  await tester.pumpAndSettle();
  final free = find.byKey(PremiumScreen.exitContinueFreeKey);
  if (reminder) {
    expect(free, findsOneWidget, reason: 'V13b on the first close');
    await tester.tap(free);
    await tester.pumpAndSettle();
  } else {
    expect(free, findsNothing);
  }
  expect(find.byType(PremiumScreen), findsNothing);
}
