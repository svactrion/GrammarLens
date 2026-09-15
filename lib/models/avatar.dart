import 'dart:math';

/// One of the app's stock avatar illustrations (`assets/avatars/`,
/// `avatar_01.webp` through `avatar_NN.webp`) — an asset-backed identity,
/// not an enum, specifically so adding a new avatar later is "drop
/// `avatar_NN.webp` in the folder, add its label, bump [count]" rather
/// than adding a new enum case and touching every switch that
/// pattern-matches on one (the previous, emoji-based set was an `enum`
/// with exactly this problem). Kept free of any Flutter/UI dependency
/// (same reasoning as [AppThemeMode] in `app_theme_mode.dart`) so the
/// storage layer doesn't need to import `package:flutter/material.dart`.
///
/// [values] holds exactly [count] singleton instances, built once; every
/// accessor below ([random], [fromJson], iterating [values] itself)
/// returns one of those existing instances rather than constructing a new
/// one, so `==` between two [Avatar]s referring to the same avatar is
/// plain reference equality — the same guarantee an `enum` gives for free,
/// without needing to hand-write `==`/`hashCode`.
///
/// Onboarding assigns one of these at random so nobody sees the generic
/// placeholder on day one (PRD v2 §13.5) — null still means "no avatar
/// set" for callers (a pre-existing profile from before an avatar was
/// assigned, or an id [fromJson] didn't recognize), and still shows that
/// placeholder wherever an avatar is rendered.
class Avatar {
  /// 1-based, matching the asset filename's own numbering
  /// (`avatar_01.webp` → index 1).
  final int index;

  const Avatar._(this.index);

  /// How many stock avatars exist — the one place this number is written.
  /// Adding avatar_13.webp: drop the file in `assets/avatars/`, add its
  /// character name to [_semanticLabels], bump this to 13. Nothing else
  /// changes.
  static const int count = 12;

  /// The [count] singleton instances, in asset order. Every other accessor
  /// on this class indexes into this same list rather than constructing a
  /// fresh [Avatar] — see the class doc comment for why that matters.
  static final List<Avatar> values =
      List.generate(count, (i) => Avatar._(i + 1), growable: false);

  /// One of the stock avatars, chosen at random. [random] is injectable so
  /// a test can make the pick deterministic; defaults to a fresh [Random].
  static Avatar random([Random? random]) =>
      values[(random ?? Random()).nextInt(count)];

  String get _paddedIndex => index.toString().padLeft(2, '0');

  /// The bundled illustration for this avatar (508×508, transparent,
  /// `assets/avatars/avatar_NN.webp`).
  String get assetPath => 'assets/avatars/avatar_$_paddedIndex.webp';

  /// The character this illustration depicts — read aloud by VoiceOver/
  /// TalkBack via `Semantics`, since the image itself carries no text.
  /// Hand-matched against each asset when this set shipped; see
  /// docs/build-log.md for the full character list if a new avatar needs
  /// one added here.
  String get semanticLabel => _semanticLabels[index - 1];

  static const List<String> _semanticLabels = [
    'Koala',
    'Snail',
    'Elephant',
    'Bee',
    'Frog',
    'Chick',
    'Crab',
    'Cat',
    'Turtle',
    'Penguin',
    'Giraffe',
    'Hedgehog',
  ];

  /// Persisted as `avatar_NN`, matching the asset filename exactly — the
  /// storage id and the asset path share one source of truth (this class),
  /// so they can never drift apart.
  String toJson() => 'avatar_$_paddedIndex';

  /// Parses a persisted id back into an [Avatar]. Returns `null` for
  /// anything that doesn't resolve to a currently-valid avatar — an
  /// unrecognized id, an out-of-range number, or an id from the previous,
  /// now-replaced emoji-based avatar set ('fox', 'owl', 'lion', ...) —
  /// never an error. Callers must treat `null` as "no avatar / fall back
  /// to a default," never as a bug: this is the app's entire defense
  /// against a stored id this build doesn't recognize (a stale set, or a
  /// future build's larger [count]) crashing instead of just showing the
  /// generic placeholder.
  static Avatar? fromJson(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^avatar_(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final index = int.parse(match.group(1)!);
    if (index < 1 || index > count) return null;
    return values[index - 1];
  }
}
