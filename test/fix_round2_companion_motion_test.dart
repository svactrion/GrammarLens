import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/widgets/companion_view.dart';

/// Fix round 2, item 1: on the owner's phone the companions did not move
/// the way the design says. Every mood's loop must be clearly visible
/// (SPEC §3.5 values are minimums): idle = breathe + ±3 px float; wave =
/// ±6° sway; cheer = two hops; think = tilt; sleep = breathe + a rising
/// Zzz. Reduce Motion still stops them.
void main() {
  /// The frames over one period, sampled every 1 %.
  List<CompanionFrame> period(CompanionMood mood,
          {double size = 110,
          CompanionAmbient ambient = CompanionAmbient.mood}) =>
      [
        for (var i = 0; i < 100; i++)
          CompanionView.frameAt(mood, i / 100, size: size, ambient: ambient)
      ];
  double range(Iterable<double> v) => v.reduce(math.max) - v.reduce(math.min);

  group('each mood\'s loop is above its minimum', () {
    test('idle: breathes to 1.04 and floats 6 px (±3)', () {
      final f = period(CompanionMood.idle);
      expect(range(f.map((f) => f.dy)), greaterThanOrEqualTo(6));
      expect(f.map((f) => f.scaleY).reduce(math.max),
          greaterThanOrEqualTo(1.04 - 1e-9));
    });

    test('wave: sways at least ±6° (gl-wave) and bobs', () {
      final f = period(CompanionMood.wave);
      expect(f.map((f) => f.turn).reduce(math.min), lessThanOrEqualTo(-6));
      expect(f.map((f) => f.turn).reduce(math.max), greaterThanOrEqualTo(6));
      expect(range(f.map((f) => f.dy)), greaterThanOrEqualTo(4 - 1e-9));
    });

    test('cheer: two hops of at least 14 px in every loop, then a breath', () {
      final dy = [
        for (var i = 0; i < 1000; i++)
          CompanionView.frameAt(CompanionMood.cheer, i / 1000).dy
      ];
      // Count the times the body leaves the ground by 14 px.
      var hops = 0;
      var up = false;
      for (final d in dy) {
        if (!up && d <= -14) {
          hops++;
          up = true;
        } else if (up && d > -1) {
          up = false;
        }
      }
      expect(hops, 2);
      final rest = period(CompanionMood.cheer).skip(50);
      expect(rest.map((f) => f.scaleY).reduce(math.max), greaterThan(1.03));
    });

    test('think: tilts to at least −6°', () {
      final f = period(CompanionMood.think);
      expect(f.map((f) => f.turn).reduce(math.min), lessThanOrEqualTo(-6));
      expect(range(f.map((f) => f.turn)), greaterThanOrEqualTo(8));
    });

    test('inspect: tilts ±4° (gl-tilt)', () {
      final f = period(CompanionMood.inspect);
      expect(f.map((f) => f.turn).reduce(math.min), lessThanOrEqualTo(-4));
      expect(f.map((f) => f.turn).reduce(math.max), greaterThanOrEqualTo(4));
    });

    test('sad: droops ±3° and 2 px', () {
      final f = period(CompanionMood.sad);
      expect(range(f.map((f) => f.turn)), greaterThanOrEqualTo(6 - 1e-9));
      expect(range(f.map((f) => f.dy)), greaterThanOrEqualTo(2 - 1e-9));
    });

    test('sleep: breathes to 1.05 in Y, twice per loop', () {
      final f = period(CompanionMood.sleep);
      expect(f.map((f) => f.scaleY).reduce(math.max), greaterThan(1.045));
      // 3.6 s breaths in a 7.2 s loop: still at 0 and 50 %.
      expect(f[0].scaleY, closeTo(1, 1e-9));
      expect(f[50].scaleY, closeTo(1, 1e-9));
    });

    test('the hop and float ambients (X05, V13)', () {
      expect(
          period(CompanionMood.idle, ambient: CompanionAmbient.hop)
              .map((f) => f.dy)
              .reduce(math.min),
          lessThanOrEqualTo(-16 + 1e-9));
      expect(
          range(period(CompanionMood.idle, ambient: CompanionAmbient.float)
              .map((f) => f.dy)),
          greaterThanOrEqualTo(8 - 1e-6));
      expect(
          period(CompanionMood.wave, ambient: CompanionAmbient.none)
              .every((f) => f.dy == 0 && f.turn == 0),
          isTrue);
    });

    test(
        'distances never shrink below the board\'s points on a small '
        'companion', () {
      final small = period(CompanionMood.idle, size: 44);
      expect(range(small.map((f) => f.dy)), greaterThanOrEqualTo(6));
    });
  });

  group('the loop really runs in the widget', () {
    setUp(() => AppMotion.loopsEnabled = true);
    tearDown(() => AppMotion.loopsEnabled = false);

    Future<void> pump(WidgetTester tester, CompanionMood mood,
        {bool reduce = false,
        CompanionAmbient ambient = CompanionAmbient.mood}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Center(
              child: CompanionView(
                  hero: Avatar.fox, mood: mood, size: 110, ambient: ambient)),
        ),
      ));
    }

    Matrix4 body(WidgetTester tester) =>
        tester.widget<Transform>(find.byKey(CompanionView.bodyKey)).transform;
    double lift(Matrix4 m) => m.getTranslation().y;
    double turn(Matrix4 m) =>
        math.atan2(m.entry(1, 0), m.entry(0, 0)) * 180 / math.pi;

    /// The body's lift and turn sampled every 50 ms over one period.
    Future<(List<double>, List<double>)> sample(
        WidgetTester tester, CompanionMood mood,
        [CompanionAmbient ambient = CompanionAmbient.mood]) async {
      final ms = CompanionView.periodOf(mood, ambient).inMilliseconds;
      final lifts = <double>[], turns = <double>[];
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        lifts.add(lift(body(tester)));
        turns.add(turn(body(tester)));
      }
      return (lifts, turns);
    }

    testWidgets('idle floats', (tester) async {
      await pump(tester, CompanionMood.idle);
      final (lifts, _) = await sample(tester, CompanionMood.idle);
      // Measured at the transform's origin, the scale adds a little.
      expect(range(lifts), greaterThan(5.5));
    });

    testWidgets('wave sways', (tester) async {
      await pump(tester, CompanionMood.wave);
      final (_, turns) = await sample(tester, CompanionMood.wave);
      expect(turns.reduce(math.min), lessThan(-6));
      expect(turns.reduce(math.max), greaterThan(5));
    });

    testWidgets('cheer hops again every loop', (tester) async {
      await pump(tester, CompanionMood.cheer);
      await sample(tester, CompanionMood.cheer); // the first loop
      final (lifts, _) = await sample(tester, CompanionMood.cheer);
      expect(lifts.reduce(math.min), lessThan(-14));
    });

    testWidgets('think and inspect tilt', (tester) async {
      await pump(tester, CompanionMood.think);
      final (_, think) = await sample(tester, CompanionMood.think);
      expect(think.reduce(math.min), lessThan(-5.5));
      await pump(tester, CompanionMood.inspect);
      final (_, inspect) = await sample(tester, CompanionMood.inspect);
      expect(range(inspect), greaterThan(7.5));
    });

    testWidgets('sleep breathes and its Zzz rises and fades', (tester) async {
      await pump(tester, CompanionMood.sleep);
      final tops = <double>[];
      final opacities = <double>[];
      var maxScale = 1.0;
      for (var t = 0; t < 2400; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
        tops.add(tester.getTopLeft(find.byKey(CompanionView.propKey)).dy);
        opacities.add(tester
            .widget<Opacity>(find.descendant(
                of: find.byKey(CompanionView.propKey),
                matching: find.byType(Opacity)))
            .opacity);
        maxScale = math.max(maxScale, body(tester).entry(1, 1));
      }
      expect(range(tops), greaterThan(25));
      expect(opacities.reduce(math.max), greaterThan(.9));
      expect(opacities.reduce(math.min), lessThan(.1));
      expect(maxScale, greaterThan(1.04));
    });

    testWidgets('the hop and float ambients run', (tester) async {
      await pump(tester, CompanionMood.idle, ambient: CompanionAmbient.hop);
      final (hop, _) =
          await sample(tester, CompanionMood.idle, CompanionAmbient.hop);
      expect(hop.reduce(math.min), lessThan(-15));
      await pump(tester, CompanionMood.idle, ambient: CompanionAmbient.float);
      final (float, _) =
          await sample(tester, CompanionMood.idle, CompanionAmbient.float);
      expect(range(float), greaterThan(7.5));
    });

    testWidgets('still under Reduce Motion, every mood', (tester) async {
      for (final mood in CompanionMood.values) {
        await pump(tester, mood, reduce: true);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 400));
          expect(body(tester).isIdentity(), isTrue, reason: '$mood');
        }
      }
    });
  });

  test(
      '(a) the loops are on in debug, profile and release: only the test '
      'config switches them off', () {
    // `AppMotion.loopsEnabled` is a plain `static bool = true`; no build
    // mode check exists, and nothing in lib/ assigns it.
    final writers = [
      for (final f in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart')))
        if (RegExp(r'loopsEnabled\s*=').hasMatch(f.readAsStringSync())) f.path
    ];
    expect(writers, ['lib/motion.dart']);
    expect(File('lib/motion.dart').readAsStringSync(),
        contains('static bool loopsEnabled = true;'));
    expect(File('lib/motion.dart').readAsStringSync(),
        isNot(contains('kReleaseMode')));
  });
}
