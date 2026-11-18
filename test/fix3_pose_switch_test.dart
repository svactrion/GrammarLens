import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/widgets/companion_view.dart';

/// Fix round 3, C6 (SPEC §3.3, v11): every change of a companion's pose
/// cross-fades in 200 ms, the new pose scaling 0.96 → 1, in CompanionView
/// so every screen gets it (Profile's wave on tap, V24 / V24f's wake, V04,
/// V05b). Reduce Motion: a 150 ms fade, no scale.
void main() {
  Future<void> pump(WidgetTester tester, CompanionMood mood,
      {bool reduce = false}) async {
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: CompanionView(hero: Avatar.fox, mood: mood)),
      ),
    ));
  }

  final idle = CompanionView.poseKey(
      CompanionView.assetFor(Avatar.fox, CompanionMood.idle));
  final wave = CompanionView.poseKey(
      CompanionView.assetFor(Avatar.fox, CompanionMood.wave));

  double opacityOf(WidgetTester tester, Key key) => tester
      .widget<FadeTransition>(find
          .ancestor(of: find.byKey(key), matching: find.byType(FadeTransition))
          .first)
      .opacity
      .value;

  double? scaleOf(WidgetTester tester, Key key) {
    final scale = find.ancestor(
        of: find.byKey(key), matching: find.byType(ScaleTransition));
    if (scale.evaluate().isEmpty) return null;
    return tester.widget<ScaleTransition>(scale.first).scale.value;
  }

  testWidgets(
      'idle → wave: both poses for 200 ms, the old fading out, the new '
      'fading in from 0.96', (tester) async {
    await pump(tester, CompanionMood.idle);
    await pump(tester, CompanionMood.wave);
    expect(find.byKey(idle), findsOneWidget);
    expect(find.byKey(wave), findsOneWidget);
    expect(scaleOf(tester, wave), closeTo(.96, .001));
    expect(scaleOf(tester, idle), isNull, reason: 'the old pose only fades');

    await tester.pump(const Duration(milliseconds: 100));
    expect(opacityOf(tester, wave), closeTo(.5, .01));
    expect(opacityOf(tester, idle), closeTo(.5, .01));
    expect(scaleOf(tester, wave), closeTo(.98, .001));

    await tester.pump(const Duration(milliseconds: 101));
    expect(find.byKey(idle), findsNothing);
    expect(scaleOf(tester, wave), 1);
  });

  testWidgets('Reduce Motion: a plain 150 ms fade', (tester) async {
    await pump(tester, CompanionMood.idle, reduce: true);
    await pump(tester, CompanionMood.wave, reduce: true);
    expect(scaleOf(tester, wave), isNull);
    await tester.pump(const Duration(milliseconds: 75));
    expect(opacityOf(tester, wave), closeTo(.5, .01));
    await tester.pump(const Duration(milliseconds: 76));
    expect(find.byKey(idle), findsNothing);
    expect(CompanionView.reducedPoseSwitch, const Duration(milliseconds: 150));
  });
}
