/**
 * Mirrors `lib/data/topics.dart`'s `kTopics` exactly (id, title,
 * description). Duplicated here on purpose rather than shared: the worker
 * is a separate deployable with no access to the Dart source, and the
 * client is only ever allowed to send a `topicId` — never a title or
 * description string of its own — so prompt text can't be injected through
 * this field. The worker looks up the real title/description from this
 * fixed table instead of trusting anything the client sends beyond the id.
 */
export interface TopicInfo {
  readonly id: string;
  readonly title: string;
  readonly description: string;
}

export const TOPICS: readonly TopicInfo[] = [
  {
    id: 'gerundVsInfinitive',
    title: 'Gerund vs. Infinitive',
    description: 'Knowing when it\'s "I enjoy swimming" vs. "I want to swim".',
  },
  {
    id: 'modalVerbs',
    title: 'Modal Verbs',
    description: 'Can, could, must, should, might, and the nuance between them.',
  },
  {
    id: 'modalPastForms',
    title: 'Modal Past Forms',
    description: 'Past and reported contexts: will → would, can → could.',
  },
  {
    id: 'tenseSelection',
    title: 'Tense Selection',
    description: 'Choosing the right tense for the situation.',
  },
  {
    id: 'articles',
    title: 'Articles',
    description: 'A, an, the — and when to use none at all.',
  },
];

const BY_ID = new Map(TOPICS.map((t) => [t.id, t]));

export function topicById(id: string): TopicInfo | undefined {
  return BY_ID.get(id);
}

export function isKnownTopicId(id: unknown): id is string {
  return typeof id === 'string' && BY_ID.has(id);
}
