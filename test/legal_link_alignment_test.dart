import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/ai_consent_screen.dart';
import 'package:grammar_lens/theme.dart';

/// AI consent's Privacy Policy link starts at the text edge above it
/// (final screens A3) and keeps a 44 pt target.
void main() {
  testWidgets('the link is aligned with the paragraph and 44 pt tall',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1400) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: const AiConsentScreen()));
    await tester.pumpAndSettle();
    final paragraph =
        tester.getRect(find.textContaining('You can change this any time'));
    final label = tester.getRect(find.text('Privacy Policy'));
    expect(label.left, closeTo(paragraph.left, 0.5));
    final button = tester.getSize(find.ancestor(
        of: find.text('Privacy Policy'), matching: find.byType(TextButton)));
    expect(button.height, greaterThanOrEqualTo(44));
    expect(button.width, greaterThanOrEqualTo(44));
  });
}
