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

  // 1.2.0 Batch 2 (owner decision Q16): the stadium plaque replaces the
  // trail sign, whose corner-radius tests went with it.
  for (final b in Brightness.values) {
    testWidgets(
        'Q16: the plaque is a stadium on the card surface with a 1.5 pt '
        'path outline, its title textPrimary 900, ${b.name}', (tester) async {
      await tester.pumpWidget(_card(b));
      final context = tester.element(find.byType(ClimbCard));
      final theme = Theme.of(context);
      final plaque = tester
          .widget<DecoratedBox>(find.byKey(ClimbCard.plaqueKey))
          .decoration as ShapeDecoration;
      expect(plaque.color, theme.colorScheme.surfaceContainerHigh);
      final shape = plaque.shape as StadiumBorder;
      expect(shape.side.color, AppPalette.of(context).pathOutline);
      expect(shape.side.width, 1.5);
      final title = tester.widget<Text>(find.text('Mountain of Learning'));
      expect(title.style!.fontWeight, FontWeight.w900);
      expect(title.style!.color, theme.colorScheme.onSurface);
    });

    testWidgets(
        'Q16: the frame has the same 1.5 pt path outline and the list card '
        'radius, ${b.name}', (tester) async {
      await tester.pumpWidget(_card(b));
      final context = tester.element(find.byType(ClimbCard));
      final frame = tester
          .widgetList<DecoratedBox>(find.descendant(
              of: find.byType(ClimbCard), matching: find.byType(DecoratedBox)))
          .map((d) => d.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.border != null);
      final side = (frame.border! as Border).top;
      expect(side.color, AppPalette.of(context).pathOutline);
      expect(side.width, 1.5);
      expect(frame.borderRadius, BorderRadius.circular(22));
      expect(ClimbCard.frameRadius, 22);
    });
  }

  testWidgets('the plaque sits centred on the frame\'s top line',
      (tester) async {
    await tester.pumpWidget(_card(Brightness.light));
    final plaque = tester.getRect(find.byKey(ClimbCard.plaqueKey));
    final card = tester.getRect(find.byType(ClimbCard));
    expect(
        plaque.height,
        closeTo(ClimbCard.plaqueHeight(tester.element(find.byType(ClimbCard))),
            .01));
    // The frame starts half a plaque below the card's top.
    expect(plaque.center.dy - card.top, closeTo(plaque.height / 2, .01));
    expect(plaque.center.dx, closeTo(card.center.dx, .01));
  });
}
