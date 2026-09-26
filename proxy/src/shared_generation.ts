import { callAnthropic, type CallMeta } from './anthropic';
import type { UpstreamFailure } from './error_log';
import {
  SHARED_PROMPT_VERSION,
  dailyPlan,
  dateOfDayNumber,
  setKey,
  sharedDailyTestRequest,
  utcDayNumber,
  validateSharedSet,
  type PublishedSet,
  type SharedSetRejection,
} from './shared_daily_test';
import type { Env } from './types';
import { durationField } from './usage_log';

/**
 * The hourly scheduled run that fills in the shared Daily Test sets
 * (docs/1.1.0-shared-daily-test.md §3, §4). It never reserves quota: no device
 * is involved, and the cost is bounded here instead (one Anthropic call per run
 * at most, three attempts per date at most).
 */

/** Dates UTC today through UTC today + 3 are kept filled. A set for date D can
 * first be asked for at UTC (D − 2) 10:00 (a UTC+14 user fetching tomorrow), so
 * a set generated on UTC D − 3 exists about 34 hours before anyone can read
 * it: the owner's optional review window, and room for retries. */
export const GENERATION_AHEAD_DAYS = 3;

/** Paid attempts per date, the cost ceiling for a date that keeps failing. */
export const MAX_ATTEMPTS_PER_DATE = 3;

/**
 * How long one generation may take before it is abandoned. The one live
 * measurement was 27.6 s for ~1,500 output tokens (build log 2026-09-24,
 * about 54 tokens/s); the budget is 3,072 output tokens, which at that pace
 * is ~57 s. A 60 s limit would cut off a response that is still being written
 * (and billed) near a long output; nobody is waiting on a scheduled run, and a
 * cron may run for 15 minutes, so 90 s leaves margin for a slower hour.
 */
export const GENERATION_TIMEOUT_MS = 90_000;

/** An attempt holds its date this long, so an overlapping run skips it
 * instead of paying for a second generation: the timeout plus margin. */
export const ATTEMPT_LEASE_MS = GENERATION_TIMEOUT_MS + 30_000;

export const SET_TTL_SECONDS = 35 * 24 * 60 * 60;
export const ATTEMPTS_TTL_SECONDS = 7 * 24 * 60 * 60;

/** How many earlier dates' answers go into the "do not reuse" list. */
const AVOID_LOOKBACK_DAYS = 7;

export const attemptsKey = (date: string) => `attempts:${date}`;
// Defined beside the read route's other dependencies, which must not pull in
// the Anthropic client; re-exported here for the generation side.
export { setKey, type PublishedSet } from './shared_daily_test';

interface AttemptRecord {
  count: number;
  /** Epoch ms until which the latest attempt still owns the date. */
  leaseUntil: number;
}

export type GenerationOutcome =
  | 'published' // validated and written as set:{date}
  | 'rejected' // content failed validateSharedSet; nothing written
  | 'upstream_failed' // no usable answer from Anthropic (incl. timeout); nothing written
  | 'already_published'; // another run published the date meanwhile; this result was dropped

function readAttempts(raw: string | null): AttemptRecord {
  if (raw === null) return { count: 0, leaseUntil: 0 };
  try {
    const parsed = JSON.parse(raw) as Partial<AttemptRecord>;
    const count = typeof parsed.count === 'number' && parsed.count >= 0 ? parsed.count : 0;
    const leaseUntil = typeof parsed.leaseUntil === 'number' ? parsed.leaseUntil : 0;
    return { count, leaseUntil };
  } catch {
    // Unreadable: treat as used up rather than risk paying again.
    return { count: MAX_ATTEMPTS_PER_DATE, leaseUntil: 0 };
  }
}

/** Correct answers of the published sets before [dayNumber], newest first. */
async function recentAnswers(kv: KVNamespace, dayNumber: number): Promise<string[]> {
  const dates = Array.from({ length: AVOID_LOOKBACK_DAYS }, (_, i) => dateOfDayNumber(dayNumber - 1 - i));
  const sets = await Promise.all(dates.map((d) => kv.get(setKey(d))));
  const answers: string[] = [];
  for (const raw of sets) {
    if (raw === null) continue;
    try {
      const set = JSON.parse(raw) as { questions?: { correctAnswer?: unknown }[] };
      for (const q of set.questions ?? []) {
        if (typeof q.correctAnswer === 'string') answers.push(q.correctAnswer);
      }
    } catch {
      // A damaged older set only shortens the list.
    }
  }
  return answers;
}

/**
 * PRIVACY CONTRACT — one line per paid attempt, built field by field: the date
 * (a calendar label, not about anyone), the attempt number, the outcome, a
 * rejection code from `SharedSetRejection`, an upstream failure category, the
 * whitelisted stop reason, token counts, duration and prompt version. Never
 * any generated text. The token counts and stop reason also appear on the
 * `anthropic_usage` line that `callAnthropic` writes for the same call.
 */
function logGeneration(fields: {
  date: string;
  attempt: number;
  outcome: GenerationOutcome;
  reason?: SharedSetRejection;
  failure?: UpstreamFailure;
  meta: CallMeta;
}): void {
  console.log(
    JSON.stringify({
      event: 'shared_set_generation',
      date: fields.date,
      attempt: fields.attempt,
      outcome: fields.outcome,
      reason: fields.reason ?? null,
      failure: fields.failure ?? null,
      stop_reason: fields.meta.stopReason ?? null,
      input_tokens: fields.meta.inputTokens ?? null,
      output_tokens: fields.meta.outputTokens ?? null,
      duration_ms: durationField(fields.meta.durationMs),
      prompt_version: SHARED_PROMPT_VERSION,
    }),
  );
}

export interface GenerationOptions {
  /** Test seam; production uses [GENERATION_TIMEOUT_MS]. */
  timeoutMs?: number;
}

/**
 * One scheduled run. Looks at UTC today … UTC today + 3, nearest first, and
 * makes **at most one** Anthropic call: for the first date that has no set, no
 * attempt in progress, and attempts left. Everything else is a KV read, so an
 * idle hour (every date filled) makes no outbound request at all.
 *
 * One call per run rather than one per missing date keeps each run's cost and
 * CPU (Workers Free: 10 ms per invocation) to a single set; after a first
 * deploy the four dates fill in over four hours.
 *
 * Publishing is write-once: the set key is read again right before the write,
 * and an existing set is never replaced. KV has no compare-and-swap, so two
 * runs that both read "no set, no attempt" in the same few milliseconds could
 * still both generate; the attempt lease closes the realistic case (a run that
 * starts while another is waiting on Anthropic).
 */
export async function runSharedGeneration(
  env: Env,
  now: Date = new Date(),
  options: GenerationOptions = {},
): Promise<void> {
  if (env.SHARED_DAILY_TEST_ENABLED !== 'true') {
    console.log(JSON.stringify({ event: 'shared_set_cron', enabled: false }));
    return;
  }
  const kv = env.DAILY_SETS_KV;
  const today = utcDayNumber(now);

  for (let offset = 0; offset <= GENERATION_AHEAD_DAYS; offset++) {
    const dayNumber = today + offset;
    const date = dateOfDayNumber(dayNumber);

    if ((await kv.get(setKey(date))) !== null) continue;
    const attempts = readAttempts(await kv.get(attemptsKey(date)));
    if (attempts.count >= MAX_ATTEMPTS_PER_DATE) continue;
    if (attempts.leaseUntil > now.getTime()) continue;

    await generate(env, date, dayNumber, attempts.count + 1, now, options);
    return;
  }
}

async function generate(
  env: Env,
  date: string,
  dayNumber: number,
  attempt: number,
  now: Date,
  options: GenerationOptions,
): Promise<void> {
  const kv = env.DAILY_SETS_KV;
  // The attempt is counted before the call, like quota: a run that dies
  // mid-call has still (possibly) been billed.
  await kv.put(attemptsKey(date), JSON.stringify({ count: attempt, leaseUntil: now.getTime() + ATTEMPT_LEASE_MS }), {
    expirationTtl: ATTEMPTS_TTL_SECONDS,
  });

  const plan = dailyPlan(date);
  const request = sharedDailyTestRequest(plan, await recentAnswers(kv, dayNumber));
  const meta: CallMeta = {};

  let content: unknown;
  try {
    content = await callAnthropic(
      env,
      { op: 'generate_shared_daily_test', request },
      { signal: AbortSignal.timeout(options.timeoutMs ?? GENERATION_TIMEOUT_MS), meta },
    );
  } catch {
    logGeneration({ date, attempt, outcome: 'upstream_failed', failure: meta.failure, meta });
    return;
  }

  const result = validateSharedSet(content, plan);
  if (!result.ok) {
    logGeneration({ date, attempt, outcome: 'rejected', reason: result.reason, meta });
    return;
  }

  if ((await kv.get(setKey(date))) !== null) {
    logGeneration({ date, attempt, outcome: 'already_published', meta });
    return;
  }
  const published: PublishedSet = {
    date,
    promptVersion: SHARED_PROMPT_VERSION,
    generatedAt: now.toISOString(),
    attempt,
    questions: result.questions,
  };
  await kv.put(setKey(date), JSON.stringify(published), { expirationTtl: SET_TTL_SECONDS });
  logGeneration({ date, attempt, outcome: 'published', meta });
}
