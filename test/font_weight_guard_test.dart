import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';

/// 1.2.0 Batch 6. On an iOS device `FontWeight` alone does not move the
/// bundled variable font's `wght` axis (the owner's check of the Theme
/// Preview weight table, 2026-10-05), so every weight sets both through
/// `TextStyle.withWeight` (theme.dart). Once the theme carries `wght`, a
/// raw local `fontWeight:` would be drawn at the theme's weight instead —
/// these tests make such an override fail here, not on a device.
void main() {
  test('no raw fontWeight: in lib/ outside withWeight', () {
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final comment = line.indexOf('//');
        final code = comment == -1 ? line : line.substring(0, comment);
        if (!RegExp(r'\bfontWeight\s*:').hasMatch(code)) continue;
        // The helper itself and the Theme Preview's raw samples, each
        // marked on its own line.
        if (line.contains('font-weight-guard:')) continue;
        offenders.add('${file.path}:${i + 1}: ${line.trim()}');
      }
    }
    expect(offenders, isEmpty,
        reason: 'Use style.withWeight(FontWeight.wN) (theme.dart) instead: '
            'a raw weight has no wght and is drawn at the theme\'s.\n'
            '${offenders.join('\n')}');
  });

  test('every text theme style carries the wght of its own weight', () {
    for (final brightness in Brightness.values) {
      for (final size in AppTextSize.values) {
        final theme = buildAppTheme(brightness, textSize: size);
        final styles = <String, TextStyle?>{
          'displayLarge': theme.textTheme.displayLarge,
          'displayMedium': theme.textTheme.displayMedium,
          'displaySmall': theme.textTheme.displaySmall,
          'headlineLarge': theme.textTheme.headlineLarge,
          'headlineMedium': theme.textTheme.headlineMedium,
          'headlineSmall': theme.textTheme.headlineSmall,
          'titleLarge': theme.textTheme.titleLarge,
          'titleMedium': theme.textTheme.titleMedium,
          'titleSmall': theme.textTheme.titleSmall,
          'bodyLarge': theme.textTheme.bodyLarge,
          'bodyMedium': theme.textTheme.bodyMedium,
          'bodySmall': theme.textTheme.bodySmall,
          'labelLarge': theme.textTheme.labelLarge,
          'labelMedium': theme.textTheme.labelMedium,
          'labelSmall': theme.textTheme.labelSmall,
          'appBar title': theme.appBarTheme.titleTextStyle,
        };
        for (final MapEntry(:key, :value) in styles.entries) {
          final reason = '$key, ${brightness.name}, ${size.name}';
          expect(value?.fontWeight, isNotNull, reason: reason);
          expect(value!.fontVariations, wghtFor(value.fontWeight!),
              reason: reason);
        }
      }
    }
  });

  test('withWeight sets the weight and its wght together', () {
    const base = TextStyle(fontSize: 14, fontVariations: [
      FontVariation('wght', 900),
    ]);
    final style = base.withWeight(FontWeight.w600);
    expect(style.fontWeight, FontWeight.w600);
    expect(style.fontVariations, [const FontVariation('wght', 600)]);
    expect(style.fontSize, 14);
  });

  testWidgets(
      'a TextStyle without a weight takes the ambient wght with its weight',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: const Scaffold(
        body: Text('x', style: TextStyle(fontSize: 13)),
      ),
    ));
    final element = tester.element(find.text('x'));
    final resolved = DefaultTextStyle.of(element)
        .style
        .merge(tester.widget<Text>(find.text('x')).style);
    expect(resolved.fontWeight, isNotNull);
    expect(resolved.fontVariations, wghtFor(resolved.fontWeight!));
  });
}
