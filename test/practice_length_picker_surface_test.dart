import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/practice_length.dart';
import 'package:grammar_lens/screens/practice_length_picker.dart';
import 'package:grammar_lens/theme.dart';

/// The length picker after the final pass (final screens A3).
double _luminance(Color c) => c.computeLuminance();
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  Future<void> open(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPracticeLengthPicker(
                context: context, initial: PracticeLength.standard),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        '${brightness.name}: the sheet is the card surface and the empty '
        'track is at least 3:1 against it', (tester) async {
      final theme = buildAppTheme(brightness);
      await open(tester, theme);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, theme.colorScheme.surfaceContainerHigh);
      final slider = tester.widget<SliderTheme>(find
          .ancestor(of: find.byType(Slider), matching: find.byType(SliderTheme))
          .first);
      expect(
          _contrast(slider.data.inactiveTrackColor!,
              theme.colorScheme.surfaceContainerHigh),
          greaterThanOrEqualTo(3));
    });
  }

  testWidgets('the selected length and its line follow the text size setting',
      (tester) async {
    final sizes = <AppTextSize, (double, double)>{};
    for (final size in AppTextSize.values) {
      await open(tester, buildAppTheme(Brightness.light, textSize: size));
      final label = tester.widget<Text>(find.text('Standard'));
      final line = tester.widget<Text>(find.text('The balanced session'));
      sizes[size] = (label.style!.fontSize!, line.style!.fontSize!);
      expect(label.style!.fontWeight, FontWeight.w800);
      Navigator.of(tester.element(find.text('Standard'))).pop();
      await tester.pumpAndSettle();
    }
    expect(
        sizes[AppTextSize.small]!.$1, lessThan(sizes[AppTextSize.medium]!.$1));
    expect(
        sizes[AppTextSize.medium]!.$1, lessThan(sizes[AppTextSize.large]!.$1));
    expect(
        sizes[AppTextSize.small]!.$2, lessThan(sizes[AppTextSize.large]!.$2));
  });
}
