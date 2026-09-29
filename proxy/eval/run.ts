/**
 * The local measurement E (docs/1.1.0-shared-daily-test-quality.md §13.6).
 * Never deployed and never imported by the Worker. Run from `proxy/`:
 *
 *   npm run eval -- dry-run            requests and estimated cost, no API call
 *   npm run eval -- run [--out DIR]    runs E (or resumes DIR), spending at most $4
 *   npm run eval -- run --out DIR --add-dates [YYYY-MM-DD,…]
 *                                      adds dates to a finished run (default: EXTRA_DATES)
 *   npm run eval -- analyze --out DIR  the report, after the owner has labelled
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
  console.log('Usage: npm run eval -- dry-run | run [--out DIR] | run --out DIR --add-dates [YYYY-MM-DD,…] | analyze --out DIR');
  process.exitCode = 1;
}

main().catch((e: unknown) => {
  // Only the message: never a request or response body.
  console.error(e instanceof Error ? e.message : 'E failed.');
  process.exitCode = 1;
});
