import 'package:flutter/material.dart';

import '../models/topic.dart';

/// The MVP's fixed topic list (PRD §5). Self-selected by the user — no
/// placement test. Titles and descriptions are in the strings
/// (`topic.title(l10n)`).
const List<Topic> kTopics = [
  Topic(
    id: TopicId.gerundVsInfinitive,
    // Two forms to choose between for the same idea.
    icon: Icons.compare_arrows,
  ),
  Topic(
    id: TopicId.modalVerbs,
    // Modals express the speaker's mental stance toward possibility/necessity.
    icon: Icons.psychology,
  ),
  Topic(
    id: TopicId.modalPastForms,
    icon: Icons.history,
  ),
  Topic(
    id: TopicId.tenseSelection,
    icon: Icons.access_time,
  ),
  Topic(
    id: TopicId.articles,
    icon: Icons.abc,
  ),
];

Topic topicById(TopicId id) => kTopics.firstWhere((t) => t.id == id);

/// The topic whose [TopicId.name] is [name] (how topic ids are stored:
/// `DailyTestQuestion.topicId`, `PracticeSet.topicId`), or null for a name
/// that is not one of [kTopics].
Topic? topicByName(String name) {
  final id = TopicId.values.asNameMap()[name];
  return id == null ? null : topicById(id);
}
