/// Interface labels of model values, from the ARB (1.4.0 B4.1). The models
/// stay free of interface text; screens call `goal.label(context.l10n)`.
library;

import 'package:flutter/painting.dart';

import '../models/learning_goal.dart';
import '../models/practice_length.dart';
import '../models/review_sort_order.dart';
import '../models/topic.dart';
import '../utils/answer_matching.dart';
import '../utils/text_format.dart';
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

extension TopicLabels on Topic {
  String title(AppLocalizations l10n) => switch (id) {
        TopicId.gerundVsInfinitive => l10n.topicGerundTitle,
        TopicId.modalVerbs => l10n.topicModalVerbsTitle,
        TopicId.modalPastForms => l10n.topicModalPastTitle,
        TopicId.tenseSelection => l10n.topicTenseTitle,
        TopicId.articles => l10n.topicArticlesTitle,
      };

  String description(AppLocalizations l10n) => switch (id) {
        TopicId.gerundVsInfinitive => l10n.topicGerundDescription,
        TopicId.modalVerbs => l10n.topicModalVerbsDescription,
        TopicId.modalPastForms => l10n.topicModalPastDescription,
        TopicId.tenseSelection => l10n.topicTenseDescription,
        TopicId.articles => l10n.topicArticlesDescription,
      };
}

/// Whether a weak spot's rule ([errorType], the scorer's English slug, or
/// the topic id a Daily Test mistake stores) is just its [topic]: compared
/// in English, the slug humanized against the topic id humanized ("Gerund
/// vs. Infinitive" both ways), so it holds in every interface language.
/// Before 1.4.0 B4.4 it compared with the topic's English title, which
/// `test/l10n_labels_test.dart` pins as the same thing.
bool ruleIsTopic(String errorType, Topic topic) =>
    humanizeSlug(errorType) == humanizeSlug(topic.id.name);

/// A weak spot's title: the topic's own title when the rule is the topic
/// ([ruleIsTopic]), translated; otherwise the scorer's English rule name,
/// humanized (AI output stays English, 1.4.0 D2).
String weakSpotTitle(String errorType, Topic topic, AppLocalizations l10n) =>
    ruleIsTopic(errorType, topic) ? topic.title(l10n) : humanizeSlug(errorType);

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

/// How many characters the keyboard note names before it shortens to "…".
const int _noteMaxCharacters = 3;

/// The Daily Test card's note for a keyboard-variant answer (1.4.0 B3,
/// B4.3; report §8 Q8): which characters the keyboard typed in another
/// form, and which it added, then that it is not a grammar mistake.
String keyboardVariantNoteText(
    KeyboardVariantNote note, AppLocalizations l10n) {
  if (note.isEmpty) return l10n.keyboardNoteGeneral;
  String quoted(Iterable<String> chars) {
    final list = chars.toList();
    final shown = list.take(_noteMaxCharacters).map((c) => '"$c"').join(', ');
    return list.length > _noteMaxCharacters ? '$shown …' : shown;
  }

  final addedParts = [
    if (note.added.isNotEmpty) quoted(note.added),
    if (note.invisible) l10n.keyboardNoteInvisible,
  ];
  final added = addedParts.isEmpty
      ? null
      : addedParts.length == 1
          ? l10n.keyboardNoteAdded(addedParts.single)
          : l10n.keyboardNoteAdded(
              l10n.keyboardNoteAnd(addedParts[0], addedParts[1]));
  if (note.typed.isEmpty) return added!;
  final typed = l10n.keyboardNoteTyped(
    quoted(note.typed.map((p) => p.$1)),
    quoted(note.typed.map((p) => p.$2)),
    note.typed.length,
  );
  return added == null
      ? '$typed ${l10n.keyboardNoteNotAMistake}'
      : '$typed $added';
}
