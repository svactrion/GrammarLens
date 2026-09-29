import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { filterLegacyDailyTest, LEGACY_MIN_QUESTIONS } from '../src/legacy_daily_test';
import { validateSharedSet, type DailyPlan } from '../src/shared_daily_test';
import { LEGACY_DAILY_TEST_BODY_COUNT_5 } from './fixtures/legacy_daily_test_body';

/**
 * The legacy route's response check (docs/1.1.0-shared-daily-test-quality.md
 * §14.4 item 5, option L3, owner decision 2026-09-28): `error_correction`
 * questions without a sentence to correct are dropped before the set reaches
 * a 1.0.0 device; fewer than 3 left is the existing upstream error. The
 * request to Anthropic never changes.
 */

const TOKEN = 'test-app-token'; // matches vitest.config.ts's miniflare.bindings

function post(body: unknown) {
  return SELF.fetch('https://proxy.example/v1/generate-daily-test', {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-grammarlens-token': TOKEN },
    body: JSON.stringify(body),
  });
}

const originalFetch = globalThis.fetch;
const originalConsole = { log: console.log, info: console.info, warn: console.warn, error: console.error };
let logged: string[] = [];
let requestBodies: string[] = [];

function anthropicResponds(payload: unknown) {
  globalThis.fetch = (async (_url: unknown, init?: RequestInit) => {
    requestBodies.push(String(init?.body));
    return new Response(
      JSON.stringify({
        content: [{ type: 'text', text: JSON.stringify(payload) }],
        usage: { input_tokens: 1173, output_tokens: 1500 },
        stop_reason: 'end_turn',
      }),
      { status: 200 },
    );
  }) as typeof fetch;
}

function filterLines(): Record<string, unknown>[] {
  return logged
    .filter((line) => line.includes('legacy_daily_test_filter'))
    .map((line) => JSON.parse(line) as Record<string, unknown>);
}

beforeEach(async () => {
  const list = await env.QUOTA_KV.list();
  await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
  logged = [];
  requestBodies = [];
  for (const level of ['log', 'info', 'warn', 'error'] as const) {
    console[level] = (...args: unknown[]) => {
      logged.push(args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' '));
    };
  }
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  Object.assign(console, originalConsole);
});

type Question = Record<string, unknown>;

/** A legacy-shaped question; [context] `undefined` leaves the field out. */
function q(id: string, type: 'fill_in_blank' | 'error_correction', context: string | undefined): Question {
  return {
    id,
    type,
    ...(context === undefined ? {} : { context }),
    instruction: type === 'error_correction' ? 'Correct the one grammar error in this sentence.' : 'Fill in the blank.',
    topicId: 'tenseSelection',
    correctAnswer: type === 'error_correction' ? 'She has lived here since 2019.' : 'has',
    explanation: 'Since takes the present perfect.',
    commonWrongAnswers: [
      { answer: 'lives', comment: 'c1' },
      { answer: 'is living', comment: 'c2' },
    ],
  };
}

/** 5 questions, of which the first [missing] error_correction ones have no sentence. */
function set(missing: number): Question[] {
  const ec = [0, 1, 2].map((i) => q(`ec${i}`, 'error_correction', i < missing ? undefined : 'She live here since 2019.'));
  return [q('f0', 'fill_in_blank', 'She ___ here since 2019.'), ec[0], q('f1', 'fill_in_blank', undefined), ec[1], ec[2]] as Question[];
}

describe('legacy Daily Test response check (L3)', () => {
  it.each([
    [0, ['f0', 'ec0', 'f1', 'ec1', 'ec2']],
    [1, ['f0', 'f1', 'ec1', 'ec2']],
    [2, ['f0', 'f1', 'ec2']],
  ] as const)('with %i sentenceless questions, serves the rest unchanged and in order', async (missing, ids) => {
    const questions = set(missing);
    anthropicResponds({ questions });

    const response = await post({ deviceId: 'd1', count: 5 });

    expect(response.status).toBe(200);
    const json = (await response.json()) as { questions: Question[] };
    expect(json.questions.map((x) => x.id)).toEqual(ids);
    // Each served question is exactly what the model wrote.
    for (const served of json.questions) expect(served).toEqual(questions.find((x) => x.id === served.id));
    expect(filterLines()).toEqual([
      {
        event: 'legacy_daily_test_filter',
        operation: 'generate_daily_test',
        received_count: 5,
        removed_count: missing,
        served_count: 5 - missing,
        outcome: 'served',
      },
    ]);
  });

  it(`with 3 sentenceless questions (fewer than ${LEGACY_MIN_QUESTIONS} left), returns the existing upstream error`, async () => {
    anthropicResponds({ questions: set(3) });

    const response = await post({ deviceId: 'd1', count: 5 });

    // What callAnthropic returns for an unusable response: 1.0.0 shows
    // "Couldn't load today's test" with "Try again" for any error it does
    // not know by name (claude_service.dart:200-206).
    expect(response.status).toBe(502);
    expect(await response.json()).toEqual({
      error: 'upstream_error',
      message: 'The upstream service returned an unexpected response.',
    });
    expect(filterLines()).toEqual([
      {
        event: 'legacy_daily_test_filter',
        operation: 'generate_daily_test',
        received_count: 5,
        removed_count: 3,
        served_count: 0,
        outcome: 'rejected',
      },
    ]);
  });

  it('keeps quota and cost as they were: one quota unit and one Anthropic call, served or rejected', async () => {
    for (const missing of [0, 3]) {
      anthropicResponds({ questions: set(missing) });
      await post({ deviceId: `device-${missing}`, count: 5 });
    }
    expect(requestBodies).toHaveLength(2);
    const counts = await Promise.all(
      (await env.QUOTA_KV.list({ prefix: 'd:' })).keys.map((k) => env.QUOTA_KV.get(k.name)),
    );
    expect(counts).toEqual(['1', '1']);
  });

  it('never changes the request: the bytes 1.0.0 always sent', async () => {
    anthropicResponds({ questions: set(2) });
    await post({ deviceId: 'd1', count: 5 });
    expect(requestBodies).toEqual([LEGACY_DAILY_TEST_BODY_COUNT_5]);
  });

  it('counts a blank, whitespace-only or too-short "context" as no sentence, and never touches fill_in_blank', () => {
    const questions = [
      q('a', 'error_correction', ''),
      q('b', 'error_correction', ' \n '),
      q('c', 'error_correction', 'Plane left.'),
      q('d', 'error_correction', 'She go home.'),
      q('e', 'fill_in_blank', ''),
      q('f', 'fill_in_blank', undefined),
    ];
    const result = filterLegacyDailyTest({ questions });
    expect(result.removed).toBe(3);
    expect(result.content).toEqual({ questions: questions.slice(3) });
  });

  it('uses the shared set rule: a question it drops is one validateSharedSet rejects as error_correction_missing_sentence', () => {
    const plan: DailyPlan = { date: '2026-10-05', theme: 'x', slots: [{ topicId: 'tenseSelection', type: 'error_correction' }] };
    for (const context of [undefined, '', '  ', '...', 'Plane left.', '— 1 2 3 —', 'She go home.', 'She live here since 2019.']) {
      const question = q('x', 'error_correction', context);
      const dropped = filterLegacyDailyTest({ questions: [question] }).removed === 1;
      const shared = validateSharedSet({ questions: [question] }, plan);
      expect(dropped).toBe(!shared.ok && shared.reason === 'error_correction_missing_sentence');
    }
  });

  it('passes a response without a questions array through untouched, as before', () => {
    for (const content of [{ items: [] }, { questions: 'x' }, null, 'text', 42]) {
      expect(filterLegacyDailyTest(content)).toEqual({ content, received: null, removed: 0, served: null, rejected: false });
    }
  });

  it('only ever removes: entries that are not sentenceless error_correction questions stay, whatever they are', () => {
    const odd = { questions: [1, null, 'q', { type: 'error_correction' }] };
    expect(filterLegacyDailyTest(odd)).toEqual({
      content: { questions: [1, null, 'q'] },
      received: 4,
      removed: 1,
      served: 3,
      rejected: false,
    });
    // Nothing removed: no floor, so a short answer is served exactly as before.
    expect(filterLegacyDailyTest({ questions: [] })).toEqual({
      content: { questions: [] },
      received: 0,
      removed: 0,
      served: 0,
      rejected: false,
    });
  });

  it('serves an unchanged object when nothing is removed', () => {
    const content = { questions: set(0), extra: 'kept' };
    expect(filterLegacyDailyTest(content).content).toBe(content);
  });

  it('logs counts only: no question text, no device id', async () => {
    const secret = set(1).map((x) => ({ ...x, instruction: 'SECRET-TEXT-9913', explanation: 'SECRET-TEXT-9913' }));
    anthropicResponds({ questions: secret });

    await post({ deviceId: 'SECRET-DEVICE-5521', count: 5 });

    const [line] = filterLines();
    expect(Object.keys(line ?? {}).sort()).toEqual(
      ['event', 'operation', 'outcome', 'received_count', 'removed_count', 'served_count'].sort(),
    );
    expect(logged.join('\n')).not.toContain('SECRET-TEXT-9913');
    expect(logged.join('\n')).not.toContain('SECRET-DEVICE-5521');
  });
});
