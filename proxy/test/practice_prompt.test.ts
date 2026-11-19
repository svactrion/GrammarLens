import { describe, expect, it } from 'vitest';
import { buildBody } from '../src/anthropic';

/**
 * The practice generation prompt asks for 1 to 4 blanks per fill_in_blank
 * item, each written as underscores (the app shows one answer box per blank,
 * at most 4; question screen plan, B3). Until 2026-11 the line said "at most
 * 4 blanks" and the topics measurement met items with none (owner decision
 * 2026-11-19, docs/TOPICS.md phase C3); built, not deployed. The Daily Test
 * stays at exactly one blank (its own prompts and the shared gate), and
 * scoring does not change.
 */
const RULE = 'A fill_in_blank item has 1 to 4 blanks, and each blank is written as a run of underscores (____).';

describe('the practice generation prompt', () => {
  it('asks for 1 to 4 blanks per fill_in_blank item, written as underscores', () => {
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
