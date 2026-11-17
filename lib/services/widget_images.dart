import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// The widgets' images (TASK-widgets fixed decision 3): the app scales its
/// own assets down to the widget's size and writes them as PNG files into
/// the App Group; no app asset is copied into the extension.

/// The medium widget's mountain crop at 3×.
const widgetMountainSize = ui.Size(1092, 510);

/// The avatar at 3× of its largest widget size (74 pt) and a little more.
const widgetAvatarSize = 240;

/// Decodes the asset at [path].
Future<ui.Image> loadAssetImage(String path, {AssetBundle? bundle}) async {
  final data = await (bundle ?? rootBundle).load(path);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// [source]'s part [rect] (fractions of its width and height) drawn at
/// [size], as PNG bytes.
Future<Uint8List> renderCrop(ui.Image source, ui.Rect rect, ui.Size size) {
  final from = ui.Rect.fromLTWH(
    rect.left * source.width,
    rect.top * source.height,
    rect.width * source.width,
    rect.height * source.height,
  );
  return _render(size, (canvas) {
    canvas.drawImageRect(source, from, ui.Offset.zero & size,
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
  });
}

/// [source] fitted into a [side] × [side] square, as PNG bytes.
Future<Uint8List> renderSquare(ui.Image source, int side) {
  final size = ui.Size.square(side.toDouble());
  final scale =
      side / (source.width > source.height ? source.width : source.height);
  final w = source.width * scale, h = source.height * scale;
  final to = ui.Rect.fromLTWH((side - w) / 2, (side - h) / 2, w, h);
  return _render(size, (canvas) {
    canvas.drawImageRect(
        source,
        ui.Rect.fromLTWH(
            0, 0, source.width.toDouble(), source.height.toDouble()),
        to,
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
  });
}

Future<Uint8List> _render(ui.Size size, void Function(ui.Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(ui.Canvas(recorder));
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.round(), size.height.round());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
