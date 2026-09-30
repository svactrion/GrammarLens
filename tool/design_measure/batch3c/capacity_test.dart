// Batch 3c-B step 4.4: how many environment items the free ground holds,
// beyond the two placed, under the same rules as the placed ones (on the
// ground, inside x 4–316, off the trail band + 8, the avatar's space, every
// month's markers and the summit, 8 units from each other).
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_scene.dart';

import '../../climb_table/climb_table_generator.dart';
import 'common.dart';

int fill(List<Rect> kinds, List<Rect> taken) {
  var n = 0;
  var placed = true;
  while (placed) {
    placed = false;
    for (final item in kinds) {
      search:
      for (var y = 60.0; y <= 736; y += 4) {
        for (var x = 20.0; x <= 300; x += 4) {
          final box = item.shift(Offset(x, y));
          if (environmentFree(box, taken: taken)) {
            taken.add(box.inflate(8));
            n++;
            placed = true;
            break search;
          }
        }
      }
    }
  }
  return n;
}

void main() {
  test('capacity', () {
    List<Rect> placedItems() => [
          for (final i in ClimbScene.environment)
            (i.kind == 'pine' ? pineBox : shrubBox).shift(i.base).inflate(8)
        ];
    final out = StringBuffer()
      ..writeln('Placed: ${ClimbScene.environment.map((i) => '${i.kind} '
          '(${i.base.dx.round()}, ${i.base.dy.round()})').join(', ')}')
      ..writeln('More pines that fit: ${fill([pineBox], placedItems())}')
      ..writeln('More shrubs that fit: ${fill([shrubBox], placedItems())}')
      ..writeln('More items, pine and shrub alternating: '
          '${fill([pineBox, shrubBox], placedItems())}');
    File('${outDir()}/environment_capacity.txt')
        .writeAsStringSync(out.toString());
  });
}
