import 'package:flutter/material.dart';

import 'models/app_text_size.dart';

// The whole ColorScheme is hand-built rather than derived via
// `ColorScheme.fromSeed`, for two reasons that both bit us with the seeded
// approach: (1) `fromSeed` desaturates any seed toward muted M3 tonal
// equivalents, which is the opposite of the vivid, confident brand this app
// wants; (2) it also drives `surfaceTint`, which paints a translucent color
// overlay on every elevated surface (app bar, cards, nav bar) — set to
// transparent below so elevation only ever adds a plain shadow, never a
// color wash.
//
// Role mapping, deliberately non-standard M3 usage per product direction.
// The values are the 1.2.0 redesign's tokens (docs/design/1.2.0/
// CLAUDE-CODE-BRIEF.md, design-tokens.json; mapping in batch0-report.md
// §1.1). The token name each role carries is noted on its constant.
// - `primary` (vivid orange, brandOrange) is the BRAND color, used for a few
//   meaningful surfaces (the Daily Test card, counters, labels), always with
//   the dark `onPrimary` — in dark mode too. It is no longer a page or app
//   bar color, and it is NOT used for buttons.
// - `secondary` (linkAndActive) is the LINK/ACTIVE color — text buttons,
//   the selected nav item, focus, section accents. The same navy as the
//   button in light mode; a light blue in dark mode.
// - The filled button's own color (primaryButton, navy in both themes) is
//   not a ColorScheme role: it lives in [AppPalette].
// - `surfaceContainerLow` is the page (pageBackground), `surfaceContainerHigh`
//   the card (cardSurface) and `surfaceContainerHighest` the subtle tile and
//   input fill (subtleSurface). In light mode the card is lighter than the
//   page, so these three do not follow M3's light-mode tone order; they are
//   named by role, not by tone.
// Every text/background pairing below is picked for contrast, not just
// hue — see the inline notes on the orange roles, where a vivid enough
// orange to read as "confident" already rules out white text. Measured
// ratios for every token pair: batch0-report.md §3.

// Primary / brand (brandOrange / onOrange) — vivid, warm, saturated orange.
// #FF7A1A has a relative luminance of ~0.35, so
// white text on it only hits ~2.6:1 contrast (fails) while a warm near-black
// hits ~6.9:1 (comfortably passes) — hence a dark "on" color, not white.
const Color _lightPrimary = Color(0xFFFF7A1A);
const Color _lightOnPrimary = Color(0xFF241200);
const Color _lightPrimaryContainer = Color(0xFFFFA64D);
const Color _lightOnPrimaryContainer = Color(0xFF241200);

// Secondary (linkAndActive) — deep, saturated parliament/royal blue. In
// light mode it is also the button color (AppPalette.button).
const Color _lightSecondary = Color(0xFF0D3B8F);
const Color _lightOnSecondary = Color(0xFFFFFFFF);

// Secondary container — a light tint of the same navy above, not a second
// hue. Previously a separate saturated violet-blue (#3D5AFE) that read as
// an unrelated second "blue" system-wide (the Settings/Premium segmented
// buttons' selected fill, Premium's icon circles, the Review frequency
// pill, the weak-spot detail pill) — docs/design-audit.md S2/D2. Every one
// of those now derives from this single navy family.
// infoSurface / onInfo.
const Color _lightSecondaryContainer = Color(0xFFD7E1FA);
const Color _lightOnSecondaryContainer = Color(0xFF0A2E70);

const Color _lightError = Color(0xFFBA1A1A);
const Color _lightOnError = Color(0xFFFFFFFF);
const Color _lightErrorContainer = Color(0xFFFFDAD6);
const Color _lightOnErrorContainer = Color(0xFF410002);

// Destructive actions — one red for both themes (see DestructiveColors below
// for the measured contrast this hex is tuned to).
const Color _destructive = Color(0xFFDC3232);
const Color _onDestructive = Color(0xFFFFFFFF);

// Neutrals — the warm ivory "paper" family. Page, card and tile are the
// tokens pageBackground, cardSurface and subtleSurface; text is
// textPrimary / textSecondary; `outlineVariant` is the card border token.
const Color _lightSurface = Color(0xFFFFFFFF);
const Color _lightOnSurface = Color(0xFF1B1B1F); // textPrimary
const Color _lightOnSurfaceVariant = Color(0xFF46464F); // textSecondary
const Color _lightSurfaceDim = Color(0xFFE8DDCF);
const Color _lightSurfaceBright = Color(0xFFFFFFFF);
const Color _lightSurfaceContainerLowest = Color(0xFFFFFFFF);
const Color _lightSurfaceContainerLow = Color(0xFFF3EFE6); // pageBackground
const Color _lightSurfaceContainer = Color(0xFFF3ECE3);
const Color _lightSurfaceContainerHigh = Color(0xFFFFFBF4); // cardSurface
const Color _lightSurfaceContainerHighest = Color(0xFFF6F0E5); // subtleSurface
const Color _lightOutline = Color(0xFF8A8A93);
const Color _lightOutlineVariant = Color(0xFFDED5C6); // border
const Color _lightInverseSurface = Color(0xFF2F2F33);
const Color _lightOnInverseSurface = Color(0xFFF2F2F5);

// Dark theme — a near-black neutral page. Orange is a surface here too
// (the 1.2.0 brief), on the same few meaningful elements as in light mode,
// and always with the dark #241200 text: light text on #FF8A3D measures
// 1.99:1 (#F0ECE7) and 2.35:1 (white), the dark text 7.71:1.
const Color _darkPrimary = Color(0xFFFF8A3D);
const Color _darkOnPrimary = Color(0xFF241200);
const Color _darkPrimaryContainer = Color(0xFFC1440E);
const Color _darkOnPrimaryContainer = Color(0xFFFFE3C7);

// linkAndActive is a light blue in dark mode, not the button's navy: the
// navy is 1.48:1 on the dark card and would not read as a link. As a fill
// (the length picker's slider) it pairs with a dark navy label, 7.72:1.
const Color _darkSecondary = Color(0xFFB4C8FF);
const Color _darkOnSecondary = Color(0xFF0A2E70);
const Color _darkSecondaryContainer = Color(0xFF243859);
const Color _darkOnSecondaryContainer = Color(0xFFD8E1FF);

const Color _darkError = Color(0xFFFFB4AB);
const Color _darkOnError = Color(0xFF690005);
const Color _darkErrorContainer = Color(0xFF93000A);
const Color _darkOnErrorContainer = Color(0xFFFFDAD6);

const Color _darkSurface = Color(0xFF121212);
const Color _darkOnSurface = Color(0xFFF0ECE7); // textPrimary
const Color _darkOnSurfaceVariant = Color(0xFFC9C5D0); // textSecondary
const Color _darkSurfaceDim = Color(0xFF121212);
const Color _darkSurfaceBright = Color(0xFF38373C);
const Color _darkSurfaceContainerLowest = Color(0xFF0B0B0D);
const Color _darkSurfaceContainerLow = Color(0xFF151517); // pageBackground
const Color _darkSurfaceContainer = Color(0xFF201F23);
const Color _darkSurfaceContainerHigh = Color(0xFF252528); // cardSurface
const Color _darkSurfaceContainerHighest = Color(0xFF303034); // subtleSurface
const Color _darkOutline = Color(0xFF8D8A93);
const Color _darkOutlineVariant = Color(0xFF45454D); // border
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

/// The light and dark `colorScheme.primary`, for data defined outside a
/// theme that still uses the brand color (the Monthly Climb palettes in
/// `models/climb_theme.dart`).
const Color appLightPrimary = _lightPrimary;
const Color appDarkPrimary = _darkPrimary;

/// The app-wide card's corner radius (`cardTheme` below), for widgets that
/// draw a card-like frame themselves (the Monthly Climb card, `ClimbCard`).
/// The brief's large card radius (24); list cards use 22.
const double appCardRadius = 24;

/// The filled and outlined buttons' corner radius (the brief: 14–15).
const double appButtonRadius = 14;

/// The text field's corner radius (the brief: 18).
const double appInputRadius = 18;

/// The brief's text sizes are what the default text size (Medium) renders
/// (owner decision Q5, 2026-10-05): the theme's base size is the brief's
/// size divided by Medium's scale factor, so Medium shows exactly the
/// brief's numbers and Small/Large keep their existing ratios to it.
double _briefSize(double sizeAtMedium) =>
    sizeAtMedium / AppTextSize.medium.scaleFactor;

// Brand mark (see widgets/brand_mark.dart) — the loupe's glass and glint
// are fixed identity colors, not theme roles: unlike everything else in
// this file they don't change with light/dark mode (the mark's rim does —
// see [brandMarkRim] below). Public and named here, rather
// than embedded as hex in the widget, so the mark's palette stays defined
// in one place alongside the rest of the brand system.
const Color brandMarkGlass = Color(0xFFFFF6EC);
const Color brandMarkGlint = Color(0xFFFFCDA3);

/// The brand mark's rim. It used to read `colorScheme.secondary`, which was
/// #0D3B8F in light mode and #5C7CFA in dark; 1.2.0 turned dark
/// `secondary` into the link color (#B4C8FF), and the logo is not a link.
/// The two earlier values are kept here so the mark, the launch screen and
/// its committed launch images stay exactly as they were.
Color brandMarkRim(Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFF5C7CFA) : _lightSecondary;

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
/// dark white at 11%. (Measured on the pre-1.2.0 body; on the 1.2.0 page,
/// `#F3EFE6` / `#151517`, the same alphas measure 1.60 and 1.36.)
Color avatarGroundShadowColor(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.white : Colors.black;

double avatarGroundShadowOpacity(Brightness brightness) =>
    brightness == Brightness.dark ? 0.11 : 0.20;

// The header band (D1, docs/design-audit.md §5: an orange band in light
// mode over a neutral body) was removed in the 1.2.0 redesign: every screen
// sits on the page color, and the app bar is the page color with
// `onSurface` content. Welcome sets its own orange (welcome_screen.dart).

/// The one place a destructive action's colors live (Reset progress, Leave):
/// a filled button in [destructive] with [onDestructive] text. Not a
/// [ColorScheme] role and not brightness-branched: the same two constants in
/// both themes, so a destructive button reads as the same strong red
/// everywhere. `error`/`onError` stay reserved for meaning "something went
/// wrong" (Premium and Review error text and icons), where a pale pink in
/// dark mode is right; as a button fill it is too weak.
///
/// Measured (WCAG relative luminance): [onDestructive] text on [destructive]
/// is 4.62:1; the fill against a dialog surface (`surfaceContainerHigh`) is
/// 3.67:1 in light and 3.08:1 in dark; against the page body
/// (`surfaceContainerLow`) 4.20:1 and 3.71:1. The text margin is narrow:
/// making this hex any lighter drops white text under 4.5:1, and making it
/// any darker drops the fill under 3:1 against the dark dialog. If you change
/// it, measure both again.
extension DestructiveColors on ColorScheme {
  /// Fill of a destructive button.
  Color get destructive => _destructive;

  /// Label of a destructive button, paired with [destructive].
  Color get onDestructive => _onDestructive;
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

/// The 1.2.0 redesign's tokens that have no [ColorScheme] role
/// (batch0-report.md §1.1): the filled button (the same navy in both
/// themes, unlike `secondary`), the navigation bar, the text field's edge,
/// the mountain path's outline, the disabled button and the two shadows.
/// Read with [AppPalette.of].
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// primaryButton / onPrimaryButton.
  final Color button;
  final Color onButton;

  /// A 1 px edge around the filled button, or null for none. Dark mode only
  /// (owner decision Q1): the navy fill is 1.28–1.77:1 against the dark
  /// surfaces, so its edge disappears; #5C7CFA measures 4.16:1 on the card,
  /// 4.97:1 on the page and 3.58:1 on the subtle surface.
  final Color? buttonEdge;

  /// The disabled filled button (owner decision Q4, the mockup's values).
  /// Inactive controls are exempt from WCAG contrast; the light label is
  /// 4.10:1 on its fill, the dark one 5.15:1.
  final Color disabledFill;
  final Color disabledLabel;

  /// navigationSurface / navigationBorder.
  final Color navSurface;
  final Color navBorder;

  /// The text field's edge (owner decision Q3): 3.53:1 on the light card
  /// and 3.17:1 on the light page; 4.01:1 on the dark card. The mockup's
  /// lighter edge was under 3:1 in both themes.
  final Color inputBorder;

  /// The mountain path's frame and title plate outline (1.5 px).
  final Color pathOutline;

  /// A translucent cream panel on a brandOrange surface (the Home Daily
  /// Test card's question count / score box, the mockup's #FAF3EC at 40 %);
  /// its text stays onOrange. The same in both themes, like the orange text
  /// pairing itself.
  final Color brandTint;

  /// The brief's card and navigation bar shadows.
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> navShadow;

  const AppPalette({
    required this.button,
    required this.onButton,
    required this.buttonEdge,
    required this.disabledFill,
    required this.disabledLabel,
    required this.navSurface,
    required this.navBorder,
    required this.inputBorder,
    required this.pathOutline,
    required this.brandTint,
    required this.cardShadow,
    required this.navShadow,
  });

  /// The theme's palette; under a theme without one (a widget pumped in
  /// isolation under a plain `ThemeData`), the palette for its brightness.
  static AppPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  // The shadows' base colors: a warm brown in light mode, black in dark.
  static const Color _lightShadowBase = Color(0xFF483018);
  static const Color _darkShadowBase = Color(0xFF000000);

  static final light = AppPalette(
    button: _lightSecondary,
    onButton: _lightOnSecondary,
    buttonEdge: null,
    disabledFill: const Color(0xFFE4DDD2),
    disabledLabel: const Color(0xFF6D6860),
    navSurface: const Color(0xFFFFFCF7),
    navBorder: const Color(0xFFD2C6B4),
    inputBorder: const Color(0xFF8E8577),
    pathOutline: const Color(0xFFA59F98),
    brandTint: const Color(0x66FAF3EC),
    cardShadow: [
      BoxShadow(
        color: _lightShadowBase.withValues(alpha: .10),
        offset: const Offset(0, 5),
        blurRadius: 18,
      ),
    ],
    navShadow: [
      BoxShadow(
        color: _lightShadowBase.withValues(alpha: .15),
        offset: const Offset(0, 6),
        blurRadius: 22,
      ),
    ],
  );

  static final dark = AppPalette(
    button: _lightSecondary,
    onButton: _lightOnSecondary,
    buttonEdge: const Color(0xFF5C7CFA),
    disabledFill: const Color(0xFF36363B),
    disabledLabel: const Color(0xFFACA8B2),
    navSurface: const Color(0xFF2D2D32),
    navBorder: const Color(0xFF595961),
    inputBorder: const Color(0xFF85818B),
    pathOutline: const Color(0xFF777581),
    brandTint: const Color(0x66FAF3EC),
    cardShadow: [
      BoxShadow(
        color: _darkShadowBase.withValues(alpha: .17),
        offset: const Offset(0, 5),
        blurRadius: 18,
      ),
    ],
    navShadow: [
      BoxShadow(
        color: _darkShadowBase.withValues(alpha: .33),
        offset: const Offset(0, 6),
        blurRadius: 22,
      ),
    ],
  );

  @override
  AppPalette copyWith({
    Color? button,
    Color? onButton,
    Color? buttonEdge,
    Color? disabledFill,
    Color? disabledLabel,
    Color? navSurface,
    Color? navBorder,
    Color? inputBorder,
    Color? pathOutline,
    Color? brandTint,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? navShadow,
  }) {
    return AppPalette(
      button: button ?? this.button,
      onButton: onButton ?? this.onButton,
      buttonEdge: buttonEdge ?? this.buttonEdge,
      disabledFill: disabledFill ?? this.disabledFill,
      disabledLabel: disabledLabel ?? this.disabledLabel,
      navSurface: navSurface ?? this.navSurface,
      navBorder: navBorder ?? this.navBorder,
      inputBorder: inputBorder ?? this.inputBorder,
      pathOutline: pathOutline ?? this.pathOutline,
      brandTint: brandTint ?? this.brandTint,
      cardShadow: cardShadow ?? this.cardShadow,
      navShadow: navShadow ?? this.navShadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      button: Color.lerp(button, other.button, t)!,
      onButton: Color.lerp(onButton, other.onButton, t)!,
      buttonEdge: Color.lerp(buttonEdge, other.buttonEdge, t),
      disabledFill: Color.lerp(disabledFill, other.disabledFill, t)!,
      disabledLabel: Color.lerp(disabledLabel, other.disabledLabel, t)!,
      navSurface: Color.lerp(navSurface, other.navSurface, t)!,
      navBorder: Color.lerp(navBorder, other.navBorder, t)!,
      inputBorder: Color.lerp(inputBorder, other.inputBorder, t)!,
      pathOutline: Color.lerp(pathOutline, other.pathOutline, t)!,
      brandTint: Color.lerp(brandTint, other.brandTint, t)!,
      cardShadow: BoxShadow.lerpList(cardShadow, other.cardShadow, t)!,
      navShadow: BoxShadow.lerpList(navShadow, other.navShadow, t)!,
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

/// The dark filled button's edge (Q1), none while disabled. Built once:
/// a `resolveWith` closure made per [buildAppTheme] call would make two
/// otherwise identical themes unequal, and `MaterialApp` would animate
/// between them on every rebuild.
final WidgetStateProperty<BorderSide?> _darkButtonEdge =
    WidgetStateProperty.resolveWith(
  (states) => states.contains(WidgetState.disabled)
      ? null
      : BorderSide(color: AppPalette.dark.buttonEdge!),
);

ThemeData buildAppTheme(
  Brightness brightness, {
  AppTextSize textSize = AppTextSize.medium,
}) {
  final colorScheme = _buildColorScheme(brightness);
  final isDark = brightness == Brightness.dark;
  final palette = isDark ? AppPalette.dark : AppPalette.light;
  final base = ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    brightness: brightness,
  );

  // The 1.2.0 type scale (batch0-report.md §1.3). Every style names its
  // weight: the bundled variable font's default instance is ExtraLight
  // (200), so a weight left to chance is worth ruling out even though
  // Flutter resolves an unset weight to 400 (measured, build-log
  // 2026-10-05). Sizes from the brief go through [_briefSize] (Q5); the
  // styles the brief does not cover keep their earlier base size.
  TextStyle style(
    TextStyle? from,
    double fontSize,
    FontWeight fontWeight,
    double? height, {
    double? letterSpacing,
  }) =>
      (from ?? const TextStyle()).copyWith(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
  final m = base.textTheme;
  final materialTextTheme = m.copyWith(
    // Not in the brief: Material sizes, weight made explicit.
    displayLarge: style(m.displayLarge, 57, FontWeight.w400, null),
    displayMedium: style(m.displayMedium, 45, FontWeight.w400, null),
    // Home brand and the Review/Profile page titles (34/900).
    displaySmall: style(m.displaySmall, _briefSize(34), FontWeight.w900, 1.10,
        letterSpacing: -1.1),
    // The Topic page title (32/900).
    headlineLarge: style(m.headlineLarge, _briefSize(32), FontWeight.w900, 1.10,
        letterSpacing: -1.0),
    // The question screen's topic title (26/900).
    headlineMedium: style(
        m.headlineMedium, _briefSize(26), FontWeight.w900, 1.12,
        letterSpacing: -0.65),
    // A main card's title (23–25/900).
    headlineSmall: style(m.headlineSmall, _briefSize(24), FontWeight.w900, 1.17,
        letterSpacing: -0.55),
    // A section title (20–21/800).
    titleLarge: style(m.titleLarge, _briefSize(20), FontWeight.w800, 1.2,
        letterSpacing: -0.4),
    // A topic or weak spot card's title (17–18/800).
    titleMedium: style(m.titleMedium, _briefSize(17), FontWeight.w800, 1.23,
        letterSpacing: -0.25),
    // Not in the brief: the earlier size and weight, now explicit.
    titleSmall: style(m.titleSmall, 14, FontWeight.w500, 1.35),
    // The question scenario (16/400/1.55).
    bodyLarge: style(m.bodyLarge, _briefSize(16), FontWeight.w400, 1.55,
        letterSpacing: 0),
    // Body and description text (13–14/400).
    bodyMedium: style(m.bodyMedium, _briefSize(14), FontWeight.w400, 1.45,
        letterSpacing: 0),
    bodySmall: style(m.bodySmall, _briefSize(13), FontWeight.w400, 1.45,
        letterSpacing: 0),
    // Buttons (14–15/800).
    labelLarge: style(m.labelLarge, _briefSize(14), FontWeight.w800, 1.3,
        letterSpacing: 0),
    // Small meta (11–12/600–800).
    labelMedium: style(m.labelMedium, _briefSize(12), FontWeight.w700, 1.4,
        letterSpacing: 0),
    labelSmall: style(m.labelSmall, _briefSize(11), FontWeight.w600, 1.4,
        letterSpacing: 0),
  );
  TextStyle? scaled(TextStyle? style) {
    final fontSize = style?.fontSize;
    return fontSize == null
        ? style
        : style!.copyWith(fontSize: fontSize * textSize.scaleFactor);
  }

  // TextTheme.apply asserts when even one platform-provided style has no
  // explicit fontSize. Scale only defined Material styles and leave any
  // intentionally incomplete fallback style alone.
  final textTheme = materialTextTheme
      .copyWith(
        displayLarge: scaled(materialTextTheme.displayLarge),
        displayMedium: scaled(materialTextTheme.displayMedium),
        displaySmall: scaled(materialTextTheme.displaySmall),
        headlineLarge: scaled(materialTextTheme.headlineLarge),
        headlineMedium: scaled(materialTextTheme.headlineMedium),
        headlineSmall: scaled(materialTextTheme.headlineSmall),
        titleLarge: scaled(materialTextTheme.titleLarge),
        titleMedium: scaled(materialTextTheme.titleMedium),
        titleSmall: scaled(materialTextTheme.titleSmall),
        bodyLarge: scaled(materialTextTheme.bodyLarge),
        bodyMedium: scaled(materialTextTheme.bodyMedium),
        bodySmall: scaled(materialTextTheme.bodySmall),
        labelLarge: scaled(materialTextTheme.labelLarge),
        labelMedium: scaled(materialTextTheme.labelMedium),
        labelSmall: scaled(materialTextTheme.labelSmall),
      )
      .apply(
        // Bundled rather than fetched at runtime: typography stays identical
        // offline and on both iOS and Android. Applying the family after the
        // Material scale is built preserves its concrete font sizes.
        fontFamily: 'NunitoSans',
      );

  // No header band any more (1.2.0): the scaffold and the app bar are the
  // page color, and the app bar's content is the ordinary `onSurface`.
  // Widgets that read `appBarTheme.foregroundColor` for text sitting on the
  // page (page titles, the loading view, the nav bar's unselected items)
  // therefore get textPrimary.
  final pageBg = colorScheme.surfaceContainerLow;
  final pageFg = colorScheme.onSurface;

  final buttonShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(appButtonRadius),
  );
  final buttonEdge = isDark ? _darkButtonEdge : null;

  return base.copyWith(
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      isDark ? SemanticColors.dark : SemanticColors.light,
      palette,
    ],
    scaffoldBackgroundColor: pageBg,
    appBarTheme: AppBarTheme(
      backgroundColor: pageBg,
      foregroundColor: pageFg,
      surfaceTintColor: colorScheme.surfaceTint,
      elevation: 0,
      scrolledUnderElevation: 2,
      shadowColor: colorScheme.shadow,
      // Centered everywhere: the home screen's brand wordmark sets its own
      // explicit style (see home_screen.dart) so this doesn't affect it,
      // and every other screen's title goes through `PageTitle` (see
      // utils/page_title.dart) for the shared second-tier size/weight.
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: pageFg),
    ),
    cardTheme: CardThemeData(
      // The 1.2.0 card (owner decision Q2): the cardSurface fill, a 1 px
      // `border` token edge and a soft shadow. The edge is 1.41:1 against
      // the light card and 1.61:1 against the dark one, so the shadow does
      // part of the separating; to be judged on the device, and interactive
      // cards go back to `outline` if it reads too faint.
      //
      // `Card` draws a Material elevation shadow and cannot take the
      // brief's exact shadow (offset 0,5, blur 18); elevation 2 in the
      // brief's shadow color is the nearest Material equivalent. The exact
      // shadow is `AppPalette.cardShadow`, for cards drawn by hand.
      color: colorScheme.surfaceContainerHigh,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(appCardRadius),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: palette.cardShadow.first.color.withValues(alpha: 1),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      // Explicit colors: M3's default FilledButton pulls colorScheme.primary
      // (the brand orange). The button is primaryButton in both themes,
      // with a 1 px edge in dark mode only (Q1); a disabled button has no
      // edge.
      style: FilledButton.styleFrom(
        backgroundColor: palette.button,
        foregroundColor: palette.onButton,
        disabledBackgroundColor: palette.disabledFill,
        disabledForegroundColor: palette.disabledLabel,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: buttonShape,
        textStyle: textTheme.labelLarge,
      ).copyWith(side: buttonEdge),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colorScheme.secondary,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: buttonShape,
        side: BorderSide(color: colorScheme.secondary),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      // Explicit color: M3's default TextButton foreground is
      // colorScheme.primary, the brand orange, which is not a text color
      // on the page (2.27:1). linkAndActive instead, in both themes.
      style: TextButton.styleFrom(
        foregroundColor: colorScheme.secondary,
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(appInputRadius),
        borderSide: BorderSide.none,
      ),
      // The field's edge reaches 3:1 against the card and the page (Q3).
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(appInputRadius),
        borderSide: BorderSide(color: palette.inputBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(appInputRadius),
        borderSide: BorderSide(color: colorScheme.secondary, width: 2),
      ),
      hintStyle:
          textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
    ),
    // Bottom nav is a custom widget (`FloatingNavShell`), styled directly
    // from the theme there — no NavigationBarThemeData needed here.
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
