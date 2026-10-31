import { describe, expect, it } from 'vitest';
import { ANNOTATION_GATE, annotateQuestion, changesOtherWords, defeatsDeduction, isUnshiftedAlternative, type CheckerReview, type QuestionCheck } from '../src/shared_check';
import type { SharedQuestion } from '../src/shared_daily_test';

/** The three tested-rule filters of 2026-10-31 (owner, after the measurement:
 * 6 of 23 written answers were right English that defeated the tested rule). */

const base = (overrides: Partial<SharedQuestion>): SharedQuestion => ({
  id: 'q',
  type: 'fill_in_blank',
  instruction: 'Fill in the blank.',
  topicId: 'modalPastForms',
  correctAnswer: 'would',
  explanation: "In reported speech 'will' shifts to 'would'.",
  commonWrongAnswers: [
    { answer: 'wills', comment: 'c' },
    { answer: 'woulds', comment: 'c' },
  ],
  ...overrides,
});

const opus = (q: SharedQuestion, o: Partial<QuestionCheck> = {}): CheckerReview => ({
  model: 'claude-opus-5-5',
  check: {
    id: q.id,
    originalSentence: q.type === 'error_correction' ? 'clearly_wrong' : 'not_applicable',
    correctAnswer: 'correct',
    acceptableAlternatives: [],
    acceptableWrongAnswers: [],
    incorrectRuleFields: [],
    explanationExcludesAlternatives: false,
    verdict: 'pass',
    ...o,
  },
});

describe('the production gate', () => {
  it('is single review (owner, 2026-10-31)', () => {
    expect(ANNOTATION_GATE).toBe('single_review');
  });
});

describe('alternative_unshifted', () => {
  it('rejects the unshifted form on a reported-speech item, fill-in and full sentence alike', () => {
    const fill = base({ context: 'Yesterday the manager said that she ____ call me back.' });
    expect(isUnshiftedAlternative(fill, 'will')).toBe(true);
    expect(isUnshiftedAlternative(fill, 'was going to')).toBe(false);
    const sentence = base({
      type: 'error_correction',
      context: 'Yesterday the technician told me he can fix my phone by Friday.',
      correctAnswer: 'Yesterday the technician told me he could fix my phone by Friday.',
      explanation: 'After a past reporting verb the modal shifts back.',
    });
    expect(isUnshiftedAlternative(sentence, 'Yesterday the technician told me he will fix my phone by Friday.')).toBe(true);
    expect(isUnshiftedAlternative(sentence, 'Yesterday the technician told me he would fix my phone by Friday.')).toBe(false);
  });

  it('does not fire without a reporting verb, or when the key itself keeps the unshifted form', () => {
    const plain = base({ context: 'If it rains we ____ stay in.', explanation: "'Would' for an imagined result." });
    expect(isUnshiftedAlternative(plain, 'will')).toBe(false);
    const keptForm = base({ context: 'She said she will come.', correctAnswer: 'will come', explanation: 'A still-true plan keeps will.' });
    expect(isUnshiftedAlternative(keptForm, 'will come')).toBe(false);
  });

  it('is applied by the decision: the unshifted alternative is a finding, not a write', () => {
    const fill = base({ context: 'Yesterday the manager said that she ____ call me back.' });
    const r = annotateQuestion(fill, [opus(fill, { acceptableAlternatives: ['will', 'was going to'] })]);
    expect(r.acceptedAnswers).toEqual(['was going to']);
    expect(r.findings).toEqual([{ questionId: 'q', code: 'alternative_unshifted', answers: ['will'] }]);
  });
});

describe('alternative_defeats_rule', () => {
  const deduction = base({
    topicId: 'modalVerbs',
    context: 'The lights are on and the car is in the drive, so my parents ____ be home.',
    correctAnswer: 'must',
    explanation: "'Must' states a logical deduction from the evidence.",
    commonWrongAnswers: [
      { answer: 'can', comment: 'c' },
      { answer: 'should', comment: 'c' },
    ],
  });
  it('rejects a prediction form for the deduction must', () => {
    expect(defeatsDeduction(deduction, 'will')).toBe(true);
    expect(defeatsDeduction(deduction, 'must')).toBe(false);
    expect(defeatsDeduction(deduction, 'have to')).toBe(false);
    const obligation = base({ topicId: 'modalVerbs', correctAnswer: 'must', explanation: "'Must' for a strict rule at the airport." });
    expect(defeatsDeduction(obligation, 'will')).toBe(false);
    const r = annotateQuestion(deduction, [opus(deduction, { acceptableAlternatives: ['will'] })]);
    expect(r.acceptedAnswers).toEqual([]);
    expect(r.findings.map((f) => f.code)).toEqual(['alternative_defeats_rule']);
  });
});

describe('alternative_changes_other_words', () => {
  const ec = base({
    type: 'error_correction',
    context: 'At the market, I bought an umbrella and a oranges.',
    instruction: 'Correct the error and write the full sentence.',
    topicId: 'articles',
    correctAnswer: 'At the market, I bought an umbrella and oranges.',
    explanation: 'A plural noun takes no article.',
  });
  it('rejects a correction that edits words the key leaves alone', () => {
    expect(changesOtherWords(ec, 'At the market, I bought an umbrella and an orange.')).toBe(true);
    expect(changesOtherWords(ec, 'At the market, I bought an umbrella and some oranges.')).toBe(false);
    expect(changesOtherWords(ec, 'At the market, I bought an umbrella and oranges.')).toBe(false);
    const r = annotateQuestion(ec, [opus(ec, { acceptableAlternatives: ['At the market, I bought an umbrella and an orange.', 'At the market, I bought an umbrella and some oranges.'] })]);
    expect(r.acceptedAnswers).toEqual(['At the market, I bought an umbrella and some oranges.']);
    expect(r.findings).toEqual([{ questionId: 'q', code: 'alternative_changes_other_words', answers: ['At the market, I bought an umbrella and an orange.'] }]);
  });

  it('allows a rephrasing of the same span and ignores fill-in items', () => {
    const modal = base({
      type: 'error_correction',
      context: 'She said yesterday that she can not find her size.',
      correctAnswer: 'She said yesterday that she could not find her size.',
      explanation: 'Backshift after said.',
    });
    expect(changesOtherWords(modal, 'She said yesterday that she was not able to find her size.')).toBe(false);
    expect(changesOtherWords(base({}), 'anything')).toBe(false);
  });
});
