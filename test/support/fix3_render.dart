import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';

/// Fix round 3: screens at a phone's size in the app's font and icons,
/// and (with `FIX3_CAPTURE=1`) a PNG of them in `build/fix3-captures/`,
/// for the sizes and states no simulator capture covers.
final fix3Boundary = GlobalKey();

bool _fontsLoaded = false;

Future<void> loadFix3Fonts() async {
  if (_fontsLoaded) return;
  await (FontLoader('NunitoSans')
        ..addFont(rootBundle.load('assets/fonts/NunitoSans-Variable.ttf')))
      .load();
  try {
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  } catch (_) {
    // Without the icon font the icons draw as boxes; the layout is the same.
  }
  _fontsLoaded = true;
}

Future<void> pumpFix3(WidgetTester tester, Widget home,
    {Size size = const Size(390, 844),
    double top = 47,
    double bottom = 34,
    Brightness brightness = Brightness.light,
    AppTextSize textSize = AppTextSize.medium,
    Locale? locale,
    bool settle = true}) async {
  await loadFix3Fonts();
  tester.view.physicalSize = size * 3.0;
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = FakeViewPadding(top: top * 3, bottom: bottom * 3);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: fix3Boundary,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(brightness, textSize: textSize),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: home,
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Future<void> fix3Capture(WidgetTester tester, String name,
        {bool dark = false}) =>
    _capture(tester, name, dark: dark, round: 3);

/// Fix round 4: the same, with `FIX4_CAPTURE=1`, into
/// `build/fix4-captures/[dark/]`.
Future<void> fix4Capture(WidgetTester tester, String name,
        {bool dark = false}) =>
    _capture(tester, name, dark: dark, round: 4);

/// Fix round 5: the same, with `FIX5_CAPTURE=1`, into
/// `build/fix5-captures/[dark/]`.
Future<void> fix5Capture(WidgetTester tester, String name,
        {bool dark = false}) =>
    _capture(tester, name, dark: dark, round: 5);

Future<void> _capture(WidgetTester tester, String name,
    {required bool dark, required int round}) async {
  if (Platform.environment['FIX${round}_CAPTURE'] != '1') return;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  await tester.runAsync(() async {
    final render = fix3Boundary.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await render.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final out =
        File('build/fix$round-captures/${dark ? 'dark/' : ''}$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

/// Fix round 4: one table row of measured numbers per render
/// (`FIX4_CAPTURE=1`: `build/fix4-captures/<file>`).
void recordFix4(String file, String row) {
  if (Platform.environment['FIX4_CAPTURE'] != '1') return;
  final out = File('build/fix4-captures/$file');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$row\n', mode: FileMode.append);
}

/// Fix round 5: one table row of measured numbers per render
/// (`FIX5_CAPTURE=1`: `build/fix5-captures/<file>`).
void recordFix5(String file, String row) {
  if (Platform.environment['FIX5_CAPTURE'] != '1') return;
  final out = File('build/fix5-captures/$file');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync('$row\n', mode: FileMode.append);
}

/// Fix round 6: frames of one run side by side. [fix6Frame] takes the
/// screen now (with `FIX6_CAPTURE=1`; null otherwise), [fix6Strip] writes
/// the frames, left to right, as `build/fix6-captures/[dark/]<name>.png`.
Future<ui.Image?> fix6Frame(WidgetTester tester) async {
  if (Platform.environment['FIX6_CAPTURE'] != '1') return null;
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
  return tester.runAsync(() {
    final render = fix3Boundary.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    return render.toImage(pixelRatio: 1);
  });
}

Future<void> fix6Strip(WidgetTester tester, String name, List<ui.Image?> frames,
    {bool dark = false}) async {
  final images = frames.whereType<ui.Image>().toList();
  if (images.isEmpty) return;
  await tester.runAsync(() async {
    const gap = 8.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final width = images.fold<double>(0, (w, i) => w + i.width) +
        gap * (images.length - 1);
    final height = images.fold<int>(0, (h, i) => i.height > h ? i.height : h);
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height.toDouble()),
        Paint()..color = const Color(0xFF808080));
    var x = 0.0;
    for (final image in images) {
      canvas.drawImage(image, Offset(x, 0), Paint());
      x += image.width + gap;
    }
    final strip = await recorder.endRecording().toImage(width.round(), height);
    final bytes = await strip.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/fix6-captures/${dark ? 'dark/' : ''}$name.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}
