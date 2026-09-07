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

  testWidgets('reduced motion skips the selection-card transition',
      (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await _openPicker(tester, initial: PracticeLength.standard);

    final switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.duration, Duration.zero);
  });

  testWidgets('normal motion animates the selection-card transition over 180ms',
      (tester) async {
    await _openPicker(tester, initial: PracticeLength.standard);

    final switcher =
        tester.widget<AnimatedSwitcher>(find.byType(AnimatedSwitcher));
    expect(switcher.duration, const Duration(milliseconds: 180));
  });
}
