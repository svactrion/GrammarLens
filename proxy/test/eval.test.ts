import { describe, expect, it } from 'vitest';
import type { QuestionCheck } from '../src/shared_check';
import { dailyPlan, type DailyPlan, type SharedQuestion } from '../src/shared_daily_test';
import { analyze, reviewedSets } from '../eval/lib/analysis';
import { LABEL_COLUMNS, buildLabelSheet, parseCsv, readLabels, seededRandom, toCsv, type LabelItem } from '../eval/lib/labels';
import {
  CHECKERS,
  EVAL_DATES,
  SPEND_CAP_USD,
  TOKEN_ESTIMATES,
  costOf,
  estimateCost,
  fitBudget,
  planRequests,
  summarizePlan,
} from '../eval/lib/matrix';
import { readGeneratedSet, readReferenceSet, type CallRecord } from '../eval/lib/sets';
import day0 from '../eval/reference/day0.json';

// ---------------------------------------------------------------------------
// The plan and its cost

describe('E plan (docs/1.1.0-shared-daily-test-quality.md §13.6)', () => {
  const plan = planRequests();

  it('makes 111 requests: 30 generations and 81 checks', () => {
    expect(plan).toHaveLength(111);
    expect(plan.filter((r) => r.kind === 'generation')).toHaveLength(30);
    expect(plan.filter((r) => r.kind === 'check')).toHaveLength(81);
  });

  it('runs one date per variant and one check per checker synchronously, the rest batched', () => {
    const count = (stage: string) => plan.filter((r) => r.stage === stage).length;
    expect([count('A'), count('B'), count('C'), count('D')]).toEqual([5, 25, 3, 78]);
    expect(plan.filter((r) => r.sync).every((r) => r.stage === 'A' || r.stage === 'C')).toBe(true);
    expect(plan.filter((r) => r.stage === 'A').map((r) => r.date)).toEqual(Array(5).fill(EVAL_DATES[0]));
    expect(plan.filter((r) => r.stage === 'C').map((r) => `${r.checker} ${r.reference} ${r.repeat}`)).toEqual([
      'K1 R3 1',
      'K2 R3 1',
      'K3 R3 1',
    ]);
  });

  it('checks each variant with the checkers the matrix gives it', () => {
    const checked = (k: string) => [...new Set(plan.filter((r) => r.checker === k && r.variant).map((r) => r.variant))];
    expect(checked('K1')).toEqual(['G1', 'G2', 'G3', 'G4', 'G5']);
    expect(checked('K2')).toEqual(['G1', 'G2', 'G3']);
    expect(checked('K3')).toEqual(['G3']);
    for (const k of CHECKERS) {
      expect(plan.filter((r) => r.checker === k.id && r.reference)).toHaveLength(9);
    }
    expect(plan.find((r) => r.checker === 'K1' && r.variant === 'G5')?.questions).toBe(10);
  });

  it('uses valid, unique Batches API custom ids', () => {
    const ids = plan.map((r) => r.customId);
    expect(new Set(ids).size).toBe(ids.length);
    for (const id of ids) expect(id).toMatch(/^[A-Za-z0-9_-]{1,64}$/);
  });

  it('estimates ≈ $3.1 batched and ≈ $5.8 all synchronous, under the $4 cap', () => {
    const summary = summarizePlan(plan);
    expect(summary.totalUsd).toBeCloseTo(3.12, 1);
    expect(summary.totalIfAllSyncUsd).toBeCloseTo(5.84, 1);
    expect(summary.totalUsd).toBeLessThan(SPEND_CAP_USD);
  });

  it('prices at the documented list price, and half through the Batches API', () => {
    const usage = { inputTokens: 1_000_000, outputTokens: 1_000_000 };
    expect(costOf('claude-sonnet-4-6', usage, true)).toBe(18);
    expect(costOf('claude-sonnet-5', usage, true)).toBe(12);
    expect(costOf('claude-opus-5-5', usage, true)).toBe(24);
    expect(costOf('claude-sonnet-5', usage, false)).toBe(6);
  });
});

describe('fitBudget', () => {
  const plan = planRequests().filter((r) => r.stage === 'D');

  it('keeps everything when the cap allows it', () => {
    expect(fitBudget(plan, 0, 100)).toEqual({ kept: plan, dropped: [] });
  });

  it('drops the highest priority number first: K3, then G5, then G4, then K2', () => {
    const total = plan.reduce((s, r) => s + estimateCost(r), 0);
    const k3 = plan.filter((r) => r.checker === 'K3').reduce((s, r) => s + estimateCost(r), 0);
    const fit = fitBudget(plan, 0, (total - k3) * 1.25 + 0.001);
    expect(fit.dropped.every((r) => r.checker === 'K3')).toBe(true);
    expect(fit.dropped).toHaveLength(plan.filter((r) => r.checker === 'K3').length);

    const tighter = fitBudget(plan, 0, (total - k3) * 1.25 - 0.01);
    expect(tighter.dropped.some((r) => r.checker === 'K1' && r.variant === 'G5')).toBe(true);
    expect(tighter.dropped.some((r) => r.checker === 'K2')).toBe(false);
  });

  it('counts what is already spent, with the margin, and keeps the planned order', () => {
    const fit = fitBudget(plan, SPEND_CAP_USD, SPEND_CAP_USD);
    expect(fit.kept).toEqual([]);
    const some = fitBudget(plan, 3.5, SPEND_CAP_USD);
    const kept = some.kept.reduce((s, r) => s + estimateCost(r), 0);
    expect(3.5 + kept * 1.25).toBeLessThanOrEqual(SPEND_CAP_USD);
    expect(some.kept).toEqual(plan.filter((r) => some.kept.includes(r)));
  });

  it('uses measured token counts once they exist', () => {
    const request = plan.find((r) => r.checker === 'K1' && r.questions === 5);
    if (!request) throw new Error('fixture');
    const measured = { ...TOKEN_ESTIMATES, 'check:K1:5': { inputTokens: 0, outputTokens: 0 } };
    expect(estimateCost(request, measured)).toBe(0);
  });
});

// ---------------------------------------------------------------------------
// The label sheet

function question(id: string, overrides: Partial<SharedQuestion> = {}): SharedQuestion {
  return {
    id,
    type: 'fill_in_blank',
    context: 'You ___ show your passport, "please", at gate 3.',
    instruction: 'Fill in the blank.',
    topicId: 'modalVerbs',
    correctAnswer: 'must',
    explanation: "'Must' is a rule.",
    commonWrongAnswers: [
      { answer: 'might', comment: "Only a possibility, isn't it?" },
      { answer: 'can', comment: 'Permission.' },
    ],
    ...overrides,
  };
}

describe('CSV', () => {
  it('round-trips commas, quotes, newlines, curly quotes and Turkish letters, with a BOM', () => {
    const rows = [{ a: 'x, y', b: 'say "hi"\nthen go', c: 'isn’t — ğüşıöç' }];
    const text = toCsv(['a', 'b', 'c'], rows);
    expect(text.startsWith('﻿')).toBe(true);
    expect(parseCsv(text)).toEqual(rows);
  });

  it('never lets a cell start like a spreadsheet formula', () => {
    const text = toCsv(['a', 'b'], [{ a: '=HYPERLINK("x")', b: '-1' }]);
    expect(parseCsv(text)).toEqual([{ a: '\'=HYPERLINK("x")', b: "'-1" }]);
  });

  it('reads LF and CRLF files and skips blank lines', () => {
    expect(parseCsv('a,b\n1,2\n\n3,4\n')).toEqual([
      { a: '1', b: '2' },
      { a: '3', b: '4' },
    ]);
    expect(parseCsv('a,b\r\n1,2\r\n')).toEqual([{ a: '1', b: '2' }]);
  });
});

describe('buildLabelSheet', () => {
  const items: LabelItem[] = [
    { source: 'G1', date: '2026-10-10', questionId: 'q1', question: question('q1') },
    { source: 'G2', date: '2026-10-10', questionId: 'q1', question: question('q1', { correctAnswer: 'have to' }) },
    { source: 'R3', questionId: 'day0_1', question: question('day0_1') },
  ];

  it('gives every row a unique random key, and keeps the source only in the mapping', () => {
    const keys = ['aaaa', 'aaaa', 'bbbb', 'cccc'];
    const sheet = buildLabelSheet(items, () => keys.shift() as string, seededRandom(1));
    expect(sheet.rows.map((r) => r.key).sort()).toEqual(['aaaa', 'bbbb', 'cccc']);
    expect(Object.values(sheet.mapping)).toEqual([
      { source: 'G1', date: '2026-10-10', questionId: 'q1' },
      { source: 'G2', date: '2026-10-10', questionId: 'q1' },
      { source: 'R3', questionId: 'day0_1' },
    ]);
    const csv = toCsv(LABEL_COLUMNS, sheet.rows);
    for (const hidden of ['G1', 'G2', 'R3', '2026-10-10', 'q1', 'day0_1']) expect(csv).not.toContain(hidden);
    expect(sheet.rows.every((r) => r.label === '' && r.defect_types === '' && r.accept_also === '' && r.note === '')).toBe(true);
  });

  it('shuffles, reproducibly from the seed', () => {
    const many = Array.from({ length: 30 }, (_, i) => ({ source: 'G1', date: 'd', questionId: `q${i}`, question: question(`q${i}`) }));
    let n = 0;
    const key = () => `k${n++}`;
    const a = buildLabelSheet(many, key, seededRandom(7));
    n = 0;
    const b = buildLabelSheet(many, key, seededRandom(7));
    expect(a.rows).toEqual(b.rows);
    expect(a.rows.map((r) => r.key)).not.toEqual(many.map((_, i) => `k${i}`));
  });

  it('shows the wrong answers with their comments', () => {
    const sheet = buildLabelSheet(items.slice(0, 1), () => 'k', seededRandom(1));
    expect(sheet.rows[0]?.predicted_wrong_answers).toBe("might — Only a possibility, isn't it? || can — Permission.");
  });
});

describe('readLabels', () => {
  it('reads labels, defect types and alternatives, and reports blanks and invalid values', () => {
    const read = readLabels([
      { key: 'a', label: ' Defect ', defect_types: 'wrong_rule; multiple_answers', accept_also: 'should | have to' },
      { key: "'b", label: 'ok', defect_types: '', accept_also: '' },
      { key: 'c', label: 'minor', defect_types: '', accept_also: '' },
      { key: 'd', label: '', defect_types: '', accept_also: '' },
      { key: 'e', label: 'bad', defect_types: '', accept_also: '' },
      { key: 'f', label: 'defect', defect_types: 'typo', accept_also: '' },
    ]);
    expect(read.labels.get('a')).toEqual({ label: 'defect', defectTypes: ['wrong_rule', 'multiple_answers'], acceptAlso: ['should', 'have to'] });
    expect(read.labels.get('b')?.label).toBe('ok');
    expect(read.labels.get('c')?.label).toBe('minor');
    expect(read.unlabelled).toEqual(['d']);
    expect(read.invalid).toEqual(['e', 'f']);
  });
});

// ---------------------------------------------------------------------------
// Sets and analysis

/** A set that passes the proxy's gate for [plan]. */
function validSetFor(plan: DailyPlan, tag: string): SharedQuestion[] {
  return plan.slots.map((slot, i) =>
    slot.type === 'fill_in_blank'
      ? question(`${tag}${i}`, { topicId: slot.topicId })
      : {
          ...question(`${tag}${i}`, { topicId: slot.topicId, type: 'error_correction' }),
          context: 'When we arrived, the plane already left.',
          correctAnswer: 'When we arrived, the plane had already left.',
          commonWrongAnswers: [
            { answer: 'When we arrived, the plane has already left.', comment: 'c' },
            { answer: 'When we arrived, the plane already left.', comment: 'c' },
          ],
        },
  );
}

function review(q: SharedQuestion, overrides: Partial<QuestionCheck> = {}): QuestionCheck {
  return {
    id: q.id,
    originalSentence: q.type === 'error_correction' ? 'clearly_wrong' : 'not_applicable',
    correctAnswer: 'correct',
    acceptableAlternatives: [],
    acceptableWrongAnswers: [],
    incorrectRuleFields: [],
    explanationExcludesAlternatives: false,
    verdict: 'pass',
    ...overrides,
  };
}

const date = EVAL_DATES[0];
const set = validSetFor(dailyPlan(date), 'a');

function records(): CallRecord[] {
  const base = { stage: 'B', sync: false, costUsd: 0.01, inputTokens: 1000, outputTokens: 2000 } as const;
  return [
    { ...base, customId: 'gen_G2', kind: 'generation', model: 'claude-sonnet-4-6', variant: 'G2', date, status: 'ok', content: { questions: set } },
    { ...base, customId: 'gen_G3', kind: 'generation', model: 'claude-sonnet-5', variant: 'G3', date, status: 'ok', content: { questions: [] } },
    {
      ...base,
      customId: 'chk_K1',
      kind: 'check',
      model: 'claude-sonnet-5',
      checker: 'K1',
      variant: 'G2',
      date,
      status: 'ok',
      content: { questions: set.map((q) => review(q)) },
    },
    {
      ...base,
      customId: 'chk_K2',
      kind: 'check',
      model: 'claude-sonnet-4-6',
      checker: 'K2',
      variant: 'G2',
      date,
      status: 'ok',
      content: { questions: set.map((q, i) => review(q, i === 0 ? { correctAnswer: 'incorrect' } : {})) },
    },
    { ...base, customId: 'skip', kind: 'check', model: 'claude-opus-5-5', checker: 'K3', variant: 'G3', date, status: 'skipped_budget', costUsd: 0 },
  ];
}

describe('readGeneratedSet / readReferenceSet', () => {
  it('runs a generation through the gate its strategy uses', () => {
    const [g2, g3] = records();
    expect(readGeneratedSet(g2 as CallRecord)).toMatchObject({ valid: true });
    expect(readGeneratedSet(g3 as CallRecord)).toEqual({ valid: false, reason: 'wrong_question_count' });
    expect(readGeneratedSet({ ...(g2 as CallRecord), status: 'expired' })).toEqual({ valid: false, reason: 'expired' });
  });

  it('reads the bundled day-0 set and a stored set record', () => {
    expect(readReferenceSet(day0).map((q) => q.id)).toEqual(['day0_1', 'day0_2', 'day0_3', 'day0_4', 'day0_5']);
    const stored = { date: '2026-09-26', promptVersion: 1, generatedAt: 'x', attempt: 1, questions: set };
    expect(readReferenceSet(stored)).toEqual(set);
    expect(() => readReferenceSet({ questions: [] })).toThrow();
  });
});

describe('analyze', () => {
  it('reads each check against the questions it reviewed', () => {
    const reviewed = reviewedSets(records(), {});
    expect(reviewed.map((s) => `${s.checker} ${s.source} ${s.set.outcome}`)).toEqual(['K1 G2 publish', 'K2 G2 reject']);
  });

  it('reports spend, gate outcomes and publish rates without labels', () => {
    const report = analyze({ records: records(), references: {} });
    expect(report).toContain('Measured spend: **$0.040**');
    expect(report).toContain('| G3 | 1 | 0 | wrong_question_count | — |');
    expect(report).toContain('| K1 | G2 | 1 | 1 | — | 100% | 100% |');
    expect(report).toContain('| K2 | G2 | 1 | 0 | key_incorrect | 0% | 0% |');
    expect(report).toContain('No labels yet.');
  });

  it('joins the owner labels through the mapping: defect rate, published defects, checker accuracy', () => {
    const mapping = Object.fromEntries(set.map((q, i) => [`k${i}`, { source: 'G2', date, questionId: q.id }]));
    const labels = new Map(
      set.map((_, i) => [`k${i}`, { label: i === 0 ? ('defect' as const) : ('ok' as const), defectTypes: [], acceptAlso: [] }]),
    );
    const report = analyze({ records: records(), references: {}, labels, mapping });
    expect(report).toContain('| G2 | 5 | 4 | 0 | 1 | 20% |');
    // K1 published the set with its defect; K2 rejected it.
    expect(report).toContain('| K1 | G2 | 5 | 1 (20%) | 0 |');
    expect(report).toContain('| K1 | 0/1 (0%) | 0/4 (0%) | 0/0 | 0 of 0 |');
    expect(report).toContain('| K2 | 1/1 (100%) | 0/4 (0%) | 0/0 | 0 of 0 |');
  });
});
