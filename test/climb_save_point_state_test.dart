import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_point_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Scene art G8 (and G6 in dark mode): a save point is faded until the
/// avatar reaches it, then lights with a short fade when the hop ends (at
/// once with Reduce Motion); the campfire's flame burns only once reached,
/// and in dark mode it keeps its own colours then (G6).
void main() {
  Widget mountain(int days, int steps,
          {Brightness brightness = Brightness.light, bool reduce = false}) =>
      MaterialApp(
          theme: buildAppTheme(brightness),
          home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduce),
              child: Scaffold(
                  body: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                          width: 341.25,
                          child: MonthlyMountain(
                              days: days,
                              completedDays: steps,
                              avatar: Avatar.values.first))))));

  /// The save point's opacity, read from its colour matrix's alpha row:
  /// 0.5 unreached, 1 reached.
  double opacity(WidgetTester tester, String clearing) {
    final f = tester.widget<ClimbObjectLayer>(
        find.byKey(ValueKey('climb_save_point_$clearing')));
    return _matrix(f)[18];
  }

  test('"reached" is the avatar\'s arc at or past the save point\'s', () {
    for (final p in ClimbSavePoints.all) {
      expect(p.reachedAt(p.arc), isTrue);
      expect(p.reachedAt(p.arc - 1e-3), isFalse);
      for (var days = 28; days <= 31; days++) {
        final d = p.reachedOn(days);
        final route = ClimbRoute(days);
        expect(p.reachedAt(route.arcAt(d.toDouble())), isTrue);
        expect(p.reachedAt(route.arcAt(d - 1.0)), isFalse);
      }
    }
  });

  for (var days = 28; days <= 31; days++) {
    testWidgets('$days days: each save point lights on the day it is reached',
        (tester) async {
      for (final p in ClimbSavePoints.all) {
        final d = p.reachedOn(days);
        await tester.pumpWidget(mountain(days, d - 1));
        expect(opacity(tester, p.clearing), ClimbSavePoints.unreachedOpacity,
            reason: '${p.object} on day ${d - 1}');
        await tester.pumpWidget(mountain(days, d));
        await tester.pumpAndSettle();
        expect(opacity(tester, p.clearing), 1, reason: '${p.object} on day $d');
      }
    });
  }

  testWidgets('the fade starts when the hop ends, and is short',
      (tester) async {
    final p = ClimbSavePoints.all.first;
    final d = p.reachedOn(31);
    await tester.pumpWidget(mountain(31, d - 1));
    await tester.pumpWidget(mountain(31, d));
    // Mid-hop (850 ms): still faded.
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(tester, p.clearing), ClimbSavePoints.unreachedOpacity);
    // The hop ends; the fade runs.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 150));
    final mid = opacity(tester, p.clearing);
    expect(mid, greaterThan(ClimbSavePoints.unreachedOpacity));
    expect(mid, lessThan(1));
    await tester.pump(MonthlyMountain.savePointFade);
    expect(opacity(tester, p.clearing), 1);
  });

  testWidgets('Reduce Motion: lit at once, no animation', (tester) async {
    final p = ClimbSavePoints.all.first;
    final d = p.reachedOn(31);
    await tester.pumpWidget(mountain(31, d - 1, reduce: true));
    await tester.pumpWidget(mountain(31, d, reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(opacity(tester, p.clearing), 1);
  });

  // The campfire's flame (G8): faded with the rest until reached.
  const flame = Color(0xFFFFA020);
  final campfire =
      ClimbSavePoints.all.firstWhere((p) => p.object == 'campfire');

  test('unreached, a flame pixel is faded and less saturated', () {
    final c = ClimbSavePoints.apply(ClimbSavePoints.matrix(lit: 0), flame);
    expect(c.a, closeTo(ClimbSavePoints.unreachedOpacity, 1e-6));
    double sat(Color x) =>
        [x.r, x.g, x.b].reduce((a, b) => a > b ? a : b) -
        [x.r, x.g, x.b].reduce((a, b) => a < b ? a : b);
    expect(sat(c), lessThan(sat(flame) * .7));
    // Reached in light mode: its own colour.
    final lit = ClimbSavePoints.apply(ClimbSavePoints.matrix(lit: 1), flame);
    expect(lit.r, closeTo(flame.r, 1e-6));
    expect(lit.g, closeTo(flame.g, 1e-6));
    expect(lit.b, closeTo(flame.b, 1e-6));
    expect(lit.a, 1);
  });

  testWidgets(
      'unreached, the whole campfire, flame included, is drawn '
      'faded', (tester) async {
    await tester.pumpWidget(mountain(31, campfire.reachedOn(31) - 1));
    final layer = tester.widget<ClimbObjectLayer>(
        find.byKey(ValueKey('climb_save_point_${campfire.clearing}')));
    final c = ClimbSavePoints.apply(layer.matrix, flame);
    expect(c.a, closeTo(ClimbSavePoints.unreachedOpacity, 1e-6));
    // One image, one matrix: no part of it escapes the fade.
    expect(
        find.descendant(
            of: find.byKey(ValueKey('climb_save_point_${campfire.clearing}')),
            matching: find.byType(Image)),
        findsOneWidget);
  });

  testWidgets(
      'dark mode, reached: the flame is drawn unfiltered over the '
      'relit campfire', (tester) async {
    await tester.pumpWidget(
        mountain(31, campfire.reachedOn(31), brightness: Brightness.dark));
    await tester.pumpAndSettle();
    final overlay = find.byKey(const ValueKey('climb_campfire_flame'));
    expect(overlay, findsOneWidget);
    expect(tester.widget<Opacity>(overlay).opacity, 1);
    // Not inside any colour filter.
    expect(find.ancestor(of: overlay, matching: find.byType(ColorFiltered)),
        findsNothing);
    // The body is relit by the theme's gain.
    final body = tester.widget<ClimbObjectLayer>(
        find.byKey(ValueKey('climb_save_point_${campfire.clearing}')));
    final (gr, gg, gb) = climbObjectDarkGain['green_slope']!;
    final m = _matrix(body);
    expect(m[0], closeTo(gr, 1e-9));
    expect(m[6], closeTo(gg, 1e-9));
    expect(m[12], closeTo(gb, 1e-9));
  });

  testWidgets(
      'dark mode, unreached: no unfiltered flame; the fire is '
      'relit and faded', (tester) async {
    await tester.pumpWidget(
        mountain(31, campfire.reachedOn(31) - 1, brightness: Brightness.dark));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('climb_campfire_flame')), findsNothing);
    final body = tester.widget<ClimbObjectLayer>(
        find.byKey(ValueKey('climb_save_point_${campfire.clearing}')));
    final c = ClimbSavePoints.apply(_matrix(body), flame);
    final (gr, _, _) = climbObjectDarkGain['green_slope']!;
    expect(c.a, closeTo(ClimbSavePoints.unreachedOpacity, 1e-6));
    expect(c.r, lessThan(flame.r * gr + 1e-6));
  });

  testWidgets('light mode: no flame layer is needed', (tester) async {
    await tester.pumpWidget(mountain(31, 31));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('climb_campfire_flame')), findsNothing);
  });

  testWidgets('the summit flag stands in Green Slope, unfaded', (tester) async {
    await tester.pumpWidget(mountain(31, 3));
    final flag = tester.widget<ClimbObjectLayer>(
        find.byKey(const ValueKey('climb_summit_flag')));
    expect(_matrix(flag)[18], 1);
  });
}

List<double> _matrix(ClimbObjectLayer layer) => layer.matrix;
