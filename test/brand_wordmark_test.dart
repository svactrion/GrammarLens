import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/debug_panel_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/debug_tools.dart';
import 'package:grammar_lens/widgets/brand_wordmark.dart';

/// The debug panel's "Two-colour wordmark" trial (owner, 2026-10-05).
void main() {
  tearDown(() {
    DebugTwoColourWordmark.runtime.value = false;
    DebugTools.enabledForTesting = true;
  });

  const style = TextStyle(fontSize: 34, letterSpacing: -1.4);

  Future<void> pump(WidgetTester tester, Brightness brightness) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness),
      home: Scaffold(
        body: Center(
          child: BrandWordmark(
              style: style.copyWith(
                  color: buildAppTheme(brightness).colorScheme.onSurface)),
        ),
      ),
    ));
  }

  RichText paragraph(WidgetTester tester) =>
      tester.widget<RichText>(find.descendant(
          of: find.byType(BrandWordmark), matching: find.byType(RichText)));

  /// The spans that carry text, in order.
  List<TextSpan> leaves(WidgetTester tester) {
    final found = <TextSpan>[];
    paragraph(tester).text.visitChildren((span) {
      if (span is TextSpan && span.text != null) found.add(span);
      return true;
    });
    return found;
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'off (the default): one colour, one span, in ${brightness.name}',
        (tester) async {
      expect(DebugTwoColourWordmark.runtime.value, isFalse);
      await pump(tester, brightness);
      expect(paragraph(tester).text.toPlainText(), 'GrammarLens');
      expect(leaves(tester), hasLength(1));
      expect(find.text('GrammarLens'), findsOneWidget);
    });

    testWidgets(
        'on: "Grammar" keeps the text colour, "Lens" is brandOrange, in '
        '${brightness.name}; same width; read as one word', (tester) async {
      final theme = buildAppTheme(brightness);
      await pump(tester, brightness);
      final width = tester.getSize(find.byType(RichText)).width;

      DebugTwoColourWordmark.runtime.value = true;
      await tester.pump();
      final root = paragraph(tester).text as TextSpan;
      final spans = leaves(tester);
      expect(spans.map((s) => s.text), ['Grammar', 'Lens']);
      expect(root.style!.color, theme.colorScheme.onSurface);
      expect(spans[0].style, isNull, reason: 'inherits the text colour');
      expect(spans[1].style!.color, theme.colorScheme.primary);
      expect(
          spans[1].style!.color,
          brightness == Brightness.dark
              ? const Color(0xFFFF8A3D)
              : const Color(0xFFFF7A1A));
      expect(root.style!.fontSize, 34);
      expect(root.style!.letterSpacing, -1.4);
      expect(tester.getSize(find.byType(RichText)).width, closeTo(width, 0.01));
      expect(find.bySemanticsLabel('GrammarLens'), findsOneWidget);

      // And back, with no rebuild of the screen asked for.
      DebugTwoColourWordmark.runtime.value = false;
      await tester.pump();
      expect(leaves(tester), hasLength(1));
    });
  }

  testWidgets('a release build ignores the switch: one colour', (tester) async {
    DebugTools.enabledForTesting = false;
    DebugTwoColourWordmark.runtime.value = true;
    await pump(tester, Brightness.light);
    expect(DebugTwoColourWordmark.enabled, isFalse);
    expect(leaves(tester), hasLength(1));
  });

  testWidgets(
      'the debug panel switch is off by default and turns it on for a '
      'wordmark already on screen', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(Brightness.light),
      home: Scaffold(
        body: Column(children: [
          const BrandWordmark(style: style),
          Expanded(child: DebugPanelScreen(onResetLocalData: () async {})),
        ]),
      ),
    ));
    final toggle = find.byKey(DebugPanelScreen.twoColourWordmarkKey);
    await tester.scrollUntilVisible(toggle, 200,
        scrollable: find.byType(Scrollable).first);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(leaves(tester), hasLength(1));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    expect(leaves(tester).map((s) => s.text), ['Grammar', 'Lens']);
  });

  test(
      'every on-screen "GrammarLens" goes through BrandWordmark, except the '
      'launch screen, Welcome and the theme preview\'s font sample', () {
    const allowed = {
      'lib/widgets/brand_wordmark.dart', // the widget itself
      'lib/widgets/launch_splash.dart', // unchanged by decision
      'lib/screens/welcome_screen.dart', // orange page in light mode
      'lib/screens/theme_preview_screen.dart', // a font sample
      'lib/app.dart', // MaterialApp.title, not drawn
    };
    final offenders = <String>[];
    for (final file in Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      if (allowed.contains(file.path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].split('//').first;
        if (code.contains("'GrammarLens'")) {
          offenders.add('${file.path}:${i + 1}');
        }
      }
    }
    expect(offenders, isEmpty);
    for (final file in [
      'lib/screens/home_screen.dart',
      'lib/screens/onboarding_screen.dart',
      'lib/screens/premium_screen.dart',
    ]) {
      expect(File(file).readAsStringSync(), contains('BrandWordmark('),
          reason: file);
    }
  });
}
