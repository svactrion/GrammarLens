// Trail layouts, cameras and rendering helpers for the Batch 3b report.
// Measuring code only: nothing in lib/ imports it.
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

import 'geo.dart';
import 'scene.dart';

/// Where text results and images go: `DESIGN_MEASURE_OUT`, or
/// `build/design_measure` (git-ignored) when it is not set.
String outDir() {
  final dir =
      Platform.environment['DESIGN_MEASURE_OUT'] ?? 'build/design_measure';
  Directory(dir).createSync(recursive: true);
  return dir;
}

/// Candidate (b) "Wide S" from the Batch 3a study, with its start at [p0].
EvenLayout wideS(String id, Offset p0) => EvenLayout(
    id,
    id,
    filletPolyline([
      p0,
      const Offset(270, 566),
      const Offset(50, 338),
      const Offset(162, 84)
    ], const [
      110,
      110
    ]));

/// (b) as studied in Batch 3a: first leg at 33°.
final bNow = wideS('b (33°)', const Offset(64, 700));

/// (b) as approved in Batch 3b (D1): first leg at 45°.
final bSteep = wideS('b-45 (45°)', const Offset(136, 700));

/// D2: the marker at day d (7, 14, 21, 28) is drawn only if days − d > 2.
Set<int> d2Skip(int days) => {
      for (var i = 0; i < 4; i++)
        if (days - 7 * (i + 1) <= 2) i
    };

/// Card width on Home: width − 2 × clamp(width × 0.045, 16, 28).
double cardWidth(double screen) =>
    screen - 2 * (screen * .045).clamp(16.0, 28.0);

class Camera {
  final String id;

  /// Scene units shown vertically; null is 1.0's rule (scene scaled to the
  /// card's width).
  final double? unitsTall;
  const Camera(this.id, this.unitsTall);

  double scale(double cardW) =>
      unitsTall == null ? cardW / 320 : 350 / unitsTall!;

  /// Visible scene rect with the pawn at 72 % of the 350 pt window, clamped
  /// to the scene vertically; centered on x = 160 when wider than the scene.
  Rect window(Offset pawn, double cardW) {
    final s = scale(cardW);
    final vw = cardW / s, vh = 350 / s;
    final left = unitsTall == null ? 0.0 : 160 - vw / 2;
    final top =
        (pawn.dy - vh * .72).clamp(0.0, math.max(0.0, 740 - vh)).toDouble();
    return Rect.fromLTWH(left, top, vw, vh);
  }
}

const f0 = Camera('F0 today (fit width)', null);
const f1 = Camera('F1 480 units tall', 480);
const f2 = Camera('F2 600 units tall', 600);

/// Mountain outline against the sky (the body polygon without its base).
const outline = [
  Offset(-60, 740),
  Offset(0, 403),
  Offset(42, 264),
  Offset(88, 211),
  Offset(118, 128),
  Offset(162, 56),
  Offset(205, 138),
  Offset(226, 210),
  Offset(279, 286),
  Offset(340, 470),
  Offset(379, 740)
];

/// Length of the outline inside [w], in scene units.
double outlineInside(Rect w) {
  var len = 0.0;
  for (var i = 1; i < outline.length; i++) {
    final a = outline[i - 1], b = outline[i];
    final n = (b - a).distance.ceil();
    for (var k = 0; k < n; k++) {
      final p = Offset.lerp(a, b, (k + .5) / n)!;
      if (w.deflate(2).contains(p)) len += (b - a).distance / n;
    }
  }
  return len;
}

/// Share of [w] that is sky (outside the mountain body), sampled every 4
/// units.
double skyShare(Rect w) {
  var sky = 0, all = 0;
  for (var y = w.top + 2; y < w.bottom; y += 4) {
    for (var x = w.left + 2; x < w.right; x += 4) {
      all++;
      if (!onMountain(Offset(x, y))) sky++;
    }
  }
  return sky / all;
}

/// Loads the bundled font, so text is measured as on a device. Run from the
/// repository root.
Future<void> loadFont() async {
  final bytes = File('assets/fonts/NunitoSans-Variable.ttf').readAsBytesSync();
  await (FontLoader('NunitoSans')
        ..addFont(
            Future.value(ByteData.view(Uint8List.fromList(bytes).buffer))))
      .load();
}

/// One card as Home would show it: [cardW] × 350 placed by [camera], or the
/// whole scene when [camera] is null.
Widget panel({
  required Layout layout,
  required int days,
  required int pawnDay,
  required double cardW,
  required Brightness brightness,
  Camera? camera,
  String? caption,
  bool dashHome = false,
}) {
  final palette = ClimbThemes.greenSlope.paletteFor(brightness);
  final pawn = layout.steps(days)[pawnDay];
  final s = camera?.scale(cardW) ?? cardW / 320;
  final win =
      camera?.window(pawn, cardW) ?? const Rect.fromLTWH(0, 0, 320, 740);
  final h = camera == null ? 740 * s : 350.0;
  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (caption != null)
        Caption(caption, width: cardW, brightness: brightness),
      ClipRRect(
        borderRadius: BorderRadius.circular(camera == null ? 0 : 20),
        child: SizedBox(
          width: cardW,
          height: h,
          child: ColoredBox(
            color: palette.sky,
            child: Stack(children: [
              Positioned(
                left: -win.left * s,
                top: -win.top * s,
                width: 320 * s,
                height: 740 * s,
                child: CustomPaint(
                    painter: StudyPainter(
                        layout: layout,
                        days: days,
                        progress: pawnDay.toDouble(),
                        palette: palette,
                        skipMarkers: d2Skip(days),
                        window: dashHome ? f0.window(pawn, cardW) : null)),
              ),
              Positioned(
                  left: (pawn.dx - 29 - win.left) * s,
                  top: (pawn.dy - 55 - win.top) * s,
                  child:
                      AvatarTile(avatar: Avatar.values.first, radius: 29 * s)),
            ]),
          ),
        ),
      ),
    ],
  );
}

class Caption extends StatelessWidget {
  final String text;
  final double width;
  final Brightness brightness;
  const Caption(this.text,
      {super.key, required this.width, required this.brightness});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'NunitoSans',
                  decoration: TextDecoration.none,
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                  color: brightness == Brightness.light
                      ? const Color(0xFF263D39)
                      : const Color(0xFFE4E2D8))),
        ),
      );
}

/// Renders [child] at [size] pt on a plain background and writes a PNG at
/// 2× to [file].
Future<void> shoot(WidgetTester tester, Widget child, Size size, String file,
    Brightness brightness) async {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  final key = GlobalKey();
  await tester.pumpWidget(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(brightness),
    home: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: brightness == Brightness.light
              ? const Color(0xFFFFFFFF)
              : const Color(0xFF101416),
          padding: const EdgeInsets.all(12),
          child: child,
        ),
      ),
    ),
  ));
  await tester.runAsync(() => precacheImage(
      AssetImage(Avatar.values.first.assetPath), key.currentContext!));
  await tester.pump();
  await writePng(tester, key, file);
}

Future<void> writePng(WidgetTester tester, GlobalKey key, String file) =>
    tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(file).writeAsBytesSync(bytes!.buffer.asUint8List());
    });
