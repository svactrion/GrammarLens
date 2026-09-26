import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

/// The iOS static launch screen must be identical to the launch splash's
/// first frame: same logo, same place, same size. These checks fail when the
/// logo or the layout changes without `scripts/generate_launch_image.sh`
/// being run again.
const _imageSet = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
const _storyboard = 'ios/Runner/Base.lproj/LaunchScreen.storyboard';

String _fileName(Brightness brightness, int scale) {
  final base =
      brightness == Brightness.dark ? 'LaunchImageDark' : 'LaunchImage';
  return scale == 1 ? '$base.png' : '$base@${scale}x.png';
}

Future<(int, int, Uint8List)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final result = (image.width, image.height, rgba!.buffer.asUint8List());
  image.dispose();
  return result;
}

void main() {
  test('the asset catalog has @1x/@2x/@3x in a light and a dark variant', () {
    final json = jsonDecode(File('$_imageSet/Contents.json').readAsStringSync())
        as Map<String, dynamic>;
    final entries = {
      for (final image in json['images'] as List)
        image['filename']: (
          image['scale'],
          (image['appearances'] as List?)?.single['value'],
        ),
    };
    for (final brightness in Brightness.values) {
      for (final scale in [1, 2, 3]) {
        expect(entries[_fileName(brightness, scale)],
            ('${scale}x', brightness == Brightness.dark ? 'dark' : null));
      }
    }
  });

  test('the storyboard places the image where the splash draws the logo', () {
    final storyboard = File(_storyboard).readAsStringSync();
    const size = LaunchSplashLayout.logoSize;
    expect(
        storyboard,
        contains('<image name="LaunchImage" width="${size.toInt()}" '
            'height="${size.toInt()}"/>'));
    expect(storyboard, contains('image="LaunchImage"'));
    expect(storyboard, contains('contentMode="center"'));
    // Centered horizontally, offset vertically like the splash's logo.
    expect(
        storyboard,
        contains('firstAttribute="centerX" secondItem="Ze5-6b-2t3" '
            'secondAttribute="centerX" id='));
    expect(
        storyboard,
        contains('firstAttribute="centerY" secondItem="Ze5-6b-2t3" '
            'secondAttribute="centerY" '
            'constant="${LaunchSplashLayout.logoCenterOffsetY.toInt()}"'));
  });

  for (final brightness in Brightness.values) {
    testWidgets(
        'the images are the logo at its first-frame scale (${brightness.name})',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(Theme(
        data: buildAppTheme(brightness),
        child: Center(
          child: RepaintBoundary(
            key: key,
            child: const LaunchLogo(scale: LaunchSplashLayout.initialLogoScale),
          ),
        ),
      ));
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      for (final scale in [1, 2, 3]) {
        final file = File('$_imageSet/${_fileName(brightness, scale)}');
        final (committed, rendered) = (await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: scale.toDouble());
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return (
            await _decode(file.readAsBytesSync()),
            await _decode(png!.buffer.asUint8List()),
          );
        }))!;

        final expectedSide = (LaunchSplashLayout.logoSize * scale).toInt();
        expect((committed.$1, committed.$2), (expectedSide, expectedSide),
            reason: '${file.path} size');
        var worst = 0;
        for (var i = 0; i < committed.$3.length; i++) {
          final diff = (committed.$3[i] - rendered.$3[i]).abs();
          if (diff > worst) worst = diff;
        }
        expect(worst, lessThanOrEqualTo(8),
            reason: '${file.path} differs from the logo; run '
                'scripts/generate_launch_image.sh');
      }
    });
  }
}
