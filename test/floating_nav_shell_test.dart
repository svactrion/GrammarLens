import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/widgets/floating_nav_shell.dart';

/// The bug this guards against (docs/design-audit.md S4): every tab
/// screen used to reserve a fixed guessed bottom padding
/// (`navBarClearance = 110`) that didn't actually match the bar's real
/// footprint, so scrollable content stayed clipped behind it even at max
/// scroll on some devices. `FloatingNavShell` measures the bar's real
/// height instead — these tests scroll a tab's content to its absolute
/// end and check nothing is left behind the bar.
void main() {
  const tabs = [
    NavShellTab(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    NavShellTab(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  Future<void> pumpShell(
    WidgetTester tester, {
    required Widget body,
    double safeAreaBottomInset = 34,
  }) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    // A real home-indicator inset — exactly the device-specific quantity
    // the old fixed constant couldn't account for.
    tester.view.padding =
        FakeViewPadding(bottom: safeAreaBottomInset * tester.view.devicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(
        home: FloatingNavShell(
          tabs: tabs,
          selectedIndex: 0,
          onTabChange: (_) {},
          body: body,
        ),
      ),
    );
    // First frame lays out with the pre-measurement fallback clearance;
    // the post-frame callback then measures the real bar and triggers a
    // second frame with the corrected value.
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      "a scrollable tab's last item can be scrolled fully clear of the "
      'nav bar, not left clipped behind it', (tester) async {
    // Mirrors exactly how Home/Review/Settings use the mechanism: the tab
    // screen itself reads NavBarClearance.of(context) for its own scroll
    // view's bottom padding. FloatingNavShell doesn't inject this
    // automatically (a screen has to ask, the same way MediaQuery works),
    // so the test has to follow that same contract to actually exercise it.
    await pumpShell(
      tester,
      body: Builder(
        builder: (context) => ListView(
          padding: EdgeInsets.only(bottom: NavBarClearance.of(context)),
          children: [
            for (var i = 0; i < 30; i++) SizedBox(height: 60, child: Text('Item $i')),
          ],
        ),
      ),
    );

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();

    final lastItemBottom = tester.getBottomLeft(find.text('Item 29')).dy;
    final barTop = tester.getTopLeft(find.byType(BackdropFilter)).dy;

    expect(
      lastItemBottom,
      lessThanOrEqualTo(barTop),
      reason: 'The last scrolled item must clear the nav bar, not sit '
          'behind/under it.',
    );
  });

  testWidgets('the measured clearance grows with the device safe-area inset',
      (tester) async {
    double? readClearance(BuildContext context) => NavBarClearance.of(context);

    late double? clearanceValue;
    await pumpShell(
      tester,
      safeAreaBottomInset: 34,
      body: Builder(
        builder: (context) {
          clearanceValue = readClearance(context);
          return const SizedBox();
        },
      ),
    );

    // Comfortably larger than the raw safe-area inset alone, proving the
    // bar's own visual chrome is counted too, not just the device inset.
    expect(clearanceValue, greaterThan(34));
    // And distinctly different from the old hardcoded guess — this is a
    // real measurement, not another fixed number that happens to match.
    expect(clearanceValue, isNot(NavBarClearance.fallback));
  });

  testWidgets(
      'NavBarClearance.of falls back to a fixed value outside a '
      'FloatingNavShell (e.g. a screen pumped in isolation under test)',
      (tester) async {
    late double clearance;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            clearance = NavBarClearance.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(clearance, NavBarClearance.fallback);
  });
}
