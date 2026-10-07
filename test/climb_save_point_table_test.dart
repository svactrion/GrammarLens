import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_point_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_trail_table.dart';

import '../tool/climb_table/climb_save_point_generator.dart';

/// Scene art Stage 2: the save points on their clearings (G4, G9) and the
/// flag on C6, generated from the Stage 2 placement and never written by
/// hand (the trail table's pattern, D3).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the committed table is exactly what the placement generates', () {
    expect(File(climbSavePointTablePath).readAsStringSync(),
        generateClimbSavePointTable(),
        reason: 'the placement and the table disagree: run '
            'scripts/generate_climb_save_points.sh');
  });

  test('G4: four save points, on C1–C4, one of each object', () {
    expect([for (final p in ClimbSavePoints.all) p.clearing],
        ['C1', 'C2', 'C3', 'C4']);
    expect({for (final p in ClimbSavePoints.all) p.object},
        {'tent', 'cabin', 'fountain', 'campfire'});
  });

  test('G6: every theme has its own dark-mode gain, each channel in (0, 1]',
      () {
    for (final theme in ClimbThemes.all) {
      final gain = climbObjectDarkGain[theme.id];
      expect(gain, isNotNull, reason: theme.id);
      for (final g in [gain!.$1, gain.$2, gain.$3]) {
        expect(g, inExclusiveRange(0, 1.0001), reason: theme.id);
      }
    }
  });

  test('G9: the cabin and the tent on the two largest clearings', () {
    double area((String, String, double, double, double, double, double) r) =>
        r.$5 * r.$6;
    final byArea = [...climbSavePointTable]
      ..sort((a, b) => area(b).compareTo(area(a)));
    expect({byArea[0].$2, byArea[1].$2}, {'cabin', 'tent'});
    expect({byArea[2].$2, byArea[3].$2}, {'campfire', 'fountain'});
  });

  test('N11, N18: one decoration, the signpost on C5 at the rule\'s 0.95', () {
    expect(climbDecorTable, hasLength(1));
    final (clearing, object, _, _, _, _, ratio) = climbDecorTable.single;
    expect(clearing, 'C5');
    expect(object, 'signpost');
    expect(ratio, 0.95);
    expect(climbObjectAspects['signpost'], isNotNull);
    expect([for (final p in ClimbSavePoints.all) p.clearing],
        isNot(contains('C5')));
  });

  test('the flag stands on C6, the clearing under the summit, left of B6', () {
    expect(ClimbSavePoints.flag.clearing, 'C6');
    expect(ClimbSavePoints.flag.object, 'summit_flag');
  });

  test(
      'each object, and the flag, stands inside its clearing and is no '
      'wider than it', () {
    for (final (clearing, _, cx, cy, bw, bh, ratio) in [
      ...climbSavePointTable,
      climbFlag
    ]) {
      final p = [...ClimbSavePoints.all, ClimbSavePoints.flag]
          .firstWhere((p) => p.clearing == clearing);
      expect(ratio, inInclusiveRange(.5, 1.0));
      expect(p.rect.left, greaterThanOrEqualTo(cx - bw / 2 - 1e-9));
      expect(p.rect.right, lessThanOrEqualTo(cx + bw / 2 + 1e-9));
      // The base is on the clearing's ground, between its top and bottom.
      final top = (cy - bh / 2) / climbImageAspect;
      final bottom = (cy + bh / 2) / climbImageAspect;
      expect(p.rect.bottom, inInclusiveRange(top, bottom), reason: clearing);
    }
  });

  /// The object's drawn extent (alpha > 25 of 255) on each of its rows, in
  /// image widths, from its own asset.
  Future<List<(double, double)?>> rowExtents(String asset, ui.Rect rect) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final image = (await codec.getNextFrame()).image;
    final rgba = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    return [
      for (var y = 0; y < image.height; y++)
        () {
          int? l, r;
          for (var x = 0; x < image.width; x++) {
            if (rgba[(y * image.width + x) * 4 + 3] > 25) {
              l ??= x;
              r = x;
            }
          }
          if (l == null) return null;
          final k = rect.width / image.width;
          return (rect.left + l * k, rect.left + (r! + 1) * k);
        }()
    ];
  }

  Future<int> trailHits(String asset, ui.Rect rect) async {
    final rows = await rowExtents(asset, rect);
    var hits = 0;
    for (var i = 0; i < climbTrail.length; i++) {
      final y = climbTrail[i].$2 / climbImageAspect;
      if (y < rect.top || y >= rect.bottom) continue;
      final row = rows[((y - rect.top) / rect.height * rows.length)
          .floor()
          .clamp(0, rows.length - 1)];
      if (row == null) continue;
      final (l, r) = climbTrailRuns[i];
      if (l < row.$2 && r > row.$1) hits++;
    }
    return hits;
  }

  test('no object, and not the flag, touches the trail', () async {
    for (final p in ClimbSavePoints.all) {
      expect(await trailHits(p.asset, p.rect), 0, reason: p.object);
    }
    expect(
        await trailHits(ClimbSavePoints.flag.asset, ClimbSavePoints.flag.rect),
        0);
  });
}
