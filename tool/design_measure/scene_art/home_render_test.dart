// Scene Art: the real Home (the real navigation shell, HomeScreen,
// ClimbCard, MonthlyMountain, ClimbScoreBar), in a 31-day month (October
// 2026), light and dark. The window is made tall so the whole card shows
// without scrolling; each image is the climb card cut out of the screen at
// 3x. Stage 1: days 1, 15 and 31 at 320 and 375 pt (the defaults);
// Stage 2: DESIGN_MEASURE_SCREENS=375 DESIGN_MEASURE_DAYS=1,10,20,31.
// DESIGN_MEASURE_MONTH (YYYY-MM) shows that month's theme on its last day.
// DESIGN_MEASURE_MODES (light,dark) limits the modes, and
// DESIGN_MEASURE_DARK_STRENGTH sets G6's strength, added to the file name.
// Next to each image, <name>.json holds the objects' boxes in its pixels.
//
//   DESIGN_MEASURE_OUT=build/design_measure/scene_art_stage1 \
//     flutter test tool/design_measure/scene_art/home_render_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });

  List<String>? env(String name) =>
      Platform.environment[name]?.split(',').map((s) => s.trim()).toList();
  final screens = [
    for (final s in env('DESIGN_MEASURE_SCREENS') ?? ['320', '375'])
      double.parse(s)
  ];
  final days = [
    for (final d in env('DESIGN_MEASURE_DAYS') ?? ['1', '15', '31'])
      int.parse(d)
  ];
  final modes = [
    for (final m in env('DESIGN_MEASURE_MODES') ?? ['light', 'dark'])
      Brightness.values.byName(m)
  ];
  final strength = double.tryParse(
      Platform.environment['DESIGN_MEASURE_DARK_STRENGTH'] ?? '');
  // DESIGN_MEASURE_MONTH (YYYY-MM): the month shown, on its last day, so
  // its rotation theme (Batch 4); October 2026 when unset. Added to the
  // file name.
  final monthEnv = Platform.environment['DESIGN_MEASURE_MONTH'];
  final (year, month) = monthEnv == null
      ? (2026, 10)
      : (int.parse(monthEnv.split('-')[0]), int.parse(monthEnv.split('-')[1]));
  final clock = DateTime(year, month + 1, 0, 14);
  for (final screen in screens) {
    for (final b in modes) {
      for (final day in days) {
        final suffix = (strength == null ? '' : '_strength$strength') +
            (monthEnv == null ? '' : '_$monthEnv');
        final file = 'home_${screen.toInt()}_${b.name}_day$day$suffix.png';
        testWidgets(file, (tester) async {
          ClimbSavePoints.debugDarkFilterStrengthOverride = strength;
          addTearDown(
              () => ClimbSavePoints.debugDarkFilterStrengthOverride = null);
          tester.view.physicalSize = Size(screen, 1400) * 3;
          tester.view.devicePixelRatio = 3;
          tester.view.padding = const FakeViewPadding(top: 60);
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          await tester.pumpWidget(RepaintBoundary(
            key: key,
            child: designHome(
                clock: clock,
                storage: DesignStorage(steps: day, correct: day * 3),
                brightness: b),
          ));
          // Decode the images for real (tests otherwise draw nothing).
          await tester.runAsync(() async {
            await Future.wait([
              for (final asset in [
                Avatar.values.first.assetPath,
                ClimbThemeRotation.shownFor(year, month).backgroundFor(b),
                for (final p in ClimbSavePoints.all) p.asset,
                ClimbSavePoints.assetFor('summit_flag'),
                ClimbSavePoints.flameAsset,
              ])
                precacheImage(AssetImage(asset), key.currentContext!),
            ]);
          });
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.pump();
          final card = tester.getRect(find.byType(ClimbCard));
          final boxes = {
            'window': tester.getRect(find.byType(MonthlyMountain)),
            for (final p in ClimbSavePoints.all)
              p.object: tester.getRect(
                  find.byKey(ValueKey('climb_save_point_${p.clearing}'))),
          };
          await tester.runAsync(() async {
            final full = await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 3);
            const pad = 8.0;
            final src = Rect.fromLTRB(card.left - pad, card.top - pad,
                card.right + pad, card.bottom + pad);
            final recorder = ui.PictureRecorder();
            Canvas(recorder).drawImageRect(
                full,
                Rect.fromLTWH(
                    src.left * 3, src.top * 3, src.width * 3, src.height * 3),
                Rect.fromLTWH(0, 0, src.width * 3, src.height * 3),
                Paint());
            final img = await recorder
                .endRecording()
                .toImage((src.width * 3).round(), (src.height * 3).round());
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File('$out/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
            File('$out/${file.replaceAll('.png', '.json')}')
                .writeAsStringSync(jsonEncode({
              for (final name in boxes.keys)
                name: [
                  for (final v in [
                    boxes[name]!.left - src.left,
                    boxes[name]!.top - src.top,
                    boxes[name]!.right - src.left,
                    boxes[name]!.bottom - src.top,
                  ])
                    v * 3
                ]
            }));
          });
        });
      }
    }
  }
}
