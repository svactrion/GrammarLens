import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/widgets/launch_splash.dart';

/// The splash's finished frame with the real font: logo and wordmark are one
/// block centered on the screen, and the wordmark fits the narrowest
/// supported screen (320 pt, iOS 15) with 24 pt on each side.
void main() {
  setUpAll(() async {
    final bytes = rootBundle.load('assets/fonts/NunitoSans-Variable.ttf');
    await (FontLoader('NunitoSans')..addFont(bytes)).load();
  });

  for (final screen in const [Size(402, 874), Size(375, 667), Size(320, 568)]) {
    testWidgets('layout at ${screen.width.toInt()} x ${screen.height.toInt()}',
        (tester) async {
      tester.view.physicalSize = screen * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MediaQuery(
        data: MediaQueryData(size: screen),
        child: const LaunchSplash(),
      ));
      await tester.pump(LaunchTiming.intro);

      final logo = tester.getRect(find.byType(LaunchLogo));
      final wordmark = tester.getRect(find.text('GrammarLens'));

      expect(logo.size, const Size.square(LaunchSplashLayout.logoSize));
      expect(logo.center.dx, screen.width / 2);
      expect(logo.center.dy,
          screen.height / 2 + LaunchSplashLayout.logoCenterOffsetY);
      expect(wordmark.top - logo.bottom, LaunchSplashLayout.wordmarkGap);
      expect(wordmark.height, LaunchSplashLayout.wordmarkHeight);

      // The block is centered vertically.
      final blockCenter = (logo.top + wordmark.bottom) / 2;
      expect((blockCenter - screen.height / 2).abs(), lessThanOrEqualTo(0.5));

      // The wordmark's glyphs, not its full-width box, keep 24 pt margins.
      final paragraph =
          tester.renderObject<RenderParagraph>(find.text('GrammarLens'));
      final textWidth = paragraph.getMaxIntrinsicWidth(double.infinity);
      expect((screen.width - textWidth) / 2, greaterThanOrEqualTo(24));
    });
  }
}
