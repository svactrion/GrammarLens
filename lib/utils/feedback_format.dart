/// Client-side formatting of the AI feedback string for reading (1.4.0 B9,
/// owner 2026-10-31): paragraphs at sentence boundaries, a closing
/// paragraph set apart, and quoted examples emphasised. A pure function
/// over the string the proxy returns, applied by `FeedbackText`; stored
/// plain-text feedback renders through the same path. A stopgap until the
/// scorer returns structured per-blank feedback: delete this file and the
/// widget then.
library;

/// A run of text in a paragraph, [emphasized] when it is a quoted example
/// (quotes included).
class FeedbackSpan {
  final String text;
  final bool emphasized;

  const FeedbackSpan(this.text, {this.emphasized = false});

  @override
  bool operator ==(Object other) =>
      other is FeedbackSpan &&
      other.text == text &&
      other.emphasized == emphasized;

  @override
  int get hashCode => Object.hash(text, emphasized);

  @override
  String toString() => emphasized ? '*$text*' : text;
}

class FeedbackParagraph {
  final List<FeedbackSpan> spans;

  const FeedbackParagraph(this.spans);

  /// The paragraph's plain text.
  String get text => spans.map((s) => s.text).join();

  /// The emphasised runs, quotes included, in order.
  List<String> get emphasized => [
        for (final s in spans)
          if (s.emphasized) s.text
      ];
}

class FormattedFeedback {
  final List<FeedbackParagraph> paragraphs;

  /// How many sentences [splitSentences] found.
  final int sentenceCount;

  /// Whether the last paragraph is the closing one, drawn apart (a thin
  /// rule above it): only with [closingMinimumSentences] sentences or more.
  /// A three-sentence feedback about three blanks has no closing sentence,
  /// so three paragraphs stand plain.
  final bool hasClosing;

  const FormattedFeedback({
    required this.paragraphs,
    required this.sentenceCount,
    required this.hasClosing,
  });
}

/// Three or more sentences: one paragraph per sentence.
const int paragraphMinimumSentences = 3;

/// Four or more sentences: the last one is the closing paragraph.
const int closingMinimumSentences = 4;

/// A quoted span longer than this (quotes included) is left plain: the
/// quote is more likely unbalanced than a long example.
const int maxEmphasizedLength = 80;

/// Formats [text]: see the library comment and the rules on
/// [splitSentences] and [emphasizeQuotes].
FormattedFeedback formatFeedback(String text) {
  final sentences = splitSentences(text);
  if (sentences.length < paragraphMinimumSentences) {
    return FormattedFeedback(
      paragraphs: [
        if (sentences.isNotEmpty) FeedbackParagraph(_joined(sentences)),
      ],
      sentenceCount: sentences.length,
      hasClosing: false,
    );
  }
  return FormattedFeedback(
    paragraphs: [
      for (final sentence in sentences)
        FeedbackParagraph(emphasizeQuotes(sentence)),
    ],
    sentenceCount: sentences.length,
    hasClosing: sentences.length >= closingMinimumSentences,
  );
}

/// The sentences' spans in one paragraph, a space between sentences.
List<FeedbackSpan> _joined(List<String> sentences) {
  final spans = <FeedbackSpan>[];
  for (var i = 0; i < sentences.length; i++) {
    if (i > 0) spans.add(const FeedbackSpan(' '));
    spans.addAll(emphasizeQuotes(sentences[i]));
  }
  return _merged(spans);
}

/// Adjacent plain spans merged, empty spans dropped.
List<FeedbackSpan> _merged(List<FeedbackSpan> spans) {
  final out = <FeedbackSpan>[];
  for (final span in spans) {
    if (span.text.isEmpty) continue;
    if (out.isNotEmpty && !out.last.emphasized && !span.emphasized) {
      out[out.length - 1] = FeedbackSpan(out.last.text + span.text);
    } else {
      out.add(span);
    }
  }
  return out;
}

/// Not a sentence end: the terminator belongs to the abbreviation.
const Set<String> _abbreviations = {'e.g.', 'i.e.', 'etc.', 'vs.'};

const String _terminators = '.!?';
const String _closersAfterTerminator = '\'’"”)]';
const String _openingQuotes = '\'‘"“';

/// Splits [text] into sentences. A sentence ends at `.`, `!` or `?` outside
/// parentheses, optionally followed by closing quotes or brackets, then
/// whitespace, then a capital letter or an opening quote; not when the word
/// before the mark is e.g., i.e., etc. or vs. Each sentence is trimmed; an
/// empty or blank [text] gives no sentences.
List<String> splitSentences(String text) {
  final sentences = <String>[];
  var start = 0;
  var depth = 0;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '(') {
      depth++;
    } else if (char == ')') {
      if (depth > 0) depth--;
    } else if (_terminators.contains(char) && depth == 0) {
      var end = i + 1;
      while (end < text.length && _closersAfterTerminator.contains(text[end])) {
        end++;
      }
      var next = end;
      while (next < text.length && _isWhitespace(text[next])) {
        next++;
      }
      final hasGap = next > end;
      if (hasGap &&
          next < text.length &&
          (_isUpper(text[next]) || _openingQuotes.contains(text[next])) &&
          !_abbreviations.contains(_wordEndingAt(text, i).toLowerCase())) {
        final sentence = text.substring(start, end).trim();
        if (sentence.isNotEmpty) sentences.add(sentence);
        start = next;
        i = next - 1;
      }
    }
  }
  final last = text.substring(start).trim();
  if (last.isNotEmpty) sentences.add(last);
  return sentences;
}

/// The word that ends at index [end] (inclusive): back to the previous
/// whitespace.
String _wordEndingAt(String text, int end) {
  var begin = end;
  while (begin > 0 && !_isWhitespace(text[begin - 1])) {
    begin--;
  }
  return text.substring(begin, end + 1);
}

bool _isWhitespace(String char) => char.trim().isEmpty;

bool _isUpper(String char) =>
    char.toUpperCase() == char && char.toLowerCase() != char;

/// What may stand right before an opening quote: the start of the text,
/// whitespace, a bracket, a double quote or a dash. An apostrophe after a
/// letter (don't, it's, learners') never opens.
const String _beforeOpening = '([{"“—–-';

/// What may stand right after a closing quote: the end of the text,
/// whitespace or punctuation.
const String _afterClosing = ',.;:!?)]}"”—–-';

/// The closer each opening quote takes.
const Map<String, String> _closers = {
  '\'': '\'’',
  '‘': '\'’',
  '"': '"”',
  '“': '"”',
};

/// The quoted examples in [sentence] marked for emphasis, quotes included.
/// A quote opens after the start, whitespace, a bracket, a double quote or
/// a dash; it closes at the first matching quote followed by the end,
/// whitespace or punctuation (no nesting); it must close within the
/// sentence and within [maxEmphasizedLength] characters, else the text
/// stays plain. A closing-shaped quote with nothing open is plain.
List<FeedbackSpan> emphasizeQuotes(String sentence) {
  final spans = <FeedbackSpan>[];
  final plain = StringBuffer();
  var i = 0;
  while (i < sentence.length) {
    final char = sentence[i];
    final closers = _closers[char];
    final opens = closers != null &&
        (i == 0 ||
            _isWhitespace(sentence[i - 1]) ||
            _beforeOpening.contains(sentence[i - 1]));
    if (opens) {
      final close = _closingIndex(sentence, i + 1, closers);
      if (close != null && close - i + 1 <= maxEmphasizedLength) {
        if (plain.isNotEmpty) {
          spans.add(FeedbackSpan(plain.toString()));
          plain.clear();
        }
        spans.add(
            FeedbackSpan(sentence.substring(i, close + 1), emphasized: true));
        i = close + 1;
        continue;
      }
    }
    plain.write(char);
    i++;
  }
  if (plain.isNotEmpty) spans.add(FeedbackSpan(plain.toString()));
  return spans;
}

/// The first index at or after [from] holding one of [closers] that the end,
/// whitespace or punctuation follows; null when there is none.
int? _closingIndex(String sentence, int from, String closers) {
  for (var j = from; j < sentence.length; j++) {
    if (!closers.contains(sentence[j])) continue;
    final atEnd = j + 1 == sentence.length;
    if (atEnd ||
        _isWhitespace(sentence[j + 1]) ||
        _afterClosing.contains(sentence[j + 1])) {
      return j;
    }
  }
  return null;
}
