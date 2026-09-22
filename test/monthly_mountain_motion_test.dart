import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';
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
}
