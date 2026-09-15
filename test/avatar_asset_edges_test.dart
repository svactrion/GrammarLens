import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';

/// Regression test for the vertical-line bug found in `avatar_07.webp`
/// (docs/build-log.md, Avatar carousel batch): columns 1–3 of that asset
/// carried a translucent stray stripe running the asset's full height,
/// baked into the shipped file itself — not a render or layout defect, so
/// no widget-level test could have caught it. This test decodes every
/// bundled avatar's real bytes (not a mock) and checks its outermost
/// pixel ring directly, the actual path that bug lived in.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ui.Image> decodeAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  test('every avatar asset has a fully transparent 1px edge on all sides',
      () async {
    for (final avatar in Avatar.values) {
      final image = await decodeAsset(avatar.assetPath);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(byteData, isNotNull,
          reason: '${avatar.assetPath} failed to decode to raw RGBA');
      final bytes = byteData!.buffer.asUint8List();
      final width = image.width;
      final height = image.height;

      int alphaAt(int x, int y) => bytes[(y * width + x) * 4 + 3];

      final edgeAlphas = <int>[
        for (var y = 0; y < height; y++) alphaAt(0, y),
        for (var y = 0; y < height; y++) alphaAt(width - 1, y),
        for (var x = 0; x < width; x++) alphaAt(x, 0),
        for (var x = 0; x < width; x++) alphaAt(x, height - 1),
      ];

      expect(
        edgeAlphas.every((a) => a == 0),
        isTrue,
        reason: '${avatar.assetPath} has non-transparent pixels on its '
            'outermost edge (${avatar.semanticLabel}) — exactly the class '
            'of defect avatar_07.webp shipped with once',
      );
    }
  });
}
