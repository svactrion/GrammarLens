import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/mountain_intro_screen.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/mountain_scene.dart';

/// Fix round 2, item 9: on the owner's iPhone 14 Plus the V06 flag was not
/// on the summit. The flag stood on the climb's flag point on the trail,
/// short of the peak, which cover-scaling magnifies on a tall phone. Now
/// its foot is the summit (the trail table's last point) in image
/// coordinates, on every screen size and every scene (V06, V12, R04, R04b,
/// the rest scene share [MountainScene]).
///
/// Set `CAPTURE_FLAG=1` to also write the renders to
/// `build/ui-polish-captures/V06-flag-<w>x<h>.png` (fix round 2 evidence).
void main() {
  test(
      'the flag stands on the trail\'s last point, not the climb\'s flag '
      'point', () {
    expect(MountainScene.flagPoint, ClimbRoute.summit);
    expect(ClimbRoute.summit, ClimbRoute.trail.last);
    // The trail table's last point is its highest.
    final highest = ClimbRoute.trail.reduce((a, b) => a.dy <= b.dy ? a : b);
    expect(ClimbRoute.summit, highest);
  });

  for (final size in [
    const Size(428, 926), // iPhone 14 Plus (the owner's)
    const Size(375, 667), // iPhone SE: a wider ratio
    const Size(440, 956), // iPhone 18 Pro Max (this round's simulator)
    const Size(1024, 1366), // iPad Pro 12.9": cover-scaled by width
  ]) {
    testWidgets(
        'V06 at ${size.width.toInt()} × ${size.height.toInt()}: the '
        'pole\'s foot on the summit of the art', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          theme: buildAppTheme(Brightness.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MountainIntroScreen(
            theme: ClimbThemes.greenSlope,
            hero: Avatar.fox,
            days: 30,
            monthName: 'November',
            onStart: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // The art's rect: the scene's first image, cover-fitted.
      final scene = find.byType(MountainScene);
      final art = tester.getRect(
          find.descendant(of: scene, matching: find.byType(Image)).first);
      // The intro's scale-in (0.9 → 1) has finished: the art is not
      // transformed any more.
      final flag = tester.getRect(find.byKey(MountainScene.flagKey));
      final poleW = flag.height / 4;
      final foot = Offset(flag.left + poleW / 2,
          flag.top + flag.height * MountainScene.poleFoot);
      final summit = art.topLeft + ClimbRoute.summit * art.width;
      expect(foot.dx, closeTo(summit.dx, .5), reason: 'x at $size');
      expect(foot.dy, closeTo(summit.dy, .5), reason: 'y at $size');
      // The summit is on screen, inside the scene.
      expect(tester.getRect(scene).contains(summit), isTrue);

      if (Platform.environment['CAPTURE_FLAG'] == '1') {
        await tester.runAsync(() async {
          // Let the images decode before the render.
          for (final element in find.byType(Image).evaluate()) {
            final image = element.widget as Image;
            await precacheImage(image.image, element);
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final render = boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final out = File('build/ui-polish-captures/'
              'V06-flag-${size.width.toInt()}x${size.height.toInt()}.png');
          out.parent.createSync(recursive: true);
          out.writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      }
    });
  }
}
