import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// `MonthlyMountain.onMotionEnd`: the pawn has finished moving to a new
/// position. Home uses it to open the first-day paywall after the climb.
void main() {
  late ValueNotifier<({int steps, int days})> state;
  late int ended;

  setUp(() {
    ended = 0;
    state = ValueNotifier((steps: 3, days: 31));
  });

  Future<void> pumpMountain(
    WidgetTester tester, {
    bool reduceMotion = false,
  }) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(
        body: ValueListenableBuilder(
          valueListenable: state,
          builder: (context, value, _) => MonthlyMountain(
            days: value.days,
            completedDays: value.steps,
            avatar: Avatar.values.first,
            onMotionEnd: () => ended++,
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('nothing is reported for the position it mounts at',
      (tester) async {
    await pumpMountain(tester);
    await tester.pump(const Duration(seconds: 3));

    expect(ended, 0);
  });

  testWidgets('a step is reported once, when the animation ends and not before',
      (tester) async {
    await pumpMountain(tester);

    state.value = (steps: 4, days: 31);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(ended, 0, reason: 'still moving at 0.8 s (the animation is 0.85 s)');

    await tester.pump(const Duration(milliseconds: 100));
    expect(ended, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(ended, 1);
  });

  testWidgets('a rebuild with the same position reports nothing',
      (tester) async {
    await pumpMountain(tester);

    state.value = (steps: 3, days: 31);
    await tester.pump(const Duration(seconds: 2));

    expect(ended, 0);
  });

  testWidgets(
      'reduced motion: reported once, right after the frame, with no '
      'animation to wait for', (tester) async {
    await pumpMountain(tester, reduceMotion: true);

    state.value = (steps: 4, days: 31);
    await tester.pump();
    await tester.pump();

    expect(ended, 1);
    await tester.pump(const Duration(seconds: 2));
    expect(ended, 1);
  });

  testWidgets(
      'a step that interrupts another is the one reported: one report in '
      'total, after the second animation', (tester) async {
    await pumpMountain(tester);

    state.value = (steps: 4, days: 31);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    state.value = (steps: 5, days: 31);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(ended, 0, reason: 'the first animation was cancelled, not finished');

    await tester.pump(const Duration(milliseconds: 400));
    expect(ended, 1);
  });

  testWidgets('a new month length jumps without animating, and is reported',
      (tester) async {
    await pumpMountain(tester);

    state.value = (steps: 0, days: 30);
    await tester.pump();
    await tester.pump();

    expect(ended, 1);
  });

  testWidgets('leaving mid-animation reports nothing and throws nothing',
      (tester) async {
    await pumpMountain(tester);
    state.value = (steps: 4, days: 31);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));

    expect(ended, 0);
    expect(tester.takeException(), isNull);
  });

  group('hop (design decision D8)', () {
    final route = ClimbRoute(31);
    const tile = MonthlyMountain.avatarTile;
    const hop = MonthlyMountain.hopShare * tile;

    /// The avatar's `top` in the image (the layer the camera moves), and
    /// the `top` it has standing on the trail at [day] with no hop.
    double avatarTop(WidgetTester tester) => tester
        .widget<Positioned>(find
            .ancestor(
                of: find.byType(AvatarTile), matching: find.byType(Positioned))
            .first)
        .top!;
    double standingTop(double day, double width) =>
        route.pointAt(day).dy * ClimbCamera(width).scale - tile * 55 / 58;

    double width(WidgetTester tester) =>
        tester.getSize(find.byType(MonthlyMountain)).width;

    testWidgets(
        'the pawn is a hop up halfway through a step, on the trail at '
        'both ends', (tester) async {
      await pumpMountain(tester);
      final w = width(tester);
      expect(avatarTop(tester), closeTo(standingTop(3, w), .01));

      state.value = (steps: 4, days: 31);
      await tester.pump();
      // easeInOut is symmetric: at half the time, half the step.
      await tester.pump(const Duration(milliseconds: 425));
      expect(avatarTop(tester), closeTo(standingTop(3.5, w) - hop, .05));

      await tester.pump(const Duration(milliseconds: 500));
      expect(avatarTop(tester), closeTo(standingTop(4, w), .01));
    });

    testWidgets('a move that interrupts another still lands on its step',
        (tester) async {
      await pumpMountain(tester);
      state.value = (steps: 4, days: 31);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      state.value = (steps: 5, days: 31);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(avatarTop(tester), closeTo(standingTop(5, width(tester)), .01));
    });

    testWidgets(
        'Reduce Motion: no hop; the pawn appears on its new step at '
        'once', (tester) async {
      await pumpMountain(tester, reduceMotion: true);
      await tester.pumpAndSettle();
      final w = width(tester);

      state.value = (steps: 4, days: 31);
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(avatarTop(tester), closeTo(standingTop(4, w), .01));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(avatarTop(tester), closeTo(standingTop(4, w), .01));
      }
    });
  });
}
