import 'package:flutter/material.dart';

/// Inline marks for a run of text (1.4.0 B10): the quote chips in
/// `FeedbackText` and the difference pills in `MistakeBreakdown`. A mark is
/// one [WidgetSpan] per word, so a marked phrase wraps like text instead of
/// moving to the next line as a block; the outer edges are rounded, the
/// inner edges between two words of one mark are square. Each word sits on
/// the text baseline.
class InlineMark {
  final Color fill;
  final TextStyle textStyle;
  final double radius;
  final double horizontalPadding;

  const InlineMark({
    required this.fill,
    required this.textStyle,
    this.radius = 4,
    this.horizontalPadding = 3,
  });
}

/// [text] as marked spans: the words of [text] each in their own pill
/// (spaces between them as plain text), the first and last with rounded
/// outer corners.
List<InlineSpan> markedSpans(String text, InlineMark mark) {
  final words = text.split(' ');
  final spans = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    if (i > 0) spans.add(const TextSpan(text: ' '));
    final word = words[i];
    if (word.isEmpty) continue;
    final r = Radius.circular(mark.radius);
    final first = i == 0;
    final last = i == words.length - 1;
    spans.add(WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: mark.fill,
          borderRadius: BorderRadius.horizontal(
            left: first ? r : Radius.zero,
            right: last ? r : Radius.zero,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: mark.horizontalPadding),
          child: Text(word, style: mark.textStyle),
        ),
      ),
    ));
  }
  return spans;
}

/// The plain text of [span], with a [WidgetSpan] made by [markedSpans] read
/// as its word rather than the placeholder character.
String plainTextOf(InlineSpan span) {
  final buffer = StringBuffer();
  span.visitChildren((child) {
    if (child is TextSpan) {
      if (child.text != null) buffer.write(child.text);
    } else if (child is WidgetSpan) {
      buffer.write(_wordOf(child.child));
    }
    return true;
  });
  return buffer.toString();
}

String _wordOf(Widget widget) {
  if (widget is Text) return widget.data ?? plainTextOf(widget.textSpan!);
  if (widget is DecoratedBox) return _wordOf(widget.child!);
  if (widget is Padding) return _wordOf(widget.child!);
  return '￼';
}
