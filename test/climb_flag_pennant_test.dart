import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/theme.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_point_table.dart';
import 'package:grammar_lens/widgets/monthly_climb/climb_save_points.dart';
import 'package:grammar_lens/widgets/monthly_climb/monthly_mountain.dart';

/// G10: only Red Canyon recolours the flag's pennant (blue against its red
/// rock); the pole, the stones and the other themes' flag are unchanged.
void main() {
  tearDown(() => ClimbSavePoints.debugPennantColorOverride = null);

  /// The brand orange the pennant is painted in, at its median luminance.
  const orange = Color(0xFFF0843A);

  double hue(Color c) => HSVColor.fromColor(c).hue;

  test('only Red Canyon has a pennant colour, one constant, blue', () {
    for (final theme in ClimbThemes.all) {
      expect(ClimbSavePoints.pennantColorFor(theme),
          theme == ClimbThemes.redCanyon ? ClimbThemes.redCanyonPennant : null,
          reason: theme.id);
    }
    expect(hue(ClimbThemes.redCanyonPennant), inInclusiveRange(180, 240));
  });

  test('a debug override never recolours a theme that keeps its orange', () {
    ClimbSavePoints.debugPennantColorOverride = const Color(0xFF1E4FA3);
    expect(ClimbSavePoints.pennantColorFor(ClimbThemes.greenSlope), isNull);
    expect(ClimbSavePoints.pennantColorFor(ClimbThemes.redCanyon),
        const Color(0xFF1E4FA3));
  });

  test('the recolour turns the orange pennant blue and keeps its shading', () {
    final m = ClimbSavePoints.pennantMatrix(ClimbThemes.redCanyonPennant);
    final lit = ClimbSavePoints.apply(m, orange);
    expect(hue(lit), inInclusiveRange(180, 240));
    // Darker pixels of the pennant stay darker.
    final shade = ClimbSavePoints.apply(m, const Color(0xFFB0602A));
    expect(shade.computeLuminance(), lessThan(lit.computeLuminance()));
    // A pixel at the pennant's median luminance takes the colour itself.
    const grey = 0.5645;
    final mid = ClimbSavePoints.apply(
        m, const Color.from(alpha: 1, red: grey, green: grey, blue: grey));
    expect(mid.r, closeTo(ClimbThemes.redCanyonPennant.r, .01));
    expect(mid.b, closeTo(ClimbThemes.redCanyonPennant.b, .01));
    expect(climbPennantLuminance, grey);
  });

  test('compose applies the inner matrix first', () {
    final a = ClimbSavePoints.matrix(lit: 0, darkGain: (0.6, 0.6, 0.8));
    final b = ClimbSavePoints.pennantMatrix(ClimbThemes.redCanyonPennant);
    final both = ClimbSavePoints.apply(ClimbSavePoints.compose(a, b), orange);
    final step = ClimbSavePoints.apply(a, ClimbSavePoints.apply(b, orange));
    expect(both.r, closeTo(step.r, 1e-9));
    expect(both.g, closeTo(step.g, 1e-9));
    expect(both.b, closeTo(step.b, 1e-9));
    expect(both.a, closeTo(step.a, 1e-9));
  });

  Widget mountain(ClimbTheme theme, int steps, Brightness b) => MaterialApp(
      theme: buildAppTheme(b),
      home: Scaffold(
          body: SizedBox(
              width: 341.25,
              child: MonthlyMountain(
                  days: 31,
                  completedDays: steps,
                  avatar: Avatar.values.first,
                  theme: theme))));

  final flagKey = ValueKey('climb_save_point_${ClimbSavePoints.flag.clearing}');
  const pennantKey = ValueKey('climb_flag_pennant');

  for (final b in Brightness.values) {
    for (final steps in [30, 31]) {
      testWidgets(
          'Red Canyon, ${b.name}, day $steps: the pole and stones '
          'as they are, the pennant blue, both in the same state',
          (tester) async {
        await tester.pumpWidget(mountain(ClimbThemes.redCanyon, steps, b));
        await tester.pumpAndSettle();
        final base = tester.widget<ClimbObjectLayer>(find.byKey(flagKey));
        final pennant = tester.widget<ClimbObjectLayer>(find.byKey(pennantKey));
        final state = ClimbSavePoints.matrix(
            lit: steps == 31 ? 1 : 0,
            darkGain: b == Brightness.dark
                ? climbObjectDarkGain[ClimbThemes.redCanyon.id]
                : null);
        // The pole and the stones: the flag without its pennant, through
        // the plain state matrix, like every other object.
        expect(base.asset, ClimbSavePoints.flagBaseAsset);
        expect(base.matrix, state);
        // The pennant: recoloured, then the same state.
        expect(pennant.asset, ClimbSavePoints.pennantAsset);
        expect(
            pennant.matrix,
            ClimbSavePoints.compose(state,
                ClimbSavePoints.pennantMatrix(ClimbThemes.redCanyonPennant)));
        if (steps == 31 && b == Brightness.light) {
          expect(hue(ClimbSavePoints.apply(pennant.matrix, orange)),
              inInclusiveRange(180, 240));
        }
      });
    }
  }

  for (final theme in [
    ClimbThemes.greenSlope,
    ClimbThemes.emberPeak,
    ClimbThemes.glacierPeak
  ]) {
    testWidgets('${theme.id}: the flag exactly as before', (tester) async {
      await tester.pumpWidget(mountain(theme, 31, Brightness.light));
      await tester.pumpAndSettle();
      final flag = tester.widget<ClimbObjectLayer>(find.byKey(flagKey));
      expect(flag.asset, ClimbSavePoints.assetFor('summit_flag'));
      expect(flag.matrix, ClimbSavePoints.matrix(lit: 1));
      expect(find.byKey(pennantKey), findsNothing);
    });
  }
}
