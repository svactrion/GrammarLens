import { requireAppToken } from './auth';
import { dayNumberOf, isInServingWindow, setKey, type PublishedSet } from './shared_daily_test';
import { ProxyError, type Env } from './types';

/**
 * `GET /v1/shared-daily-test/{date}`: serves a published shared Daily Test set
 * to 1.1.0+ clients (docs/1.1.0-shared-daily-test.md §4, §6).
 *
 * This module never reaches Anthropic and never touches quota: it imports
 * neither `anthropic.ts` nor `quota.ts` (nor anything that does, which
 * `test/shared_read.test.ts` checks), and a missing set is a 404, never "generate
 * now". Sets are produced only by the hourly cron (`shared_generation.ts`).
 *
 * Order of checks: app token → date format → serving window → kill switch →
 * Cache API → KV. The first four cost nothing and run before any cache or KV
 * read, so a bad token, a malformed or out-of-window date, or a disabled
 * feature never costs a KV read.
 */

/** Matches the route and captures the date segment (validated separately). */
export const SHARED_SET_PATH = /^\/v1\/shared-daily-test\/([^/]+)$/;

/** Seconds a set stays in the edge cache, and in KV's own read cache. A pulled
 * set (the owner deleting `set:{date}`) can keep being served for up to this
 * long in a data center that already cached it. */
export const SHARED_SET_CACHE_SECONDS = 3600;

/**
 * The Cache API key for [date]: a synthetic URL, not the request's, so the app
 * token (a header) and anything else about the caller never become part of
 * it, and every caller of a date shares one entry per data center.
 */
export function sharedSetCacheKey(date: string): Request {
  return new Request(`https://shared-daily-test.cache.grammarlens/set/${date}`, { method: 'GET' });
}

/** What the app receives: the date, the prompt version that produced the
 * set, and its questions in the shape `DailyTestQuestion.fromJson` reads. */
export interface SharedSetResponseBody {
  date: string;
  promptVersion: number;
  questions: PublishedSet['questions'];
}

function notFound(): never {
  throw new ProxyError('not_found', 404, 'No shared Daily Test for this date.');
}

/** The response to the app: never kept by the device's HTTP stack (it stores
 * the set in its own database). */
function toClient(body: string): Response {
  return new Response(body, {
    status: 200,
    headers: { 'content-type': 'application/json', 'cache-control': 'private, max-age=0' },
  });
}

/** Parses a stored set into the response body, or null if it is unusable. */
function responseBody(raw: string, date: string): string | null {
  try {
    const stored = JSON.parse(raw) as Partial<PublishedSet>;
    if (stored.date !== date || !Array.isArray(stored.questions) || typeof stored.promptVersion !== 'number') {
      return null;
    }
    const body: SharedSetResponseBody = { date, promptVersion: stored.promptVersion, questions: stored.questions };
    return JSON.stringify(body);
  } catch {
    return null;
  }
}

export interface SharedReadDeps {
  /** Test seam; production uses `caches.default`. */
  cache?: Cache;
  now?: Date;
}

export async function handleSharedSetRead(
  request: Request,
  env: Env,
  date: string,
  ctx?: ExecutionContext,
  deps: SharedReadDeps = {},
): Promise<Response> {
  requireAppToken(request, env.APP_TOKEN);
  if (dayNumberOf(date) === null) {
    throw new ProxyError('invalid_request', 400, 'The date must be a real calendar date written as YYYY-MM-DD.');
  }
  if (!isInServingWindow(date, deps.now ?? new Date())) notFound();
  // The same fail-closed rule as the cron: only "true" turns the feature on.
  if (env.SHARED_DAILY_TEST_ENABLED !== 'true') notFound();

  const cache = deps.cache ?? caches.default;
  const cacheKey = sharedSetCacheKey(date);
  const cached = await cache.match(cacheKey);
  if (cached) return toClient(await cached.text());

  const raw = await env.DAILY_SETS_KV.get(setKey(date), { cacheTtl: SHARED_SET_CACHE_SECONDS });
  // A miss (or an unusable value) is not cached: once the cron publishes the
  // date, the next read finds it.
  if (raw === null) notFound();
  const body = responseBody(raw, date);
  if (body === null) notFound();

  const put = cache.put(
    cacheKey,
    new Response(body, {
      headers: {
        'content-type': 'application/json',
        'cache-control': `public, max-age=${SHARED_SET_CACHE_SECONDS}`,
      },
    }),
  );
  if (ctx) ctx.waitUntil(put);
  else await put;

  return toClient(body);
}
