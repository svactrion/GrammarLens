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

/// The first-wave practice topics (UI polish SPEC §1.11): written, with
/// their hint cards and the proxy's handling, but switched off until the
/// question-quality check and the owner's review. Never part of the Daily
/// Test (which keeps [kTopics]).
const List<Topic> kFirstWaveTopics = [
  Topic(id: TopicId.conditionals, icon: Icons.call_split_rounded),
  Topic(id: TopicId.passiveVoice, icon: Icons.swap_horiz_rounded),
  Topic(id: TopicId.prepositions, icon: Icons.place_outlined),
  Topic(id: TopicId.relativeClauses, icon: Icons.link_rounded),
  Topic(id: TopicId.comparativesSuperlatives, icon: Icons.bar_chart_rounded),
];

/// The first-wave topics' switch: off. Turning it on shows them in Topic
/// Practice and on Home; the proxy has its own switch
/// (`FIRST_WAVE_TOPICS_ENABLED` in `proxy/src/topics.ts`), also off.
const bool kFirstWaveTopicsEnabled = false;

/// The topics Topic Practice offers: [kTopics], plus [kFirstWaveTopics]
/// when [firstWave] (by default [kFirstWaveTopicsEnabled]).
List<Topic> practiceTopics({bool firstWave = kFirstWaveTopicsEnabled}) =>
    [...kTopics, if (firstWave) ...kFirstWaveTopics];

Topic topicById(TopicId id) =>
    [...kTopics, ...kFirstWaveTopics].firstWhere((t) => t.id == id);

/// The topic whose [TopicId.name] is [name] (how topic ids are stored:
/// `DailyTestQuestion.topicId`, `PracticeSet.topicId`), or null for a name
/// that is not one of [kTopics].
Topic? topicByName(String name) {
  final id = TopicId.values.asNameMap()[name];
  return id == null ? null : topicById(id);
}
