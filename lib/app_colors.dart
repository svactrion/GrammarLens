import 'package:flutter/material.dart';

/// The UI polish palette (`docs/design/ui-polish/handoff/SPEC.md` §3.1):
/// the colours the new components use that have no [ColorScheme] role.
/// Page, card, border and text keep the app's existing theme values
/// (`theme.dart`); everything else is here, as a [ThemeExtension] with a
/// light and a dark set, so dark mode comes from the theme and never from
/// per-screen work (SY03). Read with [AppColors.of].
///
/// Orange and navy fills are the same in both themes (SPEC §3.1); the
/// surfaces (soft fills, lip, skeleton) follow the theme. Text, icons and
/// outlines in an accent colour use the `…Text` tokens, which have a light
/// counterpart on dark surfaces (SY03, v11; fix round 3, D): navy is a
/// fill only where white text sits on it.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// The solid bottom "lip" under cards (`0 Npx 0 lip`, no blur).
  final Color lip;

  /// Body text and secondary text on the new surfaces.
  final Color text;
  final Color muted;

  final Color orange;
  final Color orangeDeep;
  final Color onOrange;
  final Color cream;
  final Color navy;
  final Color navyDeep;
  final Color onNavy;

  /// Secondary text on a navy surface.
  final Color onNavyMuted;
  final Color sky;
  final Color onSky;
  final Color green;
  final Color greenDeep;
  final Color greenSoft;

  /// The lip under a green (correct) button.
  final Color greenLip;
  final Color onGreenSoft;
  final Color red;
  final Color redSoft;

  /// The lip under a red button.
  final Color redLip;
  final Color onRedSoft;
  final Color gold;
  final Color goldDeep;
  final Color goldSoft;

  /// A soft lilac tile (a topic's tile colour).
  final Color lilac;
  final Color onLilac;

  /// A wrong answer's segment and box (the boards' soft orange #E38B5A).
  final Color wrong;

  /// The Daily Test card while it loads (X05): a soft orange and its lip.
  final Color orangeSoft;

  /// The lip under [orangeSoft].
  final Color orangeSoftLip;

  /// A skeleton bar on a soft or card surface.
  final Color skeleton;

  /// The shimmer band crossing a skeleton bar.
  final Color skeletonHighlight;

  /// An empty progress segment / skeleton bar.
  final Color track;

  /// V05b's bar track: the warm light track on the onboarding page.
  final Color warmTrack;

  /// The page, card and border: the app's existing theme values
  /// (`surfaceContainerLow`, `surfaceContainerHigh`, `outlineVariant`) in
  /// both themes (SPEC §3.1 keeps them; SY03's #15141A / #211F27 are within
  /// a few steps of the app's dark #151517 / #252528, PROGRESS D1-1).
  final Color page;
  final Color card;
  final Color line;

  /// The disabled 3D button.
  final Color disabledFill;
  final Color disabledLabel;
  final Color disabledLip;

  /// Dim behind dialogs and sheets.
  final Color scrim;

  /// The snackbar capsule (SY02) and its text.
  final Color toast;
  final Color onToast;

  /// The rest scene's night sky (V24), top and bottom.
  final Color nightTop;
  final Color nightBottom;

  /// Accent text, icons and outlines on the page, cards and soft fills
  /// (SY03, v11): navy, orange, gold, green (right) and red (wrong) in
  /// light; light counterparts in dark. Each passes 4.5:1 on those
  /// surfaces (`test/fix3_contrast_test.dart`).
  final Color navyText;
  final Color orangeText;
  final Color goldText;
  final Color greenText;
  final Color redText;

  const AppColors({
    required this.lip,
    required this.text,
    required this.muted,
    required this.orange,
    required this.orangeDeep,
    required this.onOrange,
    required this.cream,
    required this.navy,
    required this.navyDeep,
    required this.onNavy,
    required this.onNavyMuted,
    required this.sky,
    required this.onSky,
    required this.green,
    required this.greenDeep,
    required this.greenSoft,
    required this.greenLip,
    required this.onGreenSoft,
    required this.red,
    required this.redSoft,
    required this.redLip,
    required this.onRedSoft,
    required this.gold,
    required this.goldDeep,
    required this.goldSoft,
    required this.lilac,
    required this.onLilac,
    required this.wrong,
    required this.orangeSoft,
    required this.orangeSoftLip,
    required this.skeleton,
    required this.skeletonHighlight,
    required this.track,
    required this.warmTrack,
    required this.page,
    required this.card,
    required this.line,
    required this.disabledFill,
    required this.disabledLabel,
    required this.disabledLip,
    required this.scrim,
    required this.toast,
    required this.onToast,
    required this.nightTop,
    required this.nightBottom,
    required this.navyText,
    required this.orangeText,
    required this.goldText,
    required this.greenText,
    required this.redText,
  });

  /// The theme's set; under a plain `ThemeData` (a widget pumped alone in a
  /// test), the set for its brightness.
  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  static const light = AppColors(
    lip: Color(0xFFE3D8C5),
    text: Color(0xFF1B1B1F),
    muted: Color(0xFF55555E),
    orange: Color(0xFFFF7A1A),
    orangeDeep: Color(0xFFC95A08),
    onOrange: Color(0xFF241200),
    cream: Color(0xFFFFF1E2),
    navy: Color(0xFF0D3B8F),
    navyDeep: Color(0xFF06245C),
    onNavy: Color(0xFFFFFFFF),
    onNavyMuted: Color(0xFFDFE8FA),
    sky: Color(0xFFDCE6FB),
    onSky: Color(0xFF0A2E70),
    green: Color(0xFF1F9D63),
    greenDeep: Color(0xFF13734A),
    greenSoft: Color(0xFFDDF3E7),
    greenLip: Color(0xFF0B4F32),
    onGreenSoft: Color(0xFF13734A),
    red: Color(0xFFB83232),
    redSoft: Color(0xFFFDE6E3),
    redLip: Color(0xFF8E2222),
    onRedSoft: Color(0xFF8E2222),
    gold: Color(0xFFFFC23C),
    goldDeep: Color(0xFF8A5C00),
    goldSoft: Color(0xFFFFF1C7),
    lilac: Color(0xFFEFE6FB),
    onLilac: Color(0xFF5B3A9E),
    wrong: Color(0xFFE38B5A),
    orangeSoft: Color(0xFFFDE4CF),
    orangeSoftLip: Color(0xFFF2CDAE),
    skeleton: Color(0x8CFFFFFF),
    skeletonHighlight: Color(0xD9FFFFFF),
    track: Color(0xFFE3DACB),
    warmTrack: Color(0xFFF3DCC4),
    page: Color(0xFFF3EFE6),
    card: Color(0xFFFFFBF4),
    line: Color(0xFFDED5C6),
    disabledFill: Color(0xFFE6DED1),
    disabledLabel: Color(0xFF857D72),
    disabledLip: Color(0xFFD2C7B6),
    scrim: Color(0x731B1B1F),
    toast: Color(0xFF26252B),
    onToast: Color(0xFFF2EEE8),
    nightTop: Color(0xFF1B2347),
    nightBottom: Color(0xFF3A2C3F),
    navyText: Color(0xFF0D3B8F),
    orangeText: Color(0xFFA14805),
    goldText: Color(0xFF8A5C00),
    greenText: Color(0xFF13734A),
    redText: Color(0xFFB83232),
  );

  static const dark = AppColors(
    // SY03 (v11): a lighter line under cards instead of a shadow colour.
    lip: Color(0xFF2E2C36),
    text: Color(0xFFF0ECE7),
    muted: Color(0xFFA9A6B2),
    orange: Color(0xFFFF7A1A),
    orangeDeep: Color(0xFFC95A08),
    onOrange: Color(0xFF241200),
    cream: Color(0xFF3A2A1C),
    navy: Color(0xFF0D3B8F),
    navyDeep: Color(0xFF06245C),
    onNavy: Color(0xFFFFFFFF),
    onNavyMuted: Color(0xFFDFE8FA),
    sky: Color(0xFF243859),
    onSky: Color(0xFFD8E1FF),
    // Fix round 3, D: white ticks and labels sit on it (3.4:1; the
    // brighter #2FB877 gave 2.6:1); it still reads 5.3:1 on the page.
    green: Color(0xFF1F9D63),
    greenDeep: Color(0xFF13734A),
    // SY03 (v11): right and wrong as dark tints with light text.
    greenSoft: Color(0xFF173A2A),
    greenLip: Color(0xFF0B4F32),
    onGreenSoft: Color(0xFF7FD6A6),
    // Fix round 3, D: white button labels on it (5.1:1; #E05A5A gave 3.6:1).
    red: Color(0xFFC93A3A),
    redSoft: Color(0xFF42201F),
    redLip: Color(0xFF8E2222),
    onRedSoft: Color(0xFFFF9C92),
    gold: Color(0xFFFFC23C),
    goldDeep: Color(0xFF8A5C00),
    goldSoft: Color(0xFF3D3218),
    lilac: Color(0xFF2E2742),
    onLilac: Color(0xFFD9C8FA),
    wrong: Color(0xFFE38B5A),
    orangeSoft: Color(0xFF3A2A1C),
    orangeSoftLip: Color(0xFF2A1E14),
    skeleton: Color(0x26FFFFFF),
    skeletonHighlight: Color(0x4DFFFFFF),
    track: Color(0xFF34323C),
    warmTrack: Color(0xFF3A2C22),
    page: Color(0xFF151517),
    card: Color(0xFF252528),
    line: Color(0xFF45454D),
    disabledFill: Color(0xFF36363B),
    disabledLabel: Color(0xFFACA8B2),
    disabledLip: Color(0xFF1F1E24),
    scrim: Color(0xB3000000),
    toast: Color(0xFF3A3842),
    onToast: Color(0xFFF2EEE8),
    nightTop: Color(0xFF0E1226),
    nightBottom: Color(0xFF231B28),
    navyText: Color(0xFF9DB8FF),
    orangeText: Color(0xFFFFA463),
    goldText: Color(0xFFF2C66B),
    greenText: Color(0xFF7FD6A6),
    redText: Color(0xFFFF9C92),
  );

  /// The wheel's slice colours, in hero order (SPEC §3.1). The same in both
  /// themes.
  /// V23's ribbon (the same in both themes, like the navy accent): the
  /// fill's top (the gradient runs to [navy]), its lip and tails, and its
  /// second line.
  static const ribbonTop = Color(0xFF1B4FB0);
  static const ribbonLip = Color(0xFF082A6B);
  static const onRibbonMuted = Color(0xFFC9D6FF);

  /// PF02's silver and bronze counters in light (the gold one is
  /// [goldSoft] / [goldText], the Welcome one [sky] / [onSky]); dark ones
  /// below.
  static const silverSoft = Color(0xFFECEFF3);

  /// V24f's Premium card runs from [navy] to this plum (both themes).
  static const premiumPlum = Color(0xFF2A1E5C);

  /// The rest scene's campfire (V24f v12; the same in both themes, the
  /// scene is a night scene): the outer flame's heart, middle and rim, its
  /// soft halo, the pale inner flame, the sparks, and the warm light on the
  /// ground (60 %); the shade under the status bar (55 %).
  static const fireCore = Color(0xFFFFE07A);
  static const fireMid = Color(0xFFFF9A2A);
  static const fireRim = Color(0xFFFF5A1F);
  static const fireHalo = Color(0xE6FF8C28);
  static const fireHeart = Color(0xFFFFF1B0);
  static const fireSpark = Color(0xFFFFC23C);
  static const fireGround = Color(0x99FFAA3C);
  static const sceneTopShade = Color(0x8C140E1E);
  static const onSilverSoft = Color(0xFF4B5563);
  static const bronzeSoft = Color(0xFFF6E7D8);
  static const onBronzeSoft = Color(0xFF8A5A2B);

  /// V23 v12's tier marks under the month's bar (light; dark uses
  /// [onBronzeSoftDark] / [onSilverSoftDark], gold [goldText]).
  static const bronzeMark = Color(0xFF9A6A3A);
  static const silverMark = Color(0xFF6F7782);

  /// The same counters on dark surfaces (SY03, v11: soft fills become dark
  /// tints of their hue with light text; fix round 3, D).
  static const silverSoftDark = Color(0xFF2E323A);
  static const onSilverSoftDark = Color(0xFFC9D1DC);
  static const bronzeSoftDark = Color(0xFF3A2A1E);
  static const onBronzeSoftDark = Color(0xFFE8B48A);

  static const List<Color> wheelSlices = [
    Color(0xFFFF7A1A),
    Color(0xFF0D3B8F),
    Color(0xFFFFC23C),
    Color(0xFF3FA36B),
    Color(0xFF4F8FE8),
    Color(0xFFE85D75),
    Color(0xFF8B5CF6),
    Color(0xFFC98A4B),
    Color(0xFFE2483D),
  ];

  /// Each hero's stage colour (picker / wheel background, ASSETS.md), in
  /// hero order.
  static const List<Color> _stageLight = [
    Color(0xFFFFD3AC),
    Color(0xFFE6E9F0),
    Color(0xFFE2E6EC),
    Color(0xFFDCF0D4),
    Color(0xFFD9ECFF),
    Color(0xFFFFEFC0),
    Color(0xFFFAEFDC),
    Color(0xFFF0E1D0),
    Color(0xFFFFD6CF),
  ];

  /// The stage colour of the hero at picker position [order]
  /// (`Avatar.order`) in [brightness]: the light colour, or in dark mode the
  /// same hue blended into the dark card so the hero still reads on it.
  static Color stageFor(int order, Brightness brightness) {
    final light = _stageLight[order.clamp(0, _stageLight.length - 1)];
    if (brightness == Brightness.light) return light;
    return Color.alphaBlend(light.withValues(alpha: .22), dark.card);
  }

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      lip: l(lip, other.lip),
      text: l(text, other.text),
      muted: l(muted, other.muted),
      orange: l(orange, other.orange),
      orangeDeep: l(orangeDeep, other.orangeDeep),
      onOrange: l(onOrange, other.onOrange),
      cream: l(cream, other.cream),
      navy: l(navy, other.navy),
      navyDeep: l(navyDeep, other.navyDeep),
      onNavy: l(onNavy, other.onNavy),
      onNavyMuted: l(onNavyMuted, other.onNavyMuted),
      sky: l(sky, other.sky),
      onSky: l(onSky, other.onSky),
      green: l(green, other.green),
      greenDeep: l(greenDeep, other.greenDeep),
      greenSoft: l(greenSoft, other.greenSoft),
      greenLip: l(greenLip, other.greenLip),
      onGreenSoft: l(onGreenSoft, other.onGreenSoft),
      red: l(red, other.red),
      redSoft: l(redSoft, other.redSoft),
      redLip: l(redLip, other.redLip),
      onRedSoft: l(onRedSoft, other.onRedSoft),
      gold: l(gold, other.gold),
      goldDeep: l(goldDeep, other.goldDeep),
      goldSoft: l(goldSoft, other.goldSoft),
      lilac: l(lilac, other.lilac),
      onLilac: l(onLilac, other.onLilac),
      wrong: l(wrong, other.wrong),
      orangeSoft: l(orangeSoft, other.orangeSoft),
      orangeSoftLip: l(orangeSoftLip, other.orangeSoftLip),
      skeleton: l(skeleton, other.skeleton),
      skeletonHighlight: l(skeletonHighlight, other.skeletonHighlight),
      track: l(track, other.track),
      warmTrack: l(warmTrack, other.warmTrack),
      page: l(page, other.page),
      card: l(card, other.card),
      line: l(line, other.line),
      disabledFill: l(disabledFill, other.disabledFill),
      disabledLabel: l(disabledLabel, other.disabledLabel),
      disabledLip: l(disabledLip, other.disabledLip),
      scrim: l(scrim, other.scrim),
      toast: l(toast, other.toast),
      onToast: l(onToast, other.onToast),
      nightTop: l(nightTop, other.nightTop),
      nightBottom: l(nightBottom, other.nightBottom),
      navyText: l(navyText, other.navyText),
      orangeText: l(orangeText, other.orangeText),
      goldText: l(goldText, other.goldText),
      greenText: l(greenText, other.greenText),
      redText: l(redText, other.redText),
    );
  }
}

/// Card shape of the new design (SPEC §3.2): radius 26–28, a 2 px border,
/// a solid bottom lip of 4–6 px, no blur.
BoxDecoration lipCard(
  AppColors c, {
  Color? color,
  Color? border,
  Color? lip,
  double radius = 26,
  double lipHeight = 5,
  double borderWidth = 2,
}) =>
    BoxDecoration(
      color: color ?? c.card,
      borderRadius: BorderRadius.circular(radius),
      border: borderWidth == 0
          ? null
          : Border.all(color: border ?? c.line, width: borderWidth),
      boxShadow: lipHeight == 0
          ? null
          : [BoxShadow(color: lip ?? c.lip, offset: Offset(0, lipHeight))],
    );
