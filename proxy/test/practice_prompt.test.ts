import { describe, expect, it } from 'vitest';
import { buildBody } from '../src/anthropic';

/**
 * The practice generation prompt caps blanks per fill_in_blank item at 4
 * (the app shows one answer box per blank, at most 4; question screen plan,
 * B3). Built and tested, not deployed until the app release that ships the
 * boxes. The Daily Test stays at exactly one blank (its own prompts and the
 * shared gate), and scoring does not change.
 */
const RULE = 'A fill_in_blank item has at most 4 blanks.';

describe('the practice generation prompt', () => {
  it('caps a fill_in_blank item at 4 blanks', () => {
    const body = buildBody({
      op: 'generate_practice_set',
      request: { deviceId: 'device', topicId: 'articles', count: 5 },
    });
    expect(body.system).toContain(RULE);
  });

  it('is the only prompt with the rule: not the Daily Test, not scoring', () => {
    const daily = buildBody({ op: 'generate_daily_test', request: { deviceId: 'device', count: 5 } });
    const scoring = buildBody({ op: 'score_answers', request: { deviceId: 'device', items: [] } });
    expect(daily.system).not.toContain(RULE);
    expect(scoring.system).not.toContain(RULE);
  });
});
