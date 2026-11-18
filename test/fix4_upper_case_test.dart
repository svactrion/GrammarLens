import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grammar_lens/data/topics.dart';
import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/models/avatar.dart';
import 'package:grammar_lens/models/climb_theme.dart';
import 'package:grammar_lens/models/medal_tier.dart';
import 'package:grammar_lens/utils/upper_case.dart';
import 'package:grammar_lens/widgets/medal_celebration.dart';
import 'package:grammar_lens/widgets/practice_preparing.dart';
import 'package:grammar_lens/widgets/practice_reviewing.dart';
import 'package:grammar_lens/widgets/rest_scene.dart';

import 'support/fix3_render.dart';

/// Fix round 4, item 8 (SPEC §3.7 v12): upper case follows the language.
/// On the device (Turkish) "GERI BILDIRIMIN YOLDA" and "TILKI RÜYASINDA"
/// were shown; right: GERİ BİLDİRİMİN YOLDA, TİLKİ RÜYASINDA. With
/// `FIX4_CAPTURE=1` the Turkish renders go to `build/fix4-captures/`.
void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));

  group('upperCaseIn', () {
    test('Turkish and Azerbaijani: i → İ, ı → I', () {
      expect(
          upperCaseIn('tr', 'geri bildirimin yolda'), 'GERİ BİLDİRİMİN YOLDA');
      expect(upperCaseIn('tr', 'Tilki rüyasında…'), 'TİLKİ RÜYASINDA…');
      expect(upperCaseIn('tr', 'kullanıldı'), 'KULLANILDI');
      expect(upperCaseIn('az', 'bilik'), 'BİLİK');
      expect(upperCaseIn('tr_TR', 'iyi'), 'İYİ');
      expect(upperCaseIn('tr-TR', 'iyi'), 'İYİ');
    });

    test('every other language: the default mapping', () {
      expect(upperCaseIn('en', 'tip of the day'), 'TIP OF THE DAY');
      expect(upperCaseIn('de', 'Straße'), 'STRASSE');
      expect(upperCaseIn('es', 'próximo'), 'PRÓXIMO');
      // Topic names stay English in every language (SPEC §3.7).
      expect(upperCaseIn('en', 'Articles'), 'ARTICLES');
    });
  });

  /// No dotless capital I where the Turkish source has a dotted i.
  void expectTurkishCapitals(String source, String shown) {
    expect(shown, upperCaseIn('tr', source));
    final lower = source.toLowerCase();
    for (var i = 0; i < lower.length && i < shown.length; i++) {
      if (lower[i] == 'i') {
        expect(shown[i], 'İ', reason: '"$shown" at $i');
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('V20 in Turkish: "GERİ BİLDİRİMİN YOLDA" (${brightness.name})',
        (tester) async {
      await pumpFix3(
          tester,
          const Scaffold(
              body: PracticeReviewing(
                  topic: 'Articles', answers: ['a'], hero: Avatar.fox)),
          locale: const Locale('tr'),
          brightness: brightness,
          settle: false);
      await tester.pump(const Duration(seconds: 2));
      final shown = upperCaseIn('tr', tr.practiceReviewingOnItsWay);
      expect(find.text(shown), findsOneWidget);
      expect(find.text('GERI BILDIRIMIN YOLDA'), findsNothing);
      expectTurkishCapitals(tr.practiceReviewingOnItsWay, shown);
      await fix4Capture(tester, 'tr-capitals-V20',
          dark: brightness == Brightness.dark);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('V24f in Turkish: "TİLKİ RÜYASINDA…" (${brightness.name})',
        (tester) async {
      await pumpFix3(
          tester,
          Scaffold(
            body: SingleChildScrollView(
              child: RestScene(
                theme: ClimbThemes.emberPeak,
                days: 30,
                steps: 3,
                hero: Avatar.fox,
                name: 'Ada',
                testLine: tr.restDailyTestDone(4, 5),
                practiceLine: tr.restFreeTicketUsed,
                clock: () => DateTime(2026, 11, 18, 13, 36),
                offer: RestOffer(
                    weakSpot: 'Missing Article',
                    trialDays: 7,
                    topics: 5,
                    onWake: () async {}),
              ),
            ),
          ),
          size: const Size(428, 926),
          brightness: brightness,
          locale: const Locale('tr'));
      final source = tr.restDreamingOf(Avatar.fox.name(tr));
      final shown = upperCaseIn('tr', source);
      expect(shown, startsWith('TİLKİ'));
      expect(find.text(shown), findsOneWidget);
      expectTurkishCapitals(source, shown);
      // The chip and the ticket stub are written in capitals in the ARB.
      expect(find.text('PREMIUM'), findsOneWidget);
      expect(find.text(tr.restTicketUsedStub), findsOneWidget);
      await fix4Capture(tester, 'tr-capitals-V24f',
          dark: brightness == Brightness.dark);
    });
  }

  testWidgets('V18 in Turkish: "BİLİYOR MUYDUN?"', (tester) async {
    await pumpFix3(
        tester,
        Scaffold(
          body: PracticePreparing(
              topic: kTopics.first,
              hero: Avatar.fox,
              questionCount: 5,
              message: tr.practicePreparingTopic(5, 'Articles')),
        ),
        locale: const Locale('tr'),
        settle: false);
    await tester.pump(const Duration(seconds: 2));
    final shown = upperCaseIn('tr', tr.practiceDidYouKnow);
    expect(find.text(shown), findsOneWidget);
    expectTurkishCapitals(tr.practiceDidYouKnow, shown);
    await fix4Capture(tester, 'tr-capitals-V18');
  });

  testWidgets('R05 in Turkish: the medal eyebrow', (tester) async {
    await pumpFix3(
        tester,
        Builder(
          builder: (context) => MedalCelebration.tier(
            tier: MedalTier.silver,
            theme: ClimbThemes.emberPeak,
            month: 11,
            onClose: () {},
            l10n: context.l10n,
            hero: Avatar.fox,
          ),
        ),
        locale: const Locale('tr'),
        settle: false);
    await tester.pump(const Duration(seconds: 2));
    final source = tr.medalEyebrow(MedalTier.silver.label(tr));
    final shown = upperCaseIn('tr', source);
    expect(find.text(shown), findsOneWidget);
    expectTurkishCapitals(source, shown);
    await fix4Capture(tester, 'tr-capitals-R05');
  });
}
