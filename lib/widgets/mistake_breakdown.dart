import 'package:flutter/material.dart';

import '../theme.dart';
import '../utils/answer_diff.dart';
import '../utils/blank_assembly.dart';
import '../utils/blanks.dart';
import 'blank_colors.dart';
import 'feedback_text.dart';
import 'inline_marks.dart';

/// Shared "question → your answer → correction → why" layout used by both
/// the Results screen's per-item feedback cards and the Review weak-spot
/// detail screen's "Recent mistakes" cards, so the two can't visually drift
/// apart. Each part gets distinct visual weight — the prompt is muted
/// context, the correction is the thing users actually look at — instead of
/// running together as one paragraph. Any part can be omitted (e.g. a
/// skipped item has no answer to show).
class MistakeBreakdown extends StatelessWidget {
  /// A "YOU WROTE" row's text for a box left empty.
  static const String leftBlankLabel = 'Left blank';

  /// A "YOU WROTE" row's text for a no-article box.
  static const String noArticleLabel = '—';

  /// The key of blank [index]'s row in "YOU WROTE".
  static Key blankRowKey(int index) => ValueKey('mistake_blank_row_$index');

  /// The keys of the two boxes' texts (1.4.0 B10: `Text.rich` with the
  /// differing words as pills).
  static const Key userTextKey = Key('mistake_user_text');
  static const Key correctedTextKey = Key('mistake_corrected_text');

  final String? prompt;
  final String? userAnswer;

  /// On a multi-blank Practice question, what each answer box held, in
  /// blank order (1.4.0 B8). With two or more entries "YOU WROTE" shows one
  /// row per blank instead of [userAnswer] (the assembled sentence, which
  /// repeats the prompt), and the prompt's blanks take the question card's
  /// colours so each row's colour points at its blank. Null or a single
  /// entry: [userAnswer] as it is.
  final List<BlankAnswer>? blankAnswers;
  final String? correctedAnswer;
  final String? explanation;

  const MistakeBreakdown({
    super.key,
    this.prompt,
    this.userAnswer,
    this.blankAnswers,
    this.correctedAnswer,
    this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>()!;
    final hasPrompt = (prompt ?? '').trim().isNotEmpty;
    final hasAnswer = (userAnswer ?? '').trim().isNotEmpty;
    final hasCorrection = (correctedAnswer ?? '').trim().isNotEmpty &&
        correctedAnswer!.trim().toLowerCase() !=
            (userAnswer ?? '').trim().toLowerCase();
    final hasExplanation = (explanation ?? '').trim().isNotEmpty;
    // Skippedness is never passed in — it's the same fact `hasAnswer`
    // already computes (an empty answer), derived once here rather than as
    // a caller-supplied bool. Every caller that has a real "skipped" state
    // (ScoringResult/DailyTest results) sets it exactly by leaving
    // userAnswer empty, so this can't drift out of sync with a caller the
    // way a separate parameter could if one call site forgot to pass it
    // (docs/design-audit.md, Batch 0 item 1's correction). Weak-spot
    // detail's mistakes are always real wrong answers (never skipped ones
    // are recorded there), so `isSkipped` is always false for that caller
    // and its box is unaffected.
    final isSkipped = hasCorrection && !hasAnswer;
    final blanks = blankAnswers;
    final perBlank = hasAnswer && blanks != null && blanks.length >= 2;
    final colors = perBlank ? blankColors(theme.brightness) : null;
    final promptStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    // The word-level difference (1.4.0 B10), when both texts exist. On a
    // per-blank record "You wrote" shows B8's rows, so only "Corrected" is
    // painted; the assembled sentence is still what is compared.
    final diff = hasAnswer && hasCorrection
        ? diffAnswer(
            userAnswer: userAnswer!,
            correctedAnswer: correctedAnswer!,
            prompt: prompt,
          )
        : null;
    final userBody =
        theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface) ??
            const TextStyle();
    final correctedBody = theme.textTheme.bodyMedium?.copyWith(
          color:
              isSkipped ? colorScheme.onSurface : semantic.onCorrectBackground,
        ) ??
        const TextStyle();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPrompt) ...[
          colors != null
              ? Text.rich(colouredBlanks(
                  prompt!,
                  colors: colors,
                  total: blankPattern.allMatches(prompt!).length,
                  style: promptStyle,
                ))
              : Text(prompt!, style: promptStyle),
          const SizedBox(height: 16),
        ],
        if (hasAnswer) ...[
          _LabeledBox(
            label: 'YOU WROTE',
            fillColor: colorScheme.surface,
            borderColor: colorScheme.outline,
            labelColor: colorScheme.onSurfaceVariant,
            child: perBlank
                ? _BlankRows(answers: blanks, colors: colors!)
                : _DiffText(
                    key: MistakeBreakdown.userTextKey,
                    tokens: diff?.user,
                    plain: userAnswer!,
                    style: userBody,
                    mark: InlineMark(
                      fill: semantic.incorrectBackground,
                      textStyle: userBody.copyWith(
                        color: semantic.onIncorrectBackground,
                        decoration: TextDecoration.underline,
                        decorationColor: semantic.onIncorrectBackground,
                        decorationThickness: 1.5,
                      ),
                      horizontalPadding: 2,
                    ),
                  ),
          ),
          const SizedBox(height: 12),
        ],
        if (hasCorrection) ...[
          // A skipped question was never attempted, so the correct answer
          // here isn't a correction of anything — the green "CORRECTED"
          // treatment (this app's success color) doesn't apply, and gets
          // the same neutral box "YOU WROTE" already uses above instead.
          _LabeledBox(
            label: isSkipped ? 'CORRECT ANSWER' : 'CORRECTED',
            fillColor:
                isSkipped ? colorScheme.surface : semantic.correctBackground,
            borderColor:
                isSkipped ? colorScheme.outline : semantic.onCorrectBackground,
            labelColor: isSkipped
                ? colorScheme.onSurfaceVariant
                : semantic.onCorrectBackground,
            child: _DiffText(
              key: MistakeBreakdown.correctedTextKey,
              tokens: diff?.corrected,
              plain: correctedAnswer!,
              style: correctedBody,
              // The inverse of the box: a solid pill in the box's text
              // colour, the box's fill as the word's colour.
              mark: InlineMark(
                fill: semantic.onCorrectBackground,
                textStyle:
                    correctedBody.copyWith(color: semantic.correctBackground),
                horizontalPadding: 2,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (hasExplanation)
          FeedbackText(explanation!, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// One row per blank in "YOU WROTE": a 3 pt bar in the blank's colour, then
/// the typed text, "—" for a no-article box, or "Left blank" (muted) for a
/// box left empty. VoiceOver reads "Blank n: …".
class _BlankRows extends StatelessWidget {
  final List<BlankAnswer> answers;
  final List<Color> colors;

  const _BlankRows({required this.answers, required this.colors});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < answers.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          _row(i, body, colorScheme),
        ],
      ],
    );
  }

  Widget _row(int i, TextStyle? body, ColorScheme colorScheme) {
    final answer = answers[i];
    final String text;
    final TextStyle? style;
    final String spoken;
    if (answer.noArticle) {
      text = MistakeBreakdown.noArticleLabel;
      style = body;
      spoken = 'no article';
    } else if (answer.isFilled) {
      text = answer.text.trim();
      style = body;
      spoken = text;
    } else {
      text = MistakeBreakdown.leftBlankLabel;
      style = body?.copyWith(color: colorScheme.onSurfaceVariant);
      spoken = 'left blank';
    }
    // IntrinsicHeight: the bar stretches to the text's height, one line or
    // several, inside a column that has no height of its own to give.
    return Semantics(
      label: 'Blank ${i + 1}: $spoken',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          key: MistakeBreakdown.blankRowKey(i),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: colors[i % colors.length],
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: style)),
          ],
        ),
      ),
    );
  }
}

/// A box's text with its differing words as pills ([markedSpans]); the
/// plain text when there is no difference to show. VoiceOver reads the
/// plain sentence.
class _DiffText extends StatelessWidget {
  final List<DiffToken>? tokens;
  final String plain;
  final TextStyle style;
  final InlineMark mark;

  const _DiffText({
    super.key,
    required this.tokens,
    required this.plain,
    required this.style,
    required this.mark,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = this.tokens;
    if (tokens == null || !tokens.any((t) => t.painted)) {
      return Text(plain, style: style);
    }
    final spans = <InlineSpan>[];
    for (var i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      if (i > 0) spans.add(const TextSpan(text: ' '));
      if (!token.painted) {
        spans.add(TextSpan(text: token.text));
        continue;
      }
      if (token.lead.isNotEmpty) spans.add(TextSpan(text: token.lead));
      spans.addAll(markedSpans(token.core, mark));
      if (token.trail.isNotEmpty) spans.add(TextSpan(text: token.trail));
    }
    return Semantics(
      label: plain,
      excludeSemantics: true,
      child: Text.rich(TextSpan(style: style, children: spans)),
    );
  }
}

class _LabeledBox extends StatelessWidget {
  final String label;
  final Widget child;
  final Color fillColor;
  final Color borderColor;
  final Color labelColor;

  const _LabeledBox({
    required this.label,
    required this.child,
    required this.fillColor,
    required this.borderColor,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall
                ?.withWeight(FontWeight.w700)
                .copyWith(color: labelColor, letterSpacing: 0.6),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
