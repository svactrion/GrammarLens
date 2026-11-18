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
  /**
   * A note for practice generation only: one sentence the worker adds to the
   * topic line of the practice request, after the description. It narrows
   * what the generator writes for the topic; it is not part of the topic's
   * identity, is not mirrored in the app, and is never sent to or shown in
   * it. A topic without one sends exactly the request it always did.
   */
  readonly generationNote?: string;
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

/**
 * The first-wave practice topics (UI polish SPEC §1.11; mirrors
 * `kFirstWaveTopics` in `lib/data/topics.dart`). Written but switched off:
 * with {@link FIRST_WAVE_TOPICS_ENABLED} false the worker treats their ids
 * as unknown, exactly as before they existed. They are practice topics
 * only and never part of the shared Daily Test ({@link TOPICS} stays the
 * five). Nothing here is deployed by this change.
 */
export const FIRST_WAVE_TOPICS: readonly TopicInfo[] = [
  {
    id: 'conditionals',
    title: 'Conditionals',
    description: 'If-sentences: real, unreal and past ("If it rains, we will stay").',
    // Owner decision 2026-11-18 (docs/1.5.0-topics-progress.md, T-34): the
    // first measurement's failures sat on the mixed conditional, which the
    // description and the hint card (three types) do not cover.
    generationNote:
      'Use the first, second and third conditional only; no mixed conditional (a past condition with a present result, or a present condition with a past result).',
  },
  {
    id: 'passiveVoice',
    title: 'Passive Voice',
    description: 'be + past participle when the action matters more than who did it.',
  },
  {
    id: 'prepositions',
    title: 'Prepositions',
    description: 'At, on, in for time and place, and verbs that take a preposition.',
  },
  {
    id: 'relativeClauses',
    title: 'Relative Clauses',
    description: 'Who, which, that, whose, where: joining two ideas in one sentence.',
  },
  {
    id: 'comparativesSuperlatives',
    title: 'Comparatives & Superlatives',
    description: 'Taller, more useful, the best: comparing two or more things.',
  },
];

/** The first-wave topics' switch. Off until the question-quality check
 *  and the owner's review (SPEC §1.11). */
export const FIRST_WAVE_TOPICS_ENABLED = false;

const BY_ID = new Map(TOPICS.map((t) => [t.id, t]));
const FIRST_WAVE_BY_ID = new Map(FIRST_WAVE_TOPICS.map((t) => [t.id, t]));

/** A practice topic by id: the five, plus the first wave when [firstWave]
 *  (by default {@link FIRST_WAVE_TOPICS_ENABLED}). */
export function topicById(
  id: string,
  firstWave: boolean = FIRST_WAVE_TOPICS_ENABLED,
): TopicInfo | undefined {
  return BY_ID.get(id) ?? (firstWave ? FIRST_WAVE_BY_ID.get(id) : undefined);
}

export function isKnownTopicId(
  id: unknown,
  firstWave: boolean = FIRST_WAVE_TOPICS_ENABLED,
): id is string {
  return typeof id === 'string' && topicById(id, firstWave) !== undefined;
}
