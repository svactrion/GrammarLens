import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/feedback_format.dart';
import 'inline_marks.dart';

/// AI feedback laid out for reading (1.4.0 B9): [formatFeedback]'s
/// paragraphs 10 pt apart, the closing paragraph under a thin rule, and
/// quoted examples as chips (1.4.0 B10, replacing B9's weight-only
/// emphasis, which did not separate from the body on the dark surface):
/// a translucent `onSurface` fill, 12 % in light and 14 % in dark, radius
/// 4, 3 pt of horizontal padding, weight 600, the text colour unchanged.
/// Translucent, so the chip reads the same on a card and on the
/// "Saved feedback" panel (which is `surfaceContainerHighest` itself); the
/// body text keeps at least 8.7:1 on the chip. One or two sentences render
/// as one paragraph, so short and stored plain-text feedback looks as it
/// did. Used at exactly two sites: `MistakeBreakdown`'s explanation and the
/// weak-spot detail's "Saved feedback" panel. VoiceOver reads each
/// paragraph as its plain text.
class FeedbackText extends StatelessWidget {
  static Key paragraphKey(int index) => ValueKey('feedback_paragraph_$index');
  static const Key closingRuleKey = Key('feedback_closing_rule');

  /// The chip's fill over the surface behind it.
  static Color chipFill(ColorScheme scheme) => scheme.onSurface
      .withValues(alpha: scheme.brightness == Brightness.dark ? 0.14 : 0.12);

  final String text;

  /// The body style; the ambient [DefaultTextStyle] when null.
  final TextStyle? style;

  const FeedbackText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final formatted = formatFeedback(text);
    final scheme = Theme.of(context).colorScheme;
    final base = style ?? DefaultTextStyle.of(context).style;
    final mark = InlineMark(
      fill: chipFill(scheme),
      textStyle: base.withWeight(FontWeight.w600),
    );
    Widget paragraph(int index, FeedbackParagraph p) => Semantics(
          label: p.text,
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              style: base,
              children: [
                for (final span in p.spans)
                  if (span.emphasized)
                    ...markedSpans(span.text, mark)
                  else
                    TextSpan(text: span.text),
              ],
            ),
            key: paragraphKey(index),
          ),
        );
    final paragraphs = formatted.paragraphs;
    if (paragraphs.isEmpty) return const SizedBox.shrink();
    if (paragraphs.length == 1) return paragraph(0, paragraphs.single);
    final last = paragraphs.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < paragraphs.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          if (formatted.hasClosing && i == last) ...[
            Divider(
              key: closingRuleKey,
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant,
            ),
            const SizedBox(height: 10),
          ],
          paragraph(i, paragraphs[i]),
        ],
      ],
    );
  }
}
