import { checkScoreFeedback } from '../../src/score_feedback';
import { topicById } from '../../src/topics';
import { scoringRequest, type MeasureRecord } from './measurement';
import { CHECK_IDS, duplicateGroups, duplicatePairs, gateProblems, type CheckId, type DuplicatePair, type ItemCheckRecord } from './topics_checks';
import { TOPICS_SPEND_CAP_USD, measuredTopics, type AnswerKind, type AnswerProblem, type TopicAnswer, type TopicItem } from './topics_measurement';

/**
 * Phase B of the 1.5.0 first-wave topics measurement (docs/TOPICS.md): the
 * report written from a finished run folder. Pure: `eval/run.ts topics
 * analyze` reads the folder and writes the files. No API call anywhere.
 *
 * The report is committed and read by the people who label the sheet, so it
 * holds counts and rates only: never a question's text, an answer's text or
 * a sheet key ({@link contentLeaks} is the check).
 */

/** One generated set as the run's `sets.json` keeps it. */
export interface SetSummary {
  topicId: string;
  set: number;
  passed: boolean;
  problems: string[];
  items: number;
}

/** What a run folder holds, as phase A wrote it. */
export interface TopicsRunData {
  records: readonly MeasureRecord[];
  sets: readonly SetSummary[];
  items: readonly TopicItem[];
  answers: readonly TopicAnswer[];
  answerProblems: readonly AnswerProblem[];
  scoringCalls: readonly { customId: string; answerIds: readonly string[] }[];
  checks: readonly ItemCheckRecord[];
}

// ---------------------------------------------------------------------------
// The scorer's verdicts

/** What the scorer said about one built answer, as the app would get it. */
export interface AnswerVerdict {
  answerId: string;
  isCorrect: boolean;
  correctedAnswer: string;
  explanation: string;
  summary?: string;
  rule?: string;
}

export interface ScoredAnswers {
  verdicts: Map<string, AnswerVerdict>;
  /** Built answers with no verdict: their call is missing or not ok, or the
   * scorer returned nothing usable for them. */
  notScored: string[];
  /** Scoring calls read (ok, and named in `scoring-calls.json`). */
  calls: number;
  /** The proxy's repairs (`checkScoreFeedback`), over all calls. */
  structuredDropped: number;
  verdictReconciled: number;
}

/**
 * The verdict per built answer. A scoring record counts only when
 * `scoring-calls.json` names it (a call whose answers changed between two
 * runs of a folder has another id), and its output goes through the proxy's
 * own `checkScoreFeedback` first, as on the route: `isCorrect` here is what
 * the app would be sent.
 */
export function scoredAnswers(data: Pick<TopicsRunData, 'records' | 'answers' | 'scoringCalls'>): ScoredAnswers {
  const records = new Map(data.records.map((r) => [r.customId, r]));
  const answers = new Map(data.answers.map((a) => [a.id, a]));
  const verdicts = new Map<string, AnswerVerdict>();
  let calls = 0;
  let structuredDropped = 0;
  let verdictReconciled = 0;
  for (const call of data.scoringCalls) {
    const record = records.get(call.customId);
    if (!record || record.status !== 'ok') continue;
    const group = call.answerIds.map((id) => answers.get(id)).filter((a): a is TopicAnswer => a !== undefined);
    const checked = checkScoreFeedback(scoringRequest(group), record.content);
    calls++;
    structuredDropped += checked.structuredDropped;
    verdictReconciled += checked.verdictReconciled;
    const feedback = (checked.content as { feedback?: unknown } | null)?.feedback;
    if (!Array.isArray(feedback)) continue;
    for (const raw of feedback) {
      const f = (raw ?? {}) as Record<string, unknown>;
      if (typeof f.itemId !== 'string' || !call.answerIds.includes(f.itemId) || typeof f.isCorrect !== 'boolean' || verdicts.has(f.itemId)) continue;
      verdicts.set(f.itemId, {
        answerId: f.itemId,
        isCorrect: f.isCorrect,
        correctedAnswer: typeof f.correctedAnswer === 'string' ? f.correctedAnswer : '',
        explanation: typeof f.explanation === 'string' ? f.explanation : '',
        ...(typeof f.summary === 'string' ? { summary: f.summary } : {}),
        ...(typeof f.rule === 'string' ? { rule: f.rule } : {}),
      });
    }
  }
  return { verdicts, notScored: data.answers.filter((a) => !verdicts.has(a.id)).map((a) => a.id), calls, structuredDropped, verdictReconciled };
}

/** The scorer against the truth by construction, over a group of answers. */
export interface ScoringMetrics {
  answers: number;
  scored: number;
  /** Scored answers whose `isCorrect` equals the built truth. */
  agree: number;
  /** Scored answers built as wrong, and how many of them were called correct. */
  wrong: number;
  falseCorrect: number;
  /** Scored answers built as right, and how many were called "needs work". */
  right: number;
  falseNeedsWork: number;
}

export function scoringMetrics(answers: readonly TopicAnswer[], verdicts: ReadonlyMap<string, AnswerVerdict>): ScoringMetrics {
  const m: ScoringMetrics = { answers: answers.length, scored: 0, agree: 0, wrong: 0, falseCorrect: 0, right: 0, falseNeedsWork: 0 };
  for (const a of answers) {
    const v = verdicts.get(a.id);
    if (!v) continue;
    m.scored++;
    if (v.isCorrect === a.truth) m.agree++;
    if (a.truth) {
      m.right++;
      if (!v.isCorrect) m.falseNeedsWork++;
    } else {
      m.wrong++;
      if (v.isCorrect) m.falseCorrect++;
    }
  }
  return m;
}

// ---------------------------------------------------------------------------
// Duplicates

export interface DuplicateSummary {
  topicId: string;
  questions: number;
  /** Questions with at least one resembling question. */
  flagged: number;
  /** Questions per kind of pair they are in; a question in pairs of two
   * kinds is counted in both. */
  sameWords: number;
  nearDuplicate: number;
  inSet: number;
  acrossSets: number;
  /** Pairs by kind: same words or near, inside a set or across sets. */
  pairs: { sameInSet: number; sameAcrossSets: number; nearInSet: number; nearAcrossSets: number };
  /** Sizes of the groups of resembling questions, largest first. */
  groupSizes: number[];
  /** How many of the topic's sets the largest group reaches into. */
  largestGroupSets: number;
  /** Flagged questions by type. */
  byType: Record<TopicItem['type'], number>;
}

export function duplicateSummary(topicId: string, items: readonly TopicItem[], pairs: readonly DuplicatePair[] = duplicatePairs(items)): DuplicateSummary {
  const mine = items.filter((i) => i.topicId === topicId);
  const myPairs = pairs.filter((p) => p.a.topicId === topicId);
  const ids = (pick: (p: DuplicatePair) => boolean) => new Set(myPairs.filter(pick).flatMap((p) => [p.a.id, p.b.id]));
  const flagged = ids(() => true);
  const groups = duplicateGroups(mine, myPairs).sort((a, b) => b.length - a.length);
  const count = (pick: (p: DuplicatePair) => boolean) => myPairs.filter(pick).length;
  const byType = { fill_in_blank: 0, error_correction: 0, sentence_writing: 0 };
  for (const item of mine) if (flagged.has(item.id)) byType[item.type]++;
  return {
    topicId,
    questions: mine.length,
    flagged: flagged.size,
    sameWords: ids((p) => p.same).size,
    nearDuplicate: ids((p) => !p.same).size,
    inSet: ids((p) => p.inSet).size,
    acrossSets: ids((p) => !p.inSet).size,
    pairs: {
      sameInSet: count((p) => p.same && p.inSet),
      sameAcrossSets: count((p) => p.same && !p.inSet),
      nearInSet: count((p) => !p.same && p.inSet),
      nearAcrossSets: count((p) => !p.same && !p.inSet),
    },
    groupSizes: groups.map((g) => g.length),
    largestGroupSets: groups[0] ? new Set(groups[0].map((i) => i.set)).size : 0,
    byType,
  };
}

// ---------------------------------------------------------------------------
// Spend and time

export interface StageSpend {
  stage: string;
  calls: number;
  ok: number;
  costUsd: number;
  /** Mean seconds of an ok call. */
  meanSeconds: number;
  meanInput: number;
  meanOutput: number;
}

const STAGES = ['generation', 'answers', 'scoring'] as const;

const mean = (values: readonly number[]) => (values.length === 0 ? 0 : values.reduce((a, b) => a + b, 0) / values.length);

function stageSpend(stage: string, records: readonly MeasureRecord[]): StageSpend {
  const ok = records.filter((r) => r.status === 'ok');
  return {
    stage,
    calls: records.length,
    ok: ok.length,
    costUsd: records.reduce((n, r) => n + r.costUsd, 0),
    meanSeconds: mean(ok.map((r) => (r.durationMs ?? 0) / 1000)),
    meanInput: Math.round(mean(ok.map((r) => r.inputTokens ?? 0))),
    meanOutput: Math.round(mean(ok.map((r) => r.outputTokens ?? 0))),
  };
}

export function spendByStage(records: readonly MeasureRecord[]): StageSpend[] {
  return STAGES.map((stage) => stageSpend(stage, records.filter((r) => r.stage === stage)));
}

/** The topic of each record: generation and answers carry it as their
 * group; a scoring call scores one set, so it has its answers' topic. */
export function topicOfRecords(data: Pick<TopicsRunData, 'records' | 'answers' | 'scoringCalls'>): Map<string, string> {
  const answers = new Map(data.answers.map((a) => [a.id, a.topicId]));
  const out = new Map<string, string>();
  for (const r of data.records) if (r.stage === 'generation' || r.stage === 'answers') out.set(r.customId, r.group);
  for (const call of data.scoringCalls) {
    const topic = call.answerIds.map((id) => answers.get(id)).find((t) => t !== undefined);
    if (topic) out.set(call.customId, topic);
  }
  return out;
}

/** The run's wall time in seconds, from the first and the last line of
 * `progress.log` that start with a timestamp; null when it has fewer than two. */
export function wallSeconds(progressLog: string): number | null {
  const stamps = progressLog
    .split(/\r?\n/)
    .map((line) => Date.parse(line.slice(0, 24)))
    .filter((t) => !Number.isNaN(t));
  if (stamps.length < 2) return null;
  return (Math.max(...stamps) - Math.min(...stamps)) / 1000;
}

// ---------------------------------------------------------------------------
// The report

export interface TopicsReportMeta {
  /** The run folder, relative to the repository root. */
  runDir: string;
  /** `YYYY-MM-DD HH:MM UTC`. */
  generatedAt: string;
  wallSeconds: number | null;
  /** The label sheet's state: rows on it, and how many are labelled. */
  sheet: { questions: number; answers: number; labelled: number; withProblems: number };
}

/**
 * What phase C puts into the report once the sheet is filled
 * (`topics_labels.ts` builds it): the status line, the limitations, the
 * label sections (their headings start with `## § `, numbered with the
 * rest), and the closing section. Without it the report is phase B's.
 */
export interface PhaseCParts {
  status: string;
  limitations: string[];
  sections: string[];
  next: string[];
}

const usd = (n: number) => `$${n.toFixed(2)}`;
const title = (topicId: string) => topicById(topicId, true)?.title ?? topicId;

/** `96.4 % (27 / 28)`, or `–` when there is nothing to divide by. */
export function rate(n: number, of: number): string {
  return of === 0 ? '–' : `${((n / of) * 100).toFixed(1)} % (${n} / ${of})`;
}

function duration(seconds: number): string {
  const s = Math.round(seconds);
  return s < 60 ? `${s} s` : `${Math.floor(s / 60)} min ${s % 60} s`;
}

const KIND_LABEL: Readonly<Record<AnswerKind, string>> = { key: 'key', variant: 'second answer', mistake1: 'mistake', mistake2: 'mistake' };
const TYPE_LABEL: Readonly<Record<TopicItem['type'], string>> = { sentence_writing: 'written sentence', error_correction: 'correction', fill_in_blank: 'fill in the blank' };
const CHECK_LABEL: Readonly<Record<CheckId, string>> = { topic: 'About its topic', single_answer: 'One natural answer', duplicate: 'Duplicates', length_level: 'Length and level', hint_card: 'Hint card against the key' };

function metricsRow(label: string, m: ScoringMetrics): string {
  return `| ${label} | ${m.answers} | ${m.scored} | ${rate(m.agree, m.scored)} | ${rate(m.falseCorrect, m.wrong)} | ${rate(m.falseNeedsWork, m.right)} |`;
}

/**
 * The report. Per topic and for the control: what was generated, the gate,
 * each automatic check's flags, the duplicates in detail, the scorer against
 * the built answers, spend and time; with [phaseC], the label sections come
 * first. Counts and rates only.
 */
export function renderTopicsReport(data: TopicsRunData, meta: TopicsReportMeta, phaseC?: PhaseCParts): string {
  const topics = measuredTopics();
  const newIds = new Set(topics.filter((t) => !t.control).map((t) => t.topic.id));
  const label = (t: (typeof topics)[number]) => `${t.topic.title}${t.control ? ' (control)' : ''}`;
  const scored = scoredAnswers(data);
  const pairs = duplicatePairs(data.items);
  const recordTopic = topicOfRecords(data);
  const stages = spendByStage(data.records);
  const total = data.records.reduce((n, r) => n + r.costUsd, 0);
  const itemsOf = (id: string) => data.items.filter((i) => i.topicId === id);
  const answersOf = (id: string) => data.answers.filter((a) => a.topicId === id);
  const checksOf = (id: string) => data.checks.filter((c) => c.topicId === id);
  const out: string[] = [];
  const push = (...lines: string[]) => out.push(...lines);

  const newAnswers = data.answers.filter((a) => newIds.has(a.topicId));
  const controlAnswers = data.answers.filter((a) => !newIds.has(a.topicId));
  const allNew = scoringMetrics(newAnswers, scored.verdicts);

  push(
    '# 1.5.0 first-wave topics — measurement report',
    '',
    `**Status: ${phaseC ? phaseC.status : 'measured, not yet labelled (phase B of [`TOPICS.md`](TOPICS.md)).'}** Written by \`npm run eval -- topics analyze\` on ${meta.generatedAt} from \`${meta.runDir}\`, the owner's run of 2026-11-18. No API call is made to write it. Nothing is deployed and the first-wave topics stay switched off. Record and decisions: [\`1.5.0-topics-progress.md\`](1.5.0-topics-progress.md).`,
    '',
    '## § Limitations, before any number',
    '',
    ...(phaseC
      ? phaseC.limitations
      : [
          '- **The answers are built, not real learners\'.** A practice question carries no answer key, so a model wrote, for every question, a key, a second correct answer where it found one, and typical learner mistakes (decision T-2).',
          '- **Their truth is by construction until phase C.** "Right" below means "written as the key or the second answer", "wrong" means "written as a mistake". A written mistake that is in fact acceptable is counted here against the scorer, and a wrong key too. Every built answer is on the label sheet; phase C replaces this truth with the labelled one (T-13).',
          '- **The automatic checks are flags, not verdicts.** They are word-level rules that know nothing about meaning: a flag is a reason for a person to look. How the flags relate to real defects is known only after the labels.',
          '- **No question is judged here.** Whether a question is good is the label sheet\'s job: all 165 questions are on it (T-12), and it is blind (T-14).',
          '- **Small numbers.** 30 questions per new topic and 15 for the control: one question is 3.3 % of a topic, one of the control\'s 6.7 %.',
          '- This report holds counts and rates only: no question, no answer and no sheet key, so it can be read before and while labelling.',
        ]),
    '',
    ...(phaseC ? [...phaseC.sections, ''] : []),
    '## § What ran',
    '',
    '| Stage | Model | Calls | ok | Measured spend | Mean input / output tokens | Mean seconds per call |',
    '|---|---|---|---|---|---|---|',
    ...stages.map((s) => {
      const model = data.records.find((r) => r.stage === s.stage)?.model ?? '–';
      return `| ${s.stage} | ${model} | ${s.calls} | ${s.ok} | ${usd(s.costUsd)} | ${s.meanInput} / ${s.meanOutput} | ${s.meanSeconds.toFixed(1)} |`;
    }),
    `| **Total** | | **${data.records.length}** | **${data.records.filter((r) => r.status === 'ok').length}** | **${usd(total)}** | | |`,
    '',
    `Measured spend from \`usage\`: **${usd(total)}** against the ${usd(TOPICS_SPEND_CAP_USD)} cap; ${data.records.filter((r) => r.status === 'skipped_budget').length} calls skipped for the cap, ${data.records.filter((r) => r.status !== 'ok' && r.status !== 'skipped_budget').length} failed.${meta.wallSeconds === null ? '' : ` The run took ${duration(meta.wallSeconds)} from its first to its last log line.`}`,
    '',
    '- **generation:** Topic Practice sets through the live practice path (the production prompt, model and effort), the first-wave topics known for these requests only.',
    '- **answers:** the harness\'s answer writer, one call per generated set.',
    '- **scoring:** the production scoring cell (1.4.0\'s C8), one generated set\'s questions per call.',
    '',
    '## § What was generated, and the gate',
    '',
    'The practice path has no semantic gate (T-4). The measurement\'s gate is what the app\'s parser accepts, plus the prompt\'s rules a program can check: a fill-in-the-blank question has 1 to 4 blanks, a correction carries its sentence, and a set is 5 questions in the 2 : 2 : 1 mix the request names.',
    '',
    '| Topic | Sets | Sets passing the gate | Questions | Questions passing the gate | Written sentence / correction / fill in the blank |',
    '|---|---|---|---|---|---|',
  );
  for (const t of topics) {
    const sets = data.sets.filter((s) => s.topicId === t.topic.id);
    const items = itemsOf(t.topic.id);
    const n = (type: TopicItem['type']) => items.filter((i) => i.type === type).length;
    push(
      `| ${label(t)} | ${sets.length} of ${t.sets} | ${rate(sets.filter((s) => s.passed).length, sets.length)} | ${items.length} | ${rate(items.filter((i) => gateProblems(i).length === 0).length, items.length)} | ${n('sentence_writing')} / ${n('error_correction')} / ${n('fill_in_blank')} |`,
    );
  }
  const failedSets = data.sets.filter((s) => !s.passed);
  const failedItems = data.items.filter((i) => gateProblems(i).length > 0);
  push('');
  if (failedSets.length === 0) push('Every set passed.');
  else {
    push('What failed, as counts (which question it was is in the details file):', '');
    for (const t of topics) {
      const sets = failedSets.filter((s) => s.topicId === t.topic.id);
      if (sets.length === 0) continue;
      const reasons = new Map<string, number>();
      for (const s of sets) for (const p of s.problems) reasons.set(`set: \`${p.replace(/:.*/, '')}\``, (reasons.get(`set: \`${p.replace(/:.*/, '')}\``) ?? 0) + 1);
      for (const i of failedItems.filter((x) => x.topicId === t.topic.id)) for (const p of gateProblems(i)) reasons.set(`question: \`${p}\``, (reasons.get(`question: \`${p}\``) ?? 0) + 1);
      push(`- ${title(t.topic.id)}: ${sets.length} set${sets.length === 1 ? '' : 's'} (${[...reasons.entries()].map(([r, n]) => `${r} × ${n}`).join('; ')}).`);
    }
  }

  push(
    '',
    '## § The built answers',
    '',
    '| Topic | Questions with answers | Built answers | Keys | Second answers | Mistakes | Right / wrong by construction |',
    '|---|---|---|---|---|---|---|',
  );
  for (const t of topics) {
    const answers = answersOf(t.topic.id);
    const kind = (k: string) => answers.filter((a) => KIND_LABEL[a.kind] === k).length;
    push(
      `| ${label(t)} | ${new Set(answers.map((a) => a.itemId)).size} of ${itemsOf(t.topic.id).length} | ${answers.length} | ${kind('key')} | ${kind('second answer')} | ${kind('mistake')} | ${answers.filter((a) => a.truth).length} / ${answers.filter((a) => !a.truth).length} |`,
    );
  }
  push(`| **All** | ${new Set(data.answers.map((a) => a.itemId)).size} of ${data.items.length} | ${data.answers.length} | | | | ${data.answers.filter((a) => a.truth).length} / ${data.answers.filter((a) => !a.truth).length} |`, '');
  if (data.answerProblems.length === 0) push('The writer\'s entry was usable for every question.');
  else {
    const topicOfItem = new Map(data.items.map((i) => [i.id, i.topicId]));
    const codes = new Map<string, Map<string, number>>();
    for (const p of data.answerProblems) {
      const row = codes.get(p.code) ?? new Map<string, number>();
      const topic = title(topicOfItem.get(p.itemId) ?? p.itemId.split('.')[0] ?? '');
      row.set(topic, (row.get(topic) ?? 0) + 1);
      codes.set(p.code, row);
    }
    push('Notes on the writer\'s entries, as counts (a note on a second answer or a mistake leaves the question\'s other answers in place; `key_unusable` leaves the question without answers):', '');
    for (const [code, row] of codes) push(`- \`${code}\`: ${[...row.entries()].map(([topic, n]) => `${topic} × ${n}`).join(', ')}`);
  }
  push('', 'A written sentence gets a key and one mistake; a correction and a fill-in-the-blank question get a key, two mistakes, and a second answer only when the writer found one that differs in the tested structure.');

  push(
    '',
    '## § The automatic checks',
    '',
    'Questions with at least one flag of the check. "Not run" means the check needs the key and the question has none.',
    '',
    `| Topic | Questions | ${CHECK_IDS.map((c) => CHECK_LABEL[c]).join(' | ')} | No flag at all |`,
    `|---|---|${CHECK_IDS.map(() => '---').join('|')}|---|`,
  );
  for (const t of topics) {
    const checks = checksOf(t.topic.id);
    const cell = (c: CheckId) => {
      const flagged = checks.filter((r) => r.flags.some((f) => f.check === c)).length;
      const notRun = checks.filter((r) => r.notRun.includes(c)).length;
      return `${rate(flagged, checks.length)}${notRun > 0 ? `; ${notRun} not run` : ''}`;
    };
    push(`| ${label(t)} | ${checks.length} | ${CHECK_IDS.map(cell).join(' | ')} | ${rate(checks.filter((r) => r.flags.length === 0).length, checks.length)} |`);
  }
  const codes = new Map<string, Map<string, number>>();
  for (const r of data.checks) {
    for (const key of new Set(r.flags.map((f) => `${f.check}|${f.code}`))) {
      const row = codes.get(key) ?? new Map<string, number>();
      row.set(r.topicId, (row.get(r.topicId) ?? 0) + 1);
      codes.set(key, row);
    }
  }
  push('', 'The same flags by code (questions with the code):', '', `| Check | Code | ${topics.map(label).join(' | ')} |`, `|---|---|${topics.map(() => '---').join('|')}|`);
  for (const check of CHECK_IDS) {
    for (const [key, row] of [...codes.entries()].filter(([k]) => k.startsWith(`${check}|`)).sort()) {
      push(`| ${CHECK_LABEL[check]} | \`${key.split('|')[1]}\` | ${topics.map((t) => row.get(t.topic.id) ?? 0).join(' | ')} |`);
    }
  }
  if (codes.size === 0) push('| – | – | ' + topics.map(() => 0).join(' | ') + ' |');
  push(
    '',
    'Reading the columns: the one-answer and hint-card rules are thinner for the control than for the new topics (T-7), so those two columns do not compare across the line; the gate, the topic check, the duplicates and the length check do.',
  );

  push(
    '',
    '## § Duplicates',
    '',
    'Two questions of one topic resemble each other when they have the same words ("same words": case, punctuation and numbers aside) or share at least 60 % of their scenario words and are of the same type ("near-duplicate"). Only questions of one topic are compared.',
    '',
    '**Questions flagged** (a question in pairs of two kinds is counted in both columns):',
    '',
    '| Topic | Questions | Flagged | Same words | Near-duplicate | Inside a set | Across sets | Written sentence / correction / fill in the blank |',
    '|---|---|---|---|---|---|---|---|',
  );
  const summaries = topics.map((t) => duplicateSummary(t.topic.id, data.items, pairs));
  topics.forEach((t, i) => {
    const s = summaries[i] as DuplicateSummary;
    push(`| ${label(t)} | ${s.questions} | ${rate(s.flagged, s.questions)} | ${s.sameWords} | ${s.nearDuplicate} | ${s.inSet} | ${s.acrossSets} | ${s.byType.sentence_writing} / ${s.byType.error_correction} / ${s.byType.fill_in_blank} |`);
  });
  push('', '**Pairs:**', '', '| Topic | Pairs | Same words, inside a set | Same words, across sets | Near-duplicate, inside a set | Near-duplicate, across sets |', '|---|---|---|---|---|---|');
  topics.forEach((t, i) => {
    const p = (summaries[i] as DuplicateSummary).pairs;
    push(`| ${label(t)} | ${p.sameInSet + p.sameAcrossSets + p.nearInSet + p.nearAcrossSets} | ${p.sameInSet} | ${p.sameAcrossSets} | ${p.nearInSet} | ${p.nearAcrossSets} |`);
  });
  push(
    '',
    '**Groups** (questions joined by a chain of resembling pairs are one group):',
    '',
    '| Topic | Groups | Sizes, largest first | Questions in a group | Sets the largest group reaches into |',
    '|---|---|---|---|---|',
  );
  topics.forEach((t, i) => {
    const s = summaries[i] as DuplicateSummary;
    push(`| ${label(t)} | ${s.groupSizes.length} | ${s.groupSizes.length === 0 ? '–' : s.groupSizes.join(', ')} | ${s.groupSizes.reduce((a, b) => a + b, 0)} of ${s.questions} | ${s.groupSizes.length === 0 ? '–' : `${s.largestGroupSets} of ${t.sets}`} |`);
  });
  const checkFlagged = (id: string) => checksOf(id).filter((r) => r.flags.some((f) => f.check === 'duplicate')).length;
  const mismatch = topics.filter((t, i) => checkFlagged(t.topic.id) !== (summaries[i] as DuplicateSummary).flagged);
  push(
    '',
    mismatch.length === 0
      ? 'These counts are recomputed from the run\'s questions and agree with the flags the run recorded (`checks.json`).'
      : `**These counts differ from the flags the run recorded for: ${mismatch.map(label).join(', ')}.** The duplicate rule changed after the run.`,
    '',
    'The resembling questions themselves, side by side, are in the details file in the run folder; it is not to be opened before the sheet is labelled.',
    '',
    '### What makes two Topic Practice sets of one topic differ on the live path today',
    '',
    '**Nothing but the model\'s own sampling.** From the code, unchanged by this work:',
    '',
    '- **The app** (`lib/services/claude_service.dart`, `generatePracticeSet`, called from `lib/screens/practice_launch.dart`) sends three fields: `deviceId`, `topicId`, `count`. Nothing about earlier questions, no seed, no list to avoid.',
    '- **The Worker** (`proxy/src/validation.ts`, `validateGeneratePracticeSet`) refuses any other field, uses `deviceId` for the daily quota only, and builds the request to the model from the topic\'s fixed title and description and the count (`proxy/src/anthropic.ts`, `buildGeneratePracticeSetBodyFor`): the system prompt, then "Topic: … / Generate exactly N fresh practice items: …". No seed, no temperature, no earlier question, no list to avoid, nothing about the user.',
    '- So two requests for the same topic and length are **the same request, byte for byte**, whoever sends them and whenever. The word "fresh" in the prompt has nothing to be fresh against.',
    '- The measurement mirrors this: the six sets of a topic are six identical requests, so the resemblance across sets above is what two sessions of one learner, or two learners, would see.',
    '- For contrast, the shared Daily Test does have such inputs: the day\'s plan (a scenario theme, a type per topic) and a list of the answers of recent days to stay away from (`sharedDailyTestUserPrompt`).',
    '',
    phaseC
      ? 'What could be done about it is in the set-variety proposal ([`1.5.0-topics-set-variety.md`](1.5.0-topics-set-variety.md)); the owner decides, and this report changes nothing.'
      : 'Whether the resemblance is a defect, and what to do about it, is the owner\'s decision after the labels; this report changes nothing.',
  );

  push(
    '',
    phaseC ? '## § The scorer on the built answers, by construction (as before the labels)' : '## § The scorer on the built answers',
    '',
    ...(phaseC ? ['Kept for the record: these are the figures before the labels, with the truth as it was built. The figures that count are in "The scorer against the labelled truth" above.', ''] : []),
    'Agreement: the scorer\'s `isCorrect`, as the app would receive it, equals the truth by construction. False "correct": answers built as wrong that the scorer called correct. False "needs work": answers built as right that the scorer called wrong. See the limitations: a disagreement here is the scorer\'s error, or a built answer whose truth is wrong; the labels decide which.',
    '',
    '| Topic | Built answers | Scored | Agreement | False "correct" (of wrong) | False "needs work" (of right) |',
    '|---|---|---|---|---|---|',
    ...topics.map((t) => metricsRow(label(t), scoringMetrics(answersOf(t.topic.id), scored.verdicts))),
    metricsRow('**The five new topics**', allNew),
    '',
    '**By kind of built answer:**',
    '',
    '| Kind | Group | Built answers | Scored | Agreement | False "correct" (of wrong) | False "needs work" (of right) |',
    '|---|---|---|---|---|---|---|',
  );
  for (const kind of ['key', 'second answer', 'mistake']) {
    for (const [group, answers] of [['new topics', newAnswers], ['control', controlAnswers]] as const) {
      push(metricsRow(`${kind} | ${group}`, scoringMetrics(answers.filter((a) => KIND_LABEL[a.kind] === kind), scored.verdicts)));
    }
  }
  push('', '**By question type:**', '', '| Type | Group | Built answers | Scored | Agreement | False "correct" (of wrong) | False "needs work" (of right) |', '|---|---|---|---|---|---|---|');
  for (const type of ['sentence_writing', 'error_correction', 'fill_in_blank'] as const) {
    for (const [group, answers] of [['new topics', newAnswers], ['control', controlAnswers]] as const) {
      push(metricsRow(`${TYPE_LABEL[type]} | ${group}`, scoringMetrics(answers.filter((a) => a.item.type === type), scored.verdicts)));
    }
  }
  push(
    '',
    `${scored.calls} scoring calls read; ${scored.notScored.length} built answers have no verdict. The proxy's own repair of a scoring response (\`checkScoreFeedback\`) was applied first, as on the route: it set \`isCorrect\` to the per-blank verdicts on ${scored.verdictReconciled} answers and removed malformed structured fields on ${scored.structuredDropped}.`,
    '',
    (() => {
      const differ = data.answers.filter((a) => scored.verdicts.has(a.id) && scored.verdicts.get(a.id)?.isCorrect !== a.truth);
      const n = (kind: string, group: readonly TopicAnswer[]) => group.filter((a) => KIND_LABEL[a.kind] === kind && differ.includes(a)).length;
      return `Where the ${differ.length} disagreements are: in the new topics ${n('key', newAnswers)} on keys, ${n('second answer', newAnswers)} on second answers and ${n('mistake', newAnswers)} on mistakes; in the control ${n('key', controlAnswers)}, ${n('second answer', controlAnswers)} and ${n('mistake', controlAnswers)}. A second answer and a mistake are the built answers whose truth is least sure (is the second answer really right here, is the mistake really wrong), so these are the rows the labels matter most for; the details file lists each with the scorer's explanation.`;
    })(),
    '',
    'For scale: in the 1.4.0 measurement the same cell agreed with the owner\'s labels on 97.8 % of 370 answers, with no false "correct" and 3.9 % false "needs work". Those answers had labelled truth and the five live topics; the figures above have neither yet.',
  );

  push('', '## § Spend and time per topic', '', '| Topic | Calls | Spend | Generation | Answers | Scoring | Seconds of calls, summed |', '|---|---|---|---|---|---|---|');
  for (const t of topics) {
    const mine = data.records.filter((r) => recordTopic.get(r.customId) === t.topic.id);
    const cost = (stage: string) => usd(mine.filter((r) => r.stage === stage).reduce((n, r) => n + r.costUsd, 0));
    push(`| ${label(t)} | ${mine.length} | ${usd(mine.reduce((n, r) => n + r.costUsd, 0))} | ${cost('generation')} | ${cost('answers')} | ${cost('scoring')} | ${Math.round(mine.reduce((n, r) => n + (r.durationMs ?? 0), 0) / 1000)} |`);
  }
  const perSet = stages.find((s) => s.stage === 'generation');
  const perScore = stages.find((s) => s.stage === 'scoring');
  if (perSet && perScore && perSet.ok > 0 && perScore.ok > 0) {
    push(
      '',
      `Per call, measured: a generated set ${`$${(perSet.costUsd / perSet.ok).toFixed(4)}`} and ${perSet.meanSeconds.toFixed(1)} s; a scoring call ${`$${(perScore.costUsd / perScore.ok).toFixed(4)}`} and ${perScore.meanSeconds.toFixed(1)} s. The calls ran five at a time, so the summed seconds are more than the run's wall time.`,
    );
  }

  push(
    '',
    '## § The label sheet',
    '',
    `All ${meta.sheet.questions} questions and their ${meta.sheet.answers} built answers are on a blind sheet in the run folder (not in the repository): the questions in mixed order under opaque keys, each with its built answers under letters in a shuffled order. It shows what a learner sees and the built answers, nothing else.`,
    '',
    '| File (in the run folder) | What | Who opens it |',
    '|---|---|---|',
    '| `sheet/questions.txt` | to read: the hint cards, then every question with its built answers | the labellers |',
    '| `sheet/labels.csv` | to fill: one row per question | the labellers |',
    `| \`private/sheet-mapping.json\` | which question and which built answer each key and letter is | ${phaseC ? 'open now that the sheet is filled' : '**nobody, until the sheet is filled**'} |`,
    `| \`private/details.txt\` | per question the flags, the gate, the scorer\'s verdicts and explanations; the resembling questions side by side | ${phaseC ? 'open now that the sheet is filled' : '**nobody, until the sheet is filled**'} |`,
    ...(phaseC ? ['| `second-look.md` | every answer where the scorer and the labelled truth differ, and the defect questions | the owner |'] : []),
    '',
    phaseC ? 'The sheet is filled, so the run\'s own files (`items.json`, `answers.json`, `checks.json`, `records.json`, …) may be opened as well.' : 'The run\'s own files (`items.json`, `answers.json`, `checks.json`, `records.json`, …) give the same away and stay closed as well.',
    '',
    `State of the sheet when this report was written: ${meta.sheet.labelled} of ${meta.sheet.questions} rows labelled${meta.sheet.withProblems > 0 ? `; ${meta.sheet.withProblems} rows with a value to fix (\`topics analyze\` names them)` : ''}.`,
    '',
    '## § What comes next',
    '',
    ...(phaseC
      ? phaseC.next
      : [
          'Phase C, after the labels: per topic the defect rate with the defects by reason, the scoring figures against the labelled truth of the built answers, and a second-look file with every answer where the scorer and the labelled truth differ. The owner\'s pass criteria per topic: at most 5 % defective questions after the gate, scoring agreement at least 95 %, false "correct" at most 2 %. Nothing in this report says whether a topic passes.',
        ]),
    '',
  );
  let section = 0;
  return out.join('\n').replace(/^## § /gm, () => `## ${section++}. `);
}

/**
 * Texts of the run that appear in [text]: a question's context or
 * instruction, a built answer, or a sheet key. Only texts of 20 characters
 * or more are looked for (a one-word answer such as "at" is in any English
 * text). The report must give an empty list.
 */
export function contentLeaks(text: string, items: readonly TopicItem[], answers: readonly TopicAnswer[], sheetKeys: readonly string[] = []): string[] {
  const leaks: string[] = [];
  const look = (what: string, value: string | undefined) => {
    const v = value?.trim() ?? '';
    if (v.length >= 20 && text.includes(v)) leaks.push(what);
  };
  for (const item of items) {
    look(`${item.id} context`, item.context);
    look(`${item.id} instruction`, item.instruction);
    look(`${item.id} hint`, item.hint);
  }
  for (const a of answers) look(`answer ${a.id}`, a.userAnswer);
  for (const key of sheetKeys) if (text.includes(key)) leaks.push(`sheet key ${key}`);
  return leaks;
}
