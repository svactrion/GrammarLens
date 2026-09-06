import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

const TOKEN = 'test-app-token'; // matches vitest.config.ts's miniflare.bindings

function post(path: string, body: unknown, headers: Record<string, string> = {}) {
  return SELF.fetch(`https://proxy.example${path}`, {
    method: 'POST',
    headers: { 'content-type': 'application/json', 'x-grammarlens-token': TOKEN, ...headers },
    body: JSON.stringify(body),
  });
}

// SELF (the worker under test) runs in the same isolate/global scope as
// this test file (per @cloudflare/vitest-pool-workers' own docs), so
// replacing the ambient `fetch` here intercepts the worker's own outbound
// call to Anthropic — no real network call, no undici-mocking dependency.
const originalFetch = globalThis.fetch;
let fetchCalls: { url: string; init?: RequestInit }[] = [];
let nextResponse: (() => Response) | null = null;

function mockAnthropicOnce(respond: () => Response) {
  nextResponse = respond;
}

function mockAnthropicSuccess(payload: unknown) {
  mockAnthropicOnce(
    () => new Response(JSON.stringify({ content: [{ type: 'text', text: JSON.stringify(payload) }] }), { status: 200 }),
  );
}

beforeEach(async () => {
  const list = await env.QUOTA_KV.list();
  await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
  fetchCalls = [];
  nextResponse = null;
  globalThis.fetch = (async (url: string | URL | Request, init?: RequestInit) => {
    fetchCalls.push({ url: String(url), init });
    if (!nextResponse) {
      throw new Error(`Unexpected outbound fetch to ${String(url)} — no mock installed for this test.`);
    }
    return nextResponse();
  }) as typeof fetch;
});

afterEach(() => {
  globalThis.fetch = originalFetch;
});

describe('GET /health', () => {
  it('responds ok without any auth', async () => {
    const response = await SELF.fetch('https://proxy.example/health');
    expect(response.status).toBe(200);
  });
});

describe('unknown routes', () => {
  it('404s a GET to a real operation path', async () => {
    const response = await SELF.fetch('https://proxy.example/v1/generate-practice-set');
    expect(response.status).toBe(404);
  });

  it('404s an unrecognized path', async () => {
    const response = await post('/v1/not-a-real-operation', {});
    expect(response.status).toBe(404);
  });
});

describe('auth', () => {
  it('rejects a request with no token', async () => {
    const response = await post(
      '/v1/generate-practice-set',
      { deviceId: 'd1', topicId: 'articles', count: 5 },
      { 'x-grammarlens-token': '' },
    );
    expect(response.status).toBe(401);
    expect((await response.json())).toMatchObject({ error: 'unauthorized' });
  });

  it('rejects a request with the wrong token', async () => {
    const response = await SELF.fetch('https://proxy.example/v1/generate-practice-set', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-grammarlens-token': 'wrong' },
      body: JSON.stringify({ deviceId: 'd1', topicId: 'articles', count: 5 }),
    });
    expect(response.status).toBe(401);
  });
});

describe('POST /v1/generate-practice-set', () => {
  it('returns the items Anthropic produced, on a valid request', async () => {
    mockAnthropicSuccess({ items: [{ id: 'q1', type: 'fill_in_blank', instruction: 'Fill it in.' }] });

    const response = await post('/v1/generate-practice-set', {
      deviceId: 'd1',
      topicId: 'articles',
      count: 5,
    });

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      items: [{ id: 'q1', type: 'fill_in_blank', instruction: 'Fill it in.' }],
    });
  });

  it('sends its own API key to Anthropic, and never the client\'s deviceId or app token', async () => {
    mockAnthropicSuccess({ items: [] });

    await post('/v1/generate-practice-set', { deviceId: 'super-secret-device-id', topicId: 'articles', count: 5 });

    expect(fetchCalls).toHaveLength(1);
    const call = fetchCalls[0];
    if (!call) throw new Error('expected a fetch call to have been recorded');
    expect(call.url).toBe('https://api.anthropic.com/v1/messages');
    expect(call.init?.headers).toMatchObject({ 'x-api-key': env.ANTHROPIC_API_KEY });
    expect(call.init?.body).not.toContain('super-secret-device-id');
    expect(call.init?.body).not.toContain(TOKEN);
  });

  it('rejects invalid input with 400 before ever calling Anthropic', async () => {
    // No mock installed — a call to Anthropic here would throw via the
    // "Unexpected outbound fetch" guard in beforeEach, failing this test.
    const response = await post('/v1/generate-practice-set', {
      deviceId: 'd1',
      topicId: 'not_a_real_topic',
      count: 5,
    });
    expect(response.status).toBe(400);
    expect((await response.json())).toMatchObject({ error: 'invalid_request' });
  });

  it('never forwards Anthropic\'s raw error body to the client', async () => {
    mockAnthropicOnce(
      () =>
        new Response(
          JSON.stringify({ type: 'error', error: { type: 'api_error', message: 'some internal Anthropic detail' } }),
          { status: 500 },
        ),
    );

    const response = await post('/v1/generate-practice-set', {
      deviceId: 'd1',
      topicId: 'articles',
      count: 5,
    });

    expect(response.status).toBe(502);
    const json = (await response.json()) as { error: string; message: string };
    expect(json.error).toBe('upstream_error');
    expect(json.message).not.toContain('some internal Anthropic detail');
  });
});

describe('POST /v1/generate-daily-test', () => {
  it('returns the questions Anthropic produced', async () => {
    mockAnthropicSuccess({
      questions: [
        {
          id: 'q1',
          type: 'fill_in_blank',
          instruction: 'Fill it in.',
          topicId: 'articles',
          correctAnswer: 'the',
          commonWrongAnswers: [],
        },
      ],
    });

    const response = await post('/v1/generate-daily-test', {
      deviceId: 'd1',
      count: 5,
      weakSpots: [{ topicId: 'articles', frequency: 2 }],
    });

    expect(response.status).toBe(200);
    const json = (await response.json()) as { questions: unknown[] };
    expect(json.questions).toHaveLength(1);
  });
});

describe('POST /v1/score-answers', () => {
  it('returns the feedback Anthropic produced', async () => {
    mockAnthropicSuccess({
      feedback: [
        {
          itemId: 'q1',
          isCorrect: true,
          correctedAnswer: 'the cat',
          explanation: 'Looks right.',
        },
      ],
    });

    const response = await post('/v1/score-answers', {
      deviceId: 'd1',
      items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'I saw ___ cat.', userAnswer: 'the' }],
    });

    expect(response.status).toBe(200);
  });

  it('instructs the model not to score Turkish-keyboard letter variants as grammar mistakes', async () => {
    mockAnthropicSuccess({ feedback: [] });

    await post('/v1/score-answers', {
      deviceId: 'd1',
      items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'I saw ___ cat.', userAnswer: 'the' }],
    });

    expect(fetchCalls).toHaveLength(1);
    const body = JSON.parse(String(fetchCalls[0]?.init?.body)) as { system: string };
    // The letter-substitution instruction itself, and the explicit carve-out
    // so a real one-character grammar difference is still never excused.
    expect(body.system).toContain('ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u');
    expect(body.system).toContain('stay');
  });
});

describe('quota', () => {
  it('rejects with 429 once the device daily limit is reached, without calling Anthropic again', async () => {
    const limit = Number.parseInt(env.DEVICE_DAILY_LIMIT, 10);
    for (let i = 0; i < limit; i++) {
      mockAnthropicSuccess({ items: [] });
      const ok = await post('/v1/generate-practice-set', {
        deviceId: 'quota-device',
        topicId: 'articles',
        count: 5,
      });
      expect(ok.status).toBe(200);
    }

    const rejected = await post('/v1/generate-practice-set', {
      deviceId: 'quota-device',
      topicId: 'articles',
      count: 5,
    });
    expect(rejected.status).toBe(429);
    const json = (await rejected.json()) as { error: string; scope: string };
    expect(json).toMatchObject({ error: 'quota_exceeded', scope: 'device' });
  });
});
