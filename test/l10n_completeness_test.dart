import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/l10n/l10n.dart';

/// 1.4.0 B5 (docs/1.4.0-b5-batch0-report.md §5): every translation has
/// every English key, the same placeholders, the plural forms its language
/// needs, the names that are never translated, and no value left in
/// English by mistake. Replaces gen-l10n's untranslated-messages file
/// (dropped in B3).
void main() {
  final english = _readArb('lib/l10n/app_en.arb');
  final keys = english.keys.where((k) => !k.startsWith('@')).toList();
  final targets = {
    for (final file in Directory('lib/l10n')
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'app_[a-z]{2}\.arb$').hasMatch(f.path))
        .where((f) => !f.path.endsWith('app_en.arb')))
      RegExp(r'app_([a-z]{2})\.arb$').firstMatch(file.path)!.group(1)!:
          _readArb(file.path),
  };

  test('at least one translation exists', () {
    expect(targets, isNotEmpty);
  });

  for (final MapEntry(key: lang, value: arb) in targets.entries) {
    group('app_$lang.arb', () {
      test('declares its locale and carries values only', () {
        expect(arb['@@locale'], lang);
        expect(arb.keys.where((k) => k.startsWith('@') && k != '@@locale'),
            isEmpty,
            reason: 'descriptions stay in app_en.arb (B5 §8 Q7)');
      });

      test('has exactly the English keys', () {
        final own = arb.keys.where((k) => !k.startsWith('@')).toSet();
        expect(own.difference(keys.toSet()), isEmpty, reason: 'extra keys');
        expect(keys.toSet().difference(own), isEmpty, reason: 'missing keys');
      });

      test('keeps every placeholder, and every plural stays a plural', () {
        final problems = <String>[];
        for (final key in keys) {
          final en = english[key] as String;
          final value = arb[key] as String? ?? '';
          if (!_sameSet(_placeholders(en), _placeholders(value))) {
            problems
                .add('$key: ${_placeholders(en)} → ${_placeholders(value)}');
          }
          if (_isPlural(en) != _isPlural(value)) {
            problems.add('$key: plural in one and not the other');
          }
        }
        expect(problems, isEmpty, reason: problems.join('\n'));
      });

      test('defines the plural forms the language needs', () {
        final needed = _pluralForms[lang] ?? const ['other'];
        final problems = <String>[
          for (final key in keys)
            if (_isPlural(arb[key] as String? ?? ''))
              for (final form in needed)
                if (!RegExp('(^|[\\s,])$form\\{').hasMatch(arb[key] as String))
                  '$key: no "$form" form',
        ];
        expect(problems, isEmpty, reason: problems.join('\n'));
      });

      test('keeps the feature names, the brand and the fixed names verbatim',
          () {
        final problems = <String>[
          for (final key in keys)
            for (final name in _verbatim)
              if (_namesIt(english, key, name) &&
                  !(arb[key] as String).contains(name))
                '$key: "$name" missing',
        ];
        expect(problems, isEmpty, reason: problems.join('\n'));
      });

      test('leaves nothing in English by mistake', () {
        final allowed = {..._sameEverywhere, ...?_sameIn[lang]};
        final problems = <String>[
          for (final key in keys)
            if (!allowed.contains(key) &&
                _hasWords(english[key] as String) &&
                arb[key] == english[key])
              '$key: "${arb[key]}"',
        ];
        expect(problems, isEmpty,
            reason: 'Translate these, or add the key to the allowlist with a '
                'reason:\n${problems.join('\n')}');
      });

      final script = _scripts[lang];
      if (script != null) {
        test('every value with letters is in the language\'s script', () {
          final problems = <String>[
            for (final key in keys)
              if (!_sameEverywhere.contains(key) &&
                  _hasWords(arb[key] as String) &&
                  !script.hasMatch(arb[key] as String))
                '$key: "${arb[key]}"',
          ];
          expect(problems, isEmpty, reason: problems.join('\n'));
        });
      }
    });
  }

  test('the picker offers every translated language (B3 rule)', () {
    final offered = {
      for (final l in AppLanguage.available())
        if (l.locale != null) l.locale!.languageCode,
    };
    expect(offered, {'en', ...targets.keys});
    expect(AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet(),
        {'en', ...targets.keys});
  });

  test('every translation loads through the delegate', () async {
    for (final lang in targets.keys) {
      final l10n = await AppLocalizations.delegate.load(Locale(lang));
      expect(l10n.localeName, lang);
    }
  });
}

/// Whether the English value of [key] uses [name] as a name. "Review" is
/// also an English verb ("Review answer", "Reviewing"), so it counts only
/// where the key's description calls it the feature.
bool _namesIt(Map<String, dynamic> english, String key, String name) {
  final value = english[key] as String;
  if (!value.contains(name)) return false;
  if (name != 'Review') return true;
  final description =
      (english['@$key'] as Map<String, dynamic>?)?['description'] as String? ??
          '';
  return description.contains('Feature names') ||
      description.contains("'Review'");
}

Map<String, dynamic> _readArb(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// The CLDR plural categories a language's plural messages must define
/// (report §3.1); the rest need `other` only.
const _pluralForms = {
  'ar': ['zero', 'one', 'two', 'few', 'many', 'other'],
};

/// Never translated (report §1): the feature names, the brand and the
/// names of companies, products, works and exams.
const _verbatim = [
  'Daily Test',
  'Topic Practice',
  'Review',
  'Monthly Climb',
  'Premium',
  'PREMIUM',
  'DAILY TEST',
  'GrammarLens',
  'GRAMMARLENS',
  'Anthropic',
  'Claude',
  'Figma Community',
  'IELTS',
  'TOEFL',
];

/// Keys whose value is the English one in every language, with the reason.
const _sameEverywhere = {
  'featureReview', // a feature name (D6)
  'featureDailyTest', // a feature name (D6)
  'featureTopicPractice', // a feature name (D6)
  'featurePremium', // a feature name (D6)
  'homeTopicPractice', // a feature name (D6)
  'offerTopicPracticeTitle', // a feature name (D6)
  'homeDailyEyebrow', // a feature name, uppercase (D6)
  'paywallHeaderPremium', // a feature name, uppercase (D6)
  'offerChip', // a feature name, uppercase (D6)
  'paywallBadge', // the brand and a feature name, uppercase
};

/// Per language: values that are the same word by nature.
const _sameIn = {
  'tr': {
    'avatarKoala', // the same word in Turkish
    'avatarPanda', // the same word in Turkish
    'paywallPlanSemantics', // "plan" is the Turkish word too
  },
};

/// The script each non-Latin language's values must contain.
final _scripts = {
  'ja': RegExp(r'[぀-ヿ一-鿿]'),
  'ko': RegExp(r'[가-힯]'),
  'ar': RegExp(r'[؀-ۿ]'),
};

/// ICU argument names: `{name}` and the variable of `{count, plural, …}`,
/// not the bodies of plural cases (`=1{question}`).
Set<String> _placeholders(String message) {
  final withoutCases =
      message.replaceAll(RegExp(r'(zero|one|two|few|many|other|=\d+)\{'), '');
  return {
    for (final m in RegExp(r'\{(\w+)(?=[,}])').allMatches(withoutCases))
      m.group(1)!,
  };
}

bool _isPlural(String message) => message.contains(', plural,');

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);

/// Whether [message] has a word outside its placeholders and ICU syntax
/// (a value of placeholders and punctuation only is the same everywhere).
bool _hasWords(String message) {
  final text = message
      .replaceAll(RegExp(r'\{\w+, plural,'), '')
      .replaceAll(RegExp(r'\b(zero|one|two|few|many|other)\{'), '')
      .replaceAll(RegExp(r'=\d+\{'), '')
      .replaceAll(RegExp(r'\{\w+\}'), '');
  return RegExp(r'\p{L}{2,}', unicode: true).hasMatch(text);
}
