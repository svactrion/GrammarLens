import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:grammar_lens/widgets/inline_marks.dart';

/// Helpers for text rendered with inline marks (1.4.0 B10): a `Text.rich`
/// whose chips and pills are `WidgetSpan`s, which `find.text` reads as
/// placeholder characters.

/// The text of a [Text] widget with its marked words read as words.
String plainTextOfWidget(Text text) =>
    text.data ?? (text.textSpan == null ? '' : plainTextOf(text.textSpan!));

/// A [Text] whose plain text is [plain], marks read as their words.
Finder findPlainText(String plain, {bool skipOffstage = true}) =>
    find.byWidgetPredicate(
      (w) => w is Text && plainTextOfWidget(w) == plain,
      description: 'text "$plain" (marks read as words)',
      skipOffstage: skipOffstage,
    );

/// One marked word as rendered: its text, the fill behind it, and the
/// word's own style.
class RenderedMark {
  final String word;
  final Color fill;
  final TextStyle? style;
  final BorderRadius radius;

  const RenderedMark(this.word, this.fill, this.style, this.radius);

  @override
  String toString() => '$word($fill)';
}

/// The [Text] at [finder]: the widget itself, or its first descendant
/// [Text] when the key sits on a wrapper (the card's boxes).
Text textAt(WidgetTester tester, Finder finder) {
  final widget = tester.widget(finder);
  if (widget is Text) return widget;
  return tester.widget<Text>(
      find.descendant(of: finder, matching: find.byType(Text)).first);
}

/// The marks inside the [Text] at [finder], in order.
List<RenderedMark> marksIn(WidgetTester tester, Finder finder) {
  final text = textAt(tester, finder);
  final marks = <RenderedMark>[];
  text.textSpan?.visitChildren((span) {
    if (span is WidgetSpan) {
      var child = span.child;
      BorderRadius radius = BorderRadius.zero;
      Color? fill;
      while (true) {
        if (child is DecoratedBox) {
          final decoration = child.decoration as BoxDecoration;
          fill = decoration.color;
          radius = (decoration.borderRadius as BorderRadius?) ?? radius;
          child = child.child!;
        } else if (child is Padding) {
          child = child.child!;
        } else {
          break;
        }
      }
      final word = child as Text;
      marks.add(RenderedMark(word.data!, fill!, word.style, radius));
    }
    return true;
  });
  return marks;
}
