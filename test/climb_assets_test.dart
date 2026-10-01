import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Scene art (S1, S4): each theme's illustrated background, light and dark,
/// exported by tool/scene_art/export_assets.py at Batch 0's recommended
/// 1536 × 2048 px (docs/design/scene-art/batch0/report.md, §5.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final backgrounds = [
    for (final theme in [
      'green_slope',
      'ember_peak',
      'glacier_peak',
      'red_canyon'
    ])
      for (final mode in ['light', 'dark'])
        'assets/climb/$theme/background_$mode.webp',
  ];

  const objects = [
    'assets/climb/objects/cabin.webp',
    'assets/climb/objects/campfire.webp',
    'assets/climb/objects/fountain.webp',
    'assets/climb/objects/summit_flag.webp',
    'assets/climb/objects/tent.webp',
  ];
  // Not an object: the campfire's flame only, drawn over it (G6, G8).
  const flame = 'assets/climb/objects/campfire_flame.webp';

  test('the bundle holds the four themes\' backgrounds and the objects',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
        manifest
            .listAssets()
            .where((path) => path.startsWith('assets/climb/'))
            .toSet(),
        {...backgrounds, ...objects, flame});
  });

  Future<ui.Image> decode(String path) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    return (await codec.getNextFrame()).image;
  }

  // Scene art Stage 2: the sources carried invisible alpha = 1 pixels at
  // their corners (Batch 0, the avatar_16 class), and resizing can leave
  // faint alpha cut off from the edge; export_objects.py zeroes both.
  for (final path in [...objects, flame]) {
    test('$path: 192 px wide, decodes, under 16 KB', () async {
      final image = await decode(path);
      expect(image.width, 192);
      expect((await rootBundle.load(path)).lengthInBytes, lessThan(16 * 1024));
    });
  }

  for (final path in objects) {
    test('$path: no alpha > 0 pixel cut off from the object\'s body', () async {
      final image = await decode(path);
      final w = image.width, h = image.height;
      final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
      bool on(int x, int y) => rgba[(y * w + x) * 4 + 3] > 0;
      // 8-connected regions of alpha > 0: there must be exactly one.
      final seen = List<bool>.filled(w * h, false);
      final sizes = <int>[];
      for (var start = 0; start < w * h; start++) {
        if (seen[start] || !on(start % w, start ~/ w)) continue;
        var size = 0;
        final stack = [start];
        seen[start] = true;
        while (stack.isNotEmpty) {
          final i = stack.removeLast();
          size++;
          final x = i % w, y = i ~/ w;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              final nx = x + dx, ny = y + dy;
              if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
              final j = ny * w + nx;
              if (!seen[j] && on(nx, ny)) {
                seen[j] = true;
                stack.add(j);
              }
            }
          }
        }
        sizes.add(size);
      }
      expect(sizes, hasLength(1), reason: 'regions of sizes $sizes');
    });
  }

  for (final path in backgrounds) {
    test('$path decodes to 1536 × 2048 (3:4)', () async {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final image = (await codec.getNextFrame()).image;
      expect(image.width, 1536);
      expect(image.height, 2048);
      // Under 450 KB each: Batch 0 measured 366 and 272 KB at quality 80.
      expect(data.lengthInBytes, lessThan(450 * 1024));
    });
  }
}
