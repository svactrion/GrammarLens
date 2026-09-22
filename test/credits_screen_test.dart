import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/credits_screen.dart';
import 'package:grammar_lens/widgets/legal_link.dart';

void main() {
  Future<void> pumpCredits(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3.0;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: CreditsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the attribution sentence word for word', (tester) async {
    await pumpCredits(tester);

    expect(
      find.text(
        'Avatar illustrations adapted from "Cute Animal 3D Icons" by Tran Mau '
        'Tri Tam, via Figma Community '
        '(https://www.figma.com/community/file/1514963172455082116/cute-animal-3d-icons), '
        'licensed under CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).',
      ),
      findsOneWidget,
    );
  });

  testWidgets('names the publisher and the licence', (tester) async {
    await pumpCredits(tester);

    final text =
        tester.widget<Text>(find.textContaining('Avatar illustrations'));
    expect(text.data, contains('Tran Mau Tri Tam'));
    expect(text.data, contains('CC BY 4.0'));
  });

  testWidgets('offers a link button for the Figma file and one for the licence',
      (tester) async {
    await pumpCredits(tester);

    final links = tester.widgetList<LegalLink>(find.byType(LegalLink)).toList();
    expect(links.map((l) => l.label), ['Figma file', 'CC BY 4.0 license']);
    expect(links.every((l) => l.url.startsWith('https://')), isTrue);
    // Live, not the disabled state an empty URL gets.
    final buttons = tester.widgetList<TextButton>(find.byType(TextButton));
    expect(buttons.every((b) => b.onPressed != null), isTrue);
  });

  testWidgets('fits at 320 pt wide with the largest text size', (tester) async {
    tester.view.physicalSize = const Size(320, 640) * 2.0;
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: const CreditsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
