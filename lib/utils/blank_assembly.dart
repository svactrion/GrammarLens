import '../models/practice_item.dart';
import 'blanks.dart';

/// What one answer box holds: the typed [text], or the no-article state
/// ("—", topic `articles` only). An empty box is never "no article".
class BlankAnswer {
  final String text;
  final bool noArticle;

  const BlankAnswer(this.text, {this.noArticle = false});

  const BlankAnswer.noArticle()
      : text = '',
        noArticle = true;

  bool get isFilled => noArticle || text.trim().isNotEmpty;
}

/// The text of [item] that holds its blanks, in reading order: the
/// context, the instruction, or both (as [PracticeItem.fullText] joins
/// them) when both have blanks.
String blankSourceText(PracticeItem item) {
  final context = item.context;
  final inContext = context != null && blankPattern.hasMatch(context);
  final inInstruction = blankPattern.hasMatch(item.instruction);
  if (inContext && inInstruction) return '$context\n${item.instruction}';
  if (inContext) return context;
  return item.instruction;
}

/// The completed sentence for a multi-blank answer (question screen plan,
/// §4): each box's answer put back into its blank, in order.
///
/// - Each box is trimmed.
/// - A no-article box removes its blank and the space after it (or the
///   space before it when there is none after), so no double space is
///   left. When that blank started a sentence, the next word's first
///   letter is capitalised (`____ water is essential.` → `Water is
///   essential.`). Otherwise case is left as typed.
/// - An empty box keeps its blank as it was.
/// - With every box empty the answer is `''`: a skipped item, as an empty
///   single box is.
///
/// [answers] has one entry per blank in [text]; a missing entry counts as
/// empty.
String assembleBlanks(String text, List<BlankAnswer> answers) {
  final blanks = blankPattern.allMatches(text).toList();
  if (!answers.any((a) => a.isFilled)) return '';
  var result = text;
  // Right to left, so earlier blanks keep their offsets.
  for (var i = blanks.length - 1; i >= 0; i--) {
    final blank = blanks[i];
    final answer = i < answers.length ? answers[i] : const BlankAnswer('');
    if (answer.noArticle) {
      result = _removeBlank(result, blank.start, blank.end);
    } else if (answer.text.trim().isNotEmpty) {
      result = result.replaceRange(blank.start, blank.end, answer.text.trim());
    }
  }
  return result;
}

String _removeBlank(String text, int start, int end) {
  final sentenceStart = _startsSentence(text, start);
  String result;
  int next;
  if (end < text.length && text[end] == ' ') {
    result = text.replaceRange(start, end + 1, '');
    next = start;
  } else if (start > 0 && text[start - 1] == ' ') {
    result = text.replaceRange(start - 1, end, '');
    next = start - 1;
  } else {
    result = text.replaceRange(start, end, '');
    next = start;
  }
  if (!sentenceStart) return result;
  // The next word's first letter, past spaces and opening quotes.
  while (next < result.length && _skippable.contains(result[next])) {
    next++;
  }
  if (next >= result.length) return result;
  return result.replaceRange(next, next + 1, result[next].toUpperCase());
}

// No straight single quote: it is also an apostrophe.
const _openingQuotes = {'"', '“', '‘', '('};
const _skippable = {' ', '"', '“', '‘', '('};

/// Whether the blank at [start] begins a sentence: nothing but spaces and
/// opening quotes before it back to the start of the text, a line break,
/// a full stop, question or exclamation mark, or an opening quote (quoted
/// speech begins a sentence).
bool _startsSentence(String text, int start) {
  var i = start - 1;
  while (i >= 0 && text[i] == ' ') {
    i--;
  }
  if (i < 0) return true;
  final char = text[i];
  return _openingQuotes.contains(char) ||
      char == '\n' ||
      char == '.' ||
      char == '?' ||
      char == '!';
}
