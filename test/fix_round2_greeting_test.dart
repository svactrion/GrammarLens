import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/home_greeting.dart';

/// Fix round 2, item 10: on the owner's phone the name dropped to a second
/// line; V14 / V15 draw one line, "Good evening, Ada" with the name bold.
/// The greeting stays on one line; if it does not fit it scales down (not
/// below [HomeGreeting.minScale]) instead of wrapping. Measured in the
/// app's font, in all 8 languages, with a 20-character name, at Home's
/// width (the page's 20 pt sides).
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  const name20 = 'Maximiliana Johanson';
  assert(name20.length == 20);

  Future<RenderParagraph> pumpGreeting(WidgetTester tester,
      {required Locale locale,
      required double screenWidth,
      AppTextSize textSize = AppTextSize.medium,
      String name = name20,
      int hour = 15}) async {
    tester.view.physicalSize = Size(screenWidth, 900) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      theme: buildAppTheme(Brightness.light, textSize: textSize),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(builder: (context) {
          final l10n = context.l10n;
          final theme = Theme.of(context);
          // Home's greeting, as built in HomeScreen (the afternoon word is
          // the longest in English).
          final word = hour < 12
              ? l10n.greetingMorning
              : hour < 18
                  ? l10n.greetingAfternoon
                  : l10n.greetingEvening;
          final size =
              theme.textTheme.titleLarge!.fontSize! * HomeScreen.greetingScale;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: HomeGreeting(
              word: word,
              name: name,
              withName: l10n.greetingWithName(word, l10n.greetingName(name)),
              addressedName: l10n.greetingName(name),
              lead: l10n.greetingLead(word),
              style: theme.textTheme.titleLarge!
                  .withWeight(FontWeight.w500)
                  .copyWith(fontSize: size),
              nameStyle: theme.textTheme.titleLarge!
                  .withWeight(FontWeight.w900)
                  .copyWith(fontSize: size),
            ),
          );
        }),
      ),
    ));
    await tester.pumpAndSettle();
    return tester
        .renderObject<RenderParagraph>(find.byKey(HomeGreeting.lineKey));
  }

  double shownSize(WidgetTester tester) =>
      (tester.widget<Text>(find.byKey(HomeGreeting.lineKey)).textSpan!
              as TextSpan)
          .style!
          .fontSize!;

  for (final locale in AppLocalizations.supportedLocales) {
    for (final width in [428.0, 390.0]) {
      testWidgets(
          '${locale.toLanguageTag()} at ${width.toInt()} pt: a 20-character '
          'name, one line, the whole name shown', (tester) async {
        final line =
            await pumpGreeting(tester, locale: locale, screenWidth: width);
        expect(tester.takeException(), isNull);
        expect(line.didExceedMaxLines, isFalse, reason: 'nothing cut with "…"');
        final size = shownSize(tester);
        // One line high.
        expect(tester.getSize(find.byKey(HomeGreeting.lineKey)).height,
            lessThan(size * 1.7));
        expect(tester.getRect(find.byKey(HomeGreeting.lineKey)).right,
            lessThanOrEqualTo(width - 20 + .5));
        // The name is bold inside the line.
        final spans = (tester
                .widget<Text>(find.byKey(HomeGreeting.lineKey))
                .textSpan! as TextSpan)
            .children!
            .whereType<TextSpan>();
        expect(spans.any((s) => s.text!.contains(name20)), isTrue);
      });
    }
  }

  testWidgets('a short name stays at full size', (tester) async {
    await pumpGreeting(tester,
        locale: const Locale('en'), screenWidth: 428, name: 'Ada', hour: 20);
    expect(find.text('Good evening, Ada'), findsOneWidget);
    final theme = Theme.of(tester.element(find.byKey(HomeGreeting.lineKey)));
    expect(shownSize(tester),
        theme.textTheme.titleLarge!.fontSize! * HomeScreen.greetingScale);
  });

  testWidgets(
      '320 pt, Large text: one line, scaled to no less than 70 %; '
      'past that the end is cut and VoiceOver still reads it all',
      (tester) async {
    final line = await pumpGreeting(tester,
        locale: const Locale('en'),
        screenWidth: 320,
        textSize: AppTextSize.large,
        name: 'Maximiliana Alexandra Konstantinopoulou');
    expect(tester.takeException(), isNull);
    final theme = Theme.of(tester.element(find.byKey(HomeGreeting.lineKey)));
    final full =
        theme.textTheme.titleLarge!.fontSize! * HomeScreen.greetingScale;
    expect(shownSize(tester), closeTo(full * HomeGreeting.minScale, .01));
    expect(line.didExceedMaxLines, isTrue);
    expect(tester.getSize(find.byKey(HomeGreeting.lineKey)).height,
        lessThan(full * 1.7));
    expect(
        find.bySemanticsLabel(
            'Good afternoon, Maximiliana Alexandra Konstantinopoulou'),
        findsOneWidget);
  });
}
