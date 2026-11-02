import 'package:flutter/material.dart';

import '../models/item_feedback.dart';
import '../theme.dart';
import '../utils/answer_diff.dart';
import '../utils/blank_assembly.dart';
import '../utils/blanks.dart';
import 'blank_colors.dart';
import 'english_content.dart';
import 'feedback_text.dart';
import 'inline_marks.dart';

/// Shared "question → your answer → correction → why" layout used by both
/// the Results screen's per-item feedback cards and the Review weak-spot
/// detail screen's "Recent mistakes" cards, so the two can't visually drift
/// apart. Each part gets distinct visual weight — the prompt is muted
/// context, the correction is the thing users actually look at — instead of
/// running together as one paragraph. Any part can be omitted (e.g. a
/// skipped item has no answer to show).
///
/// Two shapes of record (1.4.0 D11, server package report §4.4):
///
/// - **Structured**: the scorer's per-blank verdicts ([blankFeedback]) are
///   present. The per-blank rows gain the correct form next to the
///   learner's text and the scorer's note under each; the two boxes render
///   plain (the rows already say what changed, so B10's word difference is
///   not run); the short [summary] replaces the long [explanation] under
///   the boxes.
/// - **Old**: no [blankFeedback] (the old proxy, every record stored
///   before D11). B8's rows, B10's difference and B9's formatted paragraph,
///   unchanged: the fallback renderer.
class MistakeBreakdown extends StatelessWidget {
  /// A "YOU WROTE" row's text for a box left empty.
  static const String leftBlankLabel = 'Left blank';

  /// A "YOU WROTE" row's text for a no-article box.
  static const String noArticleLabel = '—';

  /// The key of blank [index]'s row in "YOU WROTE".
  static Key blankRowKey(int index) => ValueKey('mistake_blank_row_$index');

  /// The key of blank [index]'s note under its row (structured records).
  static Key blankNoteKey(int index) => ValueKey('mistake_blank_note_$index');

  /// The keys of the two boxes' texts (1.4.0 B10: `Text.rich` with the
  /// differing words as pills).
  static const Key userTextKey = Key('mistake_user_text');
  static const Key correctedTextKey = Key('mistake_corrected_text');

  /// The summary under the boxes of a structured record.
  static const Key summaryKey = Key('mistake_summary');

  /// The "You wrote" difference pill's fill: `incorrectBackground` with
  /// 15 % of `onIncorrectBackground` over it (B10.2). The plain
  /// `incorrectBackground` measured 1.25:1 against the box, which the
  /// underline used to make up for; this is 1.66:1 light (`#E1C2C1`) and
  /// 1.73:1 dark (`#563434`), with the text at 8.2:1 and 6.4:1 on it.
  static Color userMarkFill(SemanticColors semantic) => Color.alphaBlend(
        semantic.onIncorrectBackground.withValues(alpha: 0.15),
        semantic.incorrectBackground,
      );

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

  /// The scorer's per-blank verdicts (1.4.0 D11), paired with
  /// [blankAnswers] by index. Null on an old record.
  final List<BlankFeedback>? blankFeedback;

  /// The scorer's short overall lesson (1.4.0 D11), shown in place of
  /// [explanation] on a structured record.
  final String? summary;

  const MistakeBreakdown({
    super.key,
    this.prompt,
    this.userAnswer,
    this.blankAnswers,
    this.correctedAnswer,
    this.explanation,
    this.blankFeedback,
    this.summary,
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
    // A structured record (D11): the scorer's verdicts, and on a multi-blank
    // record one per box. A verdict list that does not line up with the
    // boxes is treated as absent, so the card never pairs a note with the
    // wrong blank.
    final feedback = blankFeedback;
    final structured = feedback != null &&
        feedback.isNotEmpty &&
        (!perBlank || feedback.length == blanks.length) &&
        (perBlank || feedback.length == 1);
    final hasSummary = structured && (summary ?? '').trim().isNotEmpty;
    final promptStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    // The word-level difference (1.4.0 B10), when both texts exist, the
    // record is not structured, and it has no per-blank rows. B10.4 (owner,
    // 2026-11-02): on a per-blank record the diff against the assembled
    // sentence read wrong — a right blank showed no mark and a misspelt
    // one painted only the corrected word — and the per-blank correct
    // forms it would need are D11's data, not derivable here. So
    // "Corrected" stays plain there; the rows stay, and D11's structured
    // fields add the correct form and a mark to each row when present.
    final diff = hasAnswer && hasCorrection && !structured && !perBlank
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
          // The question, the boxes' text and the feedback are English
          // (1.4.0 D2): left to right in every interface language (B3).
          EnglishContent(
            child: colors != null
                ? Text.rich(colouredBlanks(
                    prompt!,
                    colors: colors,
                    total: blankPattern.allMatches(prompt!).length,
                    style: promptStyle,
                  ))
                : Text(prompt!, style: promptStyle),
          ),
          const SizedBox(height: 16),
        ],
        if (hasAnswer) ...[
          _LabeledBox(
            label: 'YOU WROTE',
            fillColor: colorScheme.surface,
            borderColor: colorScheme.outline,
            labelColor: colorScheme.onSurfaceVariant,
            child: perBlank
                ? _BlankRows(
                    answers: blanks,
                    colors: colors!,
                    feedback: structured ? feedback : null,
                  )
                : _DiffText(
                    key: MistakeBreakdown.userTextKey,
                    tokens: diff?.user,
                    plain: userAnswer!,
                    style: userBody,
                    // B10.2: no underline (it collided with descenders);
                    // the fill darkened a step instead, see [userMarkFill].
                    mark: InlineMark(
                      fill: MistakeBreakdown.userMarkFill(semantic),
                      textStyle: userBody.copyWith(
                        color: semantic.onIncorrectBackground,
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
        // A structured record's single verdict (one box, or a blank-less
        // item): its note stands where the paragraph would, then the
        // summary. A multi-blank record's notes sit under their rows.
        if (structured && !perBlank && feedback.single.note.trim().isNotEmpty)
          Padding(
            key: MistakeBreakdown.blankNoteKey(0),
            padding: EdgeInsets.only(bottom: hasSummary ? 10 : 0),
            child: EnglishContent(
                child: Text(feedback.single.note,
                    style: theme.textTheme.bodyMedium)),
          ),
        if (hasSummary)
          FeedbackText(
            summary!,
            key: MistakeBreakdown.summaryKey,
            style: theme.textTheme.bodyMedium,
          )
        else if (!structured && hasExplanation)
          FeedbackText(explanation!, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

/// One row per blank in "YOU WROTE": a 3 pt bar in the blank's colour, then
/// the typed text, "—" for a no-article box, or "Left blank" (muted) for a
/// box left empty. VoiceOver reads "Blank n: …".
///
/// With the scorer's verdicts ([feedback], 1.4.0 D11) each row continues
/// with an arrow and the correct form — muted with a small check when the
/// answer is accepted, in the "Corrected" green when it is not — and the
/// scorer's note under the row.
class _BlankRows extends StatelessWidget {
  final List<BlankAnswer> answers;
  final List<Color> colors;
  final List<BlankFeedback>? feedback;

  const _BlankRows({
    required this.answers,
    required this.colors,
    this.feedback,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantic = theme.extension<SemanticColors>()!;
    final body = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurface,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < answers.length; i++) ...[
          if (i > 0) SizedBox(height: feedback == null ? 6 : 10),
          _row(i, body, colorScheme, semantic, theme.textTheme.bodySmall),
        ],
      ],
    );
  }

  Widget _row(
    int i,
    TextStyle? body,
    ColorScheme colorScheme,
    SemanticColors semantic,
    TextStyle? small,
  ) {
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
    final verdict = feedback?[i];
    final verdictColor = verdict == null
        ? null
        : verdict.accepted
            ? colorScheme.onSurfaceVariant
            : semantic.onCorrectBackground;
    final label = verdict == null
        ? 'Blank ${i + 1}: $spoken'
        : verdict.accepted
            ? 'Blank ${i + 1}: you wrote $spoken, correct '
                '${verdict.correctAnswer}, accepted'
            : 'Blank ${i + 1}: you wrote $spoken, correct '
                '${verdict.correctAnswer}, not accepted: ${verdict.note}';
    // IntrinsicHeight: the bar stretches to the text's height, one line or
    // several, inside a column that has no height of its own to give.
    return Semantics(
      label: label,
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
            Expanded(
              child: verdict == null
                  ? Text(text, style: style)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: text, style: style),
                              TextSpan(
                                text: ' → ${verdict.correctAnswer}',
                                style: body?.copyWith(color: verdictColor),
                              ),
                              if (verdict.accepted)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 4),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: verdictColor,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (verdict.note.trim().isNotEmpty)
                          Padding(
                            key: MistakeBreakdown.blankNoteKey(i),
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              verdict.note,
                              style: small?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
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
    // Consecutive painted words with nothing between them are one phrase
    // (one continuous strip, B10.1); a trailing or leading mark breaks it.
    final spans = <InlineSpan>[];
    var i = 0;
    while (i < tokens.length) {
      final token = tokens[i];
      if (i > 0) spans.add(const TextSpan(text: ' '));
      if (!token.painted) {
        spans.add(TextSpan(text: token.text));
        i++;
        continue;
      }
      if (token.lead.isNotEmpty) spans.add(TextSpan(text: token.lead));
      final phrase = StringBuffer(token.core);
      var last = token;
      while (i + 1 < tokens.length &&
          tokens[i + 1].painted &&
          last.trail.isEmpty &&
          tokens[i + 1].lead.isEmpty) {
        i++;
        last = tokens[i];
        phrase.write(' ${last.core}');
      }
      spans.addAll(markedSpans(phrase.toString(), mark));
      if (last.trail.isNotEmpty) spans.add(TextSpan(text: last.trail));
      i++;
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
          // The label above follows the interface; the English inside reads
          // left to right (1.4.0 B3).
          EnglishContent(child: child),
        ],
      ),
    );
  }
}
