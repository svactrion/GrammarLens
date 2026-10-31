import { env, SELF } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { dailyTestMaxTokensFor, scoreMaxTokensFor } from '../src/anthropic';
import { LEGACY_DAILY_TEST_BODY_COUNT_5 } from './fixtures/legacy_daily_test_body';

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
  it('sends Anthropic exactly the bytes 1.0.0 got: the legacy route never changes (1.1.0 §1, Option A)', async () => {
    mockAnthropicSuccess({ questions: [] });

    const response = await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

    expect(response.status).toBe(200);
    expect(fetchCalls).toHaveLength(1);
    expect(String(fetchCalls[0]?.init?.body)).toBe(LEGACY_DAILY_TEST_BODY_COUNT_5);
    // The same bytes for another device: nothing about the caller goes in.
    mockAnthropicSuccess({ questions: [] });
    await post('/v1/generate-daily-test', { deviceId: 'another-device', count: 5 });
    expect(String(fetchCalls[1]?.init?.body)).toBe(LEGACY_DAILY_TEST_BODY_COUNT_5);
  });

  it('still returns the content unchanged and counts one quota unit', async () => {
    const content = { questions: [{ id: 'q1', anything: 'passes through as before' }] };
    mockAnthropicSuccess(content);

    const response = await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

    expect(await response.json()).toEqual(content);
    const keys = (await env.QUOTA_KV.list()).keys.map((k) => k.name);
    expect(keys.filter((k) => k.startsWith('d:'))).toHaveLength(1);
    const deviceKey = keys.find((k) => k.startsWith('d:')) as string;
    expect(await env.QUOTA_KV.get(deviceKey)).toBe('1');
  });

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
    });

    expect(response.status).toBe(200);
    const json = (await response.json()) as { questions: unknown[] };
    expect(json.questions).toHaveLength(1);
  });

  it('asks for a per-question explanation and passes it through unchanged', async () => {
    mockAnthropicSuccess({
      questions: [
        {
          id: 'q1',
          type: 'fill_in_blank',
          instruction: 'Fill it in.',
          topicId: 'articles',
          correctAnswer: 'the',
          explanation: "Use 'the' when there is only one of something.",
          commonWrongAnswers: [{ answer: 'a', comment: "Close, but 'the' is specific." }],
        },
      ],
    });

    const response = await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });

    expect(response.status).toBe(200);
    const sent = JSON.parse(String(fetchCalls[0]?.init?.body)) as {
      system: string;
      output_config: {
        format: {
          schema: {
            properties: {
              questions: {
                items: {
                  properties: Record<string, unknown>;
                  required: string[];
                };
              };
            };
          };
        };
      };
    };
    const question = sent.output_config.format.schema.properties.questions.items;
    expect(question.properties.explanation).toEqual({ type: 'string' });
    expect(question.required).toContain('explanation');
    // The predicted-wrong-answer structure is unchanged beside it.
    expect(question.required).toContain('commonWrongAnswers');
    expect(sent.system).toContain('"explanation"');

    const json = (await response.json()) as { questions: { explanation: string }[] };
    expect(json.questions[0]?.explanation).toBe("Use 'the' when there is only one of something.");
  });

  it('uses its own token budget, while practice generation keeps the shared one', async () => {
    mockAnthropicSuccess({ questions: [] });
    await post('/v1/generate-daily-test', { deviceId: 'd1', count: 5 });
    mockAnthropicSuccess({ items: [] });
    await post('/v1/generate-practice-set', { deviceId: 'd1', topicId: 'articles', count: 5 });

    expect(fetchCalls).toHaveLength(2);
    const daily = JSON.parse(String(fetchCalls[0]?.init?.body)) as { max_tokens: number; system: string };
    const practice = JSON.parse(String(fetchCalls[1]?.init?.body)) as { max_tokens: number };
    expect(daily.max_tokens).toBe(3072);
    expect(practice.max_tokens).toBe(2048);
    expect(daily.system).toContain('fewer than 25 words');
  });

  it('scales the Daily Test budget with the question count, within bounds', () => {
    expect(dailyTestMaxTokensFor(5)).toBe(3072);
    expect(dailyTestMaxTokensFor(10)).toBe(6144);
    expect(dailyTestMaxTokensFor(1)).toBe(1024);
  });

  it('rejects a weakSpots field with a 400 and never calls Anthropic', async () => {
    let upstreamCalls = 0;
    const originalFetch = globalThis.fetch;
    globalThis.fetch = (async () => {
      upstreamCalls++;
      return new Response('{}', { status: 200 });
    }) as typeof fetch;
    try {
      const response = await post('/v1/generate-daily-test', {
        deviceId: 'd1',
        count: 5,
        weakSpots: [{ topicId: 'articles', frequency: 2 }],
      });
      expect(response.status).toBe(400);
      expect(upstreamCalls).toBe(0);
    } finally {
      globalThis.fetch = originalFetch;
    }
  });

  it('sends the same prompt for every device, with nothing about the user in it', async () => {
    const bodies: string[] = [];
    const originalFetch = globalThis.fetch;
    globalThis.fetch = (async (_url: unknown, init?: RequestInit) => {
      bodies.push(String(init?.body));
      return new Response(
        JSON.stringify({ content: [{ type: 'text', text: JSON.stringify({ questions: [] }) }] }),
        { status: 200 },
      );
    }) as typeof fetch;
    try {
      await post('/v1/generate-daily-test', { deviceId: 'DEVICE-ONE-SECRET', count: 5 });
      await post('/v1/generate-daily-test', { deviceId: 'DEVICE-TWO-SECRET', count: 5 });
    } finally {
      globalThis.fetch = originalFetch;
    }
    expect(bodies).toHaveLength(2);
    expect(bodies[0]).toBe(bodies[1]);
    expect(bodies[0]).not.toContain('DEVICE-');
    expect(bodies[0]).toContain('varied general mix');
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

  it('instructs the model not to score keyboard-variant characters as grammar mistakes, on any keyboard (1.4.0 D3)', async () => {
    mockAnthropicSuccess({ feedback: [] });

    await post('/v1/score-answers', {
      deviceId: 'd1',
      items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'I saw ___ cat.', userAnswer: 'the' }],
    });

    expect(fetchCalls).toHaveLength(1);
    const body = JSON.parse(String(fetchCalls[0]?.init?.body)) as { system: string };
    // The letter-substitution instruction itself, and the explicit carve-out
    // so a real one-character grammar difference is still never excused.
    expect(body.system).toContain('é/e, ı/i, ü/u, ñ/n, ç/c');
    expect(body.system).toContain('full-width Latin letters');
    expect(body.system).not.toContain('Turkish');
    expect(body.system).toContain('stay');
  });
});

describe('POST /v1/score-answers — structured feedback (1.4.0 D11)', () => {
  const items = [
    { id: 'two', type: 'fill_in_blank', prompt: 'I enjoy ____ (swim) and ____ (run).\nFill in each blank.', userAnswer: 'I enjoy swimming (swim) and ____ (run).' },
    { id: 'ec', type: 'error_correction', prompt: 'He go home.\nRewrite the sentence.', userAnswer: 'He goes home.' },
  ];
  const entry = (index: number, accepted: boolean) => ({ index, correctAnswer: `c${index}`, accepted, note: `note ${index}` });

  it('asks for summary and blanks as required fields, next to the six fields every client reads', async () => {
    mockAnthropicSuccess({ feedback: [] });
    await post('/v1/score-answers', { deviceId: 'd1', items });
    const body = JSON.parse(String(fetchCalls[0]?.init?.body)) as {
      max_tokens: number;
      system: string;
      output_config: { format: { schema: { properties: { feedback: { items: { required: string[]; properties: Record<string, unknown> } } } } } };
    };
    const item = body.output_config.format.schema.properties.feedback.items;
    expect(item.required).toEqual(['itemId', 'isCorrect', 'correctedAnswer', 'explanation', 'summary', 'blanks']);
    expect(Object.keys(item.properties)).toEqual(['itemId', 'isCorrect', 'errorType', 'rule', 'correctedAnswer', 'explanation', 'summary', 'blanks']);
    expect(body.system).toContain('"blanks"');
    expect(body.system).toContain('"summary"');
    expect(body.system).toContain('at most two sentences');
    expect(body.max_tokens).toBe(scoreMaxTokensFor(2));
  });

  it('scales the output budget with the item count, never under the old 2,048', () => {
    expect(scoreMaxTokensFor(1)).toBe(2048);
    expect(scoreMaxTokensFor(5)).toBe(2048);
    expect(scoreMaxTokensFor(10)).toBe(4000);
    expect(scoreMaxTokensFor(20)).toBe(8000);
  });

  it('repairs the structured fields against the request before they go out: a miscounted item loses them, a contradicting verdict follows the blanks', async () => {
    mockAnthropicSuccess({
      feedback: [
        { itemId: 'two', isCorrect: true, correctedAnswer: 'x', explanation: 'long', summary: 's', blanks: [entry(0, true), entry(1, false)] },
        { itemId: 'ec', isCorrect: true, correctedAnswer: 'He goes home.', explanation: 'long', summary: 's', blanks: [entry(0, true), entry(1, true)] },
      ],
    });
    const response = await post('/v1/score-answers', { deviceId: 'd1', items });
    expect(response.status).toBe(200);
    const { feedback } = (await response.json()) as { feedback: Record<string, unknown>[] };
    expect(feedback[0]).toMatchObject({ itemId: 'two', isCorrect: false, summary: 's', blanks: [entry(0, true), entry(1, false)] });
    expect(feedback[1]).toEqual({ itemId: 'ec', isCorrect: true, correctedAnswer: 'He goes home.', explanation: 'long' });
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
