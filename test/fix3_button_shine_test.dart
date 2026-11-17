import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

import 'support/fix3_render.dart';

/// Fix round 3, B4 (SPEC §3.2, v11): the shine is a diagonal band the full
/// height of the button, 38 % of its width, skewed −20°, white 0 → 50 % →
/// 0, clipped to the button; it travels from −140 % to +320 % of its own
/// width in the first 55 % of the loop. One implementation for every
/// shining button. On the device it was a small square: the band was laid
/// out in the label's box.
void main() {
  setUp(() => AppMotion.loopsEnabled = true);
  tearDown(() => AppMotion.loopsEnabled = false);

  Future<void> pumpButton(WidgetTester tester, {required String label}) async {
    await pumpFix3(
        tester,
        Scaffold(
          body: Center(
            child: SizedBox(
              width: 342,
              child: PressableButton(
                label: label,
                tone: ButtonTone.orange,
                shine: true,
                onPressed: () {},
              ),
            ),
          ),
        ),
        settle: false);
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final label in ['Continue', 'Take my first step']) {
    testWidgets('"$label": the band is the whole face\'s height, 38 % wide',
        (tester) async {
      await pumpButton(tester, label: label);
      final face = tester.getRect(find.byType(PressableButton));
      final layer = tester.getRect(find.byKey(PressableButton.shineKey));
      // The layer covers the whole face (not the label's box).
      expect(layer.width, closeTo(face.width, .5));
      expect(layer.height, greaterThanOrEqualTo(48));
      final shine = find.descendant(
          of: find.byKey(PressableButton.shineKey),
          matching: find.byType(Positioned));
      final band = tester.widget<Positioned>(shine.first);
      expect(band.width, closeTo(layer.width * ButtonShine.widthShare, .01));
      expect(band.top, 0);
      expect(band.bottom, 0);
      final skew = tester.widget<Transform>(find.descendant(
          of: find.byKey(PressableButton.shineKey),
          matching: find.byType(Transform)).first);
      expect(skew.transform.entry(0, 1),
          closeTo(math.tan(-20 * math.pi / 180), 1e-9));
      final box = tester.widget<DecoratedBox>(find.descendant(
          of: find.byKey(PressableButton.shineKey),
          matching: find.byType(DecoratedBox)).first);
      final colors = (box.decoration as BoxDecoration).gradient!.colors;
      expect(colors.map((c) => c.a), [0, .5, 0]);
      await fix3Capture(tester, 'B4-shine-${label.replaceAll(' ', '-')}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  test('the sweep: −140 % to +320 % of the band in the first 55 %', () {
    const w = 342.0;
    const band = w * .38;
    expect(ButtonShine.leftAt(0, w), closeTo(-1.4 * band, 1e-9));
    expect(ButtonShine.leftAt(.55, w), closeTo(3.2 * band, 1e-9));
    expect(ButtonShine.leftAt(.9, w), closeTo(3.2 * band, 1e-9));
    expect(ButtonShine.leftAt(.275, w), closeTo(.9 * band, 1e-9));
  });
}
