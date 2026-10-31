import 'package:flutter/material.dart';

/// Inline marks for a run of text (1.4.0 B10): the quote chips in
/// `FeedbackText` and the difference pills in `MistakeBreakdown`. A mark is
/// one [WidgetSpan] per word, so a marked phrase wraps like text instead of
/// moving to the next line as a block; the outer edges are rounded, the
/// inner edges between two words of one mark are square, and every piece
/// but the last carries its trailing space inside the mark (B10.1), so the
/// fill and any underline run on across the gap and the phrase reads as
/// one continuous strip. Each word sits on the text baseline.
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

/// [text] as marked spans: the words of [text] each in their own pill, the
/// first and last with rounded outer corners, each but the last ending in
/// its space so the pieces touch.
List<InlineSpan> markedSpans(String text, InlineMark mark) {
  final words = text.split(' ').where((w) => w.isNotEmpty).toList();
  final spans = <InlineSpan>[];
  for (var i = 0; i < words.length; i++) {
    final first = i == 0;
    final last = i == words.length - 1;
    final word = last ? words[i] : '${words[i]} ';
    final r = Radius.circular(mark.radius);
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
