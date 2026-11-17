import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/motion.dart';
import 'package:grammar_lens/widgets/companion_view.dart';

/// SPEC §3.5 (V00-CompanionSystem, X01): screens pass a mood; the widget
/// picks the image and the prop.
void main() {
  Future<void> pump(WidgetTester tester, Avatar hero, CompanionMood mood,
      {bool reduce = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Center(child: CompanionView(hero: hero, mood: mood, size: 110)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 800));
  }

  Set<String> images(WidgetTester tester) => {
        for (final image in tester.widgetList<Image>(find.byType(Image)))
          switch (image.image) {
            AssetImage(:final assetName) => assetName,
            ResizeImage(imageProvider: AssetImage(:final assetName)) =>
              assetName,
            _ => '?',
          },
      };

  test('idle and oops use the base avatar; the other moods their pose', () {
    for (final hero in Avatar.values) {
      expect(CompanionView.assetFor(hero, CompanionMood.idle), hero.assetPath);
      expect(CompanionView.assetFor(hero, CompanionMood.oops), hero.assetPath);
      for (final mood in [
        CompanionMood.wave,
        CompanionMood.cheer,
        CompanionMood.think,
        CompanionMood.inspect,
        CompanionMood.sad,
        CompanionMood.sleep,
      ]) {
        expect(CompanionView.assetFor(hero, mood),
            'assets/companions/${hero.poseName}_${mood.name}.webp');
      }
    }
  });

  test('each mood has its prop (X01)', () {
    expect(
        CompanionView.propFor(CompanionMood.cheer), endsWith('sparkle.webp'));
    expect(
        CompanionView.propFor(CompanionMood.think), endsWith('thought.webp'));
    expect(CompanionView.propFor(CompanionMood.sad), endsWith('cloud.webp'));
    expect(CompanionView.propFor(CompanionMood.sleep), endsWith('zzz.webp'));
    expect(CompanionView.propFor(CompanionMood.oops), endsWith('sweat.webp'));
    expect(CompanionView.propFor(CompanionMood.idle), isNull);
    expect(CompanionView.propFor(CompanionMood.wave), isNull);
    expect(CompanionView.propFor(CompanionMood.inspect), isNull);
  });

  testWidgets('renders the pose and the prop for every mood', (tester) async {
    for (final mood in CompanionMood.values) {
      await pump(tester, Avatar.panda, mood);
      final shown = images(tester);
      expect(shown, contains(CompanionView.assetFor(Avatar.panda, mood)));
      final prop = CompanionView.propFor(mood);
      if (prop != null) expect(shown, contains(prop));
    }
  });

  testWidgets('says who it is to VoiceOver', (tester) async {
    await pump(tester, Avatar.frog, CompanionMood.wave);
    expect(find.bySemanticsLabel('Frog, your companion'), findsOneWidget);
  });

  testWidgets('keeps its size in every mood', (tester) async {
    for (final mood in CompanionMood.values) {
      await pump(tester, Avatar.fox, mood);
      expect(tester.getSize(find.byType(CompanionView)), const Size(110, 110));
    }
  });

  testWidgets('loops run when on, and stop under Reduce Motion',
      (tester) async {
    AppMotion.loopsEnabled = true;
    addTearDown(() => AppMotion.loopsEnabled = false);
    await pump(tester, Avatar.fox, CompanionMood.idle);
    expect(tester.binding.hasScheduledFrame, isTrue);
    await pump(tester, Avatar.koala, CompanionMood.idle, reduce: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
