/** Tests for `convert.ts`; `scripts/fallback_pool.sh test` runs them (node:test). */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { dailyPlan } from '../../proxy/src/shared_daily_test';
import { convert, parseKvOutput, poolPrefix, reviewMarkdown } from './convert';

/** A set for [date] that the proxy gate passes: one question per plan slot. */
function publishedSet(date: string, overrides: Record<string, unknown> = {}) {
  const questions = dailyPlan(date).slots.map((slot, i) =>
    slot.type === 'fill_in_blank'
      ? {
          id: `q${i + 1}`,
          type: 'fill_in_blank',
          context: `She ___ to work every day, number ${i + 1}.`,
          instruction: 'Fill in the blank with the verb in brackets.',
          hint: '(go)',
          topicId: slot.topicId,
          correctAnswer: 'goes',
          explanation: 'A routine with "she" takes the present simple -s.',
          commonWrongAnswers: [
            { answer: 'go', comment: 'With "she" the verb needs -s.' },
            { answer: 'is going', comment: 'That is for right now.' },
          ],
        }
      : {
          id: `q${i + 1}`,
          type: 'error_correction',
          context: 'She go to work every day.',
          instruction: 'Correct the sentence.',
          topicId: slot.topicId,
          correctAnswer: 'She goes to work every day.',
          explanation: 'A routine with "she" takes the present simple -s.',
          commonWrongAnswers: [
            { answer: 'She go to work every day.', comment: 'That is the sentence unchanged.' },
            { answer: 'She going to work every day.', comment: 'That needs "is".' },
          ],
        },
  );
  return { date, promptVersion: 2, generatedAt: '2026-09-27T10:00:00.000Z', attempt: 1, questions, ...overrides };
}

const DATES = ['2026-09-29', '2026-09-30', '2026-10-01', '2026-10-02', '2026-10-03', '2026-10-04', '2026-10-05'];
const raws = (edit?: (date: string) => Record<string, unknown>) =>
  DATES.map((date) => ({ date, text: JSON.stringify(edit ? edit(date) : publishedSet(date)) }));

test('seven valid sets become a pool of seven, in the given order', () => {
  const result = convert(raws());
  assert.deepEqual(result.problems, []);
  assert.equal(result.pool?.formatVersion, 1);
  assert.equal(result.pool?.sets.length, 7);
  assert.equal(result.pool?.sets[0]?.questions.length, 5);
});

test('origin fields are dropped and ids become fbNN_i', () => {
  const pool = convert(raws()).pool!;
  pool.sets.forEach((set, n) => {
    assert.deepEqual(Object.keys(set), ['questions']);
    set.questions.forEach((q, i) => assert.equal(q.id, `${poolPrefix(n)}_${i + 1}`));
  });
  const text = JSON.stringify(pool);
  for (const field of ['"date"', 'generatedAt', '"attempt"', 'promptVersion', 'acceptedAnswers']) {
    assert.ok(!text.includes(field), field);
  }
});

test('the question texts are kept unchanged', () => {
  const pool = convert(raws()).pool!;
  const source = publishedSet(DATES[0]!).questions;
  const plan = dailyPlan(DATES[0]!);
  pool.sets[0]!.questions.forEach((q, i) => {
    const original = source.find((s) => s.topicId === plan.slots[i]!.topicId)!;
    assert.equal(q.context, original.context);
    assert.equal(q.correctAnswer, original.correctAnswer);
    assert.equal(q.explanation, original.explanation);
  });
});

test('wrangler notices before the JSON are skipped', () => {
  assert.deepEqual(parseKvOutput('⛅️ wrangler 4\n{"a":1}'), { a: 1 });
});

const rejections: [string, (date: string) => Record<string, unknown> | string, RegExp][] = [
  ['a v1 set', (d) => publishedSet(d, { promptVersion: 1 }), /promptVersion 1/],
  ['a set stored for another date', (d) => publishedSet(d, { date: '2026-01-01' }), /says date/],
  [
    'a fill_in_blank without its blank (the gate rule)',
    (d) => {
      const set = publishedSet(d);
      const fill = set.questions.find((q) => q.type === 'fill_in_blank')!;
      fill.context = 'My phone restarted while I was updating apps.';
      return set;
    },
    /fill_in_blank_missing_blank/,
  ],
  [
    'an error_correction without its sentence',
    (d) => {
      const set = publishedSet(d);
      set.questions.find((q) => q.type === 'error_correction')!.context = 'Fix';
      return set;
    },
    /error_correction_missing_sentence/,
  ],
  ['four questions', (d) => ({ ...publishedSet(d), questions: publishedSet(d).questions.slice(1) }), /wrong_question_count/],
  ['a missing set (empty output)', () => '', /unreadable/],
];
for (const [name, edit, pattern] of rejections) {
  test(`${name} writes nothing and names the date`, () => {
    const input = DATES.map((date, i) => ({
      date,
      text: i === 2 ? (typeof edit(date) === 'string' ? (edit(date) as string) : JSON.stringify(edit(date))) : JSON.stringify(publishedSet(date)),
    }));
    const result = convert(input);
    assert.equal(result.pool, undefined);
    assert.equal(result.review, undefined);
    assert.equal(result.problems.length, 1);
    assert.match(result.problems[0]!, new RegExp(`^${DATES[2]}: `));
    assert.match(result.problems[0]!, pattern);
  });
}

test('the wrong number of dates writes nothing', () => {
  assert.match(convert(raws().slice(1)).problems[0]!, /expected 7 dates, got 6/);
});

test('a date listed twice writes nothing', () => {
  const input = raws();
  input[6] = input[0]!;
  assert.ok(convert(input).problems.some((p) => /listed twice/.test(p)));
});

test('the review shows question text and answers only, per set', () => {
  const review = convert(raws()).review!;
  assert.match(review, /## fb01 — published for 2026-09-29/);
  assert.match(review, /## fb07 — published for 2026-10-05/);
  assert.match(review, /\*\*Answer:\*\* goes/);
  assert.match(review, /Predicted wrong: go · is going/);
  assert.ok(!review.includes('present simple -s'), 'no explanations');
  assert.ok(!review.includes('With "she"'), 'no wrong-answer comments');
  assert.equal(reviewMarkdown([]).includes('##'), false);
});
