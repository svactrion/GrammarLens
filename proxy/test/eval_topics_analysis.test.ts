import { describe, expect, it } from 'vitest';
import type { MeasureRecord } from '../eval/lib/measurement';
import {
  contentLeaks,
  duplicateSummary,
  rate,
  renderTopicsReport,
  scoredAnswers,
  scoringMetrics,
  spendByStage,
  topicOfRecords,
  wallSeconds,
  type TopicsRunData,
} from '../eval/lib/topics_analysis';
import { checkItems, duplicateGroups, duplicatePairs, gateSet } from '../eval/lib/topics_checks';
import { answersId, builtAnswersFrom, generationId, scoringCalls, type TopicAnswer, type TopicItem } from '../eval/lib/topics_measurement';
import {
  ANSWER_LABELS,
  LETTERS,
  NO_ANSWER,
  SHEET_COLUMNS,
  SHEET_SEED,
  VERDICTS,
  WHY_VALUES,
  buildTopicSheet,
  readTopicLabels,
  renderDetails,
  renderSheetStatus,
  sheetHeaderProblem,
} from '../eval/lib/topics_sheet';
import { parseCsv, toCsv } from '../eval/lib/labels';

const FIX = 'Find the mistake and rewrite the full corrected sentence.';

/** A made-up run: two sets of Conditionals (the second repeats a correction
 * and has a fill-in-the-blank item without a blank) and one of the control. */
const SUBJECT: Readonly<Record<string, string>> = { 'conditionals-1': 'chemistry', 'conditionals-2': 'geography', 'articles-1': 'history' };

function generated(topicId: string, set: number): unknown {
  const tag = `${topicId}-${set}`;
  // One word apart from set to set: near-duplicates across sets, and the
  // first correction the same words in every set.
  const subject = SUBJECT[tag] as string;
  return {
    items: [
      { id: `sw1-${tag}`, type: 'sentence_writing', context: `You are giving advice to a friend about the ${subject} exam next month.`, instruction: 'Write one sentence with "if".' },
      { id: `sw2-${tag}`, type: 'sentence_writing', context: `You are planning a weekend trip with your family to the ${subject} museum.`, instruction: 'Write one sentence about what you will do if it rains.' },
      { id: `ec1-${tag}`, type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic in the park.', instruction: FIX },
      { id: `ec2-${tag}`, type: 'error_correction', context: `If she would study harder for ${subject}, she would pass the final examination.`, instruction: FIX, hint: 'Look at the if-part.' },
      set === 2 && topicId === 'conditionals'
        ? { id: `fb-${tag}`, type: 'fill_in_blank', instruction: 'If I were you, I would apologise.' }
        : { id: `fb-${tag}`, type: 'fill_in_blank', instruction: `If I ____ you in ${subject} class, I would apologise to the whole team.` },
    ],
  };
}

function written(items: readonly TopicItem[]): unknown {
  return {
    answers: items.map((i) =>
      i.type === 'fill_in_blank'
        ? { itemId: i.id, key: ['were'], variant: ['was'], mistakes: [{ answer: ['am'], breaks: 'present in an unreal if-part' }, { answer: ['would be'], breaks: 'would in the if-part' }] }
        : i.type === 'error_correction'
          ? { itemId: i.id, key: [(i.context ?? '').replace(' will rain', ' rains').replace(' would study', ' studied')], variant: [], mistakes: [{ answer: [i.context ?? ''], breaks: 'left as it was' }, { answer: [(i.context ?? '').replace('If ', 'When if ')], breaks: 'two conjunctions' }] }
          : { itemId: i.id, key: ['If it rains, I will stay at home and revise my notes.'], variant: [], mistakes: [{ answer: ['If it will rain, I will stay at home and revise my notes.'], breaks: 'will in the if-part' }] },
    ),
  };
}

const SETS: readonly [string, number][] = [['conditionals', 1], ['conditionals', 2], ['articles', 1]];

/** [wrongOn]: answers the made-up scorer gets wrong (it says the opposite). */
function run(wrongOn: (a: TopicAnswer) => boolean = () => false): TopicsRunData {
  const records: MeasureRecord[] = [];
  const gates = SETS.map(([topicId, set]) => {
    const content = generated(topicId, set);
    records.push({ customId: generationId(topicId, set), stage: 'generation', group: topicId, model: 'claude-sonnet-5-5', status: 'ok', inputTokens: 1000, outputTokens: 600, costUsd: 0.008, durationMs: 5000, content });
    return gateSet(topicId, set, content);
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
      const isCorrect = wrongOn(a) ? !a.truth : a.truth;
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

const META = { runDir: 'proxy/eval/out/topics-test', generatedAt: '2026-11-18 17:00 UTC', wallSeconds: 332, sheet: { questions: 15, answers: 43, labelled: 0, withProblems: 0 } };

describe('topics analysis: the scorer against the built answers', () => {
  it('reads one verdict per built answer from the calls the run names', () => {
    const data = run();
    const scored = scoredAnswers(data);
    expect(scored.calls).toBe(data.scoringCalls.length);
    expect(scored.verdicts.size).toBe(data.answers.length);
    expect(scored.notScored).toEqual([]);
    const first = data.answers[0] as TopicAnswer;
    expect(scored.verdicts.get(first.id)).toMatchObject({ isCorrect: first.truth, correctedAnswer: `corrected ${first.id}`, explanation: `explanation for ${first.id}` });
  });

  it('a record the run does not name, a failed call and a missing entry leave answers unscored', () => {
    const data = run();
    const [gone, failed, ...rest] = data.scoringCalls;
    const records = data.records.map((r) => (r.customId === failed?.customId ? { ...r, status: 'http_error' } : r));
    const scored = scoredAnswers({ records, answers: data.answers, scoringCalls: [failed as (typeof data.scoringCalls)[number], ...rest] });
    expect(scored.calls).toBe(rest.length);
    expect([...scored.notScored].sort()).toEqual([...(gone?.answerIds ?? []), ...(failed?.answerIds ?? [])].sort());
  });

  it("applies the proxy's repair first: isCorrect follows the per-blank verdicts, as the app would get it", () => {
    const data = run();
    const call = data.scoringCalls[0] as (typeof data.scoringCalls)[number];
    const target = call.answerIds[0] as string;
    const truth = data.answers.find((a) => a.id === target)?.truth as boolean;
    const records = data.records.map((r) => {
      if (r.customId !== call.customId) return r;
      const feedback = (r.content as { feedback: Record<string, unknown>[] }).feedback.map((f) => (f.itemId === target ? { ...f, isCorrect: !truth } : f));
      return { ...r, content: { feedback } };
    });
    const scored = scoredAnswers({ ...data, records });
    expect(scored.verdictReconciled).toBe(1);
    expect(scored.verdicts.get(target)?.isCorrect).toBe(truth);
  });

  it('agreement, false "correct" among the wrong, false "needs work" among the right', () => {
    const data = run((a) => a.kind === 'variant' || (a.kind === 'mistake2' && a.topicId === 'articles'));
    const { verdicts } = scoredAnswers(data);
    const cond = scoringMetrics(data.answers.filter((a) => a.topicId === 'conditionals'), verdicts);
    // Two sets: 4 written (key + mistake), 4 corrections (key + 2), 1 blank item (key, second, 2).
    expect(cond).toEqual({ answers: 24, scored: 24, agree: 23, wrong: 14, falseCorrect: 0, right: 10, falseNeedsWork: 1 });
    const control = scoringMetrics(data.answers.filter((a) => a.topicId === 'articles'), verdicts);
    expect(control).toEqual({ answers: 14, scored: 14, agree: 10, wrong: 8, falseCorrect: 3, right: 6, falseNeedsWork: 1 });
    expect(scoringMetrics([], verdicts)).toEqual({ answers: 0, scored: 0, agree: 0, wrong: 0, falseCorrect: 0, right: 0, falseNeedsWork: 0 });
  });

  it('rate() shows the share and the counts, or a dash', () => {
    expect(rate(27, 28)).toBe('96.4 % (27 / 28)');
    expect(rate(0, 48)).toBe('0.0 % (0 / 48)');
    expect(rate(0, 0)).toBe('–');
  });
});

describe('topics analysis: duplicates', () => {
  const data = run();

  it('pairs keep what the flags say: same words or near, inside a set or across', () => {
    const pairs = duplicatePairs(data.items);
    const same = pairs.filter((p) => p.same);
    expect(same.map((p) => [p.a.id, p.b.id, p.inSet])).toEqual([['conditionals.1.2', 'conditionals.2.2', false]]);
    expect(pairs.every((p) => p.a.topicId === p.b.topicId)).toBe(true);
    for (const p of pairs.filter((x) => !x.same)) expect(p.similarity).toBeGreaterThanOrEqual(0.6);
    // The pairs are exactly the questions the run's check flagged.
    const flagged = new Set(data.checks.filter((c) => c.flags.some((f) => f.check === 'duplicate')).map((c) => c.itemId));
    expect(new Set(pairs.flatMap((p) => [p.a.id, p.b.id]))).toEqual(flagged);
  });

  it('groups join questions through a chain of pairs', () => {
    const [a, b, c, d] = data.items as [TopicItem, TopicItem, TopicItem, TopicItem];
    const pair = (x: TopicItem, y: TopicItem) => ({ a: x, b: y, same: false, similarity: 0.7, inSet: x.set === y.set });
    expect(duplicateGroups([a, b, c, d], [pair(a, b), pair(b, c)]).map((g) => g.map((i) => i.id))).toEqual([[a.id, b.id, c.id]]);
    expect(duplicateGroups([a, b, c, d], [pair(a, b), pair(c, d)]).map((g) => g.length)).toEqual([2, 2]);
    expect(duplicateGroups([a, b, c, d], [pair(c, d), pair(a, c), pair(b, d)]).map((g) => g.length)).toEqual([4]);
    expect(duplicateGroups([a, b], [])).toEqual([]);
  });

  it('the summary splits the flagged questions and the pairs, and sizes the groups', () => {
    const s = duplicateSummary('conditionals', data.items);
    expect(s.questions).toBe(10);
    expect(s.sameWords).toBe(2);
    expect(s.inSet).toBe(0);
    expect(s.acrossSets).toBe(s.flagged);
    expect(s.pairs.sameAcrossSets).toBe(1);
    expect(s.pairs.sameInSet + s.pairs.nearInSet).toBe(0);
    expect(s.flagged).toBe(8);
    expect(s.nearDuplicate).toBe(6);
    expect(s.pairs.nearAcrossSets).toBe(3);
    expect(s.groupSizes).toEqual([2, 2, 2, 2]);
    expect(s.byType).toEqual({ fill_in_blank: 0, error_correction: 4, sentence_writing: 4 });
    expect(s.largestGroupSets).toBe(2);
    expect(s.byType.sentence_writing + s.byType.error_correction + s.byType.fill_in_blank).toBe(s.flagged);
    expect(duplicateSummary('articles', data.items)).toMatchObject({ questions: 5, flagged: 0, groupSizes: [], largestGroupSets: 0 });
  });
});

describe('topics analysis: spend and time', () => {
  const data = run();

  it('per stage: calls, spend, mean tokens and seconds', () => {
    const [generation, answers, scoring] = spendByStage(data.records);
    expect(generation).toMatchObject({ stage: 'generation', calls: 3, ok: 3, meanInput: 1000, meanOutput: 600, meanSeconds: 5 });
    expect(generation?.costUsd).toBeCloseTo(0.024, 10);
    expect(answers).toMatchObject({ stage: 'answers', calls: 3, meanSeconds: 6 });
    expect(scoring).toMatchObject({ stage: 'scoring', calls: data.scoringCalls.length, meanSeconds: 10 });
  });

  it('every record has a topic: a scoring call has the topic of the set it scores', () => {
    const topics = topicOfRecords(data);
    expect(topics.size).toBe(data.records.length);
    expect(topics.get(generationId('articles', 1))).toBe('articles');
    const articleCalls = data.scoringCalls.filter((c) => topics.get(c.customId) === 'articles');
    expect(articleCalls.flatMap((c) => c.answerIds).length).toBe(data.answers.filter((a) => a.topicId === 'articles').length);
  });

  it("the wall time is from the log's first to its last timestamp", () => {
    expect(wallSeconds('2026-11-18T16:35:34.632Z topics run in x\nnot a line\n2026-11-18T16:41:07.008Z topics run done')).toBeCloseTo(332.376, 3);
    expect(wallSeconds('one\n2026-11-18T16:35:34.632Z only')).toBeNull();
    expect(wallSeconds('')).toBeNull();
  });
});

describe('topics analysis: the report', () => {
  const data = run((a) => a.kind === 'variant');
  const report = renderTopicsReport(data, META);

  it('states the limitations before any number', () => {
    const limits = report.indexOf('## 0. Limitations');
    expect(limits).toBeGreaterThan(0);
    expect(limits).toBeLessThan(report.indexOf('## 1. What ran'));
    const section = report.slice(limits, report.indexOf('## 1. What ran'));
    expect(section).toContain('built, not real learners');
    expect(section).toContain('by construction until phase C');
    expect(section).toContain('flags, not verdicts');
  });

  it('has, per topic and for the control, the generation, the gate, the checks, the scoring, the spend', () => {
    expect(report).toContain('| Conditionals | 2 of 6 | 50.0 % (1 / 2) | 10 | 90.0 % (9 / 10) | 4 / 4 / 2 |');
    expect(report).toContain('| Articles (control) | 1 of 3 | 100.0 % (1 / 1) | 5 | 100.0 % (5 / 5) | 2 / 2 / 1 |');
    expect(report).toContain('- Conditionals: 1 set (question: `fill_in_blank_without_blank` × 1).');
    expect(report).toContain('- `key_unusable`: Conditionals × 1');
    expect(report).toContain('| Conditionals | 9 of 10 | 24 | 9 | 1 | 14 | 10 / 14 |');
    expect(report).toContain('| Conditionals | 24 | 24 | 95.8 % (23 / 24) | 0.0 % (0 / 14) | 10.0 % (1 / 10) |');
    expect(report).toContain('| second answer | new topics | 1 | 1 | 0.0 % (0 / 1) | – | 100.0 % (1 / 1) |');
    expect(report).toContain('Where the 2 disagreements are: in the new topics 0 on keys, 1 on second answers and 0 on mistakes; in the control 0, 1 and 0.');
    expect(report).toContain('| Duplicates | `duplicate_across_sets` |');
    expect(report).toContain('The run took 5 min 32 s');
    expect(report).toMatch(/\| Articles \(control\) \| \d+ \| \$0\.0\d \|/);
    // A topic the run has nothing for still has its row.
    expect(report).toContain('| Passive Voice | 0 of 6 | – | 0 | – | 0 / 0 / 0 |');
  });

  it('says what makes two sets of one topic differ on the live path, from the code', () => {
    const section = report.slice(report.indexOf('### What makes two Topic Practice sets'), report.indexOf('## 6.'));
    expect(section).toContain("Nothing but the model's own sampling");
    expect(section).toContain('`deviceId`, `topicId`, `count`');
    expect(section).toContain('No seed, no temperature, no earlier question, no list to avoid');
  });

  it('names the sheet files and who may open them, and the state of the sheet', () => {
    expect(report).toContain('`sheet/questions.txt`');
    expect(report).toContain('`sheet/labels.csv`');
    expect(report).toContain('| `private/sheet-mapping.json` | which question and which built answer each key and letter is | **nobody, until the sheet is filled** |');
    expect(report).toContain('| `private/details.txt` |');
    expect(report).toContain('0 of 15 rows labelled.');
    expect(renderTopicsReport(data, { ...META, sheet: { ...META.sheet, labelled: 9, withProblems: 2 } })).toContain('9 of 15 rows labelled; 2 rows with a value to fix');
  });

  it('holds counts and rates only: no question, no answer, no sheet key', () => {
    const sheet = buildTopicSheet(data.items, data.answers);
    expect(contentLeaks(report, data.items, data.answers, sheet.mapping.rows.map((r) => r.key))).toEqual([]);
    for (const a of data.answers) expect(report).not.toContain(a.id);
  });

  it('contentLeaks finds a question, an answer or a key that got into a text', () => {
    const item = data.items[2] as TopicItem;
    const answer = data.answers.find((a) => a.userAnswer.length >= 20) as TopicAnswer;
    expect(contentLeaks(`x ${item.context} y`, data.items, data.answers)).toContain(`${item.id} context`);
    expect(contentLeaks(`x ${answer.userAnswer} y`, data.items, data.answers)).toContain(`answer ${answer.id}`);
    expect(contentLeaks('row k1234567 is odd', data.items, data.answers, ['k1234567'])).toEqual(['sheet key k1234567']);
    // A one-word answer is in any English text and is not looked for.
    expect(contentLeaks('If I were you', data.items, data.answers)).toEqual([]);
  });

  it('says so when the recorded flags and the recomputed duplicates differ', () => {
    expect(report).toContain('agree with the flags the run recorded');
    const noFlags = { ...data, checks: data.checks.map((c) => ({ ...c, flags: c.flags.filter((f) => f.check !== 'duplicate') })) };
    expect(renderTopicsReport(noFlags, META)).toContain('These counts differ from the flags the run recorded for: Conditionals.');
  });
});

describe('topics sheet: the blind sheet', () => {
  const data = run();
  const sheet = buildTopicSheet(data.items, data.answers);

  it('has every question once, under an opaque key, with every built answer under a letter', () => {
    expect(sheet.questions).toBe(15);
    expect(sheet.answers).toBe(data.answers.length);
    expect(sheet.mapping.seed).toBe(SHEET_SEED);
    expect(sheet.mapping.rows.map((r) => r.itemId).sort()).toEqual(data.items.map((i) => i.id).sort());
    expect(new Set(sheet.mapping.rows.map((r) => r.key)).size).toBe(15);
    for (const row of sheet.mapping.rows) {
      expect(row.key).toMatch(/^k[0-9a-f]{7}$/);
      const mine = data.answers.filter((a) => a.itemId === row.itemId).map((a) => a.id);
      expect(Object.values(row.letters).sort()).toEqual(mine.sort());
      expect(Object.keys(row.letters)).toEqual(LETTERS.slice(0, mine.length));
    }
  });

  it('a question that failed the gate and has no answers is on it like any other', () => {
    const row = sheet.mapping.rows.find((r) => r.itemId === 'conditionals.2.4');
    expect(row?.letters).toEqual({});
    const block = sheet.questionsText.slice(sheet.questionsText.indexOf(`---- ${row?.key}`));
    expect(block.slice(0, block.indexOf('\n\n'))).toContain('(none were written for this question)');
  });

  it('the order is mixed across topics and the letters are shuffled, the same on every build', () => {
    expect(buildTopicSheet(data.items, data.answers)).toEqual(sheet);
    expect(sheet.mapping.rows.map((r) => r.itemId)).not.toEqual(data.items.map((i) => i.id));
    const keyLetters = new Set(
      sheet.mapping.rows.flatMap((row) => Object.entries(row.letters).filter(([, id]) => data.answers.find((a) => a.id === id)?.kind === 'key').map(([letter]) => letter)),
    );
    expect(keyLetters.size).toBeGreaterThan(1);
    expect(buildTopicSheet(data.items, data.answers, 7).mapping.rows.map((r) => r.key)).not.toEqual(sheet.mapping.rows.map((r) => r.key));
  });

  it('shows what a learner sees and the built answers', () => {
    const text = sheet.questionsText;
    // Each topic's hint card once, at the top.
    const cards = text.slice(text.indexOf('HINT CARDS'), text.indexOf('QUESTIONS (15)'));
    expect(cards).toContain('Conditionals\n  - If + present, will + verb: real future');
    expect(cards).toContain('Articles\n  - a / an: one of many, or first mention');
    expect(cards).not.toContain('Passive Voice');
    const row = sheet.mapping.rows.find((r) => r.itemId === 'conditionals.1.3');
    const start = text.indexOf(`---- ${row?.key}`);
    const block = text.slice(start, text.indexOf('\n\n', start));
    expect(block).toContain('Topic: Conditionals');
    expect(block).toContain('Type:  Find and correct the error');
    expect(block).toContain('Context:\n    If she would study harder for chemistry, she would pass the final examination.');
    expect(block).toContain(`Instruction:\n    ${FIX}`);
    expect(block).toContain('Hint:\n    Look at the if-part.');
    for (const [letter, id] of Object.entries(row?.letters ?? {})) expect(block).toContain(`  ${letter}) ${data.answers.find((a) => a.id === id)?.userAnswer}`);
  });

  it('is blind: no kind, no truth, no flag, no gate, no scorer, no run id', () => {
    const body = sheet.questionsText.slice(sheet.questionsText.indexOf('QUESTIONS (15)'));
    // ("Find the mistake" is the questions' own instruction.)
    expect(body.replaceAll(FIX, '')).not.toMatch(/mistake|second answer|built as|by construction|needs work|scorer|Gate|Flag|duplicate|breaks/i);
    expect(body).not.toMatch(/\bkey\b/i);
    for (const item of data.items) expect(sheet.questionsText).not.toContain(item.id);
    for (const a of data.answers) {
      expect(sheet.questionsText).not.toContain(a.id);
      expect(sheet.labelsCsv).not.toContain(a.id);
      if (a.breaks) expect(sheet.questionsText).not.toContain(a.breaks);
    }
    expect(sheet.labelsCsv).not.toMatch(/conditionals|articles/);
  });

  it('the file to fill: one row per question in the reading order, the letters a question lacks marked', () => {
    const rows = parseCsv(sheet.labelsCsv);
    expect(Object.keys(rows[0] ?? {})).toEqual([...SHEET_COLUMNS]);
    expect(rows.map((r) => r.key)).toEqual(sheet.mapping.rows.map((r) => r.key));
    rows.forEach((row, i) => {
      const letters = sheet.mapping.rows[i]?.letters ?? {};
      for (const letter of LETTERS) expect(row[letter]).toBe(letter in letters ? '' : NO_ANSWER);
      expect([row.verdict, row.why, row.note, row.also_accept]).toEqual(['', '', '', '']);
    });
    expect(sheet.labelsCsv).not.toContain("'");
    expect(sheetHeaderProblem(sheet.labelsCsv)).toBeNull();
  });
});

describe('topics sheet: reading a filled sheet', () => {
  const data = run();
  const sheet = buildTopicSheet(data.items, data.answers);
  const blank = parseCsv(sheet.labelsCsv);

  /** Every row labelled ok with every answer "right", then [edit] applied. */
  function filled(edit: (rows: Record<string, string>[]) => void = () => {}): Record<string, string>[] {
    const rows = blank.map((r) => ({ ...r, verdict: 'ok', ...Object.fromEntries(LETTERS.filter((l) => r[l] === '').map((l) => [l, 'right'])) }));
    edit(rows);
    return rows;
  }

  it('the vocabulary', () => {
    expect(VERDICTS).toEqual(['ok', 'defect']);
    expect(WHY_VALUES).toEqual(['several_answers', 'off_topic', 'bad_english', 'hint_wrong', 'level', 'other']);
    expect(ANSWER_LABELS).toEqual(['right', 'wrong', 'unsure']);
  });

  it('an untouched sheet: every row is named as unlabelled, nothing to fix', () => {
    const read = readTopicLabels(blank, sheet.mapping);
    expect(read.labels).toEqual([]);
    expect(read.problems).toEqual([]);
    expect(read.unlabelled).toEqual(sheet.mapping.rows.map((r) => r.key));
    expect(renderSheetStatus(read, 15)).toContain('Label sheet: 0 of 15 rows labelled, 15 not started, 0 with something to fix.');
  });

  it('a fully labelled sheet comes back with the answers by their run ids', () => {
    const read = readTopicLabels(
      filled((rows) => {
        Object.assign(rows[0] as Record<string, string>, { verdict: ' Defect ', why: 'several_answers; level', note: 'both fit', also_accept: 'was | were to be', A: 'WRONG', B: "'unsure" });
      }),
      sheet.mapping,
    );
    expect(read.unlabelled).toEqual([]);
    expect(read.problems).toEqual([]);
    expect(read.labels).toHaveLength(15);
    const first = read.labels[0] as (typeof read.labels)[number];
    const row = sheet.mapping.rows[0] as (typeof sheet.mapping.rows)[number];
    expect(first).toMatchObject({ key: row.key, itemId: row.itemId, verdict: 'defect', why: ['several_answers', 'level'], note: 'both fit', alsoAccept: ['was', 'were to be'] });
    expect(first.answers.get(row.letters.A as string)).toBe('wrong');
    expect(first.answers.get(row.letters.B as string)).toBe('unsure');
    expect(first.answers.size).toBe(Object.keys(row.letters).length);
    expect(renderSheetStatus(read, 15)).toBe('Label sheet: 15 of 15 rows labelled, 0 not started, 0 with something to fix.');
  });

  it('names every value outside the vocabulary, and every half-filled row', () => {
    const withLetters = (n: number) => sheet.mapping.rows.findIndex((r) => Object.keys(r.letters).length === n);
    const two = withLetters(2);
    const four = withLetters(4);
    const read = readTopicLabels(
      filled((rows) => {
        Object.assign(rows[two] as Record<string, string>, { verdict: 'fine', C: 'right' });
        Object.assign(rows[four] as Record<string, string>, { verdict: 'defect', why: '', A: 'maybe', B: '' });
      }),
      sheet.mapping,
    );
    const of = (i: number) => read.problems.filter((p) => p.key === sheet.mapping.rows[i]?.key).map((p) => p.problem);
    expect(of(two)).toEqual(['verdict "fine" (ok | defect)', 'C: the question has no answer C']);
    expect(of(four)).toEqual(['a defect without a why', 'A: "maybe" (right | wrong | unsure)', 'B: no label']);
    expect(read.labels).toHaveLength(13);
    const status = renderSheetStatus(read, 15);
    expect(status).toContain('13 of 15 rows labelled, 0 not started, 2 with something to fix.');
    expect(status).toContain(`Fix ${sheet.mapping.rows[four]?.key}: B: no label`);
  });

  it('a reason needs a defect, "other" needs a note, an unknown reason is named', () => {
    const read = readTopicLabels(
      filled((rows) => {
        Object.assign(rows[0] as Record<string, string>, { why: 'level' });
        Object.assign(rows[1] as Record<string, string>, { verdict: 'defect', why: 'other' });
        Object.assign(rows[2] as Record<string, string>, { verdict: 'defect', why: 'ambiguous' });
        Object.assign(rows[3] as Record<string, string>, { verdict: '', note: 'started' });
      }),
      sheet.mapping,
    );
    expect(read.problems.map((p) => p.problem)).toEqual([
      'a why on a row that is not a defect',
      'why "other" without a note',
      'why "ambiguous" (several_answers | off_topic | bad_english | hint_wrong | level | other)',
      'no verdict',
    ]);
  });

  it('a changed key, a doubled row and a missing row are named', () => {
    const rows = filled();
    const first = rows[0] as Record<string, string>;
    const read = readTopicLabels([{ ...first, key: '2,67981E+14' }, rows[1] as Record<string, string>, rows[1] as Record<string, string>, ...rows.slice(3)], sheet.mapping);
    expect(read.problems.map((p) => p.problem)).toEqual([
      'a key the sheet does not have (was it changed by a spreadsheet?)',
      'the key is in the file twice',
      'the row is missing from the file',
      'the row is missing from the file',
    ]);
    expect(read.problems.slice(2).map((p) => p.key)).toEqual([sheet.mapping.rows[0]?.key, sheet.mapping.rows[2]?.key]);
  });

  it('survives a round trip through the CSV writer, and says when the file is not the sheet', () => {
    const csv = toCsv(SHEET_COLUMNS, filled());
    expect(readTopicLabels(parseCsv(csv), sheet.mapping).labels).toHaveLength(15);
    expect(sheetHeaderProblem(csv)).toBeNull();
    expect(sheetHeaderProblem('key;verdict;why;note;also_accept;A;B;C;D\nk1;ok')).toContain('uses ";"');
    expect(sheetHeaderProblem('key,verdict,A,B,C,D\n')).toContain('no column why, note, also_accept');
  });
});

describe('topics sheet: the details file', () => {
  const data = run((a) => a.kind === 'variant');
  const sheet = buildTopicSheet(data.items, data.answers);
  const details = renderDetails({ ...data, verdicts: scoredAnswers(data).verdicts, mapping: sheet.mapping, runDir: 'proxy/eval/out/topics-test' });

  it('says at its top that it is not to be opened before the sheet is filled', () => {
    expect(details.split('\n').slice(0, 3).join('\n')).toContain('DO NOT OPEN THIS FILE BEFORE THE LABEL SHEET IS FILLED.');
  });

  it('per question: the sheet key, the gate, the flags, each answer with its kind, truth and the scorer', () => {
    const row = sheet.mapping.rows.find((r) => r.itemId === 'conditionals.1.4');
    const start = details.indexOf('conditionals.1.4   sheet key');
    const block = details.slice(start, details.indexOf('\n\n', start));
    expect(block).toContain(`conditionals.1.4   sheet key ${row?.key}   Conditionals, set 1, question 5   Fill in the blank`);
    expect(block).toContain('  Gate: passed');
    expect(block).toContain('  Flag [single_answer] second_answer_listed: key: were; also correct: was');
    const key = data.answers.find((a) => a.itemId === 'conditionals.1.4' && a.kind === 'key') as TopicAnswer;
    const variant = data.answers.find((a) => a.itemId === 'conditionals.1.4' && a.kind === 'variant') as TopicAnswer;
    const letter = (id: string) => Object.entries(row?.letters ?? {}).find(([, v]) => v === id)?.[0];
    expect(block).toContain(`  ${letter(key.id)}) key (built as right)\n    were\n      scorer: correct\n      corrected: corrected ${key.id}\n      explanation: explanation for ${key.id}`);
    expect(block).toContain(`  ${letter(variant.id)}) second answer (built as right)\n    was\n      scorer: needs work   <-- DIFFERS from the truth by construction`);
    expect(block).toContain('mistake 2 (built as wrong; breaks: would in the if-part)');
  });

  it('a question that failed the gate shows it, with the writer note and no answers', () => {
    const start = details.indexOf('conditionals.2.4   sheet key');
    const block = details.slice(start, details.indexOf('\n\n', start));
    expect(block).toContain('  Gate: FAILED: fill_in_blank_without_blank');
    expect(block).toContain('  Checks not run (no key): single_answer, hint_card');
    expect(block).toContain('  Writer note: key_unusable:');
    expect(block).toContain('  Built answers: none');
  });

  it('the resembling questions side by side, per topic and group, with their pairs', () => {
    const section = details.slice(details.indexOf('RESEMBLING QUESTIONS, SIDE BY SIDE'));
    expect(section).toContain('==== Articles: 0 groups ====');
    expect(section).toMatch(/-- Conditionals, group 1: \d questions, in 2 set\(s\) --/);
    expect(section).toContain('    conditionals.1.2 ~ conditionals.2.2: same words, across sets');
    expect(section).toContain('conditionals.1.2   sheet key');
    expect(section).toContain('    If it will rain tomorrow, we will cancel the picnic in the park.');
  });
});
