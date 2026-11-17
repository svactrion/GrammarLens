import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/first_climb_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_zoom.dart';
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';
import 'package:grammar_lens/widgets/rest_scene.dart';

/// UI polish B5 (SPEC §5.2): the first climb's camera (V12) and the rest
/// scene's countdown (V24).
void main() {
  setUp(() => HapticMap.log = []);

  Future<List<ClimbZoomOutcome>> pumpClimb(WidgetTester tester,
      {bool reduceMotion = false, VoidCallback? onContinue}) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final ended = <ClimbZoomOutcome>[];
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: FirstClimbScreen(
        theme: ClimbThemes.emberPeak,
        hero: Avatar.fox,
        days: 30,
        onContinue: onContinue ?? () {},
        onCameraEnded: ended.add,
      ),
    ));
    return ended;
  }

  MountainScene scene(WidgetTester tester) =>
      tester.widget<MountainScene>(find.byType(MountainScene));

  group('V12 first climb', () {
    testWidgets(
        'one camera: wide, 2.2× close for the walk, wide again; the walk '
        'paints the trail and ends on the step', (tester) async {
      final ended = await pumpClimb(tester);
      expect(scene(tester).zoom, 1);
      expect(scene(tester).avatarDay, 0);
      // Mid-walk: the close shot.
      await tester.pump(FirstClimbScreen.hold +
          FirstClimbScreen.zoomIn +
          FirstClimbScreen.walk ~/ 2);
      expect(scene(tester).zoom, closeTo(FirstClimbScreen.closeZoom, .001));
      expect(scene(tester).avatarDay, closeTo(.5, .01));
      expect(scene(tester).trailPaint, closeTo(.5, .01));
      expect(ended, isEmpty);
      // The end: wide again, at the step.
      await tester.pump(FirstClimbScreen.total);
      expect(scene(tester).zoom, 1);
      expect(scene(tester).avatarDay, 1);
      expect(scene(tester).trailPaint, 1);
      expect(ended, [ClimbZoomOutcome.completed]);
      await tester.pumpAndSettle();
    });

    testWidgets(
        'the image always covers the screen: no empty band at any frame',
        (tester) async {
      await pumpClimb(tester);
      const box = Size(390, 844);
      for (var ms = 0; ms <= FirstClimbScreen.total.inMilliseconds; ms += 100) {
        final s = scene(tester);
        final map = SceneMap(box, zoom: s.zoom, focus: s.focus);
        final o = map.origin;
        final img = map.imageSize;
        expect(o.dx, lessThanOrEqualTo(0), reason: '$ms ms');
        expect(o.dy, lessThanOrEqualTo(0), reason: '$ms ms');
        expect(o.dx + img.width, greaterThanOrEqualTo(box.width - .01),
            reason: '$ms ms');
        expect(o.dy + img.height, greaterThanOrEqualTo(box.height - .01),
            reason: '$ms ms');
        await tester.pump(const Duration(milliseconds: 100));
      }
      // The wide shot fits the height and crops the sides.
      final wide = SceneMap(box);
      expect(wide.imageSize.height, closeTo(box.height, .01));
      expect(wide.imageSize.width, greaterThan(box.width));
      await tester.pumpAndSettle();
    });

    testWidgets(
        '"Step 1 of 30" pops on arrival with light + success; Continue only '
        'once the camera has opened back up', (tester) async {
      var continued = 0;
      await pumpClimb(tester, onContinue: () => continued++);
      expect(find.text('Step 1 of 30'), findsOneWidget);
      expect(find.text('Ember Peak · 30 steps to the summit'), findsOneWidget);
      // Before the end, a tap on Continue's place skips the camera instead.
      await tester.pump(FirstClimbScreen.hold);
      expect(HapticMap.log, isEmpty);
      await tester.pump(FirstClimbScreen.zoomIn + FirstClimbScreen.walk);
      await tester.pump(const Duration(milliseconds: 20));
      expect(HapticMap.log, ['light', 'success']);
      await tester.pumpAndSettle();
      expect(find.text('First step done! 29 to the summit.'), findsOneWidget);
      await tester.tap(find.byKey(FirstClimbScreen.continueKey));
      expect(continued, 1);
    });

    testWidgets('a tap during the camera jumps to its end: skipped',
        (tester) async {
      final ended = await pumpClimb(tester);
      await tester.pump(const Duration(milliseconds: 800));
      await tester.tap(find.byKey(FirstClimbScreen.sceneKey));
      await tester.pump();
      expect(ended, [ClimbZoomOutcome.skipped]);
      expect(scene(tester).avatarDay, 1);
      expect(scene(tester).zoom, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('Reduce Motion: the end frame at once, no camera',
        (tester) async {
      final ended = await pumpClimb(tester, reduceMotion: true);
      expect(ended, [ClimbZoomOutcome.reduceMotion]);
      expect(scene(tester).zoom, 1);
      expect(scene(tester).avatarDay, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(FirstClimbScreen.continueKey), findsOneWidget);
    });
  });

  group('V24 rest scene', () {
    test('the countdown runs to local midnight', () {
      expect(timeToMidnight(DateTime(2026, 11, 17, 13, 36)),
          const Duration(hours: 10, minutes: 24));
      expect(timeToMidnight(DateTime(2026, 11, 17, 23, 59, 30)),
          const Duration(seconds: 30));
    });

    testWidgets('the countdown updates every minute', (tester) async {
      var now = DateTime(2026, 11, 17, 13, 36);
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Scaffold(
          body: SingleChildScrollView(
            child: RestScene(
              theme: ClimbThemes.emberPeak,
              days: 30,
              steps: 3,
              hero: Avatar.fox,
              name: 'Ada',
              testLine: '4/5 · +9 points',
              practiceLine: 'Ticket used',
              clock: () => now,
            ),
          ),
        ),
      ));
      expect(find.text('10:24'), findsOneWidget);
      expect(find.text('See you tomorrow, Ada'), findsOneWidget);
      expect(find.text('NEXT DAILY TEST · STEP 4'), findsOneWidget);
      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('10:23'), findsOneWidget);
      // No reminder switch on this board (§1.10).
      expect(find.byType(Switch), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
