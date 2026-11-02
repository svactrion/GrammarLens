import 'package:flutter/material.dart';

import '../utils/blanks.dart';

/// The colours that link a blank in the sentence to its answer box
/// (question screen plan, §4): blank n's underline and box n's edge share
/// one. Four, for at most four blanks. No red or green (the correct /
/// incorrect colours). Contrast as non-text UI (needs 3:1):
///
/// | Blank  | Light     | card / page | Dark      | card / page |
/// |--------|-----------|-------------|-----------|-------------|
/// | orange | `#C2570C` | 4.37 / 3.93 | `#FF9A52` | 7.28 / 8.68 |
/// | blue   | `#2F5BD3` | 5.72 / 5.14 | `#8FB0FF` | 7.15 / 8.53 |
/// | teal   | `#0B7A87` | 4.91 / 4.41 | `#4CCBD8` | 7.89 / 9.41 |
/// | violet | `#8A3FC4` | 5.67 / 5.10 | `#D3A6FF` | 7.76 / 9.26 |
///
/// The brand orange `#FF7A1A` itself is 2.53:1 on the light card, hence the
/// darker orange.
List<Color> blankColors(Brightness brightness) =>
    brightness == Brightness.dark ? _dark : _light;

/// [text] with each blank's underscores replaced in look (not in width, so
/// lines wrap as before) by an underline in its colour, blank n in
/// `colors[n % colors.length]`, numbered from [first] in reading order out
/// of [total]; [focusedBlank] tinted. VoiceOver reads [blankLabel]
/// ("blank n of N", `blankSemantics` in the strings). The
/// question card and the "YOU WROTE" rows (`MistakeBreakdown`) share it, so
/// a row's colour points at the same blank on both.
TextSpan colouredBlanks(
  String text, {
  required List<Color> colors,
  required int total,
  required String Function(int number, int total) blankLabel,
  int first = 0,
  int? focusedBlank,
  TextStyle? style,
}) {
  final spans = <InlineSpan>[];
  var last = 0;
  var index = first;
  for (final blank in blankPattern.allMatches(text)) {
    spans.add(TextSpan(text: text.substring(last, blank.start)));
    final color = colors[index % colors.length];
    spans.add(TextSpan(
      text: blank[0],
      semanticsLabel: blankLabel(index + 1, total),
      style: TextStyle(
        color: Colors.transparent,
        decoration: TextDecoration.underline,
        decorationColor: color,
        decorationThickness: 3,
        backgroundColor:
            index == focusedBlank ? color.withValues(alpha: 0.16) : null,
      ),
    ));
    index++;
    last = blank.end;
  }
  spans.add(TextSpan(text: text.substring(last)));
  return TextSpan(style: style, children: spans);
}

const List<Color> _light = [
  Color(0xFFC2570C),
  Color(0xFF2F5BD3),
  Color(0xFF0B7A87),
  Color(0xFF8A3FC4),
];

const List<Color> _dark = [
  Color(0xFFFF9A52),
  Color(0xFF8FB0FF),
  Color(0xFF4CCBD8),
  Color(0xFFD3A6FF),
];
