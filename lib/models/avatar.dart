import 'dart:math';

/// One of the app's companions ("heroes", UI polish §1.1): an asset-backed
/// identity, not an enum. Kept free of any Flutter/UI dependency (same
/// reasoning as [AppThemeMode] in `app_theme_mode.dart`) so the storage
/// layer doesn't need to import `package:flutter/material.dart`.
///
/// The stored id is `avatar_NN`, the base illustration's file name
/// (`assets/avatars/avatar_NN.webp`). Ids 1–16 were handed out over time;
/// an index is never renumbered or reused.
///
/// **Nine heroes (owner, 2026-11-17).** Only [values] — Fox, Panda, Koala,
/// Frog, Bird, Giraffe, Cat, Sloth, Crab, in this order (the picker order,
/// `docs/design/ui-polish/handoff/ASSETS.md`) — exist in the app. The seven
/// retired ids (Snail 02, Elephant 03, Bee 04, Chick 06, Turtle 09, Penguin
/// 10, Hedgehog 12) are read as Fox ([fromJson]); a stored profile on one of
/// them is rewritten to Fox on its first read (`StorageService`
/// `getUserProfile`), silently.
///
/// [values] holds singleton instances, built once; every accessor returns
/// one of them, so `==` between two [Avatar]s is plain reference equality.
class Avatar {
  /// 1-based, matching the asset filename's own numbering
  /// (`avatar_01.webp` → index 1).
  final int index;

  /// The hero's file stem for its pose images
  /// (`assets/companions/<poseName>_<pose>.webp`).
  final String poseName;

  const Avatar._(this.index, this.poseName);

  /// The highest id ever handed out. Ids above it are unknown.
  static const int maxIndex = 16;

  /// The retired ids: read as Fox, never shown.
  static const Set<int> retiredIndexes = {2, 3, 4, 6, 9, 10, 12};

  static const Avatar fox = Avatar._(14, 'fox');
  static const Avatar panda = Avatar._(15, 'panda');
  static const Avatar koala = Avatar._(1, 'koala');
  static const Avatar frog = Avatar._(5, 'frog');
  static const Avatar bird = Avatar._(13, 'bird');
  static const Avatar giraffe = Avatar._(11, 'giraffe');
  static const Avatar cat = Avatar._(8, 'cat');
  static const Avatar sloth = Avatar._(16, 'sloth');
  static const Avatar crab = Avatar._(7, 'crab');

  /// The nine heroes in picker order (turntable and wheel).
  static const List<Avatar> values = [
    fox,
    panda,
    koala,
    frog,
    bird,
    giraffe,
    cat,
    sloth,
    crab,
  ];

  /// How many heroes there are.
  static int get count => values.length;

  /// One of the heroes, chosen at random. [random] is injectable so a test
  /// can make the pick deterministic; defaults to a fresh [Random].
  static Avatar random([Random? random]) =>
      values[(random ?? Random()).nextInt(values.length)];

  String get _paddedIndex => index.toString().padLeft(2, '0');

  /// The base illustration (508×508, transparent,
  /// `assets/avatars/avatar_NN.webp`): lists, small avatars, the
  /// turntable's back heroes, wheel slices, and the `idle` / `oops` moods.
  String get assetPath => 'assets/avatars/avatar_$_paddedIndex.webp';

  /// The pose illustration for [pose] (`wave`, `cheer`, `think`, `inspect`,
  /// `sad`, `sleep`; 768×768, transparent).
  String posePath(String pose) => 'assets/companions/${poseName}_$pose.webp';

  /// The position in [values] (0–8): the picker slot and the wheel slice.
  int get order => values.indexOf(this);

  /// The character's English identity — the screen shows
  /// `avatar.name(l10n)` (1.4.0 B4.7).
  // l10n-guard-begin: identities, not shown as is
  String get semanticLabel => switch (index) {
        14 => 'Fox',
        15 => 'Panda',
        1 => 'Koala',
        5 => 'Frog',
        13 => 'Bird',
        11 => 'Giraffe',
        8 => 'Cat',
        16 => 'Sloth',
        _ => 'Crab',
      };
  // l10n-guard-end

  /// Persisted as `avatar_NN`, matching the asset filename exactly.
  String toJson() => 'avatar_$_paddedIndex';

  /// The index a stored id names, or null for anything that is not an
  /// `avatar_NN` id in 1–[maxIndex].
  static int? _indexOf(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^avatar_(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final index = int.parse(match.group(1)!);
    if (index < 1 || index > maxIndex) return null;
    return index;
  }

  /// Whether [value] is the stored id of a retired hero (migrated to Fox).
  static bool isRetiredId(String? value) =>
      retiredIndexes.contains(_indexOf(value));

  /// Parses a persisted id back into an [Avatar]. A retired id is Fox
  /// (owner, 2026-11-17). Returns `null` for anything that is not a known
  /// id — an unrecognized id, an out-of-range number, or an id from the
  /// previous, emoji-based set ('fox', 'owl', ...) — never an error; callers
  /// treat `null` as "no avatar / fall back to a default".
  static Avatar? fromJson(String? value) {
    final index = _indexOf(value);
    if (index == null) return null;
    if (retiredIndexes.contains(index)) return fox;
    for (final avatar in values) {
      if (avatar.index == index) return avatar;
    }
    return null;
  }

  @override
  String toString() => 'Avatar(${toJson()})';
}
