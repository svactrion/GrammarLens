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
                avatar: avatar ?? Avatar.values.first,
                allowUserScroll: false),
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
    expect(math.cos(route.stepAngle(3)), greaterThan(0));
    expect(math.cos(route.stepAngle(10)), lessThan(0));
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
}
