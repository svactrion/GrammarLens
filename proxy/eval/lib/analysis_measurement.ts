import { annotateSet, type AnnotationFindingCode, type CheckerModel } from '../../src/shared_check';
import { dailyPlan, foldKeyboardVariants, normalizeAnswer, validateSharedSet, type SharedQuestion } from '../../src/shared_daily_test';
import { expectedBlankEntries } from '../../src/score_feedback';
import type { LabelledAnswer, LiveSetFile } from './datasets';
import { costOf } from './matrix';
import { SCORING_CELLS, type MeasureRecord, type SFreeTarget, type SGenItem, type ScoringCell, type ScoringCellId } from './measurement';

/**
 * The 1.4.0 measurement's analysis (docs/1.4.0-server-batch0-report.md §3.2):
 * the run's records and the owner's labels in, the measurement report out.
 * Pure: no network, no files. `eval/run.ts measure analyze` reads and writes.
 */

export interface AnalysisData {
  records: readonly MeasureRecord[];
  /** Every scored answer with its truth: S-pool and S-synth by construction,
   * S-free by the owner's label. */
  answers: readonly LabelledAnswer[];
  sGenItems: readonly SGenItem[];
  /** S-gen item id → the owner's label. */
  sGenLabels: ReadonlyMap<string, string>;
  /** S-free item id → the writer's target. */
  sFreeTargets: ReadonlyMap<string, SFreeTarget>;
  /** S-free item id → the owner's verdict (true = correct). */
  sFreeOwner: ReadonlyMap<string, boolean>;
  gateSets: readonly LiveSetFile[];
  /** `${date}|${questionId}` → the answers the owner also accepts (S-pool's
   * corrections, S-live's `accept_also`). Only dates in [gateTruthDates]
   * have truth. */
  gateTruth: ReadonlyMap<string, readonly string[]>;
  gateTruthDates: ReadonlySet<string>;
  /** `v${version}|${date}|${questionId}` → the owner's label on the optional
   * Daily Test sheets (s-dt and s-dt-2). */
  dtLabels?: ReadonlyMap<string, string>;
  /** The owner's judgment of written answers outside the labelled truth
   * (`eval/data/gate-judgments.json`): `${date}|${questionId}` → answers
   * judged right (they join the truth) and wrong (must never be written). */
  gateJudgments?: ReadonlyMap<string, { right: string[]; wrong: string[] }>;
  sLive: { rows: number; ok: number; minor: number; defect: number; acceptAlso: number };
  synthExclusions: number;
}

const money = (n: number) => `$${n.toFixed(2)}`;
const pct = (n: number, d: number) => (d === 0 ? '—' : `${((100 * n) / d).toFixed(1)} %`);
const mean = (xs: readonly number[]) => (xs.length === 0 ? 0 : xs.reduce((a, b) => a + b, 0) / xs.length);

function same(a: string, b: string): boolean {
  const na = normalizeAnswer(a);
  const nb = normalizeAnswer(b);
  return na === nb || foldKeyboardVariants(na) === foldKeyboardVariants(nb);
}

// ---------------------------------------------------------------------------
// Scoring

export interface ScoredItem {
  isCorrect: boolean;
  explanation: string;
  summary?: string;
  blanks?: { index: number; correctAnswer: string; accepted: boolean; note: string }[];
}

/** cell → answer id → what the model said, from the records of [stage]. */
export function scoredByCell(records: readonly MeasureRecord[], stage: 'scoring' | 'scoring_repeat' = 'scoring'): Map<ScoringCellId, Map<string, ScoredItem>> {
  const out = new Map<ScoringCellId, Map<string, ScoredItem>>();
  for (const r of records) {
    if (r.stage !== stage || r.status !== 'ok') continue;
    const cell = r.group as ScoringCellId;
    const feedback = (r.content as { feedback?: unknown[] } | null)?.feedback;
    if (!Array.isArray(feedback)) continue;
    const map = out.get(cell) ?? new Map<string, ScoredItem>();
    for (const f of feedback) {
      const e = f as Record<string, unknown>;
      if (typeof e.itemId !== 'string' || typeof e.isCorrect !== 'boolean') continue;
      map.set(e.itemId, {
        isCorrect: e.isCorrect,
        explanation: typeof e.explanation === 'string' ? e.explanation : '',
        ...(typeof e.summary === 'string' ? { summary: e.summary } : {}),
        ...(Array.isArray(e.blanks) ? { blanks: e.blanks as ScoredItem['blanks'] } : {}),
      });
    }
    out.set(cell, map);
  }
  return out;
}

export interface CellMetrics {
  cell: ScoringCellId;
  scored: number;
  agree: number;
  falseCorrect: number;
  falseNeedsWork: number;
  wrongTotal: number;
  rightTotal: number;
  bySet: Record<string, { scored: number; agree: number }>;
  byType: Record<string, { scored: number; agree: number }>;
  meanIn: number;
  meanOut: number;
  costPerCall: number;
  meanSeconds: number;
  calls: number;
}

export function cellMetrics(data: AnalysisData, stage: 'scoring' | 'scoring_repeat' = 'scoring'): CellMetrics[] {
  const scored = scoredByCell(data.records, stage);
  return SCORING_CELLS.filter((c) => scored.has(c.id)).map((c) => {
    const map = scored.get(c.id) as Map<string, ScoredItem>;
    const m: CellMetrics = { cell: c.id, scored: 0, agree: 0, falseCorrect: 0, falseNeedsWork: 0, wrongTotal: 0, rightTotal: 0, bySet: {}, byType: {}, meanIn: 0, meanOut: 0, costPerCall: 0, meanSeconds: 0, calls: 0 };
    for (const a of data.answers) {
      const s = map.get(a.id);
      if (!s) continue;
      m.scored++;
      if (a.truth) m.rightTotal++;
      else m.wrongTotal++;
      const agree = s.isCorrect === a.truth;
      if (agree) m.agree++;
      else if (s.isCorrect) m.falseCorrect++;
      else m.falseNeedsWork++;
      const set = a.kind.startsWith('sfree') ? 'S-free' : a.set;
      const bs = (m.bySet[set] ??= { scored: 0, agree: 0 });
      bs.scored++;
      if (agree) bs.agree++;
      const bt = (m.byType[a.item.type] ??= { scored: 0, agree: 0 });
      bt.scored++;
      if (agree) bt.agree++;
    }
    const calls = data.records.filter((r) => r.stage === stage && r.group === c.id && r.status === 'ok');
    m.calls = calls.length;
    m.meanIn = Math.round(mean(calls.map((r) => r.inputTokens ?? 0)));
    m.meanOut = Math.round(mean(calls.map((r) => r.outputTokens ?? 0)));
    m.costPerCall = mean(calls.map((r) => r.costUsd));
    m.meanSeconds = mean(calls.map((r) => (r.durationMs ?? 0) / 1000));
    return m;
  });
}

export function renderScoring(data: AnalysisData): string {
  const rows = cellMetrics(data);
  const cellOf = (id: ScoringCellId) => SCORING_CELLS.find((c) => c.id === id) as ScoringCell;
  const out = [
    '| Cell | Model | Effort | Prompt + schema | Answers | Agreement | False "correct" (of wrong) | False "needs work" (of right) | S-pool | S-synth | S-free | Mean in / out | Cost per call | Mean s |',
    '|---|---|---|---|---|---|---|---|---|---|---|---|---|---|',
  ];
  for (const m of rows) {
    const c = cellOf(m.cell);
    const set = (name: string) => (m.bySet[name] ? pct(m.bySet[name].agree, m.bySet[name].scored) : '—');
    out.push(
      `| ${m.cell} | ${c.model} | ${c.effort ?? '—'} | ${c.prompt === 'live' ? 'live' : 'D3 + D11'} | ${m.scored} | ${pct(m.agree, m.scored)} | ${m.falseCorrect} (${pct(m.falseCorrect, m.wrongTotal)}) | ${m.falseNeedsWork} (${pct(m.falseNeedsWork, m.rightTotal)}) | ${set('S-pool')} | ${set('S-synth')} | ${set('S-free')} | ${m.meanIn} / ${m.meanOut} | $${m.costPerCall.toFixed(4)} | ${m.meanSeconds.toFixed(1)} |`,
    );
  }
  out.push('', '**By item type (agreement):**', '', '| Cell | fill_in_blank | error_correction | sentence_writing |', '|---|---|---|---|');
  for (const m of rows) {
    const t = (name: string) => (m.byType[name] ? `${pct(m.byType[name].agree, m.byType[name].scored)} (${m.byType[name].scored})` : '—');
    out.push(`| ${m.cell} | ${t('fill_in_blank')} | ${t('error_correction')} | ${t('sentence_writing')} |`);
  }
  const repeat = cellMetrics(data, 'scoring_repeat');
  if (repeat.length > 0) {
    out.push('', '**Repeat (the same calls a second time):** agreement of a cell with itself across the two runs, and with the labels.', '', '| Cell | Answers in both runs | Same verdict | Agreement run 1 | Agreement run 2 |', '|---|---|---|---|---|');
    const first = scoredByCell(data.records, 'scoring');
    const second = scoredByCell(data.records, 'scoring_repeat');
    for (const m of repeat) {
      const a = first.get(m.cell) ?? new Map();
      const b = second.get(m.cell) ?? new Map();
      let both = 0;
      let sameVerdict = 0;
      for (const [id, s] of a) {
        const t = b.get(id);
        if (!t) continue;
        both++;
        if (t.isCorrect === s.isCorrect) sameVerdict++;
      }
      const r1 = rows.find((x) => x.cell === m.cell);
      out.push(`| ${m.cell} | ${both} | ${pct(sameVerdict, both)} | ${r1 ? pct(r1.agree, r1.scored) : '—'} | ${pct(m.agree, m.scored)} |`);
    }
  }
  return out.join('\n');
}

export function renderDisagreement(data: AnalysisData): string {
  const scored = scoredByCell(data.records);
  const base = scored.get('C1');
  if (!base) return 'C1 was not scored; no disagreement line.';
  const truth = new Map(data.answers.map((a) => [a.id, a.truth]));
  const out = ['| Cell vs C1 | Answers in both | Differ | C1 right, cell wrong | Cell right, C1 wrong | Both wrong |', '|---|---|---|---|---|---|'];
  for (const c of SCORING_CELLS) {
    if (c.id === 'C1') continue;
    const other = scored.get(c.id);
    if (!other) continue;
    let both = 0;
    let differ = 0;
    let c1Right = 0;
    let cellRight = 0;
    let bothWrong = 0;
    for (const [id, s] of base) {
      const t = other.get(id);
      const tr = truth.get(id);
      if (!t || tr === undefined) continue;
      both++;
      if (s.isCorrect !== t.isCorrect) {
        differ++;
        if (s.isCorrect === tr) c1Right++;
        else cellRight++;
      } else if (s.isCorrect !== tr) {
        bothWrong++;
      }
    }
    out.push(`| ${c.id} | ${both} | ${differ} (${pct(differ, both)}) | ${c1Right} | ${cellRight} | ${bothWrong} |`);
  }
  return out.join('\n');
}

export function renderRater(data: AnalysisData): string {
  let changed = 0;
  let n = 0;
  for (const [id, target] of data.sFreeTargets) {
    const owner = data.sFreeOwner.get(id);
    if (owner === undefined) continue;
    n++;
    if ((target === 'correct') !== owner) changed++;
  }
  const genLabels = [...data.sGenLabels.values()];
  const counts = genLabels.reduce<Record<string, number>>((acc, l) => ((acc[l] = (acc[l] ?? 0) + 1), acc), {});
  return [
    `- **S-live** (100 questions): the sheet holds the final labels only (${data.sLive.ok} ok, ${data.sLive.minor} minor, ${data.sLive.defect} defect, accept_also on ${data.sLive.acceptAlso} rows); the owner's changes to the pre-labels were not recorded as such, so no rate is given.`,
    `- **S-synth** (166 answers by construction): ${data.synthExclusions} exclusions by the owner.`,
    `- **S-free** (${n} answers labelled): the owner's verdict differs from the writer's intended target on **${changed}** (${pct(changed, n)}); the owner's verdict is the truth used above.`,
    `- **S-gen** (${genLabels.length} items labelled): ${Object.entries(counts).map(([k, v]) => `${v} ${k}`).join(', ')}; no pre-label existed.`,
  ].join('\n');
}

// ---------------------------------------------------------------------------
// Keyboard and D11

export function renderKeyboard(data: AnalysisData): string {
  const scored = scoredByCell(data.records);
  const classes = [...new Set(data.answers.filter((a) => a.kind.startsWith('kb:')).map((a) => a.kind.slice(3)))].sort();
  const out = ['| Class | ' + SCORING_CELLS.map((c) => c.id).join(' | ') + ' |', '|---|' + SCORING_CELLS.map(() => '---').join('|') + '|'];
  for (const cls of classes) {
    const answers = data.answers.filter((a) => a.kind === `kb:${cls}`);
    const cells = SCORING_CELLS.map((c) => {
      const map = scored.get(c.id);
      if (!map) return '—';
      const got = answers.filter((a) => map.has(a.id));
      const correct = got.filter((a) => map.get(a.id)?.isCorrect).length;
      const named = got.filter((a) => /keyboard|character|typed|accent|full-width|spelling of the same/i.test(map.get(a.id)?.explanation ?? '')).length;
      return `${pct(correct, got.length)} (${named} name it)`;
    });
    out.push(`| ${cls} (${answers.length}) | ${cells.join(' | ')} |`);
  }
  const near = data.answers.filter((a) => a.kind.startsWith('nearmiss'));
  out.push(
    `| near-miss, must be wrong (${near.length}) | ${SCORING_CELLS.map((c) => {
      const map = scored.get(c.id);
      if (!map) return '—';
      const got = near.filter((a) => map.has(a.id));
      return `${pct(got.filter((a) => !map.get(a.id)?.isCorrect).length, got.length)} wrong`;
    }).join(' | ')} |`,
  );
  return out.join('\n');
}

function sentences(text: string): number {
  return text.trim().length === 0 ? 0 : text.trim().split(/[.!?]+(?:\s+|$)/).filter((s) => s.trim().length > 0).length;
}

export function renderD11(data: AnalysisData): string {
  const scored = scoredByCell(data.records);
  const out = ['| Cell | Items | `blanks` present | Length right | `isCorrect` = every accepted | Per-blank agreement (multi-blank truths) | Mean note words | Summary > 2 sentences | Mean explanation words |', '|---|---|---|---|---|---|---|---|---|'];
  const byId = new Map(data.answers.map((a) => [a.id, a]));
  for (const c of SCORING_CELLS) {
    const map = scored.get(c.id);
    if (!map) continue;
    let items = 0;
    let present = 0;
    let lengthRight = 0;
    let consistent = 0;
    let blankPairs = 0;
    let blankAgree = 0;
    const noteWords: number[] = [];
    let summaries = 0;
    let longSummaries = 0;
    const explWords: number[] = [];
    for (const [id, s] of map) {
      const a = byId.get(id);
      if (!a) continue;
      items++;
      explWords.push(s.explanation.split(/\s+/).filter(Boolean).length);
      if (s.summary !== undefined) {
        summaries++;
        if (sentences(s.summary) > 2) longSummaries++;
      }
      if (!s.blanks) continue;
      present++;
      const expected = expectedBlankEntries(a.item.type, a.item.prompt);
      const ok = s.blanks.length === expected && s.blanks.every((b, i) => b.index === i);
      if (ok) lengthRight++;
      if (s.blanks.every((b) => b.accepted) === s.isCorrect) consistent++;
      if (a.blanks && ok && a.blanks.length === s.blanks.length) {
        for (let i = 0; i < a.blanks.length; i++) {
          blankPairs++;
          if ((a.blanks[i] as { accepted: boolean }).accepted === (s.blanks[i] as { accepted: boolean }).accepted) blankAgree++;
        }
      }
      for (const b of s.blanks) noteWords.push(b.note.split(/\s+/).filter(Boolean).length);
    }
    out.push(
      `| ${c.id} | ${items} | ${c.prompt === 'live' ? 'n/a' : pct(present, items)} | ${c.prompt === 'live' ? 'n/a' : pct(lengthRight, present)} | ${c.prompt === 'live' ? 'n/a' : pct(consistent, present)} | ${blankPairs === 0 ? '—' : `${pct(blankAgree, blankPairs)} (${blankPairs})`} | ${noteWords.length === 0 ? '—' : mean(noteWords).toFixed(1)} | ${summaries === 0 ? '—' : `${longSummaries} of ${summaries}`} | ${mean(explWords).toFixed(1)} |`,
    );
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Generation

export function renderGeneration(data: AnalysisData): string {
  const cells = [...new Set(data.sGenItems.map((i) => i.cell))].sort();
  const out = ['| Cell | Items | ok | ambiguous | blank_count_wrong | unnatural | other | unlabelled | Proxy checks failed | Mean prompt chars | Mean in / out | Cost per set | Mean s |', '|---|---|---|---|---|---|---|---|---|---|---|---|---|'];
  for (const cell of cells) {
    const items = data.sGenItems.filter((i) => i.cell === cell);
    const label = (l: string) => items.filter((i) => data.sGenLabels.get(i.id) === l).length;
    const unlabelled = items.filter((i) => !data.sGenLabels.has(i.id)).length;
    const failed = items.filter((i) => {
      const text = `${i.context ?? ''}\n${i.instruction}`;
      const blanks = text.match(/_{2,}/g)?.length ?? 0;
      if (i.type === 'fill_in_blank') return blanks < 1 || blanks > 4;
      if (i.type === 'error_correction') return !i.context || i.context.trim().split(/\s+/).filter((w) => /\p{L}/u.test(w)).length < 3;
      return false;
    }).length;
    const calls = data.records.filter((r) => r.stage === 'generation' && r.group === cell && r.status === 'ok');
    out.push(
      `| ${cell} | ${items.length} | ${label('ok')} | ${label('ambiguous')} | ${label('blank_count_wrong')} | ${label('unnatural')} | ${label('other')} | ${unlabelled} | ${failed} | ${Math.round(mean(items.map((i) => i.prompt.length)))} | ${Math.round(mean(calls.map((r) => r.inputTokens ?? 0)))} / ${Math.round(mean(calls.map((r) => r.outputTokens ?? 0)))} | $${mean(calls.map((r) => r.costUsd)).toFixed(4)} | ${mean(calls.map((r) => (r.durationMs ?? 0) / 1000)).toFixed(1)} |`,
    );
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Daily Test v2 vs v3

const LANGUAGE_NAMES = /\b(Turkish|Turkey|Japanese|Japan|Korean|Korea|Spanish|Spain|Mexic\w*|Portuguese|Brazil\w*|Arabic|German\w*|Germany)\b/;

export function renderDailyTest(data: AnalysisData): string {
  const out = [
    '| Version | Sets | Pass the gate | Rejection codes | Mean in / out | `max_tokens` stops | A language named | Owner labels, gate-passing sets (ok / minor / defect) | Owner labels, all sets |',
    '|---|---|---|---|---|---|---|---|---|',
  ];
  for (const version of [2, 3]) {
    const recs = data.records.filter((r) => r.stage === 'daily_test' && r.group === `DT v${version}` && r.status === 'ok');
    let pass = 0;
    const reasons: Record<string, number> = {};
    let named = 0;
    const passing = { ok: 0, minor: 0, defect: 0 };
    const all = { ok: 0, minor: 0, defect: 0 };
    for (const r of recs) {
      const date = r.customId.split('_')[2] as string;
      const v = validateSharedSet(r.content, dailyPlan(date));
      if (v.ok) pass++;
      else reasons[v.reason] = (reasons[v.reason] ?? 0) + 1;
      if (LANGUAGE_NAMES.test(JSON.stringify(r.content))) named++;
      const questions = (r.content as { questions?: SharedQuestion[] } | null)?.questions ?? [];
      for (const q of questions) {
        const l = data.dtLabels?.get(`v${version}|${date}|${q.id}`);
        if (l === 'ok' || l === 'minor' || l === 'defect') {
          all[l]++;
          if (v.ok) passing[l]++;
        }
      }
    }
    const fmt = (c: { ok: number; minor: number; defect: number }) => `${c.ok} / ${c.minor} / ${c.defect}`;
    out.push(
      `| v${version} | ${recs.length} | ${pass} of ${recs.length} | ${Object.entries(reasons).map(([k, v]) => `${k} ×${v}`).join(', ') || '—'} | ${Math.round(mean(recs.map((r) => r.inputTokens ?? 0)))} / ${Math.round(mean(recs.map((r) => r.outputTokens ?? 0)))} | ${recs.filter((r) => r.stopReason === 'max_tokens').length} | ${named} | ${data.dtLabels ? fmt(passing) : 'not labelled'} | ${data.dtLabels ? fmt(all) : 'not labelled'} |`,
    );
  }
  out.push('', 'The sheets hold every generated question, from the rejected sets too (the gate\'s reasons above), so the "all sets" column includes items no learner would have seen; the "gate-passing" column is the one that compares the versions as published.');
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// The P14 gate

export interface GateResult {
  gate: 'agreement' | 'single_review';
  setsReviewed: number;
  setsWithTruth: number;
  written: number;
  writtenInTruth: number;
  writtenOutsideTruth: { date: string; questionId: string; answer: string; key: string; judgment: 'right' | 'wrong' | '' }[];
  /** Written answers the owner judged wrong: the go/no-go count. */
  writtenWrong: number;
  truthTotal: number;
  truthFound: number;
  moved: number;
  findings: Record<string, number>;
  costPerSet: number;
}

function judgmentOf(data: AnalysisData, date: string, questionId: string, answer: string): 'right' | 'wrong' | '' {
  const j = data.gateJudgments?.get(`${date}|${questionId}`);
  if (!j) return '';
  if (j.wrong.some((w) => same(w, answer))) return 'wrong';
  if (j.right.some((r) => same(r, answer))) return 'right';
  return '';
}

export function gateResults(data: AnalysisData): GateResult[] {
  const byKey = new Map<string, unknown>();
  const costByModel = new Map<string, number[]>();
  for (const r of data.records) {
    if (r.stage !== 'gate' || r.status !== 'ok') continue;
    const m = /^gate_(.+)_(\d{4}-\d{2}-\d{2})_r(\d)$/.exec(r.customId);
    if (!m) continue;
    byKey.set(`${m[1]}|${m[2]}|${m[3]}`, r.content);
    costByModel.set(m[1] as string, [...(costByModel.get(m[1] as string) ?? []), r.costUsd]);
  }
  const gates: { gate: 'agreement' | 'single_review'; models: CheckerModel[] }[] = [
    { gate: 'agreement', models: ['claude-opus-5-5', 'claude-sonnet-5-5'] },
    { gate: 'single_review', models: ['claude-opus-5-5'] },
  ];
  return gates.map(({ gate, models }) => {
    const res: GateResult = { gate, setsReviewed: 0, setsWithTruth: 0, written: 0, writtenInTruth: 0, writtenOutsideTruth: [], writtenWrong: 0, truthTotal: 0, truthFound: 0, moved: 0, findings: {}, costPerSet: 0 };
    for (const set of data.gateSets) {
      const outputs = models.map((model) => ({ model, output: byKey.get(`${model}|${set.date}|1`) }));
      if (outputs.some((o) => o.output === undefined)) continue;
      const questions = set.questions as SharedQuestion[];
      const result = annotateSet(questions, outputs);
      if (result.outcome !== 'annotated') continue;
      res.setsReviewed++;
      res.moved += result.moved;
      for (const f of result.findings) res.findings[f.code] = (res.findings[f.code] ?? 0) + 1;
      const hasTruth = data.gateTruthDates.has(set.date);
      if (hasTruth) res.setsWithTruth++;
      result.questions.forEach((q, i) => {
        const before = questions[i] as SharedQuestion;
        const added = (q.acceptedAnswers ?? []).filter((a) => !(before.acceptedAnswers ?? []).some((b) => same(a, b)));
        // The owner's judged-right answers join the truth; judged-wrong ones
        // are the go/no-go count.
        const judged = data.gateJudgments?.get(`${set.date}|${q.id}`);
        const truth = [...(data.gateTruth.get(`${set.date}|${q.id}`) ?? []), ...(judged?.right ?? [])];
        const counts = hasTruth || judged !== undefined;
        if (counts) {
          res.truthTotal += truth.length;
          res.truthFound += truth.filter((t) => added.some((a) => same(a, t))).length;
        }
        for (const a of added) {
          res.written++;
          const judgment = judgmentOf(data, set.date, q.id, a);
          if (judgment === 'wrong') res.writtenWrong++;
          if (counts && truth.some((t) => same(a, t))) res.writtenInTruth++;
          else res.writtenOutsideTruth.push({ date: set.date, questionId: q.id, answer: a, key: q.correctAnswer, judgment });
        }
      });
    }
    res.costPerSet = models.reduce((n, m) => n + mean(costByModel.get(m) ?? [0]), 0);
    return res;
  });
}

export function renderGate(data: AnalysisData): string {
  const results = gateResults(data);
  const out = ['| Gate | Sets reviewed | With truth | Written | In the truth (precision) | Truth found (recall) | Outside the truth | Judged wrong (go/no-go) | Moved | Cost per set |', '|---|---|---|---|---|---|---|---|---|---|'];
  for (const r of results) {
    const inTruthWritten = r.written - r.writtenOutsideTruth.filter((w) => data.gateTruthDates.has(w.date) || data.gateJudgments?.has(`${w.date}|${w.questionId}`)).length;
    out.push(`| ${r.gate} | ${r.setsReviewed} | ${r.setsWithTruth} | ${r.written} | ${r.writtenInTruth} of ${inTruthWritten} (${pct(r.writtenInTruth, inTruthWritten)}) | ${r.truthFound} of ${r.truthTotal} (${pct(r.truthFound, r.truthTotal)}) | ${r.writtenOutsideTruth.length} | **${r.writtenWrong}** | ${r.moved} | ${money(r.costPerSet)} |`);
  }
  if (data.gateJudgments) {
    out.push('', `The owner's judgments (\`eval/data/gate-judgments.json\`, 2026-10-31) are applied: answers judged right count as truth; answers judged wrong are the go/no-go column. The decision rules of 2026-10-31 (\`alternative_unshifted\`, \`alternative_defeats_rule\`, \`alternative_changes_other_words\`) run offline here on the stored checker outputs, so the table shows what the production step would write today.`);
  }
  out.push('', '**Findings per code** (what the step would not write):', '', '| Code | agreement | single_review |', '|---|---|---|');
  const codes = [...new Set(results.flatMap((r) => Object.keys(r.findings)))].sort() as AnnotationFindingCode[];
  for (const code of codes) out.push(`| ${code} | ${results[0]?.findings[code] ?? 0} | ${results[1]?.findings[code] ?? 0} |`);
  // Checker agreement and stability.
  const byKey = new Map<string, unknown>();
  for (const r of data.records) {
    if (r.stage !== 'gate' || r.status !== 'ok') continue;
    const m = /^gate_(.+)_(\d{4}-\d{2}-\d{2})_r(\d)$/.exec(r.customId);
    if (m) byKey.set(`${m[1]}|${m[2]}|${m[3]}`, r.content);
  }
  const proposals = (model: string, date: string, repeat: number, questions: SharedQuestion[]): Map<string, string[]> => {
    const content = byKey.get(`${model}|${date}|${repeat}`) as { questions?: { id: string; acceptableAlternatives?: string[]; acceptableWrongAnswers?: string[] }[] } | undefined;
    const map = new Map<string, string[]>();
    for (const q of questions) {
      const rev = content?.questions?.find((x) => x.id === q.id);
      map.set(q.id, [...(rev?.acceptableAlternatives ?? []), ...(rev?.acceptableWrongAnswers ?? [])]);
    }
    return map;
  };
  let opusProps = 0;
  let agreedProps = 0;
  const stability: Record<string, { same: number; total: number }> = { 'claude-opus-5-5': { same: 0, total: 0 }, 'claude-sonnet-5-5': { same: 0, total: 0 } };
  for (const set of data.gateSets) {
    const questions = set.questions as SharedQuestion[];
    const o1 = proposals('claude-opus-5-5', set.date, 1, questions);
    const s1 = proposals('claude-sonnet-5-5', set.date, 1, questions);
    for (const q of questions) {
      for (const a of o1.get(q.id) ?? []) {
        opusProps++;
        if ((s1.get(q.id) ?? []).some((b) => same(a, b))) agreedProps++;
      }
    }
    for (const model of Object.keys(stability)) {
      const r1 = proposals(model, set.date, 1, questions);
      const r2 = proposals(model, set.date, 2, questions);
      for (const q of questions) {
        const a = r1.get(q.id) ?? [];
        const b = r2.get(q.id) ?? [];
        stability[model]!.total++;
        const sameSet = a.length === b.length && a.every((x) => b.some((y) => same(x, y)));
        if (sameSet) stability[model]!.same++;
      }
    }
  }
  out.push('', `**Checker agreement:** of ${opusProps} answers Opus 5.5 proposed (alternatives and acceptable wrong answers, run 1), Sonnet 5.5 also proposed ${agreedProps} (${pct(agreedProps, opusProps)}).`);
  out.push(`**Stability across the two repeats** (a question's proposal set identical in run 1 and run 2): Opus 5.5 ${pct(stability['claude-opus-5-5']!.same, stability['claude-opus-5-5']!.total)}, Sonnet 5.5 ${pct(stability['claude-sonnet-5-5']!.same, stability['claude-sonnet-5-5']!.total)} of ${stability['claude-opus-5-5']!.total} questions.`);
  const outside = results.flatMap((r) => r.writtenOutsideTruth.map((w) => ({ gate: r.gate, ...w })));
  if (outside.length > 0) {
    out.push('', '**Written answers outside the labelled truth** (the go/no-go: none judged wrong may be written):', '', '| Gate | Date | Question | Key | Written answer | Owner: right or wrong? |', '|---|---|---|---|---|---|');
    for (const w of outside) out.push(`| ${w.gate} | ${w.date} | ${w.questionId} | ${w.key} | ${w.answer} | ${w.judgment === 'wrong' ? '**wrong**' : w.judgment} |`);
  }
  // What the three rules of 2026-10-31 filtered, answer by answer, so the
  // owner can see that only the six judged wrong are gone.
  const ruleCodes = ['alternative_unshifted', 'alternative_defeats_rule', 'alternative_changes_other_words'] as const;
  const byKey2 = new Map<string, unknown>();
  for (const r of data.records) {
    if (r.stage !== 'gate' || r.status !== 'ok') continue;
    const m = /^gate_(.+)_(\d{4}-\d{2}-\d{2})_r(\d)$/.exec(r.customId);
    if (m && m[3] === '1') byKey2.set(`${m[1]}|${m[2]}`, r.content);
  }
  const ruleHits: string[] = [];
  const seenHits = new Set<string>();
  for (const set of data.gateSets) {
    const output = byKey2.get(`claude-opus-5-5|${set.date}`);
    if (output === undefined) continue;
    const result = annotateSet(set.questions as SharedQuestion[], [{ model: 'claude-opus-5-5', output }]);
    if (result.outcome !== 'annotated') continue;
    for (const f of result.findings) {
      if ((ruleCodes as readonly string[]).includes(f.code)) {
        for (const ans of f.answers ?? []) {
          // The same answer can be filtered as an alternative and as a move.
          const hit = `| ${f.code} | ${set.date} | ${f.questionId} | ${ans} | ${judgmentOf(data, set.date, f.questionId, ans) || '—'} |`;
          if (!seenHits.has(hit)) {
            seenHits.add(hit);
            ruleHits.push(hit);
          }
        }
      }
    }
  }
  if (ruleHits.length > 0) {
    out.push('', '**Filtered by the three rules of 2026-10-31** (single review, run 1; the owner\'s judgment where one exists):', '', '| Rule | Date | Question | Answer | Judgment |', '|---|---|---|---|---|', ...ruleHits);
  }
  const filtered = data.gateJudgments
    ? [...data.gateJudgments.entries()].flatMap(([k, j]) => j.wrong.map((answer) => ({ k, answer }))).filter(({ k, answer }) => !outside.some((w) => `${w.date}|${w.questionId}` === k && same(w.answer, answer)))
    : [];
  if (filtered.length > 0) {
    out.push('', `**Judged wrong and now filtered by the decision rules** (not written by either gate): ${filtered.map(({ k, answer }) => `${k.split('|')[1]}: "${answer}"`).join('; ')}.`);
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// The second look at a candidate cell (owner, 2026-10-31: C8 against C1)

export function renderSecondLook(data: AnalysisData, candidate: ScoringCellId, baseline: ScoringCellId): string {
  const scored = scoredByCell(data.records);
  const cand = scored.get(candidate) ?? new Map<string, ScoredItem>();
  const base = scored.get(baseline) ?? new Map<string, ScoredItem>();
  const block = (a: LabelledAnswer, c: ScoredItem | undefined, b: ScoredItem | undefined) =>
    [
      `### ${a.id} (${a.item.type}, ${a.kind})`,
      '',
      `> ${a.item.prompt.replaceAll('\n', '\n> ')}`,
      '',
      `- **Learner's answer:** ${JSON.stringify(a.userAnswer)}`,
      `- **Key:** ${JSON.stringify(a.correctAnswer)}${a.blanks ? ` — per blank: ${a.blanks.map((x) => `${x.index + 1}: ${x.noArticle ? '—' : JSON.stringify(x.user)} ${x.accepted ? '✓' : '✗'}`).join(', ')}` : ''}`,
      `- **Truth:** ${a.truth ? 'correct' : 'wrong'}`,
      `- **${candidate}:** ${c ? (c.isCorrect ? 'correct' : 'needs work') : 'not scored'} — ${c?.explanation ?? ''}${c?.summary ? ` *Summary:* ${c.summary}` : ''}${c?.blanks ? ` *Blanks:* ${c.blanks.map((x) => `${x.index + 1}: ${x.correctAnswer} ${x.accepted ? '✓' : '✗'} (${x.note})`).join(' | ')}` : ''}`,
      `- **${baseline}:** ${b ? (b.isCorrect ? 'correct' : 'needs work') : 'not scored'} — ${b?.explanation ?? ''}`,
      '- **Owner:** ',
      '',
    ].join('\n');
  const falseNeedsWork = data.answers.filter((a) => a.truth && cand.get(a.id)?.isCorrect === false);
  const differ = data.answers.filter((a) => cand.has(a.id) && base.has(a.id) && cand.get(a.id)?.isCorrect !== base.get(a.id)?.isCorrect);
  return [
    `# Second look: ${candidate} against the truth and against ${baseline}`,
    '',
    'No API call: the stored verdicts and explanations of the measurement run. The owner writes right / wrong after "Owner:".',
    '',
    `## A. ${candidate} said "needs work" where the truth says correct (${falseNeedsWork.length})`,
    '',
    ...falseNeedsWork.map((a) => block(a, cand.get(a.id), base.get(a.id))),
    `## B. ${candidate} and ${baseline} differ (${differ.length})`,
    '',
    ...differ.map((a) => block(a, cand.get(a.id), base.get(a.id))),
  ].join('\n');
}

// ---------------------------------------------------------------------------
// The cost model (owner, 2026-10-31, decision 5)

/** The planning scenarios. The user types follow the quota rules (a free
 * user: the shared Daily Test and one 3-question practice a day; Premium:
 * up to 5 sessions a day, 5 questions each); the mix of the 1,000-user
 * scenario is an assumption to be replaced by the owner's figures. */
export const COST_SCENARIOS = {
  freeItemsPerDay: 3,
  premiumLightSessionsPerDay: 1,
  premiumHeavySessionsPerDay: 5,
  itemsPerSession: 5,
  thousand: { users: 1000, freeShare: 0.9, lightShare: 0.08, heavyShare: 0.02 },
  daysPerMonth: 30,
  /** The shared Daily Test, one set a day for every user (report §1.6). */
  dailyTestPerDayUsd: 0.019 + 0.047,
} as const;

export interface CostInputs {
  generationPerSetUsd: number;
  scoringPerCallUsd: Record<string, number>;
}

/** Measured per-call costs of the chosen cells: G-D (Sonnet 5.5 low, D3) for
 * generation; C8 (Haiku) and C4 (Sonnet 5.5 low) for scoring, both D3 + D11. */
export function costInputs(data: AnalysisData): CostInputs {
  const per = (stage: string, group: string) => {
    const recs = data.records.filter((r) => r.stage === stage && r.group === group && r.status === 'ok');
    return mean(recs.map((r) => r.costUsd));
  };
  return { generationPerSetUsd: per('generation', 'G-D'), scoringPerCallUsd: { 'claude-haiku-5-5': per('scoring', 'C8'), 'claude-sonnet-5-5': per('scoring', 'C4') } };
}

export function renderCostModel(data: AnalysisData): string {
  const c = costInputs(data);
  const S = COST_SCENARIOS;
  const perItem = (model: string) => (c.generationPerSetUsd + (c.scoringPerCallUsd[model] ?? 0)) / S.itemsPerSession;
  const session = (model: string, items: number) => perItem(model) * items;
  const monthly = (model: string) => ({
    free: session(model, S.freeItemsPerDay) * S.daysPerMonth,
    light: session(model, S.itemsPerSession) * S.premiumLightSessionsPerDay * S.daysPerMonth,
    heavy: session(model, S.itemsPerSession) * S.premiumHeavySessionsPerDay * S.daysPerMonth,
  });
  const out = [
    `Measured per call (this run, list prices): generation ${money4(c.generationPerSetUsd)} per 5-item set (G-D, Sonnet 5.5 low, D3); scoring ${money4(c.scoringPerCallUsd['claude-haiku-5-5'] ?? 0)} per 5-answer call with Haiku 5.5 (C8) and ${money4(c.scoringPerCallUsd['claude-sonnet-5-5'] ?? 0)} with Sonnet 5.5 (C4), both D3 + D11. A 5-question practice session therefore costs ≈ ${money4(session('claude-haiku-5-5', 5))} with Haiku scoring and ≈ ${money4(session('claude-sonnet-5-5', 5))} with Sonnet 5.5 scoring; costs are scaled by question count below (a fixed prompt share makes short sessions slightly dearer per question than this).`,
    '',
    `| Scenario (per user per month, ${S.daysPerMonth} days) | Haiku scoring | Sonnet 5.5 scoring |`,
    '|---|---|---|',
    `| Free: the shared Daily Test and one ${S.freeItemsPerDay}-question practice a day | ${money(monthly('claude-haiku-5-5').free)} | ${money(monthly('claude-sonnet-5-5').free)} |`,
    `| Premium light: ${S.premiumLightSessionsPerDay} session of ${S.itemsPerSession} a day | ${money(monthly('claude-haiku-5-5').light)} | ${money(monthly('claude-sonnet-5-5').light)} |`,
    `| Premium heavy: ${S.premiumHeavySessionsPerDay} sessions of ${S.itemsPerSession} a day (the cap) | ${money(monthly('claude-haiku-5-5').heavy)} | ${money(monthly('claude-sonnet-5-5').heavy)} |`,
  ];
  const t = S.thousand;
  const thousand = (model: string) => {
    const m = monthly(model);
    return t.users * (t.freeShare * m.free + t.lightShare * m.light + t.heavyShare * m.heavy) + S.dailyTestPerDayUsd * S.daysPerMonth;
  };
  out.push(
    `| **${t.users} users** (${Math.round(t.freeShare * 100)} % free, ${Math.round(t.lightShare * 100)} % light, ${Math.round(t.heavyShare * 100)} % heavy; an assumed mix) plus the shared Daily Test with its check (${money(S.dailyTestPerDayUsd)} a day) | ${money(thousand('claude-haiku-5-5'))} | ${money(thousand('claude-sonnet-5-5'))} |`,
    '',
    'The Daily Test costs the same at any user count (one set a day, P14\'s single-review check included). The practice figures assume every user uses the full quota every day, so they are ceilings.',
  );
  return out.join('\n');
}

const money4 = (n: number) => `$${n.toFixed(4)}`;

// ---------------------------------------------------------------------------
// Spend and the whole report

export function renderSpend(data: AnalysisData): string {
  const stages = [...new Set(data.records.map((r) => r.stage))];
  const out = ['| Stage | Calls | ok | Measured spend |', '|---|---|---|---|'];
  for (const s of stages) {
    const recs = data.records.filter((r) => r.stage === s);
    out.push(`| ${s} | ${recs.length} | ${recs.filter((r) => r.status === 'ok').length} | ${money(recs.reduce((n, r) => n + r.costUsd, 0))} |`);
  }
  out.push(`| **Total** | ${data.records.length} | ${data.records.filter((r) => r.status === 'ok').length} | **${money(data.records.reduce((n, r) => n + r.costUsd, 0))}** |`);
  return out.join('\n');
}

export interface ReportMeta {
  runDir: string;
  generatedAt: string;
  capUsd: number;
  dropped: string[];
}

export function renderMeasurementReport(data: AnalysisData, meta: ReportMeta): string {
  const spent = data.records.reduce((n, r) => n + r.costUsd, 0);
  return `# 1.4.0 server package — measurement report

**Status: ${data.records.some((r) => r.stage === 'scoring') ? 'measured' : 'stage 1 measured; scoring not run yet'}.** Written by \`npm run eval -- measure analyze\` on ${meta.generatedAt} from \`${meta.runDir}\` (step E of [\`1.4.0-server-batch0-report.md\`](1.4.0-server-batch0-report.md) §6). Nothing is deployed by this report; §6 lists the owner's decisions.

## 0. How to read this report

**Limitation, stated up front.** The labels this report scores against were **written by Claude in the owner's Cowork session and reviewed by the owner**, who confirmed every \`defect\` and every \`accept_also\` on S-live and labelled S-gen and S-free after the generation calls; S-synth's verdicts are by construction, reviewed with ${data.synthExclusions} exclusions. The labels and the measured models therefore share a model family. The owner's disagreements with the pre-labels are reported as **"rater disagreement"** (§2.2), a separate line, never folded into the model metrics. S-pool's labels are the owner's 2026-10-04 corrections and stand on their own.

**Measured spend from \`usage\`: ${money(spent)}** against the ${money(meta.capUsd)} cap${meta.dropped.length > 0 ? `; dropped for the cap: ${meta.dropped.join(', ')}` : '; nothing dropped for the cap'}. The key: a separate key scoped to the Default workspace, read from the environment only (the production key's first replacement was organisation-level and was refused; build log 2026-10-31).

## 1. What ran

${renderSpend(data)}

## 2. Scoring cells (report §3.3, C1–C8)

Agreement with the labels on \`isCorrect\`; false "correct" as a share of the answers that are wrong; false "needs work" as a share of the answers that are right; agreement by source set and by item type.

${renderScoring(data)}

**The owner's second look at C8 (2026-10-31; \`eval/data/second-look-C8.md\`).** Of C8's 8 "needs work" verdicts against the truth: 2 are C8's errors (the key "the" of pool fb02_3, where "his" is merely more natural; "bouğht" of fb05_2, misread as a tense error, as C1 also did), 1 is an edge case both models got wrong (the umlaut variant of fb04_1), 3 carry no verdict because the pool key itself is defective (fb06_2, "has the sun": a P13 pool correction is to rewrite the question so the natural answer is "gets sun"), 1 shows C8 inconsistent with its own non-breaking-space verdict on a question whose "one modal verb" contradicts its own key (fb07_4), and 1 is a defensible owner label both models missed (an S-free sentence). Of the 21 answers where C8 and C1 differ, **C8 is right on 19 and C1 on 2**. Production today (C1) was seen to state a false rule ("afford takes -ing"), to argue with itself inside one explanation, and to penalise keyboard variants that are not Turkish as spelling errors: the D3 motivation, evidenced. **Decision:** \`claude-haiku-5-5\` at \`low\` with D3 + D11 is the production scoring model in the constant (not deployed); \`claude-sonnet-5-5\` \`low\` is the fallback.

### 2.1 Model disagreement (the owner's separate line)

For every answer both cells scored: how often the cell's \`isCorrect\` differs from C1's (production today), and who was right by the labels.

${renderDisagreement(data)}

### 2.2 Rater disagreement

${renderRater(data)}

### 2.3 Keyboard rule (S-synth)

Share of keyboard variants marked correct per class and cell, with how many explanations name the character difference; the near-miss line must read as wrong.

${renderKeyboard(data)}

### 2.4 D11 structured fields

Raw model output (before the proxy's repair): whether \`blanks\` came back, with the right length and indexes, whether \`isCorrect\` agreed with the entries, per-blank agreement with S-synth's multi-blank truths, note and summary lengths, and the explanation length on each schema.

${renderD11(data)}

## 3. Generation cells (G-A … G-F)

${renderGeneration(data)}

## 4. Daily Test prompt v2 vs v3

${renderDailyTest(data)}

## 5. P14 gate

Both gates computed from the same checker outputs with the production decision (\`annotateSet\`): the agreement gate from Opus 5.5 and Sonnet 5.5 (run 1), the single-review gate from Opus 5.5 alone. Truth: S-pool's corrections and S-live's \`accept_also\`.

${renderGate(data)}

## 6. The cost model (planning figures)

${renderCostModel(data)}

## 7. Decisions (owner, 2026-10-31)

- **Scoring:** D3 + D11 as built, effort \`low\`; after the second look (§2), \`claude-haiku-5-5\` is the production scoring model in \`PRODUCTION_SCORING\` and \`claude-sonnet-5-5\` \`low\` the fallback in \`FALLBACK_SCORING\`. Not deployed.
- **Practice generation:** \`claude-sonnet-5-5\`, \`low\`, the D3 prompt (§3).
- **P14 gate:** single review (Opus 5.5) plus the weekly review. Of the 23 written answers outside the truth none was wrong English; 17 may be written and 6 must not (they defeat the tested rule); three decision rules were added and the table in §5 is the offline re-run on the stored checker outputs. The five answers that surfaced after the rules (two single-review writes, three filtered by the kept-words rule) are all right and may be written; the kept-words rule over-filters on aspect ("have stayed" for "have been staying") and stays, with the edge recorded.
- **Prompt v3:** see §4: twelve dates a side, the owner's labels on both sheets, split by gate-passing sets.
`;
}
