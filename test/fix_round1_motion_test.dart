import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/topic_hint_card.dart';

/// UI polish fix round 1: the motion details the first run left out (SPEC
/// §5 motion notes). Ambient loops are off in tests
/// (`test/flutter_test_config.dart`); the loop tests here turn them on.
void main() {
  Future<void> pumpIn(WidgetTester tester, Widget child,
      {bool reduceMotion = false,
      TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = const Size(402, 874) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    if (reduceMotion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Directionality(
        textDirection: direction,
        child: Scaffold(
          body: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ));
  }

  group('V07: the hint knob nudges every 2.8 s', () {
    setUp(() => AppMotion.loopsEnabled = true);
    tearDown(() => AppMotion.loopsEnabled = false);

    test('the board\'s keyframes', () {
      expect(TopicHintSlider.nudgeAt(0), 0);
      expect(TopicHintSlider.nudgeAt(.59), 0);
      expect(TopicHintSlider.nudgeAt(.75), closeTo(12, .001));
      expect(TopicHintSlider.nudgeAt(.88), closeTo(4, .001));
      expect(TopicHintSlider.nudgeAt(.999), closeTo(0, .01));
    });

    double knobShift(WidgetTester tester) => tester
        .widget<Transform>(find
            .descendant(
                of: find.byKey(TopicHintSlider.knobKey),
                matching: find.byType(Transform))
            .first)
        .transform
        .getTranslation()
        .x;

    final slider = TopicHintSlider(
        topic: kTopics.first, points: const ['One.', 'Two.', 'Three.']);

    for (final direction in TextDirection.values) {
      testWidgets('towards the track\'s end ($direction)', (tester) async {
        await pumpIn(tester, slider, direction: direction);
        expect(knobShift(tester), 0);
        await tester.pump(const Duration(milliseconds: 2100)); // 75 %
        expect(knobShift(tester).abs(), closeTo(12, .5));
        expect(knobShift(tester).sign, direction == TextDirection.ltr ? 1 : -1);
        await tester.pump(const Duration(milliseconds: 700)); // 100 %
        expect(knobShift(tester).abs(), lessThan(.5));
        // It repeats.
        await tester.pump(const Duration(milliseconds: 2100));
        expect(knobShift(tester).abs(), closeTo(12, .5));
      });
    }

    testWidgets('not under Reduce Motion', (tester) async {
      await pumpIn(tester, slider, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 2100));
      expect(knobShift(tester), 0);
    });
  });
}
