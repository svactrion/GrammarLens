import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/preview/monthly_climb_preview.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

void main() {
  test('Every month keeps continuous motion and landmarks within scene', () {
    for (final days in [28, 29, 30, 31]) {
      final route = ClimbRoute(days);
      var previous = route.pointAt(0);
      for (var tick = 1; tick <= days * 100; tick++) {
        final point = route.pointAt(tick / 100);
        expect(point.dy, lessThanOrEqualTo(previous.dy + .01));
        expect((point - previous).distance, lessThan(3));
        expect(point.dx, inInclusiveRange(29, 291));
        expect(point.dy, inInclusiveRange(55, 740));
        previous = point;
      }
      for (final day in [7, 14, 21, 28]) {
        final point = route.pointAt(day.toDouble());
        final landmarkX = point.dx + (point.dx > 160 ? -42 : 42);
        expect(landmarkX - 30, greaterThanOrEqualTo(0));
        expect(landmarkX + 30, lessThanOrEqualTo(320));
      }
      expect(route.pointAt(days.toDouble()).dx, closeTo(160, .01));
      expect(route.pointAt(days.toDouble()).dy, closeTo(120, .01));
    }
  });

  testWidgets('Small screen can reach controls and advance sample progress',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MonthlyClimbPreview());
    await tester.pumpAndSettle();
    // Drag the outer gutter: a gesture centered on the mountain correctly
    // belongs to its independent inner viewport instead of the page.
    Future<void> reveal(Finder finder) async {
      for (var i = 0; i < 12 && finder.evaluate().isEmpty; i++) {
        await tester.dragFrom(const Offset(8, 480), const Offset(0, -160));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    final next = find.text('Preview next step');
    await reveal(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(find.text('9 / 30 days'), findsOneWidget);
    await reveal(find.text('28 days'));
    await tester.tap(find.text('28 days'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '28 days'))
            .selected,
        isTrue);
    await reveal(find.text('Reduce motion'));
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('Reduced motion reaches final step immediately in $brightness',
        (tester) async {
      final semantics = tester.ensureSemantics();
      Widget fixture(int progress) => MaterialApp(
          theme: buildAppTheme(brightness),
          home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                  body: SizedBox(
                      width: 320,
                      child: MonthlyMountain(
                          days: 28,
                          completedDays: progress,
                          avatar: Avatar.values.first)))));
      await tester.pumpWidget(fixture(27));
      await tester.pumpAndSettle();
      await tester.pumpWidget(fixture(28));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel(RegExp('Green Slope. 28 of 28 steps')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}
