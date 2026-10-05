import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/theme_preview_screen.dart';
import 'package:grammar_lens/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shows the destructive swatches ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(390, 3000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        home: const ThemePreviewScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('destructive'), findsOneWidget);
      expect(find.text('onDestructive'), findsOneWidget);
    });
  }

  testWidgets(
      'the font weight table: 200-900, FontWeight / FontVariation / both '
      '(1.2.0 Batch 5, H1)', (tester) async {
    tester.view.physicalSize = const Size(390, 3000) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const ThemePreviewScreen(),
    ));
    await tester.pumpAndSettle();

    final table = find.byType(Table);
    expect(table, findsOneWidget);
    for (final header in ['FontWeight', 'FontVariation', 'Both']) {
      expect(find.descendant(of: table, matching: find.text(header)),
          findsOneWidget);
    }
    final samples = tester
        .widgetList<Text>(
            find.descendant(of: table, matching: find.text('GrammarLens')))
        .toList();
    expect(samples, hasLength(6 * 3));
    // Row by row: weight only, axis only, both — the same weight value.
    for (var row = 0; row < 6; row++) {
      final weightOnly = samples[row * 3].style!;
      final axisOnly = samples[row * 3 + 1].style!;
      final both = samples[row * 3 + 2].style!;
      expect(weightOnly.fontVariations, isNull);
      expect(axisOnly.fontWeight, isNull);
      expect(axisOnly.fontVariations!.single.value,
          weightOnly.fontWeight!.value.toDouble());
      expect(both.fontWeight, weightOnly.fontWeight);
      expect(both.fontVariations, axisOnly.fontVariations);
    }
    expect(tester.takeException(), isNull);
  });
}
