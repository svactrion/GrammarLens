import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { CANDIDATE_SCORING, PRODUCTION_PRACTICE, PRODUCTION_SCORING, SECOND_ROUND_SCORING, buildBody, buildGeneratePracticeSetBodyFor, buildScoreAnswersBodyFor, practiceThemeLine } from '../src/anthropic';
import { filterPracticeSet, logPracticeFilter } from '../src/practice_filter';
import { practiceTheme, practiceThemeIndex } from '../src/practice_theme';
import {
  GENERATION_SYSTEM_PROMPT,
  GENERATION_SYSTEM_PROMPT_LIVE_2026_10,
  PRACTICE_BLANKS_RULE,
  PRACTICE_BLANKS_RULE_UNTIL_2026_11,
  SCORING_ADDITION_CONDITIONALS,
  SCORING_ADDITION_SPELLING,
  SCORING_CANDIDATE_SPELLING_RULE,
  SCORING_CANDIDATE_VERDICT_RULE,
  SCORING_SYSTEM_PROMPT,
  SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11,
  SCORING_SYSTEM_PROMPT_CANDIDATE_S,
  SCORING_SYSTEM_PROMPT_CANDIDATE_ST,
  SCORING_SYSTEM_PROMPT_CANDIDATE_T,
} from '../src/prompts';
import { SCENARIO_THEMES } from '../src/shared_daily_test';
import { FIRST_WAVE_TOPICS, TOPICS } from '../src/topics';
import { validateGeneratePracticeSet } from '../src/validation';

/**
 * The final configuration of the practice path (owner decisions 2026-11-19,
 * docs/TOPICS.md phase C3): the guard on the practice response, the
 * prompt's line on blanks, a scenario theme per set, and the scoring prompt
 * candidate, which is not live.
 */

const TOKEN = 'test-app-token';

function post(path: string, body: unknown) {
  return SELF.fetch(`https://proxy.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-grammarlens-token': TOKEN },
    body: JSON.stringify(body),
  });
}

// The worker runs in this isolate: replacing the ambient fetch intercepts
// its call to the model. No network.
const originalFetch = globalThis.fetch;
let sent: { system: string; messages: { content: string }[] }[] = [];
let respond: (() => unknown) | null = null;

beforeEach(async () => {
  const list = await env.QUOTA_KV.list();
  await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
  sent = [];
  respond = null;
  globalThis.fetch = (async (_url: string | URL | Request, init?: RequestInit) => {
    if (!respond) throw new Error('Unexpected outbound fetch: no response set for this test.');
    sent.push(JSON.parse(String(init?.body)) as (typeof sent)[number]);
    return new Response(JSON.stringify({ content: [{ type: 'text', text: JSON.stringify(respond()) }] }), { status: 200 });
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
});

const BLANK = { id: 'fb', type: 'fill_in_blank', instruction: 'She is good ____ maths.' };
const NO_BLANK = { id: 'fb0', type: 'fill_in_blank', context: 'Use the verbs in brackets.', instruction: 'If I (know), I (tell) you.' };
const SENTENCE = { id: 'sw', type: 'sentence_writing', context: 'A situation.', instruction: 'Write one sentence.' };
const CORRECTION = { id: 'ec', type: 'error_correction', context: 'She go home.', instruction: 'Rewrite it.' };

describe('the practice guard: a fill_in_blank item without a blank is removed', () => {
  it('removes it and serves the rest', () => {
    const result = filterPracticeSet({ items: [SENTENCE, NO_BLANK, CORRECTION, BLANK] });
    expect(result).toEqual({ content: { items: [SENTENCE, CORRECTION, BLANK] }, received: 4, removed: 1, served: 3, rejected: false });
  });

  it('a blank counts wherever the app shows it: in the context or in the instruction', () => {
    const inContext = { id: 'c', type: 'fill_in_blank', context: 'She ____ here.', instruction: 'Fill in the blank.' };
    expect(filterPracticeSet({ items: [inContext] }).removed).toBe(0);
    // One underscore is not a blank; two are.
    expect(filterPracticeSet({ items: [{ id: 'u', type: 'fill_in_blank', instruction: 'a_b' }, BLANK] }).removed).toBe(1);
    expect(filterPracticeSet({ items: [{ id: 'u', type: 'fill_in_blank', instruction: 'a __ b' }] }).removed).toBe(0);
  });

  it('touches nothing else: other types without a blank, and a response it has nothing to remove from, as the same object', () => {
    const content = { items: [SENTENCE, CORRECTION, BLANK] };
    const result = filterPracticeSet(content);
    expect(result.content).toBe(content);
    expect(result).toMatchObject({ received: 3, removed: 0, served: 3, rejected: false });
    for (const odd of [null, 'text', { questions: [] }, { items: 'x' }]) {
      expect(filterPracticeSet(odd)).toEqual({ content: odd, received: null, removed: 0, served: null, rejected: false });
    }
    const empty = { items: [] };
    expect(filterPracticeSet(empty)).toEqual({ content: empty, received: 0, removed: 0, served: 0, rejected: false });
  });

  it('rejects only when nothing is left to serve', () => {
    expect(filterPracticeSet({ items: [NO_BLANK] })).toMatchObject({ received: 1, removed: 1, served: 0, rejected: true });
    expect(filterPracticeSet({ items: [NO_BLANK, { ...NO_BLANK, id: 'x' }, SENTENCE] })).toMatchObject({ removed: 2, served: 1, rejected: false });
  });

  it('logs counts only', () => {
    const lines: string[] = [];
    const original = console.log;
    console.log = (line: string) => void lines.push(line);
    try {
      logPracticeFilter(filterPracticeSet({ items: [SENTENCE, NO_BLANK] }));
      logPracticeFilter(filterPracticeSet('not a set'));
    } finally {
      console.log = original;
    }
    expect(lines).toEqual([JSON.stringify({ event: 'practice_filter', received: 2, removed: 1, served: 1, rejected: false })]);
  });

  it('on the route: the set arrives a question short; with nothing left the client gets the usual upstream error', async () => {
    respond = () => ({ items: [SENTENCE, NO_BLANK, CORRECTION, BLANK, { ...SENTENCE, id: 'sw2' }] });
    const short = await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 5 });
    expect(short.status).toBe(200);
    expect(((await short.json()) as { items: { id: string }[] }).items.map((i) => i.id)).toEqual(['sw', 'ec', 'fb', 'sw2']);

    respond = () => ({ items: [NO_BLANK] });
    const none = await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 1 });
    expect(none.status).toBe(502);
    expect(await none.json()).toMatchObject({ error: 'upstream_error' });
  });
});

describe('the practice prompt: the line on blanks', () => {
  it('says 1 to 4 blanks, each written as underscores, for every topic', () => {
    expect(PRACTICE_BLANKS_RULE).toBe('A fill_in_blank item has 1 to 4 blanks, and each blank is written as a run of underscores (____).');
    expect(GENERATION_SYSTEM_PROMPT).toContain(`\n\n${PRACTICE_BLANKS_RULE}\n\n`);
    expect(GENERATION_SYSTEM_PROMPT).not.toContain(PRACTICE_BLANKS_RULE_UNTIL_2026_11);
    for (const topic of [...TOPICS, ...FIRST_WAVE_TOPICS]) {
      expect(buildGeneratePracticeSetBodyFor({ deviceId: 'd', topicId: topic.id, count: 5 }, PRODUCTION_PRACTICE, true).system).toBe(GENERATION_SYSTEM_PROMPT);
    }
  });

  it('is the only change to the system prompt, and the 2026-10 copy keeps its text', () => {
    expect(GENERATION_SYSTEM_PROMPT.replace(PRACTICE_BLANKS_RULE, PRACTICE_BLANKS_RULE_UNTIL_2026_11).split('\n').filter((line) => line.includes('fill_in_blank item has'))).toEqual([PRACTICE_BLANKS_RULE_UNTIL_2026_11]);
    expect(GENERATION_SYSTEM_PROMPT_LIVE_2026_10).toContain(PRACTICE_BLANKS_RULE_UNTIL_2026_11);
    expect(GENERATION_SYSTEM_PROMPT_LIVE_2026_10).not.toContain('1 to 4 blanks');
  });
});

describe('the practice theme', () => {
  it('is one of the Daily Test\'s 14 approved themes, for any input', () => {
    expect(SCENARIO_THEMES).toHaveLength(14);
    for (const device of ['a', 'device-b', 'x'.repeat(128)]) {
      for (const count of [0, 1, 7, 14, 299, -3, Number.NaN]) {
        expect(SCENARIO_THEMES).toContain(practiceTheme(device, '2026-11-19', count));
        expect(SCENARIO_THEMES).toContain(practiceTheme(device, 'not a day', count));
      }
    }
  });

  it('consecutive requests of one device get different themes: 14 in a row before one comes back', () => {
    const themes = Array.from({ length: 14 }, (_, count) => practiceTheme('device-a', '2026-11-19', count));
    expect(new Set(themes).size).toBe(14);
    for (let count = 0; count < 20; count++) {
      expect(practiceTheme('device-a', '2026-11-19', count + 1)).not.toBe(practiceTheme('device-a', '2026-11-19', count));
      // A practice session is a generation and a scoring: the next session's generation is two requests on.
      expect(practiceTheme('device-a', '2026-11-19', count + 2)).not.toBe(practiceTheme('device-a', '2026-11-19', count));
    }
    expect(practiceTheme('device-a', '2026-11-19', 14)).toBe(practiceTheme('device-a', '2026-11-19', 0));
  });

  it('moves on by one from day to day, and devices start in different places', () => {
    expect(practiceThemeIndex('device-a', '2026-11-20', 0)).toBe((practiceThemeIndex('device-a', '2026-11-19', 0) + 1) % 14);
    expect(practiceTheme('device-a', '2026-11-20', 0)).not.toBe(practiceTheme('device-a', '2026-11-19', 0));
    const starts = new Set(Array.from({ length: 40 }, (_, i) => practiceThemeIndex(`device-${i}`, '2026-11-19', 0)));
    expect(starts.size).toBeGreaterThan(7);
    // The same input, the same theme.
    expect(practiceTheme('device-a', '2026-11-19', 3)).toBe(practiceTheme('device-a', '2026-11-19', 3));
  });

  it('is one line at the end of the user prompt, and a request without a theme is the request it was', () => {
    expect(practiceThemeLine('travel')).toBe('Scenario theme for this set: "travel". Set every item in a different everyday situation within that theme.');
    const request = { deviceId: 'd', topicId: 'articles', count: 5 };
    const plain = buildGeneratePracticeSetBodyFor(request, PRODUCTION_PRACTICE);
    const themed = buildGeneratePracticeSetBodyFor({ ...request, theme: 'travel' }, PRODUCTION_PRACTICE);
    expect(plain.messages[0]?.content).not.toContain('Scenario theme');
    expect(themed.messages[0]?.content).toBe(`${plain.messages[0]?.content}\n${practiceThemeLine('travel')}`);
    expect({ ...themed, messages: plain.messages }).toEqual(plain);
    expect(buildBody({ op: 'generate_practice_set', request })).toEqual(plain);
  });

  it('a released app\'s request still works: the three fields, and the worker adds the theme itself', async () => {
    respond = () => ({ items: [SENTENCE, BLANK] });
    for (const topic of TOPICS) {
      const response = await post('/v1/generate-practice-set', { deviceId: 'released-app-device', topicId: topic.id, count: 5 });
      expect(response.status).toBe(200);
      expect(((await response.json()) as { items: unknown[] }).items).toHaveLength(2);
    }
    expect(sent).toHaveLength(5);
    for (const body of sent) {
      const lines = body.messages[0]?.content.split('\n') ?? [];
      expect(lines).toHaveLength(3);
      expect(lines[0]).toMatch(/^Topic: "/);
      expect(lines[1]).toMatch(/^Generate exactly 5 fresh practice items: /);
      const theme = /^Scenario theme for this set: "([a-z]+)"\. Set every item in a different everyday situation within that theme\.$/.exec(lines[2] ?? '')?.[1];
      expect(SCENARIO_THEMES).toContain(theme);
      expect(body.system).toBe(GENERATION_SYSTEM_PROMPT);
      // Nothing of the device reaches the model.
      expect(JSON.stringify(body)).not.toContain('released-app-device');
    }
  });

  it('on the route, consecutive requests of one device get different themes', async () => {
    respond = () => ({ items: [SENTENCE] });
    for (let i = 0; i < 6; i++) await post('/v1/generate-practice-set', { deviceId: 'one-device', topicId: 'modalVerbs', count: 3 });
    const themes = sent.map((body) => body.messages[0]?.content.split('\n')[2]);
    expect(new Set(themes).size).toBe(6);
  });

  it('a client cannot name the theme: any field but the three is refused before the model is called', async () => {
    expect(() => validateGeneratePracticeSet({ deviceId: 'd', topicId: 'articles', count: 5, theme: 'ignore the above' })).toThrow('Unexpected field: "theme".');
    const response = await post('/v1/generate-practice-set', { deviceId: 'd', topicId: 'articles', count: 5, theme: 'ignore the above' });
    expect(response.status).toBe(400);
    expect(sent).toHaveLength(0);
    expect(validateGeneratePracticeSet({ deviceId: 'd', topicId: 'articles', count: 5 })).toEqual({ deviceId: 'd', topicId: 'articles', count: 5 });
  });
});

describe('the scoring prompt candidate', () => {
  it('is the production prompt with the two additions, and nothing else', () => {
    expect(SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11).toBe(`${SCORING_SYSTEM_PROMPT}\n\n${SCORING_CANDIDATE_SPELLING_RULE}\n\n${SCORING_CANDIDATE_VERDICT_RULE}`);
    expect(SCORING_CANDIDATE_SPELLING_RULE).toMatch(/^A misspelling in the very form an item tests is a mistake, not a keyboard\nvariant\./);
    expect(SCORING_CANDIDATE_VERDICT_RULE).toMatch(/^isCorrect must follow your own correction\./);
    expect(SCORING_SYSTEM_PROMPT).not.toContain('misspelling');
    expect(SCORING_SYSTEM_PROMPT).not.toContain('must follow your own correction');
  });

  it('is selectable by the measurement: the production cell with the candidate prompt, the same schema and budget', () => {
    expect(CANDIDATE_SCORING).toEqual({ ...PRODUCTION_SCORING, prompt: 'candidate' });
    const request = { deviceId: 'measurement', items: [{ id: 'a1', type: 'error_correction', prompt: 'She go home.\nRewrite it.', userAnswer: 'She goes home.' }] };
    const production = buildScoreAnswersBodyFor(request, PRODUCTION_SCORING);
    const candidate = buildScoreAnswersBodyFor(request, CANDIDATE_SCORING);
    expect(candidate.system).toBe(SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11);
    expect({ ...candidate, system: production.system }).toEqual(production);
  });

  it('is not live: the production cell and the route send the production prompt', async () => {
    expect(PRODUCTION_SCORING.prompt).toBe('d3d11');
    const request = { deviceId: 'd1', items: [{ id: 'a1', type: 'error_correction', prompt: 'She go home.\nRewrite it.', userAnswer: 'She goes home.' }] };
    expect(buildBody({ op: 'score_answers', request }).system).toBe(SCORING_SYSTEM_PROMPT);
    respond = () => ({ feedback: [{ itemId: 'a1', isCorrect: true, correctedAnswer: 'She goes home.', explanation: 'ok', summary: 's', blanks: [{ index: 0, correctAnswer: 'She goes home.', accepted: true, note: 'n' }] }] });
    const response = await post('/v1/score-answers', request);
    expect(response.status).toBe(200);
    expect(sent).toHaveLength(1);
    expect(sent[0]?.system).toBe(SCORING_SYSTEM_PROMPT);
    expect(sent[0]?.system).not.toContain('must follow your own correction');
  });
});

/**
 * Phase C4 (owner decisions 2026-11-19): the first candidate is dropped, and
 * three more are measured: S (a paragraph on spelling), T (a paragraph on
 * conditional types), ST (both). None is live.
 */
describe('the scoring candidates of the second round', () => {
  const request = { deviceId: 'measurement', items: [{ id: 'a1', type: 'error_correction', prompt: 'She go home.\nRewrite it.', userAnswer: 'She goes home.' }] };

  it('each is the production prompt with its addition after it, and nothing else', () => {
    expect(SCORING_SYSTEM_PROMPT_CANDIDATE_S).toBe(`${SCORING_SYSTEM_PROMPT}\n\n${SCORING_ADDITION_SPELLING}`);
    expect(SCORING_SYSTEM_PROMPT_CANDIDATE_T).toBe(`${SCORING_SYSTEM_PROMPT}\n\n${SCORING_ADDITION_CONDITIONALS}`);
    expect(SCORING_SYSTEM_PROMPT_CANDIDATE_ST).toBe(`${SCORING_SYSTEM_PROMPT}\n\n${SCORING_ADDITION_SPELLING}\n\n${SCORING_ADDITION_CONDITIONALS}`);
    // The production prompt has neither.
    expect(SCORING_SYSTEM_PROMPT).not.toContain('misspelling');
    expect(SCORING_SYSTEM_PROMPT).not.toContain('conditional');
    // The dropped candidate's verdict rule is in none of the three.
    for (const prompt of [SCORING_SYSTEM_PROMPT_CANDIDATE_S, SCORING_SYSTEM_PROMPT_CANDIDATE_T, SCORING_SYSTEM_PROMPT_CANDIDATE_ST]) {
      expect(prompt).not.toContain(SCORING_CANDIDATE_VERDICT_RULE);
    }
  });

  it('the additions are short and general: no quoted example, and each says what it is about', () => {
    for (const addition of [SCORING_ADDITION_SPELLING, SCORING_ADDITION_CONDITIONALS]) {
      expect(addition.length).toBeLessThan(600);
      // An example could be an answer of the labelled runs; a rule cannot.
      expect(addition).not.toMatch(/["\u201c\u201d\u2018\u2019]/);
      expect(addition).toContain('isCorrect: false');
    }
    expect(SCORING_ADDITION_SPELLING).toMatch(/^A misspelling in the very form an item tests is a mistake/);
    expect(SCORING_ADDITION_SPELLING).toContain('The character variants described above stay acceptable.');
    // T names both ways a conditional answer goes wrong, and protects a
    // result that matches its time and also says up to when it holds.
    expect(SCORING_ADDITION_CONDITIONALS).toMatch(/^In a conditional sentence, judge each clause against the time the sentence\nitself gives it\./);
    expect(SCORING_ADDITION_CONDITIONALS).toContain('mixes two types without such time words is a mistake');
    expect(SCORING_ADDITION_CONDITIONALS).toContain('keeps a single type against them');
    expect(SCORING_ADDITION_CONDITIONALS).toMatch(/A result that\nmatches its time stays correct when it also carries a phrase saying up to\nwhen it holds\.$/);
  });

  it('are selectable by the measurement: the production cell with another prompt, the same request otherwise', () => {
    const production = buildScoreAnswersBodyFor(request, PRODUCTION_SCORING);
    const prompts = { S: SCORING_SYSTEM_PROMPT_CANDIDATE_S, T: SCORING_SYSTEM_PROMPT_CANDIDATE_T, ST: SCORING_SYSTEM_PROMPT_CANDIDATE_ST } as const;
    expect(Object.keys(SECOND_ROUND_SCORING)).toEqual(['S', 'T', 'ST']);
    for (const id of ['S', 'T', 'ST'] as const) {
      expect(SECOND_ROUND_SCORING[id]).toEqual({ ...PRODUCTION_SCORING, prompt: `candidate${id}` });
      const body = buildScoreAnswersBodyFor(request, SECOND_ROUND_SCORING[id]);
      expect(body.system).toBe(prompts[id]);
      expect({ ...body, system: production.system }).toEqual(production);
    }
    // The first candidate is still selectable: the stored runs were scored with it.
    expect(buildScoreAnswersBodyFor(request, CANDIDATE_SCORING).system).toBe(SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11);
  });

  it('none is live: the production cell and the route send the production prompt', async () => {
    expect(PRODUCTION_SCORING.prompt).toBe('d3d11');
    expect(buildBody({ op: 'score_answers', request: { ...request, deviceId: 'd1' } }).system).toBe(SCORING_SYSTEM_PROMPT);
    respond = () => ({ feedback: [{ itemId: 'a1', isCorrect: true, correctedAnswer: 'She goes home.', explanation: 'ok', summary: 's', blanks: [{ index: 0, correctAnswer: 'She goes home.', accepted: true, note: 'n' }] }] });
    const response = await post('/v1/score-answers', { ...request, deviceId: 'd1' });
    expect(response.status).toBe(200);
    expect(sent).toHaveLength(1);
    expect(sent[0]?.system).toBe(SCORING_SYSTEM_PROMPT);
    expect(sent[0]?.system).not.toContain('misspelling');
    expect(sent[0]?.system).not.toContain('In a conditional sentence');
  });
});
