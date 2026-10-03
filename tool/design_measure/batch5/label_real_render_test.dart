// Batch 5 step 6 (N6, N19): the real save point label on the real Home.
// October 2026 (31 days, Green Slope): Home is given a pending step, as
// after a Daily Test, so it mounts one step back and hops onto each save
// point's step (the flag's on the 31st); 320 / 375 / 430 pt, Small /
// Medium / Large (buildAppTheme(textSize:) only), light, and dark at
// 375 pt Medium. Captured 1.2 s after the hop ends (the label fully in).
// Writes one PNG per case (the climb card, 3x) and
// save_point_labels_real.txt: the label's box and what it touches (the
// window's edge, the month and step chips with their padding, the plaque,
// the avatar art's box (the largest of the 16 avatars), the other objects
// and the signpost).
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_labels_real \
//     flutter test tool/design_measure/batch5/label_real_render_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py labels_real
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/screens/home_screen.dart';
import 'package:grammar_lens/services/analytics_service.dart';
import 'package:grammar_lens/services/claude_service.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/floating_nav_shell.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/save_point_labels_real.txt').writeAsStringSync([
        'Batch 5 step 6 (N19): the real label on the real Home, October '
            '2026 (31 days), light. Points. top room: the label\'s top '
            'below the window\'s top; chips: the month chip\'s bottom '
            '(ClimbCard.chipRects); touches: what the label\'s box overlaps '
            '(the avatar: the share of its art\'s box covered).',
        '',
        'object              step  width text    label w x h     top room  chips  touches',
        ...rows,
      ].join('\n')));

  final combos = [
    for (final screen in [320.0, 375.0, 430.0])
      for (final size in AppTextSize.values) (screen, size, Brightness.light),
    (375.0, AppTextSize.medium, Brightness.dark),
  ];
  for (final p in [...ClimbSavePoints.all, ClimbSavePoints.flag]) {
    for (final (screen, size, b) in combos) {
      final step = p.reachedOn(31);
      final name =
          'label_${p.clearing}_${screen.toInt()}_${b.name}_${size.name}';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = Size(screen, 1400) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 60);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(b, textSize: size),
            home: FloatingNavShell(
              body: HomeScreen(
                active: true,
                userName: 'Ada',
                avatar: Avatar.values.first,
                claudeService: ClaudeService(),
                storageService: DesignStorage(steps: step, correct: step * 3),
                analyticsService: AnalyticsService(),
                subscriptionService: DesignSubs(),
                clock: () => DateTime(2026, 10, 31, 14),
                initialPendingClimb: (day: '2026-10-31', step: 1),
              ),
              tabs: const [
                NavShellTab(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: 'Home'),
                NavShellTab(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Profile'),
              ],
              selectedIndex: 0,
              onTabChange: (_) {},
            ),
          ),
        ));
        await tester.runAsync(() => Future.wait([
              for (final asset in [
                Avatar.values.first.assetPath,
                ClimbThemes.greenSlope.backgroundFor(b),
                for (final q in [
                  ...ClimbSavePoints.all,
                  ...ClimbSavePoints.decor
                ])
                  q.asset,
                ClimbSavePoints.assetFor('summit_flag'),
                ClimbSavePoints.flameAsset,
              ])
                precacheImage(AssetImage(asset), key.currentContext!),
            ]));
        // The scroll into view, the hop (850 ms), then 1.2 s of label.
        for (var i = 0; i < 100; i++) {
          await tester.pump(const Duration(milliseconds: 25));
        }
        final label = find.byKey(MonthlyMountain.labelKey);
        expect(label, findsOneWidget);
        final box = tester.getRect(label);
        final window = tester.getRect(find.byType(MonthlyMountain));
        Rect chip(Key k) {
          final r = tester.getRect(find.byKey(k));
          return Rect.fromLTRB(
              r.left - 6, r.top - 2, r.right + 6, r.bottom + 2);
        }

        final tile = tester.getRect(find.descendant(
            of: find.byType(MonthlyMountain),
            matching: find.byType(AvatarTile)));
        final others = {
          'month chip': chip(ClimbCard.monthKey),
          'step chip': chip(ClimbCard.stepsKey),
          'plaque': tester.getRect(find.byKey(ClimbCard.plaqueKey)),
          'avatar': Rect.fromLTRB(
              tile.left + .063 * tile.width,
              tile.top + .045 * tile.height,
              tile.left + .965 * tile.width,
              tile.top + .957 * tile.height),
          for (final q in [...ClimbSavePoints.all, ClimbSavePoints.flag])
            if (q != p)
              q.object: tester.getRect(
                  find.byKey(ValueKey('climb_save_point_${q.clearing}'))),
          'signpost':
              tester.getRect(find.byKey(const ValueKey('climb_decor_C5'))),
        };
        final touches = [
          if (box.top < window.top ||
              box.left < window.left ||
              box.right > window.right)
            'window edge',
          for (final MapEntry(:key, :value) in others.entries)
            if (box.overlaps(value))
              key == 'avatar' ? 'avatar (${_share(box, value)} %)' : key,
        ];
        final chips = others['month chip']!.bottom - window.top;
        String f(double v) => v.toStringAsFixed(1);
        if (b == Brightness.light) {
          rows.add('${'${p.clearing} ${p.name}'.padRight(19)} '
              '${'$step'.padLeft(2)}  ${screen.toInt()}   ${size.name.padRight(6)}  '
              '${'${f(box.width)} x ${f(box.height)}'.padRight(14)}  '
              '${f(box.top - window.top).padLeft(8)}  ${f(chips).padLeft(5)}  '
              '${touches.isEmpty ? '-' : touches.join(', ')}');
        }
        await tester.runAsync(() async {
          final card = tester.getRect(find.byType(ClimbCard));
          final full = await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 3);
          const pad = 8.0;
          final src = Rect.fromLTRB(card.left - pad, card.top - pad,
              card.right + pad, card.bottom + pad);
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawImageRect(
              full,
              Rect.fromLTWH(
                  src.left * 3, src.top * 3, src.width * 3, src.height * 3),
              Rect.fromLTWH(0, 0, src.width * 3, src.height * 3),
              Paint());
          final img = await recorder
              .endRecording()
              .toImage((src.width * 3).round(), (src.height * 3).round());
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File('$out/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
        });
        await tester.pumpAndSettle();
      });
    }
  }
}

/// The share of [b] that [a] covers, in whole per cent.
int _share(Rect a, Rect b) {
  final i = a.intersect(b);
  return (i.width * i.height * 100 / (b.width * b.height)).round();
}
