import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
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

  test('the bundle holds exactly Avatar.count avatar files, no more, no less',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final bundled = manifest
        .listAssets()
        .where((path) => path.startsWith('assets/avatars/'))
        .toSet();
    expect(bundled, Avatar.values.map((a) => a.assetPath).toSet());
    expect(bundled.length, 16);
  });

  test('every avatar asset decodes to 508×508 with a real alpha channel',
      () async {
    for (final avatar in Avatar.values) {
      final image = await decodeAsset(avatar.assetPath);
      expect(image.width, 508, reason: avatar.assetPath);
      expect(image.height, 508, reason: avatar.assetPath);
      final bytes = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!
          .buffer
          .asUint8List();
      var transparent = 0;
      var opaque = 0;
      for (var i = 3; i < bytes.length; i += 4) {
        if (bytes[i] == 0) transparent++;
        if (bytes[i] == 255) opaque++;
      }
      // Decoded alpha, not the file extension: a flattened (no-alpha)
      // export would decode fully opaque and fail the first check.
      expect(transparent, greaterThan(0), reason: avatar.assetPath);
      expect(opaque, greaterThan(0), reason: avatar.assetPath);
    }
  });

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
