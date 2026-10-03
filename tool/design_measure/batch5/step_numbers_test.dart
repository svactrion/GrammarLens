// Batch 5 step 2 (N31, N32): the pinned steps, on the product's tables.
// For 28–31-day months: each save point's step before N31 (even spacing
// over the whole trail: the first day whose arc reaches the save point's)
// and after it, in both endings; the smallest and largest neighbour gap
// against the even gap; the flag's arc share and the trail left unused when
// the climb ends at the flag; and the resting avatar's tile against the C5
// signpost's box on every step, at 320 / 375 / 430 pt (boxes, not pixels).
//
//   DESIGN_MEASURE_OUT=docs/design/batch5/steps \
//     flutter test tool/design_measure/batch5/step_numbers_test.dart
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';

import '../layouts.dart' show outDir;

const _windows = {320: 288.0, 375: 341.3, 430: 391.3};

void main() {
  tearDown(() => ClimbRoute.debugEndsAtFlagOverride = null);

  test('step numbers', () {
    final lines = <String>[
      'Batch 5 step 2 (N31, N32): pinned steps (tool/design_measure/batch5/'
          'step_numbers_test.dart).',
      '',
      'Trail ${ClimbRoute.length.toStringAsFixed(4)} image widths; the flag\'s '
          'point at ${climbFlagArc.toStringAsFixed(4)} '
          '(${(climbFlagArc / ClimbRoute.length * 100).toStringAsFixed(2)} % of '
          'the trail); ending at the flag leaves '
          '${((1 - climbFlagArc / ClimbRoute.length) * 100).toStringAsFixed(2)} % '
          'of it unused.',
      '',
      'Each save point\'s step: before N31 (even over the whole trail) -> '
          'after, ending at the flag (default) | ending at the tip.',
      'days  ${[
        for (final p in ClimbSavePoints.all)
          '${p.clearing} ${p.name}'.padRight(22)
      ].join()}',
    ];
    for (var days = 28; days <= 31; days++) {
      String cell(ClimbSavePoint p) {
        final before = List.generate(days + 1, (d) => d).firstWhere(
            (d) => ClimbRoute.length * d / days >= p.arc - 1e-9,
            orElse: () => days);
        ClimbRoute.debugEndsAtFlagOverride = true;
        final flag = p.reachedOn(days);
        ClimbRoute.debugEndsAtFlagOverride = false;
        final tip = p.reachedOn(days);
        ClimbRoute.debugEndsAtFlagOverride = null;
        return '$before -> $flag | $tip'.padRight(22);
      }

      lines.add(
          '$days    ${[for (final p in ClimbSavePoints.all) cell(p)].join()}');
    }
    lines.addAll([
      '',
      'Neighbour gaps against the even gap (the climb\'s length / days):',
      'days  ending at the flag (min / max)   ending at the tip (min / max)',
    ]);
    for (var days = 28; days <= 31; days++) {
      String ratios(bool atFlag) {
        ClimbRoute.debugEndsAtFlagOverride = atFlag;
        final route = ClimbRoute(days);
        final even = ClimbRoute.climbLength / days;
        var lo = double.infinity, hi = 0.0;
        for (var d = 1; d <= days; d++) {
          final r = (route.arcAt(d.toDouble()) - route.arcAt(d - 1.0)) / even;
          if (r < lo) lo = r;
          if (r > hi) hi = r;
        }
        ClimbRoute.debugEndsAtFlagOverride = null;
        return '${lo.toStringAsFixed(3)} / ${hi.toStringAsFixed(3)}';
      }

      lines.add('$days    ${ratios(true).padRight(33)}${ratios(false)}');
    }
    final sign = ClimbSavePoints.decor.single.rect;
    lines.addAll([
      '',
      'The resting avatar\'s tile against the C5 signpost\'s box '
          '(${sign.left.toStringAsFixed(4)}, ${sign.top.toStringAsFixed(4)}, '
          '${sign.right.toStringAsFixed(4)}, ${sign.bottom.toStringAsFixed(4)} '
          'image widths): steps that overlap, share of the signpost\'s box.',
    ]);
    for (final atFlag in [true, false]) {
      ClimbRoute.debugEndsAtFlagOverride = atFlag;
      for (final MapEntry(key: screen, value: window) in _windows.entries) {
        final camera = ClimbCamera(window);
        for (var days = 28; days <= 31; days++) {
          final route = ClimbRoute(days);
          final hits = <String>[];
          for (var d = 0; d <= days; d++) {
            final p = route.pointAt(d.toDouble());
            final tile =
                camera.avatarTileAt(route.arcAt(d.toDouble())) / camera.scale;
            final r = Rect.fromLTWH(
                p.dx - tile / 2, p.dy - tile * 55 / 58, tile, tile);
            final i = r.intersect(sign);
            if (i.width > 0 && i.height > 0) {
              hits.add(
                  '$d (${(i.width * i.height * 100 / (sign.width * sign.height)).round()} %)');
            }
          }
          lines.add('  ${atFlag ? 'flag' : 'tip '}  $screen pt, $days days: '
              '${hits.isEmpty ? 'none' : hits.join(', ')}');
        }
      }
    }
    ClimbRoute.debugEndsAtFlagOverride = null;
    File('${outDir()}/step_numbers.txt')
        .writeAsStringSync('${lines.join('\n')}\n');
  });
}
