import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';

void main() {
  group('Avatar.random', () {
    test('always returns one of the eight defined values', () {
      for (var seed = 0; seed < 20; seed++) {
        final picked = Avatar.random(Random(seed));
        expect(Avatar.values, contains(picked));
      }
    });

    test('the same injected Random is deterministic, for testability', () {
      expect(Avatar.random(Random(1)), Avatar.random(Random(1)));
    });
  });
}
