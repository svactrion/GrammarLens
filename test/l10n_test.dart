import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';
import 'package:grammar_lens/screens/language_picker_screen.dart';

/// 1.4.0 B3: the interface-language model, the locale resolution and the
/// picker (docs/1.4.0-b3-batch0-report.md §2.3–§2.5).
void main() {
  // The eight languages as they will be once B5's ARB files exist.
  const all = [
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('es'),
    Locale('pt'),
    Locale('tr'),
    Locale('ar'),
    Locale('de'),
  ];

  group('resolveAppLocale', () {
    test('the first preferred language the app has wins; country ignored', () {
      expect(resolveAppLocale(const [Locale('pt', 'PT')], all),
          const Locale('pt'));
      expect(resolveAppLocale(const [Locale('es', 'MX')], all),
          const Locale('es'));
      expect(resolveAppLocale(const [Locale('ar', 'EG')], all),
          const Locale('ar'));
      expect(
          resolveAppLocale(
              const [Locale('zh'), Locale('ru'), Locale('ko', 'KR')], all),
          const Locale('ko'));
    });

    test('English when nothing matches or nothing is preferred', () {
      expect(resolveAppLocale(const [Locale('zh'), Locale('fr')], all),
          const Locale('en'));
      expect(resolveAppLocale(null, all), const Locale('en'));
      expect(resolveAppLocale(const [], all), const Locale('en'));
    });

    test('only the languages this build has strings for count', () {
      // French is not one of the eight: never offered, never resolved.
      expect(resolveAppLocale(const [Locale('fr')]), const Locale('en'));
      expect(AppLocalizations.supportedLocales, contains(const Locale('en')));
    });
  });

  group('effectiveAppLocale', () {
    test('a fixed choice wins when its strings exist', () {
      expect(effectiveAppLocale(AppLanguage.de, const [Locale('ja')], all),
          const Locale('de'));
    });

    test('System default, or a choice without strings, follows the device', () {
      expect(effectiveAppLocale(AppLanguage.system, const [Locale('ja')], all),
          const Locale('ja'));
      expect(
          effectiveAppLocale(
              AppLanguage.de, const [Locale('ja')], const [Locale('en')]),
          const Locale('en'));
    });
  });

  group('AppLanguage', () {
    test('storage values round-trip; unknown and missing are System default',
        () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromStorage(language.storageValue), language);
      }
      expect(AppLanguage.fromStorage(null), AppLanguage.system);
      expect(AppLanguage.fromStorage('fr'), AppLanguage.system);
    });

    test('forLocale maps by language code, English for the rest', () {
      expect(AppLanguage.forLocale(const Locale('pt', 'BR')), AppLanguage.ptBR);
      expect(AppLanguage.forLocale(const Locale('ja', 'JP')), AppLanguage.ja);
      expect(AppLanguage.forLocale(const Locale('fr')), AppLanguage.en);
    });

    test('available: System default plus the languages with strings', () {
      // Follows the build: each ARB file B5 adds makes its language appear.
      final shipped = {
        for (final l in AppLocalizations.supportedLocales) l.languageCode
      };
      expect(AppLanguage.available(), [
        AppLanguage.system,
        for (final l in AppLanguage.values)
          if (l.locale != null && shipped.contains(l.locale!.languageCode)) l,
      ]);
      expect(AppLanguage.available(all), AppLanguage.values);
    });

    test('each language is named in its own script', () {
      expect(
          AppLanguage.values
              .where((l) => l != AppLanguage.system)
              .map((l) => l.endonym),
          [
            'English',
            '日本語',
            '한국어',
            'Español',
            'Português (Brasil)',
            'Türkçe',
            'العربية',
            'Deutsch',
          ]);
    });
  });

  group('context.l10n', () {
    testWidgets('reads the delegate when it is there', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (context) {
          l10n = context.l10n;
          return const SizedBox();
        }),
      ));
      expect(l10n.settingsLanguageLabel, 'Language');
      expect(l10n.localeName, 'en');
    });

    testWidgets('falls back to English in a bare MaterialApp', (tester) async {
      late AppLocalizations l10n;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          l10n = context.l10n;
          return const SizedBox();
        }),
      ));
      expect(l10n.settingsLanguageSystemDefault, 'System default');
    });
  });

  group('LanguagePickerScreen', () {
    Future<List<AppLanguage>> pumpPicker(
      WidgetTester tester, {
      AppLanguage current = AppLanguage.system,
      List<AppLanguage>? choices,
    }) async {
      final picked = <AppLanguage>[];
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LanguagePickerScreen(
                  current: current,
                  onSelected: picked.add,
                  choices: choices,
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return picked;
    }

    testWidgets(
        'System default (with the device language), then each language '
        'the build has strings for, and no other', (tester) async {
      tester.view.physicalSize = const Size(390, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPicker(tester);
      expect(find.text('Language'), findsOneWidget);
      expect(
          find.text('Questions and feedback stay in English.'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('Now: English'), findsOneWidget);
      final shipped = {
        for (final l in AppLocalizations.supportedLocales) l.languageCode
      };
      for (final language in AppLanguage.values.skip(1)) {
        expect(
            find.byKey(LanguagePickerScreen.optionKey(language)),
            shipped.contains(language.locale!.languageCode)
                ? findsOneWidget
                : findsNothing,
            reason: language.name);
      }
    });

    testWidgets('all eight languages, under their own names, once they exist',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1400) * 3;
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await pumpPicker(tester, choices: AppLanguage.values);
      for (final language in AppLanguage.values.skip(1)) {
        expect(find.text(language.endonym), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('the current choice is the selected one', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpPicker(tester, current: AppLanguage.en);
      expect(
          tester.getSemantics(
              find.byKey(LanguagePickerScreen.optionKey(AppLanguage.en))),
          matchesSemantics(
              label: 'English',
              isSelected: true,
              hasSelectedState: true,
              isInMutuallyExclusiveGroup: true,
              isButton: true,
              hasTapAction: true,
              isFocusable: true,
              hasFocusAction: true));
      expect(find.byIcon(Icons.radio_button_checked_rounded), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a tap applies the choice and goes back', (tester) async {
      final picked = await pumpPicker(tester);
      await tester
          .tap(find.byKey(LanguagePickerScreen.optionKey(AppLanguage.en)));
      await tester.pumpAndSettle();
      expect(picked, [AppLanguage.en]);
      expect(find.byType(LanguagePickerScreen), findsNothing);
    });
  });

  // A one-unit trial reads in the singular where the language inflects the
  // unit (German "1 Woche", not "1 Wochen"); English needs no plural there.
  test('a one-unit trial length is singular in every language', () {
    const one = {
      'de': ['1 Tag', '1 Woche', '1 Monat', '1 Jahr'],
    };
    for (final MapEntry(key: lang, value: expected) in one.entries) {
      final l10n = lookupAppLocalizations(Locale(lang));
      expect([
        l10n.paywallTrialLengthDay(1),
        l10n.paywallTrialLengthWeek(1),
        l10n.paywallTrialLengthMonth(1),
        l10n.paywallTrialLengthYear(1),
      ], expected, reason: lang);
    }
  });
}
