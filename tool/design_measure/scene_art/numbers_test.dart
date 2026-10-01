// Scene Art Stage 1, measured on the product's own classes (ClimbRoute,
// ClimbCamera, ClimbTrailDots): per card width, a day's step, the gap
// between passed-day dots, the avatar's size on days 0–30 and at the
// summit, the day the summit comes into view, and the window's share of
// the image.
//
//   DESIGN_MEASURE_OUT=docs/design/scene-art/stage1 \
//     flutter test tool/design_measure/scene_art/numbers_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../layouts.dart' show cardWidth, outDir;

/// The top of the snow cap, marked by hand on green/background_light.png in
/// Scene Art Batch 0 (tool/scene_art/framing.py, PEAK), normalized.
const _peak = (0.5087, 0.1133);

/// The month and step chips cover about the top 48 pt of the window
/// (Batch 0 report §3).
const _chipBand = 48.0;

String _f(double v, [int d = 1]) => v.toStringAsFixed(d);

void main() {
  test('scene art stage 1 numbers', () {
    final out = StringBuffer()
      ..writeln('Scene Art Stage 1 — measured on ClimbRoute / ClimbCamera '
          '(zoom ${ClimbCamera.zoom}), 31-day month unless stated')
      ..writeln('trail length ${_f(ClimbRoute.length, 4)} image widths; '
          'shrink from ${ClimbCamera.shrinkFrom} of it to '
          '${ClimbCamera.shrinkFloor} of the base; dots '
          '${ClimbTrailDots.diameter} pt at ${ClimbTrailDots.opacity}')
      ..writeln();
    final peak = Offset(_peak.$1, _peak.$2 / climbImageAspect);
    for (final screen in [320.0, 375.0, 430.0]) {
      final w = cardWidth(screen);
      final camera = ClimbCamera(w);
      final route = ClimbRoute(31);
      final step = ClimbRoute.length / 31 * camera.scale;
      var shortest = double.infinity;
      for (var d = 1; d <= 31; d++) {
        shortest = math.min(
            shortest, (route.stepAt(d) - route.stepAt(d - 1)).distance);
      }
      final gap = shortest * camera.scale - ClimbTrailDots.diameter;
      final sizes = [
        for (var d = 0; d <= 31; d++)
          camera.avatarTileAt(route.arcAt(d.toDouble()))
      ];
      bool visible(int day, double top) {
        final o = camera.offsetFor(route.stepAt(day));
        final p = camera.toWindow(peak, o);
        return p.dx >= 0 && p.dx <= w && p.dy >= top && p.dy <= 350;
      }

      int? from(double top) {
        for (var d = 0; d <= 31; d++) {
          if (List.generate(32 - d, (i) => d + i)
              .every((e) => visible(e, top))) {
            return d;
          }
        }
        return null;
      }

      final shown =
          w * 350 / (camera.imageSize.width * camera.imageSize.height);
      final shrinking = [
        for (var d = 1; d <= 31; d++)
          if (sizes[d] < sizes[d - 1] - 1e-9) d
      ];
      out
        ..writeln('$screen pt screen, card ${_f(w, 2)} pt '
            '(${_f(camera.scale, 1)} pt per image width; image '
            '${_f(camera.imageSize.width)} × ${_f(camera.imageSize.height)} pt; '
            'window shows ${_f(shown * 100, 0)} % of it)')
        ..writeln('  a day\'s step along the trail: ${_f(step)} pt; shortest '
            'straight step ${_f(shortest * camera.scale)} pt; gap between '
            'neighbouring dots ${_f(gap)} pt')
        ..writeln(
            '  avatar: ${_f(sizes[0])} pt on days 0–${shrinking.first - 1}; '
            'shrinking on days ${shrinking.first}–31: '
            '${[for (final d in shrinking) _f(sizes[d])].join(' / ')} pt; '
            'summit (floor) ${_f(sizes[31])} pt; hop ${_f(sizes[0] * MonthlyMountain.hopShare)} pt '
            'on the body')
        ..writeln('  the summit (snow cap top) is in the window from day '
            '${from(0)}, below the chips from day ${from(_chipBand)}');
      for (final days in [28, 29, 30]) {
        final r = ClimbRoute(days);
        final first = [
          for (var d = 1; d <= days; d++)
            if (camera.avatarTileAt(r.arcAt(d.toDouble())) <
                camera.baseAvatarTile - 1e-9)
              d
        ].first;
        out.writeln('  $days days: shrinking from day $first, '
            'step ${_f(ClimbRoute.length / days * camera.scale)} pt');
      }
      out.writeln();
    }
    final assets = [
      'assets/climb/green_slope/background_light.webp',
      'assets/climb/green_slope/background_dark.webp',
    ];
    var total = 0;
    for (final a in assets) {
      final n = File(a).lengthSync();
      total += n;
      out.writeln('$a: ${_f(n / 1024)} KB');
    }
    out.writeln('assets added: ${_f(total / 1024)} KB');
    final dir = outDir();
    File('$dir/numbers.txt').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print(out);
  });
}
