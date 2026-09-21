import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';

void main() {
  destructiveColorTests();

  test('light and dark themes use bundled Nunito Sans throughout', () {
    for (final brightness in Brightness.values) {
      final theme = buildAppTheme(brightness);
      expect(theme.textTheme.bodyMedium?.fontFamily, 'NunitoSans');
      expect(theme.textTheme.titleLarge?.fontFamily, 'NunitoSans');
      expect(theme.textTheme.labelLarge?.fontFamily, 'NunitoSans');
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, 'NunitoSans');
      expect(theme.filledButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
          'NunitoSans');
    }
  });

  testWidgets('Turkish and English sample characters render without errors',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const Scaffold(
        body: Text('GrammarLens — İ ı Ş ş Ğ ğ Ç ç Ö ö Ü ü'),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('GrammarLens — İ ı Ş ş Ğ ğ Ç ç Ö ö Ü ü'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('small, medium and large produce an ordered type scale', () {
    double bodySize(AppTextSize size) => buildAppTheme(
          Brightness.light,
          textSize: size,
        ).textTheme.bodyMedium!.fontSize!;

    expect(bodySize(AppTextSize.small), lessThan(bodySize(AppTextSize.medium)));
    expect(bodySize(AppTextSize.medium), lessThan(bodySize(AppTextSize.large)));
  });
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance(), l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void destructiveColorTests() {
  group('destructive colors', () {
    test('are the same red with white text in both themes', () {
      final light = buildAppTheme(Brightness.light).colorScheme;
      final dark = buildAppTheme(Brightness.dark).colorScheme;

      expect(light.destructive, const Color(0xFFDC3232));
      expect(light.onDestructive, const Color(0xFFFFFFFF));
      expect(dark.destructive, light.destructive);
      expect(dark.onDestructive, light.onDestructive);
    });

    test('keep the measured contrast in both themes', () {
      for (final brightness in Brightness.values) {
        final s = buildAppTheme(brightness).colorScheme;
        // Text on the fill: AA for normal text (16 px semi-bold is not
        // "large"). Measured 4.62.
        expect(_contrast(s.onDestructive, s.destructive),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness text');
        // Fill against the dialog surface and the page body: 3:1 for UI
        // components. Measured 3.08 (dark) / 3.67 (light) and 3.71 / 4.20.
        expect(_contrast(s.destructive, s.surfaceContainerHigh),
            greaterThanOrEqualTo(3.0),
            reason: '$brightness vs dialog');
        expect(_contrast(s.destructive, s.surfaceContainerLow),
            greaterThanOrEqualTo(3.0),
            reason: '$brightness vs body');
      }
    });

    test('are distinct from the semantic error roles', () {
      for (final brightness in Brightness.values) {
        final s = buildAppTheme(brightness).colorScheme;
        expect(s.destructive, isNot(s.error));
        expect(s.destructive, isNot(s.errorContainer));
      }
    });
  });
}
