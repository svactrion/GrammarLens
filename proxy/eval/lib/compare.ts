import { buildBody, type AnthropicRequestBody } from '../../src/anthropic';
import {
  dailyPlan,
  hasSentenceToCorrect,
  sharedDailyTestRequest,
  validateSharedSet,
  type GeneratorEffort,
  type SharedGeneratorModel,
} from '../../src/shared_daily_test';
import { EVAL_DATES, PRICES, costOf, type Usage } from './matrix';

/**
 * The generator comparison (docs/1.1.0-shared-daily-test-quality.md §16):
 * prompt v2 with `claude-sonnet-5` against `claude-sonnet-5-5`, generation
 * only. No check call and no labelling: the proxy's own gate, tokens, cost,
 * time and stop reason per set, plus the question texts for the owner to
 * skim. Pure: no network, no files. `eval/run.ts compare` does the I/O.
 */

export type CompareVariantId = 'V1' | 'V2' | 'V3';

export interface CompareVariant {
  id: CompareVariantId;
  model: SharedGeneratorModel;
  /** Absent: no `effort` field, the model's API default (`high`). */
  effort?: GeneratorEffort;
}

/**
 * V1 is the cron's request today. V2 is `claude-sonnet-5-5` as the cron would
 * send it after a one-line switch. V3 adds `effort: "low"`: Sonnet 5.5's
 * levels are recalibrated, so the default is not the same amount of thinking
 * as on Sonnet 5, and `low` is the cheaper setting the docs name for content
 * generation (and the one where they warn that thinking may run to
 * `max_tokens` with structured outputs, which the stop reasons here show).
 */
export const COMPARE_VARIANTS: readonly CompareVariant[] = [
  { id: 'V1', model: 'claude-sonnet-5' },
  { id: 'V2', model: 'claude-sonnet-5-5' },
  { id: 'V3', model: 'claude-sonnet-5-5', effort: 'low' },
];

/** E's dates, so V1 can be read against E's G3 (the same request, measured
 * 2026-09-28) and every variant answers the same three plans. */
export const COMPARE_DATES: readonly string[] = EVAL_DATES;

/** Measured spend is never allowed past this (owner, 2026-09-29). */
export const COMPARE_SPEND_CAP_USD = 1;

/** The cron's limits (`GENERATION_TIMEOUT_MS`, before and after 2026-09-29). */
export const TIMEOUT_LIMITS_S = [90, 150] as const;

/**
 * Tokens per set until the run measures them: E's G3 (v2, `claude-sonnet-5`,
 * the same request as V1), mean of its 3 sets. Sonnet 5.5 has the same
 * tokenizer, so input is the same; its output is not known yet and uses the
 * same figure.
 */
export const COMPARE_ESTIMATE: Usage = { inputTokens: 2_390, outputTokens: 4_450 };

/** The margin on the input estimate in the worst-case bound. */
const INPUT_MARGIN = 1.25;

export interface CompareRequest {
  customId: string;
  variant: CompareVariantId;
  date: string;
}

export const compareId = (variant: CompareVariantId, date: string) => `cmp_${variant}_${date}`;

/** One synchronous call per variant and date, date by date, so a run that
 * stops at the cap has still covered every variant equally far. */
export function planComparison(dates: readonly string[] = COMPARE_DATES): CompareRequest[] {
  return dates.flatMap((date) => COMPARE_VARIANTS.map((v) => ({ customId: compareId(v.id, date), variant: v.id, date })));
}

export function compareVariant(id: CompareVariantId): CompareVariant {
  const v = COMPARE_VARIANTS.find((x) => x.id === id);
  if (!v) throw new Error(`Unknown variant ${id}`);
  return v;
}

/** The exact body the Worker's builder makes: prompt v2, the day's plan, no
 * avoid list (as in E). */
export function comparisonBody(request: CompareRequest): AnthropicRequestBody {
  const v = compareVariant(request.variant);
  const shared = sharedDailyTestRequest(dailyPlan(request.date), [], {
    promptVersion: 2,
    model: v.model,
    ...(v.effort ? { effort: v.effort } : {}),
  });
  return buildBody({ op: 'generate_shared_daily_test', request: shared });
}

export function estimatedCostUsd(request: CompareRequest): number {
  return costOf(compareVariant(request.variant).model, COMPARE_ESTIMATE, true);
}

/** The most one call can cost: the input estimate with a margin, and every
 * token `max_tokens` allows billed as output (thinking included). */
export function worstCaseCostUsd(request: CompareRequest): number {
  const model = compareVariant(request.variant).model;
  const price = PRICES[model];
  const body = comparisonBody(request);
  return (COMPARE_ESTIMATE.inputTokens * INPUT_MARGIN * price.input + body.max_tokens * price.output) / 1_000_000;
}

/** A call is made only if it cannot take measured spend past the cap even in
 * its worst case, so the cap holds without trusting any estimate. */
export function fitsCap(spentUsd: number, request: CompareRequest, capUsd = COMPARE_SPEND_CAP_USD): boolean {
  return spentUsd + worstCaseCostUsd(request) <= capUsd;
}

// ---------------------------------------------------------------------------
// Records and the summary

export interface CompareRecord {
  customId: string;
  variant: CompareVariantId;
  date: string;
  model: SharedGeneratorModel;
  effort?: GeneratorEffort;
  status: 'ok' | 'unparseable' | 'http_error' | 'network_error' | 'skipped_budget';
  httpStatus?: number;
  errorType?: string;
  inputTokens?: number;
  outputTokens?: number;
  stopReason?: string | null;
  /** Request to full response, of the attempt that answered. */
  durationMs?: number;
  costUsd: number;
  /** The parsed structured output. */
  content?: unknown;
}

/** What the proxy's gate says about a record: the set passed, or why not. */
export function gateResult(record: CompareRecord): { passed: true } | { passed: false; reason: string } {
  if (record.status === 'ok') {
    const result = validateSharedSet(record.content, dailyPlan(record.date));
    return result.ok ? { passed: true } : { passed: false, reason: result.reason };
  }
  if (record.status === 'http_error') return { passed: false, reason: `http_${record.httpStatus}_${record.errorType ?? 'unknown'}` };
  return { passed: false, reason: record.status };
}

function questionsOf(content: unknown): Record<string, unknown>[] {
  const q = (content as { questions?: unknown } | null)?.questions;
  return Array.isArray(q) ? q.filter((x): x is Record<string, unknown> => typeof x === 'object' && x !== null) : [];
}

export interface VariantSummary {
  variant: CompareVariant;
  planned: number;
  /** Calls made (billed or failed), not the ones left out for the cap. */
  sent: number;
  skippedBudget: number;
  passed: number;
  /** Gate rejection code (or call failure) → sets. */
  rejections: Record<string, number>;
  /** Across every returned set, whatever the gate said: `validateSharedSet`
   * reports only a set's first problem. */
  errorCorrection: { total: number; withoutSentence: number };
  avgInputTokens: number | null;
  avgOutputTokens: number | null;
  /** Mean cost of the billed calls: the cost of one set as the cron pays it. */
  costPerSetUsd: number | null;
  totalCostUsd: number;
  avgDurationS: number | null;
  maxDurationS: number | null;
  /** Calls that took longer than each limit in [TIMEOUT_LIMITS_S]. */
  overLimit: Record<number, number>;
  stopReasons: Record<string, number>;
}

const mean = (values: number[]) => (values.length === 0 ? null : values.reduce((s, v) => s + v, 0) / values.length);

export function summarizeComparison(records: readonly CompareRecord[], dates: readonly string[] = COMPARE_DATES): VariantSummary[] {
  return COMPARE_VARIANTS.map((variant) => {
    const own = records.filter((r) => r.variant === variant.id);
    const sent = own.filter((r) => r.status !== 'skipped_budget');
    const billed = sent.filter((r) => r.inputTokens !== undefined);
    const rejections: Record<string, number> = {};
    let passed = 0;
    for (const r of sent) {
      const gate = gateResult(r);
      if (gate.passed) passed++;
      else rejections[gate.reason] = (rejections[gate.reason] ?? 0) + 1;
    }
    const ec = sent.flatMap((r) => questionsOf(r.content)).filter((q) => q.type === 'error_correction');
    const durations = sent.flatMap((r) => (r.durationMs === undefined ? [] : [r.durationMs / 1000]));
    const stopReasons: Record<string, number> = {};
    for (const r of billed) {
      const key = r.stopReason ?? 'none';
      stopReasons[key] = (stopReasons[key] ?? 0) + 1;
    }
    return {
      variant,
      planned: dates.length,
      sent: sent.length,
      skippedBudget: own.length - sent.length,
      passed,
      rejections,
      errorCorrection: { total: ec.length, withoutSentence: ec.filter((q) => !hasSentenceToCorrect(q.context)).length },
      avgInputTokens: mean(billed.map((r) => r.inputTokens as number)),
      avgOutputTokens: mean(billed.map((r) => r.outputTokens ?? 0)),
      costPerSetUsd: mean(billed.map((r) => r.costUsd)),
      totalCostUsd: own.reduce((s, r) => s + r.costUsd, 0),
      avgDurationS: mean(durations),
      maxDurationS: durations.length === 0 ? null : Math.max(...durations),
      overLimit: Object.fromEntries(TIMEOUT_LIMITS_S.map((limit) => [limit, durations.filter((d) => d > limit).length])),
      stopReasons,
    };
  });
}

export function variantLabel(v: CompareVariant): string {
  return `${v.id}: v2 + ${v.model}, effort ${v.effort ?? 'default'}`;
}

const fixed = (v: number | null, digits: number) => (v === null ? '–' : v.toFixed(digits));
const counts = (m: Record<string, number>) =>
  Object.keys(m).length === 0
    ? '–'
    : Object.entries(m)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([k, n]) => `${k} ×${n}`)
        .join(', ');

/** The report: one row per variant. Numbers only, no generated text. */
export function renderComparisonReport(summaries: readonly VariantSummary[], meta: { dates: readonly string[]; generatedAt: string }): string {
  const lines = [
    '# Generator comparison: prompt v2, claude-sonnet-5 vs claude-sonnet-5-5',
    '',
    `Dates: ${meta.dates.join(', ')}. Written ${meta.generatedAt}. Synchronous calls, list price. No check call, no labels.`,
    '',
    '| Variant | Sets passing the gate | Gate rejections / failures | error_correction without a sentence | Avg input | Avg output | Cost per set | Total | Avg time | Max time | > 90 s | > 150 s | stop_reason |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|',
  ];
  for (const s of summaries) {
    const skipped = s.skippedBudget > 0 ? ` (${s.skippedBudget} left out for the cap)` : '';
    lines.push(
      `| ${variantLabel(s.variant)} | ${s.passed} of ${s.sent}${skipped} | ${counts(s.rejections)} | ${s.errorCorrection.withoutSentence} of ${s.errorCorrection.total} | ${fixed(s.avgInputTokens, 0)} | ${fixed(s.avgOutputTokens, 0)} | ${s.costPerSetUsd === null ? '–' : `$${s.costPerSetUsd.toFixed(3)}`} | $${s.totalCostUsd.toFixed(3)} | ${s.avgDurationS === null ? '–' : `${s.avgDurationS.toFixed(1)} s`} | ${s.maxDurationS === null ? '–' : `${s.maxDurationS.toFixed(1)} s`} | ${s.overLimit[90]} | ${s.overLimit[150]} | ${counts(s.stopReasons)} |`,
    );
  }
  lines.push(
    '',
    '- **Gate:** `validateSharedSet`, the cron\'s own check; it reports only the first problem of a set.',
    '- **error_correction without a sentence:** counted over every returned set, whatever the gate said.',
    '- **Cost per set:** the mean billed cost of one call, what the cron pays per attempt.',
    '- **Time:** request to full response. The cron gives up at 150 s (90 s before 2026-09-29); a call over the limit would have been cut off and still billed.',
    '- **stop_reason `max_tokens`:** the answer was truncated (thinking included); treat as a failed attempt.',
    '- The question texts are in `questions.md`; the full sets in `records.json`.',
    '',
  );
  return lines.join('\n');
}

/** The owner's reading file: per set, only each question's sentence and
 * instruction (no key, no wrong answers, no explanation). */
export function renderQuestions(records: readonly CompareRecord[]): string {
  const out = ['# Generated questions (question text only)', ''];
  const ordered = [...records].sort((a, b) => a.variant.localeCompare(b.variant) || a.date.localeCompare(b.date));
  for (const r of ordered) {
    if (r.status === 'skipped_budget') continue;
    const v = compareVariant(r.variant);
    const gate = gateResult(r);
    out.push(`## ${variantLabel(v)} — ${r.date} — ${gate.passed ? 'passes the gate' : `rejected: ${gate.reason}`}`, '');
    const questions = questionsOf(r.content);
    if (questions.length === 0) out.push('(no questions)', '');
    questions.forEach((q, i) => {
      const text = (x: unknown) => (typeof x === 'string' ? x.replace(/\s+/g, ' ').trim() : '');
      out.push(`${i + 1}. [${text(q.topicId)} · ${text(q.type)}] ${text(q.context) || '(no sentence)'}`);
      out.push(`   ${text(q.instruction)}`);
    });
    out.push('');
  }
  return out.join('\n');
}
