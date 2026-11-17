import { describe, expect, it } from 'vitest';
import {
  FIRST_WAVE_TOPICS,
  FIRST_WAVE_TOPICS_ENABLED,
  TOPICS,
  isKnownTopicId,
  topicById,
} from '../src/topics';

// UI polish SPEC §1.11: the first-wave practice topics are written but
// switched off; the Daily Test keeps the five.
describe('first-wave topics', () => {
  const ids = FIRST_WAVE_TOPICS.map((t) => t.id);

  it('are the five planned topics, none of them a Daily Test topic', () => {
    expect(ids).toEqual([
      'conditionals',
      'passiveVoice',
      'prepositions',
      'relativeClauses',
      'comparativesSuperlatives',
    ]);
    expect(TOPICS.map((t) => t.id)).toEqual([
      'gerundVsInfinitive',
      'modalVerbs',
      'modalPastForms',
      'tenseSelection',
      'articles',
    ]);
  });

  it('are switched off by default', () => {
    expect(FIRST_WAVE_TOPICS_ENABLED).toBe(false);
  });

  it('flag off: unknown to the worker, exactly as before', () => {
    for (const id of ids) {
      expect(isKnownTopicId(id)).toBe(false);
      expect(topicById(id)).toBeUndefined();
      expect(isKnownTopicId(id, false)).toBe(false);
    }
    // The five are unaffected.
    for (const t of TOPICS) {
      expect(isKnownTopicId(t.id)).toBe(true);
      expect(topicById(t.id)).toEqual(t);
    }
  });

  it('flag on: known, with their own title and description', () => {
    for (const t of FIRST_WAVE_TOPICS) {
      expect(isKnownTopicId(t.id, true)).toBe(true);
      expect(topicById(t.id, true)).toEqual(t);
      expect(t.title.length).toBeGreaterThan(0);
      expect(t.description.length).toBeGreaterThan(0);
    }
    expect(isKnownTopicId('notATopic', true)).toBe(false);
  });
});
