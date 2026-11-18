import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/haptics.dart';
import 'package:grammar_lens/widgets/buddy_picker.dart';
import 'package:grammar_lens/widgets/companion_view.dart';
import 'package:grammar_lens/widgets/name_companion_stage.dart';
import 'package:grammar_lens/widgets/pressable_button.dart';
import 'package:grammar_lens/widgets/thinking_dots.dart';

import 'support/fix3_render.dart';

/// Fix round 3, C2 (SPEC V04 v11, storyboard V04s): the name screen's
/// companion asks (wave, "Hi! What should I call you?"), listens while the
/// name is typed (inspect, three dots) and greets 700 ms after the last key
/// when the name is valid (cheer, one hop, three sparkles, "Nice to meet
/// you, <name>!", a green tick, a light haptic once per name). Typing again
/// listens; clearing asks. With `FIX3_CAPTURE=1` the three states render to
/// `build/fix3-captures/` (light and dark).
final _field = find.byKey(OnboardingScreen.nameFieldKey);
final _tick = find.byKey(OnboardingScreen.nameTickKey);

CompanionMood _mood(WidgetTester tester) => tester
    .widget<CompanionView>(find.descendant(
        of: find.byKey(OnboardingScreen.nameStageKey),
        matching: find.byType(CompanionView)))
    .mood;

String _counter(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(OnboardingScreen.nameCounterKey)).data!;

bool _canContinue(WidgetTester tester) =>
    tester
        .widget<PressableButton>(find.byKey(OnboardingScreen.continueKey))
        .onPressed !=
    null;

int _lights() => HapticMap.log!.where((h) => h == 'light').length;

Finder _bubbleText(String text) => find.descendant(
    of: find.byKey(OnboardingScreen.nameStageKey),
    matching: find.text(text, findRichText: true));

Future<void> _toName(WidgetTester tester,
    {Brightness brightness = Brightness.light}) async {
  await pumpFix3(tester, OnboardingScreen(onComplete: (_) {}),
      size: const Size(390, 844), brightness: brightness);
  await tester.tap(find.byKey(BuddyPicker.confirmKey));
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(_field, text);
  await tester.pump();
}

void main() {
  setUp(() => HapticMap.log = []);

  testWidgets('asks → listens → greets → listens → asks, with the timing',
      (tester) async {
    await _toName(tester);
    // Asks: wave, the question, Continue disabled, 0/40.
    expect(_mood(tester), CompanionMood.wave);
    expect(_bubbleText('Hi! What should I call you?'), findsOneWidget);
    expect(_counter(tester), '0/40');
    expect(_canContinue(tester), isFalse);
    expect(_tick, findsNothing);

    // Listens: inspect, three dots, Continue active, 2/40.
    await _type(tester, 'Ad');
    expect(_mood(tester), CompanionMood.inspect);
    expect(
        find.descendant(
            of: find.byKey(OnboardingScreen.nameStageKey),
            matching: find.byType(ThinkingDots)),
        findsOneWidget);
    expect(_counter(tester), '2/40');
    expect(_canContinue(tester), isTrue);

    // Not yet at 650 ms.
    await tester.pump(const Duration(milliseconds: 650));
    expect(_mood(tester), CompanionMood.inspect);
    expect(_lights(), 0);

    // Greets at 700 ms: cheer, the name, the tick, sparkles, one haptic.
    await tester.pump(const Duration(milliseconds: 60));
    expect(_mood(tester), CompanionMood.cheer);
    expect(_bubbleText('Nice to meet you, Ad!'), findsOneWidget);
    expect(_tick, findsOneWidget);
    for (var i = 0; i < 3; i++) {
      expect(find.byKey(NameCompanionStage.sparkleKey(i)), findsOneWidget);
    }
    expect(_lights(), 1);
    await tester.pumpAndSettle();

    // Typing again listens at once; the tick goes.
    await _type(tester, 'Ada');
    expect(_mood(tester), CompanionMood.inspect);
    expect(_tick, findsNothing);
    expect(find.byKey(NameCompanionStage.sparkleKey(0)), findsNothing);
    await tester.pump(OnboardingScreen.greetDelay);
    expect(_bubbleText('Nice to meet you, Ada!'), findsOneWidget);
    expect(_lights(), 2, reason: 'a new name: one more haptic');

    // Back to a name already greeted: greeted, no second haptic.
    await _type(tester, 'Ad');
    await tester.pump(OnboardingScreen.greetDelay);
    expect(_mood(tester), CompanionMood.cheer);
    expect(_lights(), 2, reason: 'once per name');

    // Clearing asks again.
    await _type(tester, '');
    expect(_mood(tester), CompanionMood.wave);
    expect(_bubbleText('Hi! What should I call you?'), findsOneWidget);
    expect(_canContinue(tester), isFalse);
    await tester.pumpAndSettle();
  });

  testWidgets('spaces only: still asks, no greeting, Continue disabled',
      (tester) async {
    await _toName(tester);
    await _type(tester, '   ');
    await tester.pump(OnboardingScreen.greetDelay * 2);
    expect(_mood(tester), CompanionMood.wave);
    expect(_canContinue(tester), isFalse);
    expect(_lights(), 0);
  });

  testWidgets(
      'a long name: 16 characters and "…" in the bubble, whole in the field',
      (tester) async {
    await _toName(tester);
    await _type(tester, 'Maximiliana Alexandrina');
    await tester.pump(OnboardingScreen.greetDelay);
    expect(_bubbleText('Nice to meet you, Maximiliana Alex…!'), findsOneWidget);
    expect(tester.widget<TextField>(_field).controller!.text,
        'Maximiliana Alexandrina');
    expect(_counter(tester), '23/40');
    await tester.pumpAndSettle();
  });

  testWidgets(
      'the board\'s layout: the companion 142 pt and centred, the bubble '
      'centred above it, the field under it', (tester) async {
    await _toName(tester);
    await _type(tester, 'Ada');
    await tester.pump(OnboardingScreen.greetDelay);
    await tester.pumpAndSettle();
    final companion = tester.getRect(find.descendant(
        of: find.byKey(OnboardingScreen.nameStageKey),
        matching: find.byType(CompanionView)));
    final bubble = tester.getRect(find.byKey(NameCompanionStage.bubbleKey));
    final field = tester.getRect(_field);
    expect(companion.size, const Size.square(142));
    expect(companion.center.dx, closeTo(195, .5));
    expect(bubble.center.dx, closeTo(195, .5));
    expect(bubble.bottom, lessThan(companion.top));
    expect(companion.top - bubble.bottom,
        closeTo(NameCompanionStage.bubbleGap, .5));
    expect(field.top, greaterThan(companion.bottom));
    // The glow is centred under the companion.
    final glow = tester.getRect(find.byKey(NameCompanionStage.glowKey));
    expect(glow.center.dx, closeTo(195, .5));
    expect(glow.center.dy - companion.center.dy,
        closeTo(NameCompanionStage.glowDrop, .5));
  });

  for (final b in Brightness.values) {
    testWidgets('captures: the three states (${b.name})', (tester) async {
      await _toName(tester, brightness: b);
      final dark = b == Brightness.dark;
      await fix3Capture(tester, 'V04-asks', dark: dark);
      await _type(tester, 'Ad');
      await tester.pump(const Duration(milliseconds: 400));
      await fix3Capture(tester, 'V04-listens', dark: dark);
      await _type(tester, 'Ada');
      await tester.pump(OnboardingScreen.greetDelay);
      await tester.pumpAndSettle();
      await fix3Capture(tester, 'V04-greets', dark: dark);
    });
  }

  // The new strings fit the bubble at the largest text size in every
  // interface language, a 16-character name included.
  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('${locale.languageCode}: the bubble fits at the largest text',
        (tester) async {
      await loadFix3Fonts();
      tester.view.physicalSize = const Size(375, 667) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final stage in NameStage.values) {
        await tester.pumpWidget(MaterialApp(
          locale: locale,
          theme: buildAppTheme(Brightness.light, textSize: AppTextSize.large),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.fromLTRB(16, 80, 16, 0),
              child: NameCompanionStage(
                hero: Avatar.fox,
                stage: stage,
                name: 'Wwwwwwwwwwwwwwwwwwww',
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$locale $stage');
        final bubble = tester.getRect(find.byKey(NameCompanionStage.bubbleKey));
        expect(bubble.left, greaterThanOrEqualTo(16 - .5));
        expect(bubble.right, lessThanOrEqualTo(375 - 16 + .5));
        // At most three lines of the 18 pt text.
        expect(bubble.height, lessThan(3 * 18 * 1.3 * 1.3 + 24 + 8));
      }
    });
  }
}
