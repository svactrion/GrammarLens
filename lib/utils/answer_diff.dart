/// Word-level difference between "You wrote" and "Corrected" (1.4.0 B10,
/// owner 2026-10-31): which words of each text to paint on the card. Pure
/// over the stored strings, no schema. The rendered text keeps the
/// original spelling and punctuation; only a token's [DiffToken.core] is
/// painted.
library;

import 'blanks.dart';

/// One whitespace-separated token: leading quotes and brackets, the word
/// itself, trailing quotes, brackets and sentence punctuation.
class DiffToken {
  final String lead;
  final String core;
  final String trail;

  /// Whether [core] is a difference to paint.
  final bool painted;

  const DiffToken(this.lead, this.core, this.trail, {this.painted = false});

  String get text => '$lead$core$trail';

  DiffToken copyWith({bool? painted}) =>
      DiffToken(lead, core, trail, painted: painted ?? this.painted);

  @override
  String toString() => painted ? '[$text]' : text;
}

class AnswerDiff {
  final List<DiffToken> user;
  final List<DiffToken> corrected;

  /// False when the noise guard struck: nothing is painted and the card
  /// renders as before.
  final bool highlighted;

  /// Painted words over compared words, the larger of the two sides.
  final double changedShare;

  /// Whether the answer was recognised as the prompt with its blanks filled.
  final bool assembled;

  const AnswerDiff({
    required this.user,
    required this.corrected,
    required this.highlighted,
    required this.changedShare,
    required this.assembled,
  });

  List<String> get paintedUser => [
        for (final t in user)
          if (t.painted) t.core
      ];
  List<String> get paintedCorrected => [
        for (final t in corrected)
          if (t.painted) t.core
      ];
}

/// No highlighting when the changed share exceeds this on either side…
const double noiseThreshold = 0.4;

/// …and the longer side has at least this many words. Shorter answers (the
/// Daily Test's one word) always show their difference.
const int noiseMinimumWords = 6;

/// Without a prompt, an answer at least this many times longer than its
/// correction is not the same sentence (an assembled answer without its
/// prompt, extra sentences): nothing is painted. Case 1 without its prompt
/// sits exactly at 1.5 (54 words to 36), hence "at least".
const double lengthRatioLimit = 1.5;

/// The prompt alignment must match this share of the prompt's non-blank
/// tokens for the answer to count as assembled.
const double assembledMinimumMatch = 0.8;

const String _leadChars = '\'"‘“([';
const String _trailChars = '\'"’”)].,;:!?…';

String _straight(String s) => s
    .replaceAll('’', "'")
    .replaceAll('‘', "'")
    .replaceAll('“', '"')
    .replaceAll('”', '"');

/// Splits [token] into leading marks, the core and trailing marks.
DiffToken splitToken(String token) {
  var start = 0;
  var end = token.length;
  while (start < end && _leadChars.contains(token[start])) {
    start++;
  }
  while (end > start && _trailChars.contains(token[end - 1])) {
    end--;
  }
  return DiffToken(token.substring(0, start), token.substring(start, end),
      token.substring(end));
}

final RegExp _wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// The compare key of a token: its core, quotes straightened, lowercased.
/// Empty for a token without a letter or digit (a lone dash), which is
/// neutral.
String compareKey(String token) {
  final core = _straight(splitToken(token).core).toLowerCase();
  return _wordChar.hasMatch(core) ? core : '';
}

/// The key for the alignment against the prompt: parentheses kept, so a
/// hint such as `(change)` can only match itself, never the word `change`.
String _promptKey(String token) {
  var t = _straight(token).toLowerCase();
  var start = 0;
  var end = t.length;
  const lead = '\'"[';
  const trail = '\'"].,;:!?…';
  while (start < end && lead.contains(t[start])) {
    start++;
  }
  while (end > start && trail.contains(t[end - 1])) {
    end--;
  }
  return t.substring(start, end);
}

bool _isBlank(String key) =>
    blankPattern.hasMatch(key) && key.replaceAll('_', '').isEmpty;

/// The index pairs of a longest common subsequence of [a] and [b]; an empty
/// key never matches. Dynamic programming, O(n·m) time and memory: two
/// 60-word sentences are 3,721 cells.
List<(int, int)> longestCommonSubsequence(List<String> a, List<String> b) {
  final n = a.length;
  final m = b.length;
  final table = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      table[i][j] = a[i].isNotEmpty && a[i] == b[j]
          ? table[i + 1][j + 1] + 1
          : (table[i + 1][j] >= table[i][j + 1]
              ? table[i + 1][j]
              : table[i][j + 1]);
    }
  }
  final pairs = <(int, int)>[];
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (a[i].isNotEmpty && a[i] == b[j]) {
      pairs.add((i, j));
      i++;
      j++;
    } else if (table[i + 1][j] >= table[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }
  return pairs;
}

/// Compares [userAnswer] with [correctedAnswer] word by word and marks the
/// words to paint on each side.
///
/// Assembled mode (the answer is [prompt] with its blanks filled): prompt
/// text is never painted in the answer, and parenthesised prompt hints are
/// left out of the comparison. Simple mode otherwise: every answer token is
/// the learner's. Then the noise guard ([noiseThreshold],
/// [noiseMinimumWords]) and, without a prompt, the length guard
/// ([lengthRatioLimit]) decide whether anything is painted at all.
AnswerDiff diffAnswer({
  required String userAnswer,
  required String correctedAnswer,
  String? prompt,
}) {
  final userTokens = _tokens(userAnswer);
  final correctedTokens = _tokens(correctedAnswer);
  final user = userTokens.map(splitToken).toList();
  final corrected = correctedTokens.map(splitToken).toList();
  final userKeys = userTokens.map(compareKey).toList();
  final correctedKeys = correctedTokens.map(compareKey).toList();

  // Which answer tokens the learner wrote, and which are left out of the
  // comparison altogether.
  final learner = List<bool>.filled(user.length, true);
  final neutral = [for (final key in userKeys) key.isEmpty];
  var assembled = false;
  if (prompt != null && blankPattern.hasMatch(prompt)) {
    final promptTokens = _tokens(prompt);
    final promptKeys = promptTokens.map(_promptKey).toList();
    final pairs = longestCommonSubsequence(
        userTokens.map(_promptKey).toList(), promptKeys);
    final nonBlank = promptKeys.where((k) => !_isBlank(k)).length;
    final matchedNonBlank =
        pairs.where((p) => !_isBlank(promptKeys[p.$2])).length;
    if (nonBlank > 0 && matchedNonBlank / nonBlank >= assembledMinimumMatch) {
      assembled = true;
      for (final (i, _) in pairs) {
        learner[i] = false;
      }
      final inParentheses = _parenthesised(userTokens);
      for (var i = 0; i < user.length; i++) {
        if (!learner[i] && inParentheses[i]) neutral[i] = true;
      }
    }
  }

  final pairs = longestCommonSubsequence(
    [for (var i = 0; i < user.length; i++) neutral[i] ? '' : userKeys[i]],
    correctedKeys,
  );
  final matchedUser = {for (final p in pairs) p.$1};
  final matchedCorrected = {for (final p in pairs) p.$2};
  final paintUser = <int>{
    for (var i = 0; i < user.length; i++)
      if (learner[i] && !neutral[i] && !matchedUser.contains(i)) i,
  };
  final paintCorrected = <int>{
    for (var j = 0; j < corrected.length; j++)
      if (correctedKeys[j].isNotEmpty && !matchedCorrected.contains(j)) j,
  };

  // The compared words: in assembled mode the sentence region (from the
  // first to the last match, plus the learner's own words), else every
  // word of the answer.
  var comparedUser = 0;
  if (assembled && matchedUser.isNotEmpty) {
    final lo = matchedUser.reduce((a, b) => a < b ? a : b);
    final hi = matchedUser.reduce((a, b) => a > b ? a : b);
    for (var i = 0; i < user.length; i++) {
      if (neutral[i]) continue;
      if (learner[i] || (i >= lo && i <= hi && matchedUser.contains(i))) {
        comparedUser++;
      }
    }
  } else {
    comparedUser = neutral.where((n) => !n).length;
  }
  final comparedCorrected = correctedKeys.where((k) => k.isNotEmpty).length;
  final share = _max(
    comparedUser == 0 ? 0 : paintUser.length / comparedUser,
    comparedCorrected == 0 ? 0 : paintCorrected.length / comparedCorrected,
  );
  final longer =
      comparedUser > comparedCorrected ? comparedUser : comparedCorrected;
  var highlighted = !(share > noiseThreshold && longer >= noiseMinimumWords);
  if (!assembled &&
      comparedUser >= noiseMinimumWords &&
      comparedUser >= comparedCorrected * lengthRatioLimit) {
    highlighted = false;
  }
  // Nothing to show, or one side empty: a missing answer is a skipped
  // question, not a difference.
  if (paintUser.isEmpty && paintCorrected.isEmpty) highlighted = false;
  if (comparedUser == 0 || comparedCorrected == 0) highlighted = false;

  return AnswerDiff(
    user: [
      for (var i = 0; i < user.length; i++)
        user[i].copyWith(painted: highlighted && paintUser.contains(i)),
    ],
    corrected: [
      for (var j = 0; j < corrected.length; j++)
        corrected[j]
            .copyWith(painted: highlighted && paintCorrected.contains(j)),
    ],
    highlighted: highlighted,
    changedShare: share,
    assembled: assembled,
  );
}

List<String> _tokens(String text) =>
    text.trim().isEmpty ? const [] : text.trim().split(RegExp(r'\s+'));

double _max(num a, num b) => (a > b ? a : b).toDouble();

/// Whether each token lies inside parentheses (its own or an earlier
/// token's still open).
List<bool> _parenthesised(List<String> tokens) {
  final flags = <bool>[];
  var depth = 0;
  for (final token in tokens) {
    final opens = '('.allMatches(token).length;
    final closes = ')'.allMatches(token).length;
    final startsOne =
        splitToken(token).lead.contains('(') || token.startsWith('(');
    flags.add(depth > 0 || startsOne);
    depth += opens - closes;
    if (depth < 0) depth = 0;
  }
  return flags;
}
