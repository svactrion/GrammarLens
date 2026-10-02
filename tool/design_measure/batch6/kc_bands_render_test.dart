// Batch 6, M11: the K-c framing's side bands, at 430 pt in light mode, for
// the four themes: the product's single colour per theme and mode, and,
// for the owner's decision only, a vertical gradient from the image edge's
// top fifth to its bottom fifth (docs/design/batch6/kc_bands.json, written
// by tool/scene_art/kc_band_colors.py). The gradient is painted over the
// bands of the real render here; it is not in the product.
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch6_kc_bands \
//     flutter test tool/design_measure/batch6/kc_bands_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch6_kc_bands_sheet.py
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_zoom.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../layouts.dart' show loadFont, outDir;

Color _hex(String s) =>
    Color(0xFF000000 | int.parse(s.substring(1), radix: 16));

void main() {
  final out = outDir();
  final bands =
      jsonDecode(File('docs/design/batch6/kc_bands.json').readAsStringSync())
          as Map<String, dynamic>;
  setUpAll(loadFont);
  // The window on a 430 pt screen (zoom_numbers.txt).
  const width = 391.3;
  for (final theme in ClimbThemes.all) {
    for (final gradient in [false, true]) {
      final name =
          'kc_430_light_${theme.id}_${gradient ? 'gradient' : 'solid'}';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(430, 600) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final edge = bands[theme.id]['light'] as Map<String, dynamic>;
        final band = ClimbOverview.band(width);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          home: Scaffold(
            // Unbounded height: the card takes its own.
            body: SingleChildScrollView(
              child: RepaintBoundary(
                key: key,
                child: ColoredBox(
                  color: buildAppTheme(Brightness.light)
                      .colorScheme
                      .surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      width: width,
                      child: ClimbCard(
                        month: DateTime(2026, 11),
                        steps: 0,
                        days: 30,
                        chipOpacity: kAlwaysDismissedAnimation,
                        mountain: Stack(children: [
                          MonthlyMountain(
                            days: 30,
                            completedDays: 0,
                            avatar: Avatar.values.first,
                            theme: theme,
                            zoom: kAlwaysDismissedAnimation,
                          ),
                          if (gradient)
                            for (final left in [0.0, width - band])
                              Positioned(
                                left: left,
                                top: 0,
                                width: band,
                                height: 350,
                                child: DecoratedBox(
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                      _hex(edge['top'] as String),
                                      _hex(edge['bottom'] as String),
                                    ]))),
                              ),
                        ]),
                        scoreBar: const SizedBox(height: 40),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.runAsync(() async {
          await Future.wait([
            for (final asset in [
              Avatar.values.first.assetPath,
              theme.backgroundFor(Brightness.light),
              for (final p in ClimbSavePoints.all) p.asset,
              ClimbSavePoints.assetFor('summit_flag'),
              ClimbSavePoints.flagBaseAsset,
              ClimbSavePoints.pennantAsset,
            ])
              precacheImage(AssetImage(asset), key.currentContext!),
          ]);
        });
        await tester.pump();
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
