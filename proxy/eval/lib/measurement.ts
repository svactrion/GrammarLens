import {
  buildBody,
  buildGeneratePracticeSetBodyFor,
  buildScoreAnswersBodyFor,
  type AnthropicRequestBody,
  type PracticeVariant,
  type ScoringVariant,
} from '../../src/anthropic';
import { ANNOTATION_CHECKERS, sharedCheckRequest, type CheckerModel } from '../../src/shared_check';
import { dailyPlan, sharedDailyTestRequest, type SharedPromptVersion, type SharedQuestion } from '../../src/shared_daily_test';
import { TOPICS } from '../../src/topics';
import type { ScoreAnswersRequest } from '../../src/validation';
import { keyFactory, type LabelledAnswer, type LiveSetFile } from './datasets';
import { buildLabelSheet, seededRandom, shuffle, toCsv } from './labels';
import { EVAL_DATES, EXTRA_DATES, costOf, type EvalModel, type Usage } from './matrix';

/**
 * The 1.4.0 server package measurement (docs/1.4.0-server-batch0-report.md
 * §3; owner additions 2026-10-31): which calls it makes, in which stage, with
 * which request body, and what each is expected to cost. Pure: no network, no
 * files. `eval/run.ts measure` does the I/O.
 *
 * Every call goes through the proxy's own builders, so a cell's body is what
 * the proxy would send with that choice. The provider is a parameter of the
 * harness, not of this plan: a future provider change is a new request
 * adapter in `run.ts` plus a re-run (owner's design constraint).
 */

export const PROVIDER = 'anthropic' as const;

// ---------------------------------------------------------------------------
// Cells

export type ScoringCellId = 'C1' | 'C2' | 'C3' | 'C4' | 'C5' | 'C6' | 'C7' | 'C8';

export interface ScoringCell extends ScoringVariant {
  id: ScoringCellId;
  model: EvalModel;
  why: string;
}

/** Report §3.3. `claude-sonnet-4-6` as production sends it (no thinking); the
 * current models with adaptive thinking at `low` or `medium`. */
export const SCORING_CELLS: readonly ScoringCell[] = [
  { id: 'C1', model: 'claude-sonnet-4-6', prompt: 'live', why: 'production today' },
  { id: 'C2', model: 'claude-sonnet-4-6', prompt: 'd3d11', why: 'the prompt and schema effect alone' },
  { id: 'C3', model: 'claude-sonnet-5-5', thinking: true, effort: 'low', prompt: 'live', why: 'the model effect alone' },
  { id: 'C4', model: 'claude-sonnet-5-5', thinking: true, effort: 'low', prompt: 'd3d11', why: 'the expected production cell' },
  { id: 'C5', model: 'claude-sonnet-5-5', thinking: true, effort: 'medium', prompt: 'd3d11', why: 'does more thinking buy accuracy' },
  { id: 'C6', model: 'claude-sonnet-5-5', thinking: true, effort: 'medium', prompt: 'live', why: "completes the owner's 2 × 2 × 2" },
  { id: 'C7', model: 'claude-haiku-5-5', thinking: true, effort: 'low', prompt: 'live', why: 'the cheapest current model (owner addition)' },
  { id: 'C8', model: 'claude-haiku-5-5', thinking: true, effort: 'low', prompt: 'd3d11', why: 'its production candidate cell' },
];

export type GenerationCellId = 'G-A' | 'G-B' | 'G-C' | 'G-D' | 'G-E' | 'G-F';

export interface GenerationCell extends PracticeVariant {
  id: GenerationCellId;
  model: EvalModel;
}

export const GENERATION_CELLS: readonly GenerationCell[] = [
  { id: 'G-A', model: 'claude-sonnet-4-6', prompt: 'live' },
  { id: 'G-B', model: 'claude-sonnet-4-6', prompt: 'd3' },
  { id: 'G-C', model: 'claude-sonnet-5-5', thinking: true, effort: 'low', prompt: 'live' },
  { id: 'G-D', model: 'claude-sonnet-5-5', thinking: true, effort: 'low', prompt: 'd3' },
  { id: 'G-E', model: 'claude-haiku-5-5', thinking: true, effort: 'low', prompt: 'live' },
  { id: 'G-F', model: 'claude-haiku-5-5', thinking: true, effort: 'low', prompt: 'd3' },
];

/** The D3-prompt cells: S-free answers are written for their items only
 * (owner, 2026-10-31). */
export const S_FREE_CELLS: readonly GenerationCellId[] = ['G-B', 'G-D', 'G-F'];

/** Items per generated practice set (the app's "Standard" length). */
export const ITEMS_PER_SET = 5;

/** Answers per scoring call, as the app sends a Standard set. */
export const ANSWERS_PER_CALL = 5;

/** The Daily Test v2/v3 check: E's six dates (report §2.3). */
export const DT_DATES: readonly string[] = [...EVAL_DATES, ...EXTRA_DATES];
export const DT_VERSIONS: readonly SharedPromptVersion[] = [2, 3];

/** Each gate check repeated, for the agreement rate's stability. */
export const GATE_REPEATS = 2;

/** The S-free writer: `claude-sonnet-5-5` at `low`, one call per five items. */
export const S_FREE_WRITER: EvalModel = 'claude-sonnet-5-5';
export const S_FREE_ITEMS_PER_CALL = 5;

/** Measured spend is never allowed past this (owner, 2026-10-31). */
export const MEASURE_SPEND_CAP_USD = 30;

/** The scoring cells run a second time (owner, 2026-10-31, step E go): the
 * production baseline, the expected production cell and the Haiku
 * candidate; dropped in the reverse order, C8's repeat first, C1's last. */
export const REPEAT_CELLS: readonly ScoringCellId[] = ['C1', 'C4', 'C8'];

// ---------------------------------------------------------------------------
// The S-free writer's prompt (a harness prompt, not a proxy prompt)

export const S_FREE_SYSTEM_PROMPT = `
You write realistic learner answers to English grammar practice items, for a
test of an automatic scorer. For each item you get its text and a target:
"error" or "correct". For "error", answer as a B1-B2 learner whose first
language is not English would, with exactly one typical grammar mistake in
the structure the item tests and nothing else wrong. For "correct", write a
natural, fully correct answer a strong learner would give. For a
fill_in_blank item give the completed sentence with every blank filled; for
error_correction the full rewritten sentence; for sentence_writing one
sentence. Return one answer per item with its "itemId".
`.trim();

export function sFreeBody(items: readonly { id: string; type: string; prompt: string; target: 'error' | 'correct' }[]): AnthropicRequestBody {
  return {
    model: S_FREE_WRITER,
    max_tokens: 1024 + 12_000,
    system: S_FREE_SYSTEM_PROMPT,
    thinking: { type: 'adaptive' },
    output_config: {
      format: {
        type: 'json_schema',
        schema: {
          type: 'object',
          properties: {
            answers: {
              type: 'array',
              items: {
                type: 'object',
                properties: { itemId: { type: 'string' }, answer: { type: 'string' } },
                required: ['itemId', 'answer'],
                additionalProperties: false,
              },
            },
          },
          required: ['answers'],
          additionalProperties: false,
        },
      },
      effort: 'low',
    },
    messages: [{ role: 'user', content: JSON.stringify({ items }) }],
  };
}

// ---------------------------------------------------------------------------
// Grouping answers into calls

/**
 * Scoring calls of [ANSWERS_PER_CALL] answers, no two of them answers to the
 * same question (the model would otherwise read one against the other), in a
 * shuffled order fixed by [seed] so every cell scores the same calls.
 */
export function groupAnswers(answers: readonly LabelledAnswer[], seed: number): LabelledAnswer[][] {
  const pending = shuffle(answers, seededRandom(seed));
  const calls: LabelledAnswer[][] = [];
  while (pending.length > 0) {
    const call: LabelledAnswer[] = [];
    const used = new Set<string>();
    for (let i = 0; i < pending.length && call.length < ANSWERS_PER_CALL; ) {
      const a = pending[i] as LabelledAnswer;
      if (used.has(a.item.id)) {
        i++;
        continue;
      }
      call.push(a);
      used.add(a.item.id);
      pending.splice(i, 1);
    }
    calls.push(call);
  }
  return calls;
}

/** The request a scoring call sends: each answer as its own item, the id made
 * unique per answer so the feedback maps back. */
export function scoringRequest(call: readonly LabelledAnswer[]): ScoreAnswersRequest {
  return {
    deviceId: 'measurement',
    items: call.map((a) => ({ id: a.id, type: a.item.type, prompt: a.item.prompt, userAnswer: a.userAnswer })),
  };
}

// ---------------------------------------------------------------------------
// Token estimates

/**
 * Input tokens from a body's characters. The ratio is calibrated on a request
 * of the same kind whose input tokens were measured: the shared v2 generation
 * for 2026-10-10 with no avoid list, 2,875 input tokens (the 2026-09-29
 * comparison, three calls, all 2,875). The ratio comes out at 2.33, well
 * under the ≈ 4 of English prose, because the measured input counts the
 * structured-output grammar as well as the schema's characters; applied to
 * every body it over-estimates prose-heavy inputs, so the step-D figures are
 * upper bounds, the safe side for a spend cap.
 */
export const CALIBRATION = { date: '2026-10-10', promptVersion: 2 as SharedPromptVersion, measuredInputTokens: 2_875 } as const;

export function bodyCharacters(body: AnthropicRequestBody): number {
  // What the model reads: the system prompt, the messages, and the schema it
  // is constrained to (sent as grammar, counted as input).
  return body.system.length + body.messages.reduce((n, m) => n + m.content.length, 0) + JSON.stringify(body.output_config.format.schema).length;
}

export function charactersPerToken(): number {
  const body = buildBody({
    op: 'generate_shared_daily_test',
    request: sharedDailyTestRequest(dailyPlan(CALIBRATION.date), [], {
      promptVersion: CALIBRATION.promptVersion,
      model: 'claude-sonnet-5-5',
      effort: 'low',
    }),
  });
  return bodyCharacters(body) / CALIBRATION.measuredInputTokens;
}

export function estimateInputTokens(body: AnthropicRequestBody, ratio = charactersPerToken()): number {
  return Math.round(bodyCharacters(body) / ratio);
}

/**
 * Output tokens per call, estimates with their source (report §3.4):
 * scoring ≈ 140 per item on the live schema and ≈ 220 with D11's notes and
 * summary; adaptive thinking adds ≈ 400 at `low` and ≈ 1,400 at `medium`
 * (the comparison: `low` wrote 1,354 where the default wrote 4,792);
 * generation ≈ 220 per item plus thinking; the Daily Test as measured
 * (1,354–1,377); checks as E measured Opus (≈ 1,600) and an estimate for
 * Sonnet 5.5 (≈ 2,000).
 */
export function thinkingTokens(cell: { thinking?: boolean; effort?: string }): number {
  if (!cell.thinking) return 0;
  return cell.effort === 'medium' ? 1_400 : 400;
}

export function scoringOutputTokens(cell: ScoringCell, answers: number): number {
  return (cell.prompt === 'live' ? 140 : 220) * answers + thinkingTokens(cell);
}

export function generationOutputTokens(cell: GenerationCell): number {
  return 220 * ITEMS_PER_SET + thinkingTokens(cell);
}

export const DT_OUTPUT_TOKENS = 1_377;
export const S_FREE_OUTPUT_TOKENS = 80 * S_FREE_ITEMS_PER_CALL + 400;
export const CHECK_OUTPUT_TOKENS: Readonly<Record<CheckerModel, number>> = {
  'claude-opus-5-5': 1_600,
  'claude-sonnet-5-5': 2_000,
  'claude-sonnet-5': 3_500,
  'claude-sonnet-4-6': 2_700,
};

// ---------------------------------------------------------------------------
// The plan

export type Stage = 'generation' | 's_free' | 'daily_test' | 'gate' | 'scoring' | 'scoring_repeat';

export interface PlannedCall {
  customId: string;
  stage: Stage;
  /** The cell or group the call belongs to, for the table. */
  group: string;
  model: EvalModel;
  body: AnthropicRequestBody;
  estimate: Usage;
  /** Dropped first when the cap is short: the highest number first. */
  dropPriority: number;
}

export interface MeasurementInputs {
  pool: readonly LabelledAnswer[];
  synth: readonly LabelledAnswer[];
  /** S-free answers once written; before the run, placeholders of the
   * expected count so the estimate covers them. */
  sFree: readonly LabelledAnswer[];
  /** The sets the gate reviews: S-pool's seven live dates, S-live's twenty,
   * and the three prompt-v1 references. */
  gateSets: readonly LiveSetFile[];
  seed: number;
}

/** Which drop comes first when the measured spend would pass the cap (the
 * owner reads the order in the step-D table): the scoring repeat, then the
 * second gate repeat, then C6 and C5 (medium effort, the least decisive
 * cells), then the gate's Sonnet checker (the single-review gate still
 * measurable), then everything else stays. */
export const DROP_ORDER: readonly { priority: number; what: string }[] = [
  { priority: 8, what: "C8's repeat (Haiku 5.5 low, D3 + D11)" },
  { priority: 7, what: "C4's repeat (Sonnet 5.5 low, D3 + D11)" },
  { priority: 6, what: "C1's repeat (Sonnet 4.6, live: the production baseline)" },
  { priority: 5, what: 'the second gate repeat' },
  { priority: 4, what: 'C6 (Sonnet 5.5 medium, live prompt)' },
  { priority: 3, what: 'C5 (Sonnet 5.5 medium, D3 + D11)' },
  { priority: 2, what: "the gate's claude-sonnet-5-5 checker (the agreement gate is then not measured)" },
  { priority: 1, what: 'everything else: never dropped; the run stops instead' },
];

function priorityOf(stage: Stage, group: string, model?: string): number {
  if (stage === 'scoring_repeat') return group === 'C8' ? 8 : group === 'C4' ? 7 : 6;
  if (stage === 'gate' && group.endsWith('r2')) return 5;
  if (group === 'C6') return 4;
  if (group === 'C5') return 3;
  if (stage === 'gate' && model === 'claude-sonnet-5-5') return 2;
  return 1;
}

export function planMeasurement(inputs: MeasurementInputs, ratio = charactersPerToken()): PlannedCall[] {
  const calls: PlannedCall[] = [];
  const add = (c: Omit<PlannedCall, 'estimate' | 'dropPriority'> & { outputTokens: number }) => {
    calls.push({
      customId: c.customId,
      stage: c.stage,
      group: c.group,
      model: c.model,
      body: c.body,
      estimate: { inputTokens: estimateInputTokens(c.body, ratio), outputTokens: c.outputTokens },
      dropPriority: priorityOf(c.stage, c.group, c.model),
    });
  };

  // 1. Generation: every cell, every topic, one Standard set.
  for (const cell of GENERATION_CELLS) {
    for (const topic of TOPICS) {
      add({
        customId: `gen_${cell.id}_${topic.id}`,
        stage: 'generation',
        group: cell.id,
        model: cell.model,
        body: buildGeneratePracticeSetBodyFor({ deviceId: 'measurement', topicId: topic.id, count: ITEMS_PER_SET }, cell),
        outputTokens: generationOutputTokens(cell),
      });
    }
  }

  // 2. S-free answers written for the D3-prompt cells' items (placeholders
  //    before the run: the items do not exist yet).
  const sFreeItems = S_FREE_CELLS.length * TOPICS.length * ITEMS_PER_SET;
  for (let i = 0; i < Math.ceil(sFreeItems / S_FREE_ITEMS_PER_CALL); i++) {
    const placeholder = Array.from({ length: S_FREE_ITEMS_PER_CALL }, (_, j) => ({
      id: `item-${i}-${j}`,
      type: 'sentence_writing',
      prompt: 'You are writing to a colleague about a deadline that is approaching this week.\nUsing "should" or "must", write one sentence about what your team needs to do.',
      target: (j % 2 === 0 ? 'error' : 'correct') as 'error' | 'correct',
    }));
    add({ customId: `sfree_${i}`, stage: 's_free', group: 'S-free', model: S_FREE_WRITER, body: sFreeBody(placeholder), outputTokens: S_FREE_OUTPUT_TOKENS });
  }

  // 3. The Daily Test v2 vs v3 check: the live generator on six dates.
  for (const version of DT_VERSIONS) {
    for (const date of DT_DATES) {
      add({
        customId: `dt_v${version}_${date}`,
        stage: 'daily_test',
        group: `DT v${version}`,
        model: 'claude-sonnet-5-5',
        body: buildBody({ op: 'generate_shared_daily_test', request: sharedDailyTestRequest(dailyPlan(date), [], { promptVersion: version }) }),
        outputTokens: DT_OUTPUT_TOKENS,
      });
    }
  }

  // 4. The P14 gate: both checkers over every set, twice.
  for (let repeat = 1; repeat <= GATE_REPEATS; repeat++) {
    for (const model of ANNOTATION_CHECKERS.agreement) {
      for (const set of inputs.gateSets) {
        add({
          customId: `gate_${model}_${set.date}_r${repeat}`,
          stage: 'gate',
          group: `gate ${model} r${repeat}`,
          model,
          body: buildBody({ op: 'check_shared_daily_test', request: sharedCheckRequest(set.questions as SharedQuestion[], model) }),
          outputTokens: CHECK_OUTPUT_TOKENS[model],
        });
      }
    }
  }

  // 5. Scoring: every cell over the same calls; then the repeat.
  const groups = groupAnswers([...inputs.pool, ...inputs.synth, ...inputs.sFree], inputs.seed);
  for (const stage of ['scoring', 'scoring_repeat'] as const) {
    for (const cell of SCORING_CELLS) {
      if (stage === 'scoring_repeat' && !REPEAT_CELLS.includes(cell.id)) continue;
      groups.forEach((call, i) => {
        add({
          customId: `${stage === 'scoring' ? 'score' : 'score2'}_${cell.id}_${i}`,
          stage,
          group: cell.id,
          model: cell.model,
          body: buildScoreAnswersBodyFor(scoringRequest(call), cell),
          outputTokens: scoringOutputTokens(cell, call.length),
        });
      });
    }
  }
  return calls;
}

/** Placeholder S-free answers of the expected count, for the estimate. */
export function sFreePlaceholders(count = S_FREE_CELLS.length * TOPICS.length * ITEMS_PER_SET): LabelledAnswer[] {
  return Array.from({ length: count }, (_, i) => ({
    id: `sfree:placeholder:${i}`,
    set: 'S-synth',
    item: {
      id: `sfree-item-${i}`,
      type: i % 3 === 0 ? 'sentence_writing' : i % 3 === 1 ? 'error_correction' : 'fill_in_blank',
      prompt: 'You are writing to a colleague about a project deadline that is approaching.\nUsing "should" or "must", write one sentence explaining what your team needs to do before the deadline.',
    },
    userAnswer: 'We must to finish the report before Friday because the client is waiting.',
    truth: false,
    kind: 'placeholder',
    correctAnswer: '',
  }));
}

// ---------------------------------------------------------------------------
// The table

export interface GroupCost {
  stage: Stage;
  group: string;
  model: EvalModel;
  calls: number;
  meanInput: number;
  meanOutput: number;
  costPerCall: number;
  costUsd: number;
  dropPriority: number;
}

export function summarize(calls: readonly PlannedCall[]): GroupCost[] {
  const byGroup = new Map<string, PlannedCall[]>();
  for (const c of calls) {
    const key = `${c.stage}|${c.group}`;
    byGroup.set(key, [...(byGroup.get(key) ?? []), c]);
  }
  return [...byGroup.values()].map((group) => {
    const first = group[0] as PlannedCall;
    const cost = group.reduce((n, c) => n + costOf(c.model, c.estimate, true), 0);
    return {
      stage: first.stage,
      group: first.group,
      model: first.model,
      calls: group.length,
      meanInput: Math.round(group.reduce((n, c) => n + c.estimate.inputTokens, 0) / group.length),
      meanOutput: Math.round(group.reduce((n, c) => n + c.estimate.outputTokens, 0) / group.length),
      costPerCall: cost / group.length,
      costUsd: cost,
      dropPriority: first.dropPriority,
    };
  });
}

export function totalUsd(calls: readonly PlannedCall[]): number {
  return calls.reduce((n, c) => n + costOf(c.model, c.estimate, true), 0);
}

/** The calls that fit the cap, dropping the highest priority first, whole
 * groups at a time; what was dropped is reported. */
export function fitCap(calls: readonly PlannedCall[], cap = MEASURE_SPEND_CAP_USD, margin = 1.25): { kept: PlannedCall[]; dropped: string[] } {
  let kept = [...calls];
  const dropped: string[] = [];
  while (kept.length > 0 && totalUsd(kept) * margin > cap) {
    const highest = Math.max(...kept.map((c) => c.dropPriority));
    if (highest <= 1) break;
    // Within a priority, the costliest group goes first: trimming a cheap
    // Haiku cell would buy nothing.
    const victims = kept.filter((c) => c.dropPriority === highest);
    const costByGroup = new Map<string, number>();
    for (const v of victims) {
      const key = `${v.stage}|${v.group}`;
      costByGroup.set(key, (costByGroup.get(key) ?? 0) + costOf(v.model, v.estimate, true));
    }
    const target = [...costByGroup.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] as string;
    kept = kept.filter((c) => `${c.stage}|${c.group}` !== target);
    dropped.push(target.replace('|', ' / '));
  }
  return { kept, dropped };
}

const money = (n: number) => `$${n.toFixed(2)}`;

export function renderCostTable(calls: readonly PlannedCall[], ratio: number): string {
  const rows = summarize(calls);
  const out: string[] = [
    `Characters per input token (calibrated on ${CALIBRATION.measuredInputTokens} measured tokens): ${ratio.toFixed(2)}`,
    '',
    '| Stage | Cell / group | Model | Calls | Mean input | Mean output (incl. thinking) | Cost per call | Cost |',
    '|---|---|---|---|---|---|---|---|',
  ];
  const stageOrder: Stage[] = ['generation', 's_free', 'daily_test', 'gate', 'scoring', 'scoring_repeat'];
  for (const stage of stageOrder) {
    const inStage = rows.filter((r) => r.stage === stage);
    for (const r of inStage) {
      out.push(`| ${stage} | ${r.group} | ${r.model} | ${r.calls} | ${r.meanInput} | ${r.meanOutput} | $${r.costPerCall.toFixed(4)} | ${money(r.costUsd)} |`);
    }
    if (inStage.length > 1) out.push(`| **${stage}** | | | ${inStage.reduce((n, r) => n + r.calls, 0)} | | | | **${money(inStage.reduce((n, r) => n + r.costUsd, 0))}** |`);
  }
  const main = calls.filter((c) => c.stage !== 'scoring_repeat');
  out.push('', `Total without the scoring repeat: **${money(totalUsd(main))}** (${main.length} calls); with it: **${money(totalUsd(calls))}** (${calls.length} calls); cap ${money(MEASURE_SPEND_CAP_USD)}.`);
  const fit = fitCap(calls);
  out.push(fit.dropped.length === 0 ? 'Everything fits the cap with a 25 % margin on the estimate.' : `With a 25 % margin the cap drops: ${fit.dropped.join('; ')}.`);
  out.push('', 'Drop order if the measured spend runs ahead of the estimate:', ...DROP_ORDER.map((d) => `${9 - d.priority}. ${d.what}`));
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Stage 1's runtime pieces (pure; `run.ts measure run` does the I/O)

/** A generated practice item as the app would show it, with where it came from. */
export interface SGenItem {
  /** Unique across cells: `<cell>:<topic>:<model's id>`. */
  id: string;
  cell: GenerationCellId;
  topicId: string;
  type: 'fill_in_blank' | 'error_correction' | 'sentence_writing';
  context?: string;
  instruction: string;
  hint?: string;
  prompt: string;
}

const ITEM_TYPES = new Set(['fill_in_blank', 'error_correction', 'sentence_writing']);

/** The items of one generation call's output, in order; an entry without an
 * id, a known type or an instruction is left out and counted. */
export function sGenItemsFrom(cell: GenerationCellId, topicId: string, content: unknown): { items: SGenItem[]; dropped: number } {
  const raw = (content as { items?: unknown[] } | null)?.items;
  if (!Array.isArray(raw)) return { items: [], dropped: 0 };
  const items: SGenItem[] = [];
  let dropped = 0;
  const seen = new Set<string>();
  for (const entry of raw) {
    const e = (entry ?? {}) as Record<string, unknown>;
    const id = typeof e.id === 'string' ? e.id : '';
    const type = typeof e.type === 'string' && ITEM_TYPES.has(e.type) ? (e.type as SGenItem['type']) : null;
    const instruction = typeof e.instruction === 'string' ? e.instruction : '';
    if (!id || !type || !instruction.trim() || seen.has(id)) {
      dropped++;
      continue;
    }
    seen.add(id);
    const context = typeof e.context === 'string' && e.context.trim().length > 0 ? e.context : undefined;
    const hint = typeof e.hint === 'string' && e.hint.trim().length > 0 ? e.hint : undefined;
    items.push({
      id: `${cell}:${topicId}:${id}`,
      cell,
      topicId,
      type,
      ...(context === undefined ? {} : { context }),
      instruction,
      ...(hint === undefined ? {} : { hint }),
      prompt: context === undefined ? instruction : `${context}\n${instruction}`,
    });
  }
  return { items, dropped };
}

export type SFreeTarget = 'error' | 'correct';

/** The S-free items: the D3-prompt cells' items in order, targets alternating
 * so about half are meant to be wrong. */
export function sFreeSelection(items: readonly SGenItem[]): { item: SGenItem; target: SFreeTarget }[] {
  return items.filter((i) => S_FREE_CELLS.includes(i.cell)).map((item, n) => ({ item, target: n % 2 === 0 ? 'error' : 'correct' }));
}

/** The S-free writer's calls, five items each. */
export function sFreeCalls(selection: readonly { item: SGenItem; target: SFreeTarget }[]): { item: SGenItem; target: SFreeTarget }[][] {
  const calls: { item: SGenItem; target: SFreeTarget }[][] = [];
  for (let i = 0; i < selection.length; i += S_FREE_ITEMS_PER_CALL) calls.push(selection.slice(i, i + S_FREE_ITEMS_PER_CALL));
  return calls;
}

/** The writer's answers by item id; an answer that is not a non-empty string
 * for a known id is left out. */
export function sFreeAnswersFrom(call: readonly { item: SGenItem }[], content: unknown): Map<string, string> {
  const raw = (content as { answers?: unknown[] } | null)?.answers;
  const known = new Set(call.map((c) => c.item.id));
  const out = new Map<string, string>();
  if (!Array.isArray(raw)) return out;
  for (const entry of raw) {
    const e = (entry ?? {}) as Record<string, unknown>;
    if (typeof e.itemId === 'string' && known.has(e.itemId) && typeof e.answer === 'string' && e.answer.trim().length > 0 && !out.has(e.itemId)) {
      out.set(e.itemId, e.answer.trim());
    }
  }
  return out;
}

/** An S-free answer as the scoring stage scores it: the truth is the owner's
 * label, filled in at `analyze`; until then the writer's target stands in. */
export function sFreeLabelledAnswer(item: SGenItem, target: SFreeTarget, answer: string): LabelledAnswer {
  return {
    id: `sfree:${item.id}`,
    set: 'S-synth',
    item: { id: item.id, type: item.type, prompt: item.prompt },
    userAnswer: answer,
    truth: target === 'correct',
    kind: `sfree:${target}`,
    correctAnswer: '',
  };
}

export const S_GEN_SHEET_COLUMNS = ['key', 'topic', 'type', 'context', 'instruction', 'hint', 'label', 'note'] as const;
export const S_FREE_SHEET_COLUMNS = ['key', 'type', 'context', 'instruction', 'learner_answer', 'label', 'note'] as const;

/** The blind S-gen sheet: one row per generated item, shuffled, the cell only
 * in the mapping. */
export function buildGenSheet(items: readonly SGenItem[], seed: number): { rows: Record<string, string>[]; mapping: Record<string, { cell: string; topicId: string; itemId: string }> } {
  const random = seededRandom(seed);
  const newKey = keyFactory(random);
  const mapping: Record<string, { cell: string; topicId: string; itemId: string }> = {};
  const rows = items.map((item) => {
    let key = newKey();
    while (key in mapping) key = newKey();
    mapping[key] = { cell: item.cell, topicId: item.topicId, itemId: item.id };
    return { key, topic: item.topicId, type: item.type, context: item.context ?? '', instruction: item.instruction, hint: item.hint ?? '', label: '', note: '' };
  });
  return { rows: shuffle(rows, random), mapping };
}

/** The blind S-free sheet: one row per written answer, shuffled, the cell and
 * the writer's target only in the mapping. */
export function buildFreeSheet(
  answers: readonly { item: SGenItem; target: SFreeTarget; answer: string }[],
  seed: number,
): { rows: Record<string, string>[]; mapping: Record<string, { cell: string; itemId: string; target: SFreeTarget }> } {
  const random = seededRandom(seed);
  const newKey = keyFactory(random);
  const mapping: Record<string, { cell: string; itemId: string; target: SFreeTarget }> = {};
  const rows = answers.map(({ item, target, answer }) => {
    let key = newKey();
    while (key in mapping) key = newKey();
    mapping[key] = { cell: item.cell, itemId: item.id, target };
    return { key, type: item.type, context: item.context ?? '', instruction: item.instruction, learner_answer: answer, label: '', note: '' };
  });
  return { rows: shuffle(rows, random), mapping };
}

// ---------------------------------------------------------------------------
// Measured vs estimated, for the stage report

export interface MeasuredCall {
  customId: string;
  stage: Stage;
  group: string;
  model: EvalModel;
  status: string;
  inputTokens?: number;
  outputTokens?: number;
  costUsd: number;
  durationMs?: number;
  stopReason?: string;
}

/** One call as the run keeps it in `records.json`. */
export interface MeasureRecord extends MeasuredCall {
  httpStatus?: number;
  errorType?: string;
  /** The API's error message, first 300 characters: it describes the
   * request or the account, never the key. */
  errorMessage?: string;
  /** The parsed structured output; absent unless ok. */
  content?: unknown;
}

/** The blind sheet for the Daily Test v2/v3 check: the questions of the
 * twelve generated sets, shuffled, the version and date only in the mapping
 * (report §2.3; optional for the owner, ≈ 40 min). */
export function buildDtSheet(records: readonly MeasureRecord[], seed: number): { csv: string; mapping: Record<string, unknown>; rows: number } {
  const items: { source: string; date: string; questionId: string; question: SharedQuestion }[] = [];
  for (const r of records) {
    if (r.stage !== 'daily_test' || r.status !== 'ok') continue;
    const m = /^dt_v(\d)_(\d{4}-\d{2}-\d{2})$/.exec(r.customId);
    const questions = (r.content as { questions?: unknown[] } | null)?.questions;
    if (!m || !Array.isArray(questions)) continue;
    for (const q of questions) {
      const question = q as SharedQuestion;
      if (typeof question?.id !== 'string' || typeof question.instruction !== 'string') continue;
      items.push({ source: `DT v${m[1]}`, date: m[2] as string, questionId: question.id, question: { ...question, commonWrongAnswers: Array.isArray(question.commonWrongAnswers) ? question.commonWrongAnswers : [] } });
    }
  }
  const random = seededRandom(seed);
  const sheet = buildLabelSheet(items, keyFactory(random), random);
  const columns = ['key', 'topic', 'type', 'context', 'instruction', 'hint', 'correct_answer', 'predicted_wrong_answers', 'explanation', 'label', 'defect_types', 'accept_also', 'note'];
  return { csv: toCsv(columns, sheet.rows), mapping: sheet.mapping, rows: sheet.rows.length };
}

export function renderStageReport(title: string, planned: readonly PlannedCall[], measured: readonly MeasuredCall[]): string {
  const groups = [...new Set(planned.map((p) => `${p.stage}|${p.group}`))];
  const out = [
    `# ${title}`,
    '',
    '| Stage | Group | Calls planned | ok | failed | skipped | Mean in (est → measured) | Mean out (est → measured) | Cost (est → measured) | Mean s |',
    '|---|---|---|---|---|---|---|---|---|---|',
  ];
  let estTotal = 0;
  let measTotal = 0;
  for (const g of groups) {
    const [stage, group] = g.split('|') as [Stage, string];
    const plan = planned.filter((p) => p.stage === stage && p.group === group);
    const got = measured.filter((m) => m.stage === stage && m.group === group);
    const ok = got.filter((m) => m.status === 'ok');
    const failed = got.filter((m) => m.status !== 'ok' && m.status !== 'skipped_budget');
    const skipped = got.filter((m) => m.status === 'skipped_budget');
    const mean = (xs: number[]) => (xs.length === 0 ? 0 : Math.round(xs.reduce((a, b) => a + b, 0) / xs.length));
    const est = plan.reduce((n, p) => n + costOf(p.model, p.estimate, true), 0);
    const meas = got.reduce((n, m) => n + m.costUsd, 0);
    estTotal += est;
    measTotal += meas;
    out.push(
      `| ${stage} | ${group} | ${plan.length} | ${ok.length} | ${failed.length} | ${skipped.length} | ${mean(plan.map((p) => p.estimate.inputTokens))} → ${mean(ok.map((m) => m.inputTokens ?? 0))} | ${mean(plan.map((p) => p.estimate.outputTokens))} → ${mean(ok.map((m) => m.outputTokens ?? 0))} | ${money(est)} → ${money(meas)} | ${(mean(ok.map((m) => m.durationMs ?? 0)) / 1000).toFixed(1)} |`,
    );
  }
  out.push('', `Total: estimated ${money(estTotal)}, measured ${money(measTotal)} (${measTotal >= estTotal ? '+' : ''}${estTotal === 0 ? 0 : Math.round(((measTotal - estTotal) / estTotal) * 100)} %).`);
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Errors

/** The API's error type and message from a non-200 body: the message
 * describes the request or the account (a missing workspace scope, a credit
 * balance, a bad field) and never contains the key. Kept with every failed
 * call since 2026-10-31, when the type alone ("invalid_request_error" on 162
 * calls) hid a workspace-less key for twenty minutes. */
export function readApiError(payload: unknown): { errorType: string; errorMessage: string } {
  const error = (payload as { error?: { type?: unknown; message?: unknown } } | null)?.error;
  const errorType = typeof error?.type === 'string' && error.type.length > 0 ? error.type : 'unknown';
  const errorMessage = typeof error?.message === 'string' ? error.message.slice(0, 300) : '';
  return { errorType, errorMessage };
}
