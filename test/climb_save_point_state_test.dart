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
    // At the default strength: the gain moved toward 1.
    final (gr, gg, gb) = climbObjectDarkGain['green_slope']!;
    double mix(double g) =>
        1 + ClimbSavePoints.defaultDarkFilterStrength * (g - 1);
    final m = _matrix(body);
    expect(m[0], closeTo(mix(gr), 1e-9));
    expect(m[6], closeTo(mix(gg), 1e-9));
    expect(m[12], closeTo(mix(gb), 1e-9));
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
    const k = ClimbSavePoints.defaultDarkFilterStrength;
    expect(c.a, closeTo(ClimbSavePoints.unreachedOpacity, 1e-6));
    expect(c.r, lessThan(flame.r * (1 + k * (gr - 1)) + 1e-6));
  });

  // G6's strength (device check, 2026-10-01): 0 leaves an object as it is,
  // 1 is the full relighting; the flame layer is outside it at any value.
  group('dark filter strength', () {
    final gain = climbObjectDarkGain['green_slope']!;
    tearDown(() => ClimbSavePoints.debugDarkFilterStrengthOverride = null);

    test('the default is 0.6, one constant', () {
      expect(ClimbSavePoints.defaultDarkFilterStrength, .6);
      expect(ClimbSavePoints.darkFilterStrength, .6);
    });

    test('0: the object is not filtered (as in light mode)', () {
      for (final lit in [0.0, .5, 1.0]) {
        expect(ClimbSavePoints.matrix(lit: lit, darkGain: gain, strength: 0),
            ClimbSavePoints.matrix(lit: lit));
      }
    });

    test('1: the full filter, as before the device check', () {
      final m = ClimbSavePoints.matrix(lit: 1, darkGain: gain, strength: 1);
      expect(m[0], closeTo(gain.$1, 1e-9));
      expect(m[6], closeTo(gain.$2, 1e-9));
      expect(m[12], closeTo(gain.$3, 1e-9));
    });

    test('in between, a linear mix of the two', () {
      const c = Color(0xFF8A6E52);
      final none = ClimbSavePoints.apply(
          ClimbSavePoints.matrix(lit: 1, darkGain: gain, strength: 0), c);
      final full = ClimbSavePoints.apply(
          ClimbSavePoints.matrix(lit: 1, darkGain: gain, strength: 1), c);
      for (final k in [.4, .6, .8]) {
        final mid = ClimbSavePoints.apply(
            ClimbSavePoints.matrix(lit: 1, darkGain: gain, strength: k), c);
        expect(mid.r, closeTo(none.r + k * (full.r - none.r), 1e-9));
        expect(mid.b, closeTo(none.b + k * (full.b - none.b), 1e-9));
      }
    });

    for (final k in [0.0, .4, .6, .8, 1.0]) {
      testWidgets('$k: the reached flame stays outside the filter',
          (tester) async {
        ClimbSavePoints.debugDarkFilterStrengthOverride = k;
        await tester.pumpWidget(
            mountain(31, campfire.reachedOn(31), brightness: Brightness.dark));
        await tester.pumpAndSettle();
        final overlay = find.byKey(const ValueKey('climb_campfire_flame'));
        expect(overlay, findsOneWidget);
        expect(tester.widget<Opacity>(overlay).opacity, 1);
        expect(find.ancestor(of: overlay, matching: find.byType(ColorFiltered)),
            findsNothing);
      });
    }
  });

  testWidgets('light mode: no flame layer is needed', (tester) async {
    await tester.pumpWidget(mountain(31, 31));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('climb_campfire_flame')), findsNothing);
  });

  // The flag on C6 is the month's goal: faded until the summit is reached
  // on the month's last step, then lit like a save point.
  for (var days = 28; days <= 31; days++) {
    testWidgets('$days days: the flag is lit only on the last day',
        (tester) async {
      final flag = ClimbSavePoints.flag;
      expect(flag.reachedOn(days), days);
      for (final d in [1, days - 2, days - 1]) {
        await tester.pumpWidget(mountain(days, d));
        expect(opacity(tester, flag.clearing), ClimbSavePoints.unreachedOpacity,
            reason: 'day $d');
      }
      await tester.pumpWidget(mountain(days, days));
      await tester.pumpAndSettle();
      expect(opacity(tester, flag.clearing), 1);
    });
  }

  testWidgets(
      'the flag fades in after the last hop; at once with Reduce '
      'Motion', (tester) async {
    final flag = ClimbSavePoints.flag;
    await tester.pumpWidget(mountain(31, 30));
    await tester.pumpWidget(mountain(31, 31));
    await tester.pump(const Duration(milliseconds: 600));
    expect(opacity(tester, flag.clearing), ClimbSavePoints.unreachedOpacity);
    await tester.pumpAndSettle();
    expect(opacity(tester, flag.clearing), 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(mountain(31, 30, reduce: true));
    await tester.pumpWidget(mountain(31, 31, reduce: true));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(opacity(tester, flag.clearing), 1);
  });

  testWidgets('dark mode: the flag takes the theme filter like the others',
      (tester) async {
    await tester.pumpWidget(mountain(31, 31, brightness: Brightness.dark));
    await tester.pumpAndSettle();
    final layer = tester.widget<ClimbObjectLayer>(find
        .byKey(ValueKey('climb_save_point_${ClimbSavePoints.flag.clearing}')));
    expect(
        layer.matrix,
        ClimbSavePoints.matrix(
            lit: 1, darkGain: climbObjectDarkGain['green_slope']));
  });
}

List<double> _matrix(ClimbObjectLayer layer) => layer.matrix;
