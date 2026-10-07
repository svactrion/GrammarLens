import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/screens/credits_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/utils/app_messenger.dart';
import 'package:grammar_lens/widgets/legal_link.dart';
import 'package:grammar_lens/widgets/page_header.dart';

/// Profile → Credits (1.2.0 final screens, brief §4).
void main() {
  tearDown(AppMessenger.clear);

  Future<void> pumpCredits(WidgetTester tester,
      {Size size = const Size(390, 844),
      AppTextSize textSize = AppTextSize.medium,
      Brightness brightness = Brightness.light,
      double systemScale = 1}) async {
    tester.view.physicalSize = size * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(brightness, textSize: textSize),
      scaffoldMessengerKey: AppMessenger.key,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(systemScale)),
        child: child!,
      ),
      home: const CreditsScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the header, "Avatar illustrations" and the attribution: the work, '
      'its author, the source, the adaptation and the licence', (tester) async {
    await pumpCredits(tester);
    expect(find.byType(PageBackButton), findsOneWidget);
    expect(find.text('Credits'), findsOneWidget);
    expect(find.text('Artwork and attribution.'), findsOneWidget);
    expect(find.text('Avatar illustrations'), findsOneWidget);
    expect(find.text(CreditsScreen.avatarAttribution, findRichText: true),
        findsOneWidget);
    for (final part in [
      'Adapted from',
      'Cute Animal 3D Icons',
      'Tran Mau Tri Tam',
      'Figma Community',
      'CC BY 4.0',
    ]) {
      expect(CreditsScreen.avatarAttribution, contains(part));
    }
  });

  testWidgets('no raw URL in the text, no artwork, one card', (tester) async {
    await pumpCredits(tester);
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((t) => t.text.toPlainText());
    expect(texts.where((t) => t.contains('http')), isEmpty);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Card), findsOneWidget);
  });

  testWidgets('two described links with the existing URLs', (tester) async {
    await pumpCredits(tester);
    final links =
        tester.widgetList<LegalLinkRow>(find.byType(LegalLinkRow)).toList();
    expect(links.map((l) => l.label), ['Figma file', 'CC BY 4.0 license']);
    expect(links.map((l) => l.url), [
      'https://www.figma.com/community/file/1514963172455082116/cute-animal-3d-icons',
      'https://creativecommons.org/licenses/by/4.0/',
    ]);
    for (final link in ['Figma file', 'CC BY 4.0 license']) {
      expect(
          tester
              .getSize(find.ancestor(
                  of: find.text(link), matching: find.byType(InkWell)))
              .height,
          greaterThanOrEqualTo(44));
    }
  });

  testWidgets('a link that cannot open says so briefly; the screen stays',
      (tester) async {
    await pumpCredits(tester);
    // No URL launcher in the test binding: opening fails, as it would
    // with no browser to hand the link to.
    await tester.tap(find.text('Figma file'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('Could not open Figma file.'), findsOneWidget);
    expect(find.text('Avatar illustrations'), findsOneWidget);
  });

  for (final width in const [320.0, 360.0, 390.0, 430.0]) {
    for (final size in AppTextSize.values) {
      for (final brightness in Brightness.values) {
        testWidgets(
            '${width.toInt()} pt, ${size.name}, ${brightness.name}: no '
            'overflow', (tester) async {
          await pumpCredits(tester,
              size: Size(width, 844), textSize: size, brightness: brightness);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('320 pt with a 2.0 system text scale: no overflow',
      (tester) async {
    await pumpCredits(tester,
        size: const Size(320, 568),
        textSize: AppTextSize.large,
        systemScale: 2);
    expect(tester.takeException(), isNull);
  });
}
