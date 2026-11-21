import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/screens/getting_ready_screen.dart';

import 'support/fix3_render.dart';

/// Fix round 3, B2: V05b's bar as on its board: a 26 pt striped fill, 28 pt
/// stop circles that turn into green ticks, the last one 16 pt from the
/// end with the flag's pole standing on it.
void main() {
  for (final brightness in Brightness.values) {
    testWidgets('B2: the bar\'s geometry (${brightness.name})', (tester) async {
      final third = Completer<void>();
      await pumpFix3(
          tester,
          GettingReadyScreen(
            name: 'Ada',
            hero: Avatar.fox,
            goal: LearningGoal.work,
            monthName: 'November',
            mountainName: 'Ember Peak',
            steps: 30,
            questionsPerDay: 5,
            tasks: [() async {}, () async {}, () => third.future],
            onDone: () {},
          ),
          brightness: brightness,
          settle: false);
      // Two stops done; the third waits.
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final fill = tester.getRect(find.byKey(const ValueKey('ready_bar_fill')));
      expect(fill.height, 26);
      final stops = [
        for (var i = 0; i < 3; i++)
          tester.getRect(find.byKey(ValueKey('ready_bar_stop_$i')))
      ];
      for (final s in stops) {
        expect(s.width, 28);
        expect(s.center.dy, closeTo(fill.center.dy, .5));
      }
      expect(stops[0].center.dx - fill.left, closeTo(fill.width / 3, 1.5));
      expect(stops[1].center.dx - fill.left, closeTo(fill.width * 2 / 3, 1.5));
      expect(fill.right - stops[2].center.dx, closeTo(16, .5));
      // The pole stands on the last stop, the pennant at its top.
      final pole = tester.getRect(find.byKey(const ValueKey('ready_bar_pole')));
      expect(pole.center.dx, closeTo(stops[2].center.dx, .5));
      expect(pole.bottom, closeTo(fill.top + 1, .5));
      final pennant =
          tester.getRect(find.byKey(const ValueKey('ready_bar_pennant')));
      expect(pennant.left, closeTo(stops[2].center.dx, .5));
      expect(pennant.top, lessThan(pole.top + 6));
      // Two green ticks, one pending.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2 + 2));
      await fix3Capture(tester, 'V05b-GettingReady',
          dark: brightness == Brightness.dark);
      third.complete();
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
