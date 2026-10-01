import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:flutter_test/flutter_test.dart';

/// Scene art (S1, S4): Green Slope's illustrated background, light and dark,
/// exported by tool/scene_art/export_assets.py at Batch 0's recommended
/// 1536 × 2048 px (docs/design/scene-art/batch0/report.md, §5.1).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const backgrounds = [
    'assets/climb/green_slope/background_light.webp',
    'assets/climb/green_slope/background_dark.webp',
  ];

  test('the bundle holds exactly the two Green Slope backgrounds', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
        manifest
            .listAssets()
            .where((path) => path.startsWith('assets/climb/'))
            .toSet(),
        backgrounds.toSet());
  });

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
