// The launch splash's finished frame with the real font, light and dark
// (final pass: the wordmark at Home's weight).
//
//   DESIGN_MEASURE_OUT=docs/design/1.2.0-final/splash DESIGN_MEASURE_TAG=after \
//     flutter test tool/design_measure/v120/splash_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

import '../layouts.dart' show loadFont, outDir;

void main() {
  final out = outDir();
  final tag = Platform.environment['DESIGN_MEASURE_TAG'] ?? 'now';
  setUpAll(loadFont);
  for (final b in Brightness.values) {
    testWidgets('splash 390 ${b.name} $tag', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MediaQuery(
          data: MediaQueryData(
              size: const Size(390, 844), platformBrightness: b),
          child: const LaunchSplash(),
        ),
      ));
      await tester.pump(LaunchTiming.intro);
      await tester.runAsync(() async {
        final img = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 3);
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File('$out/splash_390_${b.name}_$tag.png')
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }
}
