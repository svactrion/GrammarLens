// Batch 3b report, R1, R2 and R6: numbers and images.
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'layouts.dart';
import 'geo.dart';

const widths = [320.0, 375.0, 430.0];
String f1d(double v) => v.toStringAsFixed(1);

void main() {
  final docs = outDir();
  final out = StringBuffer();
  setUpAll(loadFont);
  tearDownAll(
      () => File('$docs/report_numbers.txt').writeAsStringSync(out.toString()));

  test('R1 numbers', () {
    for (final l in [bNow, bSteep]) {
      for (final days in [31, 30, 29, 28]) {
        final st = l.steps(days);
        final t = l.metric.getTangentForOffset(1)!;
        final ang = -math.atan2(t.vector.dy, t.vector.dx) * 180 / math.pi;
        final m = measure(l, days, .9);
        for (final w in widths) {
          final s = cardWidth(w) / 320;
          final per = [
            for (var d = 1; d <= 4; d++) (st[d - 1].dy - st[d].dy) * s
          ];
          final side = [
            for (var d = 1; d <= 4; d++) (st[d].dx - st[d - 1].dx) * s
          ];
          // On screen with today's camera (window clamped at the scene's foot).
          const cam = f0;
          final scr = [
            for (var d = 0; d <= 4; d++)
              (st[d].dy - cam.window(st[d], cardWidth(w)).top) * s
          ];
          out.writeln('R1 ${l.id} ${days}d w$w angle ${f1d(ang)} '
              'rise/step ${per.map(f1d).join(",")} total ${f1d(per.reduce((a, b) => a + b))} '
              'side/step ${side.map(f1d).join(",")} '
              'screenY d0..4 ${scr.map(f1d).join(",")} screenRise ${f1d(scr[0] - scr[4])} '
              'len ${m['length_units']} consGap320 ${m['consecutive_gap_min_pt']} '
              'legGap320 ${m['leg_to_leg_centerline_min_pt']} avatarOver ${m['avatar_covers_other_leg_days']} '
              'facing ${m['facing_change_days']} turns ${m['turn_min_radius_units']}');
        }
      }
    }
  });

  test('R2 numbers', () {
    final st = bSteep.steps(31);
    for (final cam in [f0, f1, f2]) {
      for (final w in widths) {
        final cw = cardWidth(w);
        final s = cam.scale(cw);
        final chords = [
          for (var d = 1; d <= 31; d++) (st[d] - st[d - 1]).distance * s
        ]..sort();
        final win12 = cam.window(st[12], cw);
        var summitDays = <int>[], edgeDays = 0, minEdge = double.infinity;
        final edgeByDay = <String>[];
        for (var d = 0; d <= 31; d++) {
          final win = cam.window(st[d], cw);
          final summit = bSteep.summit(31);
          if (win.contains(summit) && win.top <= summit.dy - 40) {
            summitDays.add(d);
          }
          final e = outlineInside(win) * s;
          minEdge = math.min(minEdge, e);
          if (e >= 40) edgeDays++;
          if (d % 4 == 0 || d == 31) edgeByDay.add('$d:${e.round()}');
        }
        out.writeln(
            'R2 ${cam.id} w$w card ${f1d(cw)} scale ${cam.scale(cw).toStringAsFixed(3)} '
            'visible ${f1d(cw / s)}x${f1d(350 / s)} units, x ${f1d(win12.left)}..${f1d(win12.right)} '
            'avatar ${f1d(58 * s)}pt step min ${f1d(chords.first)} median ${f1d(chords[15])} max ${f1d(chords.last)}pt '
            'box ${f1d(20 * s)}x${f1d(13 * s)}pt '
            'summitDays ${summitDays.isEmpty ? '-' : '${summitDays.first}..${summitDays.last} (${summitDays.length})'} '
            'edge>=40pt days $edgeDays/32 minEdge ${f1d(minEdge)}pt edgeByDay ${edgeByDay.join(" ")} '
            'sky@12 ${(skyShare(win12) * 100).round()}% sky@4 ${(skyShare(cam.window(st[4], cw)) * 100).round()}%');
      }
    }
  });

  testWidgets('R1 images', (tester) async {
    for (final w in widths) {
      final cw = cardWidth(w);
      for (final b in Brightness.values) {
        final mode = b == Brightness.light ? 'light' : 'dark';
        await shoot(
            tester,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              panel(
                  layout: bNow,
                  days: 31,
                  pawnDay: 4,
                  cardW: cw,
                  brightness: b,
                  dashHome: true,
                  caption:
                      'Now: (b), first leg 33°. ${w.round()} pt screen, 31 days, avatar on day 4'),
              const SizedBox(width: 16),
              panel(
                  layout: bSteep,
                  days: 31,
                  pawnDay: 4,
                  cardW: cw,
                  brightness: b,
                  dashHome: true,
                  caption:
                      'Proposed: (b), first leg 45°. ${w.round()} pt screen, 31 days, avatar on day 4'),
            ]),
            Size(cw * 2 + 16 + 24, 740 * cw / 320 + 24 + 36),
            '$docs/r1_curve_${w.round()}_${mode}_31d.png',
            b);
      }
    }
  });

  testWidgets('R2 images', (tester) async {
    for (final w in widths) {
      final cw = cardWidth(w);
      final rows = <Widget>[];
      for (final day in [4, 12, 24]) {
        rows.add(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final cam in [f0, f1, f2]) ...[
            panel(
                layout: bSteep,
                days: 31,
                pawnDay: day,
                cardW: cw,
                brightness: Brightness.light,
                camera: cam,
                caption: '${cam.id} · day $day'),
            const SizedBox(width: 12),
          ]
        ]));
        rows.add(const SizedBox(height: 14));
      }
      await shoot(
          tester,
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows),
          Size(3 * (cw + 12) + 24, 3 * (350 + 14 + 22) + 24),
          '$docs/r2_framing_${w.round()}_light_31d.png',
          Brightness.light);
    }
  });

  testWidgets('R6 images', (tester) async {
    for (final days in [28, 29, 30, 31]) {
      final cw = cardWidth(375);
      final hidden = d2Skip(days).isEmpty
          ? 'all four markers drawn'
          : days == 28
              ? 'day-28 marker merged with the summit'
              : 'day-28 marker hidden (within 2 steps of the summit)';
      await shoot(
          tester,
          panel(
              layout: bSteep,
              days: days,
              pawnDay: 12,
              cardW: cw,
              brightness: Brightness.light,
              caption: '$days days · (b) 45° · $hidden'),
          Size(cw + 24, 740 * cw / 320 + 24 + 40),
          '$docs/r6_markers_${days}d_375_light.png',
          Brightness.light);
    }
  });
}
