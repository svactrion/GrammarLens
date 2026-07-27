import 'package:flutter/material.dart';

import '../models/practice_length.dart';

/// Quick "how many questions" step shown before a practice set is generated
/// (see `practice_launch.dart`, which calls this ahead of every topic launch
/// and every Review "Practice this" launch so the two entry points can't
/// drift apart). [initial] — the user's last choice — is pre-highlighted;
/// tapping any option immediately resolves the future with that choice.
/// Dismissing without tapping one (e.g. the back gesture) resolves `null`,
/// which the caller treats as "cancelled, don't generate anything".
Future<PracticeLength?> showPracticeLengthPicker({
  required BuildContext context,
  required PracticeLength initial,
}) {
  return showDialog<PracticeLength>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('How many questions?'),
      content: SizedBox(
        // AlertDialog sizes `content` to its children's intrinsic width by
        // default, which would let the Column's rows shrink to their
        // longest child instead of filling the dialog — this forces them
        // to stretch full-width.
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final length in PracticeLength.values) ...[
              if (length != PracticeLength.values.first)
                const SizedBox(height: 12),
              _LengthOption(length: length, selected: length == initial),
            ],
          ],
        ),
      ),
    ),
  );
}

IconData _iconFor(PracticeLength length) {
  switch (length) {
    case PracticeLength.quick:
      return Icons.bolt_rounded;
    case PracticeLength.standard:
      return Icons.track_changes_rounded;
    case PracticeLength.extended:
      return Icons.terrain_rounded;
  }
}

class _LengthOption extends StatelessWidget {
  final PracticeLength length;
  final bool selected;

  const _LengthOption({required this.length, required this.selected});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final onAccent = colorScheme.onSecondary;
    final titleColor = selected ? onAccent : colorScheme.onSurface;
    final subtitleColor = selected ? onAccent : colorScheme.onSurfaceVariant;
    final iconColor = selected ? onAccent : colorScheme.onSurfaceVariant;

    return Material(
      color: selected ? colorScheme.secondary : Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).pop(length),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: selected ? null : Border.all(color: colorScheme.outline),
          ),
          child: Row(
            children: [
              Icon(_iconFor(length), color: iconColor, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${length.label} · ${length.questionCount} questions',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      length.description,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: subtitleColor),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: onAccent, size: 22),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
