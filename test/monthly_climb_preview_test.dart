import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/preview/monthly_climb_preview.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

void main() {
  test('Every month walks the image\'s trail, evenly spaced, foot to summit',
      () {
    for (final days in [28, 29, 30, 31]) {
      final route = ClimbRoute(days);
      expect((route.pointAt(0) - ClimbRoute.foot).distance, lessThan(1e-4));
      expect((route.pointAt(days.toDouble()) - ClimbRoute.summit).distance,
          lessThan(1e-4));
      for (var day = 1; day <= days; day++) {
        // Straight-line distance never exceeds the even share along the
        // trail.
        final chord =
            (route.pointAt(day.toDouble()) - route.pointAt(day - 1.0)).distance;
        expect(chord, lessThanOrEqualTo(ClimbRoute.length / days + 1e-4));
      }
    }
  });

  test('Every month keeps continuous motion inside the image', () {
    for (final days in [28, 29, 30, 31]) {
      final route = ClimbRoute(days);
      var previous = route.pointAt(0);
      for (var tick = 1; tick <= days * 100; tick++) {
        final point = route.pointAt(tick / 100);
        // Never jumps: well under a hundredth of a day's share per tick.
        expect((point - previous).distance,
            lessThan(ClimbRoute.length / days / 50));
        expect(point.dx, inInclusiveRange(0, ClimbRoute.sceneSize.width));
        expect(point.dy, inInclusiveRange(0, ClimbRoute.sceneSize.height));
        previous = point;
      }
      // The whole climb goes up: the summit is far above the foot.
      expect(route.pointAt(days.toDouble()).dy,
          lessThan(route.pointAt(0).dy - .5));
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
    tester
        .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Preview next step'))
        .onPressed!();
    await tester.pumpAndSettle();
    final progress = find.text('9 / 30 days');
    for (var i = 0; i < 12 && progress.evaluate().isEmpty; i++) {
      await tester.dragFrom(const Offset(8, 120), const Offset(0, 160));
      await tester.pumpAndSettle();
    }
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
