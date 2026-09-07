import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/screens/practice_length_picker.dart';

/// Captures the eventual result of one `showPracticeLengthPicker` call so a
/// test can open the sheet, interact with it, then assert on what the
/// picker's Future resolved with once it closes.
class _PickerHarness {
  PracticeLength? result;
  bool resolved = false;
}

Future<_PickerHarness> _openPicker(
  WidgetTester tester, {
  required PracticeLength initial,
}) async {
  final harness = _PickerHarness();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async {
              harness.result = await showPracticeLengthPicker(
                context: context,
                initial: initial,
              );
              harness.resolved = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return harness;
}

void main() {
  testWidgets('opens with the given initial length pre-selected',
      (tester) async {
    await _openPicker(tester, initial: PracticeLength.extended);

    expect(find.text('How many questions?'), findsOneWidget);
    // The big number in the selection card and its entry in the 3/5/10
    // label row both read "10".
    expect(find.text('10'), findsNWidgets(2));
    expect(find.text('Extended'), findsOneWidget);
    expect(find.text('A deep, thorough workout'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Start 10 questions'),
      findsOneWidget,
    );
  });

  testWidgets(
      'dragging the slider updates the preview and confirms that length on Start',
      (tester) async {
    final harness =
        await _openPicker(tester, initial: PracticeLength.standard);

    // Directly invoking the bound onChanged callback is the reliable way
    // to drive a Slider in a widget test — simulating an exact drag
    // distance via `tester.drag()` is fragile by comparison and this
    // exercises the same state-update path either way.
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0); // Quick
    await tester.pumpAndSettle();

    expect(find.text('Quick'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Start 3 questions'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Start 3 questions'));
    await tester.pumpAndSettle();

    expect(harness.resolved, isTrue);
    expect(harness.result, PracticeLength.quick);
  });

  testWidgets('dismissing without confirming resolves null', (tester) async {
    final harness =
        await _openPicker(tester, initial: PracticeLength.standard);

    // showModalBottomSheet is dismissible by default — tapping the scrim,
    // well outside the sheet's own bounds, closes it without a value.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(harness.resolved, isTrue);
    expect(harness.result, isNull);
  });

  testWidgets('changing the slider stop fires a selection-click haptic once',
      (tester) async {
    final hapticCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') hapticCalls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _openPicker(tester, initial: PracticeLength.standard);

    tester.widget<Slider>(find.byType(Slider)).onChanged!(2); // -> Extended
    await tester.pump();
    expect(hapticCalls, hasLength(1));

    // Re-reporting the same stop is not a change and must not re-fire it.
    tester.widget<Slider>(find.byType(Slider)).onChanged!(2);
    await tester.pump();
    expect(hapticCalls, hasLength(1));
  });

  testWidgets('semanticFormatterCallback reports the count and name',
      (tester) async {
    await _openPicker(tester, initial: PracticeLength.standard);
    final slider = tester.widget<Slider>(find.byType(Slider));

    expect(slider.semanticFormatterCallback!(0), '3 questions, Quick');
    expect(slider.semanticFormatterCallback!(1), '5 questions, Standard');
    expect(slider.semanticFormatterCallback!(2), '10 questions, Extended');
  });

  testWidgets('reduced motion skips the selection-card transitions',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _openPicker(tester, initial: PracticeLength.standard);

    // Two independent AnimatedSwitchers now: the name/description text,
    // and the dial's own centered count (kept outside the dial's ring
    // animation so the ring can tween continuously — see _LengthDial).
    for (final key in ['lengthTextSwitcher', 'lengthNumberSwitcher']) {
      final switcher =
          tester.widget<AnimatedSwitcher>(find.byKey(Key(key)));
      expect(switcher.duration, Duration.zero, reason: key);
    }
  });

  testWidgets(
      'normal motion animates the selection-card transitions over 180ms',
      (tester) async {
    await _openPicker(tester, initial: PracticeLength.standard);

    for (final key in ['lengthTextSwitcher', 'lengthNumberSwitcher']) {
      final switcher =
          tester.widget<AnimatedSwitcher>(find.byKey(Key(key)));
      expect(
        switcher.duration,
        const Duration(milliseconds: 180),
        reason: key,
      );
    }
  });

  testWidgets(
      'each length label sits centered under its actual slider stop '
      '(regression: labels used to be laid out across the full row width '
      'while the slider track is inset by its thumb radius, so only the '
      'middle stop lined up by coincidence of symmetry)', (tester) async {
    await _openPicker(tester, initial: PracticeLength.standard);

    final sliderFinder = find.byType(Slider);
    final sliderTopLeft = tester.getTopLeft(sliderFinder);
    final sliderRenderBox = tester.renderObject<RenderBox>(sliderFinder);
    final sliderThemeData =
        tester.widget<SliderTheme>(find.byType(SliderTheme)).data;

    // The exact track-shape class and SliderThemeData the widget itself
    // renders with — this measures the real inset Flutter computes for
    // this slider, rather than assuming a number.
    final trackShape = sliderThemeData.trackShape!;
    final trackRect = trackShape.getPreferredRect(
      parentBox: sliderRenderBox,
      sliderTheme: sliderThemeData,
      isEnabled: true,
      isDiscrete: true,
    );

    final expectedStopX = [
      sliderTopLeft.dx + trackRect.left,
      sliderTopLeft.dx + (trackRect.left + trackRect.right) / 2,
      sliderTopLeft.dx + trackRect.right,
    ];

    for (var i = 0; i < PracticeLength.values.length; i++) {
      final length = PracticeLength.values[i];
      // Keyed rather than found by text: the label row also contains an
      // invisible same-styled sizer Text that can share a value ("10")
      // with a real label, which would otherwise make `find.text` matches
      // ambiguous.
      final labelCenter = tester.getCenter(
        find.byKey(ValueKey('lengthLabel_${length.name}')),
      );
      expect(
        labelCenter.dx,
        closeTo(expectedStopX[i], 1.0),
        reason:
            '${length.label} label should sit under its slider stop, not '
            'wherever the full-width row happens to place it',
      );
    }
  });

  group('practiceLengthDialRatio', () {
    test('is each length\'s question count over the largest one, not a '
        'hand-written constant', () {
      final maxCount = PracticeLength.values
          .map((length) => length.questionCount)
          .reduce((a, b) => a > b ? a : b);

      for (final length in PracticeLength.values) {
        expect(
          practiceLengthDialRatio(length),
          length.questionCount / maxCount,
        );
      }
    });

    test('the longest option always fills the dial completely', () {
      final longest = PracticeLength.values
          .reduce((a, b) => a.questionCount > b.questionCount ? a : b);
      expect(practiceLengthDialRatio(longest), 1.0);
    });
  });

  testWidgets('the selection card paints a dial (not just a plain number)',
      (tester) async {
    await _openPicker(tester, initial: PracticeLength.standard);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
