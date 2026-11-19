import { CANDIDATE_SCORING, PRODUCTION_PRACTICE, buildGeneratePracticeSetBodyFor, buildScoreAnswersBodyFor, practiceThemeLine, type AnthropicRequestBody } from '../../src/anthropic';
import { filterPracticeSet } from '../../src/practice_filter';
import { practiceTheme } from '../../src/practice_theme';
import { FIRST_WAVE_TOPICS, TOPICS, topicById, type TopicInfo } from '../../src/topics';
import { validateScoreAnswers } from '../../src/validation';
import { ITEMS_PER_SET, estimateInputTokens, generationOutputTokens, scoringRequest, type PlannedCall } from './measurement';
import { duplicateSummary, rate, scoringMetrics, spendByStage, type AnswerVerdict, type TopicsRunData } from './topics_analysis';
import { gateSet, type SetGate } from './topics_checks';
import { labelledMetrics, labelledTruth, noteMarks, passCriteria, questionSummary, type Criterion, type LabelledMetrics } from './topics_labels';
import {
  SCORING_OUTPUT_TOKENS_PER_ANSWER,
  TOPICS_CAP_MARGIN,
  TOPICS_DRY_RUN_LIMIT_USD,
  TOPICS_SPEND_CAP_USD,
  answerWriterCall,
  generationId,
  placeholderAnswers,
  placeholderItems,
  planCost,
  planWorstCase,
  pricedModel,
  scoringCalls,
  type TopicAnswer,
} from './topics_measurement';
import type { QuestionLabel } from './topics_sheet';

/**
 * Phase C3 of docs/TOPICS.md (owner decisions 2026-11-19): the configuration
 * that will ship, measured once more as a whole (`topics final`), and the
 * scoring prompt candidate checked against the answers that already have
 * labels (`topics rescore`). Pure: no network, no files; `eval/run.ts` does
 * the I/O. Counts and rates only in what goes to the report.
 *
 * `topics final`: for all ten topics 6 sets through the final practice
 * request (the line on blanks, a scenario theme per set, the Conditionals
 * note), the worker's guard applied to each response; the automatic checks
 * on all 60 sets; answers, scoring and labels for the five new topics on
 * all 6 sets and for the five live topics on their first 3; every built
 * answer scored twice, with the production scoring prompt and with the
 * candidate.
 */

export const FINAL_SETS_PER_TOPIC = 6;
/** Sets of a live topic that get answers, scoring and labels. */
export const FINAL_LABELLED_SETS_LIVE = 3;
/** The day the measurement's themes are stepped from (fixed, so a resumed
 * run asks for the same requests). */
export const FINAL_DAY = '2026-11-19';

export interface FinalTopic {
  topic: TopicInfo;
  /** A first-wave topic (decided by the criteria) or a live one (for reference). */
  newTopic: boolean;
  sets: number;
  labelledSets: number;
}

/** The five first-wave topics, then the five live ones. */
export function finalTopics(): FinalTopic[] {
  return [
    ...FIRST_WAVE_TOPICS.map((topic) => ({ topic, newTopic: true, sets: FINAL_SETS_PER_TOPIC, labelledSets: FINAL_SETS_PER_TOPIC })),
    ...TOPICS.map((topic) => ({ topic, newTopic: false, sets: FINAL_SETS_PER_TOPIC, labelledSets: FINAL_LABELLED_SETS_LIVE })),
  ];
}

/** Whether set [set] of [topicId] gets answers, scoring and labels. */
export function isLabelledSet(topicId: string, set: number): boolean {
  const topic = finalTopics().find((t) => t.topic.id === topicId);
  return topic !== undefined && set <= topic.labelledSets;
}

/**
 * The theme of a topic's [set]-th set (1-based), as the worker would give
 * it to one device's consecutive practice sessions on one day: a session is
 * a generation and a scoring, so the device's request count moves on by two
 * from one set to the next. Each topic is one made-up device, so the topics
 * start at different themes.
 */
export function finalTheme(topicId: string, set: number): string {
  return practiceTheme(`measurement-${topicId}`, FINAL_DAY, 2 * (set - 1));
}

/** What the worker would send for that set: the production request with the
 * first-wave topics known and the set's theme. */
export function finalGenerationBody(topicId: string, set: number): AnthropicRequestBody {
  return buildGeneratePracticeSetBodyFor({ deviceId: 'measurement', topicId, count: ITEMS_PER_SET, theme: finalTheme(topicId, set) }, PRODUCTION_PRACTICE, true);
}

function planned(customId: string, stage: PlannedCall['stage'], group: string, body: AnthropicRequestBody, outputTokens: number, ratio?: number): PlannedCall {
  return { customId, stage, group, model: pricedModel(body.model), body, estimate: { inputTokens: estimateInputTokens(body, ratio), outputTokens }, dropPriority: 1 };
}

/** 60 calls: ten topics, six sets, each set with its own theme. */
export function finalGenerationCalls(ratio?: number): PlannedCall[] {
  const outputTokens = generationOutputTokens({ ...PRODUCTION_PRACTICE, id: 'G-D', model: pricedModel(PRODUCTION_PRACTICE.model) });
  return finalTopics().flatMap(({ topic, sets }) =>
    Array.from({ length: sets }, (_, i) => planned(generationId(topic.id, i + 1), 'generation', topic.id, finalGenerationBody(topic.id, i + 1), outputTokens, ratio)),
  );
}

/** One generated set as a learner would get it: the worker's guard applied,
 * then the measurement's gate on what is left. */
export interface GuardedSet {
  gate: SetGate;
  /** Items the model returned; null when the response was not a set. */
  received: number | null;
  /** fill_in_blank items without a blank that the guard removed. */
  removed: number;
  /** The guard left nothing: the worker would answer with an error. */
  rejected: boolean;
}

export function guardedSet(topicId: string, set: number, content: unknown): GuardedSet {
  const filtered = filterPracticeSet(content);
  return { gate: gateSet(topicId, set, filtered.rejected ? { items: [] } : filtered.content), received: filtered.received, removed: filtered.removed, rejected: filtered.rejected };
}

export interface FinalPlan {
  generation: PlannedCall[];
  answers: PlannedCall[];
  scoring: PlannedCall[];
  scoringCandidate: PlannedCall[];
  answerCount: number;
}

/** The scoring of [answers], twice: the production prompt and the candidate. */
export function finalScoringCalls(answers: readonly TopicAnswer[], ratio?: number) {
  return { production: scoringCalls(answers, ratio), candidate: scoringCalls(answers, ratio, CANDIDATE_SCORING, 'tscoreC') };
}

/** Every call `topics final` makes if nothing fails, the later stages on
 * placeholders (an upper bound: a second answer for every item that can
 * have one, and no item removed by the guard). */
export function planFinalDryRun(ratio?: number): FinalPlan {
  const answers: PlannedCall[] = [];
  const built: TopicAnswer[] = [];
  for (const { topic, labelledSets } of finalTopics()) {
    for (let set = 1; set <= labelledSets; set++) {
      const items = placeholderItems(topic.id, set);
      answers.push(answerWriterCall(topic.id, set, items, ratio));
      built.push(...placeholderAnswers(items));
    }
  }
  const scoring = finalScoringCalls(built, ratio);
  return { generation: finalGenerationCalls(ratio), answers, scoring: scoring.production.map((s) => s.call), scoringCandidate: scoring.candidate.map((s) => s.call), answerCount: built.length };
}

// ---------------------------------------------------------------------------
// topics rescore

/** A labelled run whose built answers the candidate scores again. */
export interface RescoreSource {
  /** A short tag for the call ids: `a` for the first run, `b`, `c`… */
  tag: string;
  /** The run folder's name under `eval/out/`. */
  folder: string;
  answers: readonly TopicAnswer[];
  scoringCalls: readonly { customId: string; answerIds: readonly string[] }[];
}

export interface RescoreCall {
  call: PlannedCall;
  source: string;
  answerIds: string[];
}

/**
 * The candidate's calls: every scoring call of every source again, the same
 * answers in the same order, so the scoring prompt is the only difference
 * from the stored verdicts.
 */
export function rescoreCalls(sources: readonly RescoreSource[], ratio?: number): RescoreCall[] {
  const calls: RescoreCall[] = [];
  for (const source of sources) {
    const byId = new Map(source.answers.map((a) => [a.id, a]));
    for (const original of source.scoringCalls) {
      const group = original.answerIds.map((id) => byId.get(id)).filter((a): a is TopicAnswer => a !== undefined);
      if (group.length === 0) continue;
      const body = buildScoreAnswersBodyFor(validateScoreAnswers(scoringRequest(group)), CANDIDATE_SCORING);
      calls.push({
        call: planned(`rescore_${source.tag}_${original.customId}`, 'scoring', `rescore ${source.tag}`, body, SCORING_OUTPUT_TOKENS_PER_ANSWER * group.length, ratio),
        source: source.tag,
        answerIds: group.map((a) => a.id),
      });
    }
  }
  return calls;
}

// ---------------------------------------------------------------------------
// The dry runs

const usd = (n: number) => `$${n.toFixed(2)}`;
const meanOf = (calls: readonly PlannedCall[], pick: (c: PlannedCall) => number) => (calls.length === 0 ? 0 : Math.round(calls.reduce((n, c) => n + pick(c), 0) / calls.length));

function stageRow(name: string, what: string, calls: readonly PlannedCall[]): string {
  const cost = planCost(calls);
  return `| ${name} | ${what} | ${calls[0]?.model ?? '–'} | ${calls.length} | ${meanOf(calls, (c) => c.estimate.inputTokens)} | ${meanOf(calls, (c) => c.estimate.outputTokens)} | $${(calls.length === 0 ? 0 : cost / calls.length).toFixed(4)} | ${usd(cost)} |`;
}

const TABLE_HEAD = ['| Stage | What | Model | Calls | Mean input | Mean output (incl. thinking) | Cost per call | Cost |', '|---|---|---|---|---|---|---|---|'];

export interface PairedDryRun {
  text: string;
  finalCalls: number;
  finalUsd: number;
  rescoreCalls: number;
  rescoreUsd: number;
  /** Both commands together, with what was spent, leave the cap room. */
  withinLimit: boolean;
}

/**
 * The dry run of the final configuration: `topics final` and `topics
 * rescore` side by side, because the cap is on the measurement as a whole
 * and both commands draw on what is left of it. [which]: the command the
 * printout is for (it leads with that one).
 */
export function renderFinalDryRun(plan: FinalPlan, rescore: readonly RescoreCall[], sources: readonly RescoreSource[], priorSpendUsd: number, ratio: number, which: 'final' | 'rescore'): PairedDryRun {
  const finalAll = [...plan.generation, ...plan.answers, ...plan.scoring, ...plan.scoringCandidate];
  const rescoreAll = rescore.map((r) => r.call);
  const finalUsd = planCost(finalAll);
  const rescoreUsd = planCost(rescoreAll);
  const together = finalUsd + rescoreUsd;
  const worst = planWorstCase(finalAll) + planWorstCase(rescoreAll);
  const withinLimit = together <= TOPICS_DRY_RUN_LIMIT_USD && priorSpendUsd + together * TOPICS_CAP_MARGIN <= TOPICS_SPEND_CAP_USD;
  const topics = finalTopics();
  const labelledSets = topics.reduce((n, t) => n + t.labelledSets, 0);
  const finalBlock = [
    '## topics final',
    '',
    `Topics: ${topics.map((t) => `${t.topic.id} × ${t.sets}${t.labelledSets < t.sets ? ` (${t.labelledSets} with answers)` : ''}`).join(', ')}.`,
    `${topics.reduce((n, t) => n + t.sets, 0)} sets generated with the final request, a theme per set; ${labelledSets} sets (${labelledSets * ITEMS_PER_SET} questions at most) get answers, scoring and labels; at most ${plan.answerCount} built answers, each scored twice.`,
    '',
    ...TABLE_HEAD,
    stageRow('generation', 'Topic Practice sets, the final request', plan.generation),
    stageRow('answers', 'the answer writer, one call per labelled set', plan.answers),
    stageRow('scoring', 'the production scoring prompt', plan.scoring),
    stageRow('scoring', 'the candidate scoring prompt', plan.scoringCandidate),
    `| **Total** | | | **${finalAll.length}** | | | | **${usd(finalUsd)}** |`,
  ];
  const rescoreBlock = [
    '## topics rescore',
    '',
    `The labelled answers of ${sources.length} earlier run${sources.length === 1 ? '' : 's'} (${sources.map((s) => `${s.folder}: ${s.answers.length}`).join('; ')}), scored again with the candidate prompt, the same answers per call as before.`,
    '',
    ...TABLE_HEAD,
    stageRow('scoring', 'the candidate scoring prompt', rescoreAll),
    `| **Total** | | | **${rescoreAll.length}** | | | | **${usd(rescoreUsd)}** |`,
  ];
  const lines = [
    `First-wave topics measurement, the final configuration (${which === 'final' ? 'topics final' : 'topics rescore'}) — dry run (no API call)`,
    '',
    `Characters per input token (calibrated on a measured request): ${ratio.toFixed(2)}.`,
    '',
    ...(which === 'final' ? [...finalBlock, '', ...rescoreBlock] : [...rescoreBlock, '', ...finalBlock]),
    '',
    `Estimated spend: topics final ${usd(finalUsd)} (${finalAll.length} calls), topics rescore ${usd(rescoreUsd)} (${rescoreAll.length} calls), together ${usd(together)}: ${together <= TOPICS_DRY_RUN_LIMIT_USD ? 'within' : 'OVER'} the dry-run limit of ${usd(TOPICS_DRY_RUN_LIMIT_USD)}.`,
    `The cap is on the measurement as a whole: earlier runs spent ${usd(priorSpendUsd)}; with both commands the measurement comes to ${usd(priorSpendUsd + together)} of ${usd(TOPICS_SPEND_CAP_USD)}${priorSpendUsd + together * TOPICS_CAP_MARGIN <= TOPICS_SPEND_CAP_USD ? '' : ': OVER the cap with the margin'}. A call is made only while spent + its estimate × ${TOPICS_CAP_MARGIN} stays within the cap, else it is skipped and recorded.`,
    `Worst case, every call writing all its max_tokens allows: ${usd(worst)} for both, with the earlier runs ${usd(priorSpendUsd + worst)} (${priorSpendUsd + worst <= TOPICS_SPEND_CAP_USD ? 'under the cap' : 'over the cap: if calls ran that far over their estimates, the check before each call would skip the rest and the run would end incomplete, short of the cap'}).`,
    'The scoring rows of topics final are an upper bound: they assume a second correct answer for every item that can have one and no item removed by the guard.',
  ];
  return { text: lines.join('\n'), finalCalls: finalAll.length, finalUsd, rescoreCalls: rescoreAll.length, rescoreUsd, withinLimit };
}

// ---------------------------------------------------------------------------
// Report sections

const title = (topicId: string) => topicById(topicId, true)?.title ?? topicId;

function arrow(before: string, after: string): string {
  return `${before} → ${after}`;
}

/** One labelled run for the rescore section. */
export interface RescoredRun {
  /** How the run is named in the table. */
  name: string;
  answers: readonly TopicAnswer[];
  labels: readonly QuestionLabel[];
  /** The stored verdicts (the production prompt) and the candidate's. */
  production: ReadonlyMap<string, AnswerVerdict>;
  candidate: ReadonlyMap<string, AnswerVerdict>;
}

/** The two prompts on the same labelled answers of one topic of one run. */
export interface PromptComparison {
  production: LabelledMetrics;
  candidate: LabelledMetrics;
  /** Answers on which the two prompts gave different verdicts, and how many
   * of those the candidate got right by the label. */
  changed: number;
  changedToRight: number;
  changedToWrong: number;
}

export function comparePrompts(answers: readonly TopicAnswer[], labels: readonly QuestionLabel[], production: ReadonlyMap<string, AnswerVerdict>, candidate: ReadonlyMap<string, AnswerVerdict>): PromptComparison {
  const truth = labelledTruth(labels);
  const multi = new Set(labels.filter((l) => noteMarks(l.note).multi).map((l) => l.itemId));
  // Only answers both prompts scored: the same base on both sides.
  const both = answers.filter((a) => production.has(a.id) && candidate.has(a.id));
  let changed = 0;
  let changedToRight = 0;
  let changedToWrong = 0;
  for (const a of both) {
    const label = truth.get(a.id);
    const p = production.get(a.id)?.isCorrect;
    const c = candidate.get(a.id)?.isCorrect;
    if (p === c || (label !== 'right' && label !== 'wrong')) continue;
    changed++;
    if (c === (label === 'right')) changedToRight++;
    else changedToWrong++;
  }
  return { production: labelledMetrics(both, production, truth, multi), candidate: labelledMetrics(both, candidate, truth, multi), changed, changedToRight, changedToWrong };
}

export interface RescoreSectionInput {
  runs: readonly RescoredRun[];
  generatedAt: string;
  /** The rescore's own folder, relative to the repository root. */
  runDir: string;
  calls: number;
  failed: number;
  spendUsd: number;
  priorSpendUsd: number;
}

/**
 * "The scoring prompt candidate on the labelled answers": per run and
 * topic, agreement, false "correct" and false "needs work" against the
 * labels, with the production prompt's stored verdicts and with the
 * candidate's.
 */
export function renderRescoreSection(input: RescoreSectionInput): string {
  const out: string[] = [
    '# The scoring prompt candidate on the labelled answers',
    '',
    `**Status: measured.** The built answers of the earlier runs that have labels, scored again with the scoring prompt candidate: \`${input.runDir}\`, ${input.calls} calls${input.failed > 0 ? ` (${input.failed} failed)` : ''}, ${usd(input.spendUsd)}; the measurement as a whole has then spent ${usd(input.priorSpendUsd + input.spendUsd)} of ${usd(TOPICS_SPEND_CAP_USD)}. Written by \`npm run eval -- topics rescore\` on ${input.generatedAt}. The earlier sections are as they were.`,
    '',
    'The candidate is the production scoring prompt with two additions: the verdict follows the scorer\'s own correction, and a misspelling in the form an item tests is a mistake. It is not the production prompt; whether it becomes one is the owner\'s decision. Same answers, same labels, same calls: the prompt is the only difference from the stored verdicts. An answer labelled `unsure` is in neither rate.',
    '',
    '| Run | Topic | Answers compared | Agreement: production → candidate | False "correct" (of wrong): production → candidate | False "needs work" (of right): production → candidate | Verdicts changed (candidate right / wrong by the label) |',
    '|---|---|---|---|---|---|---|',
  ];
  for (const run of input.runs) {
    const topics = [...new Set(run.answers.map((a) => a.topicId))];
    const row = (name: string, answers: readonly TopicAnswer[]) => {
      const c = comparePrompts(answers, run.labels, run.production, run.candidate);
      return `| ${run.name} | ${name} | ${c.production.compared} | ${arrow(rate(c.production.agree, c.production.compared), rate(c.candidate.agree, c.candidate.compared))} | ${arrow(rate(c.production.falseCorrect, c.production.wrong), rate(c.candidate.falseCorrect, c.candidate.wrong))} | ${arrow(rate(c.production.falseNeedsWork, c.production.right), rate(c.candidate.falseNeedsWork, c.candidate.right))} | ${c.changed} (${c.changedToRight} / ${c.changedToWrong}) |`;
    };
    for (const topicId of topics) out.push(row(title(topicId), run.answers.filter((a) => a.topicId === topicId)));
    if (topics.length > 1) out.push(row('**All topics of the run**', run.answers));
  }
  const notScored = input.runs.reduce((n, run) => n + run.answers.filter((a) => !run.candidate.has(a.id)).length, 0);
  out.push(
    '',
    `"Answers compared" are the answers labelled right or wrong that both prompts scored${notScored > 0 ? `; ${notScored} answers have no verdict from the candidate (a failed or skipped call) and are left out on both sides` : ''}. "Verdicts changed": answers the two prompts judge differently, and whether the candidate's verdict is the label's.`,
    '',
    'What to read here: whether the candidate removes false "correct" verdicts without adding false "needs work" on right answers, the risk named in phase C. The owner\'s criteria (agreement at least 95 %, false "correct" at most 2 %) apply per topic as before. One scoring of each answer with each prompt: a single changed verdict can be chance, since the scorer is not deterministic (in the 1.4.0 measurement the same prompt gave the same verdict on 98.9 % of answers scored twice).',
  );
  return out.join('\n');
}

export interface FinalSectionInput {
  data: TopicsRunData;
  /** Per generated set: what the guard did. */
  guard: readonly { topicId: string; set: number; received: number | null; removed: number; rejected: boolean }[];
  production: ReadonlyMap<string, AnswerVerdict>;
  candidate: ReadonlyMap<string, AnswerVerdict>;
  /** The labels of a complete sheet; null while it is not filled. */
  labels: readonly QuestionLabel[] | null;
  /** The first run's data, for the duplicates before the themes; null when
   * its folder is not there. */
  first: TopicsRunData | null;
  runDir: string;
  generatedAt: string;
  wallSeconds: number | null;
  priorSpendUsd: number;
  sheet: { questions: number; answers: number; labelled: number; withProblems: number };
  findings: string | null;
}

function criterion(c: Criterion): string {
  return c.pass === null ? '–' : `${rate(c.n, c.of)}: **${c.pass ? 'pass' : 'FAIL'}**`;
}

/**
 * "Final configuration": what the configuration that will ship produced.
 * Before the labels: what ran, the guard, the duplicates before and after
 * the themes, the scorer by construction with both prompts. With the
 * labels: the three criteria per new topic with both scoring prompts, the
 * live topics for reference.
 */
export function renderFinalSection(input: FinalSectionInput): string {
  const { data } = input;
  const topics = finalTopics();
  const label = (t: FinalTopic) => `${t.topic.title}${t.newTopic ? '' : ' (live)'}`;
  const labelled = input.labels !== null;
  const out: string[] = [];
  const push = (...lines: string[]) => out.push(...lines);
  let n = 0;
  const section = (heading: string) => push('', `## F${++n}. ${heading}`, '');
  const itemsOf = (id: string) => data.items.filter((i) => i.topicId === id);
  const answersOf = (id: string) => data.answers.filter((a) => a.topicId === id);
  const total = data.records.reduce((sum, r) => sum + r.costUsd, 0);

  push(
    '# Final configuration',
    '',
    `**Status: ${labelled ? 'measured and labelled.' : 'measured, not yet labelled.'}** The configuration that will ship, measured once more as a whole, the five live topics included: \`${input.runDir}\`. Written by \`npm run eval -- topics analyze\` on ${input.generatedAt}; no API call is made to write it. The earlier sections are as they were.`,
    '',
    `**What is measured.** The practice request as the worker's source now builds it: the prompt's line on blanks (1 to 4, written as underscores), a scenario theme per set (the worker's 14, stepped as one device's consecutive sessions would get them: "${practiceThemeLine('…')}"), and for Conditionals its note. The worker's guard is applied to every response: a fill-in-the-blank item without a blank is removed, as a learner would never see it. All ten topics, ${FINAL_SETS_PER_TOPIC} sets each; answers, scoring and labels for the five new topics on all ${FINAL_SETS_PER_TOPIC} sets and for the five live topics on ${FINAL_LABELLED_SETS_LIVE}. Every built answer is scored twice: with the production scoring prompt and with the candidate.`,
    '',
    labelled
      ? '**This is the result that counts for every new topic**: it is the request that will ship. The criteria are in F1, for both scoring prompts; which scoring prompt ships is the owner\'s decision.'
      : '**Its label sheet is not filled yet, so there is no result yet.** Until it is, nothing here says whether a topic passes; the scorer figures below use the truth by construction.',
  );

  const truth = input.labels ? labelledTruth(input.labels) : null;
  const multi = new Set((input.labels ?? []).filter((l) => noteMarks(l.note).multi).map((l) => l.itemId));
  const labelsByItem = new Map((input.labels ?? []).map((l) => [l.itemId, l]));

  if (truth) {
    section('The pass criteria, with both scoring prompts');
    push(
      '| Topic | Defective questions after the guard (at most 5 %) | Agreement (at least 95 %): production | candidate | False "correct" (at most 2 %): production | candidate | All three: production | candidate |',
      '|---|---|---|---|---|---|---|---|',
    );
    for (const t of topics) {
      const q = questionSummary(t.topic.id, itemsOf(t.topic.id).filter((i) => isLabelledSet(i.topicId, i.set)), labelsByItem);
      const p = passCriteria(q, labelledMetrics(answersOf(t.topic.id), input.production, truth, multi));
      const c = passCriteria(q, labelledMetrics(answersOf(t.topic.id), input.candidate, truth, multi));
      const all = (x: boolean | null) => (x === null ? '–' : `${x ? '**passes**' : '**fails**'}${t.newTopic ? '' : ' (for reference)'}`);
      push(`| ${label(t)} | ${criterion(p.defects)} | ${criterion(p.agreement)} | ${criterion(c.agreement)} | ${criterion(p.falseCorrect)} | ${criterion(c.falseCorrect)} | ${all(p.pass)} | ${all(c.pass)} |`);
    }
    push(
      '',
      'A question the guard removed is not on the sheet and in no rate: the worker removes it before a learner sees it. A question that the guard left and the measurement\'s own gate still faults is counted apart, as before. The live topics are measured the same way for reference: they ship already.',
    );
    section('The scorer against the labels, both prompts');
    push('| Topic | Answers compared | Agreement: production → candidate | False "correct" (of wrong): production → candidate | False "needs work" (of right): production → candidate | Verdicts changed (candidate right / wrong by the label) |', '|---|---|---|---|---|---|');
    const row = (name: string, answers: readonly TopicAnswer[]) => {
      const c = comparePrompts(answers, input.labels ?? [], input.production, input.candidate);
      return `| ${name} | ${c.production.compared} | ${arrow(rate(c.production.agree, c.production.compared), rate(c.candidate.agree, c.candidate.compared))} | ${arrow(rate(c.production.falseCorrect, c.production.wrong), rate(c.candidate.falseCorrect, c.candidate.wrong))} | ${arrow(rate(c.production.falseNeedsWork, c.production.right), rate(c.candidate.falseNeedsWork, c.candidate.right))} | ${c.changed} (${c.changedToRight} / ${c.changedToWrong}) |`;
    };
    for (const t of topics) push(row(label(t), answersOf(t.topic.id)));
    push(row('**The five new topics**', data.answers.filter((a) => topics.find((t) => t.topic.id === a.topicId)?.newTopic)), row('**The five live topics**', data.answers.filter((a) => !topics.find((t) => t.topic.id === a.topicId)?.newTopic)));
    section('The questions: defects and notes');
    push('| Topic | Questions on the sheet | Faulted by the gate (labelled defect) | Defects after the guard | Defects by `why` | Noted `multi:` | Noted `minor:` |', '|---|---|---|---|---|---|---|');
    for (const t of topics) {
      const q = questionSummary(t.topic.id, itemsOf(t.topic.id).filter((i) => isLabelledSet(i.topicId, i.set)), labelsByItem);
      push(`| ${label(t)} | ${q.questions} | ${q.gateFailed} (${q.gateFailedDefects}) | ${rate(q.defects, q.afterGate)} | ${Object.entries(q.byWhy).map(([w, c]) => `\`${w}\` × ${c}`).join(', ') || '–'} | ${q.multi} | ${q.minor} |`);
    }
  }

  section('What ran');
  const stages = spendByStage(data.records.filter((r) => r.group !== 'C8 candidate'));
  const candidateRecords = data.records.filter((r) => r.group === 'C8 candidate');
  push(
    '| Stage | Calls | ok | Measured spend | Mean seconds per call |',
    '|---|---|---|---|---|',
    ...stages.map((s) => `| ${s.stage}${s.stage === 'scoring' ? ', production prompt' : ''} | ${s.calls} | ${s.ok} | ${usd(s.costUsd)} | ${s.meanSeconds.toFixed(1)} |`),
    `| scoring, candidate prompt | ${candidateRecords.length} | ${candidateRecords.filter((r) => r.status === 'ok').length} | ${usd(candidateRecords.reduce((sum, r) => sum + r.costUsd, 0))} | ${(candidateRecords.length === 0 ? 0 : candidateRecords.reduce((sum, r) => sum + (r.durationMs ?? 0), 0) / candidateRecords.length / 1000).toFixed(1)} |`,
    `| **Total** | **${data.records.length}** | **${data.records.filter((r) => r.status === 'ok').length}** | **${usd(total)}** | |`,
    '',
    `The cap is on the measurement as a whole: earlier runs spent ${usd(input.priorSpendUsd)}, this run ${usd(total)}, together **${usd(input.priorSpendUsd + total)}** of ${usd(TOPICS_SPEND_CAP_USD)}; ${data.records.filter((r) => r.status === 'skipped_budget').length} calls skipped for the cap, ${data.records.filter((r) => r.status !== 'ok' && r.status !== 'skipped_budget').length} failed.${input.wallSeconds === null ? '' : ` The run took ${Math.floor(input.wallSeconds / 60)} min ${Math.round(input.wallSeconds % 60)} s.`}`,
  );

  section('What was generated, and the guard');
  push('| Topic | Sets | Items the model returned | Removed by the guard (no blank) | Sets a question short | Questions served | Faulted by the measurement\'s gate after the guard |', '|---|---|---|---|---|---|---|');
  let removedAll = 0;
  let receivedAll = 0;
  for (const t of topics) {
    const g = input.guard.filter((x) => x.topicId === t.topic.id);
    const received = g.reduce((sum, x) => sum + (x.received ?? 0), 0);
    const removed = g.reduce((sum, x) => sum + x.removed, 0);
    removedAll += removed;
    receivedAll += received;
    const items = itemsOf(t.topic.id);
    const faulted = data.checks.filter((c) => c.topicId === t.topic.id && c.gate.length > 0).length;
    push(`| ${label(t)} | ${g.length} of ${t.sets} | ${received} | ${removed} | ${g.filter((x) => x.removed > 0).length}${g.some((x) => x.rejected) ? ` (${g.filter((x) => x.rejected).length} left empty)` : ''} | ${items.length} | ${faulted} |`);
  }
  push(
    '',
    `The guard would remove **${removedAll} of ${receivedAll}** items the model returned: fill-in-the-blank items without a blank, with the prompt's line on blanks already in the request.${input.first ? ` For scale, without that line and without the guard: 1 such item in the first run's 165 and 3 in the Conditionals re-measurement's 30.` : ''} A set that lost an item reaches the learner a question short.`,
  );

  section('Duplicates, before and after the themes');
  push('| Topic | First run (no theme): questions resembling another | Groups, sizes | Final (a theme per set) | Groups, sizes | Same words / near-duplicate / inside a set / across sets, final |', '|---|---|---|---|---|---|');
  for (const t of topics) {
    const before = input.first && input.first.items.some((i) => i.topicId === t.topic.id) ? duplicateSummary(t.topic.id, input.first.items) : null;
    const after = duplicateSummary(t.topic.id, data.items);
    const sizes = (s: { groupSizes: number[] }) => (s.groupSizes.length === 0 ? '–' : s.groupSizes.join(', '));
    push(`| ${label(t)} | ${before ? rate(before.flagged, before.questions) : 'not measured'} | ${before ? sizes(before) : '–'} | ${rate(after.flagged, after.questions)} | ${sizes(after)} | ${after.sameWords} / ${after.nearDuplicate} / ${after.inSet} / ${after.acrossSets} |`);
  }
  push(
    '',
    `The same rule as before (the same words, or at least 60 % of the scenario words shared), each run compared with itself, over all the sets generated. The first run had ${FINAL_SETS_PER_TOPIC} sets per new topic and 3 of Articles; the four other live topics were not in it. The automatic checks' other flags for this run are in the run folder's \`run-report.md\`.`,
  );

  section('The scorer on the built answers, by construction, both prompts');
  push('| Topic | Built answers | Agreement: production | candidate | False "correct" (of wrong): production | candidate | False "needs work" (of right): production | candidate |', '|---|---|---|---|---|---|---|---|');
  for (const t of topics) {
    const answers = answersOf(t.topic.id);
    const p = scoringMetrics(answers, input.production);
    const c = scoringMetrics(answers, input.candidate);
    push(`| ${label(t)} | ${answers.length} | ${rate(p.agree, p.scored)} | ${rate(c.agree, c.scored)} | ${rate(p.falseCorrect, p.wrong)} | ${rate(c.falseCorrect, c.wrong)} | ${rate(p.falseNeedsWork, p.right)} | ${rate(c.falseNeedsWork, c.right)} |`);
  }
  push('', labelled ? 'Kept for the record: the truth as the answers were built. The figures that count are against the labels, above.' : 'The truth is by construction until the sheet is filled: a disagreement is the scorer\'s error or a built answer whose truth is wrong.');

  section('The label sheet');
  push(
    `${input.sheet.questions} questions and ${input.sheet.answers} built answers on a blind sheet in the run folder (not in the repository), as before: \`sheet/questions.txt\` to read, \`sheet/labels.csv\` to fill, \`private/sheet-mapping.json\` and \`private/details.txt\` ${labelled ? 'open now that the sheet is filled' : '**not to be opened before the sheet is filled**'}. The sheet shows the questions the worker would serve; its keys are not an earlier sheet's keys. It does not say which scoring prompt said what.`,
    '',
    `State of the sheet when this was written: ${input.sheet.labelled} of ${input.sheet.questions} rows labelled${input.sheet.withProblems > 0 ? `; ${input.sheet.withProblems} rows with a value to fix` : ''}.`,
  );
  if (input.findings) {
    section('Findings');
    push(input.findings.trim());
  }
  return out.join('\n');
}

/** What the estimates of both commands come to, for the progress doc. */
export function pairedCost(plan: FinalPlan, rescore: readonly RescoreCall[]): { finalUsd: number; rescoreUsd: number } {
  return { finalUsd: planCost([...plan.generation, ...plan.answers, ...plan.scoring, ...plan.scoringCandidate]), rescoreUsd: planCost(rescore.map((r) => r.call)) };
}

