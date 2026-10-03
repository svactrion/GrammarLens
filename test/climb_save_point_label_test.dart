import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_point_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Batch 5 (N6, N11, N18, N19): save point names and their label, and the
/// C5 signpost, which is decoration.
void main() {
  const width = 341.25;

  Widget mountain(int days, int steps,
          {Brightness brightness = Brightness.light,
          bool reduce = false,
          Animation<double>? zoom,
          List<Rect> avoid = const []}) =>
      MaterialApp(
          theme: buildAppTheme(brightness),
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduce),
              child: Scaffold(
                  body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                          width: width,
                          child: MonthlyMountain(
                              days: days,
                              completedDays: steps,
                              avatar: Avatar.values.first,
                              zoom: zoom,
                              labelAvoid: (_) => avoid))))));

  final label = find.byKey(MonthlyMountain.labelKey);
  String labelText(WidgetTester tester) => tester
      .widget<Text>(find.descendant(of: label, matching: find.byType(Text)))
      .data!;
  double labelOpacity(WidgetTester tester) => tester
      .widget<Opacity>(
          find.ancestor(of: label, matching: find.byType(Opacity)).first)
      .opacity;

  /// From the step before to [step], through the hop to its end.
  Future<void> stepTo(WidgetTester tester, int days, int step,
      {bool reduce = false}) async {
    // A fresh scene each time: mounted on the step before, then one step.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(mountain(days, step - 1, reduce: reduce));
    await tester.pumpWidget(mountain(days, step, reduce: reduce));
    await tester.pump();
    if (!reduce) await tester.pump(const Duration(milliseconds: 860));
  }

  test('N6: five names, the same in every theme; event ids in snake case', () {
    expect({
      for (final p in ClimbSavePoints.all) p.object: p.name
    }, {
      'tent': 'First Camp',
      'cabin': 'Halfway Hut',
      'fountain': 'Mountain Spring',
      'campfire': 'High Camp',
    });
    expect(ClimbSavePoints.flag.name, 'Summit');
    expect([for (final p in ClimbSavePoints.all) p.eventId],
        ['first_camp', 'halfway_hut', 'mountain_spring', 'high_camp']);
    expect(ClimbSavePoints.flag.eventId, 'summit');
  });

  for (var days = 28; days <= 31; days++) {
    testWidgets(
        '$days days: each save point\'s name shows on the step that reaches '
        'it, the flag\'s only on the last', (tester) async {
      for (final p in [...ClimbSavePoints.all, ClimbSavePoints.flag]) {
        final d = p.reachedOn(days);
        await stepTo(tester, days, d);
        expect(label, findsOneWidget, reason: '${p.name} on step $d');
        expect(labelText(tester), p.name);
        await tester.pumpAndSettle();
        expect(label, findsNothing);
      }
      expect(ClimbSavePoints.flag.reachedOn(days), days);
    });
  }

  testWidgets('a step that reaches no save point shows no label',
      (tester) async {
    await stepTo(tester, 31, 3);
    expect(label, findsNothing);
    // C5's step: the signpost is decoration, it has no label.
    await stepTo(tester, 31, 29);
    expect(label, findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'once: the scene mounting on a save point\'s step shows none, and a '
      'rebuild at the same step shows none again', (tester) async {
    final d = ClimbSavePoints.all[1].reachedOn(31);
    await tester.pumpWidget(mountain(31, d));
    await tester.pumpAndSettle();
    expect(label, findsNothing);

    await stepTo(tester, 31, d);
    expect(label, findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pumpWidget(mountain(31, d));
    await tester.pumpAndSettle();
    expect(label, findsNothing);
  });

  testWidgets(
      'N19 timing: 200 ms in with the light-up, shown 2.5 s, 400 ms out',
      (tester) async {
    await stepTo(tester, 31, ClimbSavePoints.all.first.reachedOn(31));
    // The hop has just ended.
    await tester.pump(const Duration(milliseconds: 100));
    expect(labelOpacity(tester), closeTo(.5, .2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(labelOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 2400));
    expect(labelOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 300));
    expect(labelOpacity(tester), lessThan(1));
    await tester.pump(const Duration(milliseconds: 200));
    expect(label, findsNothing);
    expect(MonthlyMountain.labelFadeIn, const Duration(milliseconds: 200));
    expect(MonthlyMountain.labelShown, const Duration(milliseconds: 2500));
    expect(MonthlyMountain.labelFadeOut, const Duration(milliseconds: 400));
  });

  testWidgets(
      'Reduce Motion: the label appears at once, fully, with no animation, '
      'for 3 s', (tester) async {
    await stepTo(tester, 31, ClimbSavePoints.all.first.reachedOn(31),
        reduce: true);
    await tester.pump();
    expect(label, findsOneWidget);
    expect(labelOpacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(milliseconds: 2900));
    expect(label, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
    expect(label, findsNothing);
  });

  testWidgets('during a zoom no label is shown (it stands in the daily view)',
      (tester) async {
    final d = ClimbSavePoints.all.first.reachedOn(31);
    const zoom = AlwaysStoppedAnimation(.5);
    await tester.pumpWidget(mountain(31, d - 1, zoom: zoom));
    await tester.pumpWidget(mountain(31, d, zoom: zoom));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(label, findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets(
      'N19 placement: above the object and the avatar\'s art, inside the '
      'window', (tester) async {
    for (final p in [...ClimbSavePoints.all, ClimbSavePoints.flag]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(mountain(31, p.reachedOn(31) - 1));
      await tester.pumpWidget(mountain(31, p.reachedOn(31)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1200));
      final window = tester.getRect(find.byType(MonthlyMountain));
      final box = tester.getRect(label);
      final object = tester
          .getRect(find.byKey(ValueKey('climb_save_point_${p.clearing}')));
      final tile = tester.getRect(find.descendant(
          of: find.byType(MonthlyMountain), matching: find.byType(AvatarTile)));
      expect(box.left, greaterThanOrEqualTo(window.left + 6 - 1e-6));
      expect(box.right, lessThanOrEqualTo(window.right - 6 + 1e-6));
      expect(box.top, greaterThanOrEqualTo(window.top + 6 - 1e-6));
      if (box.top > window.top + 6 + 1e-6) {
        expect(box.bottom, lessThanOrEqualTo(object.top - 4 + 1e-6),
            reason: p.name);
        expect(
            box.bottom,
            lessThanOrEqualTo(tile.top +
                MonthlyMountain.avatarArtTop * tile.height -
                4 +
                1e-6),
            reason: p.name);
      }
      await tester.pumpAndSettle();
    }
  });

  testWidgets(
      'N19: a label that would touch a chip moves down below it; one that '
      'would not stays', (tester) async {
    final p = ClimbSavePoints.all[2];
    await tester.pumpWidget(mountain(31, p.reachedOn(31) - 1));
    await tester.pumpWidget(mountain(31, p.reachedOn(31)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    final window = tester.getRect(find.byType(MonthlyMountain));
    final free = tester.getRect(label).shift(-window.topLeft);
    await tester.pumpAndSettle();

    // A chip right over where it stood.
    final chip = Rect.fromLTWH(free.left, free.top - 10, 40, 24);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(mountain(31, p.reachedOn(31) - 1, avoid: [chip]));
    await tester.pumpWidget(mountain(31, p.reachedOn(31), avoid: [chip]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    final moved = tester.getRect(label).shift(-window.topLeft);
    expect(moved.top, closeTo(chip.bottom + MonthlyMountain.labelGap, 1e-6));
    expect(moved.left, free.left);
    await tester.pumpAndSettle();

    // A chip elsewhere: no move.
    await tester.pumpWidget(const SizedBox());
    final far = Rect.fromLTWH(window.width - 50, 0, 40, 24);
    await tester.pumpWidget(mountain(31, p.reachedOn(31) - 1, avoid: [far]));
    await tester.pumpWidget(mountain(31, p.reachedOn(31), avoid: [far]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.getRect(label).shift(-window.topLeft), free);
    await tester.pumpAndSettle();
  });

  group('the C5 signpost (N11, N18)', () {
    final sign = find.byKey(const ValueKey('climb_decor_C5'));

    test('decoration, not a save point: on C5, from the table', () {
      expect(ClimbSavePoints.decor.single.clearing, 'C5');
      expect(ClimbSavePoints.decor.single.object, 'signpost');
      expect(climbDecorTable.single.$7, 0.95);
      expect(ClimbSavePoints.names.containsKey('signpost'), isFalse);
    });

    testWidgets('drawn lit at every step, start and summit included',
        (tester) async {
      for (final step in [0, 20, 29, 31]) {
        await tester.pumpWidget(mountain(31, step));
        final layer = tester.widget<ClimbObjectLayer>(sign);
        expect(layer.matrix[18], 1, reason: 'opacity on step $step');
        expect(layer.matrix, ClimbSavePoints.matrix(lit: 1));
      }
    });

    testWidgets('in dark mode through the theme\'s relighting, lit',
        (tester) async {
      await tester.pumpWidget(mountain(31, 5, brightness: Brightness.dark));
      expect(
          tester.widget<ClimbObjectLayer>(sign).matrix,
          ClimbSavePoints.matrix(
              lit: 1, darkGain: climbObjectDarkGain['green_slope']));
    });

    testWidgets(
        'not named in the scene\'s VoiceOver label; the save points are',
        (tester) async {
      await tester.pumpWidget(mountain(31, 5));
      final semantics = tester
          .getSemantics(find.byType(MonthlyMountain))
          .getSemanticsData()
          .label;
      expect(semantics, contains('First Camp at step 7'));
      expect(semantics.toLowerCase(), isNot(contains('signpost')));
      expect(ClimbThemes.greenSlope.name, isNotEmpty);
    });
  });
}
