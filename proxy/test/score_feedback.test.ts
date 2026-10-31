import { describe, expect, it } from 'vitest';
import { checkScoreFeedback, expectedBlankEntries, logScoreFeedback } from '../src/score_feedback';
import type { ScoreAnswersRequest } from '../src/validation';

/** 1.4.0 D11 (docs/1.4.0-server-batch0-report.md §4.2). */
const request: ScoreAnswersRequest = {
  deviceId: 'd',
  items: [
    { id: 'two', type: 'fill_in_blank', prompt: 'I enjoy ____ (swim), but I decided ____ (learn).\nFill in each blank.', userAnswer: 'I enjoy swimming (swim), but I decided to learning (learn).' },
    { id: 'one', type: 'fill_in_blank', prompt: 'We waited for ___ bus.\nFill in the blank.', userAnswer: 'the' },
    { id: 'none', type: 'fill_in_blank', prompt: 'Complete the sentence with an article.', userAnswer: 'the' },
    { id: 'ec', type: 'error_correction', prompt: 'He go home.\nRewrite the sentence.', userAnswer: 'He goes home.' },
    { id: 'sw', type: 'sentence_writing', prompt: 'Write one sentence with "should".', userAnswer: 'You should rest.' },
  ],
};

const entry = (index: number, accepted: boolean) => ({ index, correctAnswer: `c${index}`, accepted, note: `n${index}` });

function item(itemId: string, isCorrect: boolean, blanks: unknown, summary = 'Two sentences at most.') {
  return { itemId, isCorrect, correctedAnswer: 'x', explanation: 'the long paragraph', summary, blanks };
}

describe('expectedBlankEntries', () => {
  it('is one per blank of a fill_in_blank prompt, else one', () => {
    expect(expectedBlankEntries('fill_in_blank', 'a ____ b ____ c')).toBe(2);
    expect(expectedBlankEntries('fill_in_blank', 'a __ b')).toBe(1);
    expect(expectedBlankEntries('fill_in_blank', 'no gap, one underscore _')).toBe(1);
    expect(expectedBlankEntries('error_correction', 'a ____ b ____')).toBe(1);
    expect(expectedBlankEntries('sentence_writing', '')).toBe(1);
  });
});

describe('checkScoreFeedback', () => {
  it('passes well-formed structured fields through untouched', () => {
    const content = {
      feedback: [
        item('two', false, [entry(0, true), entry(1, false)]),
        item('one', true, [entry(0, true)]),
        item('none', true, [entry(0, true)]),
        item('ec', true, [entry(0, true)]),
        item('sw', false, [entry(0, false)]),
      ],
    };
    const check = checkScoreFeedback(request, content);
    expect(check.content).toEqual(content);
    expect(check).toMatchObject({ structuredDropped: 0, verdictReconciled: 0, items: 5 });
  });

  it('removes blanks and summary when the count or the indexes do not match the prompt, keeping the six fields', () => {
    const wrongCount = item('two', false, [entry(0, true)]);
    const badIndex = item('one', true, [{ ...entry(0, true), index: 1 }]);
    const tooMany = item('ec', true, [entry(0, true), entry(1, true)]);
    const malformed = item('sw', true, [{ index: 0, correctAnswer: 'x', accepted: 'yes', note: 'n' }]);
    const check = checkScoreFeedback(request, { feedback: [wrongCount, badIndex, tooMany, malformed] });
    const out = (check.content as { feedback: Record<string, unknown>[] }).feedback;
    for (const o of out) {
      expect(o).not.toHaveProperty('blanks');
      expect(o).not.toHaveProperty('summary');
      expect(o).toMatchObject({ correctedAnswer: 'x', explanation: 'the long paragraph' });
    }
    expect(out.map((o) => o.isCorrect)).toEqual([false, true, true, true]);
    expect(check).toMatchObject({ structuredDropped: 4, verdictReconciled: 0, items: 4 });
  });

  it('sets isCorrect to the entries\' verdict when the model contradicts itself, both ways', () => {
    const saidCorrect = item('two', true, [entry(0, true), entry(1, false)]);
    const saidWrong = item('one', false, [entry(0, true)]);
    const check = checkScoreFeedback(request, { feedback: [saidCorrect, saidWrong] });
    const out = (check.content as { feedback: Record<string, unknown>[] }).feedback;
    expect(out.map((o) => o.isCorrect)).toEqual([false, true]);
    expect(out[0]?.blanks).toEqual([entry(0, true), entry(1, false)]);
    expect(check).toMatchObject({ structuredDropped: 0, verdictReconciled: 2, items: 2 });
  });

  it('leaves an unknown item, a response without the fields, and a non-object response alone', () => {
    const unknown = { itemId: 'ghost', isCorrect: true, correctedAnswer: 'x', explanation: 'y', blanks: 'nonsense' };
    const legacy = { itemId: 'one', isCorrect: true, correctedAnswer: 'x', explanation: 'y' };
    const check = checkScoreFeedback(request, { feedback: [unknown, legacy] });
    expect((check.content as { feedback: unknown[] }).feedback).toEqual([unknown, legacy]);
    expect(check).toMatchObject({ structuredDropped: 0, verdictReconciled: 0, items: 2 });
    expect(checkScoreFeedback(request, 'text')).toEqual({ content: 'text', structuredDropped: 0, verdictReconciled: 0, items: 0 });
    expect(checkScoreFeedback(request, { items: [] }).content).toEqual({ items: [] });
  });

  it('logs counts only', () => {
    const lines: string[] = [];
    const original = console.log;
    console.log = (line: string) => lines.push(line);
    try {
      logScoreFeedback(checkScoreFeedback(request, { feedback: [item('two', true, [entry(0, true), entry(1, false)])] }));
    } finally {
      console.log = original;
    }
    expect(lines.map((l) => JSON.parse(l) as unknown)).toEqual([{ event: 'score_feedback', items: 1, structured_dropped: 0, verdict_reconciled: 1 }]);
    expect(lines.join('')).not.toContain('swim');
  });
});
