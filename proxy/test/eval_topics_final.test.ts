import { describe, expect, it } from 'vitest';
import { practiceThemeLine } from '../src/anthropic';
import { practiceTheme } from '../src/practice_theme';
import { GENERATION_SYSTEM_PROMPT, SCORING_SYSTEM_PROMPT, SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11 } from '../src/prompts';
import { SCENARIO_THEMES } from '../src/shared_daily_test';
import { FIRST_WAVE_TOPICS, TOPICS, topicById } from '../src/topics';
import type { MeasureRecord } from '../eval/lib/measurement';
import { charactersPerToken } from '../eval/lib/measurement';
import { contentLeaks, type AnswerVerdict, type TopicsRunData } from '../eval/lib/topics_analysis';
import { checkItems } from '../eval/lib/topics_checks';
import {
  FINAL_DAY,
  addComparisons,
  comparePrompts,
  givenBackUnchanged,
  finalGenerationBody,
  finalGenerationCalls,
  finalScoringCalls,
  finalTheme,
  finalTopics,
  guardedSet,
  isLabelledSet,
  planFinalDryRun,
  renderFinalDryRun,
  renderFinalSection,
  renderRescoreSection,
  rescoreCalls,
  type RescoreSource,
} from '../eval/lib/topics_final';
import { answersId, builtAnswersFrom, generationId, placeholderAnswers, placeholderItems, scoringCalls, type TopicAnswer } from '../eval/lib/topics_measurement';
import { laterSectionName, remeasurementBlocks, withRemeasurement, withoutRemeasurements } from '../eval/lib/topics_remeasure';
import { LETTERS, buildTopicSheet, readTopicLabels, topicsOf, type QuestionLabel } from '../eval/lib/topics_sheet';
import { parseCsv } from '../eval/lib/labels';

const FIX = 'Find the mistake and rewrite the full corrected sentence.';
const ratio = charactersPerToken();

describe('topics final: what is measured', () => {
  it('all ten topics, six sets each; the five new ones labelled on all six, the five live ones on three', () => {
    const topics = finalTopics();
    expect(topics.map((t) => t.topic.id)).toEqual([...FIRST_WAVE_TOPICS, ...TOPICS].map((t) => t.id));
    expect(topics.filter((t) => t.newTopic).map((t) => [t.sets, t.labelledSets])).toEqual(Array.from({ length: 5 }, () => [6, 6]));
    expect(topics.filter((t) => !t.newTopic).map((t) => [t.sets, t.labelledSets])).toEqual(Array.from({ length: 5 }, () => [6, 3]));
    expect(isLabelledSet('conditionals', 6)).toBe(true);
    expect(isLabelledSet('articles', 3)).toBe(true);
    expect(isLabelledSet('articles', 4)).toBe(false);
    expect(isLabelledSet('notATopic', 1)).toBe(false);
    // 150 + 75 questions at most on the sheet.
    expect(topics.reduce((n, t) => n + t.labelledSets * 5, 0)).toBe(225);
  });

  it('the themes are stepped as one device\'s consecutive sessions would get them: six different ones per topic', () => {
    for (const { topic } of finalTopics()) {
      const themes = [1, 2, 3, 4, 5, 6].map((set) => finalTheme(topic.id, set));
      expect(new Set(themes).size).toBe(6);
      for (const [i, theme] of themes.entries()) {
        expect(SCENARIO_THEMES).toContain(theme);
        // A session is a generation and a scoring: the count moves on by two.
        expect(theme).toBe(practiceTheme(`measurement-${topic.id}`, FINAL_DAY, 2 * i));
      }
    }
    // The topics do not all start at the same theme.
    expect(new Set(finalTopics().map((t) => finalTheme(t.topic.id, 1))).size).toBeGreaterThan(3);
  });

  it('generation is the final request: the line on blanks, the set\'s theme, and the Conditionals note', () => {
    for (const { topic } of finalTopics()) {
      const body = finalGenerationBody(topic.id, 2);
      expect(body.system).toBe(GENERATION_SYSTEM_PROMPT);
      expect(body.system).toContain('1 to 4 blanks');
      const lines = body.messages[0]?.content.split('\n') ?? [];
      expect(lines).toHaveLength(3);
      expect(lines[2]).toBe(practiceThemeLine(finalTheme(topic.id, 2)));
      expect(lines[0]?.endsWith(topic.generationNote ?? topic.description)).toBe(true);
    }
    expect(finalGenerationBody('conditionals', 1).messages[0]?.content).toContain('no mixed conditional');
    const calls = finalGenerationCalls(ratio);
    expect(calls).toHaveLength(60);
    expect(new Set(calls.map((c) => c.customId)).size).toBe(60);
    expect(calls[0]?.customId).toBe(generationId('conditionals', 1));
    // Two sets of one topic are no longer the same request.
    expect(calls[0]?.body).not.toEqual(calls[1]?.body);
  });

  it('the worker\'s guard is applied to each response before the gate', () => {
    const content = {
      items: [
        { id: 'a', type: 'sentence_writing', context: 'A situation.', instruction: 'Write one sentence with "if".' },
        { id: 'b', type: 'sentence_writing', context: 'Another one.', instruction: 'Write one sentence with "unless".' },
        { id: 'c', type: 'error_correction', context: 'If it will rain, we stay home.', instruction: FIX },
        { id: 'd', type: 'error_correction', context: 'If I would know, I would tell you.', instruction: FIX },
        { id: 'e', type: 'fill_in_blank', instruction: 'If I (know), I (tell) you.' },
      ],
    };
    const guarded = guardedSet('conditionals', 1, content);
    expect([guarded.received, guarded.removed, guarded.rejected]).toEqual([5, 1, false]);
    expect(guarded.gate.items.map((i) => i.sourceId)).toEqual(['a', 'b', 'c', 'd']);
    // What is left has no item the gate faults, but the set is a question short.
    expect(guarded.gate.problems).toEqual(['wrong_count:4']);
    const empty = guardedSet('conditionals', 2, { items: [content.items[4]] });
    expect([empty.removed, empty.rejected, empty.gate.items.length]).toEqual([1, true, 0]);
    expect(guardedSet('conditionals', 3, 'not a set')).toMatchObject({ received: null, removed: 0, rejected: false });
  });
});

describe('topics final: the plan and both dry runs', () => {
  const plan = planFinalDryRun(ratio);
  const source: RescoreSource = (() => {
    const answers = placeholderAnswers([...placeholderItems('conditionals', 1), ...placeholderItems('conditionals', 2)]);
    return { tag: 'a', folder: 'topics-first', answers, scoringCalls: scoringCalls(answers).map((s) => ({ customId: s.call.customId, answerIds: s.answerIds })) };
  })();
  const rescore = rescoreCalls([source], ratio);

  it('60 generations, 45 answer calls, and the scoring of 45 sets twice', () => {
    expect([plan.generation.length, plan.answers.length, plan.scoring.length, plan.scoringCandidate.length, plan.answerCount]).toEqual([60, 45, 180, 180, 720]);
    expect(plan.scoring.every((c) => c.body.system === SCORING_SYSTEM_PROMPT && c.customId.startsWith('tscore_'))).toBe(true);
    expect(plan.scoringCandidate.every((c) => c.body.system === SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11 && c.customId.startsWith('tscoreC_'))).toBe(true);
    const ids = [...plan.generation, ...plan.answers, ...plan.scoring, ...plan.scoringCandidate].map((c) => c.customId);
    expect(new Set(ids).size).toBe(465);
  });

  it('every built answer is scored twice, in the same calls, the prompt the only difference', () => {
    const answers = placeholderAnswers(placeholderItems('conditionals', 1));
    const { production, candidate } = finalScoringCalls(answers, ratio);
    expect(candidate.map((c) => c.answerIds)).toEqual(production.map((c) => c.answerIds));
    production.forEach((p, i) => {
      const c = candidate[i]?.call;
      expect(c?.body.messages).toEqual(p.call.body.messages);
      expect({ ...c?.body, system: p.call.body.system }).toEqual(p.call.body);
      expect(c?.customId).toBe(p.call.customId.replace('tscore_', 'tscoreC_'));
    });
  });

  it('topics rescore: every stored scoring call again, the same answers in the same order, the candidate prompt', () => {
    expect(rescore).toHaveLength(source.scoringCalls.length);
    rescore.forEach((r, i) => {
      const original = source.scoringCalls[i] as (typeof source.scoringCalls)[number];
      expect(r.call.customId).toBe(`rescore_a_${original.customId}`);
      expect(r.answerIds).toEqual(original.answerIds);
      expect(r.source).toBe('a');
      expect(r.call.body.system).toBe(SCORING_SYSTEM_PROMPT_CANDIDATE_2026_11);
      expect((JSON.parse(r.call.body.messages[0]?.content ?? '{}') as { items: { id: string }[] }).items.map((x) => x.id)).toEqual(original.answerIds);
    });
    // A call whose answers are not in the source is left out; two sources keep their tags apart.
    expect(rescoreCalls([{ ...source, scoringCalls: [{ customId: 'tscore_x', answerIds: ['nope'] }] }], ratio)).toEqual([]);
    const two = rescoreCalls([source, { ...source, tag: 'b', folder: 'topics-conditionals-x' }], ratio);
    expect(new Set(two.map((r) => r.call.customId)).size).toBe(2 * source.scoringCalls.length);
  });

  it('the dry run shows both commands, their calls and estimates, and the measurement as a whole', () => {
    const summary = renderFinalDryRun(plan, rescore, [source], 0.8936, ratio, 'final');
    expect(summary.finalCalls).toBe(465);
    expect(summary.rescoreCalls).toBe(rescore.length);
    expect(summary.withinLimit).toBe(true);
    expect(summary.text).toContain('the final configuration (topics final) — dry run (no API call)');
    expect(summary.text).toContain('60 sets generated with the final request, a theme per set; 45 sets (225 questions at most) get answers, scoring and labels; at most 720 built answers, each scored twice.');
    expect(summary.text).toContain('| generation | Topic Practice sets, the final request | claude-sonnet-5-5 | 60 |');
    expect(summary.text).toContain('| scoring | the candidate scoring prompt | claude-haiku-5-5 | 180 |');
    expect(summary.text).toContain(`| **Total** | | | **465** | | | | **$${summary.finalUsd.toFixed(2)}** |`);
    expect(summary.text).toContain(`topics-first: ${source.answers.length}`);
    expect(summary.text).toContain(`together $${(summary.finalUsd + summary.rescoreUsd).toFixed(2)}: within the dry-run limit of $12.00.`);
    expect(summary.text).toContain(`earlier runs spent $0.89; with both commands the measurement comes to $${(0.8936 + summary.finalUsd + summary.rescoreUsd).toFixed(2)} of $15.00.`);
    expect(summary.text.indexOf('## topics final')).toBeLessThan(summary.text.indexOf('## topics rescore'));
    // For the other command the same numbers, its own block first.
    const other = renderFinalDryRun(plan, rescore, [source], 0.8936, ratio, 'rescore');
    expect(other.text.indexOf('## topics rescore')).toBeLessThan(other.text.indexOf('## topics final'));
    expect([other.finalUsd, other.rescoreUsd]).toEqual([summary.finalUsd, summary.rescoreUsd]);
  });

  it('both commands together must leave the cap room', () => {
    const tight = renderFinalDryRun(plan, rescore, [source], 13, ratio, 'final');
    expect(tight.withinLimit).toBe(false);
    expect(tight.text).toContain('OVER the cap with the margin');
  });
});

// ---------------------------------------------------------------------------
// A made-up final run: one new topic and one live topic, one set each.

function setOf(topicId: string): unknown {
  const place = topicId === 'conditionals' ? 'harbour' : 'airport';
  return {
    items: [
      { id: 'sw1', type: 'sentence_writing', context: `You are telling a friend about the ${place} festival.`, instruction: 'Write one sentence with "if".' },
      { id: 'sw2', type: 'sentence_writing', context: `You are planning a visit to the ${place} museum.`, instruction: 'Write one sentence about what you will do if it rains.' },
      { id: 'ec1', type: 'error_correction', context: `If it will rain near the ${place}, we will cancel the picnic.`, instruction: FIX },
      { id: 'ec2', type: 'error_correction', context: `If she would study near the ${place}, she would pass the examination.`, instruction: FIX },
      { id: 'fb', type: 'fill_in_blank', instruction: topicId === 'conditionals' ? 'If I (be) you, I (apologise).' : `If I ____ you at the ${place}, I would apologise to the whole team.` },
    ],
  };
}

function made(): { data: TopicsRunData; guard: { topicId: string; set: number; received: number | null; removed: number; rejected: boolean }[]; production: Map<string, AnswerVerdict>; candidate: Map<string, AnswerVerdict> } {
  const records: MeasureRecord[] = [];
  const guard = [];
  const items = [];
  const answers: TopicAnswer[] = [];
  for (const topicId of ['conditionals', 'articles']) {
    const g = guardedSet(topicId, 1, setOf(topicId));
    guard.push({ topicId, set: 1, received: g.received, removed: g.removed, rejected: g.rejected });
    items.push(...g.gate.items);
    records.push({ customId: generationId(topicId, 1), stage: 'generation', group: topicId, model: 'claude-sonnet-5-5', status: 'ok', costUsd: 0.008, durationMs: 5000 });
    records.push({ customId: answersId(topicId, 1), stage: 'answers', group: topicId, model: 'claude-sonnet-5-5', status: 'ok', costUsd: 0.01, durationMs: 6000 });
    const written = {
      answers: g.gate.items.map((i) =>
        i.type === 'fill_in_blank'
          ? { itemId: i.id, key: ['were'], variant: [], mistakes: [{ answer: ['am'], breaks: 'present form' }, { answer: ['would be'], breaks: 'would in the if-part' }] }
          : i.type === 'error_correction'
            ? { itemId: i.id, key: [(i.context ?? '').replace(' will rain', ' rains').replace(' would study', ' studied')], variant: [], mistakes: [{ answer: [i.context ?? ''], breaks: 'left as it was' }, { answer: [(i.context ?? '').replace('If ', 'When if ')], breaks: 'two conjunctions' }] }
            : { itemId: i.id, key: ['If it rains, I will stay at home and revise my notes.'], variant: [], mistakes: [{ answer: ['If it will rain, I will stay at home and revise my notes.'], breaks: 'will in the if-part' }] },
      ),
    };
    answers.push(...builtAnswersFrom(g.gate.items, written).answers);
  }
  const { production: p, candidate: c } = finalScoringCalls(answers);
  for (const call of p) records.push({ customId: call.call.customId, stage: 'scoring', group: 'C8', model: 'claude-haiku-5-5', status: 'ok', costUsd: 0.0014, durationMs: 10_000 });
  for (const call of c) records.push({ customId: call.call.customId, stage: 'scoring', group: 'C8 candidate', model: 'claude-haiku-5-5', status: 'ok', costUsd: 0.0016, durationMs: 11_000 });
  const verdict = (a: TopicAnswer, isCorrect: boolean): [string, AnswerVerdict] => [a.id, { answerId: a.id, isCorrect, correctedAnswer: '', explanation: '' }];
  // Production calls one Conditionals mistake correct; the candidate does not,
  // but rejects one right key of the live topic.
  const slip = answers.find((a) => a.topicId === 'conditionals' && a.kind === 'mistake1') as TopicAnswer;
  const strict = answers.find((a) => a.topicId === 'articles' && a.kind === 'key') as TopicAnswer;
  return {
    data: { records, sets: [], items, answers, answerProblems: [], scoringCalls: p.map((s) => ({ customId: s.call.customId, answerIds: s.answerIds })), checks: checkItems(items, answers) },
    guard,
    production: new Map(answers.map((a) => verdict(a, a === slip ? true : a.truth))),
    candidate: new Map(answers.map((a) => verdict(a, a === strict ? false : a.truth))),
  };
}

function labelsOf(data: TopicsRunData): QuestionLabel[] {
  const sheet = buildTopicSheet(data.items, data.answers);
  const byId = new Map(data.answers.map((a) => [a.id, a]));
  const rows = parseCsv(sheet.labelsCsv).map((row, i) => {
    const mapped = sheet.mapping.rows[i] as (typeof sheet.mapping.rows)[number];
    return { ...row, verdict: 'ok', ...Object.fromEntries(LETTERS.filter((l) => mapped.letters[l] !== undefined).map((l) => [l, byId.get(mapped.letters[l] as string)?.truth ? 'right' : 'wrong'])) };
  });
  const read = readTopicLabels(rows, sheet.mapping);
  expect(read.problems).toEqual([]);
  return read.labels;
}

describe('the scoring prompt candidate against the labels', () => {
  const m = made();
  const labels = labelsOf(m.data);
  const of = (topicId: string) => m.data.answers.filter((a) => a.topicId === topicId);

  it('compares the two prompts on the same answers and counts the verdicts that changed', () => {
    const cond = comparePrompts(of('conditionals'), labels, m.production, m.candidate);
    // Four questions served (the one without a blank was removed): 2 × 2 + 2 × 3 answers; the live topic has 3 more for its blank item.
    expect(cond.production.compared).toBe(10);
    expect([cond.production.falseCorrect, cond.candidate.falseCorrect]).toEqual([1, 0]);
    expect([cond.changed, cond.changedToRight, cond.changedToWrong]).toEqual([1, 1, 0]);
    const live = comparePrompts(of('articles'), labels, m.production, m.candidate);
    expect([live.production.falseNeedsWork, live.candidate.falseNeedsWork]).toEqual([0, 1]);
    expect([live.changed, live.changedToRight, live.changedToWrong]).toEqual([1, 0, 1]);
    // An answer only one prompt scored is in neither side.
    const fewer = new Map([...m.candidate].slice(1));
    expect(comparePrompts(of('conditionals'), labels, m.production, fewer).production.compared).toBe(9);
  });

  it('the rescore section: per run and topic, before and after, counts and rates only', () => {
    const text = renderRescoreSection({ runs: [{ name: 'First run', answers: m.data.answers, labels, production: m.production, candidate: m.candidate }], generatedAt: '2026-11-19 10:00 UTC', runDir: 'proxy/eval/out/topics-rescore-test', calls: 8, failed: 0, spendUsd: 0.2, priorSpendUsd: 0.8936 });
    expect(text).toContain('# The scoring prompt candidate on the labelled answers');
    expect(text).toContain('8 calls, $0.20; the measurement as a whole has then spent $1.09 of $15.00');
    expect(text).toContain('It is not the production prompt; whether it becomes one is the owner\'s decision.');
    expect(text).toContain('| First run | Conditionals | 10 | 90.0 % (9 / 10) → 100.0 % (10 / 10) | 16.7 % (1 / 6) → 0.0 % (0 / 6) | 0.0 % (0 / 4) → 0.0 % (0 / 4) | 1 (1 / 0) |');
    expect(text).toContain('| First run | Articles | 13 | 100.0 % (13 / 13) → 92.3 % (12 / 13) | 0.0 % (0 / 8) → 0.0 % (0 / 8) | 0.0 % (0 / 5) → 20.0 % (1 / 5) | 1 (0 / 1) |');
    expect(text).toContain('| First run | **All topics of the run** | 23 |');
    expect(contentLeaks(text, m.data.items, m.data.answers)).toEqual([]);
  });
});

describe('the final configuration section', () => {
  const m = made();
  const base = { data: m.data, guard: m.guard, production: m.production, candidate: m.candidate, first: null, runDir: 'proxy/eval/out/topics-final-test', generatedAt: '2026-11-20 09:00 UTC', wallSeconds: 300, priorSpendUsd: 0.8936, findings: null };

  it('before the labels: what is measured, the guard, the duplicates, both prompts by construction, and no result', () => {
    const text = renderFinalSection({ ...base, labels: null, sheet: { questions: 9, answers: 24, labelled: 0, withProblems: 0 } });
    expect(text).toContain('# Final configuration');
    expect(text).toContain('**Status: measured, not yet labelled.**');
    expect(text).toContain('**Its label sheet is not filled yet, so there is no result yet.**');
    expect(text).toContain(practiceThemeLine('…'));
    expect(text).not.toContain('The pass criteria');
    // The guard removed the Conditionals item without a blank.
    expect(text).toContain('| Conditionals | 1 of 6 | 5 | 1 | 1 | 4 | 0 |');
    expect(text).toContain('| Articles (live) | 1 of 6 | 5 | 0 | 0 | 5 | 0 |');
    expect(text).toContain('The guard would remove **1 of 10** items the model returned');
    expect(text).toContain('| Passive Voice | not measured | – | – | – | 0 / 0 / 0 / 0 |');
    expect(text).toContain('| Conditionals | 10 | 90.0 % (9 / 10) | 100.0 % (10 / 10) | 16.7 % (1 / 6) | 0.0 % (0 / 6) | 0.0 % (0 / 4) | 0.0 % (0 / 4) |');
    expect(text).toContain('| scoring, candidate prompt |');
    expect(text).toContain('**not to be opened before the sheet is filled**');
    expect(contentLeaks(text, m.data.items, m.data.answers)).toEqual([]);
  });

  it('with the labels: the three criteria per new topic with both scoring prompts, the live topics for reference', () => {
    const text = renderFinalSection({ ...base, labels: labelsOf(m.data), sheet: { questions: 9, answers: 24, labelled: 9, withProblems: 0 } });
    expect(text).toContain('**Status: measured and labelled.**');
    expect(text).toContain('## F1. The pass criteria, with both scoring prompts');
    // Conditionals: the production prompt's one false "correct" fails it; the candidate passes.
    expect(text).toContain('| Conditionals | 0.0 % (0 / 4): **pass** | 90.0 % (9 / 10): **FAIL** | 100.0 % (10 / 10): **pass** | 16.7 % (1 / 6): **FAIL** | 0.0 % (0 / 6): **pass** | **fails** | **passes** |');
    // The live topic: the candidate's one false "needs work" costs it the agreement.
    expect(text).toContain('| Articles (live) | 0.0 % (0 / 5): **pass** | 100.0 % (13 / 13): **pass** | 92.3 % (12 / 13): **FAIL** | 0.0 % (0 / 8): **pass** | 0.0 % (0 / 8): **pass** | **passes** (for reference) | **fails** (for reference) |');
    expect(text).toContain('## F2. The scorer against the labels, both prompts');
    expect(text).toContain('| **The five new topics** | 10 |');
    expect(text).toContain('| **The five live topics** | 13 |');
    expect(text).toContain('A question the guard removed is not on the sheet and in no rate');
    expect(contentLeaks(text, m.data.items, m.data.answers)).toEqual([]);
  });

  it('the duplicates table has the first run beside it when its folder is there', () => {
    const first: TopicsRunData = { ...m.data, items: m.data.items.filter((i) => i.topicId === 'conditionals') };
    const text = renderFinalSection({ ...base, first, labels: null, sheet: { questions: 9, answers: 24, labelled: 0, withProblems: 0 } });
    expect(text).toContain('| Conditionals | 0.0 % (0 / 4) | – | 0.0 % (0 / 4) | – | 0 / 0 / 0 / 0 |');
    expect(text).toContain('| Articles (live) | not measured | – | 0.0 % (0 / 5) |');
  });
});

describe('the later sections of the report', () => {
  it('are named, and stand after the first run\'s part in the order they were added', () => {
    expect(laterSectionName('conditionals')).toBe('Re-measurement: Conditionals');
    expect(laterSectionName('final')).toBe('Final configuration');
    expect(laterSectionName('rescore')).toBe('The scoring prompt candidate on the labelled answers');
    const first = '# Report\n\n**Status: measured.** Text.\n\n## 0. A section\n\nBody.\n';
    let report = withRemeasurement(first, 'conditionals', '# Re-measurement: Conditionals\n\nA.');
    report = withRemeasurement(report, 'rescore', '# The scoring prompt candidate on the labelled answers\n\nB.');
    report = withRemeasurement(report, 'final', '# Final configuration\n\nC.');
    expect(remeasurementBlocks(report).map((b) => b.topicId)).toEqual(['conditionals', 'rescore', 'final']);
    expect(report).toContain('**Measured again after this run: see "Re-measurement: Conditionals", "The scoring prompt candidate on the labelled answers", "Final configuration" at the end of this report.**');
    expect(withoutRemeasurements(report)).toBe(first);
    // Writing one of them again replaces it and keeps the others.
    const again = withRemeasurement(report, 'rescore', '# The scoring prompt candidate on the labelled answers\n\nB2.');
    expect(again).toContain('B2.');
    expect(again).not.toContain('\nB.\n');
    expect(remeasurementBlocks(again).map((b) => b.topicId).sort()).toEqual(['conditionals', 'final', 'rescore']);
  });

  it('a sheet lists the hint cards of the topics it has, new topics first, the live ones after', () => {
    expect(topicsOf([{ topicId: 'modalVerbs' }, { topicId: 'conditionals' }, { topicId: 'articles' }]).map((t) => t.id)).toEqual(['conditionals', 'modalVerbs', 'articles']);
    const items = guardedSet('modalVerbs', 1, setOf('articles')).gate.items;
    const sheet = buildTopicSheet(items, []);
    expect(sheet.questionsText).toContain(`${topicById('modalVerbs')?.title}\n  - modal + base verb: no "to", no "-s"`);
  });
});

describe('both scoring prompts on everything that is labelled', () => {
  const m = made();
  const labels = labelsOf(m.data);
  const earlier = { name: 'First run', answers: m.data.answers, labels, production: m.production, candidate: m.candidate };
  const base = { data: m.data, guard: m.guard, production: m.production, candidate: m.candidate, first: null, runDir: 'x', generatedAt: '2026-11-20 09:00 UTC', wallSeconds: 300, priorSpendUsd: 1.09, findings: null, labels, sheet: { questions: 9, answers: 23, labelled: 9, withProblems: 0 } };

  it('adds the runs up: per run, per topic, and everything', () => {
    const one = comparePrompts(m.data.answers, labels, m.production, m.candidate);
    const two = addComparisons(one, one);
    expect(two.production.compared).toBe(2 * one.production.compared);
    expect([two.changed, two.changedToRight, two.changedToWrong]).toEqual([4, 2, 2]);
    expect(two.candidate.falseNeedsWork).toBe(2);
    const text = renderFinalSection({ ...base, earlier: [earlier] });
    expect(text).toMatch(/## F\d+\. Both scoring prompts on everything that is labelled/);
    expect(text).toContain('(First run: 23; Final configuration: 23)');
    expect(text).toContain('| First run | 23 | 95.7 % (22 / 23) → 95.7 % (22 / 23) | 7.1 % (1 / 14) → 0.0 % (0 / 14) | 0.0 % (0 / 9) → 11.1 % (1 / 9) | 2 (1 / 1) |');
    expect(text).toContain('| **Everything labelled** | 46 | 95.7 % (44 / 46) → 95.7 % (44 / 46) | 7.1 % (2 / 28) → 0.0 % (0 / 28) | 0.0 % (0 / 18) → 11.1 % (2 / 18) | 4 (2 / 2) |');
    expect(text).toContain('| Conditionals | 20 | 90.0 % (18 / 20) → 100.0 % (20 / 20) |');
    expect(text).toContain("Of the 4 answers the two prompts judge differently, the candidate has the label's verdict on 2 and the production prompt on 2.");
    expect(contentLeaks(text, m.data.items, m.data.answers)).toEqual([]);
    // Without the rescore's folder the section is left out.
    expect(renderFinalSection(base)).not.toContain('everything that is labelled');
  });

  it('counts a verdict that contradicts the scorer\'s own correction: "needs work" with the answer given back unchanged', () => {
    const key = m.data.answers.find((a) => a.kind === 'key' && a.item.type === 'error_correction') as TopicAnswer;
    const mistake = m.data.answers.find((a) => a.kind === 'mistake1' && a.item.type === 'error_correction') as TopicAnswer;
    const verdicts = new Map(m.production);
    verdicts.set(key.id, { answerId: key.id, isCorrect: false, correctedAnswer: ` ${key.userAnswer.toUpperCase()} `, explanation: '' });
    verdicts.set(mistake.id, { answerId: mistake.id, isCorrect: false, correctedAnswer: 'Something else entirely.', explanation: '' });
    expect(givenBackUnchanged(m.data.answers, labels, verdicts)).toEqual({ count: 1, labelledRight: 1, labelledWrong: 0 });
    expect(givenBackUnchanged(m.data.answers, labels, m.production)).toEqual({ count: 0, labelledRight: 0, labelledWrong: 0 });
  });

  it('holds both prompts to the answers both scored, and says how many got no verdict', () => {
    const lost = m.data.answers.find((a) => a.topicId === 'conditionals' && a.kind === 'key') as TopicAnswer;
    const production = new Map(m.production);
    production.delete(lost.id);
    const text = renderFinalSection({ ...base, production });
    // Nine Conditionals answers left on both sides.
    expect(text).toContain('| Conditionals | 0.0 % (0 / 4): **pass** | 88.9 % (8 / 9): **FAIL** | 100.0 % (9 / 9): **pass** |');
    expect(text).toContain('1 of the 23 built answers got no usable verdict from the production prompt and 0 none from the candidate');
  });
});
