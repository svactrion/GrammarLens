import 'dart:io';
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'geometry.dart';
import 'shell.dart';
import 'common.dart';

/// Sky share: not the body, a foothill or a back layer.
double skyShare(Candidate c, Rect w) {
  final back = [
    for (final (_, pts) in c.backLayers) Path()..addPolygon(pts, true)
  ];
  var sky = 0, all = 0;
  for (var y = w.top + 2; y < w.bottom; y += 4) {
    for (var x = w.left + 2; x < w.right; x += 4) {
      all++;
      final p = Offset(x, y);
      if (!c.onGround(p) && !back.any((b) => b.contains(p))) sky++;
    }
  }
  return sky / all;
}

void main() {
  test('framing', () {
    final out = StringBuffer();
    for (final c in candidates) {
      for (final f in [f1, whole]) {
        for (final screen in [320.0, 375.0, 430.0]) {
          final w = cardWidth(screen);
          final s = f.scale;
          Rect win(int day) {
            final top = f.top(c.stepAt(day, 31)) / s;
            final left = -f.sceneLeft(w) / s;
            return Rect.fromLTWH(left, top, w / s, 350 / s);
          }

          final summitDays = [
            for (var d = 0; d <= 31; d++)
              if (win(d).contains(c.summit + const Offset(0, -36)) &&
                  win(d).contains(c.summit))
                d
          ];
          out.writeln('${c.id} ${f.id.padRight(26)} ${screen.toInt()} pt: '
              'avatar ${(58 * s).toStringAsFixed(1)} pt, day step ${(c.metric.length / 31 * s).toStringAsFixed(1)} pt, '
              'summit in frame on days ${summitDays.isEmpty ? '-' : '${summitDays.first}–${summitDays.last}'}, '
              'sky day 3 ${(skyShare(c, win(3)) * 100).round()} %, day 25 ${(skyShare(c, win(25)) * 100).round()} %');
        }
      }
    }
    File('${outDir()}/framing_numbers.txt').writeAsStringSync(out.toString());
  });
}
