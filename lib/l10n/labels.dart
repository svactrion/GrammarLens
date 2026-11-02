/// Interface labels of model values, from the ARB (1.4.0 B4.1). The models
/// stay free of interface text; screens call `goal.label(context.l10n)`.
library;

import 'package:flutter/painting.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../models/avatar.dart';
import '../models/climb_theme.dart';
import '../models/learning_goal.dart';
import '../models/medal_tier.dart';
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

extension AvatarLabels on Avatar {
  /// The animal the illustration shows, in the interface language (shown
  /// under the carousel and read by VoiceOver). [Avatar.semanticLabel] is
  /// the English identity.
  String name(AppLocalizations l10n) => switch (index) {
        1 => l10n.avatarKoala,
        2 => l10n.avatarSnail,
        3 => l10n.avatarElephant,
        4 => l10n.avatarBee,
        5 => l10n.avatarFrog,
        6 => l10n.avatarChick,
        7 => l10n.avatarCrab,
        8 => l10n.avatarCat,
        9 => l10n.avatarTurtle,
        10 => l10n.avatarPenguin,
        11 => l10n.avatarGiraffe,
        12 => l10n.avatarHedgehog,
        13 => l10n.avatarBird,
        14 => l10n.avatarFox,
        15 => l10n.avatarPanda,
        16 => l10n.avatarSloth,
        _ => semanticLabel,
      };
}

extension MedalTierLabels on MedalTier {
  String label(AppLocalizations l10n) => switch (this) {
        MedalTier.bronze => l10n.tierBronze,
        MedalTier.silver => l10n.tierSilver,
        MedalTier.gold => l10n.tierGold,
      };
}

extension ClimbThemeLabels on ClimbTheme {
  /// The theme's name ("Ember Peak"); its id for a theme the strings do
  /// not know yet.
  String title(AppLocalizations l10n) => switch (id) {
        'green_slope' => l10n.themeGreenSlope,
        'ember_peak' => l10n.themeEmberPeak,
        'glacier_peak' => l10n.themeGlacierPeak,
        'red_canyon' => l10n.themeRedCanyon,
        _ => id,
      };

  String tagline(AppLocalizations l10n) => switch (id) {
        'green_slope' => l10n.themeGreenSlopeTagline,
        'ember_peak' => l10n.themeEmberPeakTagline,
        'glacier_peak' => l10n.themeGlacierPeakTagline,
        'red_canyon' => l10n.themeRedCanyonTagline,
        _ => '',
      };
}

/// A save point's name on screen. [name] is its English identity
/// (`ClimbSavePoints.names`, also the `save_point` analytics value), never
/// shown as is.
String savePointLabel(String name, AppLocalizations l10n) => switch (name) {
      'First Camp' => l10n.savePointFirstCamp,
      'Halfway Hut' => l10n.savePointHalfwayHut,
      'Mountain Spring' => l10n.savePointMountainSpring,
      'High Camp' => l10n.savePointHighCamp,
      'Summit' => l10n.savePointSummit,
      _ => name,
    };

/// Loads intl's bundled date symbols once. In the app the Material
/// localizations delegate does it for the interface locale; a screen built
/// without it (a widget test in a bare `MaterialApp`) needs it here.
/// `initializeDateFormatting` fills the symbol tables synchronously from
/// the bundled data (its future only reports completion), and
/// `flutter_localizations` ships that data already.
bool _dateSymbolsLoaded = false;
String _dateLocale(AppLocalizations l10n) {
  if (!_dateSymbolsLoaded) {
    initializeDateFormatting();
    _dateSymbolsLoaded = true;
  }
  return l10n.localeName;
}

/// A month's name ("October") in the interface language.
String monthName(int month, AppLocalizations l10n) =>
    DateFormat.MMMM(_dateLocale(l10n)).format(DateTime(2000, month));

/// A month and its year ("October 2026").
String monthYear(int year, int month, AppLocalizations l10n) =>
    DateFormat.yMMMM(_dateLocale(l10n)).format(DateTime(year, month));

/// A month and its year, short ("Oct 2026"): the medal shelf's labels.
String monthYearShort(int year, int month, AppLocalizations l10n) =>
    DateFormat.yMMM(_dateLocale(l10n)).format(DateTime(year, month));

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
