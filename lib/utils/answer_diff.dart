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

  /// The share of the prompt's blank-bearing lines' non-blank tokens that
  /// the answer matched in order; 0 without a prompt or a blank. At least
  /// [assembledMinimumMatch] makes [assembled] true.
  final double promptMatchRatio;

  const AnswerDiff({
    required this.user,
    required this.corrected,
    required this.highlighted,
    required this.changedShare,
    required this.assembled,
    this.promptMatchRatio = 0,
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

/// The prompt alignment must match this share of the non-blank tokens of
/// the prompt's blank-bearing lines for the answer to count as assembled.
/// Only those lines: the answer was assembled from the text that holds the
/// blanks (`blankSourceText`), so a context line without a blank is never
/// in it (B10.1; the two-line prompt of the owner's case 2 record matched
/// 69 % of the whole prompt and fell to simple mode).
const double assembledMinimumMatch = 0.8;

/// B10.3 (owner, 2026-11-02): short function words the LCS can match
/// across a displaced phrase. On the device an error correction had
/// "finally to decide applying" against "finally decided to apply": the
/// learner's displaced "to" matched the correction's "to", so both stayed
/// plain although the infinitive marker was the point of the item. After
/// the LCS, a matched pair is painted on both sides when, on either side,
/// its token is one of these words (or any compared word of at most
/// [bridgeMaxLength] letters) and lies between two painted words; painted
/// runs then render as one strip. The list is a constant so it can be
/// tuned without touching the rule.
const Set<String> bridgeWords = {
  'to',
  'a',
  'an',
  'the',
  'of',
  'in',
  'on',
  'at',
  'for',
};

/// The fallback of [bridgeWords]: a compared word this short is a function
/// word for the bridge rule.
const int bridgeMaxLength = 3;

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
  var promptMatchRatio = 0.0;
  if (prompt != null && blankPattern.hasMatch(prompt)) {
    // Every prompt token, flagged when its line holds a blank. The
    // alignment runs over all of them (a context the answer does include
    // is prompt text too); the ratio counts the blank-bearing lines only.
    final promptTokens = <String>[];
    final inBlankLine = <bool>[];
    for (final line in prompt.split('\n')) {
      final hasBlank = blankPattern.hasMatch(line);
      for (final token in _tokens(line)) {
        promptTokens.add(token);
        inBlankLine.add(hasBlank);
      }
    }
    final promptKeys = promptTokens.map(_promptKey).toList();
    final pairs = longestCommonSubsequence(
        userTokens.map(_promptKey).toList(), promptKeys);
    var counted = 0;
    for (var j = 0; j < promptKeys.length; j++) {
      if (inBlankLine[j] && !_isBlank(promptKeys[j])) counted++;
    }
    final matchedCounted = pairs
        .where((p) => inBlankLine[p.$2] && !_isBlank(promptKeys[p.$2]))
        .length;
    promptMatchRatio = counted == 0 ? 0 : matchedCounted / counted;
    if (promptMatchRatio >= assembledMinimumMatch) {
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

  // The bridge rule runs after the guards: a bridged word is the same word
  // on both sides, not a difference, so it does not count towards the
  // changed share. Prompt text in an assembled answer is never painted
  // (D10), so a pair whose answer token is prompt text is left alone.
  if (highlighted) {
    _bridgeFunctionWords(
      pairs: pairs,
      userKeys: userKeys,
      correctedLength: corrected.length,
      learner: learner,
      skipUser: (i) => neutral[i],
      skipCorrected: (j) => correctedKeys[j].isEmpty,
      paintUser: paintUser,
      paintCorrected: paintCorrected,
    );
  }

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
    promptMatchRatio: promptMatchRatio,
  );
}

bool _isBridgeWord(String key) =>
    key.isNotEmpty &&
    (bridgeWords.contains(key) || key.length <= bridgeMaxLength);

/// Paints every matched pair that the bridge rule covers ([bridgeWords]).
/// A run of consecutive bridgeable words ("to the") is looked at as one:
/// the nearest compared words before and after the run must both be
/// painted. Repeated until nothing changes, since painting a pair on one
/// side can complete the condition on the other.
void _bridgeFunctionWords({
  required List<(int, int)> pairs,
  required List<String> userKeys,
  required int correctedLength,
  required List<bool> learner,
  required bool Function(int) skipUser,
  required bool Function(int) skipCorrected,
  required Set<int> paintUser,
  required Set<int> paintCorrected,
}) {
  final bridgeable = [
    for (final p in pairs)
      if (learner[p.$1] && _isBridgeWord(userKeys[p.$1])) p,
  ];
  final runUser = {for (final p in bridgeable) p.$1};
  final runCorrected = {for (final p in bridgeable) p.$2};
  var changed = true;
  while (changed) {
    changed = false;
    for (final (i, j) in bridgeable) {
      if (paintUser.contains(i)) continue;
      final onUser =
          _runBetweenPainted(i, userKeys.length, skipUser, runUser, paintUser);
      final onCorrected = _runBetweenPainted(
          j, correctedLength, skipCorrected, runCorrected, paintCorrected);
      if (onUser || onCorrected) {
        paintUser.add(i);
        paintCorrected.add(j);
        changed = true;
      }
    }
  }
}

/// Whether the nearest compared tokens before and after the run of
/// bridgeable words that holds [index] (skipping neutral tokens and the
/// run's own members) both exist and are painted.
bool _runBetweenPainted(
  int index,
  int length,
  bool Function(int) skip,
  Set<int> run,
  Set<int> painted,
) {
  var before = index - 1;
  while (before >= 0 && (skip(before) || run.contains(before))) {
    before--;
  }
  var after = index + 1;
  while (after < length && (skip(after) || run.contains(after))) {
    after++;
  }
  return before >= 0 &&
      after < length &&
      painted.contains(before) &&
      painted.contains(after);
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
