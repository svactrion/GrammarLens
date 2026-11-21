import { topicById } from '../../src/topics';
import { rate, type AnswerVerdict, type PhaseCParts, type TopicsRunData } from './topics_analysis';
import { CHECK_IDS, gateProblems, type CheckId, type ItemCheckRecord } from './topics_checks';
import { measuredTopics, type TopicAnswer, type TopicItem } from './topics_measurement';
import { TYPE_NAMES, type AnswerLabel, type QuestionLabel, type SheetMapping } from './topics_sheet';

/**
 * Phase C of the 1.5.0 first-wave topics measurement (docs/TOPICS.md): the
 * filled label sheet folded into the report, the owner's pass criteria per
 * topic, and the second-look file. Pure: `eval/run.ts topics analyze` reads
 * the sheet and writes the files. No API call anywhere.
 *
 * The report parts hold counts and rates only; the second-look file holds
 * questions and answers and goes into the run folder, never the repository.
 */

/** The owner's pass criteria per topic (docs/TOPICS.md, phase C). */
export const PASS_CRITERIA = { maxDefectPercent: 5, minAgreementPercent: 95, maxFalseCorrectPercent: 2 } as const;

/**
 * The markers a label's note carries (owner decision T-23): `multi:` for a
 * question with more than one right answer, which is not a defect for that
 * reason, and `minor:` for a lesser blemish. A marker counts at the start of
 * the note or of a later sentence in it ("minor: … . multi: …").
 */
export function noteMarks(note: string): { multi: boolean; minor: boolean } {
  const has = (marker: string) => new RegExp(`(?:^|[.;]\\s+)${marker}:`, 'i').test(note.trim());
  return { multi: has('multi'), minor: has('minor') };
}

const title = (topicId: string) => topicById(topicId, true)?.title ?? topicId;

// ---------------------------------------------------------------------------
// The questions

export interface QuestionSummary {
  topicId: string;
  questions: number;
  /** Questions that failed the gate, counted apart, and how they were labelled. */
  gateFailed: number;
  gateFailedDefects: number;
  /** Questions that passed the gate and have a label: the rate's base. */
  afterGate: number;
  /** Of those, labelled `defect`. */
  defects: number;
  /** The defects after the gate by `why` (a defect with two reasons is in both). */
  byWhy: Record<string, number>;
  /** Labelled questions (the gate aside) by the note's marker. */
  multi: number;
  minor: number;
  /** A note with neither marker, on a question that is not a defect. */
  otherNotes: number;
  /** Questions with at least one answer to accept that was not built. */
  alsoAccept: number;
  /** Questions without a complete label. */
  unlabelled: number;
}

export function questionSummary(topicId: string, items: readonly TopicItem[], labels: ReadonlyMap<string, QuestionLabel>): QuestionSummary {
  const s: QuestionSummary = { topicId, questions: 0, gateFailed: 0, gateFailedDefects: 0, afterGate: 0, defects: 0, byWhy: {}, multi: 0, minor: 0, otherNotes: 0, alsoAccept: 0, unlabelled: 0 };
  for (const item of items) {
    if (item.topicId !== topicId) continue;
    s.questions++;
    const label = labels.get(item.id);
    const failed = gateProblems(item).length > 0;
    if (failed) s.gateFailed++;
    if (!label) {
      s.unlabelled++;
      continue;
    }
    const marks = noteMarks(label.note);
    if (marks.multi) s.multi++;
    if (marks.minor) s.minor++;
    if (!marks.multi && !marks.minor && label.note !== '' && label.verdict !== 'defect') s.otherNotes++;
    if (label.alsoAccept.length > 0) s.alsoAccept++;
    if (failed) {
      if (label.verdict === 'defect') s.gateFailedDefects++;
      continue;
    }
    s.afterGate++;
    if (label.verdict === 'defect') {
      s.defects++;
      for (const why of label.why) s.byWhy[why] = (s.byWhy[why] ?? 0) + 1;
    }
  }
  return s;
}

// ---------------------------------------------------------------------------
// The scorer against the labelled truth

/** The label of every built answer, by the answer's id. */
export function labelledTruth(labels: Iterable<QuestionLabel>): Map<string, AnswerLabel> {
  const truth = new Map<string, AnswerLabel>();
  for (const label of labels) for (const [answerId, value] of label.answers) truth.set(answerId, value);
  return truth;
}

export interface LabelledMetrics {
  answers: number;
  /** Scored answers labelled right or wrong: the base of the agreement. */
  compared: number;
  agree: number;
  wrong: number;
  falseCorrect: number;
  right: number;
  falseNeedsWork: number;
  /** The split of the false "needs work": on the built key … */
  keysRight: number;
  falseNeedsWorkOnKey: number;
  /** … and on the other answers labelled right (second answers, and built
   * mistakes the labels call right). */
  othersRight: number;
  falseNeedsWorkOnOther: number;
  /** Across both: on the questions noted `multi:`. */
  multiRight: number;
  falseNeedsWorkOnMulti: number;
  /** Labelled `unsure`: in neither rate. What the scorer said is kept. */
  unsure: number;
  unsureCalledCorrect: number;
  /** No label, or no verdict from the scorer. */
  notCompared: number;
}

/**
 * Agreement, false "correct" and false "needs work" against the labelled
 * truth. `unsure` answers are counted apart and are in no rate. [multiItems]:
 * the ids of the questions noted `multi:`.
 */
export function labelledMetrics(
  answers: readonly TopicAnswer[],
  verdicts: ReadonlyMap<string, AnswerVerdict>,
  truth: ReadonlyMap<string, AnswerLabel>,
  multiItems: ReadonlySet<string> = new Set(),
): LabelledMetrics {
  const m: LabelledMetrics = {
    answers: answers.length,
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
  for (const a of answers) {
    const label = truth.get(a.id);
    const verdict = verdicts.get(a.id);
    if (label === 'unsure') {
      m.unsure++;
      if (verdict?.isCorrect) m.unsureCalledCorrect++;
      continue;
    }
    if (!label || !verdict) {
      m.notCompared++;
      continue;
    }
    m.compared++;
    if (verdict.isCorrect === (label === 'right')) m.agree++;
    if (label === 'wrong') {
      m.wrong++;
      if (verdict.isCorrect) m.falseCorrect++;
      continue;
    }
    m.right++;
    const missed = !verdict.isCorrect;
    if (missed) m.falseNeedsWork++;
    if (a.kind === 'key') {
      m.keysRight++;
      if (missed) m.falseNeedsWorkOnKey++;
    } else {
      m.othersRight++;
      if (missed) m.falseNeedsWorkOnOther++;
    }
    if (multiItems.has(a.itemId)) {
      m.multiRight++;
      if (missed) m.falseNeedsWorkOnMulti++;
    }
  }
  return m;
}

/** Where the labelled truth is not the truth the answer was built with. */
export interface TruthVsConstruction {
  mistakesLabelledRight: number;
  keysLabelledWrong: number;
  secondAnswersLabelledWrong: number;
  unsure: { key: number; secondAnswer: number; mistake: number };
}

export function truthVsConstruction(answers: readonly TopicAnswer[], truth: ReadonlyMap<string, AnswerLabel>): TruthVsConstruction {
  const t: TruthVsConstruction = { mistakesLabelledRight: 0, keysLabelledWrong: 0, secondAnswersLabelledWrong: 0, unsure: { key: 0, secondAnswer: 0, mistake: 0 } };
  for (const a of answers) {
    const label = truth.get(a.id);
    const kind = a.kind === 'key' ? 'key' : a.kind === 'variant' ? 'secondAnswer' : 'mistake';
    if (label === 'unsure') t.unsure[kind]++;
    else if (label === 'right' && !a.truth) t.mistakesLabelledRight++;
    else if (label === 'wrong' && a.kind === 'key') t.keysLabelledWrong++;
    else if (label === 'wrong' && a.kind === 'variant') t.secondAnswersLabelledWrong++;
  }
  return t;
}

// ---------------------------------------------------------------------------
// The pass criteria

export interface Criterion {
  n: number;
  of: number;
  /** Null when there is nothing to divide by. */
  pass: boolean | null;
}

export interface TopicCriteria {
  /** At most 5 % defective questions after the gate. */
  defects: Criterion;
  /** Scoring agreement at least 95 %. */
  agreement: Criterion;
  /** False "correct" at most 2 % of the wrong answers. */
  falseCorrect: Criterion;
  /** All three pass; null when one of them could not be computed. */
  pass: boolean | null;
}

/** In whole numbers, so a rate on the line is never decided by rounding. */
export function passCriteria(q: Pick<QuestionSummary, 'defects' | 'afterGate'>, m: Pick<LabelledMetrics, 'agree' | 'compared' | 'falseCorrect' | 'wrong'>): TopicCriteria {
  const defects = { n: q.defects, of: q.afterGate, pass: q.afterGate === 0 ? null : q.defects * 100 <= PASS_CRITERIA.maxDefectPercent * q.afterGate };
  const agreement = { n: m.agree, of: m.compared, pass: m.compared === 0 ? null : m.agree * 100 >= PASS_CRITERIA.minAgreementPercent * m.compared };
  const falseCorrect = { n: m.falseCorrect, of: m.wrong, pass: m.wrong === 0 ? null : m.falseCorrect * 100 <= PASS_CRITERIA.maxFalseCorrectPercent * m.wrong };
  const all = [defects.pass, agreement.pass, falseCorrect.pass];
  return { defects, agreement, falseCorrect, pass: all.includes(null) ? null : all.every((p) => p === true) };
}

// ---------------------------------------------------------------------------
// What the automatic checks were worth

export interface FlagWorth {
  /** Questions the check flagged (or the gate failed). */
  flagged: number;
  defect: number;
  multi: number;
  minor: number;
  /** Flagged, and labelled ok with neither marker. */
  neither: number;
}

function worth(items: readonly string[], labels: ReadonlyMap<string, QuestionLabel>): FlagWorth {
  const w: FlagWorth = { flagged: items.length, defect: 0, multi: 0, minor: 0, neither: 0 };
  for (const id of items) {
    const label = labels.get(id);
    const marks = noteMarks(label?.note ?? '');
    if (label?.verdict === 'defect') w.defect++;
    if (marks.multi) w.multi++;
    if (marks.minor) w.minor++;
    if (label?.verdict !== 'defect' && !marks.multi && !marks.minor) w.neither++;
  }
  return w;
}

export interface ChecksWorth {
  questions: number;
  defects: number;
  multi: number;
  gate: FlagWorth;
  byCheck: Record<CheckId, FlagWorth>;
  /** Passed the gate and no check flagged it. */
  clean: FlagWorth;
  /** Defects the gate caught; defects it did not catch that some check
   * other than the duplicate check flagged; defects nothing pointed at. */
  defectsCaughtByGate: number;
  defectsFlagged: number;
  defectsUnflagged: number;
  /** The `multi:` questions the one-answer check flagged. */
  multiFlaggedByOneAnswer: number;
}

/** How the gate's and the checks' flags relate to the labels. The duplicate
 * check is about a set, not about one question, so it is not counted as
 * pointing at a defect. */
export function checksWorth(checks: readonly ItemCheckRecord[], labels: ReadonlyMap<string, QuestionLabel>): ChecksWorth {
  const flaggedBy = (check: CheckId) => checks.filter((c) => c.flags.some((f) => f.check === check)).map((c) => c.itemId);
  const byCheck = Object.fromEntries(CHECK_IDS.map((check) => [check, worth(flaggedBy(check), labels)])) as Record<CheckId, FlagWorth>;
  const gateFailed = checks.filter((c) => c.gate.length > 0).map((c) => c.itemId);
  const defects = checks.filter((c) => labels.get(c.itemId)?.verdict === 'defect');
  const pointedAt = (c: ItemCheckRecord) => c.flags.some((f) => f.check !== 'duplicate');
  const multi = checks.filter((c) => noteMarks(labels.get(c.itemId)?.note ?? '').multi);
  return {
    questions: checks.length,
    defects: defects.length,
    multi: multi.length,
    gate: worth(gateFailed, labels),
    byCheck,
    clean: worth(checks.filter((c) => c.gate.length === 0 && c.flags.length === 0).map((c) => c.itemId), labels),
    defectsCaughtByGate: defects.filter((c) => c.gate.length > 0).length,
    defectsFlagged: defects.filter((c) => c.gate.length === 0 && pointedAt(c)).length,
    defectsUnflagged: defects.filter((c) => c.gate.length === 0 && !pointedAt(c)).length,
    multiFlaggedByOneAnswer: multi.filter((c) => c.flags.some((f) => f.check === 'single_answer')).length,
  };
}

// ---------------------------------------------------------------------------
// The report's phase C parts

export interface PhaseCInput {
  data: TopicsRunData;
  labels: readonly QuestionLabel[];
  verdicts: ReadonlyMap<string, AnswerVerdict>;
  /** The hand-written findings (causes, proposed fixes), as Markdown that
   * starts below a heading; null when there are none yet. */
  findings: string | null;
}

const CHECK_NAMES: Readonly<Record<CheckId, string>> = { topic: 'About its topic', single_answer: 'One natural answer', duplicate: 'Duplicates', length_level: 'Length and level', hint_card: 'Hint card against the key' };

function criterionCell(c: Criterion): string {
  return c.pass === null ? '–' : `${rate(c.n, c.of)}: **${c.pass ? 'pass' : 'FAIL'}**`;
}

/** Everything phase C adds to the report: counts and rates only. */
export function phaseCParts(input: PhaseCInput): PhaseCParts {
  const { data, verdicts } = input;
  const topics = measuredTopics();
  const label = (t: (typeof topics)[number]) => `${t.topic.title}${t.control ? ' (control)' : ''}`;
  const labels = new Map(input.labels.map((l) => [l.itemId, l]));
  const truth = labelledTruth(input.labels);
  const multiItems = new Set(input.labels.filter((l) => noteMarks(l.note).multi).map((l) => l.itemId));
  const newIds = new Set(topics.filter((t) => !t.control).map((t) => t.topic.id));
  const answersOf = (id: string) => data.answers.filter((a) => a.topicId === id);
  const newAnswers = data.answers.filter((a) => newIds.has(a.topicId));
  const questions = new Map(topics.map((t) => [t.topic.id, questionSummary(t.topic.id, data.items, labels)]));
  const metrics = new Map(topics.map((t) => [t.topic.id, labelledMetrics(answersOf(t.topic.id), verdicts, truth, multiItems)]));
  const q = (id: string) => questions.get(id) as QuestionSummary;
  const m = (id: string) => metrics.get(id) as LabelledMetrics;
  const allNew = labelledMetrics(newAnswers, verdicts, truth, multiItems);
  const sum = (pick: (s: QuestionSummary) => number, ids: Iterable<string>) => [...ids].reduce((n, id) => n + pick(q(id)), 0);
  const out: string[] = [];
  const push = (...lines: string[]) => out.push(...lines);

  // 1. The pass criteria.
  push(
    '## § The pass criteria, per topic',
    '',
    `The owner's criteria for a new topic: at most ${PASS_CRITERIA.maxDefectPercent} % defective questions after the gate, scoring agreement at least ${PASS_CRITERIA.minAgreementPercent} %, false "correct" at most ${PASS_CRITERIA.maxFalseCorrectPercent} %. Each cell gives the rate, the counts behind it, and pass or fail. A question with more than one right answer is not a defect for that reason (owner decision, T-23).`,
    '',
    '| Topic | Defective questions after the gate (at most 5 %) | Scoring agreement (at least 95 %) | False "correct", of wrong answers (at most 2 %) | All three |',
    '|---|---|---|---|---|',
  );
  for (const t of topics) {
    const c = passCriteria(q(t.topic.id), m(t.topic.id));
    const all = c.pass === null ? '–' : c.pass ? '**passes**' : '**fails**';
    push(`| ${label(t)} | ${criterionCell(c.defects)} | ${criterionCell(c.agreement)} | ${criterionCell(c.falseCorrect)} | ${t.control ? `${all} (for reference)` : all} |`);
  }
  const passing = topics.filter((t) => !t.control && passCriteria(q(t.topic.id), m(t.topic.id)).pass === true);
  const failing = topics.filter((t) => !t.control && passCriteria(q(t.topic.id), m(t.topic.id)).pass === false);
  push(
    '',
    `Of the five new topics, ${passing.length} pass all three criteria${passing.length > 0 ? ` (${passing.map((t) => t.topic.title).join(', ')})` : ''} and ${failing.length} fail${failing.length > 0 ? ` (${failing.map((t) => t.topic.title).join(', ')})` : ''}. The control is a live topic measured the same way: its row is for comparison, not a decision.`,
    '',
    `The agreement and the false "correct" are against the labelled truth; an answer labelled \`unsure\` is in neither. A question that failed the gate is not in the defect rate: the gate would have to exist on the live path to keep it from a learner, and today it does not (T-4). Counted with them, the defect rates are: ${topics.map((t) => `${t.topic.title} ${rate(q(t.topic.id).defects + q(t.topic.id).gateFailedDefects, q(t.topic.id).afterGate + q(t.topic.id).gateFailed)}`).join('; ')}.`,
  );

  // 2. The questions.
  push(
    '',
    '## § The questions: defects and notes',
    '',
    '| Topic | Questions | Failed the gate (labelled defect) | Labelled, after the gate | Defects after the gate | Defects by `why` | Noted `multi:` | Noted `minor:` | Another note | Answers to accept given |',
    '|---|---|---|---|---|---|---|---|---|---|',
  );
  for (const t of topics) {
    const s = q(t.topic.id);
    const why = Object.entries(s.byWhy).map(([w, n]) => `\`${w}\` × ${n}`).join(', ') || '–';
    push(`| ${label(t)} | ${s.questions} | ${s.gateFailed} (${s.gateFailedDefects}) | ${s.afterGate} | ${rate(s.defects, s.afterGate)} | ${why} | ${s.multi} | ${s.minor} | ${s.otherNotes} | ${s.alsoAccept} |`);
  }
  const ids = topics.map((t) => t.topic.id);
  push(
    `| **All** | ${sum((s) => s.questions, ids)} | ${sum((s) => s.gateFailed, ids)} (${sum((s) => s.gateFailedDefects, ids)}) | ${sum((s) => s.afterGate, ids)} | ${rate(sum((s) => s.defects, ids), sum((s) => s.afterGate, ids))} | | ${sum((s) => s.multi, ids)} | ${sum((s) => s.minor, ids)} | ${sum((s) => s.otherNotes, ids)} | ${sum((s) => s.alsoAccept, ids)} |`,
    '',
    '- **Defect:** the question contradicts itself, teaches something false or cannot be answered.',
    '- **`multi:`** more than one answer is right. Not a defect: the scorer is a model and matches no key. The risk moves to the scorer, which the next section shows.',
    '- **`minor:`** a lesser blemish; the question stays usable.',
    '- **Another note:** a remark on a single built answer (for example why a written "mistake" is in fact acceptable), on a question labelled ok.',
    '- A marker counts at the start of a note or of a later sentence in it; a question can carry both.',
  );
  const unlabelled = sum((s) => s.unlabelled, ids);
  if (unlabelled > 0) push('', `**${unlabelled} questions have no complete label and are in no figure of this report.**`);

  // 3. The scorer against the labelled truth.
  const metricsRow = (name: string, x: LabelledMetrics) =>
    `| ${name} | ${x.answers} | ${x.right} / ${x.wrong} / ${x.unsure} | ${rate(x.agree, x.compared)} | ${rate(x.falseCorrect, x.wrong)} | ${rate(x.falseNeedsWork, x.right)} |`;
  const splitRow = (name: string, x: LabelledMetrics) =>
    `| ${name} | ${rate(x.falseNeedsWork, x.right)} | ${rate(x.falseNeedsWorkOnKey, x.keysRight)} | ${rate(x.falseNeedsWorkOnOther, x.othersRight)} | ${rate(x.falseNeedsWorkOnMulti, x.multiRight)} | ${rate(x.falseNeedsWork - x.falseNeedsWorkOnMulti, x.right - x.multiRight)} |`;
  push(
    '',
    '## § The scorer against the labelled truth',
    '',
    'Agreement: the scorer\'s `isCorrect`, as the app would receive it, equals the label. False "correct": answers labelled wrong that the scorer called correct. False "needs work": answers labelled right that the scorer called wrong.',
    '',
    '| Topic | Built answers | Labelled right / wrong / unsure | Agreement | False "correct" (of wrong) | False "needs work" (of right) |',
    '|---|---|---|---|---|---|',
    ...topics.map((t) => metricsRow(label(t), m(t.topic.id))),
    metricsRow('**The five new topics**', allNew),
    '',
    '**The false "needs work", split.** A right answer called "needs work" is what a learner who gave a good alternative would see. The first two columns divide the right answers by how they were built; the last two divide the same answers by whether their question is noted `multi:`.',
    '',
    '| Topic | False "needs work" (of right) | On the built key | On the other answers labelled right | On questions noted `multi:` | On the other questions |',
    '|---|---|---|---|---|---|',
    ...topics.map((t) => splitRow(label(t), m(t.topic.id))),
    splitRow('**The five new topics**', allNew),
    '',
    `"The other answers labelled right" are the second answers the labels confirm and the written mistakes the labels call right. \`unsure\`: ${allNew.unsure} answers in the new topics and ${topics.filter((t) => t.control).reduce((n, t) => n + m(t.topic.id).unsure, 0)} in the control, in neither rate; the scorer called ${allNew.unsureCalledCorrect + topics.filter((t) => t.control).reduce((n, t) => n + m(t.topic.id).unsureCalledCorrect, 0)} of them correct.${allNew.notCompared > 0 ? ` ${allNew.notCompared} answers of the new topics have no label or no verdict and are left out.` : ''}`,
    '',
    'For scale: in the 1.4.0 measurement the same scoring cell agreed with the labels on 97.8 % of 370 answers of the five live topics, with no false "correct" and 3.9 % false "needs work".',
  );

  // 4. Truth against construction.
  push(
    '',
    '## § Where the labelled truth differs from the construction',
    '',
    'The answers were written to be right (the key, the second answer) or wrong (the mistakes). The labels do not always agree, which is why they were asked for (T-13).',
    '',
    '| Topic | Built mistakes labelled right | Built keys labelled wrong | Built second answers labelled wrong | Labelled unsure (key / second answer / mistake) | Agreement by construction | Agreement by the labels |',
    '|---|---|---|---|---|---|---|',
  );
  const constructionAgreement = (answers: readonly TopicAnswer[]) => {
    const scored = answers.filter((a) => verdicts.has(a.id));
    return rate(scored.filter((a) => verdicts.get(a.id)?.isCorrect === a.truth).length, scored.length);
  };
  const tvcRow = (name: string, answers: readonly TopicAnswer[], x: LabelledMetrics) => {
    const t = truthVsConstruction(answers, truth);
    return `| ${name} | ${t.mistakesLabelledRight} | ${t.keysLabelledWrong} | ${t.secondAnswersLabelledWrong} | ${t.unsure.key} / ${t.unsure.secondAnswer} / ${t.unsure.mistake} | ${constructionAgreement(answers)} | ${rate(x.agree, x.compared)} |`;
  };
  push(...topics.map((t) => tvcRow(label(t), answersOf(t.topic.id), m(t.topic.id))), tvcRow('**The five new topics**', newAnswers, allNew));

  // 5. What the checks were worth.
  const w = checksWorth(data.checks, labels);
  const worthRow = (name: string, x: FlagWorth) => `| ${name} | ${x.flagged} | ${x.defect} | ${x.multi} | ${x.minor} | ${x.neither} |`;
  push(
    '',
    '## § What the automatic checks were worth',
    '',
    `Over all ${w.questions} questions: how the questions a check flagged were labelled. ${w.defects} questions are labelled defect and ${w.multi} are noted \`multi:\`.`,
    '',
    '| | Questions | Labelled defect | Noted `multi:` | Noted `minor:` | Ok, no marker |',
    '|---|---|---|---|---|---|',
    worthRow('Failed the gate', w.gate),
    ...CHECK_IDS.map((c) => worthRow(`Flag: ${CHECK_NAMES[c]}`, w.byCheck[c])),
    worthRow('Passed the gate, no flag at all', w.clean),
    '',
    `- **The defects.** Of the ${w.defects}: the gate caught ${w.defectsCaughtByGate}; of the ${w.defects - w.defectsCaughtByGate} that passed the gate, a check other than the duplicate check flagged ${w.defectsFlagged} and nothing pointed at ${w.defectsUnflagged}.`,
    `- **More than one right answer.** The one-answer check flagged ${w.byCheck.single_answer.flagged} questions, ${w.byCheck.single_answer.multi} of them noted \`multi:\`; of the ${w.multi} questions noted \`multi:\` it flagged ${w.multiFlaggedByOneAnswer}. It looks at fill-in-the-blank questions only.`,
    `- **Duplicates.** A resembling question elsewhere is a property of the sets, not of the question: the labels judge each question alone, so this row says nothing about the check. Its findings are in the duplicates section below.`,
    '- **Reading the table.** A check is worth something when its flagged rows are labelled defect or carry a marker more often than the rest. With this few defects the table can show that a check missed them, not that it would find them.',
  );

  // 6. Findings and proposals (hand-written, from the repository).
  push('', '## § Findings and proposals', '', input.findings?.trim() ?? '_Not written yet._');

  return {
    status: 'measured and labelled (phase C of [`TOPICS.md`](TOPICS.md)).',
    limitations: [
      '- **The answers are built, not real learners\'.** A practice question carries no answer key, so a model wrote, for every question, a key, a second correct answer where it found one, and typical learner mistakes (decision T-2). Real learners make other mistakes, and more varied ones.',
      '- **The labels were written by Claude in the owner\'s Cowork session and checked by the owner**, on a blind sheet (T-14). The labeller and the measured models are of one model family, as in the 1.4.0 measurement.',
      '- **Small numbers.** 30 questions per new topic and 15 for the control: one question is 3.3 % of a topic, one of the control\'s 6.7 %. With 30 questions a topic passes the defect criterion with one defect and fails with two; a rate measured on 30 leaves a wide range open for the true rate.',
      '- **One run.** Six sets per topic from one day; the scorer was run once on each answer.',
      '- **The automatic checks are flags, not verdicts.** What they were worth against the labels is in its own section.',
      '- This report holds counts and rates only: no question, no answer and no sheet key. The questions behind a figure are in the run folder, outside the repository (the second-look file and the details file).',
    ],
    sections: out,
    next: [
      'Phase C ends here. The decisions are the owner\'s: which topics go on to release prep (phase D, only on his go), whether a failing topic gets its proposed fix and a re-measurement of that topic alone (new spend, the same cap rules), and which set-variety option, if any, is built ([`1.5.0-topics-set-variety.md`](1.5.0-topics-set-variety.md)). Nothing is deployed and the first-wave topics stay switched off.',
    ],
  };
}

// ---------------------------------------------------------------------------
// The second-look file (run folder only)

export interface SecondLookInput {
  data: TopicsRunData;
  labels: readonly QuestionLabel[];
  verdicts: ReadonlyMap<string, AnswerVerdict>;
  /** The scoring prompt candidate's verdicts, when the run scored every
   * answer twice: each entry then shows both. */
  candidate?: ReadonlyMap<string, AnswerVerdict>;
  mapping: SheetMapping;
  runDir: string;
}

/** Text that is safe in a Markdown paragraph: a run of underscores (a
 * blank) and the other marks stay what they are. */
function md(text: string): string {
  return text.replace(/\r?\n/g, ' ').replace(/([\\`*_|<>])/g, '\\$1');
}

const KIND_NAMES: Readonly<Record<TopicAnswer['kind'], string>> = { key: 'the key', variant: 'the second answer', mistake1: 'a mistake', mistake2: 'a mistake' };

/** The answers where the scorer and the labelled truth differ, in the run's order. */
export function scorerDisagreements(
  answers: readonly TopicAnswer[],
  verdicts: ReadonlyMap<string, AnswerVerdict>,
  truth: ReadonlyMap<string, AnswerLabel>,
): { falseNeedsWork: TopicAnswer[]; falseCorrect: TopicAnswer[]; unsure: TopicAnswer[] } {
  const scored = answers.filter((a) => verdicts.has(a.id));
  return {
    falseNeedsWork: scored.filter((a) => truth.get(a.id) === 'right' && verdicts.get(a.id)?.isCorrect === false),
    falseCorrect: scored.filter((a) => truth.get(a.id) === 'wrong' && verdicts.get(a.id)?.isCorrect === true),
    unsure: answers.filter((a) => truth.get(a.id) === 'unsure'),
  };
}

/**
 * The owner's second look (as 1.4.0's `second-look-C8.md`): every answer
 * where the scorer and the labelled truth differ, with the question, the
 * answer, the label's note and the scorer's verdict and explanation; the
 * answers labelled unsure; and the defect questions with what the gate and
 * the automatic checks said. Each entry ends with an empty "Owner:" line.
 */
export function renderTopicsSecondLook(input: SecondLookInput): string {
  const { data, verdicts } = input;
  const items = new Map(data.items.map((i) => [i.id, i]));
  const labels = new Map(input.labels.map((l) => [l.itemId, l]));
  const rows = new Map(input.mapping.rows.map((r) => [r.itemId, r]));
  const checks = new Map(data.checks.map((c) => [c.itemId, c]));
  const truth = labelledTruth(input.labels);
  const { falseNeedsWork, falseCorrect, unsure } = scorerDisagreements(data.answers, verdicts, truth);
  const defects = data.items.filter((i) => labels.get(i.id)?.verdict === 'defect');
  const letterOf = (a: TopicAnswer) => Object.entries(rows.get(a.itemId)?.letters ?? {}).find(([, id]) => id === a.id)?.[0] ?? '?';
  const question = (item: TopicItem): string[] => [
    '```text',
    ...(item.context === undefined ? [] : [item.context]),
    item.instruction,
    ...(item.hint === undefined ? [] : [`(hint: ${item.hint})`]),
    '```',
  ];
  const lineOf = (v: AnswerVerdict | undefined) => (v === undefined ? 'not scored' : `${v.isCorrect ? 'correct' : 'needs work'} — ${md(v.explanation)} *Corrected:* ${md(v.correctedAnswer)}`);
  const scorerLine = (a: TopicAnswer) => lineOf(verdicts.get(a.id));
  const candidateLines = (a: TopicAnswer) => (input.candidate ? [`- **Scorer, candidate prompt:** ${lineOf(input.candidate.get(a.id))}`] : []);
  const noteLine = (label: QuestionLabel | undefined) =>
    `- **Label's note on the question:** ${label?.note ? md(label.note) : '(none)'}${label && label.alsoAccept.length > 0 ? ` *Also accept:* ${label.alsoAccept.map(md).join(' · ')}` : ''}`;
  const answerEntry = (a: TopicAnswer): string[] => {
    const item = items.get(a.itemId) as TopicItem;
    const label = labels.get(a.itemId);
    const marks = noteMarks(label?.note ?? '');
    return [
      `### ${a.itemId}, answer ${letterOf(a)} (${title(a.topicId)}, ${TYPE_NAMES[item.type]}${marks.multi ? ', noted multi:' : ''})`,
      '',
      ...question(item),
      '',
      `- **Answer:** ${md(a.userAnswer)}`,
      `- **Built as:** ${KIND_NAMES[a.kind]}${a.breaks ? ` (breaks: ${md(a.breaks)})` : ''}`,
      `- **Labelled:** ${truth.get(a.id) ?? 'no label'}${label?.verdict === 'defect' ? ' (the question is labelled defect)' : ''}`,
      noteLine(label),
      `- **Scorer${input.candidate ? ', production prompt' : ''}:** ${scorerLine(a)}`,
      ...candidateLines(a),
      '- **Owner:**',
      '',
    ];
  };
  const out: string[] = [
    '# Second look: the scorer against the labelled truth, and the defect questions',
    '',
    `From \`${input.runDir}\`. No API call: the stored verdicts and explanations of the run, and the labels of \`sheet/labels.csv\`. This file holds questions and answers and stays in the run folder, outside the repository. The "Owner:" lines are for the owner's verdicts; once one is filled, \`topics analyze\` no longer rewrites this file.`,
    '',
    `## A. The scorer said "needs work" where the label says right (${falseNeedsWork.length})`,
    '',
    'What a learner with a good answer would have been told. "Built as a mistake" means the answer was written to be wrong and the labels call it right.',
    '',
    ...falseNeedsWork.flatMap(answerEntry),
    `## B. The scorer said "correct" where the label says wrong (${falseCorrect.length})`,
    '',
    ...falseCorrect.flatMap(answerEntry),
    `## C. Answers labelled unsure (${unsure.length}), in neither rate`,
    '',
    ...unsure.flatMap(answerEntry),
    `## D. The questions labelled defect (${defects.length})`,
    '',
  ];
  for (const item of defects) {
    const label = labels.get(item.id) as QuestionLabel;
    const check = checks.get(item.id);
    out.push(
      `### ${item.id} (${title(item.topicId)}, ${TYPE_NAMES[item.type]}; sheet key ${rows.get(item.id)?.key ?? '?'})`,
      '',
      ...question(item),
      '',
      `- **Labelled:** defect, \`${label.why.join('`, `')}\``,
      noteLine(label),
      `- **Gate:** ${check === undefined ? 'no record' : check.gate.length === 0 ? 'passed' : `failed: \`${check.gate.join('`, `')}\``}`,
      `- **Automatic checks:** ${check === undefined || check.flags.length === 0 ? 'no flag' : check.flags.map((f) => `\`${f.code}\` (${md(f.detail)})`).join('; ')}${check && check.notRun.length > 0 ? `; not run for want of a key: ${check.notRun.join(', ')}` : ''}`,
    );
    const mine = data.answers.filter((a) => a.itemId === item.id);
    if (mine.length === 0) out.push('- **Built answers:** none');
    for (const a of mine) out.push(`- **Answer ${letterOf(a)}** (built as ${KIND_NAMES[a.kind]}, labelled ${truth.get(a.id) ?? 'no label'}): ${md(a.userAnswer)} — scorer: ${scorerLine(a)}`);
    out.push('- **Owner:**', '');
  }
  return `${out.join('\n')}\n`;
}

/** Whether a second-look file has an owner's verdict in it: such a file is
 * never rewritten. */
export function secondLookHasVerdicts(text: string): boolean {
  return text.split(/\r?\n/).some((line) => /^- \*\*Owner:\*\*\s*\S/.test(line));
}

// ---------------------------------------------------------------------------
// The two scoring prompts, answer by answer (run folder only)

export interface ChangedVerdictsRun {
  name: string;
  items: readonly TopicItem[];
  answers: readonly TopicAnswer[];
  labels: readonly QuestionLabel[];
  production: ReadonlyMap<string, AnswerVerdict>;
  candidate: ReadonlyMap<string, AnswerVerdict>;
}

/** The answers the two prompts judged differently, by what the label says. */
export function changedVerdicts(run: ChangedVerdictsRun): { candidateRight: TopicAnswer[]; candidateWrong: TopicAnswer[]; unsure: TopicAnswer[] } {
  const truth = labelledTruth(run.labels);
  const changed = run.answers.filter((a) => run.production.has(a.id) && run.candidate.has(a.id) && run.production.get(a.id)?.isCorrect !== run.candidate.get(a.id)?.isCorrect);
  const right = (a: TopicAnswer) => run.candidate.get(a.id)?.isCorrect === (truth.get(a.id) === 'right');
  const decided = changed.filter((a) => truth.get(a.id) === 'right' || truth.get(a.id) === 'wrong');
  return { candidateRight: decided.filter(right), candidateWrong: decided.filter((a) => !right(a)), unsure: changed.filter((a) => !decided.includes(a)) };
}

/**
 * Every answer on which the production scoring prompt and the candidate
 * gave different verdicts, with the question, the answer, the label and
 * what each prompt said: what the owner reads to decide about the
 * candidate. Holds questions and answers: for a run folder, never the
 * repository.
 */
export function renderChangedVerdicts(runs: readonly ChangedVerdictsRun[], runDir: string): string {
  const out: string[] = [
    '# The two scoring prompts, answer by answer',
    '',
    `From \`${runDir}\`. No API call: the stored verdicts of the production scoring prompt and of the candidate on the same built answers, and the labels. Every answer the two prompts judged differently is here; an answer they judged alike is not. This file holds questions and answers and stays in the run folder, outside the repository.`,
    '',
  ];
  for (const run of runs) {
    const items = new Map(run.items.map((i) => [i.id, i]));
    const labels = new Map(run.labels.map((l) => [l.itemId, l]));
    const truth = labelledTruth(run.labels);
    const line = (v: AnswerVerdict | undefined) => (v === undefined ? 'not scored' : `${v.isCorrect ? 'correct' : 'needs work'} — ${md(v.explanation)} *Corrected:* ${md(v.correctedAnswer)}`);
    const entry = (a: TopicAnswer): string[] => {
      const item = items.get(a.itemId);
      const label = labels.get(a.itemId);
      return [
        `### ${a.itemId} (${title(a.topicId)}${item ? `, ${TYPE_NAMES[item.type]}` : ''})`,
        '',
        '```text',
        ...(item?.context === undefined ? [] : [item.context]),
        item?.instruction ?? '',
        '```',
        '',
        `- **Answer:** ${md(a.userAnswer)}`,
        `- **Built as:** ${KIND_NAMES[a.kind]}${a.breaks ? ` (breaks: ${md(a.breaks)})` : ''}`,
        `- **Labelled:** ${truth.get(a.id) ?? 'no label'}${label?.note ? `. Note on the question: ${md(label.note)}` : ''}`,
        `- **Production prompt:** ${line(run.production.get(a.id))}`,
        `- **Candidate prompt:** ${line(run.candidate.get(a.id))}`,
        '- **Owner:**',
        '',
      ];
    };
    const c = changedVerdicts(run);
    out.push(
      `## ${run.name}: the candidate is right by the label, the production prompt is not (${c.candidateRight.length})`,
      '',
      ...c.candidateRight.flatMap(entry),
      `## ${run.name}: the production prompt is right by the label, the candidate is not (${c.candidateWrong.length})`,
      '',
      ...c.candidateWrong.flatMap(entry),
      `## ${run.name}: the prompts differ on an answer labelled unsure (${c.unsure.length})`,
      '',
      ...c.unsure.flatMap(entry),
    );
  }
  return `${out.join('\n')}\n`;
}
