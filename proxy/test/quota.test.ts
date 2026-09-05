import { env } from 'cloudflare:test';
import { beforeEach, describe, expect, it } from 'vitest';
import { reserveQuota, todayKey } from '../src/quota';
import { ProxyError } from '../src/types';

describe('todayKey', () => {
  it('formats as a UTC calendar day', () => {
    expect(todayKey(new Date('2026-09-06T23:59:00Z'))).toBe('2026-09-06');
    expect(todayKey(new Date('2026-09-07T00:00:01Z'))).toBe('2026-09-07');
  });
});

describe('reserveQuota', () => {
  const now = new Date('2026-09-06T12:00:00Z');

  beforeEach(async () => {
    // KV state persists across tests in the same worker instance —
    // clear anything this day's keys might hold.
    const list = await env.QUOTA_KV.list();
    await Promise.all(list.keys.map((k) => env.QUOTA_KV.delete(k.name)));
  });

  it('allows requests under both the device and global limit', async () => {
    await expect(reserveQuota(env, 'device-a', now)).resolves.toBeUndefined();
  });

  it('rejects once a single device hits its own daily limit, without touching other devices', async () => {
    const limit = Number.parseInt(env.DEVICE_DAILY_LIMIT, 10);
    for (let i = 0; i < limit; i++) {
      await reserveQuota(env, 'device-a', now);
    }

    await expect(reserveQuota(env, 'device-a', now)).rejects.toMatchObject({
      code: 'quota_exceeded',
      scope: 'device',
    });

    // A different device is unaffected by device-a's cap.
    await expect(reserveQuota(env, 'device-b', now)).resolves.toBeUndefined();
  });

  it('rejects every device once the global daily cap is reached', async () => {
    const globalLimit = Number.parseInt(env.GLOBAL_DAILY_LIMIT, 10);
    const deviceLimit = Number.parseInt(env.DEVICE_DAILY_LIMIT, 10);
    // Spread requests across enough distinct devices to hit the global cap
    // without any single device hitting its own smaller cap first.
    let remaining = globalLimit;
    let deviceIndex = 0;
    while (remaining > 0) {
      const take = Math.min(deviceLimit, remaining);
      for (let i = 0; i < take; i++) {
        await reserveQuota(env, `device-${deviceIndex}`, now);
      }
      remaining -= take;
      deviceIndex++;
    }

    await expect(reserveQuota(env, `device-${deviceIndex}`, now)).rejects.toMatchObject({
      code: 'quota_exceeded',
      scope: 'global',
    });
  });

  it('resets for a new UTC calendar day', async () => {
    const limit = Number.parseInt(env.DEVICE_DAILY_LIMIT, 10);
    for (let i = 0; i < limit; i++) {
      await reserveQuota(env, 'device-a', now);
    }
    await expect(reserveQuota(env, 'device-a', now)).rejects.toThrow(ProxyError);

    const nextDay = new Date('2026-09-07T00:00:01Z');
    await expect(reserveQuota(env, 'device-a', nextDay)).resolves.toBeUndefined();
  });
});
