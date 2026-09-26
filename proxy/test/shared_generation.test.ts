import { createExecutionContext, createScheduledController, env, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import worker from '../src/index';
import { dailyPlan, dateOfDayNumber, dayNumberOf, type DailyPlan } from '../src/shared_daily_test';
import {
  ATTEMPTS_TTL_SECONDS,
  GENERATION_TIMEOUT_MS,
  MAX_ATTEMPTS_PER_DATE,
  SET_TTL_SECONDS,
  attemptsKey,
  runSharedGeneration,
  setKey,
  type PublishedSet,
} from '../src/shared_generation';
import type { Env } from '../src/types';

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

function envWith(overrides: Partial<Env>): Env {
  return { ...env, ...overrides } as Env;
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
  it('generates a missing date once, in plan order, and a second run makes no request', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));

    await runSharedGeneration(env, NOW);

    expect(fetchCalls).toHaveLength(1);
    expect(fetchCalls[0]?.url).toBe('https://api.anthropic.com/v1/messages');
    const set = await storedSet(PLUS_3);
    expect(set).toMatchObject({ date: PLUS_3, promptVersion: 1, attempt: 1, generatedAt: NOW.toISOString() });
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
        prompt_version: 1,
      },
    ]);
    // The ordinary cost line is written too, filed as Daily Test cost.
    expect(lines('anthropic_usage')).toEqual([
      expect.objectContaining({ kind: 'daily_test', operation: 'generate_shared_daily_test', item_count: 5 }),
    ]);

    const before = await env.DAILY_SETS_KV.get(setKey(PLUS_3));
    await runSharedGeneration(env, at(1));
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
      await runSharedGeneration(env, at(run));
      // At most one Anthropic call per run, even with several dates missing.
      expect(fetchCalls).toHaveLength(run + 1);
    }

    expect(lines('shared_set_generation').map((l) => l.date)).toEqual([0, 1, 2, 3].map(dateAt));
    for (const offset of [0, 1, 2, 3]) expect(await storedSet(dateAt(offset))).not.toBeNull();

    await runSharedGeneration(env, at(4));
    expect(fetchCalls).toHaveLength(4);
  });

  it(`stops after attempt ${MAX_ATTEMPTS_PER_DATE}; a rejected set is never written and its reason is logged`, async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    const plan = dailyPlan(PLUS_3);
    const short = { questions: validSetFor(plan).questions.slice(0, 4) };
    respond = async () => anthropicBody(short);

    for (let run = 0; run < 5; run++) await runSharedGeneration(env, at(run));

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

    await runSharedGeneration(env, NOW);
    await runSharedGeneration(env, at(1));

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

    const run = runSharedGeneration(env, NOW);
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

    await runSharedGeneration(env, NOW, { timeoutMs: 20 });

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

    await runSharedGeneration(env, NOW);

    expect(GENERATION_TIMEOUT_MS).toBe(90_000);
    expect(fetchCalls[0]?.init?.signal).toBeInstanceOf(AbortSignal);
    expect(fetchCalls[0]?.init?.signal?.aborted).toBe(false);
  });

  it('logs an Anthropic error as upstream_failed with its category', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () =>
      new Response(JSON.stringify({ type: 'error', error: { type: 'overloaded_error' } }), { status: 529 });

    await runSharedGeneration(env, NOW);

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

    await runSharedGeneration(env, NOW);

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

    await runSharedGeneration(env, NOW);

    const content = String(JSON.parse(String(fetchCalls[0]?.init?.body)).messages[0].content);
    expect(content).toContain('"recent 2", "recent 1", "recent 0"');
    expect(content).toContain('"a week ago"');
    expect(content).not.toContain('too old');
  });

  it(`stores sets for ${SET_TTL_SECONDS / 86400} days and attempt records for ${ATTEMPTS_TTL_SECONDS / 86400}`, async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));
    const nowSeconds = Date.now() / 1000;

    await runSharedGeneration(env, NOW);

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

    it('is on in wrangler.jsonc', () => {
      expect(env.SHARED_DAILY_TEST_ENABLED).toBe('true');
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

    await runSharedGeneration(env, NOW);
    await runSharedGeneration(env, at(1));

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
          'event',
          'failure',
          'input_tokens',
          'outcome',
          'output_tokens',
          'prompt_version',
          'reason',
          'stop_reason',
        ].sort(),
      );
    }
  });

  it('runs from the Worker\'s scheduled handler, using the trigger\'s scheduled time', async () => {
    for (const offset of [0, 1, 2]) await seed(dateAt(offset));
    respond = async () => anthropicBody(validSetFor(dailyPlan(PLUS_3)));
    const controller = createScheduledController({ scheduledTime: NOW.getTime(), cron: '7 * * * *' });
    const ctx = createExecutionContext();

    await worker.scheduled(controller, env);
    await waitOnExecutionContext(ctx);

    expect(fetchCalls).toHaveLength(1);
    expect(await storedSet(PLUS_3)).toMatchObject({ date: PLUS_3, generatedAt: NOW.toISOString() });
    expect(TODAY).toBe('2026-10-05');
  });
});
