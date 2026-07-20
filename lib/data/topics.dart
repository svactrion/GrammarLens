import '../models/topic.dart';

/// The MVP's fixed topic list (PRD §5). Self-selected by the user — no
/// placement test.
const List<Topic> kTopics = [
  Topic(
    id: TopicId.gerundVsInfinitive,
    title: 'Gerund vs. Infinitive',
    description: 'Knowing when it\'s "I enjoy swimming" vs. "I want to swim".',
  ),
  Topic(
    id: TopicId.modalVerbs,
    title: 'Modal Verbs',
    description: 'Can, could, must, should, might, and the nuance between them.',
  ),
  Topic(
    id: TopicId.modalPastForms,
    title: 'Modal Past Forms',
    description: 'Past and reported contexts: will → would, can → could.',
  ),
  Topic(
    id: TopicId.tenseSelection,
    title: 'Tense Selection',
    description: 'Choosing the right tense for the situation.',
  ),
  Topic(
    id: TopicId.articles,
    title: 'Articles',
    description: 'A, an, the — and when to use none at all.',
  ),
];

Topic topicById(TopicId id) => kTopics.firstWhere((t) => t.id == id);
