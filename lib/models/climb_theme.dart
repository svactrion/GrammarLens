import 'dart:ui' show Brightness, Color;

import '../theme.dart';

/// The Monthly Climb scene's colors in one appearance (light or dark).
/// Decorative tokens, independent of the app's semantic correct/incorrect
/// colors and of other screens' roles.
class ClimbPalette {
  final Color sky, mountain, ridge, trail, stone, ink, accent;
  const ClimbPalette(
      {required this.sky,
      required this.mountain,
      required this.ridge,
      required this.trail,
      required this.stone,
      required this.ink,
      required this.accent});
}

/// A theme's summit, sitting on the trail's end.
enum ClimbSummit { grassyHilltopWithFlag, smokingCrater, iceCrown, mesa }

/// The symbol on a theme's medal.
enum ClimbEmblem { pine, flame, iceCrystal, rockArch }

/// One monthly theme, as data: a new theme is an entry here plus assets,
/// not new widget code.
class ClimbTheme {
  /// Stable id, stored per month in `climb_month_themes`. Never renamed.
  final String id;
  final String name;

  /// One line, used word for word (month transition card).
  final String tagline;

  /// Whether the theme can be shown. A theme that is not ready is never
  /// assigned to a month (see [ClimbThemeRotation.shownFor]).
  final bool ready;

  /// Null until the theme is ready.
  final ClimbPalette? lightPalette;
  final ClimbPalette? darkPalette;

  /// The scene's illustration, one asset per mode (scene art S1, S4): the
  /// mountain, its trail and the START flag are all in the image, at the
  /// trail coordinates every theme shares (`ClimbRoute`). Null until the
  /// theme's images exist. A theme without a dark image shows the light
  /// one in dark mode.
  final String? backgroundLight;
  final String? backgroundDark;

  /// Whether this theme draws the flag (assets/climb/objects/summit_flag.webp),
  /// the month's goal: on clearing C6, lit only when the summit is reached
  /// (scene art S3, G4). On C6 it does not depend on the summit's shape, so
  /// all four themes draw it (Batch 4); the field stays for a later theme
  /// whose C6 does not suit it. The name is from when the flag stood on the
  /// summit.
  final bool hasSummitFlag;

  /// The flag's pennant colour where the theme recolours it (G10), or null
  /// for the asset's own brand orange. Only Red Canyon: on its orange rock
  /// the orange pennant was hard to pick out on the device.
  final Color? flagPennantColor;

  final ClimbSummit summit;
  final ClimbEmblem emblem;

  const ClimbTheme({
    required this.id,
    required this.name,
    required this.tagline,
    required this.ready,
    this.lightPalette,
    this.darkPalette,
    this.backgroundLight,
    this.backgroundDark,
    this.hasSummitFlag = false,
    this.flagPennantColor,
    required this.summit,
    required this.emblem,
  }) : assert(
            !ready ||
                (lightPalette != null &&
                    darkPalette != null &&
                    backgroundLight != null),
            'a ready theme has both palettes and a background');

  /// The palette for [brightness]. Only for a ready theme.
  ClimbPalette paletteFor(Brightness brightness) =>
      (brightness == Brightness.dark ? darkPalette : lightPalette)!;

  /// The background asset for [brightness]. Only for a ready theme.
  String backgroundFor(Brightness brightness) =>
      (brightness == Brightness.dark ? backgroundDark : null) ??
      backgroundLight!;
}

/// Every monthly theme, in rotation order.
class ClimbThemes {
  ClimbThemes._();

  static const String greenSlopeId = 'green_slope';

  /// The palettes: the 1.0 scene's colours, unchanged. Since scene art
  /// (S1) the image paints the mountain, so a palette is used only for the
  /// passed-day dots (`ink`) and the window's fill until the image has
  /// decoded (`sky`); the month and step chips read Green Slope's
  /// (`ClimbCard`). Every theme shares these two.
  static const _lightPalette = ClimbPalette(
      sky: Color(0xFFEAF0EC),
      mountain: Color(0xFFACC4AC),
      ridge: Color(0xFF789B86),
      trail: Color(0xFFD9CCAC),
      stone: Color(0xFFF5F0DF),
      ink: Color(0xFF263D39),
      accent: appLightPrimary);
  static const _darkPalette = ClimbPalette(
      sky: Color(0xFF182327),
      mountain: Color(0xFF405C53),
      ridge: Color(0xFF2E463F),
      trail: Color(0xFF8E8874),
      stone: Color(0xFFC8C8B9),
      ink: Color(0xFFE4E2D8),
      accent: appDarkPrimary);

  /// The 1.0 mountain: the default and the fallback.
  static const greenSlope = ClimbTheme(
    id: greenSlopeId,
    name: 'Green Slope',
    tagline: 'Green slopes and an easy trail to find your rhythm.',
    ready: true,
    lightPalette: _lightPalette,
    darkPalette: _darkPalette,
    backgroundLight: 'assets/climb/green_slope/background_light.webp',
    backgroundDark: 'assets/climb/green_slope/background_dark.webp',
    hasSummitFlag: true,
    summit: ClimbSummit.grassyHilltopWithFlag,
    emblem: ClimbEmblem.pine,
  );

  static const emberPeak = ClimbTheme(
    id: 'ember_peak',
    name: 'Ember Peak',
    tagline: 'Smoke on the ridge, warm rock underfoot.',
    ready: true,
    lightPalette: _lightPalette,
    darkPalette: _darkPalette,
    backgroundLight: 'assets/climb/ember_peak/background_light.webp',
    backgroundDark: 'assets/climb/ember_peak/background_dark.webp',
    hasSummitFlag: true,
    summit: ClimbSummit.smokingCrater,
    emblem: ClimbEmblem.flame,
  );

  static const glacierPeak = ClimbTheme(
    id: 'glacier_peak',
    name: 'Glacier Peak',
    tagline: 'Thin air, bright ice, and a view worth the climb.',
    ready: true,
    lightPalette: _lightPalette,
    darkPalette: _darkPalette,
    backgroundLight: 'assets/climb/glacier_peak/background_light.webp',
    backgroundDark: 'assets/climb/glacier_peak/background_dark.webp',
    hasSummitFlag: true,
    summit: ClimbSummit.iceCrown,
    emblem: ClimbEmblem.iceCrystal,
  );

  /// G10: Red Canyon's flag pennant, a cyan blue, the complement of its red
  /// rock. One constant. Of dark blue 1E4FA3, mid blue 2F7BD8 and cyan
  /// 1FB5C9, cyan separates best from the rock in its weakest case (faded,
  /// dark mode: ΔE2000 16.4, against 14.5 and 13.6; the brand orange 8.4
  /// faded in light mode) (docs/design/scene-art/batch4/flag_pennant.txt).
  static const redCanyonPennant = Color(0xFF1FB5C9);

  static const redCanyon = ClimbTheme(
    id: 'red_canyon',
    name: 'Red Canyon',
    tagline: 'Sun-baked rock and a mesa waiting at the top.',
    ready: true,
    lightPalette: _lightPalette,
    darkPalette: _darkPalette,
    backgroundLight: 'assets/climb/red_canyon/background_light.webp',
    backgroundDark: 'assets/climb/red_canyon/background_dark.webp',
    hasSummitFlag: true,
    flagPennantColor: redCanyonPennant,
    summit: ClimbSummit.mesa,
    emblem: ClimbEmblem.rockArch,
  );

  /// Rotation order.
  static const all = [greenSlope, emberPeak, glacierPeak, redCanyon];

  /// The theme with [id]; Green Slope for an unknown id (a stored id from a
  /// newer build, say), so the scene never breaks.
  static ClimbTheme byId(String id) =>
      all.firstWhere((theme) => theme.id == id, orElse: () => greenSlope);
}

/// Which theme a month gets. Global calendar: the same month has the same
/// theme for everyone, whatever their install date (Batch 0 decision 2).
class ClimbThemeRotation {
  ClimbThemeRotation._();

  /// October 2026 is Green Slope, then [ClimbThemes.all] in order, one per
  /// month, repeating. A constant, not tied to the release date.
  static const int anchorYear = 2026;
  static const int anchorMonth = 10;

  /// The calendar's theme for [year]/[month], ready or not. Months before
  /// the anchor are Green Slope.
  static ClimbTheme scheduledFor(int year, int month) {
    final offset = (year * 12 + month) - (anchorYear * 12 + anchorMonth);
    if (offset < 0) return ClimbThemes.greenSlope;
    return ClimbThemes.all[offset % ClimbThemes.all.length];
  }

  /// The theme a month is shown with, and so the one recorded for it: the
  /// calendar's theme if it is ready, otherwise Green Slope. What is
  /// recorded must be what the user sees, so a theme that is not ready
  /// never appears in the data.
  static ClimbTheme shownFor(int year, int month) {
    final scheduled = scheduledFor(year, month);
    return scheduled.ready ? scheduled : ClimbThemes.greenSlope;
  }
}
