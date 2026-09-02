import 'package:flutter/material.dart';

// The whole ColorScheme is hand-built rather than derived via
// `ColorScheme.fromSeed`, for two reasons that both bit us with the seeded
// approach: (1) `fromSeed` desaturates any seed toward muted M3 tonal
// equivalents, which is the opposite of the vivid, confident brand this app
// wants; (2) it also drives `surfaceTint`, which paints a translucent color
// overlay on every elevated surface (app bar, cards, nav bar) — set to
// transparent below so elevation only ever adds a plain shadow, never a
// color wash.
//
// Role mapping, deliberately non-standard M3 usage per product direction:
// - `primary` (vivid orange) is the app's BRAND/BACKGROUND color — scaffold
//   and app bar in light mode. It is NOT used for buttons.
// - `secondary` (deep parliament/royal blue) is the ACTION/ACCENT color —
//   buttons, the selected nav item, progress/"correct" highlights.
// - `surfaceContainerLow` is the warm "paper" card color that floats on top
//   of the orange page.
// Every text/background pairing below is picked for contrast, not just
// hue — see the inline notes on the orange roles, where a vivid enough
// orange to read as "confident" already rules out white text.

// Primary / brand — vivid, warm, saturated orange. Page + app bar
// background in light mode. #FF7A1A has a relative luminance of ~0.35, so
// white text on it only hits ~2.6:1 contrast (fails) while a warm near-black
// hits ~6.9:1 (comfortably passes) — hence a dark "on" color, not white.
const Color _lightPrimary = Color(0xFFFF7A1A);
const Color _lightOnPrimary = Color(0xFF241200);
const Color _lightPrimaryContainer = Color(0xFFFFA64D);
const Color _lightOnPrimaryContainer = Color(0xFF241200);

// Secondary / accent — deep, saturated parliament/royal blue. Buttons,
// selected nav item, progress/"correct" chips.
const Color _lightSecondary = Color(0xFF0D3B8F);
const Color _lightOnSecondary = Color(0xFFFFFFFF);
const Color _lightSecondaryContainer = Color(0xFF3D5AFE);
const Color _lightOnSecondaryContainer = Color(0xFFFFFFFF);

const Color _lightError = Color(0xFFBA1A1A);
const Color _lightOnError = Color(0xFFFFFFFF);
const Color _lightErrorContainer = Color(0xFFFFDAD6);
const Color _lightOnErrorContainer = Color(0xFF410002);

// Neutrals — warm-tinted "paper" family for cards/inputs, kept far enough
// from white that it visibly separates from a pure-white nav bar, and far
// enough from the orange page that text stays dark-on-light throughout.
const Color _lightSurface = Color(0xFFFFFFFF);
const Color _lightOnSurface = Color(0xFF1B1B1F);
const Color _lightOnSurfaceVariant = Color(0xFF46464F);
const Color _lightSurfaceDim = Color(0xFFE8DDCF);
const Color _lightSurfaceBright = Color(0xFFFFFFFF);
const Color _lightSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color _lightSurfaceContainerLow = Color(0xFFFAF3EC);
const Color _lightSurfaceContainer = Color(0xFFF3ECE3);
const Color _lightSurfaceContainerHigh = Color(0xFFEDE4D8);
const Color _lightSurfaceContainerHighest = Color(0xFFE7DCCD);
const Color _lightOutline = Color(0xFF8A8A93);
const Color _lightOutlineVariant = Color(0xFFDED3C2);
const Color _lightInverseSurface = Color(0xFF2F2F33);
const Color _lightOnInverseSurface = Color(0xFFF2F2F5);

// Dark theme — a full orange page background reads harsh/muddy at low
// brightness, so dark mode keeps a true near-black neutral for scaffold/app
// bar and reserves orange for accents (topic icon, chips) exactly like the
// light theme reserves it there too — only the *background* role changes.
const Color _darkPrimary = Color(0xFFFF8A3D);
const Color _darkOnPrimary = Color(0xFF3D1300);
const Color _darkPrimaryContainer = Color(0xFFC1440E);
const Color _darkOnPrimaryContainer = Color(0xFFFFE3C7);

const Color _darkSecondary = Color(0xFF5C7CFA);
const Color _darkOnSecondary = Color(0xFF04123A);
const Color _darkSecondaryContainer = Color(0xFF1A3FA0);
const Color _darkOnSecondaryContainer = Color(0xFFD8E1FF);

const Color _darkError = Color(0xFFFFB4AB);
const Color _darkOnError = Color(0xFF690005);
const Color _darkErrorContainer = Color(0xFF93000A);
const Color _darkOnErrorContainer = Color(0xFFFFDAD6);

const Color _darkSurface = Color(0xFF121212);
const Color _darkOnSurface = Color(0xFFE4E2E6);
const Color _darkOnSurfaceVariant = Color(0xFFC9C5D0);
const Color _darkSurfaceDim = Color(0xFF121212);
const Color _darkSurfaceBright = Color(0xFF38373C);
const Color _darkSurfaceContainerLowest = Color(0xFF0B0B0D);
const Color _darkSurfaceContainerLow = Color(0xFF1C1B1F);
const Color _darkSurfaceContainer = Color(0xFF201F23);
const Color _darkSurfaceContainerHigh = Color(0xFF2B2A2F);
const Color _darkSurfaceContainerHighest = Color(0xFF36353A);
const Color _darkOutline = Color(0xFF8D8A93);
const Color _darkOutlineVariant = Color(0xFF444349);
const Color _darkInverseSurface = Color(0xFFE4E2E6);
const Color _darkOnInverseSurface = Color(0xFF1B1B1F);

// Results feedback (correct / incorrect / skipped) — deliberately soft and
// desaturated rather than pulled from the vivid brand palette above: these
// sit behind body text as large full-card fills, so a universal, gentle
// green/rose/cream reads as "good/bad/skipped" without fighting the text
// for attention or feeling harsh in an already-stressful IELTS-prep app.
const Color _lightCorrectBg = Color(0xFFDCEEDF);
const Color _lightOnCorrectBg = Color(0xFF1E4620);
const Color _lightIncorrectBg = Color(0xFFF8E1E0);
const Color _lightOnIncorrectBg = Color(0xFF5C1210);
const Color _lightSkippedBg = Color(0xFFEDE6DA);
const Color _lightOnSkippedBg = Color(0xFF46464F);

const Color _darkCorrectBg = Color(0xFF1B3320);
const Color _darkOnCorrectBg = Color(0xFFB7E4C1);
const Color _darkIncorrectBg = Color(0xFF3A1D1D);
const Color _darkOnIncorrectBg = Color(0xFFF4B8B4);
const Color _darkSkippedBg = Color(0xFF36353A);
const Color _darkOnSkippedBg = Color(0xFFC9C5D0);

/// Semantic feedback colors for the results screen, kept out of
/// [ColorScheme] (which only has roles for the brand palette) via Flutter's
/// [ThemeExtension] mechanism — the idiomatic way to add app-specific theme
/// colors without raw hex creeping into screen files.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color correctBackground;
  final Color onCorrectBackground;
  final Color incorrectBackground;
  final Color onIncorrectBackground;
  final Color skippedBackground;
  final Color onSkippedBackground;

  const SemanticColors({
    required this.correctBackground,
    required this.onCorrectBackground,
    required this.incorrectBackground,
    required this.onIncorrectBackground,
    required this.skippedBackground,
    required this.onSkippedBackground,
  });

  static const light = SemanticColors(
    correctBackground: _lightCorrectBg,
    onCorrectBackground: _lightOnCorrectBg,
    incorrectBackground: _lightIncorrectBg,
    onIncorrectBackground: _lightOnIncorrectBg,
    skippedBackground: _lightSkippedBg,
    onSkippedBackground: _lightOnSkippedBg,
  );

  static const dark = SemanticColors(
    correctBackground: _darkCorrectBg,
    onCorrectBackground: _darkOnCorrectBg,
    incorrectBackground: _darkIncorrectBg,
    onIncorrectBackground: _darkOnIncorrectBg,
    skippedBackground: _darkSkippedBg,
    onSkippedBackground: _darkOnSkippedBg,
  );

  @override
  SemanticColors copyWith({
    Color? correctBackground,
    Color? onCorrectBackground,
    Color? incorrectBackground,
    Color? onIncorrectBackground,
    Color? skippedBackground,
    Color? onSkippedBackground,
  }) {
    return SemanticColors(
      correctBackground: correctBackground ?? this.correctBackground,
      onCorrectBackground: onCorrectBackground ?? this.onCorrectBackground,
      incorrectBackground: incorrectBackground ?? this.incorrectBackground,
      onIncorrectBackground:
          onIncorrectBackground ?? this.onIncorrectBackground,
      skippedBackground: skippedBackground ?? this.skippedBackground,
      onSkippedBackground: onSkippedBackground ?? this.onSkippedBackground,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      correctBackground:
          Color.lerp(correctBackground, other.correctBackground, t)!,
      onCorrectBackground:
          Color.lerp(onCorrectBackground, other.onCorrectBackground, t)!,
      incorrectBackground:
          Color.lerp(incorrectBackground, other.incorrectBackground, t)!,
      onIncorrectBackground: Color.lerp(
          onIncorrectBackground, other.onIncorrectBackground, t)!,
      skippedBackground:
          Color.lerp(skippedBackground, other.skippedBackground, t)!,
      onSkippedBackground:
          Color.lerp(onSkippedBackground, other.onSkippedBackground, t)!,
    );
  }
}

ColorScheme _buildColorScheme(Brightness brightness) {
  if (brightness == Brightness.dark) {
    return const ColorScheme(
      brightness: Brightness.dark,
      primary: _darkPrimary,
      onPrimary: _darkOnPrimary,
      primaryContainer: _darkPrimaryContainer,
      onPrimaryContainer: _darkOnPrimaryContainer,
      secondary: _darkSecondary,
      onSecondary: _darkOnSecondary,
      secondaryContainer: _darkSecondaryContainer,
      onSecondaryContainer: _darkOnSecondaryContainer,
      tertiary: _darkSecondary,
      onTertiary: _darkOnSecondary,
      tertiaryContainer: _darkSecondaryContainer,
      onTertiaryContainer: _darkOnSecondaryContainer,
      error: _darkError,
      onError: _darkOnError,
      errorContainer: _darkErrorContainer,
      onErrorContainer: _darkOnErrorContainer,
      surface: _darkSurface,
      onSurface: _darkOnSurface,
      onSurfaceVariant: _darkOnSurfaceVariant,
      surfaceDim: _darkSurfaceDim,
      surfaceBright: _darkSurfaceBright,
      surfaceContainerLowest: _darkSurfaceContainerLowest,
      surfaceContainerLow: _darkSurfaceContainerLow,
      surfaceContainer: _darkSurfaceContainer,
      surfaceContainerHigh: _darkSurfaceContainerHigh,
      surfaceContainerHighest: _darkSurfaceContainerHighest,
      outline: _darkOutline,
      outlineVariant: _darkOutlineVariant,
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: _darkInverseSurface,
      onInverseSurface: _darkOnInverseSurface,
      inversePrimary: _lightPrimary,
      // Disables M3's automatic elevation color-wash (see file header).
      surfaceTint: Colors.transparent,
    );
  }
  return const ColorScheme(
    brightness: Brightness.light,
    primary: _lightPrimary,
    onPrimary: _lightOnPrimary,
    primaryContainer: _lightPrimaryContainer,
    onPrimaryContainer: _lightOnPrimaryContainer,
    secondary: _lightSecondary,
    onSecondary: _lightOnSecondary,
    secondaryContainer: _lightSecondaryContainer,
    onSecondaryContainer: _lightOnSecondaryContainer,
    tertiary: _lightSecondary,
    onTertiary: _lightOnSecondary,
    tertiaryContainer: _lightSecondaryContainer,
    onTertiaryContainer: _lightOnSecondaryContainer,
    error: _lightError,
    onError: _lightOnError,
    errorContainer: _lightErrorContainer,
    onErrorContainer: _lightOnErrorContainer,
    surface: _lightSurface,
    onSurface: _lightOnSurface,
    onSurfaceVariant: _lightOnSurfaceVariant,
    surfaceDim: _lightSurfaceDim,
    surfaceBright: _lightSurfaceBright,
    surfaceContainerLowest: _lightSurfaceContainerLowest,
    surfaceContainerLow: _lightSurfaceContainerLow,
    surfaceContainer: _lightSurfaceContainer,
    surfaceContainerHigh: _lightSurfaceContainerHigh,
    surfaceContainerHighest: _lightSurfaceContainerHighest,
    outline: _lightOutline,
    outlineVariant: _lightOutlineVariant,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: _lightInverseSurface,
    onInverseSurface: _lightOnInverseSurface,
    inversePrimary: _darkPrimary,
    // Disables M3's automatic elevation color-wash (see file header).
    surfaceTint: Colors.transparent,
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final colorScheme = _buildColorScheme(brightness);
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
  );

  // Comfortable line height across the board (practice screen especially
  // reads as cramped without it) — a height multiplier on top of the M3
  // type scale rather than custom font sizes.
  final textTheme = base.textTheme.copyWith(
    headlineSmall: base.textTheme.headlineSmall?.copyWith(height: 1.3),
    titleLarge: base.textTheme.titleLarge?.copyWith(height: 1.3),
    titleMedium: base.textTheme.titleMedium?.copyWith(height: 1.35),
    titleSmall: base.textTheme.titleSmall?.copyWith(height: 1.35),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.5),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
    bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.45),
    labelLarge:
        base.textTheme.labelLarge?.copyWith(height: 1.3, letterSpacing: 0.1),
  );

  // Light mode: the page and app bar sit directly on the brand orange, with
  // `onPrimary` (dark, contrast-checked above) for title/back-button/icons.
  // Dark mode keeps a neutral near-black page (see the dark-palette note
  // above) so app bar foreground is the ordinary light `onSurface`.
  final scaffoldBg = isDark ? colorScheme.surface : colorScheme.primary;
  final appBarFg = isDark ? colorScheme.onSurface : colorScheme.onPrimary;

  return base.copyWith(
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      isDark ? SemanticColors.dark : SemanticColors.light,
    ],
    scaffoldBackgroundColor: scaffoldBg,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldBg,
      foregroundColor: appBarFg,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: colorScheme.shadow,
      // Centered everywhere: the home screen's brand wordmark sets its own
      // explicit style (see home_screen.dart) so this doesn't affect it,
      // and every other screen's title goes through `PageTitle` (see
      // utils/page_title.dart) for the shared second-tier size/weight.
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w600, color: appBarFg),
    ),
    cardTheme: CardThemeData(
      // Real elevation (not tonal tint, since surfaceTint is transparent)
      // so cards visibly lift off the orange page. M3's level-3 token (6dp)
      // rather than the resting level-2 (3dp) — the latter was too faint to
      // read as "lifted" against the saturated brand background; 6dp is
      // still a soft, standard M3 shadow (levels go up to 12dp), just one
      // notch more present. Applies to every `Card` in the app (topic list,
      // practice questions, results, review) since none override elevation
      // locally.
      elevation: 6,
      color: colorScheme.surfaceContainerLow,
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: colorScheme.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Explicit colors: M3's default FilledButton pulls colorScheme.primary,
      // which is now the page-background orange, not the button color.
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: textTheme.labelLarge
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.secondary,
        minimumSize: const Size.fromHeight(52),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: colorScheme.secondary),
        textStyle: textTheme.labelLarge
            ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.secondary, width: 2),
      ),
      hintStyle:
          textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
    // Bottom nav is a custom widget (`_FloatingNavBar` in app.dart), styled
    // directly from `colorScheme` there — no NavigationBarThemeData needed
    // here.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle:
          textTheme.bodyMedium?.copyWith(color: colorScheme.onInverseSurface),
      actionTextColor: colorScheme.inversePrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 1),
    popupMenuTheme: PopupMenuThemeData(
      color: colorScheme.surfaceContainer,
      surfaceTintColor: colorScheme.surfaceTint,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
