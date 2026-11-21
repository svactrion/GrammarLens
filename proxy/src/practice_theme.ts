import { SCENARIO_THEMES } from './shared_daily_test';

/**
 * The scenario theme of a practice set (owner decision 2026-11-19; option A
 * of docs/1.5.0-topics-set-variety.md). Until now two practice requests for
 * one topic were the same request byte for byte, so sets repeated each
 * other's scenarios; the theme gives the generator something to differ by.
 *
 * The themes are the shared Daily Test's 14 (approved by the owner on
 * 2026-09-26). Which one a request gets is stepped from what the quota
 * check has already read for it: the UTC day and how many requests the
 * device has made that day. Nothing new is sent by the app, nothing is
 * stored, and no client text reaches the prompt: the theme is one of the
 * worker's own fixed strings.
 *
 * What the stepping gives:
 * - Two requests of one device on one day never get the same theme while
 *   the device has made fewer than 14 requests that day (every request,
 *   generation or scoring, moves the count on by one).
 * - From one day to the next the sequence moves on by one, so yesterday's
 *   first theme is not today's first.
 * - Devices start at different places (a hash of the device id), so the
 *   themes are spread over users.
 * It is a step, not a memory: after the 14 themes it comes round again, and
 * two requests that read the same count at the same instant (the quota's
 * known race) get the same theme.
 */

/** FNV-1a, 32 bits. */
function hash(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

/** Days since 1970-01-01 for a `YYYY-MM-DD` UTC day key; 0 for anything else. */
function dayNumber(day: string): number {
  const time = Date.parse(`${day}T00:00:00Z`);
  return Number.isNaN(time) ? 0 : Math.floor(time / 86_400_000);
}

/** The theme's place in {@link SCENARIO_THEMES} for this request. */
export function practiceThemeIndex(deviceId: string, day: string, deviceCount: number): number {
  const count = Number.isFinite(deviceCount) && deviceCount > 0 ? Math.floor(deviceCount) : 0;
  return (hash(deviceId) + dayNumber(day) + count) % SCENARIO_THEMES.length;
}

/**
 * The theme for a practice request: [deviceId] and what the quota check
 * read for it, the UTC [day] and [deviceCount] (the device's requests that
 * day before this one).
 */
export function practiceTheme(deviceId: string, day: string, deviceCount: number): string {
  return SCENARIO_THEMES[practiceThemeIndex(deviceId, day, deviceCount)] as string;
}
