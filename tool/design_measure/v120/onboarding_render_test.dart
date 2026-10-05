// Additional screens Batch 11: the two onboarding steps with the real font,
// light and dark; step 1 also with the keyboard open (a grey box over the
// inset; the system keyboard is not part of the app).
//
//   DESIGN_MEASURE_OUT=build/design_measure/v120_onboarding \
//     flutter test tool/design_measure/v120/onboarding_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/learning_goal.dart';
import 'package:grammar_lens/screens/onboarding_screen.dart';
import 'package:grammar_lens/theme.dart';

import '../layouts.dart' show loadFont, loadIconFont, outDir;

typedef _Case = ({
  String name,
  double width,
  double height,
  double keyboard,
  AppTextSize size,
  int step,
  bool sheet,
});

const List<_Case> _cases = [
  (
    name: '390_step1',
    width: 390,
    height: 844,
    keyboard: 0,
    size: AppTextSize.medium,
    step: 1,
    sheet: false
  ),
  (
    name: '390_step1_keyboard',
    width: 390,
    height: 844,
    keyboard: 336,
    size: AppTextSize.medium,
    step: 1,
    sheet: false
  ),
  (
    name: '390_step2',
    width: 390,
    height: 844,
    keyboard: 0,
    size: AppTextSize.medium,
    step: 2,
    sheet: false
  ),
  (
    name: '390_sheet',
    width: 390,
    height: 844,
    keyboard: 0,
    size: AppTextSize.medium,
    step: 2,
    sheet: true
  ),
  (
    name: '320_step1_large_keyboard',
    width: 320,
    height: 568,
    keyboard: 260,
    size: AppTextSize.large,
    step: 1,
    sheet: false
  ),
  (
    name: '320_step2_large',
    width: 320,
    height: 568,
    keyboard: 0,
    size: AppTextSize.large,
    step: 2,
    sheet: false
  ),
];

void main() {
  final out = outDir();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  for (final c in _cases) {
    for (final b in Brightness.values) {
      final file = 'onboarding_${c.name}_${b.name}';
      testWidgets(file, (tester) async {
        tester.view.physicalSize = Size(c.width, c.height) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = FakeViewPadding(
            top: (c.width < 360 ? 20 : 47) * 3,
            bottom: c.keyboard > 0 ? 0 : 34 * 3);
        tester.view.viewInsets = FakeViewPadding(bottom: c.keyboard * 3);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [
              MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: buildAppTheme(b, textSize: c.size),
                home: OnboardingScreen(onComplete: (_) {}),
              ),
              if (c.keyboard > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: c.keyboard,
                  child: ColoredBox(
                    color: b == Brightness.dark
                        ? const Color(0xFF252527)
                        : const Color(0xFFD7D5D2),
                  ),
                ),
            ]),
          ),
        ));
        await tester.pumpAndSettle();
        // Every avatar decoded before the shot (image decoding is real I/O).
        await tester.runAsync(() => Future.wait([
              for (final a in Avatar.values)
                precacheImage(AssetImage(a.assetPath), key.currentContext!),
            ]));
        await tester.pumpAndSettle();
        await tester.enterText(
            find.byKey(OnboardingScreen.nameFieldKey), 'Ada');
        await tester.pumpAndSettle();
        if (c.keyboard == 0) {
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        if (c.step == 2) {
          await tester.tap(find.byKey(OnboardingScreen.continueKey));
          await tester.pumpAndSettle();
          await tester
              .tap(find.byKey(OnboardingScreen.goalKey(LearningGoal.work)));
          await tester.pumpAndSettle();
        }
        if (c.sheet) {
          await tester.ensureVisible(find.byKey(OnboardingScreen.dataLinkKey));
          await tester.tap(find.byKey(OnboardingScreen.dataLinkKey));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final img = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$file.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
