import { describe, expect, it } from 'vitest';
import type { MeasureRecord } from '../eval/lib/measurement';
import { contentLeaks, renderTopicsReport, scoredAnswers, type TopicsRunData } from '../eval/lib/topics_analysis';
import { checkItems, gateSet } from '../eval/lib/topics_checks';
import {
  PASS_CRITERIA,
  checksWorth,
  labelledMetrics,
  labelledTruth,
  noteMarks,
  passCriteria,
  phaseCParts,
  questionSummary,
  renderTopicsSecondLook,
  scorerDisagreements,
  secondLookHasVerdicts,
  truthVsConstruction,
} from '../eval/lib/topics_labels';
import { answersId, builtAnswersFrom, generationId, scoringCalls, type TopicAnswer } from '../eval/lib/topics_measurement';
import { LETTERS, buildTopicSheet, readTopicLabels, type AnswerLabel, type QuestionLabel } from '../eval/lib/topics_sheet';
import { parseCsv } from '../eval/lib/labels';

const FIX = 'Find the mistake and rewrite the full corrected sentence.';

/** A made-up run: one set of Conditionals (its last question has no blank)
 * and one of the control. */
function generated(topicId: string): unknown {
  const place = topicId === 'conditionals' ? 'harbour' : 'airport';
  return {
    items: [
      { id: 'sw1', type: 'sentence_writing', context: `You are telling a friend about the ${place} festival.`, instruction: 'Write one sentence with "if".' },
      { id: 'sw2', type: 'sentence_writing', context: `You are planning a visit to the ${place} museum.`, instruction: 'Write one sentence about what you will do if it rains.' },
      { id: 'ec1', type: 'error_correction', context: `If it will rain near the ${place}, we will cancel the picnic.`, instruction: FIX },
      { id: 'ec2', type: 'error_correction', context: `If she would study near the ${place}, she would pass the examination.`, instruction: FIX },
      topicId === 'conditionals'
        ? { id: 'fb', type: 'fill_in_blank', instruction: 'If I were you, I would apologise.' }
        : { id: 'fb', type: 'fill_in_blank', instruction: `If I ____ you at the ${place}, I would apologise to the whole team.` },
    ],
  };
}

function written(items: readonly { id: string; type: string; context?: string }[]): unknown {
  return {
    answers: items.map((i) =>
      i.type === 'fill_in_blank'
        ? { itemId: i.id, key: ['were'], variant: ['was'], mistakes: [{ answer: ['am'], breaks: 'present form' }, { answer: ['would be'], breaks: 'would in the if-part' }] }
        : i.type === 'error_correction'
          ? { itemId: i.id, key: [(i.context ?? '').replace(' will rain', ' rains').replace(' would study', ' studied')], variant: [(i.context ?? '').replace(' will rain', ' should rain').replace(' would study', ' were to study')], mistakes: [{ answer: [i.context ?? ''], breaks: 'left as it was' }, { answer: [(i.context ?? '').replace('If ', 'When if ')], breaks: 'two conjunctions' }] }
          : { itemId: i.id, key: ['If it rains, I will stay at home and revise my notes.'], variant: [], mistakes: [{ answer: ['If it will rain, I will stay at home and revise my notes.'], breaks: 'will in the if-part' }] },
    ),
  };
}

const TOPIC_IDS = ['conditionals', 'articles'] as const;

/** [scorerWrongOn]: built answers on which the made-up scorer says the
 * opposite of the truth they were built with. */
function run(scorerWrongOn: (a: TopicAnswer) => boolean = () => false): TopicsRunData {
  const records: MeasureRecord[] = [];
  const gates = TOPIC_IDS.map((topicId) => {
    const content = generated(topicId);
    records.push({ customId: generationId(topicId, 1), stage: 'generation', group: topicId, model: 'claude-sonnet-5-5', status: 'ok', inputTokens: 1000, outputTokens: 600, costUsd: 0.008, durationMs: 5000, content });
    return gateSet(topicId, 1, content);
  });
  const items = gates.flatMap((g) => g.items);
  const answers: TopicAnswer[] = [];
  const answerProblems = [];
  for (const g of gates) {
    const content = written(g.items);
    records.push({ customId: answersId(g.topicId, g.set), stage: 'answers', group: g.topicId, model: 'claude-sonnet-5-5', status: 'ok', inputTokens: 1600, outputTokens: 700, costUsd: 0.01, durationMs: 6000, content });
    const built = builtAnswersFrom(g.items, content);
    answers.push(...built.answers);
    answerProblems.push(...built.problems);
  }
  const calls = scoringCalls(answers);
  const byId = new Map(answers.map((a) => [a.id, a]));
  for (const { call, answerIds } of calls) {
    const feedback = answerIds.map((id) => {
      const a = byId.get(id) as TopicAnswer;
      const isCorrect = scorerWrongOn(a) ? !a.truth : a.truth;
      return { itemId: id, isCorrect, correctedAnswer: `corrected ${id}`, explanation: `explanation for ${id}`, summary: 's', blanks: [{ index: 0, correctAnswer: 'x', accepted: isCorrect, note: 'n' }] };
    });
    records.push({ customId: call.customId, stage: 'scoring', group: 'C8', model: 'claude-haiku-5-5', status: 'ok', inputTokens: 2400, outputTokens: 2200, costUsd: 0.0014, durationMs: 10_000, content: { feedback } });
  }
  return {
    records,
    sets: gates.map((g) => ({ topicId: g.topicId, set: g.set, passed: g.passed, problems: g.problems, items: g.items.length })),
    items,
    answers,
    answerProblems,
    scoringCalls: calls.map((c) => ({ customId: c.call.customId, answerIds: c.answerIds })),
    checks: checkItems(items, answers),
  };
}

interface Edit {
  verdict?: 'ok' | 'defect';
  why?: string;
  note?: string;
  alsoAccept?: string;
  /** The label of a built answer, by its kind; the others keep their built truth. */
  answers?: Partial<Record<TopicAnswer['kind'], AnswerLabel>>;
}

/** A filled sheet for [data]: every question ok and every answer labelled as
 * it was built, except where [edits] (by item id) say otherwise. Goes
 * through the real sheet and its reader. */
function labelled(data: TopicsRunData, edits: Record<string, Edit> = {}): { labels: QuestionLabel[]; mapping: ReturnType<typeof buildTopicSheet>['mapping'] } {
  const sheet = buildTopicSheet(data.items, data.answers);
  const byId = new Map(data.answers.map((a) => [a.id, a]));
  const rows = parseCsv(sheet.labelsCsv).map((row, i) => {
    const mapped = sheet.mapping.rows[i] as (typeof sheet.mapping.rows)[number];
    const edit = edits[mapped.itemId] ?? {};
    const cells = Object.fromEntries(
      LETTERS.filter((l) => mapped.letters[l] !== undefined).map((l) => {
        const a = byId.get(mapped.letters[l] as string) as TopicAnswer;
        return [l, edit.answers?.[a.kind] ?? (a.truth ? 'right' : 'wrong')];
      }),
    );
    return { ...row, verdict: edit.verdict ?? 'ok', why: edit.why ?? '', note: edit.note ?? '', also_accept: edit.alsoAccept ?? '', ...cells };
  });
  const read = readTopicLabels(rows, sheet.mapping);
  expect(read.problems).toEqual([]);
  expect(read.unlabelled).toEqual([]);
  return { labels: read.labels, mapping: sheet.mapping };
}

const byItem = (labels: readonly QuestionLabel[]) => new Map(labels.map((l) => [l.itemId, l]));

describe('topics labels: the note markers', () => {
  it('multi: and minor: count at the start of the note or of a later sentence in it', () => {
    expect(noteMarks('multi: either pronoun fits here')).toEqual({ multi: true, minor: false });
    expect(noteMarks('  Minor: an awkward word order')).toEqual({ multi: false, minor: true });
    expect(noteMarks('minor: the hint lists the answers. multi: both prepositions fit')).toEqual({ multi: true, minor: true });
    expect(noteMarks('multi: either fits; minor: the hint gives it away')).toEqual({ multi: true, minor: true });
    expect(noteMarks('B is a multi: kind of answer')).toEqual({ multi: false, minor: false });
    expect(noteMarks('C changes the word but is correct')).toEqual({ multi: false, minor: false });
    expect(noteMarks('')).toEqual({ multi: false, minor: false });
  });
});

describe('topics labels: the questions', () => {
  const data = run();

  it('the defect rate is after the gate; a question that failed the gate is counted apart', () => {
    const { labels } = labelled(data, {
      'conditionals.1.4': { verdict: 'defect', why: 'other', note: 'no blank to answer' },
      'conditionals.1.2': { verdict: 'defect', why: 'bad_english; hint_wrong' },
      'conditionals.1.0': { note: 'multi: two forms fit', alsoAccept: 'If it rained | Should it rain' },
      'conditionals.1.1': { note: 'minor: asks for two sentences. multi: both tenses fit' },
      'conditionals.1.3': { note: 'B is an acceptable alternative' },
    });
    const s = questionSummary('conditionals', data.items, byItem(labels));
    expect(s).toEqual({
      topicId: 'conditionals',
      questions: 5,
      gateFailed: 1,
      gateFailedDefects: 1,
      afterGate: 4,
      defects: 1,
      byWhy: { bad_english: 1, hint_wrong: 1 },
      multi: 2,
      minor: 1,
      otherNotes: 1,
      alsoAccept: 1,
      unlabelled: 0,
    });
    expect(questionSummary('articles', data.items, byItem(labels))).toMatchObject({ questions: 5, gateFailed: 0, afterGate: 5, defects: 0, multi: 0, minor: 0, otherNotes: 0 });
  });

  it('a question without a label is in no rate and is counted', () => {
    const { labels } = labelled(data);
    const partial = byItem(labels.filter((l) => l.itemId !== 'articles.1.2'));
    expect(questionSummary('articles', data.items, partial)).toMatchObject({ questions: 5, afterGate: 4, unlabelled: 1 });
  });
});

describe('topics labels: the scorer against the labelled truth', () => {
  // The scorer says the opposite of the construction on every second answer.
  const data = run((a) => a.kind === 'variant');
  const verdicts = scoredAnswers(data).verdicts;
  const { labels } = labelled(data, {
    // The labels agree with the scorer here: this second answer is wrong.
    'articles.1.2': { answers: { variant: 'wrong' } },
    // A written mistake that is in fact right, and one nobody can call.
    'articles.1.3': { answers: { mistake1: 'right', mistake2: 'unsure' } },
    'articles.1.4': { note: 'multi: was and were both fit' },
  });
  const truth = labelledTruth(labels);
  const multi = new Set(labels.filter((l) => noteMarks(l.note).multi).map((l) => l.itemId));
  const of = (topicId: string) => data.answers.filter((a) => a.topicId === topicId);

  it('the labelled truth is by answer id, for every built answer', () => {
    expect(truth.size).toBe(data.answers.length);
    const variant = data.answers.find((a) => a.itemId === 'articles.1.2' && a.kind === 'variant') as TopicAnswer;
    expect(variant.truth).toBe(true);
    expect(truth.get(variant.id)).toBe('wrong');
  });

  it('agreement and both error rates use the labels; unsure is in neither', () => {
    // Articles: 2 written (key, mistake), 2 corrections (key, second, 2 mistakes), 1 blank item (key, second, 2 mistakes).
    const m = labelledMetrics(of('articles'), verdicts, truth, multi);
    expect(m.answers).toBe(16);
    expect(m.unsure).toBe(1);
    expect(m.compared).toBe(15);
    // Right by the labels: 5 keys, the second answers of 1.3 and 1.4, the mistake of 1.3 called right.
    expect(m.right).toBe(8);
    expect(m.wrong).toBe(7);
    // The scorer rejected the second answers of 1.3 and 1.4 (right) and the mistake labelled right.
    expect(m.falseNeedsWork).toBe(3);
    // It called the second answer of 1.2 "needs work": the label says wrong too.
    expect(m.falseCorrect).toBe(0);
    expect(m.agree).toBe(12);
    expect(m.notCompared).toBe(0);
  });

  it('the false "needs work" is split: the built key, the other right answers, the questions noted multi:', () => {
    const m = labelledMetrics(of('articles'), verdicts, truth, multi);
    expect([m.keysRight, m.falseNeedsWorkOnKey]).toEqual([5, 0]);
    expect([m.othersRight, m.falseNeedsWorkOnOther]).toEqual([3, 3]);
    // articles.1.4 is noted multi: its key and its second answer are right, the second was rejected.
    expect([m.multiRight, m.falseNeedsWorkOnMulti]).toEqual([2, 1]);
    expect(m.falseNeedsWorkOnKey + m.falseNeedsWorkOnOther).toBe(m.falseNeedsWork);
  });

  it('an answer without a label or without a verdict is left out and counted', () => {
    const keys = new Set(of('articles').filter((a) => a.kind === 'key').map((a) => a.id));
    const noVerdict = new Map([...verdicts].filter(([id]) => !keys.has(id)));
    const m = labelledMetrics(of('articles'), noVerdict, truth, multi);
    expect(m.compared + m.unsure + m.notCompared).toBe(16);
    expect(m.notCompared).toBe(5);
    expect(labelledMetrics(of('articles'), verdicts, new Map())).toMatchObject({ compared: 0, notCompared: 16, agree: 0 });
  });

  it('where the labelled truth differs from the construction', () => {
    expect(truthVsConstruction(of('articles'), truth)).toEqual({ mistakesLabelledRight: 1, keysLabelledWrong: 0, secondAnswersLabelledWrong: 1, unsure: { key: 0, secondAnswer: 0, mistake: 1 } });
    expect(truthVsConstruction(of('conditionals'), truth)).toEqual({ mistakesLabelledRight: 0, keysLabelledWrong: 0, secondAnswersLabelledWrong: 0, unsure: { key: 0, secondAnswer: 0, mistake: 0 } });
  });

  it('the disagreements for the second look: both directions and the unsure answers', () => {
    const d = scorerDisagreements(data.answers, verdicts, truth);
    expect(d.falseNeedsWork.filter((a) => a.topicId === 'articles').map((a) => `${a.itemId}:${a.kind}`).sort()).toEqual(['articles.1.3:mistake1', 'articles.1.3:variant', 'articles.1.4:variant']);
    expect(d.falseCorrect).toEqual([]);
    expect(d.unsure.map((a) => `${a.itemId}:${a.kind}`)).toEqual(['articles.1.3:mistake2']);
  });
});

describe('topics labels: the pass criteria', () => {
  it('are the owner\'s three', () => {
    expect(PASS_CRITERIA).toEqual({ maxDefectPercent: 5, minAgreementPercent: 95, maxFalseCorrectPercent: 2 });
  });

  it('at most 5 % defects: with 30 questions one passes and two fail; with 29, one still passes', () => {
    const scoring = { agree: 100, compared: 100, falseCorrect: 0, wrong: 50 };
    expect(passCriteria({ defects: 1, afterGate: 30 }, scoring).defects).toEqual({ n: 1, of: 30, pass: true });
    expect(passCriteria({ defects: 2, afterGate: 30 }, scoring).defects.pass).toBe(false);
    expect(passCriteria({ defects: 1, afterGate: 29 }, scoring).defects.pass).toBe(true);
    expect(passCriteria({ defects: 1, afterGate: 15 }, scoring).defects.pass).toBe(false);
    expect(passCriteria({ defects: 1, afterGate: 20 }, scoring).defects.pass).toBe(true);
  });

  it('agreement at least 95 %, false "correct" at most 2 %, on the line both pass', () => {
    const q = { defects: 0, afterGate: 30 };
    expect(passCriteria(q, { agree: 95, compared: 100, falseCorrect: 1, wrong: 50 })).toMatchObject({ agreement: { pass: true }, falseCorrect: { pass: true }, pass: true });
    expect(passCriteria(q, { agree: 75, compared: 80, falseCorrect: 0, wrong: 46 }).agreement.pass).toBe(false);
    expect(passCriteria(q, { agree: 76, compared: 80, falseCorrect: 0, wrong: 46 }).agreement.pass).toBe(true);
    // One false "correct" of 47 is over 2 %; one of 50 is on the line.
    expect(passCriteria(q, { agree: 80, compared: 81, falseCorrect: 1, wrong: 47 })).toMatchObject({ falseCorrect: { n: 1, of: 47, pass: false }, pass: false });
    expect(passCriteria(q, { agree: 80, compared: 81, falseCorrect: 1, wrong: 50 }).pass).toBe(true);
  });

  it('nothing to divide by is neither pass nor fail', () => {
    const c = passCriteria({ defects: 0, afterGate: 0 }, { agree: 0, compared: 0, falseCorrect: 0, wrong: 0 });
    expect([c.defects.pass, c.agreement.pass, c.falseCorrect.pass, c.pass]).toEqual([null, null, null, null]);
  });
});

describe('topics labels: what the automatic checks were worth', () => {
  const data = run();
  const { labels } = labelled(data, {
    'conditionals.1.4': { verdict: 'defect', why: 'other', note: 'no blank to answer' },
    'articles.1.0': { verdict: 'defect', why: 'bad_english' },
    'articles.1.4': { note: 'multi: was and were both fit' },
    'articles.1.3': { note: 'multi: two corrections are equally good' },
  });
  const w = checksWorth(data.checks, byItem(labels));

  it('relates the gate and each check to the labels', () => {
    expect(w.questions).toBe(10);
    expect(w.defects).toBe(2);
    expect(w.multi).toBe(2);
    expect(w.gate).toEqual({ flagged: 1, defect: 1, multi: 0, minor: 0, neither: 0 });
    // The control's blank question lists a second answer: the one-answer check flagged it.
    expect(w.byCheck.single_answer).toMatchObject({ flagged: 1, multi: 1, defect: 0 });
    expect(w.multiFlaggedByOneAnswer).toBe(1);
    for (const check of Object.values(w.byCheck)) expect(check.defect + check.multi + check.minor + check.neither).toBeGreaterThanOrEqual(check.flagged);
  });

  it('says how the defects were found: by the gate, by a flag, or by nothing', () => {
    expect(w.defectsCaughtByGate).toBe(1);
    expect(w.defectsFlagged + w.defectsUnflagged).toBe(1);
    expect(w.defectsUnflagged).toBe(1);
    expect(w.clean.defect).toBe(data.checks.find((c) => c.itemId === 'articles.1.0')?.flags.length === 0 ? 1 : 0);
  });
});

describe('topics labels: the report with the labels in it', () => {
  const data = run((a) => a.kind === 'variant' && a.topicId === 'articles');
  const verdicts = scoredAnswers(data).verdicts;
  const { labels, mapping } = labelled(data, {
    'conditionals.1.4': { verdict: 'defect', why: 'other', note: 'no blank to answer' },
    'articles.1.2': { answers: { variant: 'wrong' } },
    'articles.1.4': { note: 'multi: was and were both fit' },
  });
  const parts = phaseCParts({ data, labels, verdicts, findings: '### A finding\n\nA defect described in words.' });
  const meta = { runDir: 'proxy/eval/out/topics-test', generatedAt: '2026-11-18 18:00 UTC', wallSeconds: 60, sheet: { questions: 10, answers: 32, labelled: 10, withProblems: 0 } };
  const report = renderTopicsReport(data, meta, parts);

  it('opens with the status, the limitations and the pass criteria per topic, with the counts behind each', () => {
    expect(report).toContain('**Status: measured and labelled (phase C of [`TOPICS.md`](TOPICS.md)).**');
    const limits = report.slice(report.indexOf('## 0. Limitations'), report.indexOf('## 1. '));
    expect(limits).toContain('written by Claude in the owner\'s Cowork session and checked by the owner');
    expect(limits).toContain('built, not real learners');
    expect(report).toContain('## 1. The pass criteria, per topic');
    // Conditionals: 4 questions after the gate, none a defect; its 12 answers (the question without a blank has none) all agree.
    expect(report).toContain('| Conditionals | 0.0 % (0 / 4): **pass** | 100.0 % (12 / 12): **pass** | 0.0 % (0 / 6): **pass** | **passes** |');
    // The control: the scorer rejected two second answers the labels call right.
    expect(report).toContain('| Articles (control) | 0.0 % (0 / 5): **pass** | 87.5 % (14 / 16): **FAIL** | 0.0 % (0 / 9): **pass** | **fails** (for reference) |');
    expect(report).toContain('Of the five new topics, 1 pass all three criteria (Conditionals) and 0 fail.');
    // A topic the run has nothing for is neither.
    expect(report).toContain('| Passive Voice | – | – | – | – |');
  });

  it('counts the questions that failed the gate apart, and the defects by why', () => {
    expect(report).toContain('| Conditionals | 5 | 1 (1) | 4 | 0.0 % (0 / 4) | – | 0 | 0 | 0 | 0 |');
    expect(report).toContain('Counted with them, the defect rates are: Conditionals 20.0 % (1 / 5);');
    expect(report).toContain('| Articles (control) | 5 | 0 (0) | 5 | 0.0 % (0 / 5) | – | 1 | 0 | 0 | 0 |');
  });

  it('has the scoring against the labels, the split and the difference from the construction', () => {
    expect(report).toContain('| Articles (control) | 16 | 7 / 9 / 0 | 87.5 % (14 / 16) | 0.0 % (0 / 9) | 28.6 % (2 / 7) |');
    expect(report).toContain('| Articles (control) | 28.6 % (2 / 7) | 0.0 % (0 / 5) | 100.0 % (2 / 2) | 50.0 % (1 / 2) | 20.0 % (1 / 5) |');
    expect(report).toContain('| Articles (control) | 0 | 0 | 1 | 0 / 0 / 0 | 81.3 % (13 / 16) | 87.5 % (14 / 16) |');
    expect(report).toContain('## 5. What the automatic checks were worth');
  });

  it('carries the hand-written findings, and says so when there are none', () => {
    expect(report).toContain('## 6. Findings and proposals\n\n### A finding\n\nA defect described in words.');
    expect(renderTopicsReport(data, meta, phaseCParts({ data, labels, verdicts, findings: null }))).toContain('## 6. Findings and proposals\n\n_Not written yet._');
  });

  it('keeps the run sections after the label sections, numbered on, and updates what may be opened', () => {
    expect(report).toContain('## 7. What ran');
    expect(report).toContain('## 12. The scorer on the built answers, by construction (as before the labels)');
    expect(report).toContain('| `private/details.txt` | per question the flags, the gate, the scorer\'s verdicts and explanations; the resembling questions side by side | open now that the sheet is filled |');
    expect(report).toContain('| `second-look.md` |');
    expect(report).toContain('1.5.0-topics-set-variety.md');
    expect(report).not.toContain('§');
    expect(report.match(/^## \d+\. /gm)?.length).toBe(16);
  });

  it('without the labels it is still the phase B report', () => {
    const phaseB = renderTopicsReport(data, { ...meta, sheet: { ...meta.sheet, labelled: 0 } });
    expect(phaseB).toContain('**Status: measured, not yet labelled');
    expect(phaseB).toContain('## 1. What ran');
    expect(phaseB).not.toContain('pass criteria, per topic');
    expect(phaseB).not.toContain('§');
  });

  it('holds counts and rates only: no question, no answer, no sheet key', () => {
    expect(contentLeaks(report, data.items, data.answers, mapping.rows.map((r) => r.key))).toEqual([]);
    for (const a of data.answers) expect(report).not.toContain(a.id);
    expect(report).not.toContain('was and were both fit');
    expect(report).not.toContain('no blank to answer');
  });
});

describe('topics labels: the second-look file', () => {
  const data = run((a) => (a.kind === 'variant' && a.topicId === 'articles') || (a.kind === 'mistake1' && a.itemId === 'conditionals.1.0'));
  const verdicts = scoredAnswers(data).verdicts;
  const { labels, mapping } = labelled(data, {
    'conditionals.1.4': { verdict: 'defect', why: 'other', note: 'no blank to answer' },
    'articles.1.2': { answers: { variant: 'wrong' } },
    'articles.1.3': { answers: { mistake2: 'unsure' }, note: 'multi: two corrections are good', alsoAccept: 'If she studied there' },
  });
  const text = renderTopicsSecondLook({ data, labels, verdicts, mapping, runDir: 'proxy/eval/out/topics-test' });
  const section = (from: string, to: string) => text.slice(text.indexOf(from), to === '' ? undefined : text.indexOf(to));

  it('A: every right answer the scorer rejected, with the question, the answer, the note and the scorer\'s words', () => {
    const a = section('## A.', '## B.');
    expect(a).toContain('## A. The scorer said "needs work" where the label says right (2)');
    expect(a).toMatch(/### articles\.1\.3, answer [A-D] \(Articles, Find and correct the error, noted multi:\)/);
    expect(a).toContain('```text\nIf she would study near the airport, she would pass the examination.\n' + FIX + '\n```');
    expect(a).toContain('- **Answer:** If she were to study near the airport, she would pass the examination.');
    expect(a).toContain('- **Built as:** the second answer');
    expect(a).toContain('- **Labelled:** right');
    expect(a).toContain("- **Label's note on the question:** multi: two corrections are good *Also accept:* If she studied there");
    const variant = data.answers.find((x) => x.itemId === 'articles.1.3' && x.kind === 'variant') as TopicAnswer;
    expect(a).toContain(`- **Scorer:** needs work — explanation for ${variant.id} *Corrected:* corrected ${variant.id}`);
    // The second answer the labels call wrong is not a disagreement.
    expect(a).not.toContain('### articles.1.2');
  });

  it('B: every wrong answer the scorer accepted; C: the unsure answers', () => {
    const b = section('## B.', '## C.');
    expect(b).toContain('## B. The scorer said "correct" where the label says wrong (1)');
    expect(b).toMatch(/### conditionals\.1\.0, answer [A-D] \(Conditionals, Write a sentence\)/);
    expect(b).toContain('- **Built as:** a mistake (breaks: will in the if-part)');
    expect(b).toContain('- **Scorer:** correct — ');
    const c = section('## C.', '## D.');
    expect(c).toContain('## C. Answers labelled unsure (1), in neither rate');
    expect(c).toContain('- **Labelled:** unsure');
  });

  it('D: the defect questions with the gate, the checks and every built answer', () => {
    const d = section('## D.', '');
    expect(d).toContain('## D. The questions labelled defect (1)');
    expect(d).toMatch(/### conditionals\.1\.4 \(Conditionals, Fill in the blank; sheet key k[0-9a-f]{7}\)/);
    expect(d).toContain('- **Labelled:** defect, `other`');
    expect(d).toContain("- **Label's note on the question:** no blank to answer");
    expect(d).toContain('- **Gate:** failed: `fill_in_blank_without_blank`');
    expect(d).toContain('- **Automatic checks:** no flag; not run for want of a key: single_answer, hint_card');
    expect(d).toContain('- **Built answers:** none');
  });

  it('every entry ends with an empty Owner line, and a file with a verdict in it is never rewritten', () => {
    expect(text.match(/^- \*\*Owner:\*\*$/gm)?.length).toBe(2 + 1 + 1 + 1);
    expect(secondLookHasVerdicts(text)).toBe(false);
    expect(secondLookHasVerdicts(text.replace('- **Owner:**', '- **Owner:** the scorer is right'))).toBe(true);
    expect(secondLookHasVerdicts('')).toBe(false);
  });

  it('a blank in an answer or a note stays a run of underscores in the rendered file', () => {
    const blanked = renderTopicsSecondLook({ data, labels: labels.map((l) => (l.itemId === 'articles.1.3' ? { ...l, note: 'multi: the ____ may take *either*' } : l)), verdicts, mapping, runDir: 'x' });
    expect(blanked).toContain('multi: the \\_\\_\\_\\_ may take \\*either\\*');
  });
});
