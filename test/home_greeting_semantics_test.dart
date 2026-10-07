import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/home_greeting.dart';

/// VoiceOver reads the greeting as one sentence, "Good morning, Charlotte",
/// whether it is laid out on one line or on two.
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  Future<void> pumpGreeting(WidgetTester tester, double width) async {
    final theme = buildAppTheme(Brightness.light);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: HomeGreeting(
              word: 'Good morning',
              name: 'Charlotte',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ));
  }

  // 216 pt is the greeting's width on a 320 pt screen (two lines); 400 pt
  // holds it on one.
  for (final (width, lines) in [(216.0, 2), (400.0, 1)]) {
    testWidgets('$lines line(s) at $width pt: one node, the whole greeting',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpGreeting(tester, width);
      expect(
          find.descendant(
              of: find.byType(HomeGreeting), matching: find.byType(RichText)),
          findsNWidgets(lines));

      expect(find.bySemanticsLabel('Good morning, Charlotte'), findsOneWidget);
      expect(tester.getSemantics(find.byType(HomeGreeting)).label,
          'Good morning, Charlotte');
      // Not read as parts.
      expect(find.bySemanticsLabel('Good morning,'), findsNothing);
      expect(find.bySemanticsLabel('Charlotte'), findsNothing);
      semantics.dispose();
    });
  }

  testWidgets('an empty name is read as the greeting word alone',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: HomeGreeting(word: 'Good evening', name: ''))));
    expect(
        tester.getSemantics(find.byType(HomeGreeting)).label, 'Good evening');
    semantics.dispose();
  });
}
