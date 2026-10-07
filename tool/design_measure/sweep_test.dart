// Batch 3b report, R1: steepening sweep for candidate (b).
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'geo.dart';
import 'layouts.dart';

EvenLayout _wideS(String id, Offset p0, Offset p1) => EvenLayout(
    id,
    id,
    filletPolyline([p0, p1, const Offset(50, 338), const Offset(162, 84)],
        const [110, 110]));

void main() {
  test('sweep', () {
    final out = StringBuffer();
    final variants = <EvenLayout>[];
    for (final deg in [33.0, 38.0, 42.0, 45.0, 48.0, 50.0, 55.0]) {
      final x0 = 270 - 134 / math.tan(deg * math.pi / 180);
      variants.add(_wideS('A${deg.round()} start x=${x0.toStringAsFixed(1)}',
          Offset(x0, 700), const Offset(270, 566)));
    }
    for (final deg in [40.0, 45.0, 50.0]) {
      final y1 = 700 - 206 * math.tan(deg * math.pi / 180);
      variants.add(_wideS('B${deg.round()} corner y=${y1.toStringAsFixed(1)}',
          const Offset(64, 700), Offset(270, y1)));
    }
    for (final l in variants) {
      for (final days in [31, 28]) {
        final st = l.steps(days);
        final m = measure(l, days, 0.9);
        final t0 = l.metric.getTangentForOffset(1)!;
        final ang = -math.atan2(t0.vector.dy, t0.vector.dx) * 180 / math.pi;
        final dys = [for (var d = 1; d <= 4; d++) st[d - 1].dy - st[d].dy];
        final rise4 = st[0].dy - st[4].dy;
        // First straight: where curvature starts (first turn's fillet entry).
        out.writeln('${l.id} | ${days}d | angle ${ang.toStringAsFixed(1)} | '
            'len ${m['length_units']} | step ${(m['length_units'] as double) / days} | '
            'dy1-4 units ${dys.map((e) => e.toStringAsFixed(1)).join(",")} | '
            'rise4 units ${rise4.toStringAsFixed(1)} pt320 ${(rise4 * .9).toStringAsFixed(1)} pt375 ${(rise4 * 341.25 / 320).toStringAsFixed(1)} pt430 ${(rise4 * 391.3 / 320).toStringAsFixed(1)} | '
            'consGap ${m['consecutive_gap_min_pt']} at ${m['consecutive_gap_min_at']} | '
            'legGap ${m['leg_to_leg_centerline_min_pt']} at ${m['leg_to_leg_at']} | '
            'avatarOver ${m['avatar_covers_other_leg_days']} | turns ${m['turn_min_radius_units']} | '
            'acrossTurn ${m['nonconsecutive_gap_min_pt']} | start ${st[0]} | '
            'free ${m['free_area_pct_scene']}% ${m['free_boxes_on_mountain']}/${m['free_boxes_count']} 80:${m['free_boxes_80']} | noSpot ${m['markers_no_clear_spot']}');
      }
    }
    File('${outDir()}/sweep.txt').writeAsStringSync(out.toString());
  });
}
