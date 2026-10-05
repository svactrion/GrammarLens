// 1.2.0 Batch 7, A1: Home's hero with the real font and images, cut out of
// the screen at 3x (the hero's square plus a 28 pt margin), and the whole
// header for context. 390 × 844, light and dark (DESIGN_MEASURE_MODES).
// DESIGN_MEASURE_TAG is added to the file names (e.g. before / after).
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_hero DESIGN_MEASURE_TAG=after \
//     flutter test tool/design_measure/v120/hero_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/avatar_picker_screen.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  final tag = Platform.environment['DESIGN_MEASURE_TAG'] ?? 'now';
  final modes = [
    for (final m in (Platform.environment['DESIGN_MEASURE_MODES'] ??
            'light,dark')
        .split(','))
      Brightness.values.byName(m.trim())
  ];

  for (final b in modes) {
    testWidgets('hero 390 ${b.name} $tag', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 47 * 3);
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: designHome(
          clock: DateTime(2026, 10, 5, 9),
          storage: DesignStorage(steps: 4, correct: 12),
          brightness: b,
          userName: 'Ahmet',
          avatar: Avatar.values.first,
        ),
      ));
      await tester.runAsync(() => precacheImage(
          AssetImage(Avatar.values.first.assetPath), key.currentContext!));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      final hero = tester.getRect(find.descendant(
          of: find.byWidgetPredicate(
              (w) => w is Hero && w.tag == homeAvatarHeroTag),
          matching: find.byType(AvatarTile)));
      await tester.runAsync(() async {
        final full = await (key.currentContext!.findRenderObject()
                as RenderRepaintBoundary)
            .toImage(pixelRatio: 3);
        Future<void> crop(Rect src, String name) async {
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
          File('$out/$name').writeAsBytesSync(bytes!.buffer.asUint8List());
        }

        await crop(hero.inflate(28), 'hero_390_${b.name}_$tag.png');
        await crop(Rect.fromLTRB(0, 0, 390, hero.bottom + 120),
            'header_390_${b.name}_$tag.png');
      });
    });
  }
}
