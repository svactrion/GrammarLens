import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_scene.dart';

String hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

double distance(Color a, Color b) {
  double d(double x, double y) => (x - y) * (x - y);
  return d(a.r, b.r) + d(a.g, b.g) + d(a.b, b.b);
}

/// Batch 3c e: a mountain that reads as one, in flat colors, the same
/// shapes for every theme; tones derived from the palette by one rule.
void main() {
  group('tones from Green Slope, as proposed in the 3c-A report', () {
    final light =
        ClimbSceneTones.of(ClimbThemes.greenSlope.paletteFor(Brightness.light));
    final dark =
        ClimbSceneTones.of(ClimbThemes.greenSlope.paletteFor(Brightness.dark));

    test('light', () {
      expect(
          [light.farRidge, light.midRidge, light.litFace, light.shadowFace]
              .map(hex),
          ['#D0DED1', '#C0D2C0', '#ACC4AC', '#789B86']);
      expect([light.foothill, light.pine, light.trunk, light.shrub].map(hex),
          ['#9DB9A1', '#597769', '#3F5950', '#83A48E']);
    });

    test('dark', () {
      expect(
          [dark.farRidge, dark.midRidge, dark.litFace, dark.shadowFace]
              .map(hex),
          ['#293B39', '#334A45', '#405C53', '#2E463F']);
      expect([dark.foothill, dark.pine, dark.trunk, dark.shrub].map(hex),
          ['#3B564D', '#263936', '#1F2E2E', '#324B43']);
    });

    test('farther layers are closer to the sky, in both modes', () {
      for (final t in [light, dark]) {
        expect(
            distance(t.farRidge, t.sky), lessThan(distance(t.midRidge, t.sky)));
        expect(
            distance(t.midRidge, t.sky), lessThan(distance(t.litFace, t.sky)));
      }
    });
  });

  test('the rule works for any palette (Batch 4 themes)', () {
    const palette = ClimbPalette(
        sky: Color(0xFF000000),
        mountain: Color(0xFFFFFFFF),
        ridge: Color(0xFF808080),
        trail: Color(0xFF000000),
        stone: Color(0xFF111111),
        ink: Color(0xFF222222),
        accent: Color(0xFF333333));
    final t = ClimbSceneTones.of(palette);
    expect(t.litFace, palette.mountain);
    expect(t.shadowFace, palette.ridge);
    expect(t.cap, palette.stone);
  });

  test('the silhouette is concave: it widens faster toward the foot', () {
    final right = ClimbScene.body
        .where((p) => p.dx > ClimbScene.peak.dx)
        .toList(); // top to bottom
    // Below the shoulders: the first eighth ramps out to the summit's
    // half-width (22 units) so the peak is not a needle.
    for (var i = 10; i < right.length; i++) {
      final a = right[i - 1].dx - right[i - 2].dx;
      final b = right[i].dx - right[i - 1].dx;
      expect(b, greaterThanOrEqualTo(a - 1e-9), reason: 'at ${right[i]}');
    }
  });

  test('the trail runs on the ground from the foot to the summit', () {
    final metric = ClimbRoute(31).path.computeMetrics().single;
    for (var s = 0.0; s <= metric.length; s += 1) {
      final p = metric.getTangentForOffset(s)!.position;
      expect(ClimbScene.onGround(p), isTrue, reason: '$p');
    }
    expect(ClimbScene.peak.dy, lessThan(ClimbRoute.summit.dy));
  });
}
