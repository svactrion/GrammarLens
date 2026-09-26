import { createExecutionContext, env, SELF, waitOnExecutionContext } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { dateOfDayNumber, setKey, utcDayNumber, type PublishedSet } from '../src/shared_daily_test';
import {
  SHARED_SET_CACHE_SECONDS,
  handleSharedSetRead,
  sharedSetCacheKey,
} from '../src/shared_read';
import type { Env } from '../src/types';
import authSource from '../src/auth.ts?raw';
import sharedDailyTestSource from '../src/shared_daily_test.ts?raw';
import sharedReadSource from '../src/shared_read.ts?raw';
import topicsSource from '../src/topics.ts?raw';
import typesSource from '../src/types.ts?raw';

const TOKEN = 'test-app-token'; // matches vitest.config.ts's miniflare.bindings

/** Dates relative to the real UTC today: the route reads the real clock. */
const dateAt = (offset: number, now = new Date()) => dateOfDayNumber(utcDayNumber(now) + offset);

function get(path: string, token: string | null = TOKEN) {
  return SELF.fetch(`https://proxy.example${path}`, {
    method: 'GET',
    headers: token === null ? {} : { 'x-grammarlens-token': token },
  });
}

function storedSet(date: string, tag = 'x'): PublishedSet {
  return {
    date,
    promptVersion: 1,
    generatedAt: '2026-10-01T00:07:00.000Z',
    attempt: 1,
    questions: [
      {
        id: `${tag}-q1`,
        type: 'fill_in_blank',
        context: 'We waited for ___ bus.',
        instruction: 'Fill in the blank.',
        topicId: 'articles',
        correctAnswer: 'the',
        explanation: "Use 'the' for the bus you both know.",
        commonWrongAnswers: [
          { answer: 'a', comment: "'A' is any bus." },
          { answer: 'an', comment: "'An' goes before a vowel sound." },
        ],
      },
    ],
  };
}

async function seed(date: string, tag = 'x') {
  await env.DAILY_SETS_KV.put(setKey(date), JSON.stringify(storedSet(date, tag)));
}

async function clear(kv: KVNamespace) {
  const list = await kv.list();
  await Promise.all(list.keys.map((k) => kv.delete(k.name)));
}

/** Records every call on a KV namespace. */
function countingKv(kv: KVNamespace) {
  const calls: { method: string; args: unknown[] }[] = [];
  const wrap =
    (method: 'get' | 'put' | 'list' | 'delete' | 'getWithMetadata') =>
    (...args: unknown[]) => {
      calls.push({ method, args });
      return (kv[method] as (...a: unknown[]) => unknown).apply(kv, args);
    };
  const wrapped = {
    get: wrap('get'),
    put: wrap('put'),
    list: wrap('list'),
    delete: wrap('delete'),
    getWithMetadata: wrap('getWithMetadata'),
  } as unknown as KVNamespace;
  return { kv: wrapped, calls };
}

/** Records every call on a Cache. */
function countingCache(cache: Cache) {
  const calls: { method: string; key: string; response?: Response }[] = [];
  const wrapped = {
    match: (key: Request, options?: CacheQueryOptions) => {
      calls.push({ method: 'match', key: key.url });
      return cache.match(key, options);
    },
    put: (key: Request, response: Response) => {
      calls.push({ method: 'put', key: key.url, response: response.clone() });
      return cache.put(key, response);
    },
    delete: (key: Request, options?: CacheQueryOptions) => {
      calls.push({ method: 'delete', key: key.url });
      return cache.delete(key, options);
    },
  } as unknown as Cache;
  return { cache: wrapped, calls };
}

function request(date: string, token: string | null = TOKEN): Request {
  return new Request(`https://proxy.example/v1/shared-daily-test/${date}`, {
    headers: token === null ? {} : { 'x-grammarlens-token': token },
  });
}

/** Calls the handler directly with counting KV and cache; returns the response
 * (or the thrown ProxyError's response) and what was touched. */
async function readDirect(date: string, options: { token?: string | null; overrides?: Partial<Env> } = {}) {
  const sets = countingKv(env.DAILY_SETS_KV);
  const quota = countingKv(env.QUOTA_KV);
  const cache = countingCache(caches.default);
  const e = { ...env, DAILY_SETS_KV: sets.kv, QUOTA_KV: quota.kv, ...options.overrides } as Env;
  const ctx = createExecutionContext();
  let response: Response;
  try {
    response = await handleSharedSetRead(request(date, options.token === undefined ? TOKEN : options.token), e, date, ctx, {
      cache: cache.cache,
    });
  } catch (err) {
    response = (err as { toResponse: () => Response }).toResponse();
  }
  await waitOnExecutionContext(ctx);
  return { response, kvCalls: sets.calls, quotaCalls: quota.calls, cacheCalls: cache.calls };
}

// No outbound request may ever leave this route: any fetch fails the test.
const originalFetch = globalThis.fetch;
let fetchCalls: string[] = [];

beforeEach(async () => {
  await clear(env.DAILY_SETS_KV);
  await clear(env.QUOTA_KV);
  for (let offset = -3; offset <= 4; offset++) await caches.default.delete(sharedSetCacheKey(dateAt(offset)));
  fetchCalls = [];
  globalThis.fetch = (async (url: string | URL | Request) => {
    fetchCalls.push(String(url));
    throw new Error(`Unexpected outbound fetch to ${String(url)}`);
  }) as typeof fetch;
});

afterEach(async () => {
  globalThis.fetch = originalFetch;
  // Every case: nothing left the Worker, and the quota was never touched.
  expect(fetchCalls).toEqual([]);
  expect((await env.QUOTA_KV.list()).keys).toEqual([]);
});

describe('GET /v1/shared-daily-test/{date}', () => {
  describe('hit', () => {
    it.each([-1, 0, 1, 2])('serves a published set for UTC today %+d', async (offset) => {
      const date = dateAt(offset);
      await seed(date);

      const response = await get(`/v1/shared-daily-test/${date}`);

      expect(response.status).toBe(200);
      expect(response.headers.get('cache-control')).toBe('private, max-age=0');
      expect(response.headers.get('content-type')).toBe('application/json');
      const stored = storedSet(date);
      expect(await response.json()).toEqual({
        date,
        promptVersion: 1,
        questions: stored.questions,
      });
    });

    it('does not send the storage-only fields (generatedAt, attempt)', async () => {
      await seed(dateAt(0));
      const body = (await (await get(`/v1/shared-daily-test/${dateAt(0)}`)).json()) as Record<string, unknown>;
      expect(Object.keys(body).sort()).toEqual(['date', 'promptVersion', 'questions']);
    });

    it('serves the second read from the Cache API, without reading KV again', async () => {
      const date = dateAt(0);
      await seed(date);

      const first = await readDirect(date);
      expect(first.response.status).toBe(200);
      expect(first.kvCalls.map((c) => c.method)).toEqual(['get']);
      expect(first.cacheCalls.map((c) => c.method)).toEqual(['match', 'put']);

      const second = await readDirect(date);
      expect(second.response.status).toBe(200);
      expect(second.kvCalls).toEqual([]);
      expect(second.cacheCalls.map((c) => c.method)).toEqual(['match']);
      expect(await second.response.json()).toEqual(await first.response.json());
      expect(second.response.headers.get('cache-control')).toBe('private, max-age=0');
    });

    it('keeps serving from the cache even after the KV key is gone (through the Worker)', async () => {
      const date = dateAt(1);
      await seed(date);
      expect((await get(`/v1/shared-daily-test/${date}`)).status).toBe(200);

      await env.DAILY_SETS_KV.delete(setKey(date));

      expect((await get(`/v1/shared-daily-test/${date}`)).status).toBe(200);
    });

    it(`caches for ${SHARED_SET_CACHE_SECONDS} s under a synthetic key without the token, and asks KV for a ${SHARED_SET_CACHE_SECONDS} s cacheTtl`, async () => {
      const date = dateAt(0);
      await seed(date);

      const { kvCalls, cacheCalls } = await readDirect(date);

      expect(SHARED_SET_CACHE_SECONDS).toBe(3600);
      expect(kvCalls).toEqual([{ method: 'get', args: [setKey(date), { cacheTtl: 3600 }] }]);
      const keys = cacheCalls.map((c) => c.key);
      expect(new Set(keys)).toEqual(new Set([`https://shared-daily-test.cache.grammarlens/set/${date}`]));
      for (const key of keys) {
        expect(key).not.toContain(TOKEN);
        expect(key).not.toContain('proxy.example');
      }
      const put = cacheCalls.find((c) => c.method === 'put');
      expect(put?.response?.headers.get('cache-control')).toBe('public, max-age=3600');
    });
  });

  describe('miss', () => {
    it('is a 404 with the not_found envelope, and never generates', async () => {
      const response = await get(`/v1/shared-daily-test/${dateAt(0)}`);

      expect(response.status).toBe(404);
      expect(await response.json()).toEqual({ error: 'not_found', message: 'No shared Daily Test for this date.' });
    });

    it('is not cached: once the set is published, the next read finds it', async () => {
      const date = dateAt(2);
      const miss = await readDirect(date);
      expect(miss.response.status).toBe(404);
      expect(miss.cacheCalls.map((c) => c.method)).toEqual(['match']);

      await seed(date);

      expect((await get(`/v1/shared-daily-test/${date}`)).status).toBe(200);
    });

    it('treats an unusable stored value as missing, and does not cache it', async () => {
      const date = dateAt(0);
      await env.DAILY_SETS_KV.put(setKey(date), 'not json');
      const broken = await readDirect(date);
      expect(broken.response.status).toBe(404);
      expect(broken.cacheCalls.map((c) => c.method)).toEqual(['match']);

      await env.DAILY_SETS_KV.put(setKey(date), JSON.stringify({ ...storedSet(date), date: dateAt(1) }));
      expect((await readDirect(date)).response.status).toBe(404);
    });
  });

  describe('outside the window [UTC today − 1, UTC today + 2]', () => {
    it.each([-2, 3, -30, 400])('is a 404 for UTC today %+d, without touching KV or the cache', async (offset) => {
      const date = dateAt(offset);
      await seed(date);

      const { response, kvCalls, cacheCalls } = await readDirect(date);

      expect(response.status).toBe(404);
      expect(await response.json()).toMatchObject({ error: 'not_found' });
      expect(kvCalls).toEqual([]);
      expect(cacheCalls).toEqual([]);
    });

    it('also through the Worker', async () => {
      await seed(dateAt(3));
      expect((await get(`/v1/shared-daily-test/${dateAt(3)}`)).status).toBe(404);
    });
  });

  describe('malformed date', () => {
    it.each(['2026-9-26', '20260926', 'today', '2027-02-29', '2026-13-01', '2026-09-26T00:00', '%20' + dateAt(0)])(
      '%j is a 400, without touching KV or the cache',
      async (date) => {
        const { response, kvCalls, cacheCalls } = await readDirect(date);

        expect(response.status).toBe(400);
        expect(await response.json()).toMatchObject({ error: 'invalid_request' });
        expect(kvCalls).toEqual([]);
        expect(cacheCalls).toEqual([]);
      },
    );

    it('also through the Worker', async () => {
      const response = await get('/v1/shared-daily-test/not-a-date');
      expect(response.status).toBe(400);
    });
  });

  describe('bad token', () => {
    it.each([
      ['missing', null],
      ['wrong', 'wrong-token'],
      ['empty', ''],
    ])('%s token is a 401 for a valid, published date, without touching KV or the cache', async (_, token) => {
      const date = dateAt(0);
      await seed(date);

      const { response, kvCalls, cacheCalls } = await readDirect(date, { token });

      expect(response.status).toBe(401);
      expect(await response.json()).toMatchObject({ error: 'unauthorized' });
      expect(kvCalls).toEqual([]);
      expect(cacheCalls).toEqual([]);
    });

    it('is checked before the date: a bad token with a bad date is still a 401', async () => {
      const { response, kvCalls, cacheCalls } = await readDirect('nonsense', { token: 'wrong-token' });
      expect(response.status).toBe(401);
      expect(kvCalls).toEqual([]);
      expect(cacheCalls).toEqual([]);
    });

    it('also through the Worker', async () => {
      await seed(dateAt(0));
      expect((await get(`/v1/shared-daily-test/${dateAt(0)}`, null)).status).toBe(401);
    });
  });

  describe('kill switch (SHARED_DAILY_TEST_ENABLED)', () => {
    it.each(['false', '', 'TRUE', 'yes'])(
      '"%s" is a 404 for a published date, without touching KV or the cache',
      async (value) => {
        const date = dateAt(0);
        await seed(date);
        // Even a set already in the edge cache is not served.
        await caches.default.put(
          sharedSetCacheKey(date),
          new Response(JSON.stringify({ date, promptVersion: 1, questions: [] }), {
            headers: { 'cache-control': 'public, max-age=3600' },
          }),
        );

        const { response, kvCalls, cacheCalls } = await readDirect(date, {
          overrides: { SHARED_DAILY_TEST_ENABLED: value },
        });

        expect(response.status).toBe(404);
        expect(await response.json()).toMatchObject({ error: 'not_found' });
        expect(kvCalls).toEqual([]);
        expect(cacheCalls).toEqual([]);
      },
    );
  });

  describe('routing', () => {
    it('only answers GET: a POST to the path is a 404, like any unknown operation', async () => {
      await seed(dateAt(0));
      const response = await SELF.fetch(`https://proxy.example/v1/shared-daily-test/${dateAt(0)}`, {
        method: 'POST',
        headers: { 'x-grammarlens-token': TOKEN, 'content-type': 'application/json' },
        body: '{}',
      });
      expect(response.status).toBe(404);
    });

    it.each(['/v1/shared-daily-test/', '/v1/shared-daily-test', `/v1/shared-daily-test/${dateAt(0)}/extra`])(
      '%s is not the route',
      async (path) => {
        await seed(dateAt(0));
        expect((await get(path)).status).toBe(404);
      },
    );

    it('ignores a query string', async () => {
      await seed(dateAt(0));
      expect((await get(`/v1/shared-daily-test/${dateAt(0)}?x=1`)).status).toBe(200);
    });
  });

  it('lives in modules that import neither the Anthropic client nor the quota', () => {
    // shared_read.ts and everything it imports at run time.
    const graph: Record<string, string> = {
      'shared_read.ts': sharedReadSource,
      'auth.ts': authSource,
      'shared_daily_test.ts': sharedDailyTestSource,
      'types.ts': typesSource,
      'topics.ts': topicsSource,
    };
    const imports = (source: string) =>
      [...source.matchAll(/^import\s+(type\s+)?[^;]*?from\s+'\.\/([a-z_]+)'/gm)]
        .filter((m) => !m[1])
        .map((m) => `${m[2]}.ts`);
    const seen = new Set<string>();
    const queue = ['shared_read.ts'];
    while (queue.length > 0) {
      const file = queue.shift() as string;
      if (seen.has(file)) continue;
      seen.add(file);
      const source = graph[file];
      expect(source, `${file} is imported but not listed in this test`).toBeDefined();
      queue.push(...imports(source as string));
    }
    expect([...seen].sort()).toEqual(['auth.ts', 'shared_daily_test.ts', 'shared_read.ts', 'topics.ts', 'types.ts']);
    expect(seen.has('anthropic.ts')).toBe(false);
    expect(seen.has('quota.ts')).toBe(false);
  });
});
