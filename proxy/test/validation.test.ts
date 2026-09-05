import { describe, expect, it } from 'vitest';
import {
  validateGenerateDailyTest,
  validateGeneratePracticeSet,
  validateScoreAnswers,
} from '../src/validation';
import { ProxyError } from '../src/types';

describe('validateGeneratePracticeSet', () => {
  const valid = { deviceId: 'abc123', topicId: 'articles', count: 5 };

  it('accepts a valid request', () => {
    expect(validateGeneratePracticeSet(valid)).toEqual(valid);
  });

  it('rejects an unrecognized topicId', () => {
    expect(() => validateGeneratePracticeSet({ ...valid, topicId: 'not_a_real_topic' })).toThrow(
      ProxyError,
    );
  });

  it('rejects a count outside 1..10', () => {
    expect(() => validateGeneratePracticeSet({ ...valid, count: 0 })).toThrow(ProxyError);
    expect(() => validateGeneratePracticeSet({ ...valid, count: 11 })).toThrow(ProxyError);
    expect(() => validateGeneratePracticeSet({ ...valid, count: 5.5 })).toThrow(ProxyError);
  });

  it('rejects a missing deviceId', () => {
    const { deviceId, ...rest } = valid;
    expect(() => validateGeneratePracticeSet(rest)).toThrow(ProxyError);
  });

  it('rejects an unexpected extra field', () => {
    expect(() => validateGeneratePracticeSet({ ...valid, admin: true })).toThrow(ProxyError);
  });

  it('rejects a non-object body', () => {
    expect(() => validateGeneratePracticeSet('just a string')).toThrow(ProxyError);
    expect(() => validateGeneratePracticeSet(null)).toThrow(ProxyError);
    expect(() => validateGeneratePracticeSet([valid])).toThrow(ProxyError);
  });
});

describe('validateGenerateDailyTest', () => {
  const valid = {
    deviceId: 'abc123',
    count: 5,
    weakSpots: [{ topicId: 'articles', frequency: 3 }],
  };

  it('accepts a valid request, including an empty weakSpots list', () => {
    expect(validateGenerateDailyTest(valid)).toEqual(valid);
    expect(validateGenerateDailyTest({ ...valid, weakSpots: [] })).toEqual({
      ...valid,
      weakSpots: [],
    });
  });

  it('rejects a weak spot with an unrecognized topicId', () => {
    expect(() =>
      validateGenerateDailyTest({ ...valid, weakSpots: [{ topicId: 'nope', frequency: 1 }] }),
    ).toThrow(ProxyError);
  });

  it('rejects a negative frequency', () => {
    expect(() =>
      validateGenerateDailyTest({ ...valid, weakSpots: [{ topicId: 'articles', frequency: -1 }] }),
    ).toThrow(ProxyError);
  });

  it('rejects an oversized weakSpots array', () => {
    const tooMany = Array.from({ length: 21 }, () => ({ topicId: 'articles', frequency: 1 }));
    expect(() => validateGenerateDailyTest({ ...valid, weakSpots: tooMany })).toThrow(ProxyError);
  });

  it('rejects an extra field on a weak spot entry', () => {
    expect(() =>
      validateGenerateDailyTest({
        ...valid,
        weakSpots: [{ topicId: 'articles', frequency: 1, errorType: 'x' }],
      }),
    ).toThrow(ProxyError);
  });
});

describe('validateScoreAnswers', () => {
  const valid = {
    deviceId: 'abc123',
    items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'I saw ___ cat.', userAnswer: 'a' }],
  };

  it('accepts a valid request', () => {
    expect(validateScoreAnswers(valid)).toEqual(valid);
  });

  it('accepts an empty userAnswer (a skipped item)', () => {
    const withSkip = {
      ...valid,
      items: [{ ...valid.items[0], userAnswer: '' }],
    };
    expect(validateScoreAnswers(withSkip)).toEqual(withSkip);
  });

  it('rejects an empty items array', () => {
    expect(() => validateScoreAnswers({ ...valid, items: [] })).toThrow(ProxyError);
  });

  it('rejects an unrecognized item type', () => {
    expect(() =>
      validateScoreAnswers({ ...valid, items: [{ ...valid.items[0], type: 'multiple_choice' }] }),
    ).toThrow(ProxyError);
  });

  it('rejects a prompt longer than the size limit', () => {
    expect(() =>
      validateScoreAnswers({
        ...valid,
        items: [{ ...valid.items[0], prompt: 'x'.repeat(2001) }],
      }),
    ).toThrow(ProxyError);
  });

  it('rejects an empty id (unlike userAnswer, this must not be blank)', () => {
    expect(() =>
      validateScoreAnswers({ ...valid, items: [{ ...valid.items[0], id: '' }] }),
    ).toThrow(ProxyError);
  });

  it('rejects more items than the size limit', () => {
    const tooMany = Array.from({ length: 21 }, (_, i) => ({
      id: `q${i}`,
      type: 'fill_in_blank',
      prompt: 'x',
      userAnswer: 'y',
    }));
    expect(() => validateScoreAnswers({ ...valid, items: tooMany })).toThrow(ProxyError);
  });
});
