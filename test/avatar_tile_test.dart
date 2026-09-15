import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/widgets/avatar_tile.dart';

/// The regression test for this batch's actual bug: `AvatarTile` used to
/// grow by 5px whenever `selected` was true (an extra border+padding
/// wrapper around the same box), which broke Settings' avatar `Wrap`
/// layout every time the last tile in a row was tapped. `selected` is
/// gone now — this pins down that the tile's own footprint depends on
/// nothing but [AvatarTile.radius], not on which (or whether an) avatar
/// it's showing, so nothing rendering a set of these in a row/wrap can
/// ever have this happen again.
void main() {
  Future<Size> pumpAndMeasure(WidgetTester tester, Avatar? avatar) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: AvatarTile(avatar: avatar))),
      ),
    );
    return tester.getSize(find.byType(AvatarTile));
  }

  testWidgets('every avatar renders at the exact same size at a fixed radius',
      (tester) async {
    final placeholderSize = await pumpAndMeasure(tester, null);
    for (final avatar in Avatar.values) {
      final size = await pumpAndMeasure(tester, avatar);
      expect(size, placeholderSize);
    }
  });

  testWidgets('size is exactly radius * 2 on both axes', (tester) async {
    const radius = 37.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: AvatarTile(avatar: Avatar.values.first, radius: radius),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AvatarTile)), const Size(74, 74));
  });
}
