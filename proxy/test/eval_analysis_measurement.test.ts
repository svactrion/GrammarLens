import { describe, expect, it } from 'vitest';
import { cellMetrics, gateResults, renderDisagreement, renderMeasurementReport, scoredByCell, type AnalysisData } from '../eval/lib/analysis_measurement';
import type { LabelledAnswer } from '../eval/lib/datasets';
import type { MeasureRecord } from '../eval/lib/measurement';
import type { SharedQuestion } from '../src/shared_daily_test';

function answer(id: string, truth: boolean, kind = 'key', set: 'S-pool' | 'S-synth' = 'S-pool'): LabelledAnswer {
  return { id, set, item: { id: `item-${id}`, type: 'fill_in_blank', prompt: 'We saw ___ cat.\nFill in the blank.' }, userAnswer: 'the', truth, kind, correctAnswer: 'the' };
}

function scoring(cell: string, feedback: { itemId: string; isCorrect: boolean }[], stage: 'scoring' | 'scoring_repeat' = 'scoring'): MeasureRecord {
  return { customId: `${stage}_${cell}_${feedback[0]?.itemId}`, stage, group: cell, model: 'claude-sonnet-4-6', status: 'ok', inputTokens: 1000, outputTokens: 500, costUsd: 0.01, durationMs: 2000, content: { feedback: feedback.map((f) => ({ ...f, correctedAnswer: 'x', explanation: 'e' })) } };
}

const answers = [answer('a', true), answer('b', false, 'predicted_wrong'), answer('c', true, 'kb:fullwidth', 'S-synth'), answer('d', false, 'nearmiss:add_s', 'S-synth')];

const base: AnalysisData = {
  records: [
    scoring('C1', [{ itemId: 'a', isCorrect: true }, { itemId: 'b', isCorrect: true }, { itemId: 'c', isCorrect: false }, { itemId: 'd', isCorrect: false }]),
    scoring('C4', [{ itemId: 'a', isCorrect: true }, { itemId: 'b', isCorrect: false }, { itemId: 'c', isCorrect: true }, { itemId: 'd', isCorrect: true }]),
  ],
  answers,
  sGenItems: [],
  sGenLabels: new Map(),
  sFreeTargets: new Map([['i1', 'error'], ['i2', 'correct']]),
  sFreeOwner: new Map([['i1', false], ['i2', false]]),
  gateSets: [],
  gateTruth: new Map(),
  gateTruthDates: new Set(),
  sLive: { rows: 100, ok: 93, minor: 3, defect: 4, acceptAlso: 31 },
  synthExclusions: 0,
};

describe('scoring analysis', () => {
  it('reads each cell\'s verdicts and scores agreement, false correct and false needs work against the truth', () => {
    expect(scoredByCell(base.records).get('C1')?.get('b')?.isCorrect).toBe(true);
    const [c1, c4] = cellMetrics(base);
    expect(c1).toMatchObject({ cell: 'C1', scored: 4, agree: 2, falseCorrect: 1, falseNeedsWork: 1, wrongTotal: 2, rightTotal: 2, calls: 1, meanIn: 1000 });
    expect(c1?.bySet).toEqual({ 'S-pool': { scored: 2, agree: 1 }, 'S-synth': { scored: 2, agree: 1 } });
    expect(c4).toMatchObject({ cell: 'C4', scored: 4, agree: 3, falseCorrect: 1, falseNeedsWork: 0 });
  });

  it('writes the disagreement line against C1 with who was right', () => {
    const line = renderDisagreement(base);
    expect(line).toContain('| C4 | 4 | 3 (75.0 %) | 1 | 2 | 0 |');
  });

  it('renders the whole report with the limitation first and the rater line', () => {
    const report = renderMeasurementReport(base, { runDir: 'x', generatedAt: 'now', capUsd: 30, dropped: [] });
    expect(report).toContain('**Limitation, stated up front.**');
    expect(report).toContain('rater disagreement');
    expect(report).toContain('differs from the writer\'s intended target on **1** (50.0 %)');
    expect(report).toContain('Measured spend from `usage`: $0.02');
    expect(report).not.toContain('sk-ant');
  });
});

describe('gate analysis', () => {
  const question: SharedQuestion = {
    id: 'q1',
    type: 'fill_in_blank',
    context: 'You ___ show your passport.',
    instruction: 'Fill in the blank.',
    topicId: 'modalVerbs',
    correctAnswer: 'must',
    explanation: 'A rule.',
    commonWrongAnswers: [
      { answer: 'might', comment: 'c' },
      { answer: 'can', comment: 'c' },
    ],
  };
  const review = (alternatives: string[]) => ({
    questions: [{ id: 'q1', originalSentence: 'not_applicable', correctAnswer: 'correct', acceptableAlternatives: alternatives, acceptableWrongAnswers: [], incorrectRuleFields: [], explanationExcludesAlternatives: false, verdict: alternatives.length ? 'pass_with_alternatives' : 'pass' }],
  });
  const gateRecord = (model: string, repeat: number, alternatives: string[]): MeasureRecord => ({
    customId: `gate_${model}_2026-10-07_r${repeat}`,
    stage: 'gate',
    group: `gate ${model} r${repeat}`,
    model: model as MeasureRecord['model'],
    status: 'ok',
    costUsd: model.includes('opus') ? 0.04 : 0.03,
    content: review(alternatives),
  });
  const data: AnalysisData = {
    ...base,
    gateSets: [{ date: '2026-10-07', promptVersion: 2, questions: [question] }],
    gateTruth: new Map([['2026-10-07|q1', ['have to']]]),
    gateTruthDates: new Set(['2026-10-07']),
    records: [gateRecord('claude-opus-5-5', 1, ['have to', 'need to']), gateRecord('claude-sonnet-5-5', 1, ['have to']), gateRecord('claude-opus-5-5', 2, ['have to', 'need to']), gateRecord('claude-sonnet-5-5', 2, [])],
  };

  it('computes precision and recall per gate from the production decision, and lists what the owner must judge', () => {
    const [agreement, single] = gateResults(data);
    expect(agreement).toMatchObject({ gate: 'agreement', setsReviewed: 1, setsWithTruth: 1, written: 1, writtenInTruth: 1, truthTotal: 1, truthFound: 1, writtenOutsideTruth: [] });
    expect(agreement?.findings).toEqual({ proposed_by_one_model: 1 });
    expect(agreement?.costPerSet).toBeCloseTo(0.07, 6);
    expect(single).toMatchObject({ gate: 'single_review', written: 2, writtenInTruth: 1, truthFound: 1 });
    expect(single?.writtenOutsideTruth).toEqual([{ date: '2026-10-07', questionId: 'q1', answer: 'need to', key: 'must', judgment: '' }]);
    expect(single?.writtenWrong).toBe(0);
    expect(single?.costPerSet).toBeCloseTo(0.04, 6);
  });
});
