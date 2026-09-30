// The greeting fix on the real Home at 320 × 568: three names in the
// afternoon (the longest greeting word), at Medium and Large.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';

import 'home_fakes.dart';
import 'layouts.dart';

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });

  for (final textSize in [AppTextSize.medium, AppTextSize.large]) {
    for (final name in ['Ada', 'Charlotte', 'Mary Anne Smith']) {
      final file = 'greeting_after_320_${textSize.name}_'
          '${name.split(' ').first.toLowerCase()}.png';
      testWidgets(file, (tester) async {
        tester.view.physicalSize = const Size(320, 568) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 60);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: designHome(
              clock: DateTime(2026, 9, 15, 14),
              storage: DesignStorage(steps: 8),
              textSize: textSize,
              userName: name),
        ));
        await tester.runAsync(() => precacheImage(
            AssetImage(Avatar.values.first.assetPath), key.currentContext!));
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        await writePng(tester, key, '$out/$file');
      });
    }
  }
}
