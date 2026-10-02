// Batch 6 Batch 0, step 2: the plaque's rounded corners. For each text size
// (applied only through `buildAppTheme(textSize:)`), the plaque's height,
// the radius it asks for (ClimbCard.frameRadius × plaqueRadiusShare) and the
// radius each corner is drawn with, plus the largest share at which no
// corner is fitted down. Writes `plaque_numbers.txt`.
//
//   DESIGN_MEASURE_OUT=docs/design/batch6/plaque \
//     flutter test tool/design_measure/batch6/plaque_numbers_test.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/app_text_size.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';

import '../layouts.dart' show loadFont, outDir;

void main() {
  final out = outDir();
  setUpAll(loadFont);

  testWidgets('plaque_numbers.txt', (tester) async {
    final lines = <String>[
      'Batch 6 Batch 0, step 2: the plaque\'s rounded corners',
      'frameRadius = ${ClimbCard.frameRadius} pt (appCardRadius), '
          'plaqueRadiusShare = ${ClimbCard.plaqueRadiusShare}, '
          'asked radius = '
          '${ClimbCard.frameRadius * ClimbCard.plaqueRadiusShare} pt',
      '',
      'size    plaque h  point corner r  top/bottom corner r  '
          'point pulled in  largest unfitted share',
    ];
    for (final size in AppTextSize.values) {
      late double h;
      // A new app per size: one app would animate between the themes.
      await tester.pumpWidget(MaterialApp(
          key: ValueKey(size),
          theme: buildAppTheme(Brightness.light, textSize: size),
          home: Builder(builder: (context) {
            h = ClimbCard.plaqueHeight(context);
            return const SizedBox();
          })));
      final rect = Rect.fromLTWH(0, 0, 200, h);
      final c = TrailSignBorder.corners(rect);
      const asked = ClimbCard.frameRadius * ClimbCard.plaqueRadiusShare;
      final point = TrailSignBorder.fittedRadius(c[0], c[5], c[4], asked);
      final top = TrailSignBorder.fittedRadius(c[5], c[0], c[1], asked);
      // Half of a point's angle: atan((h / 2) / depth).
      final half = math.atan(1 / (2 * TrailSignBorder.pointDepth));
      final pull = point * (1 / math.sin(half) - 1);
      // The largest radius every corner takes unchanged: the point's,
      // whose arc reaches farthest along the slanted edge (half its length).
      final maxPoint =
          TrailSignBorder.fittedRadius(c[0], c[5], c[4], double.infinity);
      lines.add('${size.name.padRight(8)}'
          '${h.toStringAsFixed(1).padLeft(8)}  '
          '${point.toStringAsFixed(2).padLeft(14)}  '
          '${top.toStringAsFixed(2).padLeft(19)}  '
          '${pull.toStringAsFixed(2).padLeft(15)}  '
          '${(maxPoint / ClimbCard.frameRadius).toStringAsFixed(2).padLeft(22)}');
    }
    lines.addAll([
      '',
      'All in points. "point pulled in": how far each point moves in from',
      'the sharp sign\'s end. "largest unfitted share": above it, the',
      'points are drawn with a smaller radius than asked (half the slanted',
      'edge); the silhouette is kept either way.',
    ]);
    File('$out/plaque_numbers.txt').writeAsStringSync('${lines.join('\n')}\n');
  });
}
