import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';

void main() {
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
