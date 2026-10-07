import 'package:flutter/material.dart';

/// Home's "Good morning, <name>", read by VoiceOver as that one sentence.
///
/// One line when it fits. When it does not, two lines: the greeting word on
/// the first, the name on a line of its own
/// (`docs/design/greeting-fix/report.md`, option A). On one line the ellipsis
/// cuts from the end, and at 320 pt "Good morning, " leaves less room than
/// one letter plus "…", so the name vanished entirely, for every name, at
/// the default text size.
///
/// - Only the first line may shrink, and only if the greeting word alone is
///   wider than the space ("Good afternoon," at Large on a 320 pt screen).
/// - The name keeps the user's text size; it is shortened with "…" only if
///   it is longer than a whole line, so it is never lost entirely.
/// - An empty name shows the greeting word alone.
///
/// With [nameStyle] (Home since 1.2.0, the brief's greeting): always two
/// lines, "Good evening," in [style] above the name in [nameStyle]. The
/// name wraps rather than being shortened, so a long name is never cut off.
class HomeGreeting extends StatelessWidget {
  final String word;
  final String name;
  final TextStyle? style;
  final TextStyle? nameStyle;

  const HomeGreeting(
      {super.key,
      required this.word,
      required this.name,
      this.style,
      this.nameStyle});

  /// What is shown, and what VoiceOver reads, however it is laid out.
  String get text => name.isEmpty ? word : '$word, $name';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: nameStyle != null
          ? _stacked()
          : LayoutBuilder(builder: (context, constraints) {
              if (name.isEmpty || _fitsOneLine(context, constraints.maxWidth)) {
                return Text(text,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('$word,', maxLines: 1, style: style),
                  ),
                  Text(name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: style),
                ],
              );
            }),
    );
  }

  Widget _stacked() {
    if (name.isEmpty) return Text(word, style: style);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$word,', style: style),
        Text(name, style: nameStyle),
      ],
    );
  }

  /// Lays the one-line text out the way [Text] would (the same merged
  /// style, text scaler and direction) and checks it needs no ellipsis.
  bool _fitsOneLine(BuildContext context, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(
          text: text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: maxWidth);
    final fits = !painter.didExceedMaxLines;
    painter.dispose();
    return fits;
  }
}
