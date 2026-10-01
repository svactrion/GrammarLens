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

  /// The 1.0 mountain: the default and the fallback. Its palettes are the
  /// scene's colors from 1.0, unchanged.
  static const greenSlope = ClimbTheme(
    id: greenSlopeId,
    name: 'Green Slope',
    tagline: 'Green slopes and an easy trail to find your rhythm.',
    ready: true,
    lightPalette: ClimbPalette(
        sky: Color(0xFFEAF0EC),
        mountain: Color(0xFFACC4AC),
        ridge: Color(0xFF789B86),
        trail: Color(0xFFD9CCAC),
        stone: Color(0xFFF5F0DF),
        ink: Color(0xFF263D39),
        accent: appLightPrimary),
    darkPalette: ClimbPalette(
        sky: Color(0xFF182327),
        mountain: Color(0xFF405C53),
        ridge: Color(0xFF2E463F),
        trail: Color(0xFF8E8874),
        stone: Color(0xFFC8C8B9),
        ink: Color(0xFFE4E2D8),
        accent: appDarkPrimary),
    backgroundLight: 'assets/climb/green_slope/background_light.webp',
    backgroundDark: 'assets/climb/green_slope/background_dark.webp',
    summit: ClimbSummit.grassyHilltopWithFlag,
    emblem: ClimbEmblem.pine,
  );

  static const emberPeak = ClimbTheme(
    id: 'ember_peak',
    name: 'Ember Peak',
    tagline: 'Smoke on the ridge, warm rock underfoot.',
    ready: false,
    summit: ClimbSummit.smokingCrater,
    emblem: ClimbEmblem.flame,
  );

  static const glacierPeak = ClimbTheme(
    id: 'glacier_peak',
    name: 'Glacier Peak',
    tagline: 'Thin air, bright ice, and a view worth the climb.',
    ready: false,
    summit: ClimbSummit.iceCrown,
    emblem: ClimbEmblem.iceCrystal,
  );

  static const redCanyon = ClimbTheme(
    id: 'red_canyon',
    name: 'Red Canyon',
    tagline: 'Sun-baked rock and a mesa waiting at the top.',
    ready: false,
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
  ///
  /// Scene art Stage 1: only Green Slope has images, so only it is ready,
  /// and every month, whatever the calendar says, is shown and recorded
  /// (`climb_month_themes`) as Green Slope. A theme becomes ready with its
  /// light and dark images (Stage 2).
  static ClimbTheme shownFor(int year, int month) {
    final scheduled = scheduledFor(year, month);
    return scheduled.ready ? scheduled : ClimbThemes.greenSlope;
  }
}
