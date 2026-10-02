// Batch 6, M22: the K-c framing over its blurred backdrop, at 430 pt, for
// the four themes, light and dark, at three blur strengths (light /
// medium / strong, tool/scene_art/export_blur.py --candidates). The
// product's assets are the medium ones. The real ClimbCard and
// MonthlyMountain in K-c (zoom at 0), sheet closed, chips hidden as in a
// zoom; the backdrop is swapped through ClimbOverview.debugBackdropOverride.
// Next to each PNG, a JSON with the window and the sharp image's bounds in
// its pixels (for the seam measure in batch6_blur_sheet.py).
//
//   build/scene_art_venv/bin/python tool/scene_art/export_blur.py --candidates
//   DESIGN_MEASURE_OUT=build/design_measure/batch6_blur \
//     flutter test tool/design_measure/batch6/kc_blur_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch6_blur_sheet.py
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

void main() {
  final out = outDir();
  setUpAll(loadFont);
  tearDown(() => ClimbOverview.debugBackdropOverride = null);
  // The window on a 430 pt screen (zoom_numbers.txt).
  const width = 391.3;
  for (final strength in ['light', 'medium', 'strong']) {
    for (final b in Brightness.values) {
      for (final theme in ClimbThemes.all) {
        final name = 'blur_${strength}_${b.name}_${theme.id}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = const Size(430, 600) * 2;
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.reset);
          // Bytes read here: a FileImage started inside the test's fake
          // async zone never finishes loading.
          final backdrop = MemoryImage(
              File('build/scene_art/blur/$strength/${theme.id}_${b.name}.webp')
                  .readAsBytesSync());
          ClimbOverview.debugBackdropOverride = (_, __) => backdrop;
          final key = GlobalKey();
          final appTheme = buildAppTheme(b);
          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: appTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: appTheme.colorScheme.surfaceContainerLow,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: SizedBox(
                        width: width,
                        child: ClimbCard(
                          month: DateTime(2026, 11),
                          steps: 0,
                          days: 30,
                          chipOpacity: kAlwaysDismissedAnimation,
                          mountain: MonthlyMountain(
                            days: 30,
                            completedDays: 0,
                            avatar: Avatar.values.first,
                            theme: theme,
                            zoom: kAlwaysDismissedAnimation,
                          ),
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
            final context = key.currentContext!;
            await Future.wait([
              precacheImage(backdrop, context),
              for (final asset in [
                Avatar.values.first.assetPath,
                theme.backgroundFor(b),
                for (final p in ClimbSavePoints.all) p.asset,
                ClimbSavePoints.assetFor('summit_flag'),
                ClimbSavePoints.flagBaseAsset,
                ClimbSavePoints.pennantAsset,
              ])
                precacheImage(AssetImage(asset), context),
            ]);
          });
          await tester.pump();
          final origin = tester.getTopLeft(find.byKey(key));
          final window =
              tester.getRect(find.byType(MonthlyMountain)).shift(-origin);
          final band = ClimbOverview.band(window.width);
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$name.png')
                .writeAsBytesSync(bytes!.buffer.asUint8List());
            File('$out/$name.json').writeAsStringSync(jsonEncode({
              'window': [
                for (final v in [
                  window.left,
                  window.top,
                  window.right,
                  window.bottom
                ])
                  v * 2
              ],
              'sharp_left': (window.left + band) * 2,
              'sharp_right': (window.right - band) * 2,
            }));
          });
        });
      }
    }
  }
}
