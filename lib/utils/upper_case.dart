import 'package:flutter/widgets.dart';

/// SPEC §3.7 (v12): upper case follows the language. Dart's
/// `toUpperCase()` ignores the locale, so a Turkish "geri" became "GERI"
/// instead of "GERİ". Every label shown in capitals goes through here (or
/// its ARB string is written in capitals): Turkish and Azerbaijani map the
/// dotted i to İ (and the dotless ı to I, as the default mapping already
/// does); every other language keeps the default mapping.
String upperCaseIn(String languageCode, String text) {
  final dotted = languageCode == 'tr' || languageCode == 'az';
  return (dotted ? text.replaceAll('i', 'İ') : text).toUpperCase();
}

/// [upperCaseIn] for the app's current language.
String upperCaseFor(BuildContext context, String text) => upperCaseIn(
    Localizations.maybeLocaleOf(context)?.languageCode ?? 'en', text);
