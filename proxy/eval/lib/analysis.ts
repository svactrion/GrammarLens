import {
  decideQuestion,
  parseCheckOutput,
  selectCandidates,
  type CheckedSetDecision,
  type QuestionDecision,
} from '../../src/shared_check';
import type { SharedQuestion } from '../../src/shared_daily_test';
import type { LabelSource, OwnerLabel } from './labels';
import { CHECKERS, GENERATION_VARIANTS, costOf, type CheckerId } from './matrix';
import { readGeneratedSet, type CallRecord, type ReferenceSets } from './sets';

/**
 * Turns a finished E run (its call records, and the owner's labels once they
 * exist) into the numbers §13.6 asks for, as a Markdown report. Pure.
 */

/** A set's candidates as reviewed by one check call: each question's decision
 * (or null when the review could not be used), and the set's decision. */
export interface ReviewedSet {
  checker: CheckerId;
  /** A variant's set (`G…` + date) or a reference set (`R…` + repeat). */
  source: string;
  date?: string;
  repeat?: number;
  candidates: SharedQuestion[][];
  decisions: Map<string, QuestionDecision> | null;
  set: CheckedSetDecision;
}

/** Every successful check, read against the questions it reviewed. */
export function reviewedSets(records: readonly CallRecord[], references: ReferenceSets): ReviewedSet[] {
  const generations = new Map(
    records.filter((r) => r.kind === 'generation').map((r) => [`${r.variant}|${r.date}`, readGeneratedSet(r)]),
  );
  const out: ReviewedSet[] = [];
  for (const record of records) {
    if (record.kind !== 'check' || record.status !== 'ok' || !record.checker) continue;
    let candidates: SharedQuestion[][];
    if (record.reference) {
      const questions = references[record.reference];
      if (!questions) continue;
      candidates = questions.map((q) => [q]);
    } else {
      const generated = generations.get(`${record.variant}|${record.date}`);
      if (!generated?.valid) continue;
      candidates = generated.candidates;
    }
    const flat = candidates.flat();
    const checks = parseCheckOutput(record.content, flat);
    const decisions = checks
      ? new Map(flat.map((q) => [q.id, decideQuestion(q, checks.get(q.id) as NonNullable<ReturnType<typeof checks.get>>)]))
      : null;
    out.push({
      checker: record.checker,
      source: record.reference ?? (record.variant as string),
      ...(record.date === undefined ? {} : { date: record.date }),
      ...(record.repeat === undefined ? {} : { repeat: record.repeat }),
      candidates,
      decisions,
      set: selectCandidates(candidates, record.content),
    });
  }
  return out;
}

const pct = (n: number, d: number) => (d === 0 ? 'n/a' : `${((100 * n) / d).toFixed(0)}%`);
const usd = (v: number) => `$${v.toFixed(3)}`;
const labelKey = (source: string, date: string | undefined, questionId: string) => `${source}|${date ?? ''}|${questionId}`;

export interface AnalysisInput {
  records: readonly CallRecord[];
  references: ReferenceSets;
  /** Absent before labelling: the label-dependent sections say so. */
  labels?: Map<string, OwnerLabel>;
  mapping?: Record<string, LabelSource>;
  /** Mean milliseconds of each phase's JSON work, measured by the runner. */
  cpu?: { generation: Record<string, number>; check: Record<string, number> };
}

export function analyze(input: AnalysisInput): string {
  const { records } = input;
  const reviewed = reviewedSets(records, input.references);
  const labelByQuestion = new Map<string, OwnerLabel>();
  if (input.labels && input.mapping) {
    for (const [key, source] of Object.entries(input.mapping)) {
      const label = input.labels.get(key);
      if (label) labelByQuestion.set(labelKey(source.source, source.date, source.questionId), label);
    }
  }
  const hasLabels = labelByQuestion.size > 0;
  const out: string[] = ['# E — results', ''];

  // Spend
  const spent = records.reduce((s, r) => s + r.costUsd, 0);
  const skipped = records.filter((r) => r.status === 'skipped_budget').length;
  out.push(`Measured spend: **${usd(spent)}** over ${records.filter((r) => r.costUsd > 0).length} billed calls.`);
  out.push(`Skipped for the budget: ${skipped}. Not billed (errored, expired, skipped): ${records.filter((r) => r.costUsd === 0).length}.`, '');

  // 1. Owner labels
  out.push('## 1. Owner labels (raw defect rate)', '');
  if (!hasLabels) {
    out.push('No labels yet.', '');
  } else {
    out.push('| Source | Labelled | ok | minor | defect | Defect rate |', '|---|---|---|---|---|---|');
    const bySource = new Map<string, OwnerLabel[]>();
    for (const [key, label] of labelByQuestion) {
      const source = key.split('|')[0] as string;
      bySource.set(source, [...(bySource.get(source) ?? []), label]);
    }
    for (const [source, labels] of [...bySource].sort()) {
      const count = (v: string) => labels.filter((l) => l.label === v).length;
      out.push(`| ${source} | ${labels.length} | ${count('ok')} | ${count('minor')} | ${count('defect')} | ${pct(count('defect'), labels.length)} |`);
    }
    out.push('', 'G4 and G5 rows are the questions K1 would publish, so they are already after the check.', '');
  }

  // 2. Generations
  out.push('## 2. Generations and the proxy gate', '', '| Variant | Calls ok | Passed the gate | Gate rejections | Other outcomes |', '|---|---|---|---|---|');
  for (const v of GENERATION_VARIANTS) {
    const gens = records.filter((r) => r.kind === 'generation' && r.variant === v.id);
    const read = gens.filter((r) => r.status === 'ok').map((r) => readGeneratedSet(r));
    const gateReasons = read.flatMap((g) => (g.valid ? [] : [g.reason]));
    const other = gens.filter((r) => r.status !== 'ok').map((r) => r.status);
    out.push(
      `| ${v.id} | ${read.length} | ${read.filter((g) => g.valid).length} | ${gateReasons.join(', ') || '—'} | ${other.join(', ') || '—'} |`,
    );
  }
  out.push('');

  // 3. Publishing
  out.push('## 3. Publish probability (strategies S1, S2; S3 simulated)', '');
  out.push(
    '| Checker | Variant | Sets reviewed | Published | Reasons | One attempt | Within 3 attempts | S3 simulated |',
    '|---|---|---|---|---|---|---|---|',
  );
  for (const k of CHECKERS) {
    for (const vId of k.variants) {
      const attempts = records.filter((r) => r.kind === 'generation' && r.variant === vId && r.status !== 'skipped_budget').length;
      const sets = reviewed.filter((s) => s.checker === k.id && s.source === vId);
      const published = sets.filter((s) => s.set.outcome === 'publish').length;
      const reasons = sets.flatMap((s) => (s.set.outcome === 'reject' ? [s.set.reason] : s.set.outcome === 'unreadable' ? ['unreadable'] : []));
      const q = attempts === 0 ? 0 : published / attempts;
      const variant = GENERATION_VARIANTS.find((v) => v.id === vId);
      let s3 = '—';
      if (variant?.strategy === 'S1') {
        const decisions = sets.flatMap((s) => (s.decisions ? [...s.decisions.values()] : []));
        const p = decisions.length === 0 ? 1 : decisions.filter((d) => !d.pass).length / decisions.length;
        s3 = `${pct(Math.pow(1 - Math.pow(p, 3), 5), 1)} (p=${p.toFixed(2)})`;
      }
      out.push(
        `| ${k.id} | ${vId} | ${sets.length} | ${published} | ${reasons.join(', ') || '—'} | ${pct(q, 1)} | ${pct(1 - Math.pow(1 - q, 3), 1)} | ${s3} |`,
      );
    }
  }
  out.push('', '"One attempt" counts every generation call made (a call that failed or did not pass the gate is an attempt that did not publish). S3 assumes a regenerated slot is as good as a first-attempt question.', '');

  // 4. Published defect rate
  out.push('## 4. Owner-labelled defects in what would be published', '');
  if (!hasLabels) {
    out.push('No labels yet.', '');
  } else {
    out.push('| Checker | Variant | Published questions labelled | defect | minor |', '|---|---|---|---|---|');
    for (const k of CHECKERS) {
      for (const vId of k.variants) {
        const labels = reviewed
          .filter((s) => s.checker === k.id && s.source === vId && s.set.outcome === 'publish')
          .flatMap((s) => (s.set.outcome === 'publish' ? s.set.questions : []).map((q) => labelByQuestion.get(labelKey(vId, s.date, q.id))))
          .filter((l): l is OwnerLabel => l !== undefined);
        const count = (v: string) => labels.filter((l) => l.label === v).length;
        out.push(`| ${k.id} | ${vId} | ${labels.length} | ${count('defect')} (${pct(count('defect'), labels.length)}) | ${count('minor')} |`);
      }
    }
    out.push('');
  }

  // 5. Checker accuracy
  out.push('## 5. Checker accuracy against the owner labels', '');
  if (!hasLabels) {
    out.push('No labels yet.', '');
  } else {
    out.push(
      '| Checker | Defects flagged (recall) | Clean items rejected (false rejects) | Minor items rejected | Reference defects flagged in ≥ 2 of 3 repeats |',
      '|---|---|---|---|---|',
    );
    for (const k of CHECKERS) {
      let tp = 0;
      let fn = 0;
      let fp = 0;
      let tn = 0;
      let minorRejected = 0;
      let minorTotal = 0;
      const refFlags = new Map<string, number>();
      for (const s of reviewed.filter((x) => x.checker === k.id && x.decisions)) {
        for (const q of s.candidates.flat()) {
          const label = labelByQuestion.get(labelKey(s.source, s.date, q.id));
          const decision = s.decisions?.get(q.id);
          if (!label || !decision) continue;
          const flagged = !decision.pass;
          if (label.label === 'defect') flagged ? tp++ : fn++;
          else if (label.label === 'ok') flagged ? fp++ : tn++;
          else {
            minorTotal++;
            if (flagged) minorRejected++;
          }
          if (s.repeat !== undefined && label.label === 'defect') {
            const id = `${s.source}|${q.id}`;
            refFlags.set(id, (refFlags.get(id) ?? 0) + (flagged ? 1 : 0));
          }
        }
      }
      const refDefects = [...refFlags.values()];
      out.push(
        `| ${k.id} | ${tp}/${tp + fn} (${pct(tp, tp + fn)}) | ${fp}/${fp + tn} (${pct(fp, fp + tn)}) | ${minorRejected}/${minorTotal} | ${refDefects.filter((n) => n >= 2).length} of ${refDefects.length} |`,
      );
    }
    out.push('', 'Reference sets count once per repeat. Only questions the checker reviewed and the owner labelled are counted.', '');
  }

  // 6. Tokens and cost
  out.push('## 6. Measured tokens and cost per call', '', '| Call | Calls | Mean input | Mean output (incl. thinking) | Mean cost at list price | At batch price |', '|---|---|---|---|---|---|');
  const groups = new Map<string, CallRecord[]>();
  for (const r of records.filter((x) => x.status === 'ok' || x.status === 'unparseable')) {
    const key = r.kind === 'generation' ? `generation ${r.variant}` : `check ${r.checker} (${r.reference ? 'reference' : r.variant})`;
    groups.set(key, [...(groups.get(key) ?? []), r]);
  }
  const meanListCost = new Map<string, number>();
  for (const [key, rs] of [...groups].sort()) {
    const mean = (f: (r: CallRecord) => number) => rs.reduce((s, r) => s + f(r), 0) / rs.length;
    const usage = (r: CallRecord) => ({ inputTokens: r.inputTokens ?? 0, outputTokens: r.outputTokens ?? 0 });
    const list = mean((r) => costOf(r.model, usage(r), true));
    meanListCost.set(key, list);
    out.push(
      `| ${key} | ${rs.length} | ${mean((r) => r.inputTokens ?? 0).toFixed(0)} | ${mean((r) => r.outputTokens ?? 0).toFixed(0)} | ${usd(list)} | ${usd(list / 2)} |`,
    );
  }
  out.push('');
  out.push('Expected cost per published date at list price (generation + check per attempt, times the expected number of attempts within the cap of 3):', '');
  out.push('| Checker | Variant | Per attempt | Expected per date |', '|---|---|---|---|');
  for (const k of CHECKERS) {
    for (const vId of k.variants) {
      const gen = meanListCost.get(`generation ${vId}`);
      const check = meanListCost.get(`check ${k.id} (${vId})`);
      if (gen === undefined || check === undefined) continue;
      const attempts = records.filter((r) => r.kind === 'generation' && r.variant === vId && r.status !== 'skipped_budget').length;
      const published = reviewed.filter((s) => s.checker === k.id && s.source === vId && s.set.outcome === 'publish').length;
      const q = attempts === 0 ? 0 : published / attempts;
      const expected = 1 + (1 - q) + (1 - q) ** 2;
      out.push(`| ${k.id} | ${vId} | ${usd(gen + check)} | ${usd((gen + check) * expected)} |`);
    }
  }
  out.push('');

  // 7. Wall time
  out.push('## 7. Wall time (synchronous calls)', '', '| Call | Seconds |', '|---|---|');
  for (const r of records.filter((x) => x.sync && x.durationMs !== undefined)) {
    out.push(`| ${r.customId} | ${((r.durationMs ?? 0) / 1000).toFixed(1)} |`);
  }
  out.push('');

  // 8. CPU
  out.push('## 8. JSON work per phase (local Node, not Workers)', '');
  if (!input.cpu) {
    out.push('Not measured.', '');
  } else {
    out.push('| Phase | Mean ms |', '|---|---|');
    for (const [k, v] of Object.entries(input.cpu.generation)) out.push(`| generation ${k} | ${v.toFixed(3)} |`);
    for (const [k, v] of Object.entries(input.cpu.check)) out.push(`| check ${k} | ${v.toFixed(3)} |`);
    out.push('', "Parse + gate for a generation, parse + decision for a check, on the recorded outputs. Workers' own CPU accounting is measured after D3; this shows only whether the JSON work itself is a large share of the 10 ms.", '');
  }
  return out.join('\n');
}

/** Mean milliseconds of the JSON work each phase does in the Worker, on the
 * recorded outputs: parse + gate for a generation, parse + decision for a
 * check. */
export function benchmarkJsonWork(
  records: readonly CallRecord[],
  references: ReferenceSets,
  now: () => number,
  iterations = 200,
): { generation: Record<string, number>; check: Record<string, number> } {
  const generation: Record<string, number> = {};
  const check: Record<string, number> = {};
  const time = (f: () => void) => {
    const start = now();
    for (let i = 0; i < iterations; i++) f();
    return (now() - start) / iterations;
  };
  for (const v of GENERATION_VARIANTS) {
    const r = records.find((x) => x.kind === 'generation' && x.variant === v.id && x.status === 'ok');
    if (!r) continue;
    const text = JSON.stringify(r.content);
    generation[v.id] = time(() => readGeneratedSet({ ...r, content: JSON.parse(text) }));
  }
  for (const s of reviewedSets(records, references)) {
    const key = `${s.checker} ${s.candidates.flat().length}q`;
    if (key in check) continue;
    const r = records.find(
      (x) =>
        x.kind === 'check' &&
        x.status === 'ok' &&
        x.checker === s.checker &&
        (x.reference ?? x.variant) === s.source &&
        x.date === s.date &&
        x.repeat === s.repeat,
    );
    if (!r) continue;
    const text = JSON.stringify(r.content);
    check[key] = time(() => selectCandidates(s.candidates, JSON.parse(text)));
  }
  return { generation, check };
}

