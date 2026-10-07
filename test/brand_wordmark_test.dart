import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/welcome_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/brand_wordmark.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

/// The two-colour wordmark (owner decision, 2026-10-05): "Grammar" in the
/// text colour, "Lens" brandOrange, in every build.
void main() {
  const style = TextStyle(fontSize: 34, letterSpacing: -1.4);

  Future<void> pump(WidgetTester tester, Brightness brightness,
      {required Widget child}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness),
      home: Scaffold(body: Center(child: child)),
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
        '"Grammar" keeps the text colour, "Lens" is brandOrange, in '
        '${brightness.name}; same width as one colour; read as one word',
        (tester) async {
      final theme = buildAppTheme(brightness);
      final textStyle = style.copyWith(color: theme.colorScheme.onSurface);
      await pump(tester, brightness,
          child: Text(BrandWordmark.text, style: textStyle));
      final plainWidth = tester.getSize(find.byType(RichText)).width;

      await pump(tester, brightness,
          child: BrandWordmark(style: textStyle));
      final root = paragraph(tester).text as TextSpan;
      final spans = leaves(tester);
      expect(root.toPlainText(), 'GrammarLens');
      expect(spans.map((s) => s.text), ['Grammar', 'Lens']);
      expect(root.style!.color, theme.colorScheme.onSurface);
      expect(spans[0].style, isNull, reason: 'inherits the text colour');
      expect(spans[1].style!.color, theme.colorScheme.primary);
      expect(
          spans[1].style!.color,
          brightness == Brightness.dark
              ? const Color(0xFFFF8A3D)
              : const Color(0xFFFF7A1A));
      expect(spans[1].style!.fontSize, isNull);
      expect(spans[1].style!.fontWeight, isNull);
      expect(spans[1].style!.letterSpacing, isNull);
      expect(root.style!.fontSize, 34);
      expect(root.style!.letterSpacing, -1.4);
      expect(tester.getSize(find.byType(RichText)).width,
          closeTo(plainWidth, 0.01));
      expect(find.bySemanticsLabel('GrammarLens'), findsOneWidget);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets(
        'the launch screen\'s wordmark is two colours in ${brightness.name}',
        (tester) async {
      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(
            size: const Size(390, 844), platformBrightness: brightness),
        child: const LaunchSplash(),
      ));
      await tester.pump(LaunchTiming.intro);
      final spans = leaves(tester);
      expect(spans.map((s) => s.text), ['Grammar', 'Lens']);
      expect(spans[1].style!.color,
          buildAppTheme(brightness).colorScheme.primary);
      expect((paragraph(tester).text as TextSpan).style!.color,
          buildAppTheme(brightness).colorScheme.onSurface);
    });
  }

  testWidgets(
      'the launch screen\'s wordmark has Home\'s weight, wght and letter '
      'spacing ratio (final pass, owner)', (tester) async {
    final home = buildAppTheme(Brightness.light)
        .textTheme
        .displaySmall!
        .copyWith(letterSpacing: -1.4);
    await tester.pumpWidget(const MediaQuery(
      data: MediaQueryData(size: Size(390, 844)),
      child: LaunchSplash(),
    ));
    await tester.pump(LaunchTiming.intro);
    final splash = (paragraph(tester).text as TextSpan).style!;
    expect(splash.fontWeight, home.fontWeight);
    expect(splash.fontWeight, FontWeight.w900);
    expect(splash.fontVariations, home.fontVariations);
    // Home's ratio at the brief's 34 pt: -1.4 / 34.
    expect(splash.letterSpacing! / splash.fontSize!,
        closeTo(-1.4 / 34, 0.0001));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'Welcome (owner, 2026-10-06): two colours on the page colour in '
        'dark mode, one colour on the brand orange in light mode '
        '(${brightness.name})', (tester) async {
      final theme = buildAppTheme(brightness);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: const MediaQueryData(
              size: Size(390, 844), disableAnimations: true),
          child: WelcomeScreen(onGetStarted: () {}),
        ),
      ));
      await tester.pump(const Duration(seconds: 2));
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      if (brightness == Brightness.dark) {
        expect(scaffold.backgroundColor, const Color(0xFF151517));
        expect(leaves(tester).map((s) => s.text), ['Grammar', 'Lens']);
        expect(leaves(tester)[1].style!.color, theme.colorScheme.primary);
      } else {
        expect(scaffold.backgroundColor, theme.colorScheme.primary);
        expect(find.byType(BrandWordmark), findsNothing);
        expect(find.text('GrammarLens'), findsOneWidget);
      }
    });
  }

  test(
      'every on-screen "GrammarLens" goes through BrandWordmark, except '
      'Welcome and the theme preview\'s font sample', () {
    const allowed = {
      'lib/widgets/brand_wordmark.dart', // the widget itself
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
      'lib/widgets/launch_splash.dart',
    ]) {
      expect(File(file).readAsStringSync(), contains('BrandWordmark('),
          reason: file);
    }
  });
}
