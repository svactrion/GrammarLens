import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';

/// UI polish (owner, 2026-11-17; SPEC §1.1, §1.2): nine heroes in a fixed
/// order; the seven retired ids read as Fox. The stored format stays
/// `avatar_NN`. (Replaces the 16-avatar, append-only tests of Batch 8.)
void main() {
  group('Avatar.values', () {
    test('the picker lists exactly the nine heroes, in order', () {
      expect(Avatar.values.map((a) => a.semanticLabel).toList(), [
        'Fox',
        'Panda',
        'Koala',
        'Frog',
        'Bird',
        'Giraffe',
        'Cat',
        'Sloth',
        'Crab',
      ]);
      expect(Avatar.count, 9);
    });

    test('each hero keeps its stored id and base image', () {
      expect(Avatar.values.map((a) => a.toJson()).toList(), [
        'avatar_14',
        'avatar_15',
        'avatar_01',
        'avatar_05',
        'avatar_13',
        'avatar_11',
        'avatar_08',
        'avatar_16',
        'avatar_07',
      ]);
      for (final avatar in Avatar.values) {
        expect(avatar.assetPath, 'assets/avatars/${avatar.toJson()}.webp');
      }
    });

    test('order is the position in the list', () {
      for (var i = 0; i < Avatar.values.length; i++) {
        expect(Avatar.values[i].order, i);
      }
    });

    test('every hero has its six pose images and its base image on disk', () {
      for (final avatar in Avatar.values) {
        expect(File(avatar.assetPath).existsSync(), isTrue,
            reason: avatar.assetPath);
        for (final pose in [
          'wave',
          'cheer',
          'think',
          'inspect',
          'sad',
          'sleep'
        ]) {
          expect(File(avatar.posePath(pose)).existsSync(), isTrue,
              reason: avatar.posePath(pose));
        }
      }
    });

    test('no retired hero is in the list', () {
      for (final avatar in Avatar.values) {
        expect(Avatar.retiredIndexes, isNot(contains(avatar.index)));
      }
    });
  });

  group('Avatar.random', () {
    test('always returns one of the heroes', () {
      for (var seed = 0; seed < 40; seed++) {
        expect(Avatar.values, contains(Avatar.random(Random(seed))));
      }
    });

    test('the same injected Random is deterministic, for testability', () {
      expect(Avatar.random(Random(1)), Avatar.random(Random(1)));
    });
  });

  group('Avatar.toJson / fromJson', () {
    test('round-trips every hero through its own id', () {
      for (final avatar in Avatar.values) {
        expect(Avatar.fromJson(avatar.toJson()), same(avatar));
      }
    });

    test('the seven retired ids read as Fox', () {
      for (final id in [
        'avatar_02',
        'avatar_03',
        'avatar_04',
        'avatar_06',
        'avatar_09',
        'avatar_10',
        'avatar_12',
      ]) {
        expect(Avatar.isRetiredId(id), isTrue, reason: id);
        expect(Avatar.fromJson(id), same(Avatar.fox), reason: id);
      }
    });

    test('a hero id is not retired', () {
      for (final avatar in Avatar.values) {
        expect(Avatar.isRetiredId(avatar.toJson()), isFalse);
      }
      expect(Avatar.isRetiredId(null), isFalse);
      expect(Avatar.isRetiredId('fox'), isFalse);
    });

    test(
        'returns null for null, unrecognized, or out-of-range ids — never '
        'throws', () {
      expect(Avatar.fromJson(null), isNull);
      expect(Avatar.fromJson(''), isNull);
      expect(Avatar.fromJson('avatar_00'), isNull);
      expect(Avatar.fromJson('avatar_17'), isNull);
      expect(Avatar.fromJson('avatar_1'), isNull);
      expect(Avatar.fromJson('not-an-avatar'), isNull);
    });

    test('returns null for ids from the emoji-based set before 1.0', () {
      for (final legacyId in ['fox', 'cat', 'owl', 'panda', 'lion']) {
        expect(Avatar.fromJson(legacyId), isNull);
      }
    });
  });
}
