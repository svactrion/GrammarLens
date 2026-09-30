// Batch 3c-A rendering helpers. Measuring code only: nothing in lib/ imports it.
// Run from the repository root.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';

import 'shell.dart';

/// Where results go: `DESIGN_MEASURE_OUT`, or `build/design_measure`.
String outDir() {
  final dir =
      Platform.environment['DESIGN_MEASURE_OUT'] ?? 'build/design_measure';
  Directory(dir).createSync(recursive: true);
  return dir;
}

Future<void> loadFonts() async {
  final nunito = File('assets/fonts/NunitoSans-Variable.ttf').readAsBytesSync();
  await (FontLoader('NunitoSans')
        ..addFont(
            Future.value(ByteData.view(Uint8List.fromList(nunito).buffer))))
      .load();
}

double cardWidth(double screen) =>
    screen - 2 * (screen * .045).clamp(16.0, 28.0);

class Caption extends StatelessWidget {
  final String text;
  final Color color;
  const Caption(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontFamily: 'NunitoSans',
                decoration: TextDecoration.none,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      );
}

/// Renders [child] on the app's Home body color and writes a PNG at 2×.
Future<void> shoot(
    WidgetTester tester, Widget child, Size size, String file, Brightness b,
    {AppTextSize textSize = AppTextSize.medium}) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  final theme = buildAppTheme(b, textSize: textSize);
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: theme,
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: theme.colorScheme.surfaceContainerLow,
          padding: const EdgeInsets.all(14),
          child: DefaultTextStyle(
              style: const TextStyle(decoration: TextDecoration.none),
              child: child),
        ),
      ),
    ),
  ));
  await tester.runAsync(
      () => precacheImage(AssetImage(snail.assetPath), key.currentContext!));
  await tester.pump();
  await tester.runAsync(() async {
    final img =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
