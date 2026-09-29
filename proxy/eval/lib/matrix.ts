import type { CheckerModel } from '../../src/shared_check';
import type { CandidatesPerSlot, SharedGeneratorModel, SharedPromptVersion } from '../../src/shared_daily_test';

/**
 * The local measurement E (docs/1.1.0-shared-daily-test-quality.md §13.6):
 * which requests it makes, in which stage, and what they are expected to cost.
 * Pure: no network, no files. `eval/run.ts` does the I/O.
 */

/**
 * The dates every variant generates for, so every variant answers the same
 * plans (owner, 2026-09-28: 3 dates, not 6). Every day has the same 5 topics;
 * the dates differ in theme and in which topic gets which type. These 3 give
 * 3 themes (health, study, technology), both splits (2 fill-in-blank / 3
 * error-correction on the 10th, 3/2 on the 11th and 13th) and every topic in
 * both types, and they put `modalVerbs` and `modalPastForms`, where the 26-27
 * September defects were, into error correction twice each. The first stays
 * 2026-10-10, the synchronous date.
 */
export const EVAL_DATES = ['2026-10-10', '2026-10-11', '2026-10-13'] as const;

/**
 * The dates a finished run can add if its results are not clear
 * (`run --out DIR --add-dates`), in this order. On their own they also give 3
 * themes (family, food, money), both splits and every topic in both types.
 */
export const EXTRA_DATES = ['2026-10-12', '2026-10-14', '2026-10-15'] as const;

export type VariantId = 'G1' | 'G2' | 'G3' | 'G4' | 'G5';
export type Strategy = 'S1' | 'S2';

export interface GenerationVariant {
  id: VariantId;
  promptVersion: SharedPromptVersion;
  model: SharedGeneratorModel;
  candidatesPerSlot: CandidatesPerSlot;
  strategy: Strategy;
}

export const GENERATION_VARIANTS: readonly GenerationVariant[] = [
  { id: 'G1', promptVersion: 1, model: 'claude-sonnet-4-6', candidatesPerSlot: 1, strategy: 'S1' },
  { id: 'G2', promptVersion: 2, model: 'claude-sonnet-4-6', candidatesPerSlot: 1, strategy: 'S1' },
  { id: 'G3', promptVersion: 2, model: 'claude-sonnet-5', candidatesPerSlot: 1, strategy: 'S1' },
  { id: 'G4', promptVersion: 2, model: 'claude-sonnet-4-6', candidatesPerSlot: 2, strategy: 'S2' },
  { id: 'G5', promptVersion: 2, model: 'claude-sonnet-5', candidatesPerSlot: 2, strategy: 'S2' },
];

export type CheckerId = 'K1' | 'K2' | 'K3';

export interface Checker {
  id: CheckerId;
  model: CheckerModel;
  /** The generation variants whose sets this checker reviews. */
  variants: readonly VariantId[];
}

export const CHECKERS: readonly Checker[] = [
  { id: 'K1', model: 'claude-sonnet-5', variants: ['G1', 'G2', 'G3', 'G4', 'G5'] },
  { id: 'K2', model: 'claude-sonnet-4-6', variants: ['G1', 'G2', 'G3'] },
  // The checker if the generator becomes claude-sonnet-5 (owner, 2026-09-27).
  { id: 'K3', model: 'claude-opus-5-5', variants: ['G3'] },
];

/** R1/R2: the published sets of 2026-09-26 and 2026-09-27 (the owner's
 * review); R3: the bundled day-0 set, known good. */
export type ReferenceId = 'R1' | 'R2' | 'R3';
export const REFERENCES: readonly ReferenceId[] = ['R1', 'R2', 'R3'];
export const REFERENCE_REPEATS = 3;

/** Measured spend at which E stops submitting anything (owner, 2026-09-27). */
export const SPEND_CAP_USD = 4;

// ---------------------------------------------------------------------------
// Prices (docs/1.1.0-shared-daily-test-quality.md §13.1, read 2026-09-27 from
// https://platform.claude.com/docs/en/about-claude/pricing)

export type EvalModel = SharedGeneratorModel | CheckerModel;

/** Standard USD per million tokens. */
export const PRICES: Readonly<Record<EvalModel, { input: number; output: number }>> = {
  'claude-sonnet-4-6': { input: 3, output: 15 },
  'claude-sonnet-5': { input: 2, output: 10 },
  // Read 2026-09-29 from the same page: the same price as claude-sonnet-5.
  'claude-sonnet-5-5': { input: 2, output: 10 },
  'claude-opus-5-5': { input: 4, output: 20 },
};

/** "a 50% discount on both input and output tokens". */
export const BATCH_PRICE_FACTOR = 0.5;

export interface Usage {
  inputTokens: number;
  outputTokens: number;
}

/** What [usage] costs on [model], synchronously or through the Batches API.
 * Thinking tokens are part of `output_tokens`. */
export function costOf(model: EvalModel, usage: Usage, sync: boolean): number {
  const price = PRICES[model];
  const list = (usage.inputTokens * price.input + usage.outputTokens * price.output) / 1_000_000;
  return sync ? list : list * BATCH_PRICE_FACTOR;
}

// ---------------------------------------------------------------------------
// Token estimates, until E replaces them with its own measurements (§13.3,
// §13.6; thinking included in output). Keyed by `estimateKey`.

export const TOKEN_ESTIMATES: Readonly<Record<string, Usage>> = {
  'gen:G1': { inputTokens: 1_380, outputTokens: 1_620 }, // measured live, 2026-09-26
  'gen:G2': { inputTokens: 1_830, outputTokens: 1_600 },
  'gen:G3': { inputTokens: 2_380, outputTokens: 4_330 },
  'gen:G4': { inputTokens: 1_900, outputTokens: 3_200 },
  'gen:G5': { inputTokens: 2_470, outputTokens: 6_660 },
  'check:K1:5': { inputTokens: 3_640, outputTokens: 3_510 },
  'check:K1:10': { inputTokens: 5_850, outputTokens: 4_820 },
  'check:K2:5': { inputTokens: 2_800, outputTokens: 2_700 },
  'check:K3:5': { inputTokens: 3_640, outputTokens: 3_510 },
};

// ---------------------------------------------------------------------------
// The plan

/** A: synchronous generations (one date per variant, for wall time and first
 * token counts). B: the other generations, batched. C: one synchronous check
 * per checker (wall time). D: the other checks, batched. */
export type Stage = 'A' | 'B' | 'C' | 'D';

export interface PlannedRequest {
  /** The Batches API `custom_id`: 1-64 of [A-Za-z0-9_-]. */
  customId: string;
  kind: 'generation' | 'check';
  stage: Stage;
  sync: boolean;
  model: EvalModel;
  /** Generations: the variant generated. Checks of a generated set: its variant. */
  variant?: VariantId;
  checker?: CheckerId;
  date?: string;
  reference?: ReferenceId;
  repeat?: number;
  /** Questions in the request (generated or reviewed), as planned. */
  questions: number;
  /** 1 is kept longest when the budget is short; 5 is dropped first. */
  priority: number;
  estimateKey: string;
}

function variant(id: VariantId): GenerationVariant {
  return GENERATION_VARIANTS.find((v) => v.id === id) as GenerationVariant;
}

function checker(id: CheckerId): Checker {
  return CHECKERS.find((c) => c.id === id) as Checker;
}

/** Priority of a variant's generation and its K1 check. */
const VARIANT_PRIORITY: Readonly<Record<VariantId, number>> = { G1: 1, G2: 1, G3: 1, G4: 3, G5: 4 };

function checkPriority(checkerId: CheckerId, variantId?: VariantId): number {
  if (checkerId === 'K2') return 2;
  if (checkerId === 'K3') return 5;
  return variantId ? VARIANT_PRIORITY[variantId] : 1;
}

export const generationId = (v: VariantId, date: string) => `gen_${v}_${date}`;
export const setCheckId = (k: CheckerId, v: VariantId, date: string) => `chk_${k}_${v}_${date}`;
export const referenceCheckId = (k: CheckerId, r: ReferenceId, repeat: number) => `chk_${k}_${r}_${repeat}`;

/** Every request E would make for [dates] if nothing failed and the budget
 * held: with [EVAL_DATES], 15 generations and 54 checks. The first date's
 * generations are the synchronous ones; the reference checks do not depend on
 * the dates. */
export function planRequests(dates: readonly string[] = EVAL_DATES): PlannedRequest[] {
  const requests: PlannedRequest[] = [];
  for (const v of GENERATION_VARIANTS) {
    dates.forEach((date, i) => {
      requests.push({
        customId: generationId(v.id, date),
        kind: 'generation',
        stage: i === 0 ? 'A' : 'B',
        sync: i === 0,
        model: v.model,
        variant: v.id,
        date,
        questions: 5 * v.candidatesPerSlot,
        priority: VARIANT_PRIORITY[v.id],
        estimateKey: `gen:${v.id}`,
      });
    });
  }
  for (const k of CHECKERS) {
    for (const r of REFERENCES) {
      for (let repeat = 1; repeat <= REFERENCE_REPEATS; repeat++) {
        const sync = r === 'R3' && repeat === 1;
        requests.push({
          customId: referenceCheckId(k.id, r, repeat),
          kind: 'check',
          stage: sync ? 'C' : 'D',
          sync,
          model: k.model,
          checker: k.id,
          reference: r,
          repeat,
          questions: 5,
          priority: checkPriority(k.id),
          estimateKey: `check:${k.id}:5`,
        });
      }
    }
    for (const vId of k.variants) {
      const questions = 5 * variant(vId).candidatesPerSlot;
      for (const date of dates) {
        requests.push({
          customId: setCheckId(k.id, vId, date),
          kind: 'check',
          stage: 'D',
          sync: false,
          model: k.model,
          variant: vId,
          checker: k.id,
          date,
          questions,
          priority: checkPriority(k.id, vId),
          estimateKey: `check:${k.id}:${questions}`,
        });
      }
    }
  }
  return requests;
}

export function checkerModel(id: CheckerId): CheckerModel {
  return checker(id).model;
}

export function generationVariant(id: VariantId): GenerationVariant {
  return variant(id);
}

/**
 * The run's dates after adding [requested] (or, with none, every
 * [EXTRA_DATES] date not in it yet) to [current]. Throws on a date that is
 * not a calendar date or is already in the run, and when nothing is left to
 * add. The order is kept, so the first (synchronous) date does not change.
 */
export function addDates(current: readonly string[], requested: readonly string[] = []): string[] {
  const adding = requested.length > 0 ? [...requested] : EXTRA_DATES.filter((d) => !current.includes(d));
  if (adding.length === 0) throw new Error('No dates left to add; name them with --add-dates YYYY-MM-DD,….');
  for (const date of adding) {
    // Only a YYYY-MM-DD calendar date survives the round trip.
    const time = Date.parse(`${date}T00:00:00Z`);
    if (Number.isNaN(time) || new Date(time).toISOString().slice(0, 10) !== date) throw new Error(`Not a calendar date: ${date}.`);
    if (current.includes(date) || adding.indexOf(date) !== adding.lastIndexOf(date)) throw new Error(`Date already in the run: ${date}.`);
  }
  return [...current, ...adding];
}

/** The state key of a batch stage's batch: `B`/`D` for the first round, `B2`,
 * `D2`… for each round of added dates, so an added round never resumes an
 * earlier round's batch. */
export function batchKey(stage: 'B' | 'D', round: number): string {
  return round === 0 ? stage : `${stage}${round + 1}`;
}

/** The estimated cost of [request], from [estimates] (falling back to the
 * static [TOKEN_ESTIMATES]). */
export function estimateCost(request: PlannedRequest, estimates: Readonly<Record<string, Usage>> = TOKEN_ESTIMATES): number {
  const usage = estimates[request.estimateKey] ?? TOKEN_ESTIMATES[request.estimateKey];
  if (!usage) throw new Error(`No token estimate for ${request.estimateKey}.`);
  return costOf(request.model, usage, request.sync);
}

export interface BudgetFit {
  kept: PlannedRequest[];
  dropped: PlannedRequest[];
}

/**
 * The requests of one stage that fit the cap: already [spent] plus the kept
 * requests' estimate times [margin] (the estimates can be off, thinking most)
 * must stay within [cap]. Drops the highest priority number first, and within
 * a priority the last planned first.
 */
export function fitBudget(
  requests: readonly PlannedRequest[],
  spent: number,
  cap: number,
  estimates: Readonly<Record<string, Usage>> = TOKEN_ESTIMATES,
  margin = 1.25,
): BudgetFit {
  const order = requests.map((r, i) => ({ r, i })).sort((a, b) => a.r.priority - b.r.priority || a.i - b.i);
  const kept = [...order];
  const dropped: typeof order = [];
  const total = () => kept.reduce((sum, { r }) => sum + estimateCost(r, estimates), 0);
  while (kept.length > 0 && spent + total() * margin > cap) {
    dropped.unshift(kept.pop() as (typeof order)[number]);
  }
  return {
    kept: kept.sort((a, b) => a.i - b.i).map(({ r }) => r),
    dropped: dropped.sort((a, b) => a.i - b.i).map(({ r }) => r),
  };
}

/** Per-kind totals for the dry run: count and estimated cost. */
export interface PlanSummaryRow {
  stage: Stage;
  kind: string;
  sync: boolean;
  count: number;
  estimatedUsd: number;
}

export function summarizePlan(
  requests: readonly PlannedRequest[],
  estimates: Readonly<Record<string, Usage>> = TOKEN_ESTIMATES,
): { rows: PlanSummaryRow[]; totalRequests: number; totalUsd: number; totalIfAllSyncUsd: number } {
  const rows = new Map<string, PlanSummaryRow>();
  for (const r of requests) {
    const kind = r.kind === 'generation' ? `generation ${r.variant}` : `check ${r.checker} (${r.questions} q)`;
    const key = `${r.stage}|${kind}`;
    const row = rows.get(key) ?? { stage: r.stage, kind, sync: r.sync, count: 0, estimatedUsd: 0 };
    row.count++;
    row.estimatedUsd += estimateCost(r, estimates);
    rows.set(key, row);
  }
  const totalUsd = requests.reduce((s, r) => s + estimateCost(r, estimates), 0);
  const totalIfAllSyncUsd = requests.reduce((s, r) => s + estimateCost({ ...r, sync: true }, estimates), 0);
  return { rows: [...rows.values()], totalRequests: requests.length, totalUsd, totalIfAllSyncUsd };
}
