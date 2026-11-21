import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { SCORING_SYSTEM_PROMPT } from '../src/prompts';
import { SCORE_RETRY_MAX_FIRST_MS, isCompleteScore, scoreVerdictGaps } from '../src/score_retry';
import { FIRST_WAVE_TOPICS, TOPICS } from '../src/topics';

/**
 * Phase D of docs/TOPICS.md (owner decisions 2026-11-19): the scoring route
 * asks the scorer once more when a response leaves an answer without a
 * usable verdict, and the practice route accepts the five first-wave ids.
 * The worker runs in this isolate; its call to the model is intercepted. No
 * network.
 */

const TOKEN = 'test-app-token';

function post(path: string, body: unknown) {
  return SELF.fetch(`https://proxy.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-grammarlens-token': TOKEN },
    body: JSON.stringify(body),
  });
}

const originalFetch = globalThis.fetch;
const originalConsole = { log: console.log, info: console.info, warn: console.warn, error: console.error };
const realNow = Date.now;
let logged: string[] = [];
let sent: { system: string; messages: { content: string }[] }[] = [];
/** What the model answers, call by call; the last one repeats. */
let answers: unknown[] = [];
/** Fake wall time each call to the model takes. */
let callMs = 0;
let clock = 0;

beforeEach(async () => {
  const list = await env.QUOTA_KV.list();
  await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
  logged = [];
  sent = [];
  answers = [];
  callMs = 0;
  clock = realNow();
  Date.now = () => clock;
  for (const level of ['log', 'info', 'warn', 'error'] as const) {
    console[level] = (...args: unknown[]) => {
      logged.push(args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' '));
    };
  }
  globalThis.fetch = (async (_url: string | URL | Request, init?: RequestInit) => {
    if (answers.length === 0) throw new Error('Unexpected outbound fetch: no response set for this test.');
    sent.push(JSON.parse(String(init?.body)) as (typeof sent)[number]);
    clock += callMs;
    const payload = answers[Math.min(sent.length, answers.length) - 1];
    return new Response(JSON.stringify({ content: [{ type: 'text', text: JSON.stringify(payload) }] }), { status: 200 });
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  Date.now = realNow;
  Object.assign(console, originalConsole);
});

const lines = (event: string) => logged.filter((l) => l.includes(`"event":"${event}"`)).map((l) => JSON.parse(l) as Record<string, unknown>);

const REQUEST = {
  deviceId: 'd1',
  items: [
    { id: 'a1', type: 'error_correction', prompt: 'She go home.\nRewrite it.', userAnswer: 'She goes home.' },
    { id: 'a2', type: 'sentence_writing', prompt: 'A situation.\nWrite one sentence.', userAnswer: 'I would go.' },
    { id: 'a3', type: 'fill_in_blank', prompt: 'She is good ____ maths.', userAnswer: '' },
  ],
};
const entry = (itemId: string, isCorrect = true) => ({ itemId, isCorrect, correctedAnswer: 'x', explanation: 'y' });
const COMPLETE = { feedback: [entry('a1'), entry('a2'), entry('a3', false)] };
/** The two shapes the measurement met. */
const ONE_OF_THREE = { feedback: [entry('a1')] };
const UNASKED_ID = { feedback: [entry('a1'), entry('a2'), entry('a9')] };

describe('a usable verdict for every answer', () => {
  it('complete: each requested id once, with a verdict, in any order', () => {
    expect(scoreVerdictGaps(REQUEST, COMPLETE)).toEqual({ requested: 3, missing: 0, extra: 0 });
    expect(isCompleteScore(scoreVerdictGaps(REQUEST, { feedback: [entry('a3'), entry('a1'), entry('a2')] }))).toBe(true);
  });

  it('counts the answers left out and the entries that belong to no answer', () => {
    expect(scoreVerdictGaps(REQUEST, ONE_OF_THREE)).toEqual({ requested: 3, missing: 2, extra: 0 });
    expect(scoreVerdictGaps(REQUEST, UNASKED_ID)).toEqual({ requested: 3, missing: 1, extra: 1 });
    // A second entry for an id, an entry without a verdict, and something that is not an entry.
    expect(scoreVerdictGaps(REQUEST, { feedback: [...COMPLETE.feedback, entry('a1')] })).toEqual({ requested: 3, missing: 0, extra: 1 });
    expect(scoreVerdictGaps(REQUEST, { feedback: [entry('a1'), entry('a2'), { itemId: 'a3', isCorrect: 'yes' }] })).toEqual({ requested: 3, missing: 1, extra: 1 });
    expect(scoreVerdictGaps(REQUEST, { feedback: [...COMPLETE.feedback, null, 'text'] })).toEqual({ requested: 3, missing: 0, extra: 2 });
    for (const gaps of [ONE_OF_THREE, UNASKED_ID].map((c) => scoreVerdictGaps(REQUEST, c))) expect(isCompleteScore(gaps)).toBe(false);
  });

  it('a response that is not {feedback: [...]} answers nothing', () => {
    for (const content of [null, 'text', [], {}, { feedback: 'none' }]) {
      expect(scoreVerdictGaps(REQUEST, content)).toEqual({ requested: 3, missing: 3, extra: 0 });
    }
  });
});

describe('POST /v1/score-answers: an incomplete response is asked for once more', () => {
  it('a complete response is served from one call, with no line about it', async () => {
    answers = [COMPLETE];
    const response = await post('/v1/score-answers', REQUEST);
    expect(response.status).toBe(200);
    expect(((await response.json()) as { feedback: { itemId: string }[] }).feedback.map((f) => f.itemId)).toEqual(['a1', 'a2', 'a3']);
    expect(sent).toHaveLength(1);
    expect(lines('score_incomplete')).toEqual([]);
  });

  it.each([
    ['feedback for one of three answers', ONE_OF_THREE, { missing: 2, extra: 0 }],
    ['feedback under an id that was not asked', UNASKED_ID, { missing: 1, extra: 1 }],
  ])('%s: the second call\'s complete response is what the app gets', async (_name, incomplete, counts) => {
    answers = [incomplete, COMPLETE];
    const response = await post('/v1/score-answers', REQUEST);
    expect(response.status).toBe(200);
    const body = (await response.json()) as { feedback: { itemId: string }[] };
    expect(body.feedback.map((f) => f.itemId)).toEqual(['a1', 'a2', 'a3']);
    // The same request twice: the production scoring prompt, the same answers.
    expect(sent).toHaveLength(2);
    expect(sent[1]).toEqual(sent[0]);
    expect(sent[0]?.system).toBe(SCORING_SYSTEM_PROMPT);
    expect(lines('score_incomplete')).toEqual([{ event: 'score_incomplete', attempt: 1, requested: 3, ...counts, outcome: 'retry' }]);
    // The feedback check logs what was served, once.
    expect(lines('score_feedback')).toHaveLength(1);
  });

  it('incomplete twice: the usual upstream error, and no third call', async () => {
    answers = [ONE_OF_THREE, UNASKED_ID];
    const response = await post('/v1/score-answers', REQUEST);
    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({ error: 'upstream_error', message: 'The upstream service returned an unexpected response.' });
    expect(sent).toHaveLength(2);
    expect(lines('score_incomplete')).toEqual([
      { event: 'score_incomplete', attempt: 1, requested: 3, missing: 2, extra: 0, outcome: 'retry' },
      { event: 'score_incomplete', attempt: 2, requested: 3, missing: 1, extra: 1, outcome: 'failed' },
    ]);
    expect(lines('score_feedback')).toEqual([]);
  });

  it('a first call too slow for a second to reach the app in time is not repeated', async () => {
    answers = [ONE_OF_THREE, COMPLETE];
    callMs = SCORE_RETRY_MAX_FIRST_MS + 1;
    const late = await post('/v1/score-answers', REQUEST);
    expect(late.status).toBe(502);
    expect(sent).toHaveLength(1);
    expect(lines('score_incomplete')).toEqual([{ event: 'score_incomplete', attempt: 1, requested: 3, missing: 2, extra: 0, outcome: 'failed_no_time' }]);
    // Just inside the limit it is.
    sent = [];
    callMs = SCORE_RETRY_MAX_FIRST_MS;
    const inTime = await post('/v1/score-answers', { ...REQUEST, deviceId: 'd2' });
    expect(inTime.status).toBe(200);
    expect(sent).toHaveLength(2);
  });

  it('the device\'s quota is counted once, whether or not the scorer is asked twice', async () => {
    const count = async () => {
      const keys = (await env.QUOTA_KV.list()).keys.map((k) => k.name);
      return Promise.all(keys.map(async (name) => [name.replace(/\d{4}-\d{2}-\d{2}/, 'DAY'), await env.QUOTA_KV.get(name)]));
    };
    answers = [COMPLETE];
    await post('/v1/score-answers', REQUEST);
    const once = await count();
    const list = await env.QUOTA_KV.list();
    await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
    sent = [];
    answers = [ONE_OF_THREE, COMPLETE];
    await post('/v1/score-answers', REQUEST);
    expect(sent).toHaveLength(2);
    expect(await count()).toEqual(once);
  });

  it('the line holds counts only: no id, no prompt, no answer, no text of the response', async () => {
    const secret = { device: 'DEVICE-SECRET-8841', answer: 'ANSWER-SECRET-5520', prompt: 'PROMPT-SECRET-3307', id: 'ID-SECRET-1209', text: 'GENERATED-SECRET-7712' };
    answers = [{ feedback: [{ itemId: 'ID-OTHER-4411', isCorrect: true, correctedAnswer: secret.text, explanation: secret.text }] }];
    const response = await post('/v1/score-answers', { deviceId: secret.device, items: [{ id: secret.id, type: 'sentence_writing', prompt: secret.prompt, userAnswer: secret.answer }] });
    expect(response.status).toBe(502);
    expect(lines('score_incomplete')).toHaveLength(2);
    for (const line of lines('score_incomplete')) expect(Object.keys(line).sort()).toEqual(['attempt', 'event', 'extra', 'missing', 'outcome', 'requested']);
    const all = logged.join('\n');
    for (const value of [...Object.values(secret), 'ID-OTHER-4411']) expect(all).not.toContain(value);
  });
});

describe('POST /v1/generate-practice-set: the first-wave topics are accepted', () => {
  const SET = {
    items: [
      { id: 'sw', type: 'sentence_writing', context: 'A situation.', instruction: 'Write one sentence.' },
      { id: 'ec', type: 'error_correction', context: 'She go home.', instruction: 'Rewrite it.' },
      { id: 'fb', type: 'fill_in_blank', instruction: 'She is good ____ maths.' },
    ],
  };

  it('each of the five ids gets a set, generated from its own topic line', async () => {
    answers = [SET];
    for (const [i, topic] of FIRST_WAVE_TOPICS.entries()) {
      const response = await post('/v1/generate-practice-set', { deviceId: `device-${i}`, topicId: topic.id, count: 3 });
      expect(response.status).toBe(200);
      expect(await response.json()).toEqual(SET);
      const prompt = sent[i]?.messages[0]?.content ?? '';
      expect(prompt.startsWith(`Topic: "${topic.title}" — ${topic.description}`)).toBe(true);
      // The final configuration: a scenario theme at the end of the request.
      expect(prompt.split('\n').at(-1)).toMatch(/^Scenario theme/);
    }
    expect(sent).toHaveLength(5);
    // Conditionals carries its generation note (three types, no mixed conditional).
    expect(sent[0]?.messages[0]?.content).toContain('no mixed conditional');
  });

  it('the five live ids work as before, and an id that is no topic is refused before the model is called', async () => {
    answers = [SET];
    for (const [i, topic] of TOPICS.entries()) {
      expect((await post('/v1/generate-practice-set', { deviceId: `live-${i}`, topicId: topic.id, count: 3 })).status).toBe(200);
    }
    sent = [];
    const response = await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'phrasalVerbs', count: 3 });
    expect(response.status).toBe(400);
    expect(await response.json()).toMatchObject({ error: 'invalid_request' });
    expect(sent).toHaveLength(0);
  });

  it('the Daily Test keeps its five topics', () => {
    expect(TOPICS.map((t) => t.id)).toEqual(['gerundVsInfinitive', 'modalVerbs', 'modalPastForms', 'tenseSelection', 'articles']);
    expect(TOPICS.some((t) => FIRST_WAVE_TOPICS.some((f) => f.id === t.id))).toBe(false);
  });
});
