import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

const TOKEN = 'test-app-token'; // matches vitest.config.ts's miniflare.bindings

function post(path: string, body: unknown) {
  return SELF.fetch(`https://proxy.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-grammarlens-token': TOKEN },
    body: JSON.stringify(body),
  });
}

// Same in-isolate interception the other proxy tests use (see index.test.ts).
const originalFetch = globalThis.fetch;
const originalConsole = { log: console.log, info: console.info, warn: console.warn, error: console.error };
let logged: string[] = [];

function anthropicResponds(payload: unknown, usage?: unknown) {
  globalThis.fetch = (async () =>
    new Response(
      JSON.stringify({
        content: [{ type: 'text', text: typeof payload === 'string' ? payload : JSON.stringify(payload) }],
        ...(usage === undefined ? {} : { usage }),
      }),
      { status: 200 },
    )) as typeof fetch;
}

/** Only the structured usage lines, parsed. */
function usageLines(): Record<string, unknown>[] {
  return logged
    .filter((line) => line.includes('anthropic_usage'))
    .map((line) => JSON.parse(line) as Record<string, unknown>);
}

beforeEach(async () => {
  const list = await env.QUOTA_KV.list();
  await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
  logged = [];
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

describe('token usage logging', () => {
  it('logs a daily_test call with its real input/output tokens', async () => {
    anthropicResponds({ questions: [] }, { input_tokens: 1234, output_tokens: 567 });

    const response = await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

    expect(response.status).toBe(200);
    expect(usageLines()).toEqual([
      {
        event: 'anthropic_usage',
        kind: 'daily_test',
        operation: 'generate_daily_test',
        item_count: 5,
        input_tokens: 1234,
        output_tokens: 567,
        duration_ms: expect.any(Number),
      },
    ]);
  });

  it('logs both calls of a practice session as topic_practice, told apart by operation', async () => {
    anthropicResponds({ items: [] }, { input_tokens: 900, output_tokens: 1700 });
    await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 3 });

    anthropicResponds({ feedback: [] }, { input_tokens: 1100, output_tokens: 400 });
    await post('/v1/score-answers', {
      deviceId: 'd1',
      items: [
        { id: 'q1', type: 'fill_in_blank', prompt: 'p1', userAnswer: 'a1' },
        { id: 'q2', type: 'fill_in_blank', prompt: 'p2', userAnswer: '' },
      ],
    });

    expect(usageLines()).toEqual([
      {
        event: 'anthropic_usage',
        kind: 'topic_practice',
        operation: 'generate_practice_set',
        item_count: 3,
        input_tokens: 900,
        output_tokens: 1700,
        duration_ms: expect.any(Number),
      },
      {
        event: 'anthropic_usage',
        kind: 'topic_practice',
        operation: 'score_answers',
        item_count: 2,
        input_tokens: 1100,
        output_tokens: 400,
        duration_ms: expect.any(Number),
      },
    ]);
  });

  it('never logs anything the user wrote, their device id, or the generated text', async () => {
    const secrets = [
      'DEVICE-SECRET-8841',
      'USER-ANSWER-SECRET-5520',
      'PROMPT-SECRET-3307',
      'GENERATED-SECRET-7712',
    ];
    anthropicResponds({ feedback: [{ explanation: secrets[3] }] }, { input_tokens: 10, output_tokens: 20 });
    const scored = await post('/v1/score-answers', {
      deviceId: secrets[0],
      items: [{ id: 'q1', type: 'sentence_writing', prompt: secrets[2], userAnswer: secrets[1] }],
    });
    anthropicResponds({ questions: [{ instruction: secrets[3] }] }, { input_tokens: 10, output_tokens: 20 });
    const daily = await post('/v1/generate-daily-test', {
      deviceId: secrets[0],
      count: 5,
    });

    expect(scored.status).toBe(200);
    expect(daily.status).toBe(200);
    expect(usageLines()).toHaveLength(2);
    // Every console channel, not just the usage line.
    const everything = logged.join('\n');
    for (const secret of secrets) expect(everything).not.toContain(secret);
    // The usage line has exactly the allowed fields and nothing else.
    for (const line of usageLines()) {
      expect(Object.keys(line).sort()).toEqual(
        ['duration_ms', 'event', 'input_tokens', 'item_count', 'kind', 'operation', 'output_tokens'].sort(),
      );
    }
  });

  it('logs nulls, and still answers normally, when Anthropic sends no usage object', async () => {
    anthropicResponds({ items: [] });

    const response = await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 5 });

    expect(response.status).toBe(200);
    expect(usageLines()).toEqual([
      {
        event: 'anthropic_usage',
        kind: 'topic_practice',
        operation: 'generate_practice_set',
        item_count: 5,
        input_tokens: null,
        output_tokens: null,
        duration_ms: expect.any(Number),
      },
    ]);
  });

  it('ignores non-numeric usage values instead of logging them', async () => {
    anthropicResponds({ items: [] }, { input_tokens: 'lots', output_tokens: { nested: true } });

    await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 5 });

    expect(usageLines()[0]).toMatchObject({ input_tokens: null, output_tokens: null });
  });

  it('still records the tokens of a billed call whose content turns out unusable', async () => {
    anthropicResponds('this is not json', { input_tokens: 50, output_tokens: 60 });

    const response = await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 5 });

    expect(response.status).toBe(502);
    expect(usageLines()).toHaveLength(1);
    expect(usageLines()[0]).toMatchObject({ input_tokens: 50, output_tokens: 60 });
  });

  describe('duration_ms', () => {
    const realNow = Date.now;
    let clock = 1_000_000;

    beforeEach(() => {
      clock = 1_000_000;
      Date.now = () => clock;
    });
    afterEach(() => {
      Date.now = realNow;
    });

    /** Anthropic answers after [ms] of (fake) wall time. */
    function anthropicTakes(ms: number, payload: unknown, usage?: unknown) {
      globalThis.fetch = (async () => {
        clock += ms;
        return new Response(
          JSON.stringify({ content: [{ type: 'text', text: JSON.stringify(payload) }], usage }),
          { status: 200 },
        );
      }) as typeof fetch;
    }

    it('logs how long the call to Anthropic took, in whole milliseconds', async () => {
      anthropicTakes(12_345, { questions: [] }, { input_tokens: 10, output_tokens: 20 });

      await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

      expect(usageLines()).toEqual([
        {
          event: 'anthropic_usage',
          kind: 'daily_test',
          operation: 'generate_daily_test',
          item_count: 5,
          input_tokens: 10,
          output_tokens: 20,
          duration_ms: 12_345,
        },
      ]);
    });

    it('times each call on its own', async () => {
      anthropicTakes(800, { items: [] });
      await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 3 });
      anthropicTakes(4_000, { feedback: [] });
      await post('/v1/score-answers', {
        deviceId: 'd1',
        items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'p', userAnswer: 'a' }],
      });

      expect(usageLines().map((l) => l.duration_ms)).toEqual([800, 4_000]);
    });

    it('is a plain number and never anything else (no text, no id)', async () => {
      anthropicTakes(5, { questions: [] });

      await post('/v1/generate-daily-test', { deviceId: 'DEVICE-SECRET-1', count: 5 });

      const line = usageLines()[0];
      expect(typeof line?.duration_ms).toBe('number');
      expect(logged.join('\n')).not.toContain('DEVICE-SECRET-1');
    });

    it('still records the duration of a billed call whose content turns out unusable', async () => {
      // A 200 whose text block is not valid JSON.
      globalThis.fetch = (async () => {
        clock += 7_000;
        return new Response(JSON.stringify({ content: [{ type: 'text', text: 'not json' }] }), { status: 200 });
      }) as typeof fetch;

      const response = await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 5 });

      expect(response.status).toBe(502);
      expect(usageLines()[0]).toMatchObject({ duration_ms: 7_000 });
    });
  });
});
