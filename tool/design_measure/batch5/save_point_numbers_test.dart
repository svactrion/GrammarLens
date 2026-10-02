// Batch 5 Batch 0, §3 and §4: on the product's own classes (ClimbRoute,
// ClimbCamera, ClimbSavePoints), for 28–31-day months:
//   - the step each save point and the flag is reached on (N6's label day);
//   - the step the avatar reaches C5 on (N11 says 26 of 28, 29 of 31), by
//     the save points' own rule (the arc of the trail point nearest the
//     clearing's centre);
//   - the resting avatar's tile against the signpost's box
//     (docs/design/batch5/signpost/placement.json, from
//     tool/scene_art/batch5_signpost.py) on every step, at 320 / 375 /
//     430 pt, and, for scale, against the four save points and the flag.
//
//   DESIGN_MEASURE_OUT=docs/design/batch5 \
//     flutter test tool/design_measure/batch5/save_point_numbers_test.dart
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';

import '../layouts.dart' show outDir;

/// The card's window width at each screen (Batch 6, zoom_numbers.txt).
const windows = {320: 288.0, 375: 341.3, 430: 391.3};

/// The signpost's box in image widths and C5's centre (normalized).
({Rect rect, Offset centre}) signpost() {
  final json = jsonDecode(
          File('docs/design/batch5/signpost/placement.json').readAsStringSync())
      as Map<String, dynamic>;
  final r = (json['rect_image_widths'] as List).cast<num>();
  final c = (json['center_norm'] as List).cast<num>();
  return (
    rect: Rect.fromLTRB(
        r[0].toDouble(), r[1].toDouble(), r[2].toDouble(), r[3].toDouble()),
    centre: Offset(c[0].toDouble(), c[1].toDouble() / climbImageAspect),
  );
}

/// The arc, in image widths, of the trail point nearest [centre]: the rule
/// `ClimbSavePoints._place` uses for a save point's "reached".
double nearestArc(Offset centre) {
  var arc = 0.0, nearest = double.infinity;
  for (var s = 0.0; s <= ClimbRoute.length; s += ClimbRoute.length / 2000) {
    final d = (ClimbRoute.at(s) - centre).distance;
    if (d < nearest) {
      nearest = d;
      arc = s;
    }
  }
  return arc;
}

/// The resting avatar's tile on step [day], in image widths
/// (MonthlyMountain: the feet on the step, the tile's top 55/58 of its
/// side above it).
Rect avatarTile(ClimbRoute route, ClimbCamera camera, int day) {
  final p = route.pointAt(day.toDouble());
  final tile = camera.avatarTileAt(route.arcAt(day.toDouble())) / camera.scale;
  return Rect.fromLTWH(p.dx - tile / 2, p.dy - tile * 55 / 58, tile, tile);
}

double overlapShare(Rect a, Rect b) {
  final i = a.intersect(b);
  if (i.width <= 0 || i.height <= 0) return 0;
  return i.width * i.height / (b.width * b.height);
}

void main() {
  test('save point and signpost numbers', () {
    final sign = signpost();
    final c5Arc = nearestArc(sign.centre);
    final lines = <String>[
      'Batch 5 Batch 0 §3-§4: save points, the flag and the C5 signpost on the '
          'product\'s route and camera (tool/design_measure/batch5/'
          'save_point_numbers_test.dart).',
      '',
      'Step each is reached on (ClimbSavePoint.reachedOn; C5 by the same '
          'rule, nearest trail point to the clearing\'s centre):',
      'days  ${[
        for (final p in ClimbSavePoints.all) '${p.clearing} ${p.object}'
      ].join('  ')}  C5 signpost  C6 flag',
    ];
    for (final days in [28, 29, 30, 31]) {
      final route = ClimbRoute(days);
      var c5 = days;
      for (var d = 0; d <= days; d++) {
        if (route.arcAt(d.toDouble()) >= c5Arc - 1e-9) {
          c5 = d;
          break;
        }
      }
      lines.add('$days    ${[
        for (final p in ClimbSavePoints.all)
          '${p.reachedOn(days)}'.padRight('${p.clearing} ${p.object}'.length)
      ].join('  ')}  ${'$c5'.padRight(11)}  ${ClimbSavePoints.flag.reachedOn(days)}'
          '   (C5 is ${days - c5} step(s) before the summit)');
    }
    lines.addAll([
      '',
      'C5 arc: ${c5Arc.toStringAsFixed(4)} image widths of '
          '${ClimbRoute.length.toStringAsFixed(4)} '
          '(${(c5Arc / ClimbRoute.length * 100).toStringAsFixed(1)} %).',
      'Signpost box (image widths): left ${sign.rect.left.toStringAsFixed(4)}, '
          'top ${sign.rect.top.toStringAsFixed(4)}, right '
          '${sign.rect.right.toStringAsFixed(4)}, bottom '
          '${sign.rect.bottom.toStringAsFixed(4)}.',
      '',
      'The resting avatar\'s tile against the signpost\'s box: the steps whose '
          'tile overlaps it, with the share of the signpost\'s box covered '
          '(boxes, not pixels; the avatar is drawn above the objects).',
    ]);
    for (final MapEntry(key: screen, value: window) in windows.entries) {
      final camera = ClimbCamera(window);
      for (final days in [28, 29, 30, 31]) {
        final route = ClimbRoute(days);
        final hits = <String>[];
        for (var d = 0; d <= days; d++) {
          final share = overlapShare(avatarTile(route, camera, d), sign.rect);
          if (share > 0) hits.add('$d (${(share * 100).round()} %)');
        }
        lines.add('  $screen pt, $days days: '
            '${hits.isEmpty ? 'none' : hits.join(', ')}');
      }
    }
    lines.addAll([
      '',
      'For scale, the same for the save points and the flag at 375 pt '
          '(steps that overlap, any month length 28-31):',
    ]);
    final camera = ClimbCamera(windows[375]!);
    for (final p in [...ClimbSavePoints.all, ClimbSavePoints.flag]) {
      final hits = <String>{};
      for (final days in [28, 29, 30, 31]) {
        final route = ClimbRoute(days);
        for (var d = 0; d <= days; d++) {
          final share = overlapShare(avatarTile(route, camera, d), p.rect);
          if (share > 0) hits.add('$days:$d (${(share * 100).round()} %)');
        }
      }
      lines.add('  ${p.clearing} ${p.object}: '
          '${hits.isEmpty ? 'none' : hits.join(', ')}');
    }
    File('${outDir()}/save_point_numbers.txt')
        .writeAsStringSync('${lines.join('\n')}\n');
  });
}
