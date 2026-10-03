// Batch 5 step 2 (N31, N32): the scene with the avatar on each save point's
// step and on the last step, October 2026 (31 days, Green Slope), light.
// The real MonthlyMountain at a card width, mounted on that step (no hop).
// STEPS_LABEL names the files (before / after); STEPS_WIDTHS (default
// 375) the screens; STEPS_ENDING = flag / tip renders the last step with
// that ending (ClimbRoute.debugEndsAtFlagOverride, after N32 only).
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_steps STEPS_LABEL=after \
//     flutter test tool/design_measure/batch5/steps_render_test.dart
// Run on the commit before N31 (a separate worktree, with this file copied
// in and a steps_render_hooks.dart whose setEnding does nothing and whose
// extraAssets lists the signpost) with STEPS_LABEL=before for the "before"
// frames, then
//   build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py steps
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../layouts.dart' show loadFont, outDir, writePng;
import 'steps_render_hooks.dart';

const _windows = {320: 288.0, 375: 341.25, 430: 391.3};

void main() {
  final out = outDir();
  final label = Platform.environment['STEPS_LABEL'] ?? 'after';
  final ending = Platform.environment['STEPS_ENDING'];
  final widths = [
    for (final w in (Platform.environment['STEPS_WIDTHS'] ?? '375').split(','))
      int.parse(w.trim())
  ];
  setUpAll(loadFont);

  final cases = <(String, int)>[
    if (ending == null)
      for (final p in ClimbSavePoints.all) (p.clearing, p.reachedOn(31)),
    ('C6', 31),
  ];
  for (final screen in widths) {
    for (final (clearing, step) in cases) {
      final name = ending == null
          ? 'steps_${label}_${clearing}_$screen.png'
          : 'summit_${ending}_$screen.png';
      testWidgets(name, (tester) async {
        if (ending != null) {
          // Only the build after N32 has the switch (steps_render_hooks).
          setEnding(ending == 'flag');
          addTearDown(() => setEnding(null));
        }
        final window = _windows[screen]!;
        tester.view.physicalSize = Size(window, 350) * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(Brightness.light),
          home: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: window,
                child: MonthlyMountain(
                    days: 31,
                    completedDays: step,
                    avatar: Avatar.values.first,
                    showPassedDayDots: true),
              ),
            ),
          ),
        ));
        await tester.runAsync(() => Future.wait([
              for (final asset in [
                Avatar.values.first.assetPath,
                ClimbThemes.greenSlope.backgroundFor(Brightness.light),
                for (final p in ClimbSavePoints.all) p.asset,
                ClimbSavePoints.assetFor('summit_flag'),
                ClimbSavePoints.flameAsset,
                ...extraAssets(),
              ])
                precacheImage(AssetImage(asset), key.currentContext!),
            ]));
        await tester.pump();
        await writePng(tester, key, '$out/$name');
      });
    }
  }
}
