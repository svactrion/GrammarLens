import { callAnthropic, type CallMeta } from './anthropic';
import type { UpstreamFailure } from './error_log';
import {
  ANNOTATION_CHECKERS,
  ANNOTATION_GATE,
  CHECK_VERSION,
  annotateSet,
  isAdditivePatch,
  sharedCheckRequest,
  type AnnotationFinding,
  type AnnotationGate,
  type CheckerModel,
} from './shared_check';
import {
  dailyPlan,
  dateOfDayNumber,
  reviewKey,
  setKey,
  sharedDailyTestRequest,
  utcDayNumber,
  validateSharedSet,
  type GenerateSharedDailyTestRequest,
  type PublishedSet,
  type SharedGenerationOptions,
  type SharedSetRejection,
} from './shared_daily_test';
import type { Env } from './types';
import { durationField } from './usage_log';

/**
 * The hourly scheduled run that fills in the shared Daily Test sets
 * (docs/1.1.0-shared-daily-test.md §3, §4) and, since P14
 * (docs/1.4.0-server-batch0-report.md §1.3), annotates a published set once
 * with the accepted answers a check finds. It never reserves quota: no device
 * is involved, and the cost is bounded here instead: one generation, or one
 * annotation (one call per checker of the gate), per run; three generations
 * and two annotations per date at most.
 */

/** Dates UTC today through UTC today + 3 are kept filled. A set for date D can
 * first be asked for at UTC (D − 2) 10:00 (a UTC+14 user fetching tomorrow), so
 * a set generated on UTC D − 3 exists about 34 hours before anyone can read
 * it: the owner's optional review window, and room for retries. */
export const GENERATION_AHEAD_DAYS = 3;

/** Paid generation attempts per date, the cost ceiling for a date that keeps failing. */
export const MAX_ATTEMPTS_PER_DATE = 3;

/** Paid annotation attempts per date (a check that fails upstream or comes
 * back unreadable is retried on a later run); after them the set stays as
 * published, without accepted answers, as before P14. */
export const MAX_CHECKS_PER_DATE = 2;

/**
 * How long one generation may take before it is abandoned
 * (docs/1.1.0-shared-daily-test-quality.md §15.2). `claude-sonnet-5` with
 * adaptive thinking wrote 4,052–4,878 output tokens at ~97 tokens/s in E
 * (≈ 50 s for the largest), but its budget is 15,072 tokens (≈ 155 s): 90 s
 * would cut off (and still bill) a call that thinks longer. 150 s lets a
 * generation end at its token budget rather than at the timer. It costs
 * nothing: nobody waits on a scheduled run, a cron invocation may run for 15
 * minutes, and waiting on `fetch` is not CPU time.
 */
export const GENERATION_TIMEOUT_MS = 150_000;

/** The same reasoning for a check: E's checks took 14–91 s with budgets of
 * 14,048 tokens (§14.1); the checker that thinks to its budget needs this. */
export const CHECK_TIMEOUT_MS = 150_000;

/** An attempt holds its date this long, so an overlapping run skips it
 * instead of paying for a second generation: the timeout plus margin. */
export const ATTEMPT_LEASE_MS = GENERATION_TIMEOUT_MS + 30_000;

/** An annotation holds its date for every checker's timeout plus margin. */
export function checkLeaseMs(gate: AnnotationGate): number {
  return ANNOTATION_CHECKERS[gate].length * CHECK_TIMEOUT_MS + 30_000;
}

export const SET_TTL_SECONDS = 35 * 24 * 60 * 60;
export const ATTEMPTS_TTL_SECONDS = 7 * 24 * 60 * 60;
/** `review:{date}` outlives the date's serving window by well over a week:
 * the owner's weekly look has two chances at it. */
export const REVIEW_TTL_SECONDS = 14 * 24 * 60 * 60;

/** How many earlier dates' answers go into the "do not reuse" list. */
const AVOID_LOOKBACK_DAYS = 7;

export const attemptsKey = (date: string) => `attempts:${date}`;
// Defined beside the read route's other dependencies, which must not pull in
// the Anthropic client; re-exported here for the generation side.
export { reviewKey, setKey, type PublishedSet } from './shared_daily_test';

interface AttemptRecord {
  /** Paid generation attempts. */
  count: number;
  /** Paid annotation attempts (P14); absent in records written before it. */
  checks: number;
  /** Epoch ms until which the latest attempt still owns the date. */
  leaseUntil: number;
}

export type GenerationOutcome =
  | 'published' // validated and written as set:{date}
  | 'rejected' // content failed validateSharedSet; nothing written
  | 'upstream_failed' // no usable answer from Anthropic (incl. timeout); nothing written
  | 'already_published'; // another run published the date meanwhile; this result was dropped

export type AnnotationOutcome =
  | 'annotated' // the patched set written, with checkedAt
  | 'unreadable' // a checker's output could not be used; the set is untouched and the check retried later
  | 'upstream_failed' // a checker call failed (incl. timeout); the set is untouched and the check retried later
  | 'set_changed' // the set in KV is no longer the one that was checked; nothing written
  | 'patch_rejected'; // the annotated questions were not an additive patch (a bug guard); nothing written

function readAttempts(raw: string | null): AttemptRecord {
  if (raw === null) return { count: 0, checks: 0, leaseUntil: 0 };
  try {
    const parsed = JSON.parse(raw) as Partial<AttemptRecord>;
    const count = typeof parsed.count === 'number' && parsed.count >= 0 ? parsed.count : 0;
    const checks = typeof parsed.checks === 'number' && parsed.checks >= 0 ? parsed.checks : 0;
    const leaseUntil = typeof parsed.leaseUntil === 'number' ? parsed.leaseUntil : 0;
    return { count, checks, leaseUntil };
  } catch {
    // Unreadable: treat as used up rather than risk paying again.
    return { count: MAX_ATTEMPTS_PER_DATE, checks: MAX_CHECKS_PER_DATE, leaseUntil: 0 };
  }
}

/** The stored set, or null when the value is not one. */
function readSet(raw: string | null): PublishedSet | null {
  if (raw === null) return null;
  try {
    const parsed = JSON.parse(raw) as Partial<PublishedSet>;
    if (typeof parsed.date !== 'string' || !Array.isArray(parsed.questions)) return null;
    return parsed as PublishedSet;
  } catch {
    return null;
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
 * whitelisted stop reason, token counts, duration, and what was asked: the
 * prompt version, the generator model and its effort (`null` when none was
 * sent), all fixed vocabularies from the request. Never any generated text.
 * The token counts and stop reason also appear on the `anthropic_usage` line
 * that `callAnthropic` writes for the same call; the model and effort only
 * here (that line keeps one shape for every operation, the legacy one
 * included).
 */
function logGeneration(fields: {
  date: string;
  attempt: number;
  outcome: GenerationOutcome;
  reason?: SharedSetRejection;
  failure?: UpstreamFailure;
  meta: CallMeta;
  request: GenerateSharedDailyTestRequest;
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
      prompt_version: fields.request.promptVersion,
      model: fields.request.model,
      effort: fields.request.effort ?? null,
    }),
  );
}

/**
 * PRIVACY CONTRACT — one line per paid annotation attempt: the date, the check
 * number, the outcome, the gate and its checker models (fixed vocabularies),
 * an upstream failure category and the model it came from, token counts and
 * duration summed over the checker calls, the check version, and three
 * counts: accepted answers added, wrong answers moved, findings recorded.
 * Never a question, an answer or a finding's text: those are in
 * `review:{date}` (KV), not in a log line.
 */
function logAnnotation(fields: {
  date: string;
  check: number;
  outcome: AnnotationOutcome;
  gate: AnnotationGate;
  models: readonly CheckerModel[];
  failure?: UpstreamFailure;
  failedModel?: CheckerModel;
  metas: readonly CallMeta[];
  added?: number;
  moved?: number;
  findings?: number;
}): void {
  const sum = (pick: (m: CallMeta) => number | null | undefined) => {
    const values = fields.metas.map(pick).filter((v): v is number => typeof v === 'number');
    return values.length === 0 ? null : values.reduce((a, b) => a + b, 0);
  };
  console.log(
    JSON.stringify({
      event: 'shared_set_annotation',
      date: fields.date,
      check: fields.check,
      outcome: fields.outcome,
      gate: fields.gate,
      models: [...fields.models],
      failure: fields.failure ?? null,
      failed_model: fields.failedModel ?? null,
      input_tokens: sum((m) => m.inputTokens),
      output_tokens: sum((m) => m.outputTokens),
      duration_ms: durationField(sum((m) => m.durationMs) ?? undefined),
      check_version: CHECK_VERSION,
      added: fields.added ?? null,
      moved: fields.moved ?? null,
      findings: fields.findings ?? null,
    }),
  );
}

export interface GenerationOptions {
  /** Test seam; production uses [GENERATION_TIMEOUT_MS]. */
  timeoutMs?: number;
  /** Test seam; production uses [CHECK_TIMEOUT_MS]. */
  checkTimeoutMs?: number;
  /** Test seam; production uses the defaults (`SHARED_GENERATOR`, the
   * current prompt version). */
  generation?: SharedGenerationOptions;
  /** Test seam; production uses [ANNOTATION_GATE]. */
  gate?: AnnotationGate;
}

/**
 * One scheduled run. Looks at UTC today … UTC today + 3, nearest first, and
 * does **at most one thing**: for the first date that has a published set
 * without `checkedAt`, checks left and no attempt in progress, the annotation
 * (one call per checker of the gate); otherwise, for the first date that has
 * no set, no attempt in progress and attempts left, one generation.
 * Everything else is a KV read, so an idle hour (every date filled and
 * checked) makes no outbound request at all.
 *
 * One thing per run rather than one per missing date keeps each run's cost
 * and CPU (Workers Free: 10 ms per invocation) to a single set; after a first
 * deploy the four dates fill in over four hours, and each is annotated the
 * hour after it is published. Generation and annotation never share a run,
 * so a check always sees a set that is at least an hour old.
 *
 * A published set is written by the generation once and by the annotation
 * once more (P14, owner decision 2 of 2026-10-31): the annotation re-reads
 * the set right before its write and writes only if it is still the set it
 * checked and the change is an additive patch (`isAdditivePatch`). The
 * generation never replaces an existing set. KV has no compare-and-swap, so
 * two runs that both read "no set, no attempt" in the same few milliseconds
 * could still both generate; the attempt lease closes the realistic case (a
 * run that starts while another is waiting on Anthropic).
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
  const checkEnabled = env.SHARED_SET_CHECK_ENABLED === 'true';

  for (let offset = 0; offset <= GENERATION_AHEAD_DAYS; offset++) {
    const dayNumber = today + offset;
    const date = dateOfDayNumber(dayNumber);

    const stored = readSet(await kv.get(setKey(date)));
    if (stored !== null) {
      // Published. Checked, or the step is off: nothing to do for this date.
      if (!checkEnabled || stored.checkedAt !== undefined) continue;
      const attempts = readAttempts(await kv.get(attemptsKey(date)));
      if (attempts.checks >= MAX_CHECKS_PER_DATE) continue;
      if (attempts.leaseUntil > now.getTime()) continue;
      await annotate(env, date, stored, attempts, now, options);
      return;
    }
    const attempts = readAttempts(await kv.get(attemptsKey(date)));
    if (attempts.count >= MAX_ATTEMPTS_PER_DATE) continue;
    if (attempts.leaseUntil > now.getTime()) continue;

    await generate(env, date, dayNumber, attempts, now, options);
    return;
  }
}

async function generate(
  env: Env,
  date: string,
  dayNumber: number,
  attempts: AttemptRecord,
  now: Date,
  options: GenerationOptions,
): Promise<void> {
  const kv = env.DAILY_SETS_KV;
  const attempt = attempts.count + 1;
  // The attempt is counted before the call, like quota: a run that dies
  // mid-call has still (possibly) been billed.
  await kv.put(
    attemptsKey(date),
    JSON.stringify({ count: attempt, checks: attempts.checks, leaseUntil: now.getTime() + ATTEMPT_LEASE_MS }),
    { expirationTtl: ATTEMPTS_TTL_SECONDS },
  );

  const plan = dailyPlan(date);
  const request = sharedDailyTestRequest(plan, await recentAnswers(kv, dayNumber), options.generation);
  const meta: CallMeta = {};

  let content: unknown;
  try {
    content = await callAnthropic(
      env,
      { op: 'generate_shared_daily_test', request },
      { signal: AbortSignal.timeout(options.timeoutMs ?? GENERATION_TIMEOUT_MS), meta },
    );
  } catch {
    logGeneration({ date, attempt, outcome: 'upstream_failed', failure: meta.failure, meta, request });
    return;
  }

  const result = validateSharedSet(content, plan);
  if (!result.ok) {
    logGeneration({ date, attempt, outcome: 'rejected', reason: result.reason, meta, request });
    return;
  }

  if ((await kv.get(setKey(date))) !== null) {
    logGeneration({ date, attempt, outcome: 'already_published', meta, request });
    return;
  }
  const published: PublishedSet = {
    date,
    promptVersion: request.promptVersion,
    generatedAt: now.toISOString(),
    attempt,
    questions: result.questions,
  };
  await kv.put(setKey(date), JSON.stringify(published), { expirationTtl: SET_TTL_SECONDS });
  logGeneration({ date, attempt, outcome: 'published', meta, request });
}

/** What `review:{date}` holds: what the step found and did not write. */
export interface ReviewRecord {
  date: string;
  checkedAt: string;
  gate: AnnotationGate;
  models: CheckerModel[];
  findings: AnnotationFinding[];
}

/**
 * The annotation step for one published set: one call per checker of the
 * gate, the add-only decision (`annotateSet`), then the patched set written
 * only if the set in KV is still the one that was checked and the change is
 * additive. Findings go to `review:{date}`. The 35-day TTL of the set
 * restarts at this write (the set is at most a day old by then).
 */
async function annotate(
  env: Env,
  date: string,
  stored: PublishedSet,
  attempts: AttemptRecord,
  now: Date,
  options: GenerationOptions,
): Promise<void> {
  const kv = env.DAILY_SETS_KV;
  const gate = options.gate ?? ANNOTATION_GATE;
  const models = ANNOTATION_CHECKERS[gate];
  const check = attempts.checks + 1;
  await kv.put(
    attemptsKey(date),
    JSON.stringify({ count: attempts.count, checks: check, leaseUntil: now.getTime() + checkLeaseMs(gate) }),
    { expirationTtl: ATTEMPTS_TTL_SECONDS },
  );

  const metas: CallMeta[] = [];
  const outputs: { model: CheckerModel; output: unknown }[] = [];
  for (const model of models) {
    const meta: CallMeta = {};
    metas.push(meta);
    try {
      const output = await callAnthropic(
        env,
        { op: 'check_shared_daily_test', request: sharedCheckRequest(stored.questions, model) },
        { signal: AbortSignal.timeout(options.checkTimeoutMs ?? CHECK_TIMEOUT_MS), meta },
      );
      outputs.push({ model, output });
    } catch {
      logAnnotation({ date, check, outcome: 'upstream_failed', gate, models, failure: meta.failure, failedModel: model, metas });
      return;
    }
  }

  const result = annotateSet(stored.questions, outputs);
  if (result.outcome === 'unreadable') {
    logAnnotation({ date, check, outcome: 'unreadable', gate, models, failedModel: result.model, metas });
    return;
  }

  const current = readSet(await kv.get(setKey(date)));
  if (current === null || current.checkedAt !== undefined || JSON.stringify(current.questions) !== JSON.stringify(stored.questions)) {
    logAnnotation({ date, check, outcome: 'set_changed', gate, models, metas });
    return;
  }
  if (!isAdditivePatch(current.questions, result.questions)) {
    logAnnotation({ date, check, outcome: 'patch_rejected', gate, models, metas });
    return;
  }

  const checkedAt = now.toISOString();
  const patched: PublishedSet = {
    ...current,
    questions: result.questions,
    checkedAt,
    checkVersion: CHECK_VERSION,
    checkGate: gate,
    checkModels: [...models],
  };
  await kv.put(setKey(date), JSON.stringify(patched), { expirationTtl: SET_TTL_SECONDS });
  if (result.findings.length > 0) {
    const review: ReviewRecord = { date, checkedAt, gate, models: [...models], findings: result.findings };
    await kv.put(reviewKey(date), JSON.stringify(review), { expirationTtl: REVIEW_TTL_SECONDS });
  }
  logAnnotation({
    date,
    check,
    outcome: 'annotated',
    gate,
    models,
    metas,
    added: result.added,
    moved: result.moved,
    findings: result.findings.length,
  });
}
