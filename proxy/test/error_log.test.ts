import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

const TOKEN = 'test-app-token'; // matches vitest.config.ts's miniflare.bindings
const SECRET = 'USER-TEXT-SECRET-4417';

function post(path: string, body: unknown) {
  return SELF.fetch(`https://proxy.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-grammarlens-token': TOKEN },
    body: JSON.stringify(body),
  });
}

const originalFetch = globalThis.fetch;
const originalConsole = { log: console.log, info: console.info, warn: console.warn, error: console.error };
let logged: string[] = [];

function upstreamReturns(response: () => Response) {
  globalThis.fetch = (async () => response()) as typeof fetch;
}

function upstreamThrows(error: Error) {
  globalThis.fetch = (async () => {
    throw error;
  }) as typeof fetch;
}

function failureLines(): Record<string, unknown>[] {
  return logged
    .filter((line) => line.includes('anthropic_failure'))
    .map((line) => JSON.parse(line) as Record<string, unknown>);
}

const practiceRequest = { deviceId: 'd1', topicId: 'articles', count: 5 };

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

describe('upstream failure logging', () => {
  it('logs status, Anthropic error type and operation for a non-200, never the body', async () => {
    upstreamReturns(
      () =>
        new Response(
          JSON.stringify({ type: 'error', error: { type: 'rate_limit_error', message: `echoed: ${SECRET}` } }),
          { status: 429 },
        ),
    );

    const response = await post('/v1/generate-practice-set', practiceRequest);

    expect(response.status).toBe(502);
    expect(JSON.stringify(await response.json())).not.toContain(SECRET);
    expect(failureLines()).toEqual([
      {
        event: 'anthropic_failure',
        kind: 'topic_practice',
        operation: 'generate_practice_set',
        failure: 'http_error',
        http_status: 429,
        upstream_error_type: 'rate_limit_error',
        duration_ms: expect.any(Number),
      },
    ]);
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  it('classifies each operation: daily_test versus topic_practice', async () => {
    upstreamReturns(() => new Response('{}', { status: 500 }));
    await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });
    await post('/v1/score-answers', {
      deviceId: 'd1',
      items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'p', userAnswer: 'a' }],
    });

    expect(failureLines().map((l) => [l.operation, l.kind, l.http_status])).toEqual([
      ['generate_daily_test', 'daily_test', 500],
      ['score_answers', 'topic_practice', 500],
    ]);
  });

  it('only ever logs an error type from the known list', async () => {
    upstreamReturns(
      () => new Response(JSON.stringify({ error: { type: `made_up_${SECRET}`, message: SECRET } }), { status: 400 }),
    );
    await post('/v1/generate-practice-set', practiceRequest);

    expect(failureLines()[0]).toMatchObject({ http_status: 400, upstream_error_type: 'unknown' });
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  it('logs unknown for a non-JSON error body, without the body', async () => {
    upstreamReturns(() => new Response(`<html>${SECRET}</html>`, { status: 503 }));
    await post('/v1/generate-practice-set', practiceRequest);

    expect(failureLines()[0]).toMatchObject({ http_status: 503, upstream_error_type: 'unknown' });
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  it('logs invalid_json_content without the parse exception that quotes the text', async () => {
    upstreamReturns(
      () =>
        new Response(
          JSON.stringify({
            content: [{ type: 'text', text: `not json ${SECRET}` }],
            usage: { input_tokens: 5, output_tokens: 6 },
          }),
          { status: 200 },
        ),
    );

    const response = await post('/v1/generate-practice-set', practiceRequest);

    expect(response.status).toBe(502);
    expect(failureLines()).toEqual([
      {
        event: 'anthropic_failure',
        kind: 'topic_practice',
        operation: 'generate_practice_set',
        failure: 'invalid_json_content',
        http_status: 200,
        upstream_error_type: null,
        duration_ms: expect.any(Number),
      },
    ]);
    expect(logged.join('\n')).not.toContain(SECRET);
    // The billed call is still measured.
    expect(logged.some((line) => line.includes('anthropic_usage'))).toBe(true);
  });

  it('logs no_text_block for a 200 without text content', async () => {
    upstreamReturns(() => new Response(JSON.stringify({ content: [] }), { status: 200 }));
    await post('/v1/generate-practice-set', practiceRequest);

    expect(failureLines()[0]).toMatchObject({ failure: 'no_text_block', http_status: 200 });
  });

  it('logs unreadable_body for a 200 that is not JSON, without the body', async () => {
    upstreamReturns(() => new Response(`garbage ${SECRET}`, { status: 200 }));

    const response = await post('/v1/generate-practice-set', practiceRequest);

    expect(response.status).toBe(502);
    expect(failureLines()[0]).toMatchObject({ failure: 'unreadable_body', http_status: 200 });
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  it('logs network_error without the exception message', async () => {
    upstreamThrows(new Error(`connect failed near ${SECRET}`));

    const response = await post('/v1/generate-practice-set', practiceRequest);

    expect(response.status).toBe(502);
    expect(failureLines()[0]).toMatchObject({ failure: 'network_error', http_status: null });
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  describe('duration_ms on failures', () => {
    const realNow = Date.now;
    let clock = 5_000_000;
    beforeEach(() => {
      clock = 5_000_000;
      Date.now = () => clock;
    });
    afterEach(() => {
      Date.now = realNow;
    });

    it('records how long a non-200 took to arrive', async () => {
      upstreamReturns(() => {
        clock += 30_000;
        return new Response('{}', { status: 529 });
      });

      await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

      expect(failureLines()[0]).toMatchObject({ failure: 'http_error', http_status: 529, duration_ms: 30_000 });
    });

    it('records how long a network failure took to fail', async () => {
      globalThis.fetch = (async () => {
        clock += 45_000;
        throw new Error(`timed out near ${SECRET}`);
      }) as typeof fetch;

      await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

      expect(failureLines()[0]).toMatchObject({ failure: 'network_error', duration_ms: 45_000 });
      expect(logged.join('\n')).not.toContain(SECRET);
    });
  });

  it('logs only the allowed fields on every failure line', async () => {
    upstreamReturns(() => new Response('{}', { status: 500 }));
    await post('/v1/generate-practice-set', practiceRequest);

    expect(Object.keys(failureLines()[0] ?? {}).sort()).toEqual(
      ['duration_ms', 'event', 'failure', 'http_status', 'kind', 'operation', 'upstream_error_type'].sort(),
    );
  });
});

describe('unhandled error logging', () => {
  /** A fetch result whose `status` getter throws, so the failure happens
   * outside every handled Anthropic path and reaches the catch-all. */
  function upstreamBreaksUnexpectedly(thrown: unknown) {
    globalThis.fetch = (async () => ({
      get status(): number {
        throw thrown;
      },
    })) as unknown as typeof fetch;
  }

  function unhandledLines(): Record<string, unknown>[] {
    return logged
      .filter((line) => line.includes('unhandled_error'))
      .map((line) => JSON.parse(line) as Record<string, unknown>);
  }

  it('logs only the error category and the operation, never the message or stack', async () => {
    upstreamBreaksUnexpectedly(new TypeError(`bad thing with ${SECRET}`));

    const response = await post('/v1/generate-practice-set', { ...practiceRequest, deviceId: `${SECRET}-device` });

    expect(response.status).toBe(500);
    expect(await response.json()).toMatchObject({ error: 'internal_error' });
    expect(unhandledLines()).toEqual([
      {
        event: 'unhandled_error',
        kind: 'topic_practice',
        operation: 'generate_practice_set',
        error: 'TypeError',
      },
    ]);
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  it('classifies the operation for a daily test', async () => {
    upstreamBreaksUnexpectedly(new Error('x'));
    await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

    expect(unhandledLines()[0]).toMatchObject({ kind: 'daily_test', operation: 'generate_daily_test', error: 'Error' });
  });

  it('never echoes a custom error name or a thrown string', async () => {
    const custom = new Error('m');
    custom.name = `Custom${SECRET}`;
    upstreamBreaksUnexpectedly(custom);
    await post('/v1/generate-practice-set', practiceRequest);
    upstreamBreaksUnexpectedly(`thrown text ${SECRET}`);
    await post('/v1/generate-practice-set', practiceRequest);

    expect(unhandledLines().map((l) => l.error)).toEqual(['other_error', 'non_error']);
    expect(logged.join('\n')).not.toContain(SECRET);
  });

  it('logs only the allowed fields', async () => {
    upstreamBreaksUnexpectedly(new RangeError('r'));
    await post('/v1/generate-practice-set', practiceRequest);

    expect(Object.keys(unhandledLines()[0] ?? {}).sort()).toEqual(['error', 'event', 'kind', 'operation']);
  });

  it('a handled ProxyError still answers as before and logs no unhandled line', async () => {
    const response = await post('/v1/generate-practice-set', { deviceId: '', topicId: 'articles', count: 5 });

    expect(response.status).toBe(400);
    expect(unhandledLines()).toEqual([]);
  });
});
