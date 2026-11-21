import { topicById } from '../../src/topics';
import type { MeasureRecord } from './measurement';
import { duplicateSummary, rate, scoringMetrics, spendByStage, topicOfRecords, type AnswerVerdict, type TopicsRunData } from './topics_analysis';
import { CHECK_IDS, gateProblems, type CheckId, type ItemCheckRecord } from './topics_checks';
import { labelledMetrics, labelledTruth, noteMarks, passCriteria, questionSummary, truthVsConstruction, type Criterion } from './topics_labels';
import { TOPICS_SPEND_CAP_USD, type TopicAnswer, type TopicItem } from './topics_measurement';
import type { QuestionLabel } from './topics_sheet';

/**
 * A re-measurement of one topic (docs/TOPICS.md, phase C2): its section of
 * the report, next to the first run's figures for the same topic, and the
 * bookkeeping that keeps the section in `docs/1.5.0-topics-report.md` when
 * either run is analysed again. Pure: `eval/run.ts topics analyze` reads the
 * folders and writes the file. No API call anywhere.
 *
 * The first run's part of the report is never changed by a re-measurement:
 * the section is added after it, between markers, and one marked line under
 * the status says that it is there.
 */

const title = (topicId: string) => topicById(topicId, true)?.title ?? topicId;
const usd = (n: number) => `$${n.toFixed(2)}`;

// ---------------------------------------------------------------------------
// One topic of a run

/** [data] with only what belongs to [topicId]. */
export function restrictToTopic(data: TopicsRunData, topicId: string): TopicsRunData {
  const topicOf = topicOfRecords(data);
  const answerIds = new Set(data.answers.filter((a) => a.topicId === topicId).map((a) => a.id));
  return {
    records: data.records.filter((r) => topicOf.get(r.customId) === topicId),
    sets: data.sets.filter((s) => s.topicId === topicId),
    items: data.items.filter((i) => i.topicId === topicId),
    answers: data.answers.filter((a) => a.topicId === topicId),
    answerProblems: data.answerProblems.filter((p) => p.itemId.startsWith(`${topicId}.`)),
    scoringCalls: data.scoringCalls.filter((c) => c.answerIds.some((id) => answerIds.has(id))),
    checks: data.checks.filter((c) => c.topicId === topicId),
  };
}

/**
 * Whether the generation note kept mixed conditionals out, in two counts:
 * questions the hint-card check marks as a mixed conditional (it knows the
 * form "if + had + participle, would + verb", and needs the built key), and
 * questions whose own text names one. `notRun`: questions without a key,
 * which the check could not look at.
 */
export function mixedConditionals(items: readonly TopicItem[], checks: readonly ItemCheckRecord[]): { questions: number; flagged: number; named: number; notRun: number } {
  const named = items.filter((i) => /\bmixed\b/i.test(`${i.context ?? ''}\n${i.instruction}\n${i.hint ?? ''}`)).length;
  const flagged = checks.filter((c) => c.flags.some((f) => f.check === 'hint_card' && /^a mixed conditional/.test(f.detail))).length;
  return { questions: items.length, flagged, named, notRun: checks.filter((c) => c.notRun.includes('hint_card')).length };
}

// ---------------------------------------------------------------------------
// The section

export interface RunForSection {
  data: TopicsRunData;
  verdicts: ReadonlyMap<string, AnswerVerdict>;
  /** The labels of a complete sheet; null while the sheet is not filled. */
  labels: readonly QuestionLabel[] | null;
  /** The run folder, relative to the repository root. */
  runDir: string;
}

export interface RemeasurementInput {
  topicId: string;
  run: RunForSection;
  /** The first run, when its folder is there to be read. */
  first: RunForSection | null;
  generatedAt: string;
  wallSeconds: number | null;
  /** What the measurement's other runs spent (the cap is on the whole). */
  priorSpendUsd: number;
  sheet: { questions: number; answers: number; labelled: number; withProblems: number };
  /** Hand-written findings for this re-measurement, or null. */
  findings: string | null;
}

const CHECK_NAMES: Readonly<Record<CheckId, string>> = { topic: 'About its topic', single_answer: 'One natural answer', duplicate: 'Duplicates', length_level: 'Length and level', hint_card: 'Hint card against the key' };
const KIND: Readonly<Record<TopicAnswer['kind'], string>> = { key: 'key', variant: 'second', mistake1: 'mistake', mistake2: 'mistake' };

function criterion(c: Criterion): string {
  return c.pass === null ? '–' : `${rate(c.n, c.of)}: **${c.pass ? 'pass' : 'FAIL'}**`;
}

function duration(seconds: number): string {
  const s = Math.round(seconds);
  return s < 60 ? `${s} s` : `${Math.floor(s / 60)} min ${s % 60} s`;
}

/**
 * The section for one re-measured topic: the result that counts for it, with
 * the first run's figures for the same topic beside each table. Counts and
 * rates only, like the rest of the report.
 */
export function renderRemeasurement(input: RemeasurementInput): string {
  const { topicId } = input;
  const name = title(topicId);
  const now = { ...input.run, data: restrictToTopic(input.run.data, topicId) };
  const first = input.first ? { ...input.first, data: restrictToTopic(input.first.data, topicId) } : null;
  const runs = [
    { label: 'Re-measurement', r: now },
    ...(first ? [{ label: 'First run', r: first }] : []),
  ];
  const labelled = now.labels !== null;
  const note = topicById(topicId, true)?.generationNote;
  const out: string[] = [];
  const push = (...lines: string[]) => out.push(...lines);
  let n = 0;
  const section = (heading: string) => push('', `## R${++n}. ${heading}`, '');

  const criteriaOf = (r: RunForSection) => {
    if (r.labels === null) return null;
    const labels = new Map(r.labels.map((l) => [l.itemId, l]));
    const truth = labelledTruth(r.labels);
    const multi = new Set(r.labels.filter((l) => noteMarks(l.note).multi).map((l) => l.itemId));
    const questions = questionSummary(topicId, r.data.items, labels);
    const metrics = labelledMetrics(r.data.answers, r.verdicts, truth, multi);
    return { questions, metrics, criteria: passCriteria(questions, metrics), truth };
  };
  const nowResult = criteriaOf(now);

  push(
    `# Re-measurement: ${name}`,
    '',
    `**Status: ${labelled ? 'measured and labelled.' : 'measured, not yet labelled.'}** ${name} was measured again after a fix, in a run of its own: \`${now.runDir}\`. Written by \`npm run eval -- topics analyze\` on ${input.generatedAt}; no API call is made to write it. The first run's sections above are as they were.`,
    '',
    `**This is the ${name} result that counts.** ${
      nowResult
        ? `It replaces the ${name} rows of the first run, which stay above as they were measured: ${name} ${nowResult.criteria.pass === null ? 'has no result yet' : nowResult.criteria.pass ? '**passes** all three criteria' : '**fails**'} in the re-measurement (R1).`
        : `Its label sheet is not filled yet, so there is no result yet: until it is, nothing here says whether ${name} passes, and the first run's ${name} rows are a result for the request as it was before the fix.`
    }`,
    '',
    `**What changed between the two runs.** One sentence added to the topic line of the practice request for this topic, a generation-only note that is not sent to or shown in the app${note ? `: "${note}"` : ' (the topic has no note in the code this report was written with)'} Nothing else in any prompt changed; the hint card, the scoring prompt and every other topic's request are as they were.`,
  );

  if (nowResult) {
    section('The pass criteria');
    push(
      '| Run | Defective questions after the gate (at most 5 %) | Scoring agreement (at least 95 %) | False "correct", of wrong answers (at most 2 %) | All three |',
      '|---|---|---|---|---|',
    );
    for (const { label, r } of runs) {
      const c = criteriaOf(r);
      if (!c) {
        push(`| ${label} | – | – | – | not labelled |`);
        continue;
      }
      push(`| ${label}${r === now ? ' (the result that counts)' : ''} | ${criterion(c.criteria.defects)} | ${criterion(c.criteria.agreement)} | ${criterion(c.criteria.falseCorrect)} | ${c.criteria.pass === null ? '–' : c.criteria.pass ? '**passes**' : '**fails**'} |`);
    }
  }

  if (topicId === 'conditionals') {
    section('Did the note keep mixed conditionals out');
    push('| Run | Questions | Marked as a mixed conditional by the hint-card check | Questions whose own text names a mixed conditional | Not looked at by the check (no key) |', '|---|---|---|---|---|');
    for (const { label, r } of runs) {
      const m = mixedConditionals(r.data.items, r.data.checks);
      push(`| ${label} | ${m.questions} | ${m.flagged} | ${m.named} | ${m.notRun} |`);
    }
    push(
      '',
      'The check reads the built key and knows one of the two mixed forms (a past condition with a present result); the other count is a word search in the question. Neither is a verdict: a mixed conditional the generator wrote without naming it, in the form the check does not know, is in neither count. The labels are what settles it.',
    );
  }

  section('What ran');
  const stages = spendByStage(now.data.records);
  const total = now.data.records.reduce((sum, r) => sum + r.costUsd, 0);
  push(
    '| Stage | Model | Calls | ok | Measured spend | Mean input / output tokens | Mean seconds per call |',
    '|---|---|---|---|---|---|---|',
    ...stages.map((s) => `| ${s.stage} | ${now.data.records.find((r: MeasureRecord) => r.stage === s.stage)?.model ?? '–'} | ${s.calls} | ${s.ok} | ${usd(s.costUsd)} | ${s.meanInput} / ${s.meanOutput} | ${s.meanSeconds.toFixed(1)} |`),
    `| **Total** | | **${now.data.records.length}** | **${now.data.records.filter((r) => r.status === 'ok').length}** | **${usd(total)}** | | |`,
    '',
    `The cap is on the measurement as a whole: earlier runs spent ${usd(input.priorSpendUsd)}, this run ${usd(total)}, together **${usd(input.priorSpendUsd + total)}** of ${usd(TOPICS_SPEND_CAP_USD)}; ${now.data.records.filter((r) => r.status === 'skipped_budget').length} calls skipped for the cap, ${now.data.records.filter((r) => r.status !== 'ok' && r.status !== 'skipped_budget').length} failed.${input.wallSeconds === null ? '' : ` The run took ${duration(input.wallSeconds)}.`}`,
  );

  section('What was generated, the gate, the built answers');
  push('| Run | Sets | Sets passing the gate | Questions | Questions passing the gate | Questions with answers | Built answers (key / second / mistake) |', '|---|---|---|---|---|---|---|');
  for (const { label, r } of runs) {
    const d = r.data;
    const kinds = (k: string) => d.answers.filter((a) => KIND[a.kind] === k).length;
    push(
      `| ${label} | ${d.sets.length} | ${rate(d.sets.filter((s) => s.passed).length, d.sets.length)} | ${d.items.length} | ${rate(d.items.filter((i) => gateProblems(i).length === 0).length, d.items.length)} | ${new Set(d.answers.map((a) => a.itemId)).size} of ${d.items.length} | ${d.answers.length} (${kinds('key')} / ${kinds('second')} / ${kinds('mistake')}) |`,
    );
  }
  const gateCodes = new Map<string, number>();
  for (const i of now.data.items) for (const p of gateProblems(i)) gateCodes.set(p, (gateCodes.get(p) ?? 0) + 1);
  for (const s of now.data.sets) for (const p of s.problems) gateCodes.set(`set: ${p.replace(/:.*/, '')}`, (gateCodes.get(`set: ${p.replace(/:.*/, '')}`) ?? 0) + 1);
  const writerCodes = new Map<string, number>();
  for (const p of now.data.answerProblems) writerCodes.set(p.code, (writerCodes.get(p.code) ?? 0) + 1);
  const counts = (m: Map<string, number>) => (m.size === 0 ? 'none' : [...m.entries()].map(([code, c]) => `\`${code}\` × ${c}`).join(', '));
  push('', `In the re-measurement: what failed the gate: ${counts(gateCodes)}; notes on the writer's entries: ${counts(writerCodes)}.`);

  section('The automatic checks');
  push(`| Check | ${runs.map((x) => x.label).join(' | ')} |`, `|---|${runs.map(() => '---').join('|')}|`);
  for (const check of CHECK_IDS) {
    push(
      `| ${CHECK_NAMES[check]} | ${runs
        .map(({ r }) => {
          const flagged = r.data.checks.filter((c) => c.flags.some((f) => f.check === check)).length;
          const notRun = r.data.checks.filter((c) => c.notRun.includes(check)).length;
          return `${rate(flagged, r.data.checks.length)}${notRun > 0 ? `; ${notRun} not run` : ''}`;
        })
        .join(' | ')} |`,
    );
  }
  const codes = new Map<string, number>();
  for (const c of now.data.checks) for (const key of new Set(c.flags.map((f) => `${CHECK_NAMES[f.check]}: \`${f.code}\``))) codes.set(key, (codes.get(key) ?? 0) + 1);
  push('', `Questions with at least one flag of the check. By code, in the re-measurement: ${codes.size === 0 ? 'no flag' : [...codes.entries()].sort().map(([code, c]) => `${code} × ${c}`).join('; ')}. Flags, not verdicts.`);

  section('Duplicates inside the run');
  push('| Run | Questions flagged | Same words | Near-duplicate | Inside a set | Across sets | Groups, sizes largest first |', '|---|---|---|---|---|---|---|');
  for (const { label, r } of runs) {
    const d = duplicateSummary(topicId, r.data.items);
    push(`| ${label} | ${rate(d.flagged, d.questions)} | ${d.sameWords} | ${d.nearDuplicate} | ${d.inSet} | ${d.acrossSets} | ${d.groupSizes.length === 0 ? '–' : d.groupSizes.join(', ')} |`);
  }
  push('', 'Each run is compared with itself only. The request still gives the generator nothing to differ by from set to set (the set-variety proposal is a separate decision), so repetition across sets is expected here as in the first run.');

  section('The scorer');
  push('| Run | Truth | Built answers | Compared | Agreement | False "correct" (of wrong) | False "needs work" (of right) |', '|---|---|---|---|---|---|---|');
  for (const { label, r } of runs) {
    const c = scoringMetrics(r.data.answers, r.verdicts);
    push(`| ${label} | by construction | ${c.answers} | ${c.scored} | ${rate(c.agree, c.scored)} | ${rate(c.falseCorrect, c.wrong)} | ${rate(c.falseNeedsWork, c.right)} |`);
    const l = criteriaOf(r);
    if (l) push(`| ${label} | **by the labels** | ${l.metrics.answers} | ${l.metrics.compared} | ${rate(l.metrics.agree, l.metrics.compared)} | ${rate(l.metrics.falseCorrect, l.metrics.wrong)} | ${rate(l.metrics.falseNeedsWork, l.metrics.right)} |`);
  }
  if (nowResult) {
    const m = nowResult.metrics;
    const t = truthVsConstruction(now.data.answers, nowResult.truth);
    push(
      '',
      `In the re-measurement, by the labels: the false "needs work" is ${rate(m.falseNeedsWorkOnKey, m.keysRight)} on the built key, ${rate(m.falseNeedsWorkOnOther, m.othersRight)} on the other answers labelled right, and ${rate(m.falseNeedsWorkOnMulti, m.multiRight)} on questions noted \`multi:\`. ${m.unsure} answers are labelled \`unsure\` and are in neither rate. The labels differ from the construction on ${t.mistakesLabelledRight} built mistakes (labelled right), ${t.keysLabelledWrong} built keys and ${t.secondAnswersLabelledWrong} built second answers (labelled wrong).`,
    );
  } else {
    push('', 'The truth is by construction until the sheet is filled: a disagreement is the scorer\'s error or a built answer whose truth is wrong.');
  }

  if (nowResult) {
    section('The questions: defects and notes');
    push('| Run | Questions | Failed the gate (labelled defect) | Labelled, after the gate | Defects after the gate | Defects by `why` | Noted `multi:` | Noted `minor:` |', '|---|---|---|---|---|---|---|---|');
    for (const { label, r } of runs) {
      const c = criteriaOf(r);
      if (!c) continue;
      const q = c.questions;
      push(`| ${label} | ${q.questions} | ${q.gateFailed} (${q.gateFailedDefects}) | ${q.afterGate} | ${rate(q.defects, q.afterGate)} | ${Object.entries(q.byWhy).map(([w, c2]) => `\`${w}\` × ${c2}`).join(', ') || '–'} | ${q.multi} | ${q.minor} |`);
    }
  }

  section('The label sheet');
  push(
    `${input.sheet.questions} questions and ${input.sheet.answers} built answers on a blind sheet in the run folder (not in the repository), as in the first run: \`sheet/questions.txt\` to read, \`sheet/labels.csv\` to fill, \`private/sheet-mapping.json\` and \`private/details.txt\` ${labelled ? 'open now that the sheet is filled' : '**not to be opened before the sheet is filled**'}${labelled ? ', and `second-look.md` for the owner' : ''}. Its keys are not the first run's keys.`,
    '',
    `State of the sheet when this was written: ${input.sheet.labelled} of ${input.sheet.questions} rows labelled${input.sheet.withProblems > 0 ? `; ${input.sheet.withProblems} rows with a value to fix` : ''}.`,
  );

  if (input.findings) {
    section('Findings');
    push(input.findings.trim());
  }
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Keeping the section in the report

const START = (topicId: string) => `<!-- topics-remeasurement:${topicId}:start -->`;
const END = (topicId: string) => `<!-- topics-remeasurement:${topicId}:end -->`;
const POINTER_START = '<!-- topics-remeasurement:pointer:start -->';
const POINTER_END = '<!-- topics-remeasurement:pointer:end -->';
const BLOCK = /<!-- topics-remeasurement:([A-Za-z]+):start -->[\s\S]*?<!-- topics-remeasurement:\1:end -->/g;

/** The re-measurement sections a report holds, with their markers. */
export function remeasurementBlocks(report: string): { topicId: string; text: string }[] {
  return [...report.matchAll(BLOCK)].filter((m) => m[1] !== 'pointer').map((m) => ({ topicId: m[1] as string, text: m[0] }));
}

/** [report] without any re-measurement section and without the pointer line:
 * the first run's part alone. */
export function withoutRemeasurements(report: string): string {
  const pointer = new RegExp(`\\n*${POINTER_START}[\\s\\S]*?${POINTER_END}`, 'g');
  return `${report.replace(BLOCK, '').replace(pointer, '').replace(/\n{3,}/g, '\n\n').trimEnd()}\n`;
}

/** The id of the report's closing section: the owner's decision (phase D of
 * docs/TOPICS.md). It is written by hand, kept by every later write of the
 * report like the measured sections, and always stands last. */
export const DECISION_SECTION = 'decision';

/** The heading of a later section, by its id: a re-measured topic's id, or
 * one of the two sections of the final configuration. */
export function laterSectionName(id: string): string {
  if (id === DECISION_SECTION) return 'Decision';
  if (id === 'final') return 'Final configuration';
  if (id === 'rescore') return 'The scoring prompt candidate on the labelled answers';
  if (id === 'second') return 'The scoring prompt, second round';
  return `Re-measurement: ${title(id)}`;
}

function assemble(base: string, all: readonly { topicId: string; text: string }[]): string {
  if (all.length === 0) return base;
  // The measured sections in the order they were written; the decision last.
  const measured = all.filter((b) => b.topicId !== DECISION_SECTION);
  const decision = all.filter((b) => b.topicId === DECISION_SECTION);
  const blocks = [...measured, ...decision];
  const names = measured.map((b) => `"${laterSectionName(b.topicId)}"`);
  const pointer = `${POINTER_START}\n${measured.length > 0 ? `**Measured again after this run: see ${names.join(', ')} at the end of this report.** A later section is the result that counts for what it measures again; the rows of the first run below are kept as they were measured.` : ''}${decision.length > 0 ? `${measured.length > 0 ? ' ' : ''}**What was decided with these results: "${laterSectionName(DECISION_SECTION)}", the last section of this report.**` : ''}\n${POINTER_END}`;
  const lines = base.trimEnd().split('\n');
  const status = lines.findIndex((line) => line.startsWith('**Status:'));
  const withPointer = status < 0 ? [pointer, '', ...lines] : [...lines.slice(0, status + 1), '', pointer, ...lines.slice(status + 1)];
  return `${withPointer.join('\n')}\n\n${blocks.map((b) => b.text).join('\n\n')}\n`;
}

/**
 * [report] with [section] as the re-measurement section of [topicId]: put
 * after the first run's part (replacing an earlier version of the same
 * topic's section, keeping other topics'), with the pointer line under the
 * status. The first run's part is not touched otherwise.
 */
export function withRemeasurement(report: string, topicId: string, section: string): string {
  const block = { topicId, text: `${START(topicId)}\n${section.trim()}\n${END(topicId)}` };
  const others = remeasurementBlocks(report).filter((b) => b.topicId !== topicId);
  return assemble(withoutRemeasurements(report), [...others, block]);
}

/** A freshly written first-run report with the re-measurement sections the
 * old report had: analysing the first run again must not lose them. */
export function carryRemeasurements(oldReport: string, newReport: string): string {
  return assemble(withoutRemeasurements(newReport), remeasurementBlocks(oldReport));
}
