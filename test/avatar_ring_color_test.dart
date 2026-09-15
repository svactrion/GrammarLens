import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/theme.dart';

/// Pins down the rule the carousel spec called out by name: a ring color
/// must never match its own avatar's dominant silhouette color, checked
/// concretely for Frog (avatar_05) and Turtle (avatar_09) — both read as
/// green animals, so a green-ish ring behind either would make the
/// silhouette disappear into its own background. Dinosaur (avatar_07),
/// the original third green-illustrated avatar this check was written
/// for, has since been replaced by Crab — kept in this test's coverage
/// anyway since it exercises the same index/ring-color pairing.
/// `avatarRingColor`'s doc comment explains why simple sequential cycling
/// happens to satisfy this without a hand-written per-avatar exception
/// table; this test is what actually guarantees that stays true instead
/// of trusting the coincidence, including if the avatar set or the color
/// palette ever grows.
void main() {
  // This palette's three green-ish entries (see theme.dart's own hue
  // comments on avatarRingColor2/3/4) — the actual "must not use for a
  // green animal" set.
  final greenishRingColors = {
    avatarRingColor2,
    avatarRingColor3,
    avatarRingColor4,
  };

  test('Frog, Crab, and Turtle never get a green-ish ring color', () {
    final frog = Avatar.values[4]; // avatar_05
    final crab = Avatar.values[6]; // avatar_07
    final turtle = Avatar.values[8]; // avatar_09

    expect(frog.semanticLabel, 'Frog');
    expect(crab.semanticLabel, 'Crab');
    expect(turtle.semanticLabel, 'Turtle');

    for (final avatar in [frog, crab, turtle]) {
      expect(
        greenishRingColors.contains(avatarRingColor(avatar)),
        isFalse,
        reason: '${avatar.semanticLabel} got a green-ish ring color',
      );
    }
  });

  test('every avatar gets one of the ten named ring colors', () {
    final palette = {
      avatarRingColor1,
      avatarRingColor2,
      avatarRingColor3,
      avatarRingColor4,
      avatarRingColor5,
      avatarRingColor6,
      avatarRingColor7,
      avatarRingColor8,
      avatarRingColor9,
      avatarRingColor10,
    };
    expect(palette.length, 10);
    for (final avatar in Avatar.values) {
      expect(palette.contains(avatarRingColor(avatar)), isTrue);
    }
  });
}
