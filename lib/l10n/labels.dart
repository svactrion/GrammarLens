/// Interface labels of model values, from the ARB (1.4.0 B4.1). The models
/// stay free of interface text; screens call `goal.label(context.l10n)`.
library;

import 'package:flutter/painting.dart';

import '../models/learning_goal.dart';
import '../models/practice_length.dart';
import '../models/review_sort_order.dart';
import 'generated/app_localizations.dart';

extension LearningGoalLabels on LearningGoal {
  String label(AppLocalizations l10n) => switch (this) {
        LearningGoal.examPrep => l10n.goalExamPrep,
        LearningGoal.work => l10n.goalWork,
        LearningGoal.general => l10n.goalGeneral,
      };

  String description(AppLocalizations l10n) => switch (this) {
        LearningGoal.examPrep => l10n.goalExamPrepDetail,
        LearningGoal.work => l10n.goalWorkDetail,
        LearningGoal.general => l10n.goalGeneralDetail,
      };
}

extension PracticeLengthLabels on PracticeLength {
  String label(AppLocalizations l10n) => switch (this) {
        PracticeLength.quick => l10n.practiceLengthQuick,
        PracticeLength.standard => l10n.practiceLengthStandard,
        PracticeLength.extended => l10n.practiceLengthExtended,
      };

  String description(AppLocalizations l10n) => switch (this) {
        PracticeLength.quick => l10n.practiceLengthQuickDetail,
        PracticeLength.standard => l10n.practiceLengthStandardDetail,
        PracticeLength.extended => l10n.practiceLengthExtendedDetail,
      };
}

extension ReviewSortOrderLabels on ReviewSortOrder {
  String label(AppLocalizations l10n) => switch (this) {
        ReviewSortOrder.recent => l10n.reviewSortRecent,
        ReviewSortOrder.frequent => l10n.reviewSortFrequent,
      };
}

/// [text] as spans with each of [emphasized] (values a localized message
/// inserted through its placeholders) in [style]. A message cannot carry
/// spans itself, so the emphasis is found again in the formatted text, at
/// each value's first occurrence, in whatever order a translation puts
/// them. A value not found is left plain; of two overlapping values, the
/// earlier one wins.
List<InlineSpan> emphasizedSpans(
  String text, {
  required List<String> emphasized,
  required TextStyle style,
}) {
  final found = <(int, int)>[];
  for (final value in emphasized) {
    if (value.isEmpty) continue;
    final at = text.indexOf(value);
    if (at >= 0) found.add((at, at + value.length));
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  final spans = <InlineSpan>[];
  var i = 0;
  for (final (start, end) in found) {
    if (start < i) continue; // overlapping values: keep the first
    if (start > i) spans.add(TextSpan(text: text.substring(i, start)));
    spans.add(TextSpan(text: text.substring(start, end), style: style));
    i = end;
  }
  if (i < text.length) spans.add(TextSpan(text: text.substring(i)));
  return spans;
}
