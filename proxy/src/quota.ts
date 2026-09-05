import { ProxyError, type Env } from './types';

/** Self-expire after 2 days — plenty past a calendar day's reset, no cron needed. */
const KEY_TTL_SECONDS = 60 * 60 * 24 * 2;

/** UTC calendar day, e.g. "2026-09-06" — resets at UTC midnight, not local. */
export function todayKey(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}

async function readCount(kv: KVNamespace, key: string): Promise<number> {
  const raw = await kv.get(key);
  if (raw === null) return 0;
  const n = Number.parseInt(raw, 10);
  return Number.isFinite(n) ? n : 0;
}

/**
 * Reserves one unit of quota for [deviceId] before the Anthropic call is
 * made — counts the attempt, not just a success, since the whole point is
 * bounding what we spend calling Anthropic at all. Throws
 * ProxyError('quota_exceeded') if either the per-device or the global
 * daily cap is already reached; otherwise increments both counters.
 *
 * Known tradeoff: KV reads/writes here are not atomic (no
 * compare-and-swap), so two requests landing at nearly the same instant
 * can both read the same pre-increment count and both proceed — a small
 * possible overshoot past the configured limit under concurrent bursts.
 * Acceptable for a cost guardrail at this project's traffic scale (a
 * personal project with a handful of testers pre-launch), not something
 * this reserves a Durable Object to fix. If real concurrent traffic ever
 * makes that overshoot matter, that's the fix to reach for then.
 */
export async function reserveQuota(env: Env, deviceId: string, now: Date = new Date()): Promise<void> {
  const day = todayKey(now);
  const deviceKey = `d:${day}:${deviceId}`;
  const globalKey = `g:${day}`;
  const deviceLimit = Number.parseInt(env.DEVICE_DAILY_LIMIT, 10);
  const globalLimit = Number.parseInt(env.GLOBAL_DAILY_LIMIT, 10);

  const [deviceCount, globalCount] = await Promise.all([
    readCount(env.QUOTA_KV, deviceKey),
    readCount(env.QUOTA_KV, globalKey),
  ]);

  if (deviceCount >= deviceLimit) {
    throw new ProxyError(
      'quota_exceeded',
      429,
      "You've reached today's practice limit on this device. Please try again tomorrow.",
      'device',
    );
  }
  if (globalCount >= globalLimit) {
    throw new ProxyError(
      'quota_exceeded',
      429,
      "GrammarLens has reached its overall limit for today. Please try again tomorrow.",
      'global',
    );
  }

  await Promise.all([
    env.QUOTA_KV.put(deviceKey, String(deviceCount + 1), { expirationTtl: KEY_TTL_SECONDS }),
    env.QUOTA_KV.put(globalKey, String(globalCount + 1), { expirationTtl: KEY_TTL_SECONDS }),
  ]);
}
