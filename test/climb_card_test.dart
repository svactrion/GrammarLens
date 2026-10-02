import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

Widget _card(Brightness brightness, {int steps = 3, Avatar? avatar}) =>
    MaterialApp(
      theme: buildAppTheme(brightness),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: ClimbCard(
            month: DateTime(2026, 10),
            steps: steps,
            days: 31,
            mountain: MonthlyMountain(
                days: 31,
                completedDays: steps,
                avatar: avatar ?? Avatar.values.first),
            scoreBar: const SizedBox(height: 40),
          ),
        ),
      ),
    );

void main() {
  for (final b in Brightness.values) {
    testWidgets(
        'K4: month and steps are at least 4.5:1 on their chips, '
        '${b.name}', (tester) async {
      await tester.pumpWidget(_card(b));
      for (final key in [ClimbCard.monthKey, ClimbCard.stepsKey]) {
        final text = tester.widget<Text>(find.byKey(key));
        final chip = tester.widget<DecoratedBox>(find
            .ancestor(of: find.byKey(key), matching: find.byType(DecoratedBox))
            .first);
        final chipColor = (chip.decoration as BoxDecoration).color!;
        // Opaque, so the contrast below holds over any part of the
        // illustrated scene (scene art S1), light or dusk.
        expect(chipColor.a, 1.0, reason: '$key in ${b.name}');
        expect(
            _contrast(text.style!.color!, chipColor), greaterThanOrEqualTo(4.5),
            reason: '$key in ${b.name}');
      }
    });
  }

  testWidgets(
      'VoiceOver: the plaque is read as a heading; the counter as '
      '"3 of 31 steps"', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_card(Brightness.light));
    final plaque = tester.getSemantics(find.text('Mountain of Learning'));
    expect(plaque.label, 'Mountain of Learning');
    expect(plaque.getSemanticsData().flagsCollection.isHeader, isTrue);
    expect(find.bySemanticsLabel('3 of 31 steps.'), findsOneWidget);
    expect(find.bySemanticsLabel('3 / 31'), findsNothing);
    expect(find.bySemanticsLabel('October'), findsOneWidget);
    await tester.pumpWidget(_card(Brightness.light, steps: 31));
    expect(find.bySemanticsLabel('Summit reached. 31 of 31 steps.'),
        findsOneWidget);
    semantics.dispose();
  });

  // D4, confirmed by Batch 3c K2: no avatar is ever mirrored.
  bool mirrored(WidgetTester tester) => tester
      .widgetList<Transform>(find.ancestor(
          of: find.byType(AvatarTile), matching: find.byType(Transform)))
      .any((t) => t.transform.storage[0] < 0);

  testWidgets('no avatar is mirrored, on any leg or while moving',
      (tester) async {
    // The legs alternate direction: day 3 walks right, day 10 left.
    final route = ClimbRoute(31);
    expect(route.stepAt(4).dx - route.stepAt(3).dx, greaterThan(0));
    expect(route.stepAt(11).dx - route.stepAt(10).dx, lessThan(0));
    for (final avatar in Avatar.values) {
      for (final day in [0, 3, 10, 17, 24, 31]) {
        await tester
            .pumpWidget(_card(Brightness.light, steps: day, avatar: avatar));
        expect(mirrored(tester), isFalse,
            reason: '${avatar.semanticLabel} on day $day');
      }
    }
    // Moving across a turn, mid-hop.
    await tester.pumpWidget(_card(Brightness.light, steps: 8));
    await tester.pumpWidget(_card(Brightness.light, steps: 9));
    for (var i = 0; i < 9; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(mirrored(tester), isFalse);
    }
  });

  group('the plaque\'s rounded corners (Batch 6 Batch 0, step 2)', () {
    testWidgets(
        'its radius is derived from the frame\'s, which is the app\'s card '
        'radius', (tester) async {
      await tester.pumpWidget(_card(Brightness.light));
      final shape = (tester
              .widget<DecoratedBox>(find.byKey(ClimbCard.plaqueKey))
              .decoration as ShapeDecoration)
          .shape as TrailSignBorder;
      expect(shape.radius, ClimbCard.frameRadius * ClimbCard.plaqueRadiusShare);
      final card = Theme.of(tester.element(find.byType(ClimbCard))).cardTheme;
      expect((card.shape! as RoundedRectangleBorder).borderRadius,
          BorderRadius.circular(ClimbCard.frameRadius));
    });

    const rect = Rect.fromLTWH(0, 0, 220, 36);
    // Half of a point's angle: atan((height / 2) / depth).
    final tipHalf = math.atan(1 / (2 * TrailSignBorder.pointDepth));

    test(
        'the sharp sign reaches the rect\'s ends; the rounded one keeps its '
        'silhouette and pulls its points in by r (1 / sin(half) − 1)', () {
      const side = BorderSide();
      final sharp = const TrailSignBorder(side).getOuterPath(rect).getBounds();
      expect(sharp.left, closeTo(rect.left, 1e-9));
      expect(sharp.right, closeTo(rect.right, 1e-9));
      const r = 8.0;
      final rounded = const TrailSignBorder(side, radius: r).getOuterPath(rect);
      // The outline's own extent, sampled (`getBounds` counts the arcs'
      // control points).
      final xs = <double>[], ys = <double>[];
      for (final m in rounded.computeMetrics()) {
        for (var d = 0.0; d <= m.length; d += .01) {
          final p = m.getTangentForOffset(d)!.position;
          xs.add(p.dx);
          ys.add(p.dy);
        }
      }
      final pullIn = r * (1 / math.sin(tipHalf) - 1);
      expect(xs.reduce(math.min), closeTo(rect.left + pullIn, .01));
      expect(xs.reduce(math.max), closeTo(rect.right - pullIn, .01));
      expect(ys.reduce(math.min), closeTo(rect.top, .01));
      expect(ys.reduce(math.max), closeTo(rect.bottom, .01));
      // No point of the sharp sign's corners is inside the rounded one, and
      // the text area (between the points' inner ends) is.
      for (final c in TrailSignBorder.corners(rect)) {
        expect(rounded.contains(c), isFalse, reason: '$c');
      }
      final inset = rect.height * TrailSignBorder.pointDepth;
      expect(rounded.contains(Offset(inset + 1, 1.5)), isTrue);
      expect(rounded.contains(Offset(rect.right - inset - 1, 34.5)), isTrue);
    });

    test('a radius too large for an edge is fitted to half of it', () {
      final c = TrailSignBorder.corners(rect);
      final edge = (c[0] - c[5]).distance;
      final fitted = TrailSignBorder.fittedRadius(c[0], c[5], c[4], 100);
      expect(fitted / math.tan(tipHalf), closeTo(edge / 2, 1e-9));
      expect(
          TrailSignBorder.fittedRadius(c[0], c[5], c[4], 8), closeTo(8, 1e-9));
    });
  });
}
