import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/feedback_format.dart';

/// AI feedback laid out for reading (1.4.0 B9): [formatFeedback]'s
/// paragraphs 10 pt apart, the closing paragraph under a thin rule, and
/// quoted examples at weight 700 in the surrounding colour (no accent
/// colour: the link blue would read as tappable). One or two sentences
/// render as one paragraph, so short and stored plain-text feedback looks
/// as it did. Used at exactly two sites: `MistakeBreakdown`'s explanation
/// and the weak-spot detail's "Saved feedback" panel.
class FeedbackText extends StatelessWidget {
  static Key paragraphKey(int index) => ValueKey('feedback_paragraph_$index');
  static const Key closingRuleKey = Key('feedback_closing_rule');

  final String text;

  /// The body style; the ambient [DefaultTextStyle] when null.
  final TextStyle? style;

  const FeedbackText(this.text, {super.key, this.style});

  @override
  Widget build(BuildContext context) {
    final formatted = formatFeedback(text);
    final base = style ?? DefaultTextStyle.of(context).style;
    final emphasis = base.withWeight(FontWeight.w700);
    Widget paragraph(int index, FeedbackParagraph p) => Text.rich(
          TextSpan(
            style: base,
            children: [
              for (final span in p.spans)
                TextSpan(
                    text: span.text, style: span.emphasized ? emphasis : null),
            ],
          ),
          key: paragraphKey(index),
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
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 10),
          ],
          paragraph(i, paragraphs[i]),
        ],
      ],
    );
  }
}
