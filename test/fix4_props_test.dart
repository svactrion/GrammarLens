import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/widgets/companion_head_table.dart';
import 'package:grammar_lens/widgets/companion_view.dart';

import 'support/fix3_render.dart';

/// Fix round 4, item 5 (SPEC §3.5 v12): every prop is placed by the head of
/// the image it is drawn on (a head box measured from the image's pixels,
/// `tool/scene_art/companion_heads.py`), mirrored in RTL. With
/// `FIX4_CAPTURE=1` the contact sheet (the nine heroes × the five props,
/// light and dark, and Arabic) goes to `build/fix4-captures/`.
void main() {
  const propMoods = [
    CompanionMood.oops,
    CompanionMood.think,
    CompanionMood.sad,
    CompanionMood.sleep,
    CompanionMood.cheer,
  ];
  const poses = ['wave', 'cheer', 'think', 'inspect', 'sad', 'sleep'];

  test('every hero × pose image has a head box, inside the image', () {
    for (final hero in Avatar.values) {
      for (final asset in [
        hero.assetPath,
        for (final pose in poses) hero.posePath(pose),
      ]) {
        final box = CompanionView.headBoxOf(asset);
        expect(box, isNotNull, reason: asset);
        expect(box!.left, greaterThanOrEqualTo(0), reason: asset);
        expect(box.top, greaterThanOrEqualTo(0), reason: asset);
        expect(box.right, lessThanOrEqualTo(1), reason: asset);
        expect(box.bottom, lessThanOrEqualTo(1), reason: asset);
        // A head, not a sliver: at least a fifth of the image each way.
        expect(box.width, greaterThan(.2), reason: asset);
        expect(box.height, greaterThan(.12), reason: asset);
      }
    }
    expect(companionHeadBox, hasLength(Avatar.values.length * 7));
  });

  test('every hero × prop has a table entry and a place by the head', () {
    const size = 110.0;
    for (final hero in Avatar.values) {
      for (final mood in propMoods) {
        final asset = CompanionView.assetFor(hero, mood);
        final head = CompanionView.headBoxOf(asset);
        expect(head, isNotNull, reason: '$hero $mood');
        final h = Rect.fromLTRB(head!.left * size, head.top * size,
            head.right * size, head.bottom * size);
        final rect = CompanionView.propRectFor(asset, mood, size: size)!;
        switch (mood) {
          case CompanionMood.oops:
            // The drop starts at the temple: inside the head's right half.
            expect(h.contains(rect.center), isTrue, reason: '$hero');
            expect(rect.center.dx, greaterThan(h.center.dx), reason: '$hero');
          case CompanionMood.think || CompanionMood.sad:
            // Just above the head's top right.
            expect(rect.bottom, closeTo(h.top, .25 * h.height),
                reason: '$hero $mood');
            expect(rect.center.dx, greaterThan(h.center.dx),
                reason: '$hero $mood');
          case CompanionMood.sleep:
            expect(rect.bottom, closeTo(h.top, .25 * h.height),
                reason: '$hero');
            expect(rect.right, greaterThan(h.center.dx), reason: '$hero');
          case CompanionMood.cheer:
            // Beside the head, level with its upper half.
            expect(rect.left, greaterThan(h.center.dx), reason: '$hero');
            expect(rect.top, lessThan(h.center.dy), reason: '$hero');
          default:
            break;
        }
        // RTL: the same place mirrored about the head's middle.
        final mirrored =
            CompanionView.propRectFor(asset, mood, size: size, rtl: true)!;
        expect(mirrored.center.dx - h.center.dx,
            closeTo(h.center.dx - rect.center.dx, .01),
            reason: '$hero $mood RTL');
        expect(mirrored.top, rect.top);
      }
    }
  });

  test('the device case: the giraffe\'s sweat drop starts at its head', () {
    const size = 110.0;
    final asset = CompanionView.assetFor(Avatar.giraffe, CompanionMood.oops);
    final head = CompanionView.headBoxOf(asset)!;
    final drop =
        CompanionView.propRectFor(asset, CompanionMood.oops, size: size)!;
    // Before: the box's corner (92, 4), above and right of the head.
    const before = Rect.fromLTWH(92, 4, 28, 28);
    final h = Rect.fromLTRB(head.left * size, head.top * size,
        head.right * size, head.bottom * size);
    expect(h.contains(before.center), isFalse);
    expect(h.contains(drop.center), isTrue);
  });

  for (final (name, brightness, locale) in [
    ('light', Brightness.light, null),
    ('dark', Brightness.dark, null),
    ('arabic', Brightness.light, const Locale('ar')),
  ]) {
    testWidgets('the contact sheet: nine heroes × five props ($name)',
        (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      const cell = 110.0;
      await pumpFix3(
          tester,
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
              child: Column(children: [
                for (final hero in Avatar.values)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final mood in propMoods)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 30, 14, 4),
                        child: CompanionView(
                            hero: hero, mood: mood, size: cell * .7),
                      ),
                  ]),
              ]),
            ),
          ),
          size: const Size(620, 1100),
          top: 0,
          bottom: 0,
          brightness: brightness,
          locale: locale);
      expect(tester.takeException(), isNull);
      expect(find.byKey(CompanionView.propKey),
          findsNWidgets(Avatar.values.length * propMoods.length));
      await fix4Capture(
          tester, 'props-contact-sheet${name == 'arabic' ? '-ar' : ''}',
          dark: brightness == Brightness.dark);
    });
  }
}
