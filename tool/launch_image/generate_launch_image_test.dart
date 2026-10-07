// Renders the iOS static launch image from the app's own logo widget.
// Run through scripts/generate_launch_image.sh, not as part of `flutter test`
// (which only runs test/).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/launch_splash.dart';

const _imageSet = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
const _scales = [1, 2, 3];

String _fileName(Brightness brightness, int scale) {
  final base =
      brightness == Brightness.dark ? 'LaunchImageDark' : 'LaunchImage';
  return scale == 1 ? '$base.png' : '$base@${scale}x.png';
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('renders the launch image (${brightness.name})',
        (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(Theme(
        data: buildAppTheme(brightness),
        child: Center(
          child: RepaintBoundary(
            key: key,
            // The splash's first frame: the logo at its initial scale.
            child: const LaunchLogo(
              scale: LaunchSplashLayout.initialLogoScale,
            ),
          ),
        ),
      ));

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      for (final scale in _scales) {
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: scale.toDouble());
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        File('$_imageSet/${_fileName(brightness, scale)}')
            .writeAsBytesSync(bytes!);
      }
    });
  }

  test('writes the asset catalog entry with light and dark variants', () {
    final images = [
      for (final brightness in Brightness.values)
        for (final scale in _scales)
          {
            if (brightness == Brightness.dark)
              'appearances': [
                {'appearance': 'luminosity', 'value': 'dark'},
              ],
            'filename': _fileName(brightness, scale),
            'idiom': 'universal',
            'scale': '${scale}x',
          },
    ];
    final json = const JsonEncoder.withIndent('  ').convert({
      'images': images,
      'info': {'author': 'xcode', 'version': 1},
    });
    File('$_imageSet/Contents.json').writeAsStringSync('$json\n');
  });
}
