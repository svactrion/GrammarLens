import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';

/// SPEC §3.2 / V00-MotionSystem: 56 high, a 5 px lip; on press it moves
/// down 4 px and the lip shrinks; disabled does nothing.
void main() {
  setUp(() => HapticMap.log = []);

  Future<void> pump(WidgetTester tester, Widget button) => tester
      .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: button))));

  BoxDecoration face(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PressableButton),
        matching: find.byType(AnimatedContainer)));
    return container.decoration! as BoxDecoration;
  }

  testWidgets('is 56 high plus its lip, and calls back on tap', (tester) async {
    var taps = 0;
    await pump(
        tester, PressableButton(label: 'Start', onPressed: () => taps++));
    expect(tester.getSize(find.byType(PressableButton)).height, 56 + 5);
    await tester.tap(find.text('Start'));
    expect(taps, 1);
    expect(HapticMap.log, ['medium']);
  });

  testWidgets('moves down 4 px and the lip shrinks while pressed',
      (tester) async {
    await pump(tester, PressableButton(label: 'Go', onPressed: () {}));
    expect(face(tester).boxShadow!.single.offset.dy, PressableButton.lip);
    final gesture =
        await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        face(tester).boxShadow!.single.offset.dy, PressableButton.pressedLip);
    final container = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PressableButton),
        matching: find.byType(AnimatedContainer)));
    expect(container.transform!.getTranslation().y, PressableButton.travel);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    expect(face(tester).boxShadow!.single.offset.dy, PressableButton.lip);
  });

  testWidgets('disabled: no callback, no haptic, marked disabled',
      (tester) async {
    await pump(tester, const PressableButton(label: 'Wait', onPressed: null));
    await tester.tap(find.text('Wait'), warnIfMissed: false);
    expect(HapticMap.log, isEmpty);
    final node = tester.getSemantics(find.bySemanticsLabel('Wait'));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
  });

  testWidgets('busy shows dots instead of the label and ignores taps',
      (tester) async {
    var taps = 0;
    await pump(
        tester,
        PressableButton(
            label: 'Try again', busy: true, onPressed: () => taps++));
    expect(find.text('Try again'), findsNothing);
    await tester.tap(find.byType(PressableButton));
    expect(taps, 0);
  });

  testWidgets('each tone keeps the same size', (tester) async {
    for (final tone in ButtonTone.values) {
      await pump(
          tester, PressableButton(label: 'Same', tone: tone, onPressed: () {}));
      final flat = tone == ButtonTone.text || tone == ButtonTone.danger;
      expect(
          tester.getSize(find.byType(PressableButton)).height, flat ? 56 : 61);
    }
  });
}
