import { SECOND_ROUND_SCORING, type ScoringVariant } from '../../src/anthropic';
import { SCORING_ADDITION_CONDITIONALS, SCORING_ADDITION_SPELLING } from '../../src/prompts';
import type { PlannedCall } from './measurement';
import { rate, type AnswerVerdict } from './topics_analysis';
import { finalTopics, rescoreCalls, type RescoreCall, type RescoreSource } from './topics_final';
import { PASS_CRITERIA, labelledMetrics, labelledTruth, noteMarks, passCriteria, type LabelledMetrics } from './topics_labels';
import { TOPICS_CAP_MARGIN, TOPICS_DRY_RUN_LIMIT_USD, TOPICS_SPEND_CAP_USD, planCost, planWorstCase, type TopicAnswer } from './topics_measurement';
import type { QuestionLabel } from './topics_sheet';

/**
 * Phase C4 of docs/TOPICS.md (owner decisions 2026-11-19): the scoring
 * prompt's second round. Three candidates (the spelling addition alone, the
 * conditional-types addition alone, both) are scored against every built
 * answer that has labels, the same answers per call as in the stored runs;
 * and the scoring criteria are read on the labelled answers of all runs
 * pooled. Pure: no network, no files; `eval/run.ts topics rescore` does the
 * I/O. Counts and rates only in what goes to the report.
 */

export type RoundTwoId = 'S' | 'T' | 'ST';

export const ROUND_TWO: readonly { id: RoundTwoId; variant: ScoringVariant; what: string }[] = [
  { id: 'S', variant: SECOND_ROUND_SCORING.S, what: 'the spelling addition alone' },
  { id: 'T', variant: SECOND_ROUND_SCORING.T, what: 'the conditional-types addition alone' },
  { id: 'ST', variant: SECOND_ROUND_SCORING.ST, what: 'both additions' },
];

export interface RoundTwoCall extends RescoreCall {
  candidate: RoundTwoId;
}

/** Every stored scoring call of every labelled run again, once per
 * candidate: the same answers in the same order, the prompt the only
 * difference. Ids: `rescore<candidate>_<run's tag>_<the stored call's id>`. */
export function roundTwoCalls(sources: readonly RescoreSource[], ratio?: number): RoundTwoCall[] {
  return ROUND_TWO.flatMap(({ id, variant }) => rescoreCalls(sources, ratio, variant, `rescore${id}`).map((c) => ({ ...c, candidate: id })));
}

// ---------------------------------------------------------------------------
// The pooled reading

/** One labelled run with every prompt's verdicts on its built answers. */
export interface PooledRun {
  name: string;
  answers: readonly TopicAnswer[];
  labels: readonly QuestionLabel[];
  /** By prompt: `production`, and each candidate that scored the run. */
  verdicts: Readonly<Record<string, ReadonlyMap<string, AnswerVerdict>>>;
}

const ZERO: LabelledMetrics = {
  answers: 0,
  compared: 0,
  agree: 0,
  wrong: 0,
  falseCorrect: 0,
  right: 0,
  falseNeedsWork: 0,
  keysRight: 0,
  falseNeedsWorkOnKey: 0,
  othersRight: 0,
  falseNeedsWorkOnOther: 0,
  multiRight: 0,
  falseNeedsWorkOnMulti: 0,
  unsure: 0,
  unsureCalledCorrect: 0,
  notCompared: 0,
};

function add(a: LabelledMetrics, b: LabelledMetrics): LabelledMetrics {
  return Object.fromEntries((Object.keys(a) as (keyof LabelledMetrics)[]).map((k) => [k, a[k] + b[k]])) as unknown as LabelledMetrics;
}

/**
 * Each of [prompts] against the labels, over [runs] together, on the same
 * answers: those every one of the prompts gave a verdict for. [pick]
 * narrows the answers (a topic). An answer labelled `unsure` is in no rate.
 */
export function pooled(runs: readonly PooledRun[], prompts: readonly string[], pick: (a: TopicAnswer) => boolean = () => true): Record<string, LabelledMetrics> {
  const out: Record<string, LabelledMetrics> = Object.fromEntries(prompts.map((p) => [p, ZERO]));
  for (const run of runs) {
    const truth = labelledTruth(run.labels);
    const multi = new Set(run.labels.filter((l) => noteMarks(l.note).multi).map((l) => l.itemId));
    const base = run.answers.filter((a) => pick(a) && prompts.every((p) => run.verdicts[p]?.has(a.id)));
    for (const p of prompts) out[p] = add(out[p] as LabelledMetrics, labelledMetrics(base, run.verdicts[p] as ReadonlyMap<string, AnswerVerdict>, truth, multi));
  }
  return out;
}

/** The verdicts a candidate changed against the production prompt, by
 * whether the change is towards the label or away from it. */
export function changedAgainstProduction(runs: readonly PooledRun[], candidate: string, pick: (a: TopicAnswer) => boolean = () => true): { changed: number; towards: number; away: number } {
  const out = { changed: 0, towards: 0, away: 0 };
  for (const run of runs) {
    const truth = labelledTruth(run.labels);
    for (const a of run.answers) {
      const label = truth.get(a.id);
      const p = run.verdicts.production?.get(a.id)?.isCorrect;
      const c = run.verdicts[candidate]?.get(a.id)?.isCorrect;
      if (!pick(a) || p === undefined || c === undefined || p === c || (label !== 'right' && label !== 'wrong')) continue;
      out.changed++;
      if (c === (label === 'right')) out.towards++;
      else out.away++;
    }
  }
  return out;
}

/** The defect criterion's counts per topic, from the final configuration's
 * questions (it stays on that run; owner decision T-72). */
export type FinalDefects = ReadonlyMap<string, { defects: number; afterGate: number }>;

const PROMPT_NAME: Readonly<Record<string, string>> = { production: 'production prompt', S: 'candidate S', T: 'candidate T', ST: 'candidate ST' };

/**
 * The three criteria per new topic on the pooled reading: the defects of the
 * final configuration's questions, and each prompt's agreement and false
 * "correct" over every labelled run that has the topic.
 */
export function renderPooledCriteria(runs: readonly PooledRun[], prompts: readonly string[], defects: FinalDefects): string[] {
  const out = [
    `| Topic | Defective questions, final configuration (at most ${PASS_CRITERIA.maxDefectPercent} %) | Scoring prompt | Agreement, pooled (at least ${PASS_CRITERIA.minAgreementPercent} %) | False "correct", pooled (at most ${PASS_CRITERIA.maxFalseCorrectPercent} %) | All three |`,
    '|---|---|---|---|---|---|',
  ];
  const cell = (n: number, of: number, pass: boolean | null) => (pass === null ? '–' : `${rate(n, of)}: **${pass ? 'pass' : 'FAIL'}**`);
  for (const t of finalTopics().filter((x) => x.newTopic)) {
    const metrics = pooled(runs, prompts, (a) => a.topicId === t.topic.id);
    const d = defects.get(t.topic.id) ?? { defects: 0, afterGate: 0 };
    for (const p of prompts) {
      const c = passCriteria(d, metrics[p] as LabelledMetrics);
      push(out, `| ${t.topic.title} | ${cell(c.defects.n, c.defects.of, c.defects.pass)} | ${PROMPT_NAME[p] ?? p} | ${cell(c.agreement.n, c.agreement.of, c.agreement.pass)} | ${cell(c.falseCorrect.n, c.falseCorrect.of, c.falseCorrect.pass)} | ${c.pass === null ? '–' : c.pass ? '**passes**' : '**fails**'} |`);
    }
  }
  return out;
}

function push(list: string[], line: string): void {
  list.push(line);
}

// ---------------------------------------------------------------------------
// The dry run

const usd = (n: number) => `$${n.toFixed(2)}`;
const meanOf = (calls: readonly PlannedCall[], pick: (c: PlannedCall) => number) => (calls.length === 0 ? 0 : Math.round(calls.reduce((n, c) => n + pick(c), 0) / calls.length));

export interface RoundTwoDryRun {
  text: string;
  calls: number;
  usd: number;
  withinLimit: boolean;
}

/**
 * The dry run of the second round: the calls per candidate and the
 * estimated spend; and, from what is already stored and at no cost, the
 * production prompt's pooled criteria as they stand before any candidate.
 */
export function renderRoundTwoDryRun(calls: readonly RoundTwoCall[], sources: readonly RescoreSource[], priorSpendUsd: number, ratio: number, production: { runs: readonly PooledRun[]; defects: FinalDefects } | null): RoundTwoDryRun {
  const all = calls.map((c) => c.call);
  const total = planCost(all);
  const worst = planWorstCase(all);
  const withinLimit = total <= TOPICS_DRY_RUN_LIMIT_USD && priorSpendUsd + total * TOPICS_CAP_MARGIN <= TOPICS_SPEND_CAP_USD;
  const answers = sources.reduce((n, s) => n + s.answers.length, 0);
  const lines = [
    'First-wave topics measurement, the scoring prompt\'s second round (topics rescore) — dry run (no API call)',
    '',
    `Characters per input token (calibrated on a measured request): ${ratio.toFixed(2)}.`,
    '',
    `The labelled answers of ${sources.length} run${sources.length === 1 ? '' : 's'} (${sources.map((s) => `${s.folder}: ${s.answers.length}`).join('; ')}; ${answers} in all), scored again with each of ${ROUND_TWO.length} candidates, the same answers per call as in the stored runs.`,
    '',
    '| Candidate | What it adds to the production scoring prompt | Model | Calls | Mean input | Mean output (incl. thinking) | Cost per call | Cost |',
    '|---|---|---|---|---|---|---|---|',
    ...ROUND_TWO.map(({ id, what }) => {
      const mine = calls.filter((c) => c.candidate === id).map((c) => c.call);
      const cost = planCost(mine);
      return `| ${id} | ${what} | ${mine[0]?.model ?? '–'} | ${mine.length} | ${meanOf(mine, (c) => c.estimate.inputTokens)} | ${meanOf(mine, (c) => c.estimate.outputTokens)} | $${(mine.length === 0 ? 0 : cost / mine.length).toFixed(4)} | ${usd(cost)} |`;
    }),
    `| **Total** | | | **${all.length}** | | | | **${usd(total)}** |`,
    '',
    `Estimated spend ${usd(total)} (${all.length} calls): ${total <= TOPICS_DRY_RUN_LIMIT_USD ? 'within' : 'OVER'} the dry-run limit of ${usd(TOPICS_DRY_RUN_LIMIT_USD)}.`,
    `The cap is on the measurement as a whole: earlier runs spent ${usd(priorSpendUsd)}; with this run the measurement comes to ${usd(priorSpendUsd + total)} of ${usd(TOPICS_SPEND_CAP_USD)}${priorSpendUsd + total * TOPICS_CAP_MARGIN <= TOPICS_SPEND_CAP_USD ? '' : ': OVER the cap with the margin'}. A call is made only while spent + its estimate × ${TOPICS_CAP_MARGIN} stays within the cap, else it is skipped and recorded.`,
    `Worst case, every call writing all its max_tokens allows: ${usd(worst)}, with the earlier runs ${usd(priorSpendUsd + worst)} (${priorSpendUsd + worst <= TOPICS_SPEND_CAP_USD ? 'under the cap' : 'over the cap: the check before each call would skip the rest and the run would end incomplete, short of the cap'}).`,
  ];
  if (production) {
    lines.push(
      '',
      'The production scoring prompt today, before any candidate (from the stored verdicts, no call): the three criteria per new topic on the pooled reading.',
      '',
      ...renderPooledCriteria(production.runs, ['production'], production.defects),
    );
  }
  return { text: lines.join('\n'), calls: all.length, usd: total, withinLimit };
}

// ---------------------------------------------------------------------------
// The report's section

export interface RoundTwoSectionInput {
  runs: readonly PooledRun[];
  defects: FinalDefects;
  generatedAt: string;
  /** The round's own folder, relative to the repository root. */
  runDir: string;
  calls: number;
  failed: number;
  spendUsd: number;
  priorSpendUsd: number;
}

const quote = (text: string) => text.split('\n').map((line) => `> ${line}`);

/**
 * "The scoring prompt, second round": the production prompt and each
 * candidate against the labels, per topic and pooled over the runs; the
 * three criteria per new topic on the pooled reading; and the verdicts each
 * candidate changed, towards the label and away from it.
 */
export function renderRoundTwoSection(input: RoundTwoSectionInput): string {
  const { runs } = input;
  const candidates = ROUND_TWO.map((c) => c.id).filter((id) => runs.some((r) => r.verdicts[id] !== undefined));
  const prompts = ['production', ...candidates];
  const answers = runs.reduce((n, r) => n + r.answers.length, 0);
  const all = pooled(runs, prompts);
  const base = (all.production as LabelledMetrics).compared;
  const cells = (m: Record<string, LabelledMetrics>, pick: (x: LabelledMetrics) => string) => prompts.map((p) => pick(m[p] as LabelledMetrics)).join(' · ');
  const row = (name: string, m: Record<string, LabelledMetrics>) => {
    const p = m.production as LabelledMetrics;
    return `| ${name} | ${p.compared} | ${cells(m, (x) => `${x.agree}`)} | ${cells(m, (x) => `${x.falseCorrect}`)} of ${p.wrong} | ${cells(m, (x) => `${x.falseNeedsWork}`)} of ${p.right} |`;
  };
  const notScored = (id: string) => runs.reduce((n, r) => n + r.answers.filter((a) => !r.verdicts[id]?.has(a.id)).length, 0);
  const out: string[] = [
    '# The scoring prompt, second round',
    '',
    `**Status: measured.** The ${answers} built answers that have labels (${runs.map((r) => `${r.name}: ${r.answers.length}`).join('; ')}), scored again with ${candidates.length} candidates: \`${input.runDir}\`, ${input.calls} calls${input.failed > 0 ? ` (${input.failed} failed)` : ''}, ${usd(input.spendUsd)}; the measurement as a whole has then spent ${usd(input.priorSpendUsd + input.spendUsd)} of ${usd(TOPICS_SPEND_CAP_USD)}. Written by \`npm run eval -- topics rescore\` on ${input.generatedAt}. The earlier sections are as they were.`,
    '',
    '**What was tried.** The first candidate was dropped (owner, 2026-11-19). This round adds one of two short paragraphs to the production scoring prompt, or both; nothing else changes, and none of the three is live.',
    '',
    '**S**, the spelling addition:',
    '',
    ...quote(SCORING_ADDITION_SPELLING),
    '',
    '**T**, the conditional-types addition:',
    '',
    ...quote(SCORING_ADDITION_CONDITIONALS),
    '',
    '**ST**: both, S then T.',
    '',
    '**How the criteria are read (owner, 2026-11-19).** Agreement and false "correct" are properties of the scorer, and at 45 to 49 answers labelled wrong a topic, "at most 2 %" allows not one answer in a single run. So each topic\'s scoring numbers are pooled over every labelled run that has the topic (the first run, the Conditionals re-measurement, the final configuration). The defect criterion stays on the final configuration\'s questions.',
    '',
    '## S1. The three criteria per new topic, on the pooled reading',
    '',
    ...renderPooledCriteria(runs, prompts, input.defects),
    '',
    `Every prompt is held to the same answers: those labelled right or wrong that each of the ${prompts.length} gave a verdict for (${base} of the ${answers}; an answer labelled \`unsure\` is in no rate). Without a usable verdict: ${prompts.map((p) => `${PROMPT_NAME[p] ?? p} ${notScored(p)}`).join(', ')}.`,
    '',
    '## S2. Each prompt against the labels, per topic, pooled over the runs',
    '',
    `In each cell: ${prompts.map((p) => PROMPT_NAME[p] ?? p).join(' · ')}.`,
    '',
    '| Topic | Answers compared | Agreement | False "correct" (of wrong) | False "needs work" (of right) |',
    '|---|---|---|---|---|',
    ...finalTopics().map((t) => row(`${t.topic.title}${t.newTopic ? '' : ' (live)'}`, pooled(runs, prompts, (a) => a.topicId === t.topic.id))),
    row('**The five new topics**', pooled(runs, prompts, (a) => finalTopics().some((t) => t.newTopic && t.topic.id === a.topicId))),
    row('**Everything labelled**', all),
    '',
    '## S3. Each prompt against the labels, per run',
    '',
    '| Run | Answers compared | Agreement | False "correct" (of wrong) | False "needs work" (of right) |',
    '|---|---|---|---|---|',
    ...runs.map((r) => row(r.name, pooled([r], prompts))),
    '',
    '## S4. The verdicts each candidate changed',
    '',
    'Against the production prompt\'s stored verdict on the same answer: towards the label (the candidate has the label\'s verdict, the production prompt has not) and away from it.',
    '',
    '| Candidate | Verdicts changed | Towards the label | Away from the label | Of them in Conditionals (towards / away) | In the other topics (towards / away) |',
    '|---|---|---|---|---|---|',
    ...candidates.map((id) => {
      const c = changedAgainstProduction(runs, id);
      const cond = changedAgainstProduction(runs, id, (a) => a.topicId === 'conditionals');
      return `| ${id} | ${c.changed} | ${c.towards} | ${c.away} | ${cond.towards} / ${cond.away} | ${c.towards - cond.towards} / ${c.away - cond.away} |`;
    }),
    '',
    'One scoring of each answer with each prompt. The scorer is not deterministic: in the 1.4.0 measurement the same prompt gave the same verdict on 98.9 % of answers scored twice, so about one changed verdict in a hundred answers is what two runs of one prompt would show; a candidate\'s changes mean something only beyond that, and by their direction. Every changed verdict, with the question, the label and both scorers\' words, is in the run folder\'s `changed-verdicts.md` (not in the repository).',
  ];
  return out.join('\n');
}
