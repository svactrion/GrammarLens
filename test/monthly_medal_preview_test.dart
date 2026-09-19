import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/preview/monthly_medal_preview.dart';

void main() {
  const scenarios = [
    'In progress',
    'Bronze finalized',
    'Silver finalized',
    'Gold finalized',
    'No medal',
    'Multiple months',
  ];

  // A device-sized viewport, set explicitly rather than relying on
  // flutter_test's small default surface — the default is short enough
  // that the dropdown field itself sits outside its bounds, which makes
  // `tester.tap` miss it entirely instead of opening the menu.
  void setDeviceSize(WidgetTester tester, {double width = 375}) {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  // The scenario dropdown's field shows the currently-selected label, and
  // opening it lists every option including that same label again — `from`
  // (the field, closed) then `to` (the option, in the open menu) picks the
  // right occurrence without depending on the private scenario enum this
  // test file can't import.
  Future<void> selectScenario(
      WidgetTester tester, String from, String to) async {
    await tester.tap(find.text(from).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(to).last);
    await tester.pumpAndSettle();
  }

  testWidgets('every medal scenario renders with no exception, both themes',
      (tester) async {
    setDeviceSize(tester);
    // A single pumpWidget, not one per theme: pumping the same const
    // MonthlyMedalPreview again mid-test would reuse the existing State
    // (same widget type, no key) rather than reset it, so a second
    // pumpWidget wouldn't actually bring the dropdown back to "In
    // progress" — it would silently keep whatever scenario the first
    // cycle ended on. Toggling dark mode in place and continuing the
    // scenario cycle from wherever it left off avoids relying on a reset
    // that wouldn't really happen.
    await tester.pumpWidget(const MonthlyMedalPreview());
    await tester.pumpAndSettle();

    var current = scenarios.first;
    for (final dark in [false, true]) {
      if (dark) {
        await tester.tap(find.byTooltip('Toggle dark mode'));
        await tester.pumpAndSettle();
      }
      for (final target in scenarios) {
        if (target != current) {
          await selectScenario(tester, current, target);
          current = target;
        }
        expect(tester.takeException(), isNull,
            reason: '$target in ${dark ? 'dark' : 'light'} mode');
      }
    }
  });

  testWidgets('each finalized scenario shows the expected medal outcome',
      (tester) async {
    setDeviceSize(tester);
    await tester.pumpWidget(const MonthlyMedalPreview());
    await tester.pumpAndSettle();

    expect(
      find.text('Your monthly medals will appear here once earned.'),
      findsOneWidget,
      reason: 'In progress starts with no finalized history',
    );

    await selectScenario(tester, 'In progress', 'Bronze finalized');
    expect(find.textContaining('Bronze medal'), findsWidgets);

    await selectScenario(tester, 'Bronze finalized', 'Silver finalized');
    expect(find.textContaining('Silver medal'), findsWidgets);

    await selectScenario(tester, 'Silver finalized', 'Gold finalized');
    expect(find.textContaining('Gold medal'), findsWidgets);

    // "No medal" also happens to be this scenario's own dropdown label, so
    // it legitimately renders twice (the selected field plus the frozen
    // history row) — assert presence, not an exact count.
    await selectScenario(tester, 'Gold finalized', 'No medal');
    expect(find.text('No medal'), findsWidgets);

    await selectScenario(tester, 'No medal', 'Multiple months');
    expect(find.textContaining('Gold medal'), findsWidgets);
    expect(find.textContaining('Silver medal'), findsWidgets);
    expect(find.textContaining('Bronze medal'), findsWidgets);
    expect(find.text('No medal'), findsWidgets);
  });

  for (final textSize in ['Small', 'Medium', 'Large']) {
    testWidgets(
        'the busiest scenario (multiple finalized months, Welcome earned) '
        'renders with no exception at $textSize text, 320pt width',
        (tester) async {
      setDeviceSize(tester, width: 320);
      await tester.pumpWidget(const MonthlyMedalPreview());
      await tester.pumpAndSettle();
      await selectScenario(tester, 'In progress', 'Multiple months');
      await tester.tap(find.text('Welcome badge earned'));
      await tester.pumpAndSettle();
      if (textSize != 'Medium') {
        await tester.tap(find.text(textSize));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });
  }

  group('Welcome badge earned toggle (docs/gamification-handoff.md §12.5)', () {
    testWidgets(
        'starts locked, and the toggle flips it independently of '
        'the medal scenario', (tester) async {
      setDeviceSize(tester);
      await tester.pumpWidget(const MonthlyMedalPreview());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Welcome badge, locked.'), findsOneWidget);

      await tester.tap(find.text('Welcome badge earned'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Welcome badge, earned.'), findsOneWidget);

      // Switching the medal scenario must not reset or depend on the
      // Welcome toggle — the two are deliberately orthogonal (§12.5).
      await selectScenario(tester, 'In progress', 'Gold finalized');
      expect(find.bySemanticsLabel('Welcome badge, earned.'), findsOneWidget);

      await tester.tap(find.text('Welcome badge earned'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Welcome badge, locked.'), findsOneWidget);
    });
  });
}
