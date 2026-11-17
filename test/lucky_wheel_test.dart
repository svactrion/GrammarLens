import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/screens/lucky_wheel_screen.dart';

/// SPEC §1.3: the wheel never lands on the current buddy or on the previous
/// spin's result.
void main() {
  test('never the current buddy, never the previous result', () {
    for (var seed = 0; seed < 400; seed++) {
      final random = Random(seed);
      for (final current in Avatar.values) {
        for (final previous in [null, ...Avatar.values]) {
          final pick = pickLuckyHero(
              current: current, previous: previous, random: random);
          expect(pick, isNot(current));
          expect(pick, isNot(previous));
          expect(Avatar.values, contains(pick));
        }
      }
    }
  });

  test('every other hero can come up', () {
    final seen = <Avatar>{};
    for (var seed = 0; seed < 300; seed++) {
      seen.add(pickLuckyHero(current: Avatar.fox, random: Random(seed)));
    }
    expect(seen, Avatar.values.where((a) => a != Avatar.fox).toSet());
  });

  test('a run of spins never repeats a result twice in a row', () {
    final random = Random(7);
    Avatar? previous;
    for (var i = 0; i < 200; i++) {
      final pick = pickLuckyHero(
          current: Avatar.panda, previous: previous, random: random);
      expect(pick, isNot(previous));
      previous = pick;
    }
  });
}
