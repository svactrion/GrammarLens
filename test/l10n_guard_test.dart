import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 1.4.0 B3 (docs/1.4.0-b3-batch0-report.md §4.1): no hard-coded
/// user-visible string in `lib/` outside the files still waiting for B4.
///
/// A lexical tripwire, not a proof. A string literal offends when it reads
/// as interface text: prose (a letter, whitespace, a letter; or a trailing
/// "…"), or any text passed straight to `Text(`, `TextSpan(text:` or a
/// `label:` / `title:` / `hintText:` / `semanticsLabel:`-style argument.
/// Not counted: comments, SQL, URLs and asset paths, `debugPrint`,
/// `assert`, `RegExp`, keys, analytics calls and programmer errors
/// (`StateError` and the like), and a line marked `// l10n-guard: <reason>`
/// (or the line above it).
///
/// [_pending] lists every file with a hit when B3 landed. A hit in any
/// other file fails, so no new hard-coded string can be added; each B4
/// batch removes its files from the list once they are clean, and a listed
/// file that is already clean fails too, so the list only ever shrinks.
/// B4's last batch deletes the list.
void main() {
  final offences = <String, List<String>>{};
  for (final file in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    final path = file.path.replaceAll(r'\', '/');
    if (_excluded.any(path.startsWith)) continue;
    final hits = scanForInterfaceText(file.readAsStringSync());
    if (hits.isNotEmpty) offences[path] = hits;
  }

  test('no hard-coded interface text outside the B4 pending list', () {
    final unexpected = {
      for (final MapEntry(:key, :value) in offences.entries)
        if (!_pending.contains(key)) key: value,
    };
    expect(
      unexpected,
      isEmpty,
      reason: 'Move these strings to lib/l10n/app_en.arb and read them '
          'through context.l10n (or mark a line `// l10n-guard: <reason>` '
          'when it is not interface text):\n'
          '${unexpected.entries.map((e) => '${e.key}\n  ${e.value.join('\n  ')}').join('\n')}',
    );
  });

  test('every file on the pending list still has a hit (the list shrinks)', () {
    final clean = _pending.where((p) => !offences.containsKey(p)).toList();
    expect(clean, isEmpty,
        reason: 'These files are clean now: remove them from _pending.');
  });

  group('the scanner', () {
    test('finds prose, interpolated text and UI arguments', () {
      expect(scanForInterfaceText("Text('Hello there')"), ['Hello there']);
      expect(scanForInterfaceText(r"x = '$n days ago';"), [r'$n days ago']);
      expect(scanForInterfaceText("Text('Retry')"), ['Retry']);
      expect(scanForInterfaceText("label: 'Home',"), ['Home']);
      expect(scanForInterfaceText("const m = 'Loading…';"), ['Loading…']);
    });

    test('a key earlier in the same widget tree does not hide later text', () {
      expect(
          scanForInterfaceText(
              "Column(children: [Text(key: ValueKey('a'), 'Hello there')])"),
          ['Hello there']);
      expect(scanForInterfaceText("assert(ok,\n  'never shown to anyone');"),
          isEmpty);
      expect(
          scanForInterfaceText(
              "const k = ValueKey('k');\nWidget b() => Row(children: [\n"
              "  IconButton(tooltip: 'Previous question')]);"),
          ['Previous question']);
    });

    test('nested quotes inside an interpolation do not derail it', () {
      expect(
          scanForInterfaceText(
              r"x = '$n practice${n == 1 ? '' : 's'} left'; y = 'snake_id';"),
          [r'$n practice${…} left']);
    });

    test('skips comments, identifiers, SQL, paths, debug and marked lines', () {
      expect(scanForInterfaceText('// Text(\'Hello there\')'), isEmpty);
      expect(scanForInterfaceText("/* 'Hello there' */"), isEmpty);
      expect(scanForInterfaceText("x = 'daily_test_completed';"), isEmpty);
      expect(
          scanForInterfaceText(
              "db.execute('''\n  CREATE TABLE IF NOT EXISTS t (id INTEGER)\n''');"),
          isEmpty);
      expect(scanForInterfaceText("Image.asset('assets/a b.png')"), isEmpty);
      expect(scanForInterfaceText("debugPrint('took too long');"), isEmpty);
      expect(
          scanForInterfaceText("throw StateError('not ready yet');"), isEmpty);
      expect(
          scanForInterfaceText(
              "title: 'GrammarLens', // l10n-guard: the brand"),
          isEmpty);
      expect(
          scanForInterfaceText(
              "// l10n-guard: debug only\nText('Preview pricing')"),
          isEmpty);
    });
  });
}

/// Never scanned: the generated and hand-written l10n code; debug-only
/// screens, previews and fixtures; bundled question content (English by
/// 1.4.0 D2); the hint cards (English in 1.4.0, report §8 Q2); generated
/// data tables.
const _excluded = [
  'lib/l10n/',
  'lib/preview/',
  'lib/screens/debug_panel_screen.dart',
  'lib/screens/theme_preview_screen.dart',
  'lib/utils/debug_practice_sets.dart',
  'lib/utils/debug_sample_collection.dart',
  'lib/utils/debug_tools.dart',
  'lib/widgets/monthly_climb/climb_debug_',
  'lib/data/day_zero_daily_test.dart',
  'lib/data/fallback_pool.dart',
  'lib/data/topic_hints.dart',
  'lib/firebase_options.dart',
  'lib/widgets/monthly_climb/climb_trail_table.dart',
  'lib/widgets/monthly_climb/climb_save_point_table.dart',
];

/// Files with hard-coded interface text, waiting for B4. Only ever shrinks.
const _pending = <String>{
  // The 51 files with a hit when B3 landed (2026-11-02).
  'lib/app.dart',
  'lib/data/topics.dart',
  'lib/models/climb_theme.dart',
  'lib/models/learning_goal.dart',
  'lib/models/practice_length.dart',
  'lib/models/review_sort_order.dart',
  'lib/screens/ai_consent_screen.dart',
  'lib/screens/avatar_picker_screen.dart',
  'lib/screens/credits_screen.dart',
  'lib/screens/daily_test_result_screen.dart',
  'lib/screens/daily_test_screen.dart',
  'lib/screens/data_screen.dart',
  'lib/screens/first_launch_flow.dart',
  'lib/screens/home_screen.dart',
  'lib/screens/onboarding_screen.dart',
  'lib/screens/practice_launch.dart',
  'lib/screens/practice_length_picker.dart',
  'lib/screens/practice_screen.dart',
  'lib/screens/premium_screen.dart',
  'lib/screens/results_screen.dart',
  'lib/screens/review_screen.dart',
  'lib/screens/settings_screen.dart',
  'lib/screens/topic_practice_screen.dart',
  'lib/screens/weak_spot_detail_screen.dart',
  'lib/screens/welcome_screen.dart',
  'lib/services/claude_service.dart',
  'lib/services/subscription_service.dart',
  'lib/utils/answer_matching.dart',
  'lib/utils/app_messenger.dart',
  'lib/utils/greeting.dart',
  'lib/utils/premium_copy.dart',
  'lib/utils/text_format.dart',
  'lib/widgets/avatar_carousel.dart',
  'lib/widgets/blank_colors.dart',
  'lib/widgets/brand_wordmark.dart',
  'lib/widgets/legal_link.dart',
  'lib/widgets/locked_premium_pill.dart',
  'lib/widgets/medal_celebration.dart',
  'lib/widgets/mistake_breakdown.dart',
  'lib/widgets/month_card_sheet.dart',
  'lib/widgets/monthly_climb/climb_card.dart',
  'lib/widgets/monthly_climb/climb_save_points.dart',
  'lib/widgets/monthly_climb/climb_score_bar.dart',
  'lib/widgets/monthly_climb/monthly_mountain.dart',
  'lib/widgets/monthly_medal_collection.dart',
  'lib/widgets/practice_step_footer.dart',
  'lib/widgets/premium_offer_card.dart',
  'lib/widgets/question_app_bar.dart',
  'lib/widgets/question_view.dart',
  'lib/widgets/topic_hint_card.dart',
  'lib/widgets/weak_spot_card.dart',
};

final _prose = RegExp(r'\p{L}\s+\p{L}', unicode: true);
final _letter = RegExp(r'\p{L}', unicode: true);
final _uiArgument = RegExp(
    r'(\bText\(|\bTextSpan\(\s*text:|\b(label|title|subtitle|tooltip|hintText|'
    r'labelText|semanticsLabel|semanticLabel|hint|message|description|'
    r'tagline|name|text):)\s*(const\s+)?$');

/// SQL: a statement, or a fragment carrying an uppercase SQL keyword (a
/// `where:` or `orderBy:` argument, a column definition).
final _sql = RegExp(
    r'^\s*(CREATE|ALTER|SELECT|INSERT|UPDATE|DELETE|DROP|PRAGMA|WITH)\b|'
    r'\b(WHERE|FROM|IS|NOT|DESC|ASC|NULL|DEFAULT|INTEGER|PRIMARY KEY|AND|OR|'
    r'IN|LIKE)\b');

/// Calls whose string arguments are never interface text. A literal is
/// skipped only while it sits inside such a call's parentheses: widget
/// trees have no semicolons, so "anywhere after `ValueKey(`" would hide
/// every later string of the expression.
final _ignoredCall = RegExp(
    r'\b(debugPrint|assert|RegExp|Key|ValueKey|_?logEvent|_?setUserProperty|'
    r'StateError|ArgumentError|FormatException|UnsupportedError|'
    r'UnimplementedError|AssertionError)\(');
final _directive = RegExp(r'^\s*(import|export|part)\s', multiLine: true);

/// The interface-text literals of a Dart [source], as their text with
/// interpolations shown as written (`$n`) or as `${…}`.
List<String> scanForInterfaceText(String source) {
  final lines = source.split('\n');
  final lineStarts = <int>[0];
  for (var i = 0; i < source.length; i++) {
    if (source.codeUnitAt(i) == 0x0A) lineStarts.add(i + 1);
  }
  int lineOf(int offset) {
    var lo = 0;
    var hi = lineStarts.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) >> 1;
      if (lineStarts[mid] <= offset) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return lo;
  }

  final hits = <String>[];
  for (final literal in _literals(source)) {
    final text = literal.text;
    if (!_letter.hasMatch(text.replaceAll(RegExp(r'\$\{…\}|\$\w+'), ''))) {
      continue;
    }
    final line = lineOf(literal.start);
    final marked = lines[line].contains('l10n-guard:') ||
        (line > 0 && lines[line - 1].contains('l10n-guard:'));
    if (marked) continue;
    final before = source.substring(
        literal.start < 200 ? 0 : literal.start - 200, literal.start);
    if (_insideIgnoredCall(source, literal.start)) continue;
    if (_directive.hasMatch(lines[line])) continue;
    if (_sql.hasMatch(text)) continue;
    if (text.contains('://') || text.startsWith('assets/')) continue;
    final prose = _prose.hasMatch(text) || text.trimRight().endsWith('…');
    if (prose || _uiArgument.hasMatch(before)) hits.add(text);
  }
  return hits;
}

/// Whether the literal at [offset] is an argument of an [_ignoredCall]
/// still open at that point (its parentheses not yet balanced).
bool _insideIgnoredCall(String source, int offset) {
  final from = offset < 600 ? 0 : offset - 600;
  final window = source.substring(from, offset);
  for (final m in _ignoredCall.allMatches(window)) {
    // From the call's own "(": inside it while the count stays above zero;
    // once it falls back to zero the call has closed before [offset].
    var depth = 0;
    var closed = false;
    final between = _withoutStrings(window.substring(m.end - 1));
    for (final c in between.split('')) {
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0) {
        closed = true;
        break;
      }
    }
    if (!closed) return true;
  }
  return false;
}

/// [code] with the contents of its string literals blanked, so a bracket
/// inside a string does not count.
String _withoutStrings(String code) => code.replaceAllMapped(
    RegExp(r"'(?:[^'\\\n]|\\.)*'|" r'"(?:[^"\\\n]|\\.)*"'), (m) => '""');

class _Literal {
  final int start;
  final String text;
  const _Literal(this.start, this.text);
}

/// Every string literal of [s], comments skipped; adjacent literals are
/// kept apart (each is judged on its own).
List<_Literal> _literals(String s) {
  final out = <_Literal>[];
  var i = 0;
  while (i < s.length) {
    i = _skipCode(s, i, out, untilBrace: false);
  }
  return out;
}

/// Scans code from [i]; with [untilBrace], stops after the `}` that closes
/// an interpolation. Returns the index reached.
int _skipCode(String s, int i, List<_Literal> out, {required bool untilBrace}) {
  var depth = 0;
  while (i < s.length) {
    final c = s[i];
    if (c == '/' && i + 1 < s.length && s[i + 1] == '/') {
      final end = s.indexOf('\n', i);
      i = end < 0 ? s.length : end;
      continue;
    }
    if (c == '/' && i + 1 < s.length && s[i + 1] == '*') {
      final end = s.indexOf('*/', i + 2);
      i = end < 0 ? s.length : end + 2;
      continue;
    }
    if (c == "'" || c == '"') {
      final raw = i > 0 && s[i - 1] == 'r' && (i < 2 || !_isIdent(s[i - 2]));
      i = _readString(s, i, raw, out);
      continue;
    }
    if (untilBrace) {
      if (c == '{') depth++;
      if (c == '}') {
        if (depth == 0) return i + 1;
        depth--;
      }
    }
    i++;
  }
  return i;
}

bool _isIdent(String c) => RegExp(r'[A-Za-z0-9_$]').hasMatch(c);

/// Reads the string literal starting at [start] (its opening quote) and
/// records it; returns the index after its closing quote.
int _readString(String s, int start, bool raw, List<_Literal> out) {
  final q = s[start];
  final triple = s.startsWith(q * 3, start);
  final close = triple ? q * 3 : q;
  var i = start + close.length;
  final text = StringBuffer();
  while (i < s.length) {
    if (s.startsWith(close, i)) {
      out.add(_Literal(start, text.toString()));
      return i + close.length;
    }
    final c = s[i];
    if (!triple && c == '\n') break; // unterminated: give up on this line
    if (!raw && c == r'\' && i + 1 < s.length) {
      text.write(s.substring(i, i + 2));
      i += 2;
      continue;
    }
    if (!raw && c == r'$' && i + 1 < s.length) {
      if (s[i + 1] == '{') {
        text.write(r'${…}');
        i = _skipCode(s, i + 2, out, untilBrace: true);
        continue;
      }
      final m = RegExp(r'[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(s, i + 1);
      if (m != null) {
        text.write('\$${m.group(0)}');
        i = m.end;
        continue;
      }
    }
    text.write(c);
    i++;
  }
  out.add(_Literal(start, text.toString()));
  return i;
}
