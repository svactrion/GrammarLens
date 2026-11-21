import 'package:flutter/widgets.dart';

/// SPEC §3.7 (v12): upper case follows the language. Dart's
/// `toUpperCase()` ignores the locale, so a Turkish "geri" became "GERI"
/// instead of "GERİ". Every label shown in capitals goes through here (or
/// its ARB string is written in capitals): Turkish and Azerbaijani map the
/// dotted i to İ (and the dotless ı to I, as the default mapping already
/// does); "ß" becomes "SS" (German); every other language keeps the
/// default mapping. A brand or plan name ("Premium", the ARB's own
/// "PREMIUM") and the English topic names take the English rules:
/// `upperCaseIn('en', …)`.
///
/// [language] is a language code or a locale name (`tr`, `tr_TR`, `tr-TR`).
String upperCaseIn(String language, String text) {
  final code = language.split(RegExp('[_-]')).first.toLowerCase();
  final dotted = code == 'tr' || code == 'az';
  final mapped = dotted ? text.replaceAll('i', 'İ') : text;
  return mapped.replaceAll('ß', 'SS').toUpperCase();
}

/// [upperCaseIn] for the app's current language.
String upperCaseFor(BuildContext context, String text) => upperCaseIn(
    Localizations.maybeLocaleOf(context)?.languageCode ?? 'en', text);
