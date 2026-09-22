import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/screens/theme_preview_screen.dart';
import 'package:grammar_lens/theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shows the destructive swatches ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(390, 3000) * 3.0;
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(
        theme: buildAppTheme(brightness),
        home: const ThemePreviewScreen(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('destructive'), findsOneWidget);
      expect(find.text('onDestructive'), findsOneWidget);
    });
  }
}
