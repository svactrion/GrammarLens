import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/widgets/medal_badge.dart';

/// Batch 5 (N1–N3, N10, N23): the medal draws a composed image; the caller
/// gives the disc, the widget keeps the stars' room.
void main() {
  test('every theme and tier names its asset; an unknown theme is Green', () {
    for (final theme in ClimbThemes.all) {
      for (final tier in MedalTier.values) {
        expect(MedalArt.monthly(theme.id, tier),
            'assets/medals/medal_${theme.id}_${tier.name}.webp');
      }
    }
    expect(MedalArt.monthly('a_theme_from_a_newer_build', MedalTier.gold),
        'assets/medals/medal_green_slope_gold.webp');
    expect(MedalArt.welcome, 'assets/medals/medal_welcome.webp');
  });

  Future<void> pump(WidgetTester tester, Widget medal) =>
      tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: Align(alignment: Alignment.topLeft, child: medal)));

  testWidgets('a monthly medal is the disc wide and keeps the stars above',
      (tester) async {
    await pump(
        tester,
        MedalBadge.monthly(
            themeId: 'ember_peak', tier: MedalTier.silver, disc: 48));
    expect(tester.getSize(find.byType(MedalBadge)),
        const Size(48, 48 * (1 + MedalArt.starsAbove)));
    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName,
        'assets/medals/medal_ember_peak_silver.webp');
    expect(image.width, closeTo(48 * MedalArt.canvasOverDisc, 1e-9));
    expect(find.byType(ColorFiltered), findsNothing);
  });

  testWidgets('the Welcome badge is a square: its ribbon needs no room',
      (tester) async {
    await pump(tester, const MedalBadge.welcome(disc: 112));
    expect(tester.getSize(find.byType(MedalBadge)), const Size(112, 112));
  });

  testWidgets('N10: an unearned medal is faded, opacity 0.5, saturation 0.6',
      (tester) async {
    await pump(
        tester,
        MedalBadge.monthly(
            themeId: 'green_slope',
            tier: MedalTier.gold,
            disc: 48,
            earned: false));
    expect(find.byType(ColorFiltered), findsOneWidget);
    final m = MedalBadge.unearnedMatrix;
    // Alpha row: 0.5 of the image's alpha.
    expect(m.sublist(15), [0, 0, 0, .5, 0]);
    // A grey pixel stays grey; a pure red keeps 0.6 of its saturation.
    double row(int r, List<double> c) =>
        m[r * 5] * c[0] + m[r * 5 + 1] * c[1] + m[r * 5 + 2] * c[2];
    expect(row(0, [.5, .5, .5]), closeTo(.5, 1e-9));
    expect(row(0, [1, 0, 0]) - row(1, [1, 0, 0]), closeTo(.6, 1e-9));
  });

  testWidgets(
      'the image is excluded from semantics: the caller says what '
      'it is', (tester) async {
    await pump(tester, const MedalBadge.welcome(disc: 64));
    expect(
        tester.widget<Image>(find.byType(Image)).excludeFromSemantics, isTrue);
  });
}
