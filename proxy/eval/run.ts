/**
 * The local measurement E (docs/1.1.0-shared-daily-test-quality.md §13.6).
 * Never deployed and never imported by the Worker. Run from `proxy/`:
 *
 *   npm run eval -- dry-run            requests and estimated cost, no API call
 *   npm run eval -- run [--out DIR]    runs E (or resumes DIR), spending at most $4
 *   npm run eval -- run --out DIR --add-dates [YYYY-MM-DD,…]
 *                                      adds dates to a finished run (default: EXTRA_DATES)
 *   npm run eval -- analyze --out DIR  the report, after the owner has labelled
 *   npm run eval -- compare --dry-run  the generator comparison's requests and cost, no API call
 *   npm run eval -- compare [--out DIR]
 *                                      runs the generator comparison (or resumes DIR), at most $1
 *   npm run eval -- sets               writes the 1.4.0 measurement's test sets and label
 *                                      sheets to eval/data/ from the repo's inputs (no API call)
 *   npm run eval -- measure --dry-run  the 1.4.0 measurement's calls and cost per cell, from
 *                                      the built request bodies (no API call)
 *   npm run eval -- measure probe      one minimal Haiku call: the status and the API's message
 *   npm run eval -- measure run [--out DIR]
 *                                      stage 1 of the measurement (generation, the S-free
 *                                      writer, the Daily Test check, the gate), the two owner
 *                                      sheets, the stage report; at most $30 of measured spend;
 *                                      the key from ANTHROPIC_API_KEY in the environment only
 *   npm run eval -- measure dt-sheet --out DIR
 *                                      the optional blind Daily Test sheet from a run's sets
 *   npm run eval -- measure score --out DIR [--dry-run]
 *                                      stage 2: scoring (eight cells) and the repeat (C1, C4, C8),
 *                                      after the owner's S-gen and S-free labels
 *   npm run eval -- measure analyze --out DIR
 *                                      the measurement report into docs/1.4.0-measurement-report.md,
 *                                      and second-look-C8.md in the run folder
 *   npm run eval -- measure dt-more --out DIR
 *                                      six more dates per version for the v2/v3 check (12 calls)
 *                                      and the s-dt-2 sheet
 *
 * The API key is read from the environment (ANTHROPIC_API_KEY) or from
 * `proxy/.dev.vars`, is sent only to api.anthropic.com, and is never printed or
 * written. Everything a run writes goes under `eval/out/` (gitignored):
 * `labels.csv` for the owner at the top, everything that reveals a row's
 * variant under `private/`.
 */
import { randomInt, randomUUID } from 'node:crypto';
import { appendFile, mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { buildBody, type AnthropicRequestBody } from '../src/anthropic';
import { sharedCheckRequest, type QuestionDecision } from '../src/shared_check';
import { dailyPlan, sharedDailyTestRequest, type SharedQuestion } from '../src/shared_daily_test';
import { analyze, benchmarkJsonWork, reviewedSets } from './lib/analysis';
import {
  COMPARE_DATES,
  COMPARE_ESTIMATE,
  COMPARE_SPEND_CAP_USD,
  compareVariant,
  comparisonBody,
  estimatedCostUsd,
  fitsCap,
  planComparison,
  renderComparisonReport,
  renderQuestions,
  summarizeComparison,
  variantLabel,
  worstCaseCostUsd,
  type CompareRecord,
  type CompareRequest,
} from './lib/compare';
import {
  LABEL_COLUMNS,
  buildLabelSheet,
  isSheetFileName,
  newLabelItems,
  parseCsv,
  readLabels,
  seededRandom,
  sheetFileName,
  toCsv,
  type LabelItem,
  type LabelSource,
} from './lib/labels';
import {
  EVAL_DATES,
  EXTRA_DATES,
  SPEND_CAP_USD,
  addDates,
  batchKey,
  TOKEN_ESTIMATES,
  checkerModel,
  costOf,
  estimateCost,
  fitBudget,
  generationVariant,
  planRequests,
  summarizePlan,
  type PlannedRequest,
  type ReferenceId,
  type Usage,
} from './lib/matrix';
import { readGeneratedSet, readReferenceSet, type CallRecord, type ReferenceSets } from './lib/sets';
import {
  buildLiveSheet,
  buildPoolGate,
  buildPoolScoring,
  buildSynth,
  freeSheetTemplate,
  genSheetTemplate,
  renderSynthReview,
  selectLiveSets,
  summarize,
  type LiveSetFile,
  type PoolCorrection,
} from './lib/datasets';
import {
  MEASURE_SPEND_CAP_USD,
  SCORING_CELLS,
  S_FREE_SHEET_COLUMNS,
  S_GEN_SHEET_COLUMNS,
  buildDtSheet,
  buildFreeSheet,
  buildGenSheet,
  charactersPerToken,
  planMeasurement,
  readApiError,
  renderCostTable,
  renderStageReport,
  sFreeAnswersFrom,
  sFreeBody,
  sFreeCalls,
  sFreeLabelledAnswer,
  sFreePlaceholders,
  sFreeSelection,
  sGenItemsFrom,
  S_FREE_OUTPUT_TOKENS,
  totalUsd,
  DT_VERSIONS,
  DT_OUTPUT_TOKENS,
  estimateInputTokens,
  type GenerationCellId,
  type MeasureRecord,
  type MeasurementInputs,
  type PlannedCall,
  type SFreeTarget,
  type SGenItem,
} from './lib/measurement';
import { renderMeasurementReport, renderSecondLook, type AnalysisData } from './lib/analysis_measurement';
import { POOL_DATES, type LabelledAnswer } from './lib/datasets';

const API = 'https://api.anthropic.com/v1';
const API_HOST = 'api.anthropic.com';
const API_VERSION = '2023-06-01';
const SYNC_TIMEOUT_MS = 600_000;
const POLL_INTERVAL_MS = 60_000;

const ROOT = process.cwd();
const REFERENCE_FILES: Readonly<Record<ReferenceId, string>> = {
  R1: 'eval/input/set-2026-09-26.json',
  R2: 'eval/input/set-2026-09-27.json',
  R3: 'eval/reference/day0.json',
};

// ---------------------------------------------------------------------------
// Files

interface RunState {
  seed: number;
  /** Batch ids by [batchKey]. */
  batches: Record<string, string>;
  estimates: Record<string, Usage>;
  /** The run's dates: [EVAL_DATES], then any added. Absent in a run started
   * before dates could be added. */
  dates?: string[];
  /** 0, then one more for each `--add-dates`. */
  round?: number;
}

class Run {
  constructor(readonly dir: string) {}
  get privateDir() {
    return path.join(this.dir, 'private');
  }
  file(name: string) {
    return path.join(this.privateDir, name);
  }
  async init() {
    await mkdir(this.privateDir, { recursive: true });
  }
  async log(line: string) {
    const stamped = `${new Date().toISOString()} ${line}`;
    console.log(stamped);
    await appendFile(path.join(this.dir, 'progress.log'), `${stamped}\n`);
  }
  async readJson<T>(name: string, fallback: T): Promise<T> {
    try {
      return JSON.parse(await readFile(this.file(name), 'utf8')) as T;
    } catch {
      return fallback;
    }
  }
  async writeJson(name: string, value: unknown) {
    await writeFile(this.file(name), `${JSON.stringify(value, null, 2)}\n`);
  }
}

async function exists(file: string): Promise<boolean> {
  try {
    await readFile(file);
    return true;
  } catch {
    return false;
  }
}

async function loadReferences(): Promise<{ sets: ReferenceSets; missing: ReferenceId[] }> {
  const sets: ReferenceSets = {};
  const missing: ReferenceId[] = [];
  for (const [id, file] of Object.entries(REFERENCE_FILES) as [ReferenceId, string][]) {
    try {
      sets[id] = readReferenceSet(JSON.parse(await readFile(path.join(ROOT, file), 'utf8')));
    } catch {
      missing.push(id);
    }
  }
  return { sets, missing };
}

async function apiKey(): Promise<string> {
  const fromEnv = process.env.ANTHROPIC_API_KEY?.trim();
  if (fromEnv) return fromEnv;
  try {
    const vars = await readFile(path.join(ROOT, '.dev.vars'), 'utf8');
    const line = vars.split(/\r?\n/).find((l) => l.trim().startsWith('ANTHROPIC_API_KEY='));
    const value = line?.slice(line.indexOf('=') + 1).trim().replace(/^["']|["']$/g, '');
    if (value) return value;
  } catch {
    // no .dev.vars
  }
  throw new Error('No API key: set ANTHROPIC_API_KEY or put ANTHROPIC_API_KEY=… in proxy/.dev.vars.');
}

// ---------------------------------------------------------------------------
// Requests

function generationBody(request: PlannedRequest): AnthropicRequestBody {
  const v = generationVariant(request.variant as NonNullable<PlannedRequest['variant']>);
  const shared = sharedDailyTestRequest(dailyPlan(request.date as string), [], {
    promptVersion: v.promptVersion,
    model: v.model,
    candidatesPerSlot: v.candidatesPerSlot,
  });
  return buildBody({ op: 'generate_shared_daily_test', request: shared });
}

function checkBody(request: PlannedRequest, questions: readonly SharedQuestion[]): AnthropicRequestBody {
  const model = checkerModel(request.checker as NonNullable<PlannedRequest['checker']>);
  return buildBody({ op: 'check_shared_daily_test', request: sharedCheckRequest(questions, model) });
}

function headers(key: string): Record<string, string> {
  return { 'x-api-key': key, 'anthropic-version': API_VERSION, 'content-type': 'application/json' };
}

/** Reads a Messages API response into the record's measured fields. */
function readMessage(request: PlannedRequest, message: unknown): Pick<CallRecord, 'status' | 'inputTokens' | 'outputTokens' | 'stopReason' | 'costUsd' | 'content'> {
  const m = message as { usage?: { input_tokens?: number; output_tokens?: number }; stop_reason?: string; content?: { type: string; text?: string }[] };
  const usage = { inputTokens: m.usage?.input_tokens ?? 0, outputTokens: m.usage?.output_tokens ?? 0 };
  const base = {
    ...usage,
    stopReason: m.stop_reason ?? null,
    costUsd: costOf(request.model, usage, request.sync),
  };
  const text = m.content?.find((b) => b.type === 'text')?.text;
  try {
    if (text === undefined) throw new Error('no text block');
    return { ...base, status: 'ok', content: JSON.parse(text) };
  } catch {
    return { ...base, status: 'unparseable' };
  }
}

function recordOf(request: PlannedRequest, fields: Partial<CallRecord> & Pick<CallRecord, 'status' | 'costUsd'>): CallRecord {
  return {
    customId: request.customId,
    kind: request.kind,
    stage: request.stage,
    sync: request.sync,
    model: request.model,
    ...(request.variant ? { variant: request.variant } : {}),
    ...(request.checker ? { checker: request.checker } : {}),
    ...(request.date ? { date: request.date } : {}),
    ...(request.reference ? { reference: request.reference } : {}),
    ...(request.repeat ? { repeat: request.repeat } : {}),
    ...fields,
  };
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

/** One synchronous call, retried twice on 429/5xx (not billed). */
async function syncCall(key: string, request: PlannedRequest, body: AnthropicRequestBody): Promise<CallRecord> {
  for (let attempt = 1; ; attempt++) {
    const started = Date.now();
    let response: Response;
    try {
      response = await fetch(`${API}/messages`, {
        method: 'POST',
        headers: headers(key),
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(SYNC_TIMEOUT_MS),
      });
    } catch {
      return recordOf(request, { status: 'network_error', costUsd: 0, durationMs: Date.now() - started });
    }
    if (response.status === 200) {
      const message = await response.json();
      return recordOf(request, { ...readMessage(request, message), durationMs: Date.now() - started });
    }
    let errorType = 'unknown';
    try {
      errorType = ((await response.json()) as { error?: { type?: string } }).error?.type ?? 'unknown';
    } catch {
      // unreadable error body
    }
    if ((response.status === 429 || response.status >= 500) && attempt < 3) {
      await sleep(20_000 * attempt);
      continue;
    }
    return recordOf(request, { status: 'http_error', httpStatus: response.status, errorType, costUsd: 0 });
  }
}

async function submitBatch(key: string, items: { request: PlannedRequest; body: AnthropicRequestBody }[]): Promise<string> {
  const response = await fetch(`${API}/messages/batches`, {
    method: 'POST',
    headers: headers(key),
    body: JSON.stringify({ requests: items.map(({ request, body }) => ({ custom_id: request.customId, params: body })) }),
  });
  if (response.status !== 200) {
    let errorType = 'unknown';
    try {
      errorType = ((await response.json()) as { error?: { type?: string } }).error?.type ?? 'unknown';
    } catch {
      // unreadable error body
    }
    throw new Error(`Batch submission failed: HTTP ${response.status} (${errorType}). Nothing was submitted.`);
  }
  return ((await response.json()) as { id: string }).id;
}

async function waitForBatch(key: string, id: string, run: Run): Promise<string> {
  for (;;) {
    const response = await fetch(`${API}/messages/batches/${id}`, { headers: headers(key) });
    if (response.status === 200) {
      const batch = (await response.json()) as {
        processing_status: string;
        request_counts: Record<string, number>;
        results_url: string | null;
      };
      const counts = Object.entries(batch.request_counts)
        .map(([k, v]) => `${k} ${v}`)
        .join(', ');
      await run.log(`batch ${id}: ${batch.processing_status} (${counts})`);
      if (batch.processing_status === 'ended' && batch.results_url) return batch.results_url;
    } else {
      await run.log(`batch ${id}: status check failed (HTTP ${response.status}); retrying`);
    }
    await sleep(POLL_INTERVAL_MS);
  }
}

async function batchResults(key: string, url: string): Promise<{ custom_id: string; result: Record<string, unknown> }[]> {
  if (new URL(url).host !== API_HOST) throw new Error('Unexpected results host; the API key is only sent to api.anthropic.com.');
  const response = await fetch(url, { headers: headers(key) });
  if (response.status !== 200) throw new Error(`Batch results download failed: HTTP ${response.status}.`);
  return (await response.text())
    .split('\n')
    .filter((l) => l.trim().length > 0)
    .map((l) => JSON.parse(l) as { custom_id: string; result: Record<string, unknown> });
}

/** Submits (or, on a resumed run, finds) one stage's batch, waits for it, and
 * turns its results into records. */
async function runBatch(
  key: string,
  run: Run,
  state: RunState,
  stage: 'B' | 'D',
  items: { request: PlannedRequest; body: AnthropicRequestBody }[],
): Promise<CallRecord[]> {
  if (items.length === 0) return [];
  const slot = batchKey(stage, state.round ?? 0);
  let id = state.batches[slot];
  if (!id) {
    id = await submitBatch(key, items);
    state.batches[slot] = id;
    await run.writeJson('state.json', state);
    await run.log(`stage ${stage}: submitted batch ${id} with ${items.length} requests`);
  } else {
    await run.log(`stage ${stage}: resuming batch ${id}`);
  }
  const results = new Map((await batchResults(key, await waitForBatch(key, id, run))).map((r) => [r.custom_id, r.result]));
  return items.map(({ request }) => {
    const result = results.get(request.customId);
    const type = result?.type;
    if (type === 'succeeded') return recordOf(request, readMessage(request, result?.message));
    if (type === 'expired' || type === 'canceled') return recordOf(request, { status: type, costUsd: 0 });
    const error = (result?.error as { error?: { type?: string } } | undefined)?.error?.type ?? 'unknown';
    return recordOf(request, { status: 'errored', errorType: error, costUsd: 0 });
  });
}

// ---------------------------------------------------------------------------
// Commands

const money = (v: number) => `$${v.toFixed(2)}`;

async function dryRun(): Promise<void> {
  const requests = planRequests();
  const { missing } = await loadReferences();
  const summary = summarizePlan(requests);
  console.log('E dry run: no API call is made.\n');
  console.log('Stage  Sync   Requests  Est. cost  Call');
  for (const row of summary.rows) {
    console.log(
      `${row.stage.padEnd(6)} ${String(row.sync).padEnd(6)} ${String(row.count).padStart(8)}  ${money(row.estimatedUsd).padStart(9)}  ${row.kind}`,
    );
  }
  console.log(`\nRequests: ${summary.totalRequests} (${requests.filter((r) => r.kind === 'generation').length} generations, ${requests.filter((r) => r.kind === 'check').length} checks)`);
  console.log(`Estimated cost: ${money(summary.totalUsd)} (all synchronous it would be ${money(summary.totalIfAllSyncUsd)})`);
  console.log(`Spend cap: ${money(SPEND_CAP_USD)} of measured spend; a stage is trimmed if spend so far + 1.25 × its estimate would pass it.`);
  console.log(`Dates: ${EVAL_DATES.join(', ')}`);
  const planned = new Set(requests.map((r) => r.customId));
  const extra = planRequests(addDates(EVAL_DATES)).filter((r) => !planned.has(r.customId));
  const extraSummary = summarizePlan(extra);
  console.log(
    `Adding ${EXTRA_DATES.join(', ')} later (run --out DIR --add-dates): +${extraSummary.totalRequests} requests (${extra.filter((r) => r.kind === 'generation').length} generations, ${extra.filter((r) => r.kind === 'check').length} checks), +${money(extraSummary.totalUsd)}; the same ${money(SPEND_CAP_USD)} cap covers the whole run folder.`,
  );
  console.log(`Reference sets: ${missing.length === 0 ? 'all present' : `missing ${missing.join(', ')} (${missing.map((m) => REFERENCE_FILES[m]).join(', ')}); their checks would be skipped`}`);
  let keyFound = true;
  try {
    await apiKey();
  } catch {
    keyFound = false;
  }
  console.log(`API key: ${keyFound ? 'found (not shown)' : 'not found'}`);
}

async function runE(outArg: string | undefined, add: string[] | undefined): Promise<void> {
  const key = await apiKey();
  const dir = outArg ? path.resolve(ROOT, outArg) : path.join(ROOT, 'eval/out', `run-${new Date().toISOString().replace(/[:.]/g, '-')}`);
  const run = new Run(dir);
  if (add && !(await exists(run.file('state.json')))) throw new Error('--add-dates needs --out with the folder of a finished run.');
  await run.init();
  const state = await run.readJson<RunState>('state.json', {
    seed: randomInt(2 ** 31),
    batches: {},
    estimates: { ...TOKEN_ESTIMATES },
    dates: [...EVAL_DATES],
    round: 0,
  });
  state.dates ??= [...EVAL_DATES];
  state.round ??= 0;
  if (add) {
    if (!(await exists(path.join(dir, sheetFileName(state.round))))) {
      throw new Error('Finish the run first (it has not written its label sheet yet): run it again with --out and without --add-dates.');
    }
    state.dates = addDates(state.dates, add);
    state.round++;
  }
  await run.writeJson('state.json', state);
  const round = state.round;
  const records = await run.readJson<CallRecord[]>('records.json', []);
  const done = new Set(records.map((r) => r.customId));
  const save = async (added: CallRecord[]) => {
    records.push(...added);
    for (const r of added) done.add(r.customId);
    await run.writeJson('records.json', records);
  };
  const spent = () => records.reduce((s, r) => s + r.costUsd, 0);
  const { sets: references, missing } = await loadReferences();
  await run.writeJson('references.json', references);
  await run.log(`E run in ${dir}; spent so far ${money(spent())}`);

  await run.log(`dates: ${state.dates.join(', ')}${round > 0 ? ` (round ${round + 1})` : ''}`);
  const plan = planRequests(state.dates);
  const broken = new Set<string>(); // a model/prompt combination the API refused synchronously

  // A and C: synchronous
  const syncStage = async (stage: 'A' | 'C', bodyOf: (r: PlannedRequest) => AnthropicRequestBody | null) => {
    for (const request of plan.filter((r) => r.stage === stage && !done.has(r.customId))) {
      const body = bodyOf(request);
      if (body === null) {
        await save([recordOf(request, { status: 'skipped_dependency', errorType: 'missing_input', costUsd: 0 })]);
        continue;
      }
      if (spent() + estimateCost(request, state.estimates) > SPEND_CAP_USD) {
        await save([recordOf(request, { status: 'skipped_budget', costUsd: 0 })]);
        continue;
      }
      await run.log(`${request.customId}: calling`);
      const record = await syncCall(key, request, body);
      if (record.status === 'http_error' && record.httpStatus !== undefined && record.httpStatus < 500 && record.httpStatus !== 429) {
        broken.add(request.estimateKey.split(':').slice(0, 2).join(':'));
      }
      if (record.status === 'ok') {
        const usage = { inputTokens: record.inputTokens ?? 0, outputTokens: record.outputTokens ?? 0 };
        state.estimates[request.estimateKey] = usage;
        if (request.kind === 'check') {
          state.estimates[`check:${request.checker}:10`] = { inputTokens: usage.inputTokens * 2, outputTokens: usage.outputTokens * 2 };
        }
        await run.writeJson('state.json', state);
      }
      await save([record]);
      await run.log(
        `${request.customId}: ${record.status}${record.httpStatus ? ` ${record.httpStatus} ${record.errorType}` : ''}, ${record.inputTokens ?? 0} in / ${record.outputTokens ?? 0} out, ${money(record.costUsd)}, ${((record.durationMs ?? 0) / 1000).toFixed(1)} s; spent ${money(spent())}`,
      );
    }
  };

  const batchStage = async (stage: 'B' | 'D', bodyOf: (r: PlannedRequest) => AnthropicRequestBody | null) => {
    const pending = plan.filter((r) => r.stage === stage && !done.has(r.customId));
    const skipped: CallRecord[] = [];
    const candidates: PlannedRequest[] = [];
    for (const request of pending) {
      if (broken.has(request.estimateKey.split(':').slice(0, 2).join(':'))) {
        skipped.push(recordOf(request, { status: 'skipped_dependency', errorType: 'refused_synchronously', costUsd: 0 }));
      } else if (bodyOf(request) === null) {
        skipped.push(recordOf(request, { status: 'skipped_dependency', errorType: 'no_valid_input', costUsd: 0 }));
      } else {
        candidates.push(request);
      }
    }
    const fit = state.batches[batchKey(stage, round)] ? { kept: candidates, dropped: [] } : fitBudget(candidates, spent(), SPEND_CAP_USD, state.estimates);
    skipped.push(...fit.dropped.map((r) => recordOf(r, { status: 'skipped_budget', costUsd: 0 })));
    await save(skipped);
    if (fit.dropped.length > 0) await run.log(`stage ${stage}: ${fit.dropped.length} requests left out for the budget`);
    const results = await runBatch(key, run, state, stage, fit.kept.map((request) => ({ request, body: bodyOf(request) as AnthropicRequestBody })));
    await save(results);
    const ok = results.filter((r) => r.status === 'ok').length;
    await run.log(`stage ${stage}: ${ok} of ${results.length} succeeded; spent ${money(spent())}`);
  };

  if (spent() >= SPEND_CAP_USD) await run.log('spend cap reached; nothing more is submitted');
  await syncStage('A', generationBody);
  await batchStage('B', generationBody);

  const generated = new Map(
    records.filter((r) => r.kind === 'generation').map((r) => [`${r.variant}|${r.date}`, readGeneratedSet(r)]),
  );
  await run.log(`generations passing the gate: ${[...generated.values()].filter((g) => g.valid).length} of ${generated.size}`);
  const checkInput = (request: PlannedRequest): AnthropicRequestBody | null => {
    if (request.reference) {
      const questions = references[request.reference];
      return questions ? checkBody(request, questions) : null;
    }
    const set = generated.get(`${request.variant}|${request.date}`);
    return set?.valid ? checkBody(request, set.candidates.flat()) : null;
  };
  await syncStage('C', checkInput);
  await batchStage('D', checkInput);

  // The owner's sheet: this round's new rows only; a written sheet is never
  // rewritten.
  const mapping = await run.readJson<Record<string, LabelSource>>('mapping.json', {});
  const sheetFile = path.join(dir, sheetFileName(round));
  const items = newLabelItems(labelItems(records, references), mapping);
  if (await exists(sheetFile)) {
    await run.log(`done: ${sheetFile} already written, left as it is; spent ${money(spent())}`);
  } else {
    const newKey = () => {
      let k = randomUUID().replaceAll('-', '').slice(0, 8);
      while (k in mapping) k = randomUUID().replaceAll('-', '').slice(0, 8);
      return k;
    };
    const sheet = buildLabelSheet(items, newKey, seededRandom(state.seed + round));
    await writeFile(sheetFile, toCsv(LABEL_COLUMNS, sheet.rows));
    await run.writeJson('mapping.json', { ...mapping, ...sheet.mapping });
    await run.log(`done: ${sheet.rows.length} rows in ${sheetFile}; spent ${money(spent())}`);
  }
  if (missing.length > 0) await run.log(`reference sets missing: ${missing.join(', ')}`);
}

/** The questions the owner labels: every question of a valid G1–G3 set, the
 * question K1 would publish for each slot of a G4/G5 set, and every reference
 * question. */
function labelItems(records: readonly CallRecord[], references: ReferenceSets): LabelItem[] {
  const items: LabelItem[] = [];
  for (const r of records.filter((x) => x.kind === 'generation')) {
    const set = readGeneratedSet(r);
    if (!set.valid || generationVariant(r.variant as NonNullable<CallRecord['variant']>).candidatesPerSlot !== 1) continue;
    for (const [q] of set.candidates) {
      if (q) items.push({ source: r.variant as string, date: r.date as string, questionId: q.id, question: q });
    }
  }
  for (const s of reviewedSets(records, references)) {
    if (s.checker !== 'K1' || s.repeat !== undefined || !s.decisions || s.candidates.every((slot) => slot.length === 1)) continue;
    for (const slot of s.candidates) {
      const chosen = chooseInSlot(slot, s.decisions);
      if (chosen) items.push({ source: s.source, date: s.date as string, questionId: chosen.id, question: chosen });
    }
  }
  for (const [id, questions] of Object.entries(references)) {
    for (const q of questions ?? []) items.push({ source: id, questionId: q.id, question: q });
  }
  return items;
}

/** The candidate `selectCandidates` would choose for one slot, or null. */
function chooseInSlot(slot: readonly SharedQuestion[], decisions: Map<string, QuestionDecision>): SharedQuestion | null {
  let best: { q: SharedQuestion; n: number } | null = null;
  for (const q of slot) {
    const d = decisions.get(q.id);
    if (d?.pass && (best === null || d.acceptedAnswers.length < best.n)) best = { q, n: d.acceptedAnswers.length };
  }
  return best?.q ?? null;
}

async function analyzeRun(outArg: string | undefined): Promise<void> {
  if (!outArg) throw new Error('analyze needs --out DIR (the run folder).');
  const run = new Run(path.resolve(ROOT, outArg));
  const records = await run.readJson<CallRecord[]>('records.json', []);
  const references = await run.readJson<ReferenceSets>('references.json', {});
  const mapping = await run.readJson<Record<string, LabelSource>>('mapping.json', {});
  const sheets = (await readdir(run.dir)).filter(isSheetFileName).sort();
  let labels;
  if (sheets.length > 0) {
    const rows = [];
    for (const sheet of sheets) rows.push(...parseCsv(await readFile(path.join(run.dir, sheet), 'utf8')));
    const read = readLabels(rows);
    if (read.invalid.length > 0) console.log(`Rows with a label or defect type outside the allowed values: ${read.invalid.join(', ')}`);
    if (read.unlabelled.length > 0) console.log(`Rows not labelled yet: ${read.unlabelled.length}`);
    labels = read.labels;
  }
  const cpu = benchmarkJsonWork(records, references, () => performance.now());
  const report = analyze({ records, references, ...(labels ? { labels, mapping } : {}), cpu });
  await writeFile(path.join(run.dir, 'report.md'), report);
  console.log(`Report written to ${path.join(run.dir, 'report.md')}`);
}

// ---------------------------------------------------------------------------
// The generator comparison (docs/1.1.0-shared-daily-test-quality.md §16)

async function compareDryRun(): Promise<void> {
  const plan = planComparison();
  console.log('Generator comparison dry run: no API call is made.\n');
  console.log('Variant                                         Calls  max_tokens  Est. cost  Worst case');
  for (const id of ['V1', 'V2', 'V3'] as const) {
    const own = plan.filter((r) => r.variant === id);
    const est = own.reduce((s, r) => s + estimatedCostUsd(r), 0);
    const worst = own.reduce((s, r) => s + worstCaseCostUsd(r), 0);
    console.log(
      `${variantLabel(compareVariant(id)).padEnd(46)} ${String(own.length).padStart(6)}  ${String(comparisonBody(own[0] as CompareRequest).max_tokens).padStart(10)}  ${money(est).padStart(9)}  ${money(worst).padStart(10)}`,
    );
  }
  const est = plan.reduce((s, r) => s + estimatedCostUsd(r), 0);
  const worst = plan.reduce((s, r) => s + worstCaseCostUsd(r), 0);
  console.log(`\nCalls: ${plan.length}, synchronous, one after another, date by date (${COMPARE_DATES.join(', ')})`);
  console.log(
    `Estimated cost: ${money(est)} (${COMPARE_ESTIMATE.inputTokens} in / ${COMPARE_ESTIMATE.outputTokens} out per set, E's G3 mean, list price)`,
  );
  console.log(
    `Spend cap: ${money(COMPARE_SPEND_CAP_USD)}. A call is made only if spend so far + its worst case (every max_tokens token billed) stays within it; all ${plan.length} at worst case would be ${money(worst)}, so at worst the last ones are left out.`,
  );
  console.log('Typical time: 1 min per call, about 10 min in total (each call may run to its token budget; nothing is cut off at 150 s, so the time over the limit is measured).');
  let keyFound = true;
  try {
    await apiKey();
  } catch {
    keyFound = false;
  }
  console.log(`API key: ${keyFound ? 'found (not shown)' : 'not found'}`);
}

/** One synchronous call, retried twice on 429/5xx (not billed). */
async function compareCall(key: string, request: CompareRequest): Promise<CompareRecord> {
  const v = compareVariant(request.variant);
  const base = { customId: request.customId, variant: request.variant, date: request.date, model: v.model, ...(v.effort ? { effort: v.effort } : {}) };
  const body = comparisonBody(request);
  for (let attempt = 1; ; attempt++) {
    const started = Date.now();
    let response: Response;
    try {
      response = await fetch(`${API}/messages`, {
        method: 'POST',
        headers: headers(key),
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(SYNC_TIMEOUT_MS),
      });
    } catch {
      return { ...base, status: 'network_error', costUsd: 0, durationMs: Date.now() - started };
    }
    if (response.status === 200) {
      const m = (await response.json()) as {
        usage?: { input_tokens?: number; output_tokens?: number };
        stop_reason?: string;
        content?: { type: string; text?: string }[];
      };
      const durationMs = Date.now() - started;
      const usage = { inputTokens: m.usage?.input_tokens ?? 0, outputTokens: m.usage?.output_tokens ?? 0 };
      const measured = { ...base, ...usage, stopReason: m.stop_reason ?? null, durationMs, costUsd: costOf(v.model, usage, true) };
      const text = m.content?.find((b) => b.type === 'text')?.text;
      try {
        if (text === undefined) throw new Error('no text block');
        return { ...measured, status: 'ok', content: JSON.parse(text) };
      } catch {
        return { ...measured, status: 'unparseable' };
      }
    }
    let errorType = 'unknown';
    try {
      errorType = ((await response.json()) as { error?: { type?: string } }).error?.type ?? 'unknown';
    } catch {
      // unreadable error body
    }
    if ((response.status === 429 || response.status >= 500) && attempt < 3) {
      await sleep(20_000 * attempt);
      continue;
    }
    return { ...base, status: 'http_error', httpStatus: response.status, errorType, costUsd: 0, durationMs: Date.now() - started };
  }
}

async function runComparison(outArg: string | undefined): Promise<void> {
  const key = await apiKey();
  const dir = outArg ? path.resolve(ROOT, outArg) : path.join(ROOT, 'eval/out', `compare-${new Date().toISOString().replace(/[:.]/g, '-')}`);
  await mkdir(dir, { recursive: true });
  const log = async (line: string) => {
    const stamped = `${new Date().toISOString()} ${line}`;
    console.log(stamped);
    await appendFile(path.join(dir, 'progress.log'), `${stamped}\n`);
  };
  const recordsFile = path.join(dir, 'records.json');
  let records: CompareRecord[] = [];
  try {
    records = JSON.parse(await readFile(recordsFile, 'utf8')) as CompareRecord[];
  } catch {
    // a new run
  }
  // A call left out for the cap is tried again on a resumed run.
  records = records.filter((r) => r.status !== 'skipped_budget');
  const done = new Set(records.map((r) => r.customId));
  const spent = () => records.reduce((s, r) => s + r.costUsd, 0);
  await log(`generator comparison in ${dir}; spent so far ${money(spent())}`);

  for (const request of planComparison().filter((r) => !done.has(r.customId))) {
    if (!fitsCap(spent(), request)) {
      const v = compareVariant(request.variant);
      records.push({ customId: request.customId, variant: request.variant, date: request.date, model: v.model, ...(v.effort ? { effort: v.effort } : {}), status: 'skipped_budget', costUsd: 0 });
      await log(`${request.customId}: left out, its worst case ${money(worstCaseCostUsd(request))} would pass the ${money(COMPARE_SPEND_CAP_USD)} cap`);
      continue;
    }
    await log(`${request.customId}: calling`);
    const record = await compareCall(key, request);
    records.push(record);
    await writeFile(recordsFile, `${JSON.stringify(records, null, 2)}\n`);
    await log(
      `${request.customId}: ${record.status}${record.httpStatus ? ` ${record.httpStatus} ${record.errorType}` : ''}, ${record.inputTokens ?? 0} in / ${record.outputTokens ?? 0} out, stop ${record.stopReason ?? '–'}, ${money(record.costUsd)}, ${((record.durationMs ?? 0) / 1000).toFixed(1)} s; spent ${money(spent())}`,
    );
  }
  await writeFile(recordsFile, `${JSON.stringify(records, null, 2)}\n`);
  await writeFile(path.join(dir, 'report.md'), renderComparisonReport(summarizeComparison(records), { dates: COMPARE_DATES, generatedAt: new Date().toISOString() }));
  await writeFile(path.join(dir, 'questions.md'), renderQuestions(records));
  await log(`done: ${path.join(dir, 'report.md')} and questions.md; spent ${money(spent())}`);
}

/**
 * The 1.4.0 server package's test sets and label sheets
 * (docs/1.4.0-server-batch0-report.md §3.1, `eval/lib/datasets.ts`), from
 * inputs that are in the repo: the fallback pool and its corrections, and the
 * live sets exported read-only from KV into `eval/data/live-sets/`. No API
 * call. The S-live sheet is deterministic (a fixed seed), so running this
 * again never changes a sheet the owner has started; a sheet that already
 * exists is left alone.
 */
async function buildSets(): Promise<void> {
  const data = path.join(ROOT, 'eval/data');
  const repo = path.join(ROOT, '..');
  const pool = JSON.parse(await readFile(path.join(repo, 'assets/daily_test_fallback/pool.json'), 'utf8')) as {
    sets: { questions: SharedQuestion[] }[];
  };
  const corrections = (JSON.parse(await readFile(path.join(repo, 'tool/fallback_pool/corrections.json'), 'utf8')) as { corrections: PoolCorrection[] })
    .corrections;
  const liveDir = path.join(data, 'live-sets');
  const liveFiles = (await readdir(liveDir)).filter((f) => /^set-\d{4}-\d{2}-\d{2}\.json$/.test(f)).sort();
  const liveSets: LiveSetFile[] = [];
  for (const f of liveFiles) liveSets.push(JSON.parse(await readFile(path.join(liveDir, f), 'utf8')) as LiveSetFile);

  const poolScoring = buildPoolScoring(pool);
  const gate = buildPoolGate(liveSets, corrections);
  const synth = buildSynth(pool);
  const live = buildLiveSheet(selectLiveSets(liveSets));

  await mkdir(path.join(data, 's-live'), { recursive: true });
  await mkdir(path.join(data, 'templates'), { recursive: true });
  await writeFile(path.join(data, 's-pool.scoring.json'), `${JSON.stringify(poolScoring, null, 2)}\n`);
  await writeFile(path.join(data, 's-pool.gate.json'), `${JSON.stringify(gate, null, 2)}\n`);
  await writeFile(path.join(data, 's-synth.json'), `${JSON.stringify(synth, null, 2)}\n`);
  await writeFile(path.join(data, 's-synth-review.md'), renderSynthReview(synth));
  const sheet = path.join(data, 's-live/labels.csv');
  if (await exists(sheet)) {
    console.log('s-live/labels.csv exists; not rewritten (the owner may have started it).');
  } else {
    await writeFile(sheet, live.csv);
    await writeFile(path.join(data, 's-live/mapping.json'), `${JSON.stringify(live.mapping, null, 2)}\n`);
  }
  await writeFile(
    path.join(data, 's-live/questions.json'),
    `${JSON.stringify(selectLiveSets(liveSets).map((s) => ({ date: s.date, questions: s.questions })), null, 2)}\n`,
  );
  await writeFile(path.join(data, 'templates/s-gen-labels.csv'), genSheetTemplate());
  await writeFile(path.join(data, 'templates/s-free-labels.csv'), freeSheetTemplate());
  console.log(summarize(poolScoring, gate, live.rows, synth));
  console.log(`Written under ${path.relative(ROOT, data)}/.`);
}

/** The step-D cost table (docs/1.4.0-server-batch0-report.md §3.4, §6):
 * every call the measurement would make, built with the proxy's own request
 * builders, with its estimated tokens and cost. No API call. */
async function measureDryRun(): Promise<void> {
  const data = path.join(ROOT, 'eval/data');
  const pool = JSON.parse(await readFile(path.join(data, 's-pool.scoring.json'), 'utf8')) as LabelledAnswer[];
  const synth = JSON.parse(await readFile(path.join(data, 's-synth.json'), 'utf8')) as LabelledAnswer[];
  const liveDir = path.join(data, 'live-sets');
  const gateSets: LiveSetFile[] = [];
  for (const f of (await readdir(liveDir)).filter((n) => /^set-\d{4}-\d{2}-\d{2}\.json$/.test(n)).sort()) {
    gateSets.push(JSON.parse(await readFile(path.join(liveDir, f), 'utf8')) as LiveSetFile);
  }
  const inputs: MeasurementInputs = { pool, synth, sFree: sFreePlaceholders(), gateSets, seed: 20261101 };
  const ratio = charactersPerToken();
  const calls = planMeasurement(inputs, ratio);
  console.log(`Answers: S-pool ${pool.length}, S-synth ${synth.length}, S-free ${inputs.sFree.length} (placeholders until written); gate sets ${gateSets.length}.`);
  console.log('');
  console.log(renderCostTable(calls, ratio));
}

// ---------------------------------------------------------------------------
// The 1.4.0 measurement (docs/1.4.0-server-batch0-report.md §3.4a, §6 step E)

/** The key for the measurement: the environment only (owner, 2026-10-31;
 * never a file). It is held in this closure, sent in a header to
 * api.anthropic.com, and never written anywhere. */
function measureKey(): string {
  const key = process.env.ANTHROPIC_API_KEY?.trim();
  if (!key) throw new Error('No API key: export ANTHROPIC_API_KEY in this shell (read -s ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY). The measurement does not read .dev.vars.');
  return key;
}

/** One call: retried twice on 429, 529 and 5xx; of an error body the type
 * and the message are kept (never the key, which is not in it). */
async function measureCall(key: string, body: AnthropicRequestBody): Promise<Omit<MeasureRecord, 'customId' | 'stage' | 'group' | 'model'>> {
  for (let attempt = 1; ; attempt++) {
    const started = Date.now();
    let response: Response;
    try {
      response = await fetch(`${API}/messages`, { method: 'POST', headers: headers(key), body: JSON.stringify(body), signal: AbortSignal.timeout(SYNC_TIMEOUT_MS) });
    } catch {
      if (attempt < 3) {
        await sleep(10_000 * attempt);
        continue;
      }
      return { status: 'network_error', costUsd: 0, durationMs: Date.now() - started };
    }
    const durationMs = Date.now() - started;
    if (response.status === 200) {
      const m = (await response.json()) as { usage?: { input_tokens?: number; output_tokens?: number }; stop_reason?: string; content?: { type: string; text?: string }[] };
      const usage = { inputTokens: m.usage?.input_tokens ?? 0, outputTokens: m.usage?.output_tokens ?? 0 };
      const costUsd = costOf(body.model as Parameters<typeof costOf>[0], usage, true);
      const text = m.content?.find((b) => b.type === 'text')?.text;
      let content: unknown;
      try {
        content = text ? JSON.parse(text) : undefined;
      } catch {
        content = undefined;
      }
      return { status: content === undefined ? 'unparseable' : 'ok', ...usage, stopReason: m.stop_reason, costUsd, durationMs, ...(content === undefined ? {} : { content }) };
    }
    let errorType = 'unknown';
    let errorMessage = '';
    try {
      ({ errorType, errorMessage } = readApiError(await response.json()));
    } catch {
      // unreadable error body
    }
    if ((response.status === 429 || response.status === 529 || response.status >= 500) && attempt < 3) {
      await sleep(20_000 * attempt);
      continue;
    }
    return { status: 'http_error', httpStatus: response.status, errorType, errorMessage, costUsd: 0, durationMs };
  }
}

/** One minimal call (`claude-haiku-5-5`, 16 output tokens, well under a cent)
 * that prints the status, the error type and the API's message: what a 400
 * on every call of a run means. The key from the environment only. */
async function measureProbe(): Promise<void> {
  const key = measureKey();
  const body: AnthropicRequestBody = {
    model: 'claude-haiku-5-5',
    max_tokens: 16,
    system: 'Answer with the single word ok.',
    output_config: { format: { type: 'json_schema', schema: { type: 'object', properties: { answer: { type: 'string' } }, required: ['answer'], additionalProperties: false } } },
    messages: [{ role: 'user', content: 'ok?' }],
  };
  const result = await measureCall(key, body);
  const line = `probe: ${result.status}${result.httpStatus ? ` ${result.httpStatus} ${result.errorType}: ${result.errorMessage ?? ''}` : ''}; ${result.inputTokens ?? 0} in / ${result.outputTokens ?? 0} out; ${money(result.costUsd)}`;
  if (line.includes(key)) throw new Error('refusing to print the API key');
  console.log(line);
}

/** Runs [items] with at most [limit] in flight, in order of start. */
async function pool<T>(items: readonly T[], limit: number, work: (item: T) => Promise<void>): Promise<void> {
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const item = items[next++] as T;
      await work(item);
    }
  });
  await Promise.all(workers);
}

// ---------------------------------------------------------------------------
// The data the measurement reads (eval/data; the owner's sheets)

const DATA_DIR = path.join(ROOT, 'eval/data');

async function readJsonFile<T>(file: string): Promise<T> {
  return JSON.parse(await readFile(file, 'utf8')) as T;
}

async function readSheet(file: string): Promise<Record<string, string>[]> {
  return (await exists(file)) ? parseCsv(await readFile(file, 'utf8')) : [];
}

const cleanCell = (v: string | undefined) => (v ?? '').replace(/^'/, '').trim();

async function loadLiveSets(): Promise<LiveSetFile[]> {
  const liveDir = path.join(DATA_DIR, 'live-sets');
  const sets: LiveSetFile[] = [];
  for (const f of (await readdir(liveDir)).filter((n) => /^set-\d{4}-\d{2}-\d{2}\.json$/.test(n)).sort()) {
    sets.push(await readJsonFile<LiveSetFile>(path.join(liveDir, f)));
  }
  return sets;
}

/** S-synth minus the owner's exclusions (`s-synth-exclusions.txt`, one id per line). */
async function loadSynth(): Promise<{ answers: LabelledAnswer[]; excluded: number }> {
  const all = await readJsonFile<LabelledAnswer[]>(path.join(DATA_DIR, 's-synth.json'));
  const file = path.join(DATA_DIR, 's-synth-exclusions.txt');
  const excluded = new Set((await exists(file)) ? (await readFile(file, 'utf8')).split(/\r?\n/).map((l) => l.trim()).filter((l) => l.length > 0 && !l.startsWith('#')) : []);
  return { answers: all.filter((a) => !excluded.has(a.id)), excluded: excluded.size };
}

interface OwnerSheets {
  sGenLabels: Map<string, string>;
  sGenUnlabelled: number;
  sFreeOwner: Map<string, boolean>;
  sFreeTargets: Map<string, SFreeTarget>;
  sFreeUnlabelled: number;
  sFreeInvalid: number;
  sLiveAccept: Map<string, string[]>;
  sLiveDates: Set<string>;
  sLive: { rows: number; ok: number; minor: number; defect: number; acceptAlso: number };
  dtLabels?: Map<string, string>;
}

/** The owner's sheets joined with their mappings; what is still unlabelled
 * is counted, never guessed. */
async function loadOwnerSheets(): Promise<OwnerSheets> {
  const genRows = await readSheet(path.join(DATA_DIR, 's-gen/labels.csv'));
  const genMap = (await exists(path.join(DATA_DIR, 's-gen/mapping.json'))) ? await readJsonFile<Record<string, { itemId: string }>>(path.join(DATA_DIR, 's-gen/mapping.json')) : {};
  const sGenLabels = new Map<string, string>();
  let sGenUnlabelled = 0;
  for (const row of genRows) {
    const item = genMap[cleanCell(row.key)]?.itemId;
    const label = cleanCell(row.label).toLowerCase();
    if (!item) continue;
    if (label === '') sGenUnlabelled++;
    else sGenLabels.set(item, label);
  }
  const freeRows = await readSheet(path.join(DATA_DIR, 's-free/labels.csv'));
  const freeMap = (await exists(path.join(DATA_DIR, 's-free/mapping.json'))) ? await readJsonFile<Record<string, { itemId: string; target: SFreeTarget }>>(path.join(DATA_DIR, 's-free/mapping.json')) : {};
  const sFreeOwner = new Map<string, boolean>();
  const sFreeTargets = new Map<string, SFreeTarget>();
  let sFreeUnlabelled = 0;
  let sFreeInvalid = 0;
  for (const row of freeRows) {
    const m = freeMap[cleanCell(row.key)];
    if (!m) continue;
    sFreeTargets.set(m.itemId, m.target);
    const label = cleanCell(row.label).toLowerCase();
    if (label === '') sFreeUnlabelled++;
    else if (label === 'correct' || label === 'wrong') sFreeOwner.set(m.itemId, label === 'correct');
    else sFreeInvalid++;
  }
  const liveRows = await readSheet(path.join(DATA_DIR, 's-live/labels.csv'));
  const liveMap = await readJsonFile<Record<string, { date?: string; questionId: string }>>(path.join(DATA_DIR, 's-live/mapping.json'));
  const sLiveAccept = new Map<string, string[]>();
  const sLiveDates = new Set<string>();
  const sLive = { rows: liveRows.length, ok: 0, minor: 0, defect: 0, acceptAlso: 0 };
  for (const row of liveRows) {
    const m = liveMap[cleanCell(row.key)];
    if (!m?.date) continue;
    sLiveDates.add(m.date);
    const label = cleanCell(row.label).toLowerCase();
    if (label === 'ok' || label === 'minor' || label === 'defect') sLive[label]++;
    const accept = cleanCell(row.accept_also).split('|').map((a) => a.trim()).filter((a) => a.length > 0);
    if (accept.length > 0) sLive.acceptAlso++;
    sLiveAccept.set(`${m.date}|${m.questionId}`, accept);
  }
  let dtLabels: Map<string, string> | undefined;
  for (const folder of ['s-dt', 's-dt-2']) {
    const dtRows = await readSheet(path.join(DATA_DIR, `${folder}/labels.csv`));
    if (dtRows.length === 0) continue;
    const dtMap = await readJsonFile<Record<string, { source: string; date?: string; questionId: string }>>(path.join(DATA_DIR, `${folder}/mapping.json`));
    dtLabels ??= new Map();
    for (const row of dtRows) {
      const m = dtMap[cleanCell(row.key)];
      const label = cleanCell(row.label).toLowerCase();
      if (m?.date && label) dtLabels.set(`${m.source.replace('DT ', '')}|${m.date}|${m.questionId}`, label);
    }
  }
  return { sGenLabels, sGenUnlabelled, sFreeOwner, sFreeTargets, sFreeUnlabelled, sFreeInvalid, sLiveAccept, sLiveDates, sLive, ...(dtLabels ? { dtLabels } : {}) };
}

/** The S-free answers with the owner's verdict as the truth; an answer the
 * owner has not labelled is left out of scoring. */
async function loadSFree(sheets: OwnerSheets): Promise<LabelledAnswer[]> {
  const file = path.join(DATA_DIR, 's-free/answers.json');
  if (!(await exists(file))) return [];
  const answers = await readJsonFile<LabelledAnswer[]>(file);
  return answers.filter((a) => sheets.sFreeOwner.has(a.item.id)).map((a) => ({ ...a, truth: sheets.sFreeOwner.get(a.item.id) as boolean }));
}

// ---------------------------------------------------------------------------
// A run folder

class MeasureRun {
  readonly records: MeasureRecord[] = [];
  private readonly done = new Map<string, MeasureRecord>();
  private constructor(
    readonly dir: string,
    private readonly key: string,
  ) {}

  static async open(outDir: string | undefined, key: string): Promise<MeasureRun> {
    const dir = outDir ?? path.join(ROOT, 'eval/out', `measure-${new Date().toISOString().replace(/[:.]/g, '-')}`);
    await mkdir(path.join(dir, 'private'), { recursive: true });
    const run = new MeasureRun(dir, key);
    if (await exists(run.recordsFile)) {
      run.records.push(...(await readJsonFile<MeasureRecord[]>(run.recordsFile)));
      for (const r of run.records) run.done.set(r.customId, r);
    }
    return run;
  }

  get recordsFile() {
    return path.join(this.dir, 'records.json');
  }

  spent(): number {
    return this.records.reduce((n, r) => n + r.costUsd, 0);
  }

  record(customId: string): MeasureRecord | undefined {
    return this.done.get(customId);
  }

  /** Every file a run writes goes through here: nothing that contains the
   * key is ever written (the key never reaches these strings, and this makes
   * sure of it). */
  async writeSafe(file: string, text: string): Promise<void> {
    if (text.includes(this.key)) throw new Error('refusing to write a file that contains the API key');
    await mkdir(path.dirname(file), { recursive: true });
    await writeFile(file, text);
  }

  async log(line: string): Promise<void> {
    if (line.includes(this.key)) throw new Error('refusing to log the API key');
    const stamped = `${new Date().toISOString()} ${line}`;
    console.log(stamped);
    await appendFile(path.join(this.dir, 'progress.log'), `${stamped}\n`);
  }

  private async save(): Promise<void> {
    await this.writeSafe(this.recordsFile, `${JSON.stringify(this.records, null, 2)}\n`);
  }

  private put(record: MeasureRecord): void {
    const idx = this.records.findIndex((r) => r.customId === record.customId);
    if (idx >= 0) this.records[idx] = record;
    else this.records.push(record);
    this.done.set(record.customId, record);
  }

  /** One planned call, unless it is already ok or would pass the cap. */
  async call(c: Pick<PlannedCall, 'customId' | 'stage' | 'group' | 'model' | 'body'>, estimate: Usage): Promise<MeasureRecord> {
    const existing = this.done.get(c.customId);
    if (existing?.status === 'ok') return existing;
    const est = costOf(c.model, estimate, true);
    if (this.spent() + est * 1.25 > MEASURE_SPEND_CAP_USD) {
      const skipped: MeasureRecord = { customId: c.customId, stage: c.stage, group: c.group, model: c.model, status: 'skipped_budget', costUsd: 0 };
      this.put(skipped);
      await this.save();
      await this.log(`${c.customId}: skipped, the cap`);
      return skipped;
    }
    const result = await measureCall(this.key, c.body);
    const record: MeasureRecord = { customId: c.customId, stage: c.stage, group: c.group, model: c.model, ...result };
    this.put(record);
    await this.save();
    await this.log(
      `${c.customId}: ${result.status}${result.httpStatus ? ` ${result.httpStatus} ${result.errorType}: ${result.errorMessage ?? ''}` : ''}, ${result.inputTokens ?? 0} in / ${result.outputTokens ?? 0} out, stop ${result.stopReason ?? '–'}, ${money(result.costUsd)}, ${((result.durationMs ?? 0) / 1000).toFixed(1)} s; spent ${money(this.spent())}`,
    );
    return record;
  }

  async runPlanned(calls: readonly PlannedCall[], label: string): Promise<void> {
    const todo = calls.filter((c) => this.done.get(c.customId)?.status !== 'ok');
    await this.log(`${label}: ${calls.length} calls, ${todo.length} to make`);
    await pool(todo, 5, async (c) => {
      await this.call(c, c.estimate);
    });
  }
}

/** The plan for the data as it is now: S-free from the written answers when
 * they exist (with the owner's truth), placeholders before. */
async function currentPlan(sheets?: OwnerSheets): Promise<{ plan: PlannedCall[]; inputs: MeasurementInputs; ratio: number; synthExcluded: number }> {
  const pool_ = await readJsonFile<LabelledAnswer[]>(path.join(DATA_DIR, 's-pool.scoring.json'));
  const synth = await loadSynth();
  const sFree = sheets ? await loadSFree(sheets) : sFreePlaceholders();
  const inputs: MeasurementInputs = { pool: pool_, synth: synth.answers, sFree, gateSets: await loadLiveSets(), seed: 20261101 };
  const ratio = charactersPerToken();
  return { plan: planMeasurement(inputs, ratio), inputs, ratio, synthExcluded: synth.excluded };
}

// ---------------------------------------------------------------------------
// Stage 1

async function runMeasureStage1(outDir: string | undefined): Promise<void> {
  const run = await MeasureRun.open(outDir, measureKey());
  const { plan } = await currentPlan();
  const stage1 = plan.filter((c) => c.stage === 'generation' || c.stage === 'daily_test' || c.stage === 'gate');
  const sFreeEstimate = plan.find((c) => c.stage === 's_free')?.estimate ?? { inputTokens: 900, outputTokens: S_FREE_OUTPUT_TOKENS };
  await run.log(`stage 1 in ${path.relative(ROOT, run.dir)}; cap ${money(MEASURE_SPEND_CAP_USD)} of measured spend; ${run.records.length} records already there; spent so far ${money(run.spent())}`);

  await run.runPlanned(stage1.filter((c) => c.stage === 'generation'), 'generation');

  const items: SGenItem[] = [];
  let droppedItems = 0;
  for (const c of stage1.filter((x) => x.stage === 'generation')) {
    const r = run.record(c.customId);
    if (!r || r.status !== 'ok') continue;
    const [, cell, topicId] = c.customId.split('_') as [string, GenerationCellId, string];
    const parsed = sGenItemsFrom(cell, topicId, r.content);
    items.push(...parsed.items);
    droppedItems += parsed.dropped;
  }
  await run.log(`S-gen: ${items.length} items from the generations (${droppedItems} entries dropped as malformed)`);
  const selection = sFreeSelection(items);
  const freeCalls = sFreeCalls(selection);
  const written = new Map<string, string>();
  await run.log(`S-free: ${selection.length} items in ${freeCalls.length} writer calls`);
  await pool(
    freeCalls.map((call, i) => ({ call, i })),
    5,
    async ({ call, i }) => {
      const record = await run.call(
        {
          customId: `sfree_${i}`,
          stage: 's_free',
          group: 'S-free',
          model: 'claude-sonnet-5-5',
          body: sFreeBody(call.map(({ item, target }) => ({ id: item.id, type: item.type, prompt: item.prompt, target }))),
        },
        sFreeEstimate,
      );
      if (record.status === 'ok') for (const [id, answer] of sFreeAnswersFrom(call, record.content)) written.set(id, answer);
    },
  );
  const sFreeAnswers = selection.filter((s) => written.has(s.item.id)).map((s) => ({ ...s, answer: written.get(s.item.id) as string }));
  await run.log(`S-free: ${sFreeAnswers.length} answers written`);

  const genSheet = buildGenSheet(items, 20261102);
  await run.writeSafe(path.join(DATA_DIR, 's-gen/labels.csv'), toCsv(S_GEN_SHEET_COLUMNS, genSheet.rows));
  await run.writeSafe(path.join(DATA_DIR, 's-gen/mapping.json'), `${JSON.stringify(genSheet.mapping, null, 2)}\n`);
  await run.writeSafe(path.join(DATA_DIR, 's-gen/items.json'), `${JSON.stringify(items, null, 2)}\n`);
  const freeSheet = buildFreeSheet(sFreeAnswers, 20261103);
  await run.writeSafe(path.join(DATA_DIR, 's-free/labels.csv'), toCsv(S_FREE_SHEET_COLUMNS, freeSheet.rows));
  await run.writeSafe(path.join(DATA_DIR, 's-free/mapping.json'), `${JSON.stringify(freeSheet.mapping, null, 2)}\n`);
  await run.writeSafe(
    path.join(DATA_DIR, 's-free/answers.json'),
    `${JSON.stringify(sFreeAnswers.map((a) => sFreeLabelledAnswer(a.item, a.target, a.answer)), null, 2)}\n`,
  );
  await run.log(`sheets written: eval/data/s-gen/labels.csv (${genSheet.rows.length} rows), eval/data/s-free/labels.csv (${freeSheet.rows.length} rows)`);

  await run.runPlanned(stage1.filter((c) => c.stage === 'daily_test'), 'daily test v2 vs v3');
  await run.runPlanned(stage1.filter((c) => c.stage === 'gate'), 'gate');

  const report = renderStageReport('Measurement stage 1 — measured against the estimate', [...stage1, ...plan.filter((c) => c.stage === 's_free')], run.records);
  await run.writeSafe(path.join(run.dir, 'stage1-report.md'), `${report}\n`);
  console.log(`\n${report}`);
  await run.log(`stage 1 done; spent ${money(run.spent())}; report ${path.relative(ROOT, path.join(run.dir, 'stage1-report.md'))}`);
}

/** The optional Daily Test sheet (report §2.3), from a run's twelve sets. */
async function writeDtSheet(outDir: string | undefined): Promise<void> {
  if (!outDir) throw new Error('measure dt-sheet needs --out DIR (the run folder with the Daily Test records).');
  const records = await readJsonFile<MeasureRecord[]>(path.join(outDir, 'records.json'));
  const sheet = buildDtSheet(records, 20261104);
  const file = path.join(DATA_DIR, 's-dt/labels.csv');
  if (await exists(file)) {
    console.log('s-dt/labels.csv exists; not rewritten (the owner may have started it).');
    return;
  }
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, sheet.csv);
  await writeFile(path.join(DATA_DIR, 's-dt/mapping.json'), `${JSON.stringify(sheet.mapping, null, 2)}\n`);
  console.log(`eval/data/s-dt/labels.csv: ${sheet.rows} rows (the version and date only in mapping.json).`);
}

// ---------------------------------------------------------------------------
// Stage 2: scoring and the repeat

async function runMeasureScoring(outDir: string | undefined, dryRun: boolean): Promise<void> {
  if (!outDir) throw new Error('measure score needs --out DIR (the stage-1 run folder).');
  const sheets = await loadOwnerSheets();
  const missing: string[] = [];
  if (sheets.sFreeTargets.size === 0) missing.push('s-free/labels.csv is missing or empty (stage 1 writes it)');
  if (sheets.sFreeUnlabelled > 0) missing.push(`${sheets.sFreeUnlabelled} S-free rows have no label`);
  if (sheets.sFreeInvalid > 0) missing.push(`${sheets.sFreeInvalid} S-free rows have a label other than correct / wrong`);
  if (sheets.sGenUnlabelled > 0) missing.push(`${sheets.sGenUnlabelled} S-gen rows have no label`);
  if (missing.length > 0 && !dryRun) throw new Error(`The labels come first (owner's order): ${missing.join('; ')}.`);
  const { plan, inputs, synthExcluded } = await currentPlan(sheets);
  const scoring = plan.filter((c) => c.stage === 'scoring');
  const repeat = plan.filter((c) => c.stage === 'scoring_repeat');
  console.log(
    `Scoring: ${inputs.pool.length} S-pool + ${inputs.synth.length} S-synth (${synthExcluded} excluded) + ${inputs.sFree.length} S-free answers = ${inputs.pool.length + inputs.synth.length + inputs.sFree.length}, in ${scoring.length / SCORING_CELLS.length} calls per cell; ${scoring.length} scoring calls (${money(totalUsd(scoring))}) + ${repeat.length} repeat calls (${money(totalUsd(repeat))}).`,
  );
  if (missing.length > 0) console.log(`Not runnable yet: ${missing.join('; ')}.`);
  if (dryRun) return;
  const run = await MeasureRun.open(outDir, measureKey());
  await run.log(`stage 2 in ${path.relative(ROOT, run.dir)}; spent so far ${money(run.spent())}; cap ${money(MEASURE_SPEND_CAP_USD)}`);
  await run.runPlanned(scoring, 'scoring');
  // The repeat in its drop order: C1 first (kept longest), C8 last.
  const order: Record<string, number> = { C1: 0, C4: 1, C8: 2 };
  await run.runPlanned([...repeat].sort((a, b) => (order[a.group] ?? 9) - (order[b.group] ?? 9)), 'scoring repeat (C1, C4, C8)');
  const report = renderStageReport('Measurement stage 2 — measured against the estimate', [...scoring, ...repeat], run.records);
  await run.writeSafe(path.join(run.dir, 'stage2-report.md'), `${report}\n`);
  console.log(`\n${report}`);
  await run.log(`stage 2 done; spent ${money(run.spent())}`);
}

// ---------------------------------------------------------------------------
// Analyze: the measurement report

async function analyzeMeasurement(outDir: string | undefined): Promise<void> {
  if (!outDir) throw new Error('measure analyze needs --out DIR (the run folder).');
  const records = await readJsonFile<MeasureRecord[]>(path.join(outDir, 'records.json'));
  const sheets = await loadOwnerSheets();
  const { inputs, synthExcluded } = await currentPlan(sheets);
  const sGenItems = (await exists(path.join(DATA_DIR, 's-gen/items.json'))) ? await readJsonFile<SGenItem[]>(path.join(DATA_DIR, 's-gen/items.json')) : [];
  const gateTruth = new Map<string, string[]>();
  const gateTruthDates = new Set<string>();
  const poolGate = await readJsonFile<{ date: string; questionId: string; acceptAlso: string[]; movedFromWrong: string[] }[]>(path.join(DATA_DIR, 's-pool.gate.json'));
  for (const d of POOL_DATES) gateTruthDates.add(d);
  for (const g of poolGate) gateTruth.set(`${g.date}|${g.questionId}`, [...g.acceptAlso, ...g.movedFromWrong]);
  for (const d of sheets.sLiveDates) gateTruthDates.add(d);
  for (const [k, v] of sheets.sLiveAccept) gateTruth.set(k, v);
  const data: AnalysisData & { gateJudgments?: AnalysisData['gateJudgments'] } = {
    records,
    answers: [...inputs.pool, ...inputs.synth, ...inputs.sFree],
    sGenItems,
    sGenLabels: sheets.sGenLabels,
    sFreeTargets: sheets.sFreeTargets,
    sFreeOwner: sheets.sFreeOwner,
    gateSets: inputs.gateSets,
    gateTruth,
    gateTruthDates,
    ...(sheets.dtLabels ? { dtLabels: sheets.dtLabels } : {}),
    sLive: sheets.sLive,
    synthExclusions: synthExcluded,
  };
  const judgmentsFile = path.join(DATA_DIR, 'gate-judgments.json');
  if (await exists(judgmentsFile)) {
    const { judgments } = await readJsonFile<{ judgments: { date: string; questionId: string; answer: string; verdict: 'right' | 'wrong' }[] }>(judgmentsFile);
    const map = new Map<string, { right: string[]; wrong: string[] }>();
    for (const j of judgments) {
      const key = `${j.date}|${j.questionId}`;
      const entry = map.get(key) ?? { right: [], wrong: [] };
      entry[j.verdict].push(j.answer);
      map.set(key, entry);
    }
    data.gateJudgments = map;
  }
  const dropped = [...new Set(records.filter((r) => r.status === 'skipped_budget').map((r) => `${r.stage} / ${r.group}`))];
  const report = renderMeasurementReport(data, { runDir: path.relative(path.join(ROOT, '..'), outDir), generatedAt: new Date().toISOString().slice(0, 16).replace('T', ' ') + ' UTC', capUsd: MEASURE_SPEND_CAP_USD, dropped });
  const key = process.env.ANTHROPIC_API_KEY?.trim();
  if (key && report.includes(key)) throw new Error('refusing to write a report that contains the API key');
  const file = path.join(ROOT, '..', 'docs/1.4.0-measurement-report.md');
  await writeFile(file, report);
  console.log(`Written: docs/1.4.0-measurement-report.md (${report.split('\n').length} lines).`);
  // The second look at the scoring candidate (owner, 2026-10-31, decision 1).
  const secondLookFile = path.join(outDir, 'second-look-C8.md');
  if (await exists(secondLookFile)) {
    console.log('second-look-C8.md exists; not rewritten (the owner\'s verdicts live in it; the committed copy is eval/data/second-look-C8.md).');
  } else {
    const secondLook = renderSecondLook(data, 'C8', 'C1');
    if (key && secondLook.includes(key)) throw new Error('refusing to write a file that contains the API key');
    await writeFile(secondLookFile, `${secondLook}\n`);
    console.log(`Written: ${path.relative(ROOT, secondLookFile)}.`);
  }
}

/** Six more dates per version for the v2/v3 check (owner, 2026-10-31,
 * decision 4): 12 calls with the live generator, appended to the run's
 * records, and the blind sheet `s-dt-2`. The key from the environment. */
export const DT_MORE_DATES: readonly string[] = ['2026-11-05', '2026-11-06', '2026-11-07', '2026-11-08', '2026-11-09', '2026-11-10'];

async function runDtMore(outDir: string | undefined): Promise<void> {
  if (!outDir) throw new Error('measure dt-more needs --out DIR (the run folder).');
  const run = await MeasureRun.open(outDir, measureKey());
  const ratio = charactersPerToken();
  const calls: PlannedCall[] = [];
  for (const version of DT_VERSIONS) {
    for (const date of DT_MORE_DATES) {
      const body = buildBody({ op: 'generate_shared_daily_test', request: sharedDailyTestRequest(dailyPlan(date), [], { promptVersion: version }) });
      calls.push({ customId: `dt_v${version}_${date}`, stage: 'daily_test', group: `DT v${version}`, model: 'claude-sonnet-5-5', body, estimate: { inputTokens: estimateInputTokens(body, ratio), outputTokens: DT_OUTPUT_TOKENS }, dropPriority: 1 });
    }
  }
  await run.log(`dt-more: ${calls.length} calls on ${DT_MORE_DATES.join(', ')}; spent so far ${money(run.spent())}`);
  await run.runPlanned(calls, 'daily test v2 vs v3, six more dates');
  const extra = run.records.filter((r) => r.stage === 'daily_test' && DT_MORE_DATES.some((d) => r.customId.endsWith(d)));
  const sheet = buildDtSheet(extra, 20261105);
  const file = path.join(DATA_DIR, 's-dt-2/labels.csv');
  if (await exists(file)) {
    await run.log('s-dt-2/labels.csv exists; not rewritten (the owner may have started it).');
  } else {
    await run.writeSafe(file, sheet.csv);
    await run.writeSafe(path.join(DATA_DIR, 's-dt-2/mapping.json'), `${JSON.stringify(sheet.mapping, null, 2)}\n`);
    await run.log(`eval/data/s-dt-2/labels.csv: ${sheet.rows} rows`);
  }
  await run.log(`dt-more done; spent ${money(run.spent())}`);
}

async function main(): Promise<void> {
  if (!(await exists(path.join(ROOT, 'wrangler.jsonc')))) throw new Error('Run from proxy/ (npm run eval -- …).');
  const [command, ...rest] = process.argv.slice(2);
  const outIndex = rest.indexOf('--out');
  const out = outIndex >= 0 ? rest[outIndex + 1] : undefined;
  const addIndex = rest.indexOf('--add-dates');
  const addValue = addIndex >= 0 ? rest[addIndex + 1] : undefined;
  const add = addIndex < 0 ? undefined : addValue && !addValue.startsWith('--') ? addValue.split(',').map((d) => d.trim()) : [];
  if (command === 'dry-run') return dryRun();
  if (command === 'run') return runE(out, add);
  if (command === 'analyze') return analyzeRun(out);
  if (command === 'compare') return rest.includes('--dry-run') ? compareDryRun() : runComparison(out);
  if (command === 'sets') return buildSets();
  if (command === 'measure' && rest.includes('score')) return runMeasureScoring(out, rest.includes('--dry-run'));
  if (command === 'measure' && rest.includes('--dry-run')) return measureDryRun();
  if (command === 'measure' && rest.includes('probe')) return measureProbe();
  if (command === 'measure' && rest.includes('run')) return runMeasureStage1(out);
  if (command === 'measure' && rest.includes('dt-sheet')) return writeDtSheet(out);
  if (command === 'measure' && rest.includes('analyze')) return analyzeMeasurement(out);
  if (command === 'measure' && rest.includes('dt-more')) return runDtMore(out);
  console.log(
    'Usage: npm run eval -- dry-run | run [--out DIR] | run --out DIR --add-dates [YYYY-MM-DD,…] | analyze --out DIR | compare --dry-run | compare [--out DIR] | sets',
  );
  process.exitCode = 1;
}

main().catch((e: unknown) => {
  // Only the message: never a request or response body.
  console.error(e instanceof Error ? e.message : 'E failed.');
  process.exitCode = 1;
});
