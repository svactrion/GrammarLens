import { createExecutionContext, createScheduledController, env, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { THINKING_HEADROOM_TOKENS, buildGenerateSharedDailyTestBody, dailyTestMaxTokensFor } from '../src/anthropic';
import worker from '../src/index';
import {
  dailyPlan,
  dateOfDayNumber,
  dayNumberOf,
  SHARED_GENERATOR,
  SHARED_PROMPT_VERSION,
  sharedDailyTestRequest,
  type DailyPlan,
} from '../src/shared_daily_test';
import {
  ATTEMPTS_TTL_SECONDS,
  ATTEMPT_LEASE_MS,
  CHECK_TIMEOUT_MS,
  GENERATION_TIMEOUT_MS,
  MAX_ATTEMPTS_PER_DATE,
  MAX_CHECKS_PER_DATE,
  REVIEW_TTL_SECONDS,
  SET_TTL_SECONDS,
  attemptsKey,
  checkLeaseMs,
  reviewKey,
  runSharedGeneration,
  setKey,
  type PublishedSet,
  type ReviewRecord,
} from '../src/shared_generation';
import { ANNOTATION_CHECKERS, ANNOTATION_GATE, CHECK_VERSION, type QuestionCheck } from '../src/shared_check';
import { validateSharedSet, type SharedQuestion } from '../src/shared_daily_test';
import type { Env } from '../src/types';
import wranglerSource from '../wrangler.jsonc?raw';

const NOW = new Date('2026-10-05T00:07:00Z');
const HOUR = 60 * 60 * 1000;
const at = (hoursLater: number) => new Date(NOW.getTime() + hoursLater * HOUR);
const dateAt = (offset: number) => dateOfDayNumber((dayNumberOf('2026-10-05') as number) + offset);
const TODAY = dateAt(0);
const PLUS_3 = dateAt(3);

/** Planted in the generated text: must never reach a log line. */
const CONTENT_SECRET = 'CONTENT-SECRET-6621';

/** A set that passes validateSharedSet for [plan]. */
function validSetFor(plan: DailyPlan, tag = 'a'): { questions: Record<string, unknown>[] } {
  return {
    questions: plan.slots.map((slot, i) =>
      slot.type === 'fill_in_blank'
        ? {
            id: `${tag}-q${i}`,
            type: slot.type,
            context: `We waited for ___ bus ${CONTENT_SECRET}.`,
            instruction: 'Fill in the blank.',
            topicId: slot.topicId,
            correctAnswer: `answer ${tag}${i}`,
            explanation: 'The rule at work here picks this form.',
            commonWrongAnswers: [
              { answer: `wrong ${tag}${i} one`, comment: 'This form does not fit here.' },
              { answer: `wrong ${tag}${i} two`, comment: 'This one misses the rule.' },
            ],
          }
        : {
            id: `${tag}-q${i}`,
            type: slot.type,
            context: `Flawed sentence ${tag}${i} ${CONTENT_SECRET}.`,
            instruction: 'Find the mistake and rewrite the full corrected sentence.',
            topicId: slot.topicId,
            correctAnswer: `Fixed sentence ${tag}${i}.`,
            explanation: 'The corrected form follows the rule for this structure.',
            commonWrongAnswers: [
              { answer: `Half fixed ${tag}${i}.`, comment: 'Only part of the mistake is fixed.' },
              { answer: `Flawed sentence ${tag}${i} ${CONTENT_SECRET}.`, comment: 'The sentence is unchanged.' },
            ],
          },
    ),
  };
}

function anthropicBody(content: unknown, stopReason = 'end_turn'): Response {
  return new Response(
    JSON.stringify({
      content: [{ type: 'text', text: JSON.stringify(content) }],
      usage: { input_tokens: 1500, output_tokens: 1400 },
      stop_reason: stopReason,
    }),
    { status: 200 },
  );
}

// Outbound fetch is replaced for every test; an unexpected call fails loudly.
const originalFetch = globalThis.fetch;
const originalConsole = { log: console.log, error: console.error, warn: console.warn, info: console.info };
let fetchCalls: { url: string; init?: RequestInit }[] = [];
let respond: ((init?: RequestInit) => Promise<Response>) | null = null;
let logged: string[] = [];

function lines(event: string): Record<string, unknown>[] {
  return logged.filter((l) => l.includes(`"${event}"`)).map((l) => JSON.parse(l) as Record<string, unknown>);
}

async function clear(kv: KVNamespace) {
  const list = await kv.list();
  await Promise.all(list.keys.map((k) => kv.delete(k.name)));
}

/** A published set already in KV for [date]. */
async function seed(date: string, answers: string[] = ['seeded']) {
  const set: PublishedSet = {
    date,
    promptVersion: 1,
    generatedAt: '2026-10-01T00:07:00.000Z',
    attempt: 1,
    questions: answers.map((a, i) => ({ correctAnswer: a, id: `s${i}` }) as never),
  };
  await env.DAILY_SETS_KV.put(setKey(date), JSON.stringify(set));
}

/** Counts every KV call made through it. */
function counting(kv: KVNamespace) {
  const counts = { get: 0, put: 0, list: 0, delete: 0 };
  const wrapped = {
    get: (...args: unknown[]) => {
      counts.get++;
      return (kv.get as (...a: unknown[]) => unknown)(...args);
    },
    put: (...args: unknown[]) => {
      counts.put++;
      return (kv.put as (...a: unknown[]) => unknown)(...args);
    },
    list: (...args: unknown[]) => {
      counts.list++;
      return (kv.list as (...a: unknown[]) => unknown)(...args);
    },
    delete: (...args: unknown[]) => {
      counts.delete++;
      return (kv.delete as (...a: unknown[]) => unknown)(...args);
    },
  } as unknown as KVNamespace;
  return { kv: wrapped, counts };
}

/**
 * The test environment with the kill switch set here, not read from
 * wrangler.jsonc: the owner may switch the live value off (docs 2026-09-29)
 * without turning these tests red. Every run in this file goes through it.
 */
function envWith(overrides: Partial<Env> = {}): Env {
  return { ...env, SHARED_DAILY_TEST_ENABLED: 'true', ...overrides } as Env;
}

beforeEach(async () => {
  await clear(env.DAILY_SETS_KV);
  await clear(env.QUOTA_KV);
  fetchCalls = [];
  respond = null;
  logged = [];
  for (const level of ['log', 'error', 'warn', 'info'] as const) {
    console[level] = (...args: unknown[]) => {
      logged.push(args.map((a) => (typeof a === 'string' ? a : JSON.stringify(a))).join(' '));
    };
  }
  globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
    fetchCalls.push({ url: String(url), init });
    if (!respond) throw new Error(`Unexpected outbound fetch to ${String(url)}`);
    return respond(init);
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
  Object.assign(console, originalConsole);
});

async function storedSet(date: string): Promise<PublishedSet | null> {
  const raw = await env.DAILY_SETS_KV.get(setKey(date));
  return raw === null ? null : (JSON.parse(raw) as PublishedSet);
}

describe('shared set generation (cron)', () => {
  describe('request: prompt version 3 (1.4.0 D3) with SHARED_GENERATOR; the check call is the annotation step, never in the same run', () => {
    async function sentBody(): Promise<string> {
      for (const offset of [0, 1, 2]) await seed(dateAt(offset), [`recent ${offset}`]);
      respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));
      await runSharedGeneration(envWith(), NOW);
      expect(fetchCalls).toHaveLength(1);
      return String(fetchCalls[0]?.init?.body);
    }

    it('sends prompt version 3 with claude-sonnet-5-5 at effort low, adaptive thinking and its headroom', async () => {
      expect(SHARED_PROMPT_VERSION).toBe(3);
      expect(SHARED_GENERATOR).toEqual({ model: 'claude-sonnet-5-5', effort: 'low' });
      const sent = JSON.parse(await sentBody()) as Record<string, unknown> & { output_config: object };
      const avoid = ['recent 2', 'recent 1', 'recent 0'];
      const v3 = buildGenerateSharedDailyTestBody(
        sharedDailyTestRequest(dailyPlan(PLUS_3), avoid, { promptVersion: 3, model: 'claude-sonnet-5-5', effort: 'low' }),
      );
      const v2 = buildGenerateSharedDailyTestBody(
        sharedDailyTestRequest(dailyPlan(PLUS_3), avoid, { promptVersion: 2, model: 'claude-sonnet-5-5', effort: 'low' }),
      );
      expect(sent).toEqual(v3);
      expect(sent.system).not.toBe(v2.system);
      expect(sent.model).toBe('claude-sonnet-5-5');
      expect(sent.thinking).toEqual({ type: 'adaptive' });
      expect(sent.max_tokens).toBe(dailyTestMaxTokensFor(5) + THINKING_HEADROOM_TOKENS);
      expect(sent.output_config).toMatchObject({ effort: 'low' });
    });

    it('pins the bytes the cron sends to a fingerprint', async () => {
      // If this changes, the cron's request changed: the prompt (a new
      // SHARED_PROMPT_VERSION), the plan, or SHARED_GENERATOR. Switching the
      // generator after the comparison is expected to re-pin it here.
      // History: b7ef3b35 (claude-sonnet-5, no effort, never deployed), then
      // 80b1fa85 (claude-sonnet-5-5, effort low; owner, 2026-09-29; the live
      // cron until 1.4.0 D3 deploys), then 2bfd39d1 (prompt version 3,
      // 1.4.0 D3, 2026-10-31; not deployed until the v2/v3 measurement).
      const body = await sentBody();
      let hash = 0x811c9dc5;
      for (let i = 0; i < body.length; i++) {
        hash ^= body.charCodeAt(i);
        hash = Math.imul(hash, 0x01000193) >>> 0;
      }
      expect(hash.toString(16)).toBe('2bfd39d1');
    });

    it('stores prompt version 3 with the published set and in its log line', async () => {
      await sentBody();
      expect(await storedSet(PLUS_3)).toMatchObject({ promptVersion: 3 });
      expect(lines('shared_set_generation')).toEqual([expect.objectContaining({ outcome: 'published', prompt_version: 3 })]);
    });
  });

  it('generates a missing date once, in plan order, and a second run makes no request', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));

    await runSharedGeneration(envWith(), NOW);

    expect(fetchCalls).toHaveLength(1);
    expect(fetchCalls[0]?.url).toBe('https://api.anthropic.com/v1/messages');
    const set = await storedSet(PLUS_3);
    expect(set).toMatchObject({ date: PLUS_3, promptVersion: 3, attempt: 1, generatedAt: NOW.toISOString() });
    expect(set?.questions.map((q) => q.topicId)).toEqual(dailyPlan(PLUS_3).slots.map((s) => s.topicId));
    expect(lines('shared_set_generation')).toEqual([
      {
        event: 'shared_set_generation',
        date: PLUS_3,
        attempt: 1,
        outcome: 'published',
        reason: null,
        failure: null,
        stop_reason: 'end_turn',
        input_tokens: 1500,
        output_tokens: 1400,
        duration_ms: expect.any(Number),
        prompt_version: 3,
        model: 'claude-sonnet-5-5',
        effort: 'low',
      },
    ]);
    // The ordinary cost line is written too, filed as Daily Test cost, in the
    // one shape every operation's line has: no model or effort there.
    const [usage] = lines('anthropic_usage');
    expect(usage).toMatchObject({ kind: 'daily_test', operation: 'generate_shared_daily_test', item_count: 5 });
    expect(Object.keys(usage as object).sort()).toEqual(
      ['event', 'kind', 'operation', 'item_count', 'input_tokens', 'output_tokens', 'stop_reason', 'duration_ms'].sort(),
    );

    const before = await env.DAILY_SETS_KV.get(setKey(PLUS_3));
    await runSharedGeneration(envWith(), at(1));
    expect(fetchCalls).toHaveLength(1);
    expect(await env.DAILY_SETS_KV.get(setKey(PLUS_3))).toBe(before);
  });

  it('makes zero outbound requests and writes nothing when every date already has a set', async () => {
    for (const offset of [0, 1, 2, 3]) await seed(dateAt(offset));
    const { kv, counts } = counting(env.DAILY_SETS_KV);

    await runSharedGeneration(envWith({ DAILY_SETS_KV: kv }), NOW);

    expect(fetchCalls).toHaveLength(0);
    expect(counts.put).toBe(0);
    expect(counts.get).toBe(4); // one presence check per date
    expect(lines('shared_set_generation')).toHaveLength(0);
  });

  it('fills the nearest missing date first, one per run', async () => {
    respond = async (init) => {
      // Answer with a valid set for whichever plan the request asks for.
      const content = String(JSON.parse(String(init?.body)).messages[0].content);
      const date = [0, 1, 2, 3].map(dateAt).find((d) => {
        const first = dailyPlan(d).slots[0];
        return content.includes(`1. topicId "${first?.topicId}"`) && content.includes(`"${dailyPlan(d).theme}"`);
      }) as string;
      return anthropicBody(validSetFor(dailyPlan(date)));
    };

    for (let run = 0; run < 4; run++) {
      await runSharedGeneration(envWith(), at(run));
      // At most one Anthropic call per run, even with several dates missing.
      expect(fetchCalls).toHaveLength(run + 1);
    }

    expect(lines('shared_set_generation').map((l) => l.date)).toEqual([0, 1, 2, 3].map(dateAt));
    for (const offset of [0, 1, 2, 3]) expect(await storedSet(dateAt(offset))).not.toBeNull();

    await runSharedGeneration(envWith(), at(4));
    expect(fetchCalls).toHaveLength(4);
  });

  it(`stops after attempt ${MAX_ATTEMPTS_PER_DATE}; a rejected set is never written and its reason is logged`, async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    const plan = dailyPlan(PLUS_3);
    const short = { questions: validSetFor(plan).questions.slice(0, 4) };
    respond = async () => anthropicBody(short);

    for (let run = 0; run < 5; run++) await runSharedGeneration(envWith(), at(run));

    expect(fetchCalls).toHaveLength(3);
    expect(await storedSet(PLUS_3)).toBeNull();
    expect(lines('shared_set_generation').map((l) => [l.attempt, l.outcome, l.reason])).toEqual([
      [1, 'rejected', 'wrong_question_count'],
      [2, 'rejected', 'wrong_question_count'],
      [3, 'rejected', 'wrong_question_count'],
    ]);
    expect(JSON.parse((await env.DAILY_SETS_KV.get(attemptsKey(PLUS_3))) as string)).toMatchObject({ count: 3 });
  });

  it('retries after a rejection and publishes the next good set', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    const plan = dailyPlan(PLUS_3);
    const bad = validSetFor(plan);
    (bad.questions[0] as Record<string, unknown>).explanation = 'Not quite: this is the rule.';
    const results = [anthropicBody(bad), anthropicBody(validSetFor(plan, 'b'))];
    respond = async () => results.shift() as Response;

    await runSharedGeneration(envWith(), NOW);
    await runSharedGeneration(envWith(), at(1));

    expect(lines('shared_set_generation').map((l) => [l.attempt, l.outcome, l.reason])).toEqual([
      [1, 'rejected', 'explanation_bad_opening'],
      [2, 'published', null],
    ]);
    expect(await storedSet(PLUS_3)).toMatchObject({ attempt: 2 });
  });

  it('two overlapping runs make one request and one set write', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    let release: (r: Response) => void = () => {};
    respond = () => new Promise<Response>((resolve) => (release = resolve));
    const { kv, counts } = counting(env.DAILY_SETS_KV);
    const e = envWith({ DAILY_SETS_KV: kv });

    const first = runSharedGeneration(e, NOW);
    while (fetchCalls.length === 0) await new Promise((r) => setTimeout(r, 1));
    // A second run starts while the first is still waiting on Anthropic.
    await runSharedGeneration(e, new Date(NOW.getTime() + 30_000));
    expect(fetchCalls).toHaveLength(1);

    release(anthropicBody(validSetFor(dailyPlan(PLUS_3))));
    await first;

    expect(fetchCalls).toHaveLength(1);
    expect(counts.put).toBe(2); // the attempt record, then the set
    expect(lines('shared_set_generation').map((l) => l.outcome)).toEqual(['published']);
  });

  it('never overwrites a set that appeared while its own call was running', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    let release: (r: Response) => void = () => {};
    respond = () => new Promise<Response>((resolve) => (release = resolve));

    const run = runSharedGeneration(envWith(), NOW);
    while (fetchCalls.length === 0) await new Promise((r) => setTimeout(r, 1));
    await seed(PLUS_3, ['the winner']);
    const winner = await env.DAILY_SETS_KV.get(setKey(PLUS_3));
    release(anthropicBody(validSetFor(dailyPlan(PLUS_3))));
    await run;

    expect(await env.DAILY_SETS_KV.get(setKey(PLUS_3))).toBe(winner);
    expect(lines('shared_set_generation').map((l) => l.outcome)).toEqual(['already_published']);
  });

  it('logs a timeout as an upstream failure, writes no set, and counts the attempt', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = (init) =>
      new Promise<Response>((_, reject) => {
        init?.signal?.addEventListener('abort', () => reject(new Error('aborted')));
      });

    await runSharedGeneration(envWith(), NOW, { timeoutMs: 20 });

    expect(await storedSet(PLUS_3)).toBeNull();
    const [line] = lines('shared_set_generation');
    expect(line).toMatchObject({
      date: PLUS_3,
      attempt: 1,
      outcome: 'upstream_failed',
      failure: 'timeout',
      reason: null,
      stop_reason: null,
      input_tokens: null,
      output_tokens: null,
    });
    expect(typeof line?.duration_ms).toBe('number');
    expect(lines('anthropic_failure')).toEqual([expect.objectContaining({ failure: 'timeout' })]);
    expect(JSON.parse((await env.DAILY_SETS_KV.get(attemptsKey(PLUS_3))) as string)).toMatchObject({ count: 1 });
  });

  it(`gives Anthropic ${GENERATION_TIMEOUT_MS / 1000} s by default, and only on this path`, async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));

    await runSharedGeneration(envWith(), NOW);

    expect(GENERATION_TIMEOUT_MS).toBe(150_000);
    expect(fetchCalls[0]?.init?.signal).toBeInstanceOf(AbortSignal);
    expect(fetchCalls[0]?.init?.signal?.aborted).toBe(false);
  });

  it(`holds a date for ${ATTEMPT_LEASE_MS / 1000} s after an attempt starts (the timeout plus 30 s)`, async () => {
    expect(ATTEMPT_LEASE_MS).toBe(180_000);
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => new Response('{}', { status: 500 });

    await runSharedGeneration(envWith(), NOW);
    expect(JSON.parse((await env.DAILY_SETS_KV.get(attemptsKey(PLUS_3))) as string)).toEqual({
      count: 1,
      checks: 0,
      leaseUntil: NOW.getTime() + 180_000,
    });
    // Still held just before the lease ends: no second call.
    await runSharedGeneration(envWith(), new Date(NOW.getTime() + 179_999));
    expect(fetchCalls).toHaveLength(1);
    // Free again once it has ended.
    await runSharedGeneration(envWith(), new Date(NOW.getTime() + 180_001));
    expect(fetchCalls).toHaveLength(2);
  });

  it('logs an Anthropic error as upstream_failed with its category', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () =>
      new Response(JSON.stringify({ type: 'error', error: { type: 'overloaded_error' } }), { status: 529 });

    await runSharedGeneration(envWith(), NOW);

    expect(lines('shared_set_generation')).toEqual([
      expect.objectContaining({ outcome: 'upstream_failed', failure: 'http_error', attempt: 1 }),
    ]);
    expect(await storedSet(PLUS_3)).toBeNull();
  });

  it('logs a truncated answer with its stop_reason and tokens', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () =>
      new Response(
        JSON.stringify({
          content: [{ type: 'text', text: '{"questions": [{"id": "q1", "ty' }],
          usage: { input_tokens: 1500, output_tokens: 3072 },
          stop_reason: 'max_tokens',
        }),
        { status: 200 },
      );

    await runSharedGeneration(envWith(), NOW);

    expect(lines('shared_set_generation')).toEqual([
      expect.objectContaining({
        outcome: 'upstream_failed',
        failure: 'invalid_json_content',
        stop_reason: 'max_tokens',
        output_tokens: 3072,
      }),
    ]);
  });

  it('sends recent published answers as the avoid list, looking back 7 days', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset), [`recent ${offset}`]);
    await seed(dateAt(-4), ['a week ago']);
    await seed(dateAt(-5), ['too old']); // PLUS_3 − 8
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));

    await runSharedGeneration(envWith(), NOW);

    const content = String(JSON.parse(String(fetchCalls[0]?.init?.body)).messages[0].content);
    expect(content).toContain('"recent 2", "recent 1", "recent 0"');
    expect(content).toContain('"a week ago"');
    expect(content).not.toContain('too old');
  });

  it(`stores sets for ${SET_TTL_SECONDS / 86400} days and attempt records for ${ATTEMPTS_TTL_SECONDS / 86400}`, async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));
    const nowSeconds = Date.now() / 1000;

    await runSharedGeneration(envWith(), NOW);

    const keys = (await env.DAILY_SETS_KV.list()).keys;
    const expiry = (name: string) => keys.find((k) => k.name === name)?.expiration as number;
    expect(expiry(setKey(PLUS_3)) - nowSeconds).toBeGreaterThan(35 * 86400 - 60);
    expect(expiry(setKey(PLUS_3)) - nowSeconds).toBeLessThan(35 * 86400 + 60);
    expect(expiry(attemptsKey(PLUS_3)) - nowSeconds).toBeGreaterThan(7 * 86400 - 60);
    expect(expiry(attemptsKey(PLUS_3)) - nowSeconds).toBeLessThan(7 * 86400 + 60);
  });

  describe('kill switch (SHARED_DAILY_TEST_ENABLED)', () => {
    it.each(['false', 'TRUE', '', 'yes'])('"%s" touches neither KV nor Anthropic', async (value) => {
      const sets = counting(env.DAILY_SETS_KV);
      const quota = counting(env.QUOTA_KV);

      await runSharedGeneration(
        envWith({ SHARED_DAILY_TEST_ENABLED: value, DAILY_SETS_KV: sets.kv, QUOTA_KV: quota.kv }),
        NOW,
      );

      expect(fetchCalls).toHaveLength(0);
      expect(sets.counts).toEqual({ get: 0, put: 0, list: 0, delete: 0 });
      expect(quota.counts).toEqual({ get: 0, put: 0, list: 0, delete: 0 });
      expect(lines('shared_set_cron')).toEqual([{ event: 'shared_set_cron', enabled: false }]);
    });

    it('makes zero Anthropic calls on a run where every date is missing', async () => {
      respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));

      for (let run = 0; run < 3; run++) await runSharedGeneration(envWith({ SHARED_DAILY_TEST_ENABLED: 'false' }), at(run));

      expect(fetchCalls).toHaveLength(0);
      expect((await env.DAILY_SETS_KV.list()).keys).toHaveLength(0);
      expect(lines('shared_set_generation')).toHaveLength(0);
    });

    it('is "true" or "false" in wrangler.jsonc: either is a valid live setting', () => {
      // Which one is the owner's call (off until release is fine); the tests
      // above set it themselves, so neither value turns them red.
      const match = wranglerSource.match(/"SHARED_DAILY_TEST_ENABLED"\s*:\s*"([^"]*)"/g) ?? [];
      expect(match).toHaveLength(1);
      expect(['true', 'false']).toContain(/:\s*"([^"]*)"/.exec(match[0] as string)?.[1]);
    });
  });

  it('never touches the quota: no path reserves a unit', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    const quota = counting(env.QUOTA_KV);
    const e = envWith({ QUOTA_KV: quota.kv });
    const plan = dailyPlan(PLUS_3);
    const results: (() => Promise<Response>)[] = [
      async () => anthropicBody({ questions: [] }), // rejected
      async () => new Response('{}', { status: 500 }), // upstream failure
      async () => anthropicBody(validSetFor(plan)), // published
    ];
    respond = () => (results.shift() as () => Promise<Response>)();

    for (let run = 0; run < 4; run++) await runSharedGeneration(e, at(run));

    expect(lines('shared_set_generation').map((l) => l.outcome)).toEqual(['rejected', 'upstream_failed', 'published']);
    expect(quota.counts).toEqual({ get: 0, put: 0, list: 0, delete: 0 });
    expect((await env.QUOTA_KV.list()).keys).toHaveLength(0);
  });

  it('never logs generated text or recent answers, and the line has only its fixed fields', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset), [`AVOID-SECRET-${offset}`]);
    const plan = dailyPlan(PLUS_3);
    const rejected = validSetFor(plan);
    (rejected.questions[1] as Record<string, unknown>).explanation = `${CONTENT_SECRET} is two. Sentences here.`;
    const results = [anthropicBody(rejected), anthropicBody(validSetFor(plan))];
    respond = async () => results.shift() as Response;

    await runSharedGeneration(envWith(), NOW);
    await runSharedGeneration(envWith(), at(1));

    expect(lines('shared_set_generation')).toHaveLength(2);
    const everything = logged.join('\n');
    expect(everything).not.toContain(CONTENT_SECRET);
    expect(everything).not.toContain('AVOID-SECRET');
    for (const line of lines('shared_set_generation')) {
      expect(Object.keys(line).sort()).toEqual(
        [
          'attempt',
          'date',
          'duration_ms',
          'effort',
          'event',
          'failure',
          'input_tokens',
          'model',
          'outcome',
          'output_tokens',
          'prompt_version',
          'reason',
          'stop_reason',
        ].sort(),
      );
    }
  });

  it('logs the model and effort asked for on every outcome, as fixed values only', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    const plan = dailyPlan(PLUS_3);
    // A blankless fill_in_blank question whose text must not reach the log.
    const blankless = validSetFor(plan);
    const fill = blankless.questions.find((q) => q.type === 'fill_in_blank') as Record<string, unknown>;
    fill.context = `A scene with no gap ${CONTENT_SECRET}.`;
    fill.instruction = `Complete the sentence ${CONTENT_SECRET}.`;
    const results: (() => Promise<Response>)[] = [
      async () => new Response('{}', { status: 500 }), // upstream_failed
      async () => anthropicBody(blankless), // rejected
      async () => anthropicBody(validSetFor(plan)), // published
    ];
    respond = () => (results.shift() as () => Promise<Response>)();

    for (let run = 0; run < 3; run++) await runSharedGeneration(envWith(), at(run));

    expect(lines('shared_set_generation').map((l) => [l.outcome, l.reason, l.model, l.effort, l.prompt_version])).toEqual([
      ['upstream_failed', null, 'claude-sonnet-5-5', 'low', 3],
      ['rejected', 'fill_in_blank_missing_blank', 'claude-sonnet-5-5', 'low', 3],
      ['published', null, 'claude-sonnet-5-5', 'low', 3],
    ]);
    expect(logged.join('\n')).not.toContain(CONTENT_SECRET);
  });

  it('logs effort as null when the generator sends none', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));

    await runSharedGeneration(envWith(), NOW, { generation: { model: 'claude-sonnet-5' } });

    expect(JSON.parse(String(fetchCalls[0]?.init?.body)).model).toBe('claude-sonnet-5');
    expect(lines('shared_set_generation')).toEqual([expect.objectContaining({ model: 'claude-sonnet-5', effort: null })]);
  });

  it('runs from the Worker\'s scheduled handler, using the trigger\'s scheduled time', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));
    const controller = createScheduledController({ scheduledTime: NOW.getTime(), cron: '7 * * * *' });
    const ctx = createExecutionContext();

    await worker.scheduled(controller, envWith());
    await waitOnExecutionContext(ctx);

    expect(fetchCalls).toHaveLength(1);
    expect(await storedSet(PLUS_3)).toMatchObject({ date: PLUS_3, generatedAt: NOW.toISOString() });
    expect(TODAY).toBe('2026-10-05');
  });
});

// ---------------------------------------------------------------------------
// P14: the annotation step (docs/1.4.0-server-batch0-report.md §1.3–1.4)

describe('shared set annotation (cron, P14)', () => {
  const PLAN = dailyPlan(TODAY);
  const withCheck = (overrides: Partial<Env> = {}) => envWith({ SHARED_SET_CHECK_ENABLED: 'true', ...overrides });

  /** The validated questions of a set that passes the gate for [plan]. */
  function questionsFor(plan: DailyPlan, tag = 'a'): SharedQuestion[] {
    const result = validateSharedSet(validSetFor(plan, tag), plan);
    if (!result.ok) throw new Error(result.reason);
    return result.questions;
  }

  /** A published, unchecked set in KV, as the generation step writes it. */
  async function publish(date: string, questions: SharedQuestion[], extra: Partial<PublishedSet> = {}): Promise<PublishedSet> {
    const set: PublishedSet = { date, promptVersion: 2, generatedAt: '2026-10-02T00:07:00.000Z', attempt: 1, questions, ...extra };
    await env.DAILY_SETS_KV.put(setKey(date), JSON.stringify(set));
    return set;
  }

  /** A clean review of every question, with per-question overrides by id. */
  function reviewOf(questions: readonly SharedQuestion[], overrides: Record<string, Partial<QuestionCheck>> = {}): { questions: QuestionCheck[] } {
    return {
      questions: questions.map((q) => ({
        id: q.id,
        originalSentence: q.type === 'error_correction' ? 'clearly_wrong' : 'not_applicable',
        correctAnswer: 'correct',
        acceptableAlternatives: [],
        acceptableWrongAnswers: [],
        incorrectRuleFields: [],
        explanationExcludesAlternatives: false,
        verdict: 'pass',
        ...overrides[q.id],
      })),
    };
  }

  /** Checked sets for the three later dates, so a run that skips today has
   * nothing to generate and the call count is the annotation's alone. */
  async function fillLaterDates(): Promise<void> {
    for (const offset of [1, 2, 3]) await publish(dateAt(offset), questionsFor(dailyPlan(dateAt(offset))), { checkedAt: 'earlier' });
  }

  /** Answers each checker call from [byModel], keyed by the request's model. */
  function respondByModel(byModel: Record<string, unknown>) {
    respond = async (init) => {
      const body = JSON.parse(String(init?.body)) as { model: string };
      const content = byModel[body.model];
      if (content === undefined) throw new Error(`no response planned for ${body.model}`);
      return anthropicBody(content);
    };
  }

  const sentModels = () => fetchCalls.map((c) => (JSON.parse(String(c.init?.body)) as { model: string }).model);

  it('annotates an unchecked published set with the agreed alternatives, one call per checker, and stamps it', async () => {
    const questions = questionsFor(PLAN);
    const q0 = questions[0] as SharedQuestion;
    const alt = `also ${q0.correctAnswer}`;
    await publish(TODAY, questions);
    const models = ANNOTATION_CHECKERS.agreement;
    respondByModel({
      [models[0] as string]: reviewOf(questions, { [q0.id]: { acceptableAlternatives: [alt], verdict: 'pass_with_alternatives' } }),
      [models[1] as string]: reviewOf(questions, { [q0.id]: { acceptableAlternatives: [alt, 'only one model says this'], verdict: 'pass_with_alternatives' } }),
    });

    await runSharedGeneration(withCheck(), NOW, { gate: 'agreement' });

    expect(sentModels()).toEqual([...models]);
    const stored = (await storedSet(TODAY)) as PublishedSet;
    expect(stored.checkedAt).toBe(NOW.toISOString());
    expect(stored).toMatchObject({ checkVersion: CHECK_VERSION, checkGate: 'agreement', checkModels: [...models], promptVersion: 2, attempt: 1 });
    expect(stored.questions[0]?.acceptedAnswers).toEqual([alt]);
    expect(stored.questions.slice(1).every((q) => q.acceptedAnswers === undefined)).toBe(true);
    // Everything else about the set is byte-identical.
    const { acceptedAnswers: _a, ...annotated } = stored.questions[0] as SharedQuestion;
    expect(annotated).toEqual(q0);
    const review = JSON.parse((await env.DAILY_SETS_KV.get(reviewKey(TODAY))) as string) as ReviewRecord;
    expect(review.findings).toEqual([{ questionId: q0.id, code: 'proposed_by_one_model', model: models[1], answers: ['only one model says this'] }]);
    expect(lines('shared_set_annotation')).toEqual([
      expect.objectContaining({ date: TODAY, check: 1, outcome: 'annotated', gate: 'agreement', models: [...models], added: 1, moved: 0, findings: 1, check_version: CHECK_VERSION }),
    ]);
  });

  it('under the single-review gate makes one call and writes what that checker proposes', async () => {
    const questions = questionsFor(PLAN);
    const q0 = questions[0] as SharedQuestion;
    await publish(TODAY, questions);
    respondByModel({ 'claude-opus-5-5': reviewOf(questions, { [q0.id]: { acceptableAlternatives: ['alone'], verdict: 'pass_with_alternatives' } }) });

    await runSharedGeneration(withCheck(), NOW, { gate: 'single_review' });

    expect(sentModels()).toEqual(['claude-opus-5-5']);
    expect((await storedSet(TODAY))?.questions[0]?.acceptedAnswers).toEqual(['alone']);
    expect(await env.DAILY_SETS_KV.get(reviewKey(TODAY))).toBeNull();
  });

  it(`uses the production gate ${ANNOTATION_GATE} by default`, async () => {
    const questions = questionsFor(PLAN);
    await publish(TODAY, questions);
    const byModel: Record<string, unknown> = {};
    for (const m of ANNOTATION_CHECKERS[ANNOTATION_GATE]) byModel[m] = reviewOf(questions);
    respondByModel(byModel);

    await runSharedGeneration(withCheck(), NOW);

    expect(sentModels()).toEqual([...ANNOTATION_CHECKERS[ANNOTATION_GATE]]);
    expect((await storedSet(TODAY))?.checkGate).toBe(ANNOTATION_GATE);
  });

  it('moves an agreed acceptable wrong answer into the accepted ones and keeps the rest', async () => {
    const questions = questionsFor(PLAN);
    const q0 = questions[0] as SharedQuestion;
    const moved = q0.commonWrongAnswers[0] as { answer: string; comment: string };
    await publish(TODAY, questions);
    const byModel: Record<string, unknown> = {};
    for (const m of ANNOTATION_CHECKERS.agreement) byModel[m] = reviewOf(questions, { [q0.id]: { acceptableWrongAnswers: [moved.answer], verdict: 'reject' } });
    respondByModel(byModel);

    await runSharedGeneration(withCheck(), NOW, { gate: 'agreement' });

    const stored = (await storedSet(TODAY)) as PublishedSet;
    expect(stored.questions[0]?.acceptedAnswers).toEqual([moved.answer]);
    expect(stored.questions[0]?.commonWrongAnswers).toEqual(q0.commonWrongAnswers.slice(1));
    expect(lines('shared_set_annotation')[0]).toMatchObject({ outcome: 'annotated', added: 1, moved: 1 });
    // The checkers' "reject" is a finding for the owner, never a change to the set.
    const review = JSON.parse((await env.DAILY_SETS_KV.get(reviewKey(TODAY))) as string) as ReviewRecord;
    expect(review.findings.map((f) => f.code)).toEqual(['checker_verdict', 'checker_verdict']);
  });

  it('checks the nearest unchecked set before generating a missing later date, one thing per run', async () => {
    const questions = questionsFor(PLAN);
    await publish(TODAY, questions);
    const byModel: Record<string, unknown> = {};
    for (const m of ANNOTATION_CHECKERS.agreement) byModel[m] = reviewOf(questions);
    respondByModel(byModel);

    await runSharedGeneration(withCheck(), NOW, { gate: 'agreement' });
    expect(sentModels()).toEqual([...ANNOTATION_CHECKERS.agreement]);
    expect(await storedSet(dateAt(1))).toBeNull();

    // The next hour: today is checked, so the run generates the next date.
    respond = async () => anthropicBody(validSetFor(dailyPlan(dateAt(1))));
    await runSharedGeneration(withCheck(), at(1), { gate: 'agreement' });
    expect(fetchCalls).toHaveLength(ANNOTATION_CHECKERS.agreement.length + 1);
    expect(await storedSet(dateAt(1))).toMatchObject({ date: dateAt(1), promptVersion: 3 });
    expect((await storedSet(dateAt(1)))?.checkedAt).toBeUndefined();
  });

  it('skips a checked set with one KV read, and never checks when the switch is off', async () => {
    const questions = questionsFor(PLAN);
    await publish(TODAY, questions, { checkedAt: '2026-10-05T01:07:00.000Z' });
    for (const offset of [1, 2, 3]) await publish(dateAt(offset), questionsFor(dailyPlan(dateAt(offset))), { checkedAt: 'x' });
    const sets = counting(env.DAILY_SETS_KV);
    await runSharedGeneration(withCheck({ DAILY_SETS_KV: sets.kv }), NOW);
    expect(fetchCalls).toHaveLength(0);
    expect(sets.counts).toEqual({ get: 4, put: 0, list: 0, delete: 0 });

    await publish(TODAY, questions); // unchecked again
    for (const value of ['false', '', 'TRUE']) {
      await runSharedGeneration(envWith({ SHARED_SET_CHECK_ENABLED: value }), NOW);
    }
    expect(fetchCalls).toHaveLength(0);
    expect((await storedSet(TODAY))?.checkedAt).toBeUndefined();
  });

  it(`counts a check before the call, holds the date for ${checkLeaseMs('agreement') / 1000} s, and gives up after ${MAX_CHECKS_PER_DATE} unreadable or failed checks`, async () => {
    const questions = questionsFor(PLAN);
    await publish(TODAY, questions);
    await fillLaterDates();
    respond = async () => anthropicBody({ questions: [] }); // unreadable: wrong count

    await runSharedGeneration(withCheck(), NOW, { gate: 'agreement' });
    expect(JSON.parse((await env.DAILY_SETS_KV.get(attemptsKey(TODAY))) as string)).toEqual({
      count: 0,
      checks: 1,
      leaseUntil: NOW.getTime() + checkLeaseMs('agreement'),
    });
    expect(checkLeaseMs('agreement')).toBe(2 * CHECK_TIMEOUT_MS + 30_000);
    expect((await storedSet(TODAY))?.checkedAt).toBeUndefined();
    expect(lines('shared_set_annotation')[0]).toMatchObject({ outcome: 'unreadable', check: 1, failed_model: 'claude-opus-5-5' });

    // Both checkers were called before the output was read. Within the
    // lease: nothing. After it: the second check. Then no more.
    expect(fetchCalls).toHaveLength(2);
    await runSharedGeneration(withCheck(), new Date(NOW.getTime() + 60_000), { gate: 'agreement' });
    expect(fetchCalls).toHaveLength(2);
    await runSharedGeneration(withCheck(), at(1), { gate: 'agreement' });
    expect(fetchCalls).toHaveLength(4);
    await runSharedGeneration(withCheck(), at(2), { gate: 'agreement' });
    await runSharedGeneration(withCheck(), at(3), { gate: 'agreement' });
    expect(fetchCalls).toHaveLength(4);
    expect(lines('shared_set_annotation').map((l) => l.check)).toEqual([1, 2]);
    expect((await storedSet(TODAY))?.checkedAt).toBeUndefined();
  });

  it('logs a checker timeout as upstream_failed with the model, leaves the set untouched and counts the check', async () => {
    const questions = questionsFor(PLAN);
    const before = await publish(TODAY, questions);
    await fillLaterDates();
    respond = (init) =>
      new Promise<Response>((_, reject) => {
        init?.signal?.addEventListener('abort', () => reject(new Error('aborted')));
      });

    await runSharedGeneration(withCheck(), NOW, { gate: 'single_review', checkTimeoutMs: 20 });

    expect(lines('shared_set_annotation')).toEqual([
      expect.objectContaining({ outcome: 'upstream_failed', failure: 'timeout', failed_model: 'claude-opus-5-5', check: 1, input_tokens: null }),
    ]);
    expect(await storedSet(TODAY)).toEqual(before);
    expect(JSON.parse((await env.DAILY_SETS_KV.get(attemptsKey(TODAY))) as string)).toMatchObject({ checks: 1 });
  });

  it('writes nothing when the set changed while the checkers were working', async () => {
    const questions = questionsFor(PLAN);
    await publish(TODAY, questions);
    let release: (r: Response) => void = () => {};
    respond = () => new Promise<Response>((resolve) => (release = resolve));

    const run = runSharedGeneration(withCheck(), NOW, { gate: 'single_review' });
    while (fetchCalls.length === 0) await new Promise((r) => setTimeout(r, 1));
    const replaced = await publish(TODAY, questionsFor(PLAN, 'b'));
    release(anthropicBody(reviewOf(questions, { [(questions[0] as SharedQuestion).id]: { acceptableAlternatives: ['x'] } })));
    await run;

    expect(await storedSet(TODAY)).toEqual(replaced);
    expect(lines('shared_set_annotation')[0]).toMatchObject({ outcome: 'set_changed' });
  });

  it(`stores the set for ${SET_TTL_SECONDS / 86400} days again and the review for ${REVIEW_TTL_SECONDS / 86400}`, async () => {
    const questions = questionsFor(PLAN);
    const q0 = questions[0] as SharedQuestion;
    await publish(TODAY, questions);
    respondByModel({ 'claude-opus-5-5': reviewOf(questions, { [q0.id]: { incorrectRuleFields: ['hint'] } }) });
    const puts: { key: string; options?: KVNamespacePutOptions }[] = [];
    const kv = {
      ...env.DAILY_SETS_KV,
      get: env.DAILY_SETS_KV.get.bind(env.DAILY_SETS_KV),
      put: (key: string, value: string, options?: KVNamespacePutOptions) => {
        puts.push({ key, options });
        return env.DAILY_SETS_KV.put(key, value, options);
      },
    } as unknown as KVNamespace;

    await runSharedGeneration(withCheck({ DAILY_SETS_KV: kv }), NOW, { gate: 'single_review' });

    expect(puts.map((p) => [p.key, p.options?.expirationTtl])).toEqual([
      [attemptsKey(TODAY), ATTEMPTS_TTL_SECONDS],
      [setKey(TODAY), SET_TTL_SECONDS],
      [reviewKey(TODAY), REVIEW_TTL_SECONDS],
    ]);
    const review = JSON.parse((await env.DAILY_SETS_KV.get(reviewKey(TODAY))) as string) as ReviewRecord;
    expect(review).toEqual({
      date: TODAY,
      checkedAt: NOW.toISOString(),
      gate: 'single_review',
      models: ['claude-opus-5-5'],
      findings: [{ questionId: q0.id, code: 'wrong_rule', model: 'claude-opus-5-5', answers: ['hint'] }],
    });
  });

  it('never logs a question, an answer or a finding\'s text, and the line has only its fixed fields', async () => {
    const questions = questionsFor(PLAN);
    const q0 = questions[0] as SharedQuestion;
    await publish(TODAY, questions);
    respondByModel({ 'claude-opus-5-5': reviewOf(questions, { [q0.id]: { acceptableAlternatives: [`${CONTENT_SECRET} alt`], verdict: 'pass_with_alternatives' } }) });

    await runSharedGeneration(withCheck(), NOW, { gate: 'single_review' });

    expect(logged.some((l) => l.includes(CONTENT_SECRET))).toBe(false);
    expect(logged.some((l) => l.includes('alt'))).toBe(false);
    const [line] = lines('shared_set_annotation');
    expect(Object.keys(line as object).sort()).toEqual(
      ['event', 'date', 'check', 'outcome', 'gate', 'models', 'failure', 'failed_model', 'input_tokens', 'output_tokens', 'duration_ms', 'check_version', 'added', 'moved', 'findings'].sort(),
    );
    expect(line).toMatchObject({ input_tokens: 1500, output_tokens: 1400 });
  });

  it('is "true" or "false" in wrangler.jsonc: either is a valid live setting', () => {
    const match = wranglerSource.match(/"SHARED_SET_CHECK_ENABLED"\s*:\s*"([^"]*)"/g) ?? [];
    expect(match).toHaveLength(1);
    expect(['"true"', '"false"']).toContain((match[0] as string).split(':')[1]?.trim());
  });

  it('never touches the quota', async () => {
    const questions = questionsFor(PLAN);
    await publish(TODAY, questions);
    respondByModel({ 'claude-opus-5-5': reviewOf(questions) });
    const quota = counting(env.QUOTA_KV);

    await runSharedGeneration(withCheck({ QUOTA_KV: quota.kv }), NOW, { gate: 'single_review' });

    expect(quota.counts).toEqual({ get: 0, put: 0, list: 0, delete: 0 });
  });
});
