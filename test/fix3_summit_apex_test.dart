import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/mountain_intro_screen.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_summit_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';

import 'support/fix3_render.dart';

/// Fix round 3, B6 (SPEC V06): the summit flag stands on each mountain
/// art's own apex, measured from the image (light and dark) by
/// `tool/scene_art/summit_apex.py` into `climb_summit_table.dart`, not on
/// the trail's last point under the peak.
///
/// With `FIX3_CAPTURE=1` the V06 renders go to `build/fix3-captures/`
/// (light) and `build/fix3-captures/dark/`: this month (November 2026,
/// Ember Peak) and the other three themes' months.
const _months = {
  'green_slope': 'October',
  'ember_peak': 'November',
  'glacier_peak': 'December',
  'red_canyon': 'January',
};

/// The art's pixels around the peak, to check the measured apex.
class _Art {
  final int width;
  final int height;
  final ByteData rgba;
  _Art(this.width, this.height, this.rgba);

  List<int> px(int x, int y) {
    final i = (y * width + x) * 4;
    return [rgba.getUint8(i), rgba.getUint8(i + 1), rgba.getUint8(i + 2)];
  }

  /// The sky at row [y]: the mean of the measuring window's outer columns
  /// (the tool's model).
  List<double> sky(int y) {
    final k = width / 1536;
    final x0 = (580 * k).round(), x1 = ((580 + 400) * k).round();
    final cols = [
      for (var x = x0 + 3; x < x0 + 18; x++) x,
      for (var x = x1 - 18; x < x1 - 3; x++) x,
    ];
    final sum = [0.0, 0.0, 0.0];
    for (final x in cols) {
      final p = px(x, y);
      for (var i = 0; i < 3; i++) {
        sum[i] += p[i];
      }
    }
    return [for (final s in sum) s / cols.length];
  }

  double skyDistance(int x, int y) {
    final p = px(x, y), s = sky(y);
    var d = 0.0;
    for (var i = 0; i < 3; i++) {
      d += (p[i] - s[i]) * (p[i] - s[i]);
    }
    return d < 0 ? 0 : _sqrt(d);
  }

  static double _sqrt(double v) {
    var x = v, last = 0.0;
    if (v == 0) return 0;
    while ((x - last).abs() > 1e-6) {
      last = x;
      x = (x + v / x) / 2;
    }
    return x;
  }
}

Future<_Art> _decode(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return _Art(image.width, image.height, rgba!);
}

void main() {
  final themes = ClimbThemes.all.where((t) => t.ready).toList();

  test('every ready theme\'s art, light and dark, has a measured apex', () {
    for (final theme in themes) {
      for (final b in Brightness.values) {
        expect(climbSummitApex[theme.backgroundFor(b)], isNotNull,
            reason: '${theme.id} $b');
        expect(MountainScene.apexFor(theme, b), isNotNull);
      }
    }
    // No stale rows: each row is one of the themes' images.
    final images = {
      for (final t in themes)
        for (final b in Brightness.values) t.backgroundFor(b)
    };
    expect(images.containsAll(climbSummitApex.keys), isTrue);
  });

  test(
      'the apex is above and left of the trail\'s end, near the art\'s '
      'middle; the light and dark art agree within 10 px', () {
    for (final theme in themes) {
      final light = MountainScene.apexFor(theme, Brightness.light)!;
      final dark = MountainScene.apexFor(theme, Brightness.dark)!;
      for (final a in [light, dark]) {
        expect(a.dy, lessThan(ClimbRoute.summit.dy - .05), reason: theme.id);
        expect(a.dx, lessThan(ClimbRoute.summit.dx), reason: theme.id);
        expect(a.dx, inInclusiveRange(.45, .56), reason: theme.id);
      }
      expect((light - dark).distance, lessThan(10 / 1536), reason: theme.id);
      // The pole's foot: the apex, sunk into the rock or snow.
      expect(MountainScene.flagPointFor(theme, Brightness.light),
          light + const Offset(0, MountainScene.poleSink));
    }
  });

  testWidgets(
      'the measured point is the art\'s highest: mountain at and under it, '
      'sky above it across the whole peak', (tester) async {
    for (final theme in themes) {
      for (final b in Brightness.values) {
        final asset = theme.backgroundFor(b);
        final art = (await tester.runAsync(() => _decode(asset)))!;
        final (nx, ny) = climbSummitApex[asset]!;
        final ax = (nx * art.width).round(), ay = (ny * art.height).round();
        // Mountain at the apex and just under it.
        for (var dy = 0; dy <= 6; dy += 2) {
          expect(art.skyDistance(ax, ay + dy), greaterThan(20),
              reason: '$asset: mountain at ($ax, ${ay + dy})');
        }
        // Nothing of the mountain 6 px higher, 40 px either side.
        for (var dx = -40; dx <= 40; dx += 4) {
          expect(art.skyDistance(ax + dx, ay - 6), lessThan(45),
              reason: '$asset: sky at (${ax + dx}, ${ay - 6})');
        }
      }
    }
  });

  for (final theme in ClimbThemes.all.where((t) => t.ready)) {
    for (final b in Brightness.values) {
      final dark = b == Brightness.dark;
      testWidgets(
          'V06, ${theme.id}, ${dark ? 'dark' : 'light'}: the pole\'s foot on '
          'the apex, the whole flag in the scene', (tester) async {
        await pumpFix3(
          tester,
          MountainIntroScreen(
            theme: theme,
            hero: Avatar.fox,
            days: 30,
            monthName: _months[theme.id]!,
            onStart: () {},
          ),
          size: const Size(402, 874),
          top: 62,
          brightness: b,
        );
        final scene = find.byType(MountainScene);
        final art = tester.getRect(
            find.descendant(of: scene, matching: find.byType(Image)).first);
        final flag = tester.getRect(find.byKey(MountainScene.flagKey));
        final poleW = flag.height / 4;
        final foot = Offset(flag.left + poleW / 2,
            flag.top + flag.height * MountainScene.poleFoot);
        final apex =
            art.topLeft + MountainScene.flagPointFor(theme, b) * art.width;
        expect(foot.dx, closeTo(apex.dx, .5));
        expect(foot.dy, closeTo(apex.dy, .5));
        // The pole's top is inside the scene: nothing cut off.
        expect(flag.top, greaterThanOrEqualTo(tester.getRect(scene).top));
        await fix3Capture(
            tester, 'V06-${theme.id}-${_months[theme.id]!.toLowerCase()}',
            dark: dark);
      });
    }
  }
}
