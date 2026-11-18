import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/widgets/centered_scroll.dart';
import 'package:grammar_lens/widgets/practice_preparing.dart';
import 'package:grammar_lens/widgets/practice_reviewing.dart';

import 'support/fix3_render.dart';

/// Fix round 4, item 7 (SPEC V20 v12, §1.26): the loading screens centre
/// their content in the space under the header; V20's checklist is honest
/// (the first two items tick on their timers, the last stays in progress
/// until the result arrives and ticks with it); the lens stays inside the
/// scan window over the answer cards. With `FIX4_CAPTURE=1` the renders go
/// to `build/fix4-captures/(dark/)`.
void main() {
  const answers = [
    'This is the best pizza in town.',
    'Mount Everest is a highest mountain.',
    'It was the easiest test I’ve taken.',
  ];

  // The space under the practice screen's header on a 390 × 844 phone.
  Widget host(Widget child) => Scaffold(
        body: Column(children: [
          const SizedBox(height: 120),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: child,
            ),
          ),
        ]),
      );

  Finder stepIcon(int i, Key key) => find.descendant(
      of: find.byKey(PracticeReviewing.stepKey(i)), matching: find.byKey(key));

  testWidgets('V20: before the result the last item stays in progress',
      (tester) async {
    await pumpFix3(
        tester,
        host(const PracticeReviewing(
            topic: 'Articles', answers: answers, hero: Avatar.fox)),
        settle: false);
    await tester.pump(const Duration(milliseconds: 100));
    // At first nothing has ticked; nothing is in progress yet.
    expect(stepIcon(0, PracticeReviewing.tickedKey), findsNothing);
    await tester.pump(PracticeReviewing.tick * 2 + AppMotionFast.wait);
    expect(stepIcon(0, PracticeReviewing.tickedKey), findsOneWidget);
    expect(stepIcon(1, PracticeReviewing.tickedKey), findsOneWidget);
    expect(stepIcon(2, PracticeReviewing.tickedKey), findsNothing);
    expect(stepIcon(2, PracticeReviewing.waitingKey), findsOneWidget);
    // However long the wait.
    await tester.pump(const Duration(seconds: 20));
    expect(stepIcon(2, PracticeReviewing.tickedKey), findsNothing);
    expect(stepIcon(2, PracticeReviewing.waitingKey), findsOneWidget);
    await fix4Capture(tester, 'V20-reviewing-waiting');
  });

  testWidgets('V20: when the result arrives the last item ticks',
      (tester) async {
    await pumpFix3(
        tester,
        host(const PracticeReviewing(
            topic: 'Articles', answers: answers, hero: Avatar.fox)),
        settle: false);
    await tester.pump(PracticeReviewing.tick * 2 + AppMotionFast.wait);
    await pumpFix3(
        tester,
        host(const PracticeReviewing(
            topic: 'Articles', answers: answers, hero: Avatar.fox, done: true)),
        settle: false);
    await tester.pump(AppMotionFast.wait);
    for (var i = 0; i < 3; i++) {
      expect(stepIcon(i, PracticeReviewing.tickedKey), findsOneWidget,
          reason: '$i');
    }
    expect(find.byKey(PracticeReviewing.waitingKey), findsNothing);
  });

  testWidgets('V20 under Reduce Motion: two ticked, the last waiting', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpFix3(
        tester,
        host(const PracticeReviewing(
            topic: 'Articles', answers: answers, hero: Avatar.fox)));
    expect(stepIcon(1, PracticeReviewing.tickedKey), findsOneWidget);
    expect(stepIcon(2, PracticeReviewing.waitingKey), findsOneWidget);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'V20 and V18: centred in the space under the header '
        '(${brightness.name})', (tester) async {
      const box = Rect.fromLTRB(16, 120, 374, 844);
      for (final (name, widget) in [
        (
          'V20-reviewing',
          const PracticeReviewing(
              topic: 'Articles', answers: answers, hero: Avatar.fox),
        ),
        (
          'V18-preparing',
          PracticePreparing(
              topic: kTopics.first,
              hero: Avatar.fox,
              questionCount: 5,
              message: 'Preparing 5 questions on Articles…'),
        ),
      ]) {
        await pumpFix3(tester, host(widget),
            brightness: brightness, settle: false);
        await tester.pump(const Duration(seconds: 3));
        final content = tester.getRect(find.byKey(CenteredScroll.contentKey));
        expect(content.height, lessThan(box.height), reason: name);
        // Centred, give or take the scroll padding's difference.
        expect(content.center.dy, closeTo(box.center.dy, 8), reason: name);
        // Past the ticks' switch-over.
        await tester.pump(const Duration(milliseconds: 500));
        await fix4Capture(tester, name, dark: brightness == Brightness.dark);
      }
    });
  }

  testWidgets('V20: the lens stays inside the scan window and the cards',
      (tester) async {
    // The sweep is an ambient loop (off in tests unless switched on).
    AppMotion.loopsEnabled = true;
    addTearDown(() => AppMotion.loopsEnabled = false);
    await pumpFix3(
        tester,
        host(const PracticeReviewing(
            topic: 'Articles', answers: answers, hero: Avatar.fox)),
        settle: false);
    for (var i = 0; i < 16; i++) {
      await tester.pump(PracticeReviewing.sweep ~/ 8);
      final window = tester.getRect(find.byKey(PracticeReviewing.windowKey));
      final lens = tester.getRect(find.byKey(PracticeReviewing.lensKey));
      expect(window.contains(lens.topLeft), isTrue, reason: '$i');
      expect(window.contains(lens.bottomRight - const Offset(.1, .1)), isTrue,
          reason: '$i');
    }
  });
}

/// A beat longer than a switcher's fade (AppMotion.fast).
abstract final class AppMotionFast {
  static const wait = Duration(milliseconds: 400);
}
