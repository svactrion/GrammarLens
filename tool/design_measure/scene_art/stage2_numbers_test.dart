// Scene Art Stage 2, measured on the real Home (the shell, HomeScreen,
// ClimbCard, MonthlyMountain) on the last day of October 2026 (31 steps,
// the window at the image's top): the flag (on the summit until the
// Stage 2 fix, on C5 since) against the month and step chips and the
// plaque, and against the avatar standing on the summit; plus the object
// assets' bytes.
//
//   DESIGN_MEASURE_OUT=docs/design/scene-art/stage2 \
//     flutter test tool/design_measure/scene_art/stage2_numbers_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_card.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

import '../home_fakes.dart';
import '../layouts.dart' show loadFont, loadIconFont, outDir;

String _f(double v) => v.toStringAsFixed(1);

void main() {
  final out = StringBuffer()
    ..writeln('Scene Art Stage 2 — the flag on the real Home, '
        'day 31 of 31 (window at the image top)')
    ..writeln();
  setUpAll(() async {
    await loadFont();
    await loadIconFont();
  });

  for (final screen in [320.0, 375.0, 430.0]) {
    testWidgets('$screen pt', (tester) async {
      tester.view.physicalSize = Size(screen, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = const FakeViewPadding(top: 60);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(designHome(
          clock: DateTime(2026, 10, 31, 14),
          storage: DesignStorage(steps: 31, correct: 90)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final window = tester.getRect(find.byType(MonthlyMountain));
      final flag = tester.getRect(find.byKey(
          ValueKey('climb_save_point_${ClimbSavePoints.flag.clearing}')));
      final avatar = tester.getRect(find.descendant(
          of: find.byType(MonthlyMountain), matching: find.byType(AvatarTile)));
      Rect chip(Key key) => tester.getRect(find
          .ancestor(of: find.byKey(key), matching: find.byType(DecoratedBox))
          .first);
      final month = chip(ClimbCard.monthKey), steps = chip(ClimbCard.stepsKey);
      final plaque = tester.getRect(find.byKey(ClimbCard.plaqueKey));
      String against(String name, Rect r) {
        final across = flag.left < r.right && flag.right > r.left;
        final down = flag.top - r.bottom;
        return across
            ? '$name: overlaps it across; the flag\'s top is ${_f(down)} pt '
                '${down >= 0 ? 'below' : 'INTO'} its bottom'
            : '$name: clear across (${_f(flag.left >= r.right ? flag.left - r.right : r.left - flag.right)} pt apart); '
                'the flag\'s top is ${_f(down)} pt from its bottom';
      }

      final gapToAvatar = flag.left - avatar.right;
      out
        ..writeln(
            '$screen pt (window ${_f(window.width)} × ${_f(window.height)} pt)')
        ..writeln(
            '  flag box x ${_f(flag.left - window.left)}–${_f(flag.right - window.left)}, '
            'y ${_f(flag.top - window.top)}–${_f(flag.bottom - window.top)} pt in the window '
            '(${_f(flag.width)} × ${_f(flag.height)} pt)')
        ..writeln('  ${against('month chip', month)}')
        ..writeln('  ${against('steps chip', steps)}')
        ..writeln('  ${against('plaque', plaque)}')
        ..writeln('  chip band bottom ${_f(month.bottom - window.top)} pt; '
            'flag top ${_f(flag.top - window.top)} pt')
        ..writeln('  avatar on the summit ${_f(avatar.width)} pt; '
            '${gapToAvatar >= 0 ? 'clear of the flag by ${_f(gapToAvatar)} pt' : 'OVERLAPS the flag box by ${_f(-gapToAvatar)} pt'}')
        ..writeln();
    });
  }

  tearDownAll(() {
    var total = 0;
    for (final f
        in Directory('assets/climb/objects').listSync().whereType<File>()) {
      total += f.lengthSync();
      out.writeln(
          '${f.path}: ${(f.lengthSync() / 1024).toStringAsFixed(1)} KB');
    }
    out.writeln('objects added: ${(total / 1024).toStringAsFixed(1)} KB '
        '(${ClimbSavePoints.all.length} save points, the flag, the flame layer)');
    File('${outDir()}/numbers.txt').writeAsStringSync(out.toString());
    // ignore: avoid_print
    print(out);
  });
}
