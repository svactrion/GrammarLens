// Batch 5 Batch 0, §3: N6's save point name label, as a prototype over the
// real Home. October 2026 (31 days, Green Slope); the avatar on the step
// each save point is reached on (ClimbSavePoint.reachedOn), the flag on
// the last; 320 / 375 / 430 pt, Small / Medium / Large (only through
// buildAppTheme(textSize:)), light, and dark at 375 pt Medium.
//
// The label is drawn by this tool above the screen, not by the app: an
// opaque chip in the month and step chips' style (K4: the palette's sky,
// `ink` text in labelLarge bold, radius 8), its bottom 4 pt above the
// object's box, centred on it, then moved sideways to stay 6 pt inside the
// mountain window. Measured: the label's box, how far it was moved, and
// what it touches: the window's edge, the month and step chips, the
// plaque, the avatar, the other objects and the C5 signpost's box
// (docs/design/batch5/signpost/placement.json).
//
//   DESIGN_MEASURE_OUT=build/design_measure/batch5_labels \
//     flutter test tool/design_measure/batch5/save_point_label_test.dart
//   build/scene_art_venv/bin/python tool/scene_art/batch5_sheet.py labels
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_camera.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_route.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;
import 'save_point_numbers_test.dart' show signpost;

/// N6's names, by object.
const names = {
  'tent': 'First Camp',
  'cabin': 'Halfway Hut',
  'fountain': 'Mountain Spring',
  'campfire': 'High Camp',
  'summit_flag': 'Summit',
};

const _gap = 4.0, _inset = 6.0;

/// The prototype label: an opaque chip like the month and step chips.
class ProtoLabel extends StatelessWidget {
  final String text;
  const ProtoLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = ClimbThemes.greenSlope.paletteFor(theme.brightness);
    return DecoratedBox(
      decoration: BoxDecoration(
          color: palette.sky, borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(text,
            style: theme.textTheme.labelLarge
                ?.copyWith(color: palette.ink, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

void main() {
  final out = outDir();
  final rows = <String>[];
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });
  tearDownAll(() => File('$out/save_point_labels.txt').writeAsStringSync([
        'Batch 5 Batch 0 §3: N6\'s label prototype over the real Home, '
            'October 2026 (31 days), light (layout is the same in dark). '
            'Points.',
        'label: its size; moved: how far it was moved sideways to stay '
            '$_inset pt inside the window (0 = centred on the object); '
            'top room: the label\'s top below the window\'s top; touches: what '
            'the label\'s box overlaps (chips = the month and step chips with '
            'their padding; avatar = the avatar art\'s visible box in its tile, the largest of the 16 avatars; signpost = the C5 '
            'signpost\'s box, drawn there once N11 is built).',
        '',
        'Placement A: the label\'s bottom $_gap pt above the object (N6 as '
            'written). B: $_gap pt above the object and the avatar\'s art '
            'together. Both centred on the object, then moved sideways.',
        '',
        'p  object             step  width text    label w x h     moved   top room  touches',
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
          'label_${p.clearing}_${screen.toInt()}_${b.name}_${size.name}.png';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = Size(screen, 1400) * 3;
        tester.view.devicePixelRatio = 3;
        tester.view.padding = const FakeViewPadding(top: 60);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final labelKey = GlobalKey();
        final position = ValueNotifier<Offset?>(null);
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Stack(children: [
              designHome(
                  clock: DateTime(2026, 10, 31, 14),
                  storage: DesignStorage(steps: step, correct: step * 3),
                  brightness: b,
                  textSize: size),
              ValueListenableBuilder<Offset?>(
                valueListenable: position,
                builder: (context, at, _) => Positioned(
                  left: at?.dx ?? 0,
                  top: at?.dy ?? 0,
                  child: Offstage(
                    offstage: at == null,
                    child: Theme(
                      data: buildAppTheme(b, textSize: size),
                      child: Material(
                          type: MaterialType.transparency,
                          child: ProtoLabel(names[p.object]!, key: labelKey)),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ));
        await tester.runAsync(() async {
          await Future.wait([
            for (final asset in [
              Avatar.values.first.assetPath,
              ClimbThemes.greenSlope.backgroundFor(b),
              for (final q in ClimbSavePoints.all) q.asset,
              ClimbSavePoints.assetFor('summit_flag'),
              ClimbSavePoints.flameAsset,
            ])
              precacheImage(AssetImage(asset), key.currentContext!),
          ]);
        });
        await tester.pump();
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        final window = tester.getRect(find.byType(MonthlyMountain));
        final object = tester
            .getRect(find.byKey(ValueKey('climb_save_point_${p.clearing}')));
        final label = tester.getSize(find.byKey(labelKey, skipOffstage: false));
        Rect chip(Key k) =>
            tester.getRect(find.byKey(k)).copyWith(dx: 6, dy: 2);
        final camera = ClimbCamera(window.width);
        final offset = camera.offsetFor(ClimbRoute(31).pointAt(step * 1.0));
        Rect toScreen(Rect r) => Rect.fromLTRB(
            r.left * camera.scale - offset.dx + window.left,
            r.top * camera.scale - offset.dy + window.top,
            r.right * camera.scale - offset.dx + window.left,
            r.bottom * camera.scale - offset.dy + window.top);
        final others = {
          'month chip': chip(ClimbCard.monthKey),
          'step chip': chip(ClimbCard.stepsKey),
          'plaque': tester.getRect(find.byKey(ClimbCard.plaqueKey)),
          // The art's visible box in its tile, the union over the 16
          // avatars (alpha > 40: left 0.063, top 0.045, right 0.965,
          // bottom 0.957 of the tile), so the worst avatar.
          'avatar': () {
            final t = tester.getRect(find.descendant(
                of: find.byType(MonthlyMountain),
                matching: find.byType(AvatarTile)));
            return Rect.fromLTRB(
                t.left + .063 * t.width,
                t.top + .045 * t.height,
                t.left + .965 * t.width,
                t.top + .957 * t.height);
          }(),
          for (final q in [...ClimbSavePoints.all, ClimbSavePoints.flag])
            if (q != p) q.object: toScreen(q.rect),
          'signpost': toScreen(signpost().rect),
        };
        // A: above the object (N6 as written); B: above the object and
        // the avatar together, so the avatar's head stays in view.
        for (final placement in ['A', 'B']) {
          final centred = object.center.dx - label.width / 2;
          final left = centred.clamp(
              window.left + _inset, window.right - _inset - label.width);
          final above = placement == 'A'
              ? object.top
              : math.min(object.top, others['avatar']!.top);
          final top = above - _gap - label.height;
          position.value = Offset(left, top);
          await tester.pump();
          final box = Rect.fromLTWH(left, top, label.width, label.height);
          final touches = [
            if (box.top < window.top ||
                box.left < window.left ||
                box.right > window.right)
              'window edge',
            for (final MapEntry(:key, :value) in others.entries)
              if (box.overlaps(value))
                key == 'avatar'
                    ? 'avatar (${_share(box, value)} % of its art box)'
                    : key,
          ];
          String f(double v) => v.toStringAsFixed(1);
          if (b == Brightness.light) {
            rows.add(
                '$placement  ${'${p.clearing} ${names[p.object]}'.padRight(19)} '
                '${'$step'.padLeft(2)}  ${screen.toInt()}   ${size.name.padRight(6)}  '
                '${'${f(label.width)} x ${f(label.height)}'.padRight(14)}  '
                '${f(left - centred).padLeft(6)}  ${f(top - window.top).padLeft(8)}  '
                '${touches.isEmpty ? '-' : touches.join(', ')}');
          }
          final file = name.replaceAll('.png', '_$placement.png');
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
            File('$out/$file').writeAsBytesSync(bytes!.buffer.asUint8List());
          });
        }
      });
    }
  }
}

/// The share of [b] that [a] covers, in whole per cent.
int _share(Rect a, Rect b) {
  final i = a.intersect(b);
  return (i.width * i.height * 100 / (b.width * b.height)).round();
}

extension on Rect {
  /// Grown by [dx] sideways and [dy] up and down (a chip's padding).
  Rect copyWith({required double dx, required double dy}) =>
      Rect.fromLTRB(left - dx, top - dy, right + dx, bottom + dy);
}
