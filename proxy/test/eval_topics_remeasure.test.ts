import { describe, expect, it } from 'vitest';
import type { MeasureRecord } from '../eval/lib/measurement';
import { charactersPerToken } from '../eval/lib/measurement';
import { contentLeaks, renderTopicsReport, scoredAnswers, type TopicsRunData } from '../eval/lib/topics_analysis';
import { checkItems, gateSet } from '../eval/lib/topics_checks';
import {
  TOPICS_FIRST_RUN,
  TOPICS_SPEND_CAP_USD,
  answersId,
  builtAnswersFrom,
  fitsTopicsCap,
  generationCalls,
  generationId,
  measuredTopics,
  planCost,
  planTopicsDryRun,
  priorTopicsSpend,
  renderTopicsDryRun,
  scoringCalls,
  type TopicAnswer,
} from '../eval/lib/topics_measurement';
import { carryRemeasurements, mixedConditionals, remeasurementBlocks, renderRemeasurement, restrictToTopic, withRemeasurement, withoutRemeasurements, type RunForSection } from '../eval/lib/topics_remeasure';
import { LETTERS, SHEET_SEED, buildTopicSheet, readTopicLabels, type QuestionLabel } from '../eval/lib/topics_sheet';
import { parseCsv } from '../eval/lib/labels';
import { topicById } from '../src/topics';

const FIX = 'Find the mistake and rewrite the full corrected sentence.';
const NOTE = topicById('conditionals', true)?.generationNote as string;

describe('a re-measurement: one topic, a run of its own', () => {
  const ratio = charactersPerToken();

  it('--only names one measured topic, with the sets it has in the full measurement', () => {
    expect(measuredTopics('conditionals').map((t) => [t.topic.id, t.sets, t.control])).toEqual([['conditionals', 6, false]]);
    expect(measuredTopics('articles').map((t) => [t.topic.id, t.sets, t.control])).toEqual([['articles', 3, true]]);
    expect(measuredTopics()).toHaveLength(6);
    expect(() => measuredTopics('modalVerbs')).toThrow('--only modalVerbs: not a measured topic');
  });

  it('plans 6 generations with the note in each, 6 answer calls and the scoring of 6 sets', () => {
    const generation = generationCalls(ratio, 'conditionals');
    expect(generation.map((c) => c.customId)).toEqual([1, 2, 3, 4, 5, 6].map((n) => generationId('conditionals', n)));
    for (const call of generation) expect(call.body.messages[0]?.content).toContain(` ${NOTE}\nGenerate exactly 5 fresh practice items`);
    const plan = planTopicsDryRun(ratio, 'conditionals');
    expect([plan.generation.length, plan.answers.length, plan.scoring.length, plan.answerCount]).toEqual([6, 6, 24, 96]);
    expect(plan.answers.every((c) => c.group === 'conditionals')).toBe(true);
    // The full plan is what it was.
    const full = planTopicsDryRun(ratio);
    expect([full.generation.length, full.answers.length, full.scoring.length]).toEqual([33, 33, 132]);
  });

  it('the cap is on the measurement as a whole: earlier runs count as spent', () => {
    expect(TOPICS_FIRST_RUN).toEqual({ folder: 'topics-2026-11-18T16-35-34-632Z', spendUsd: 0.77 });
    // The first run's folder is there: its measured spend is what counts.
    expect(priorTopicsSpend([{ name: TOPICS_FIRST_RUN.folder, spendUsd: 0.7636 }])).toBeCloseTo(0.7636, 10);
    expect(priorTopicsSpend([{ name: TOPICS_FIRST_RUN.folder, spendUsd: 0.7636 }, { name: 'topics-conditionals-2026-11-19T09-00-00-000Z', spendUsd: 0.1 }])).toBeCloseTo(0.8636, 10);
    // It is not there: its known spend stands in, so the cap never forgets it.
    expect(priorTopicsSpend([])).toBe(0.77);
    expect(priorTopicsSpend([{ name: 'topics-conditionals-2026-11-19T09-00-00-000Z', spendUsd: 0.1 }])).toBeCloseTo(0.87, 10);
    // The check before a call, with the earlier runs counted in.
    const prior = 0.7636;
    expect(fitsTopicsCap(prior + 0, 0.02)).toBe(true);
    expect(fitsTopicsCap(prior + 14.2, 0.02)).toBe(true);
    expect(fitsTopicsCap(prior + 14.22, 0.02)).toBe(false);
    expect(TOPICS_SPEND_CAP_USD).toBe(15);
  });

  it('the dry run names the topic, the calls, the estimate and what the measurement has spent', () => {
    const plan = planTopicsDryRun(ratio, 'conditionals');
    const summary = renderTopicsDryRun(plan, ratio, { only: 'conditionals', priorSpendUsd: 0.7636 });
    expect(summary.totalCalls).toBe(36);
    expect(summary.withinLimit).toBe(true);
    expect(summary.totalUsd).toBeCloseTo(planCost([...plan.generation, ...plan.answers, ...plan.scoring]), 10);
    expect(summary.text).toContain('First-wave topics measurement, conditionals only (a re-measurement) — dry run (no API call)');
    expect(summary.text).toContain('Topics: conditionals × 6.');
    expect(summary.text).toContain('6 sets of 5 = 30 questions; at most 96 built answers to score.');
    expect(summary.text).toContain('| generation | Topic Practice sets, the live practice path | claude-sonnet-5-5 | 6 |');
    expect(summary.text).toContain('| scoring | the production scoring cell (C8), one set\'s questions a call | claude-haiku-5-5 | 24 |');
    expect(summary.text).toContain(`earlier runs spent $0.76, so this run starts at $0.76 spent and may add $14.24. With this estimate the measurement comes to $${(0.7636 + summary.totalUsd).toFixed(2)} of $15.00.`);
    expect(summary.text).toContain(`with the earlier runs $${(0.7636 + summary.worstCaseUsd).toFixed(2)} (under the cap)`);
  });

  it('an estimate that does not fit under the cap with the earlier runs is said to be over', () => {
    const plan = planTopicsDryRun(ratio, 'conditionals');
    const summary = renderTopicsDryRun(plan, ratio, { only: 'conditionals', priorSpendUsd: 14.9 });
    expect(summary.withinLimit).toBe(false);
    expect(summary.text).toContain('OVER the cap with the margin');
    // The full dry run says nothing about earlier runs.
    expect(renderTopicsDryRun(planTopicsDryRun(ratio), ratio).text).not.toContain('earlier runs');
  });
});

// ---------------------------------------------------------------------------
// A made-up first run (Conditionals and the control) and a made-up
// re-measurement (Conditionals only).

function generated(topicId: string, set: number, mixed: boolean): unknown {
  const place = `${topicId === 'conditionals' ? 'harbour' : 'airport'} ${['north', 'south'][set - 1]}`;
  return {
    items: [
      { id: 'sw1', type: 'sentence_writing', context: `You are telling a friend about the ${place} festival.`, instruction: 'Write one sentence with "if".' },
      { id: 'sw2', type: 'sentence_writing', context: `You are planning a visit to the ${place} museum.`, instruction: 'Write one sentence about what you will do if it rains.' },
      { id: 'ec1', type: 'error_correction', context: `If it will rain near the ${place}, we will cancel the picnic.`, instruction: FIX },
      { id: 'ec2', type: 'error_correction', context: `If she would study near the ${place}, she would pass the examination.`, instruction: FIX },
      mixed
        ? { id: 'fb', type: 'fill_in_blank', instruction: `If I ____ (take) the ${place} train yesterday, I ____ (be) at home now.`, hint: 'This is a mixed conditional.' }
        : { id: 'fb', type: 'fill_in_blank', instruction: `If I ____ you at the ${place}, I would apologise to the whole team.` },
    ],
  };
}

function written(items: readonly { id: string; type: string; context?: string; blanks: number }[]): unknown {
  return {
    answers: items.map((i) =>
      i.type === 'fill_in_blank'
        ? i.blanks === 2
          ? { itemId: i.id, key: ['had taken', 'would be'], variant: [], mistakes: [{ answer: ['took', 'would be'], breaks: 'past simple for a past condition' }, { answer: ['had taken', 'will be'], breaks: 'will after an unreal condition' }] }
          : { itemId: i.id, key: ['were'], variant: ['was'], mistakes: [{ answer: ['am'], breaks: 'present form' }, { answer: ['would be'], breaks: 'would in the if-part' }] }
        : i.type === 'error_correction'
          ? { itemId: i.id, key: [(i.context ?? '').replace(' will rain', ' rains').replace(' would study', ' studied')], variant: [], mistakes: [{ answer: [i.context ?? ''], breaks: 'left as it was' }, { answer: [(i.context ?? '').replace('If ', 'When if ')], breaks: 'two conjunctions' }] }
          : { itemId: i.id, key: ['If it rains, I will stay at home and revise my notes.'], variant: [], mistakes: [{ answer: ['If it will rain, I will stay at home and revise my notes.'], breaks: 'will in the if-part' }] },
    ),
  };
}

function run(sets: readonly [string, number, boolean][], scorerWrongOn: (a: TopicAnswer) => boolean = () => false): TopicsRunData {
  const records: MeasureRecord[] = [];
  const gates = sets.map(([topicId, set, mixed]) => {
    const content = generated(topicId, set, mixed);
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
      const isCorrect = scorerWrongOn(a) ? !a.truth : a.truth;
      return { itemId: id, isCorrect, correctedAnswer: `corrected ${id}`, explanation: `explanation for ${id}`, summary: 's', blanks: Array.from({ length: a.fills?.length ?? 1 }, (_, index) => ({ index, correctAnswer: 'x', accepted: isCorrect, note: 'n' })) };
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

/** Every question ok, every answer labelled as it was built; through the real sheet. */
function labelled(data: TopicsRunData, seed = SHEET_SEED): { labels: QuestionLabel[]; keys: string[] } {
  const sheet = buildTopicSheet(data.items, data.answers, seed);
  const byId = new Map(data.answers.map((a) => [a.id, a]));
  const rows = parseCsv(sheet.labelsCsv).map((row, i) => {
    const mapped = sheet.mapping.rows[i] as (typeof sheet.mapping.rows)[number];
    return { ...row, verdict: 'ok', ...Object.fromEntries(LETTERS.filter((l) => mapped.letters[l] !== undefined).map((l) => [l, byId.get(mapped.letters[l] as string)?.truth ? 'right' : 'wrong'])) };
  });
  const read = readTopicLabels(rows, sheet.mapping);
  expect(read.problems).toEqual([]);
  return { labels: read.labels, keys: sheet.mapping.rows.map((r) => r.key) };
}

// The first run: two Conditionals sets with a mixed-conditional question each, and a control set.
const firstData = run([['conditionals', 1, true], ['conditionals', 2, true], ['articles', 1, false]], (a) => a.kind === 'mistake2' && a.fills?.length === 2);
// The re-measurement: two Conditionals sets, no mixed conditional.
const againData = run([['conditionals', 1, false], ['conditionals', 2, false]]);
const section = (r: TopicsRunData, labels: QuestionLabel[] | null, runDir: string): RunForSection => ({ data: r, verdicts: scoredAnswers(r).verdicts, labels, runDir });
const meta = { topicId: 'conditionals', generatedAt: '2026-11-19 10:00 UTC', wallSeconds: 95, priorSpendUsd: 0.7636, findings: null };

describe('a re-measurement: its section of the report', () => {
  it('restrictToTopic keeps one topic of a run, its calls included', () => {
    const only = restrictToTopic(firstData, 'conditionals');
    expect(only.items).toHaveLength(10);
    expect(only.sets).toHaveLength(2);
    expect(only.answers.every((a) => a.topicId === 'conditionals')).toBe(true);
    expect(only.checks).toHaveLength(10);
    expect(only.records.filter((r) => r.stage === 'generation')).toHaveLength(2);
    const scored = new Set(only.scoringCalls.flatMap((c) => c.answerIds));
    expect(scored.size).toBe(only.answers.length);
    expect(only.records.filter((r) => r.stage === 'scoring')).toHaveLength(only.scoringCalls.length);
    expect(restrictToTopic(firstData, 'articles').items).toHaveLength(5);
  });

  it('counts the mixed conditionals: marked by the hint-card check, and named in the question', () => {
    const before = restrictToTopic(firstData, 'conditionals');
    expect(mixedConditionals(before.items, before.checks)).toEqual({ questions: 10, flagged: 2, named: 2, notRun: 0 });
    expect(mixedConditionals(againData.items, againData.checks)).toEqual({ questions: 10, flagged: 0, named: 0, notRun: 0 });
  });

  const unlabelled = renderRemeasurement({ ...meta, run: section(againData, null, 'proxy/eval/out/topics-conditionals-test'), first: section(firstData, labelled(firstData).labels, 'proxy/eval/out/topics-first'), sheet: { questions: 10, answers: 28, labelled: 0, withProblems: 0 } });

  it('before the labels: says it is the result that counts, that there is none yet, and what changed', () => {
    expect(unlabelled).toContain('# Re-measurement: Conditionals');
    expect(unlabelled).toContain('**Status: measured, not yet labelled.**');
    expect(unlabelled).toContain('`proxy/eval/out/topics-conditionals-test`');
    expect(unlabelled).toContain('**This is the Conditionals result that counts.** Its label sheet is not filled yet, so there is no result yet');
    expect(unlabelled).toContain(`a generation-only note that is not sent to or shown in the app: "${NOTE}" Nothing else in any prompt changed`);
    expect(unlabelled).not.toContain('The pass criteria');
  });

  it('says how many questions the hint-card check still marks as a mixed conditional, next to the first run', () => {
    expect(unlabelled).toContain('## R1. Did the note keep mixed conditionals out');
    expect(unlabelled).toContain('| Re-measurement | 10 | 0 | 0 | 0 |');
    expect(unlabelled).toContain('| First run | 10 | 2 | 2 | 0 |');
  });

  it('has what ran with the whole measurement\'s spend, the gate, the answers, the checks, the duplicates, the scorer and the sheet', () => {
    expect(unlabelled).toContain('earlier runs spent $0.76, this run $0.05, together **$0.81** of $15.00; 0 calls skipped for the cap, 0 failed. The run took 1 min 35 s.');
    expect(unlabelled).toContain('| Re-measurement | 2 | 100.0 % (2 / 2) | 10 | 100.0 % (10 / 10) | 10 of 10 | 28 (10 / 2 / 16) |');
    expect(unlabelled).toContain('| Hint card against the key | 0.0 % (0 / 10) | 20.0 % (2 / 10) |');
    expect(unlabelled).toContain('## R5. Duplicates inside the run');
    expect(unlabelled).toContain('| Re-measurement | by construction | 28 | 28 | 100.0 % (28 / 28) | 0.0 % (0 / 16) | 0.0 % (0 / 12) |');
    // The first run's row is its Conditionals only, by construction and by its labels.
    expect(unlabelled).toContain('| First run | by construction | 26 | 26 | 92.3 % (24 / 26) | 12.5 % (2 / 16) | 0.0 % (0 / 10) |');
    expect(unlabelled).toContain('| First run | **by the labels** | 26 | 26 | 92.3 % (24 / 26) | 12.5 % (2 / 16) | 0.0 % (0 / 10) |');
    expect(unlabelled).toContain('**not to be opened before the sheet is filled**');
    expect(unlabelled).toContain('0 of 10 rows labelled.');
  });

  it('once labelled: the pass criteria of the re-measurement, the first run beside them', () => {
    const done = renderRemeasurement({ ...meta, run: section(againData, labelled(againData, SHEET_SEED + 1).labels, 'proxy/eval/out/topics-conditionals-test'), first: section(firstData, labelled(firstData).labels, 'proxy/eval/out/topics-first'), sheet: { questions: 10, answers: 28, labelled: 10, withProblems: 0 } });
    expect(done).toContain('**Status: measured and labelled.**');
    expect(done).toContain('Conditionals **passes** all three criteria in the re-measurement (R1).');
    expect(done).toContain('## R1. The pass criteria');
    expect(done).toContain('| Re-measurement (the result that counts) | 0.0 % (0 / 10): **pass** | 100.0 % (28 / 28): **pass** | 0.0 % (0 / 16): **pass** | **passes** |');
    expect(done).toContain('| First run | 0.0 % (0 / 10): **pass** | 92.3 % (24 / 26): **FAIL** | 12.5 % (2 / 16): **FAIL** | **fails** |');
    expect(done).toContain('| Re-measurement | **by the labels** | 28 | 28 | 100.0 % (28 / 28) | 0.0 % (0 / 16) | 0.0 % (0 / 12) |');
    expect(done).toContain('The questions: defects and notes');
    expect(done).toContain('open now that the sheet is filled, and `second-look.md` for the owner');
  });

  it('without the first run\'s folder there are no comparison rows; findings are added when there are some', () => {
    const alone = renderRemeasurement({ ...meta, findings: '### What it shows\n\nIn words.', run: section(againData, null, 'x'), first: null, sheet: { questions: 10, answers: 28, labelled: 0, withProblems: 0 } });
    expect(alone).not.toContain('| First run |');
    expect(alone).toMatch(/## R\d+\. Findings\n\n### What it shows\n\nIn words\./);
  });

  it('holds counts and rates only: no question, no answer and no sheet key of either run', () => {
    const { keys } = labelled(againData, SHEET_SEED + 1);
    expect(contentLeaks(unlabelled, againData.items, againData.answers, keys)).toEqual([]);
    expect(contentLeaks(unlabelled, firstData.items, firstData.answers, labelled(firstData).keys)).toEqual([]);
  });
});

describe('a re-measurement: kept in the report', () => {
  const first = renderTopicsReport(firstData, { runDir: 'proxy/eval/out/topics-first', generatedAt: '2026-11-18 17:38 UTC', wallSeconds: 60, sheet: { questions: 15, answers: 42, labelled: 0, withProblems: 0 } });
  const sectionText = '# Re-measurement: Conditionals\n\nFirst version.';

  it('goes after the first run\'s part, which is otherwise untouched, with one line under the status', () => {
    const report = withRemeasurement(first, 'conditionals', sectionText);
    expect(withoutRemeasurements(report)).toBe(first);
    expect(report.indexOf('# Re-measurement: Conditionals')).toBeGreaterThan(report.indexOf('What comes next'));
    const lines = report.split('\n');
    const status = lines.findIndex((l) => l.startsWith('**Status:'));
    expect(lines[status + 2]).toBe('<!-- topics-remeasurement:pointer:start -->');
    expect(lines[status + 3]).toBe('**Measured again after a fix: Conditionals.** The result that counts for that topic is in "Re-measurement: Conditionals" at the end of this report; the rows of the first run below are kept as they were measured.');
    expect(remeasurementBlocks(report)).toEqual([{ topicId: 'conditionals', text: `<!-- topics-remeasurement:conditionals:start -->\n${sectionText}\n<!-- topics-remeasurement:conditionals:end -->` }]);
    expect(report.endsWith('<!-- topics-remeasurement:conditionals:end -->\n')).toBe(true);
  });

  it('a newer version of the section replaces the older one; writing the same again changes nothing', () => {
    const once = withRemeasurement(first, 'conditionals', sectionText);
    expect(withRemeasurement(once, 'conditionals', sectionText)).toBe(once);
    const newer = withRemeasurement(once, 'conditionals', '# Re-measurement: Conditionals\n\nSecond version.');
    expect(newer).toContain('Second version.');
    expect(newer).not.toContain('First version.');
    expect(remeasurementBlocks(newer)).toHaveLength(1);
    expect(newer.match(/topics-remeasurement:pointer:start/g)).toHaveLength(1);
  });

  it('another topic\'s section stands beside it, and the line under the status names both', () => {
    const both = withRemeasurement(withRemeasurement(first, 'conditionals', sectionText), 'comparativesSuperlatives', '# Re-measurement: Comparatives & Superlatives\n\nIts own.');
    expect(remeasurementBlocks(both).map((b) => b.topicId)).toEqual(['conditionals', 'comparativesSuperlatives']);
    expect(both).toContain('**Measured again after a fix: Conditionals, Comparatives & Superlatives.**');
    expect(withoutRemeasurements(both)).toBe(first);
  });

  it('analysing the first run again keeps the sections it had', () => {
    const old = withRemeasurement(first, 'conditionals', sectionText);
    const rewritten = first.replace('2026-11-18 17:38 UTC', '2026-11-20 08:00 UTC');
    const carried = carryRemeasurements(old, rewritten);
    expect(withoutRemeasurements(carried)).toBe(rewritten);
    expect(remeasurementBlocks(carried)).toEqual(remeasurementBlocks(old));
    expect(carried).toContain('**Measured again after a fix: Conditionals.**');
    // A report that never had one is written as it is.
    expect(carryRemeasurements(first, rewritten)).toBe(rewritten);
  });
});
