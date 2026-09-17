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

// Secondary container — a light tint of the same navy above, not a second
// hue. Previously a separate saturated violet-blue (#3D5AFE) that read as
// an unrelated second "blue" system-wide (the Settings/Premium segmented
// buttons' selected fill, Premium's icon circles, the Review frequency
// pill, the weak-spot detail pill) — docs/design-audit.md S2/D2. Every one
// of those now derives from this single navy family.
const Color _lightSecondaryContainer = Color(0xFFD7E1FA);
const Color _lightOnSecondaryContainer = Color(0xFF0A2E70);

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

// Brand mark (see widgets/brand_mark.dart) — the loupe's glass and glint
// are fixed identity colors, not theme roles: unlike everything else in
// this file they don't change with light/dark mode (the mark's rim does —
// it uses colorScheme.secondary directly). Public and named here, rather
// than embedded as hex in the widget, so the mark's palette stays defined
// in one place alongside the rest of the brand system.
const Color brandMarkGlass = Color(0xFFFFF6EC);
const Color brandMarkGlint = Color(0xFFFFCDA3);

/// The avatar presentation's ground shadow (see `widgets/avatar_tile.dart`)
/// — a soft ellipse painted beneath the avatar illustration instead of a
/// colored selection ring or a drop shadow on the silhouette itself
/// (docs/design-audit.md's avatar section, superseding the ring-color
/// system that used to live here — see that doc for why it was removed).
///
/// Deliberately two different base colors, not one reused across both
/// themes: measured contrast against `BrandScaffold`'s own body color
/// (`colorScheme.surfaceContainerLow`) found a black shadow works well on
/// the light body (`#FAF3EC`) but is nearly imperceptible on the dark
/// body (`#1C1B1F` — even 65% alpha black only reaches ~1.16 contrast
/// against it, since the body is already near-black). Dark mode instead
/// uses a light-based mark, matching Material 3's own dark-theme
/// convention that elevated/grounded surfaces read lighter, not darker,
/// against a near-black background. [avatarGroundShadowOpacity] pairs
/// each color with the alpha that lands both themes at a comparable
/// ~1.4–1.6 contrast ratio against their own body — light black at 20%,
/// dark white at 11%.
Color avatarGroundShadowColor(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.white : Colors.black;

double avatarGroundShadowOpacity(Brightness brightness) =>
    brightness == Brightness.dark ? 0.11 : 0.20;

/// D1's header-band colors (docs/design-audit.md §5), read as an
/// extension on [ColorScheme] rather than a new field: the band's own
/// color is not a single role but this `isDark ? X : Y` expression, and
/// this extension is the *one* place that expression lives. Both
/// [buildAppTheme] (today's full-screen scaffold/app-bar background, for
/// every screen not yet migrated onto [BrandScaffold]) and
/// `BrandScaffold` itself read from here — reverting D1 (or changing what
/// "neutral" means in dark mode) is a one-line change in this extension,
/// not a per-call-site sweep, but it is a code change, not a single
/// token/value swap, since the band was never one role to begin with.
///
/// Accepted, deliberate coupling from reading `primary`/`onPrimary` in
/// light mode: a handful of dialog "Cancel" buttons across the app
/// (`practice_screen.dart`, `settings_screen.dart`, `daily_test_screen.dart`)
/// already override `FilledButton` to `colorScheme.primary`/`onPrimary`
/// explicitly, for the same "read as the least-committal action" reason a
/// plain-orange button reads that way today. Because the band reads from
/// the same role, the band's orange and those buttons' orange are — and
/// will stay — bit-for-bit identical. Before D1 this was invisible (the
/// whole screen was that color, so there was nothing to compare against);
/// once the band is a distinct region, this is a real, visible
/// consequence of the role choice, not a new bug — accepted rather than
/// worked around with a second orange.
extension BandColors on ColorScheme {
  /// The header band's background — orange (`primary`) in light mode, the
  /// neutral `surface` in dark mode. Dark mode never uses orange as a
  /// surface (docs/design-audit.md §5 D1's dark-mode decision).
  Color get bandBackground => brightness == Brightness.dark ? surface : primary;

  /// The band's title/icon color, paired with [bandBackground].
  /// Light: `onPrimary` on `primary`, ~6.93:1. Dark: `onSurface` on
  /// `surface`, ~14.56:1. Both computed directly (WCAG relative
  /// luminance), comfortably clearing AA for either text or UI components.
  Color get bandForeground =>
      brightness == Brightness.dark ? onSurface : onPrimary;
}

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
      onIncorrectBackground:
          Color.lerp(onIncorrectBackground, other.onIncorrectBackground, t)!,
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
    // tertiary aliases secondary rather than introducing a third hue — one
    // blue system-wide (D2).
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
  // above) so app bar foreground is the ordinary light `onSurface`. Same
  // expression `BandColors.bandBackground`/`bandForeground` reads for
  // `BrandScaffold` (docs/design-audit.md §5 D1) — this is the whole-screen
  // default for every screen not yet migrated onto that widget; screens
  // that have migrated override `Scaffold.backgroundColor` to the neutral
  // body color but leave the app bar to inherit these same colors.
  final scaffoldBg = colorScheme.bandBackground;
  final appBarFg = colorScheme.bandForeground;

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
      // The app-wide card treatment (docs/design-audit.md §5 D1, closed):
      // every screen is now on `BrandScaffold`'s neutral body (Welcome is
      // the one deliberate exception, and never uses `Card`), so there's
      // exactly one card language, not the scoped-override-during-
      // migration split this used to require. `BrandScaffold` previously
      // carried a local `Theme` copy of these exact values for its own
      // subtree while migration was still in progress; that override is
      // gone now that there's nothing left for it to be scoped against.
      //
      // `surfaceContainerHigh`, one step up from the body's own
      // `surfaceContainerLow` — a card the same color as the body it sits
      // on would separate by shadow alone, measured directly (see the
      // border note below) to not hold up in dark mode.
      color: colorScheme.surfaceContainerHigh,
      // 1dp, not M3's level-3 (6dp) this app used before D1: back when
      // shadow was the only separation signal (full-orange/near-black
      // scaffold), 6dp was deliberately heavier than the M3 default to
      // read as "lifted" at all. The border below is now the primary,
      // theme-consistent signal, so elevation is a light lift rather than
      // dominant depth — measured directly: the previous 6dp shadow was
      // ~1.73:1 against the body in light mode but only ~1.06:1 in dark
      // (docs/build-log.md, 2026-09-09), i.e. it was never reliable in
      // both themes to begin with.
      elevation: 1,
      // `outline`, not `outlineVariant` (this app's usual divider/border
      // role) — tried `outlineVariant` first and measured it directly
      // on-device: ~1.34:1 against the body in light mode, genuinely hard
      // to see, not just a borderline number on paper. `outline` measures
      // ~3.11:1 (body) / ~2.72:1 (card) in light, ~5.05:1 / ~4.20:1 in
      // dark — comfortably legible in both, still an existing role.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outline),
      ),
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: colorScheme.shadow,
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
    textButtonTheme: TextButtonThemeData(
      // Explicit color for the same reason FilledButton/OutlinedButton
      // need one above: M3's default TextButton foreground is
      // colorScheme.primary, which in light mode *is* the page's own
      // vivid-orange background — an unstyled TextButton renders
      // orange-on-orange and disappears. Several call sites (Restore
      // Purchases, Skip, "Maybe later") had been patching this
      // individually; centralizing it here means any new TextButton gets
      // a readable color by default, in both themes, without repeating
      // the fix.
      style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

/// Named decorative Green Slope tokens for the isolated Monthly Climb preview.
/// Independent of semantic correct/incorrect colors and existing screen roles.
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

  static ClimbPalette of(Brightness brightness) => brightness == Brightness.dark
      ? const ClimbPalette(
          sky: Color(0xFF182327),
          mountain: Color(0xFF405C53),
          ridge: Color(0xFF2E463F),
          trail: Color(0xFF8E8874),
          stone: Color(0xFFC8C8B9),
          ink: Color(0xFFE4E2D8),
          accent: _darkPrimary)
      : const ClimbPalette(
          sky: Color(0xFFEAF0EC),
          mountain: Color(0xFFACC4AC),
          ridge: Color(0xFF789B86),
          trail: Color(0xFFD9CCAC),
          stone: Color(0xFFF5F0DF),
          ink: Color(0xFF263D39),
          accent: _lightPrimary);
}
