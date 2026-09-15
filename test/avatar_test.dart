import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';

void main() {
  group('Avatar.values', () {
    test('holds exactly Avatar.count entries, in asset order', () {
      expect(Avatar.values.length, Avatar.count);
      for (var i = 0; i < Avatar.values.length; i++) {
        expect(Avatar.values[i].index, i + 1);
      }
    });

    test('every avatar has a unique, non-empty semantic label', () {
      final labels = Avatar.values.map((a) => a.semanticLabel).toSet();
      expect(labels.length, Avatar.count);
      for (final avatar in Avatar.values) {
        expect(avatar.semanticLabel, isNotEmpty);
      }
    });

    test('asset paths are distinct and follow the avatar_NN.webp pattern',
        () {
      final paths = Avatar.values.map((a) => a.assetPath).toSet();
      expect(paths.length, Avatar.count);
      expect(Avatar.values.first.assetPath, 'assets/avatars/avatar_01.webp');
      expect(Avatar.values.last.assetPath, 'assets/avatars/avatar_12.webp');
    });
  });

  group('Avatar.random', () {
    test('always returns one of the defined values', () {
      for (var seed = 0; seed < 20; seed++) {
        final picked = Avatar.random(Random(seed));
        expect(Avatar.values, contains(picked));
      }
    });

    test('the same injected Random is deterministic, for testability', () {
      expect(Avatar.random(Random(1)), Avatar.random(Random(1)));
    });
  });

  group('Avatar.toJson / fromJson', () {
    test('round-trips every avatar through its own id', () {
      for (final avatar in Avatar.values) {
        expect(Avatar.fromJson(avatar.toJson()), same(avatar));
      }
    });

    test('ids are zero-padded and match the asset filename', () {
      expect(Avatar.values.first.toJson(), 'avatar_01');
      expect(Avatar.values.last.toJson(), 'avatar_12');
    });

    test('returns null for null, unrecognized, or out-of-range ids — never '
        'throws', () {
      expect(Avatar.fromJson(null), isNull);
      expect(Avatar.fromJson(''), isNull);
      expect(Avatar.fromJson('avatar_00'), isNull);
      expect(Avatar.fromJson('avatar_13'), isNull);
      expect(Avatar.fromJson('avatar_1'), isNull);
      expect(Avatar.fromJson('not-an-avatar'), isNull);
    });

    test('returns null for ids from the previous, now-replaced emoji-based '
        'avatar set — the actual migration case this app can hit in the '
        'wild', () {
      for (final legacyId in ['fox', 'cat', 'owl', 'panda', 'koala',
          'penguin', 'lion', 'turtle']) {
        expect(Avatar.fromJson(legacyId), isNull);
      }
    });
  });
}
