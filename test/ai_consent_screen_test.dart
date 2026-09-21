import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_links.dart';
import 'package:grammar_lens/widgets/legal_link.dart';

void main() {
  // Layout is measured in the real typeface: under the default test font
  // every line is about twice as wide and the measurements would mean nothing.
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  /// Opens the screen from a button so its pop value can be observed.
  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    double systemTextScale = 1,
    void Function(bool?)? onResult,
  }) async {
    tester.view.physicalSize = size * 2.0;
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = systemTextScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const AiConsentScreen()),
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('says what is sent, to whom, why, and what never leaves',
      (tester) async {
    await pumpScreen(tester);

    expect(find.text('Feedback on your answers'), findsOneWidget);
    expect(
        find.text('Topic Practice uses an AI service to check your answers '
            'and explain what to fix.'),
        findsOneWidget);
    expect(find.text('What is sent'), findsOneWidget);
    expect(
        find.text('The answers you type, together with the question each one '
            'responds to. This happens when you finish a practice session.'),
        findsOneWidget);
    expect(find.text('Who receives it'), findsOneWidget);
    expect(
        find.text('Anthropic, the company that makes Claude. Your answers go '
            "through GrammarLens's server to Anthropic's Claude model, which "
            'writes your feedback.'),
        findsOneWidget);
    expect(find.text('What is never sent'), findsOneWidget);
    expect(
        find.text('Your name, your learning goal or your avatar. Daily Test '
            'answers stay on your device.'),
        findsOneWidget);
    expect(
        find.text("Please don't type personal details such as full names, "
            'addresses or contact information into your answers.'),
        findsOneWidget);
    expect(find.text('You can change this any time in Profile → Data.'),
        findsOneWidget);
    expect(find.text('Not now: you can still take the Daily Test.'),
        findsOneWidget);
  });

  testWidgets(
      'makes no claim about how the provider stores or uses the data — that '
      "is the provider's and the privacy policy's to state", (tester) async {
    await pumpScreen(tester);

    final allText = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
        .join(' ')
        .toLowerCase();
    for (final word in [
      'train',
      'retain',
      'retention',
      'store',
      'delete',
      'anonym',
      'encrypt',
      'never used',
    ]) {
      expect(allText, isNot(contains(word)), reason: '"$word" is a claim');
    }
  });

  testWidgets('links to the privacy policy', (tester) async {
    await pumpScreen(tester);

    final link = tester.widget<LegalLink>(find.byType(LegalLink));
    expect(link.label, 'Privacy Policy');
    expect(link.url, AppLinks.privacyPolicyUrl);
    expect(link.url, isNotEmpty);
  });

  testWidgets('"Agree and continue" pops true', (tester) async {
    bool? result;
    var done = false;
    await pumpScreen(tester, onResult: (r) {
      result = r;
      done = true;
    });

    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();

    expect(done, isTrue);
    expect(result, isTrue);
  });

  testWidgets('"Not now" pops false', (tester) async {
    bool? result = true;
    await pumpScreen(tester, onResult: (r) => result = r);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(result, isFalse);
  });

  testWidgets('the back arrow pops null, which callers read as a decline',
      (tester) async {
    bool? result = true;
    await pumpScreen(tester, onResult: (r) => result = r);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  // Both answers stay on the first screen at every supported size: the text
  // scrolls, the buttons are pinned.
  for (final target in [
    (
      name: '375x667 Large',
      size: const Size(375, 667),
      text: AppTextSize.large,
      scale: 1.0
    ),
    (
      name: '375x667 Large, system 1.6x',
      size: const Size(375, 667),
      text: AppTextSize.large,
      scale: 1.6
    ),
    (
      name: '320x568 Large',
      size: const Size(320, 568),
      text: AppTextSize.large,
      scale: 1.0
    ),
    (
      name: '320x568 Large, system 2.0x',
      size: const Size(320, 568),
      text: AppTextSize.large,
      scale: 2.0
    ),
  ]) {
    for (final brightness in Brightness.values) {
      testWidgets(
          'small screen, ${target.name}, $brightness: no overflow, both '
          'buttons and the decline note visible without scrolling, and the '
          'text is reachable', (tester) async {
        await pumpScreen(tester,
            size: target.size,
            brightness: brightness,
            textSize: target.text,
            systemTextScale: target.scale);

        final height = target.size.height;
        for (final finder in [
          find.text('Agree and continue'),
          find.text('Not now'),
          find.text('Not now: you can still take the Daily Test.'),
        ]) {
          final rect = tester.getRect(finder);
          expect(rect.bottom, lessThanOrEqualTo(height));
          expect(rect.top, greaterThanOrEqualTo(0));
        }
        // The pinned footer leaves a readable text area above it.
        final body = tester.getRect(find.byKey(const Key('aiConsentBody')));
        expect(body.height, greaterThan(150));

        // Everything is reachable by scrolling the text area.
        await tester.scrollUntilVisible(
          find.text('Privacy Policy'),
          200,
          scrollable: find.descendant(
              of: find.byKey(const Key('aiConsentBody')),
              matching: find.byType(Scrollable)),
        );
        expect(find.text('Privacy Policy'), findsOneWidget);
      });
    }
  }
}
