import 'package:flutter/material.dart';

import '../theme.dart';

/// Shared "question → your answer → correction → why" layout used by both
/// the Results screen's per-item feedback cards and the Review weak-spot
/// detail screen's "Recent mistakes" cards, so the two can't visually drift
/// apart. Each part gets distinct visual weight — the prompt is muted
/// context, the correction is the thing users actually look at — instead of
/// running together as one paragraph. Any part can be omitted (e.g. a
/// skipped item has no answer to show).
class MistakeBreakdown extends StatelessWidget {
  final String? prompt;
  final String? userAnswer;
  final String? correctedAnswer;
  final String? explanation;

  const MistakeBreakdown({
    super.key,
    this.prompt,
    this.userAnswer,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasPrompt) ...[
          Text(
            prompt!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (hasAnswer) ...[
          _LabeledBox(
            label: 'YOU WROTE',
            text: userAnswer!,
            fillColor: colorScheme.surface,
            borderColor: colorScheme.outline,
            labelColor: colorScheme.onSurfaceVariant,
            textColor: colorScheme.onSurface,
          ),
          const SizedBox(height: 12),
        ],
        if (hasCorrection) ...[
          _LabeledBox(
            label: 'CORRECTED',
            text: correctedAnswer!,
            fillColor: semantic.correctBackground,
            borderColor: semantic.onCorrectBackground,
            labelColor: semantic.onCorrectBackground,
            textColor: semantic.onCorrectBackground,
          ),
          const SizedBox(height: 16),
        ],
        if (hasExplanation)
          Text(explanation!, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class _LabeledBox extends StatelessWidget {
  final String label;
  final String text;
  final Color fillColor;
  final Color borderColor;
  final Color labelColor;
  final Color textColor;

  const _LabeledBox({
    required this.label,
    required this.text,
    required this.fillColor,
    required this.borderColor,
    required this.labelColor,
    required this.textColor,
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
            style: theme.textTheme.labelSmall?.copyWith(
              color: labelColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}
