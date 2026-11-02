/// The interface language (1.4.0 B3; docs/1.4.0-b3-batch0-report.md §2).
///
/// English is the template and the fallback; the generated
/// [AppLocalizations] comes from `lib/l10n/*.arb` (see `l10n.yaml`). The
/// questions and every AI explanation stay English in every interface
/// language (1.4.0 D2), and so do the feature names (D6).
library;

import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';
import 'generated/app_localizations_en.dart';

export 'generated/app_localizations.dart';
export 'labels.dart';

extension AppLocalizationsX on BuildContext {
  /// The interface strings for this context's locale.
  ///
  /// Falls back to English when no [AppLocalizations] is in the tree. The
  /// app's own `MaterialApp` always has the delegate
  /// (`test/l10n_app_test.dart` pins it); the fallback is for widget tests
  /// that pump a screen inside a bare `MaterialApp`, so moving a screen's
  /// strings to the ARB (B4) never needs every such test rewritten.
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ?? _english;
}

final AppLocalizations _english = AppLocalizationsEn();

/// A choice of interface language: [system] follows the device, the others
/// fix one language. Order: the picker's.
enum AppLanguage {
  system(null, '', 'system', ''),
  en(Locale('en'), 'English', 'en', 'en'),
  ja(Locale('ja'), '日本語', 'ja', 'ja'),
  ko(Locale('ko'), '한국어', 'ko', 'ko'),
  es(Locale('es'), 'Español', 'es', 'es'),
  // One Brazilian Portuguese text declared as `pt` (report §8 Q1): a
  // European-Portuguese device gets it rather than English, and gen-l10n
  // requires the base-language file anyway. Analytics keeps `pt-BR`.
  ptBR(Locale('pt'), 'Português (Brasil)', 'pt', 'pt-BR'),
  tr(Locale('tr'), 'Türkçe', 'tr', 'tr'),
  ar(Locale('ar'), 'العربية', 'ar', 'ar'),
  de(Locale('de'), 'Deutsch', 'de', 'de');

  const AppLanguage(
      this.locale, this.endonym, this.storageValue, this.analyticsValue);

  /// The locale this choice fixes; null for [system].
  final Locale? locale;

  /// The language's own name, shown in the picker in every interface
  /// language (never translated, so not in the ARB). Empty for [system],
  /// whose label is `settingsLanguageSystemDefault`.
  final String endonym;

  /// How the choice is stored (`language_settings.language`).
  final String storageValue;

  /// The `ui_language` user property's value for this language
  /// (docs/analytics-plan.md §3). Empty for [system], which is never sent:
  /// the resolved language is.
  final String analyticsValue;

  /// The stored choice, or [system] for no row or an unknown value.
  static AppLanguage fromStorage(String? value) {
    for (final language in values) {
      if (language.storageValue == value) return language;
    }
    return system;
  }

  /// The language of [locale] (by language code), or [en] when the app has
  /// none for it.
  static AppLanguage forLocale(Locale locale) {
    for (final language in values) {
      if (language.locale?.languageCode == locale.languageCode) {
        return language;
      }
    }
    return en;
  }

  /// The choices the picker offers: [system], then every language whose
  /// strings exist ([supported], the generated
  /// `AppLocalizations.supportedLocales`). Until the translations land
  /// (B5) that is English alone; each ARB file added makes its language
  /// appear, with nothing else to change.
  static List<AppLanguage> available(
      [Iterable<Locale> supported = AppLocalizations.supportedLocales]) {
    final codes = {for (final l in supported) l.languageCode};
    return [
      for (final language in values)
        if (language == system || codes.contains(language.locale!.languageCode))
          language,
    ];
  }
}

/// The locale the interface is shown in for the device's [preferred]
/// locales (most preferred first): the first whose language code the app
/// has strings for, country and script ignored (`pt-PT` → `pt`, `es-MX` →
/// `es`); English when none matches.
Locale resolveAppLocale(
  List<Locale>? preferred, [
  Iterable<Locale> supported = AppLocalizations.supportedLocales,
]) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return const Locale('en');
}

/// The locale [choice] shows the interface in, given the device's
/// [preferred] locales: the chosen language when the app has its strings,
/// else (System default, or a stored choice whose strings are not in this
/// build) the device's resolved language.
Locale effectiveAppLocale(
  AppLanguage choice,
  List<Locale>? preferred, [
  Iterable<Locale> supported = AppLocalizations.supportedLocales,
]) {
  final fixed = choice.locale;
  if (fixed != null &&
      supported.any((l) => l.languageCode == fixed.languageCode)) {
    return fixed;
  }
  return resolveAppLocale(preferred, supported);
}
