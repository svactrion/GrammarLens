import 'package:flutter/material.dart';

import '../models/topic.dart';

/// The MVP's fixed topic list (PRD §5). Self-selected by the user — no
/// placement test.
const List<Topic> kTopics = [
  Topic(
    id: TopicId.gerundVsInfinitive,
    title: 'Gerund vs. Infinitive',
    description: 'Knowing when it\'s "I enjoy swimming" vs. "I want to swim".',
    // Two forms to choose between for the same idea.
    icon: Icons.compare_arrows,
  ),
  Topic(
    id: TopicId.modalVerbs,
    title: 'Modal Verbs',
    description: 'Can, could, must, should, might, and the nuance between them.',
    // Modals express the speaker's mental stance toward possibility/necessity.
    icon: Icons.psychology,
  ),
  Topic(
    id: TopicId.modalPastForms,
    title: 'Modal Past Forms',
    description: 'Past and reported contexts: will → would, can → could.',
    icon: Icons.history,
  ),
  Topic(
    id: TopicId.tenseSelection,
    title: 'Tense Selection',
    description: 'Choosing the right tense for the situation.',
    icon: Icons.access_time,
  ),
  Topic(
    id: TopicId.articles,
    title: 'Articles',
    description: 'A, an, the — and when to use none at all.',
    icon: Icons.abc,
  ),
];

Topic topicById(TopicId id) => kTopics.firstWhere((t) => t.id == id);
