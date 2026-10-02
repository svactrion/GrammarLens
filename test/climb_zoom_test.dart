import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_zoom.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// Batch 6 (M6, M11, M16): the zoom from the whole mountain (K-c) to the
/// daily framing.
void main() {
  group('ClimbOverview (K-c)', () {
    test('the whole image fitted to the window\'s height, centred', () {
      expect(ClimbOverview.scale, closeTo(262.5, .01));
      expect(ClimbOverview.band(341.25), closeTo(39.4, .05));
      expect(ClimbOverview.band(288), closeTo(12.75, .01));
    });

    test(
        't = 1 is the daily framing; t = 0 puts every point where K-c '
        'draws it', () {
      const camera = ClimbCamera(341.25);
      final route = ClimbRoute(30);
      final offset = camera.offsetFor(route.pointAt(0));
      expect(ClimbOverview.transform(camera, offset, 1), Matrix4.identity());
      for (final p in [
        route.pointAt(0),
        route.pointAt(15),
        ClimbRoute.summit
      ]) {
        final daily = camera.toWindow(p, offset);
        final kc = p * ClimbOverview.scale +
            Offset(ClimbOverview.band(camera.width), 0);
        final mapped = MatrixUtils.transformPoint(
            ClimbOverview.transform(camera, offset, 0), daily);
        expect(mapped.dx, closeTo(kc.dx, 1e-6));
        expect(mapped.dy, closeTo(kc.dy, 1e-6));
      }
    });
  });

  group('ClimbZoomController', () {
    test('the named defaults', () {
      expect(ClimbZoomController.duration, const Duration(milliseconds: 1800));
      expect(ClimbZoomController.pause, const Duration(milliseconds: 300));
    });

    Future<ClimbZoomOutcome?> runIn(
        WidgetTester tester, ClimbZoomController zoom,
        {bool reduceMotion = false,
        bool claimed = true,
        void Function()? after}) async {
      ClimbZoomOutcome? outcome;
      var done = false;
      zoom
          .run(
              trigger: ClimbZoomTrigger.monthChange,
              reduceMotion: reduceMotion,
              claim: () async => claimed)
          .then((o) {
        outcome = o;
        done = true;
      });
      await tester.pump();
      after?.call();
      for (var i = 0; i < 200 && !done; i++) {
        await tester.pump(const Duration(milliseconds: 25));
      }
      expect(done, isTrue);
      expect(zoom.active, isFalse);
      expect(zoom.progress.value, 1);
      return outcome;
    }

    testWidgets('plays after the pause and completes', (tester) async {
      final zoom = ClimbZoomController(vsync: tester);
      addTearDown(zoom.dispose);
      zoom.hold(ClimbZoomTrigger.monthChange);
      expect((zoom.active, zoom.progress.value), (true, 0.0));
      final start = tester.binding.clock.now();
      expect(await runIn(tester, zoom), ClimbZoomOutcome.completed);
      expect(tester.binding.clock.now().difference(start),
          greaterThanOrEqualTo(const Duration(milliseconds: 2100)));
    });

    testWidgets('a skip ends it at once', (tester) async {
      final zoom = ClimbZoomController(vsync: tester);
      addTearDown(zoom.dispose);
      expect(await runIn(tester, zoom, after: zoom.skip),
          ClimbZoomOutcome.skipped);
    });

    testWidgets('opening the Daily Test ends it at once, as its own outcome',
        (tester) async {
      final zoom = ClimbZoomController(vsync: tester);
      addTearDown(zoom.dispose);
      expect(await runIn(tester, zoom, after: zoom.dailyTestOpened),
          ClimbZoomOutcome.dailyTestOpened);
    });

    testWidgets('Reduce Motion: a short cross-fade', (tester) async {
      final zoom = ClimbZoomController(vsync: tester);
      addTearDown(zoom.dispose);
      final start = tester.binding.clock.now();
      expect(await runIn(tester, zoom, reduceMotion: true),
          ClimbZoomOutcome.reduceMotion);
      expect(tester.binding.clock.now().difference(start),
          lessThan(const Duration(milliseconds: 700)));
    });

    testWidgets(
        'already played (the claim fails): no run, the daily '
        'framing, a null outcome', (tester) async {
      final zoom = ClimbZoomController(vsync: tester);
      addTearDown(zoom.dispose);
      expect(await runIn(tester, zoom, claimed: false), isNull);
    });

    testWidgets('dispose ends a run: a chain waiting on it goes on',
        (tester) async {
      final zoom = ClimbZoomController(vsync: tester);
      var done = false;
      zoom
          .run(
              trigger: ClimbZoomTrigger.firstRun,
              reduceMotion: false,
              claim: () async => true)
          .then((_) => done = true);
      await tester.pump();
      zoom.dispose();
      await tester.pump();
      expect(done, isTrue);
    });
  });

  group('the scene during a zoom', () {
    Widget scene(Animation<double>? zoom,
            {bool crossFade = false, ClimbTheme? theme}) =>
        MaterialApp(
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            body: SizedBox(
              width: 341.25,
              child: MonthlyMountain(
                days: 30,
                completedDays: 0,
                avatar: Avatar.values.first,
                theme: theme ?? ClimbThemes.emberPeak,
                zoom: zoom,
                zoomCrossFade: crossFade,
              ),
            ),
          ),
        );

    testWidgets(
        'only the transform follows the zoom: the scene layer is not '
        'repainted', (tester) async {
      final zoom = AnimationController(vsync: tester, value: 0);
      addTearDown(zoom.dispose);
      await tester.pumpWidget(scene(zoom));
      final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(MonthlyMountain.sceneKey));
      // The boundary's counters: "symmetric" counts the scene painted again
      // together with its parent (what a repaint during the zoom would
      // be); "asymmetric" counts the parent painting around the reused
      // layer, which is what a transform change is.
      final repaints = boundary.debugSymmetricPaintCount;
      final reuses = boundary.debugAsymmetricPaintCount;
      final transforms = <Matrix4>[];
      zoom.duration = const Duration(seconds: 1);
      zoom.forward();
      // The first frame starts it at 0; eleven frames reach 1.
      for (var i = 0; i < 11; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        transforms.add(tester
            .widget<Transform>(find.descendant(
                of: find.byType(MonthlyMountain),
                matching: find.byType(Transform)))
            .transform);
      }
      await tester.pumpAndSettle();
      expect(boundary.debugSymmetricPaintCount, repaints);
      expect(boundary.debugAsymmetricPaintCount, greaterThan(reuses));
      expect(transforms.toSet().length, greaterThan(5));
      expect(transforms.last, Matrix4.identity());
    });

    testWidgets('the window\'s fill is the theme\'s K-c band colour (M11)',
        (tester) async {
      await tester.pumpWidget(scene(kAlwaysDismissedAnimation));
      final fill = tester
          .widget<ColoredBox>(find.descendant(
              of: find.byType(MonthlyMountain),
              matching: find.byType(ColoredBox)))
          .color;
      expect(fill, ClimbThemes.emberPeak.kcBandFor(Brightness.light));
      expect(
          fill, isNot(ClimbThemes.emberPeak.paletteFor(Brightness.light).sky));
    });

    testWidgets(
        'Reduce Motion: no zoom transform moves; the K-c frame fades '
        'out over the daily one', (tester) async {
      final zoom = AnimationController(vsync: tester, value: 0);
      addTearDown(zoom.dispose);
      await tester.pumpWidget(scene(zoom, crossFade: true));
      expect(find.byKey(MonthlyMountain.sceneKey), findsNWidgets(2));
      final fade = tester.widget<FadeTransition>(find.descendant(
          of: find.byType(MonthlyMountain),
          matching: find.byType(FadeTransition)));
      expect(fade.opacity.value, 1);
      zoom.value = 1;
      await tester.pump();
      expect(fade.opacity.value, 0);
    });

    test('every theme has its band colours, both modes', () {
      for (final theme in ClimbThemes.all) {
        expect(theme.kcBandLight, isNotNull, reason: theme.id);
        expect(theme.kcBandDark, isNotNull, reason: theme.id);
      }
    });
  });

  testWidgets('ClimbCard: the chips follow chipOpacity', (tester) async {
    final opacity = AnimationController(vsync: tester, value: 0);
    addTearDown(opacity.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: ClimbCard(
          month: DateTime(2026, 11),
          steps: 0,
          days: 30,
          chipOpacity: opacity,
          mountain: const SizedBox(height: 350),
          scoreBar: const SizedBox(height: 40),
        ),
      ),
    ));
    final chips = tester.widget<FadeTransition>(find.byKey(ClimbCard.chipsKey));
    expect(chips.opacity.value, 0);
    opacity.value = 1;
    expect(chips.opacity.value, 1);
  });
}
