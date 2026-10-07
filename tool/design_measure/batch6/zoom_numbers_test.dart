// Batch 6 Batch 0, §6: the month-change zoom's two framings, on the real
// Home's window at 320 / 375 / 430 pt, from the product's own ClimbCamera
// and ClimbRoute. K-c: the whole image in the window (fitted to its
// height, scene art Batch 0 §3). Daily: ClimbCamera (fitted to the width,
// × ClimbCamera.zoom, following the avatar). For the avatar on START (day
// 0, where a new month and a first run both stand), and for reference on
// day 15 and the last day of a 31-day month. Writes `zoom_numbers.txt`.
//
//   DESIGN_MEASURE_OUT=docs/design/batch6 \
//     flutter test tool/design_measure/batch6/zoom_numbers_test.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, outDir;

String _f(double v, [int d = 1]) => v.toStringAsFixed(d);
String _o(Offset o) => '(${_f(o.dx)}, ${_f(o.dy)})';

void main() {
  final lines = <String>[
    'Batch 6 Batch 0 §6: K-c and the daily framing on the real Home',
    'Units: points. "scale" = points per image width (ClimbRoute\'s unit).',
    'A layer drawn at the daily scale reaches K-c by Transform: scale s0 = '
        'K-c scale ÷ daily scale, then translate.',
    '',
  ];
  setUpAll(loadFont);
  tearDownAll(() => File('${outDir()}/zoom_numbers.txt')
      .writeAsStringSync('${lines.join('\n')}\n'));

  for (final screen in [320.0, 375.0, 430.0]) {
    testWidgets('$screen', (tester) async {
      tester.view.physicalSize = Size(screen, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(designHome(
          clock: DateTime(2026, 10, 15, 14), storage: DesignStorage(steps: 0)));
      await tester.pump(const Duration(seconds: 1));
      final window = tester.getRect(find.byType(MonthlyMountain));
      final card = tester.getRect(find.byType(ClimbCard));
      final w = window.width;
      const h = ClimbCamera.windowHeight;
      final camera = ClimbCamera(w);
      final route = ClimbRoute(31);

      // K-c: fitted to the window's height, centered across.
      final kcScale = h / ClimbRoute.sceneSize.height;
      final kcImage = ClimbRoute.sceneSize * kcScale;
      final band = (w - kcImage.width) / 2;
      final s0 = kcScale / camera.scale;

      lines.addAll([
        '== $screen pt screen: window ${_f(w)} × ${_f(h)} '
            '(card ${_f(card.width)} wide) ==',
        'Daily (ClimbCamera.zoom ${ClimbCamera.zoom}): scale ${_f(camera.scale)}, '
            'image ${_f(camera.imageSize.width)} × '
            '${_f(camera.imageSize.height)}, shows '
            '${_f(w * h * 100 / (camera.imageSize.width * camera.imageSize.height), 0)} % '
            'of the image',
        '  layer at 3x: ${_f(camera.imageSize.width * 3, 0)} × '
            '${_f(camera.imageSize.height * 3, 0)} px '
            '(${_f(camera.imageSize.width * camera.imageSize.height * 9 * 4 / 1048576)} MB as RGBA)',
        'K-c (fitted to the height): scale ${_f(kcScale)}, image '
            '${_f(kcImage.width)} × ${_f(kcImage.height)}, '
            '${_f(band)} pt of empty window on each side',
        'Zoom: s0 = ${_f(s0, 3)} (K-c is ${_f(1 / s0, 2)}× smaller than daily)',
      ]);
      for (final day in [0, 15, 31]) {
        final p = route.pointAt(day.toDouble());
        final off = camera.offsetFor(p);
        final dailyAt = camera.toWindow(p, off);
        final kcAt = p * kcScale + Offset(band, 0);
        final tile = camera.avatarTileAt(route.arcAt(day.toDouble()));
        lines.addAll([
          '  day $day${day == 0 ? ' (START)' : ''}: daily offset ${_o(off)}, '
              'avatar at ${_o(dailyAt)} in the window; K-c avatar at '
              '${_o(kcAt)}',
          '    translate at K-c ${_o(Offset(band, 0))} → daily ${_o(-off)} '
              '(applied after scaling the daily layer by s0 → 1)',
          '    avatar tile ${_f(tile)} daily, ${_f(tile * s0)} at K-c',
        ]);
      }
      final summitKc = ClimbRoute.summit * kcScale + Offset(band, 0);
      final chipsBottom =
          tester.getRect(find.byKey(ClimbCard.stepsKey)).bottom - window.top;
      lines.addAll([
        '  summit at K-c: ${_o(summitKc)}; the step chip\'s text ends '
            '${_f(chipsBottom)} pt below the window\'s top',
        '',
      ]);
    });
  }
}
