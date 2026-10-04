/** Tests for `convert.ts`; `scripts/fallback_pool.sh test` runs them (node:test). */
import assert from 'node:assert/strict';
import { test } from 'node:test';
import { dailyPlan } from '../../proxy/src/shared_daily_test';
import { readFileSync } from 'node:fs';
import { convert, parseCorrections, parseKvOutput, poolPrefix, reviewMarkdown, type Correction } from './convert';

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

// ---------------------------------------------------------------------------
// Owner corrections (roadmap P13)

/** The corrected date (fb04 here) and the number of its first question of [type]. */
const CORRECTED = DATES[3]!;
const numberOf = (type: string) => dailyPlan(CORRECTED).slots.findIndex((s) => s.type === type) + 1;

/** The raw sets, with a third predicted wrong answer on every question of the
 * corrected date, so one can be removed and the gate's minimum of 2 still holds. */
function rawsWithThreeWrong() {
  return raws((date) => {
    const set = publishedSet(date);
    if (date !== CORRECTED) return set;
    for (const q of set.questions) {
      (q.commonWrongAnswers as { answer: string; comment: string }[]).push({
        answer: q.type === 'fill_in_blank' ? "'s going" : 'She goes to the work every day.',
        comment: 'A third prediction.',
      });
    }
    return set;
  });
}

const fill = numberOf('fill_in_blank');
const fix = (overrides: Partial<Correction> = {}): Correction => ({
  date: CORRECTED,
  question: fill,
  reason: 'The hint contradicts the key.',
  ...overrides,
});

test('a correction adds accepted answers, removes a predicted wrong answer and the hint', () => {
  const result = convert(rawsWithThreeWrong(), [
    fix({ removeHint: true, removeWrongAnswers: ["'s going"], addAcceptedAnswers: ["'s going", ' does go '] }),
  ]);
  assert.deepEqual(result.problems, []);
  const q = result.pool!.sets[3]!.questions[fill - 1]!;
  assert.equal(q.id, `fb04_${fill}`);
  assert.equal(q.hint, undefined);
  assert.deepEqual(q.acceptedAnswers, ["'s going", 'does go']);
  assert.deepEqual(q.commonWrongAnswers.map((w) => w.answer), ['go', 'is going']);
  assert.equal(q.correctAnswer, 'goes');
  // Every other question is untouched and carries no acceptedAnswers key.
  const others = result.pool!.sets.flatMap((s) => s.questions).filter((o) => o !== q);
  assert.ok(others.every((o) => !('acceptedAnswers' in o)));
  assert.ok(others.every((o) => o.type !== 'fill_in_blank' || o.hint === '(go)'));
});

test('the review shows the correction, its reason and the accepted answers', () => {
  const review = convert(rawsWithThreeWrong(), [
    fix({ removeHint: true, removeWrongAnswers: ["'s going"], addAcceptedAnswers: ["'s going"] }),
  ]).review!;
  assert.match(review, /\*\*Also accepted:\*\* 's going/);
  assert.match(
    review,
    /\*Owner correction:\* hint removed; predicted wrong removed: "'s going"; accepted added: "'s going" — The hint contradicts the key\./,
  );
  assert.equal(review.match(/Owner correction/g)?.length, 1);
  assert.match(review, /do not edit by hand:\ncorrections go in `tool\/fallback_pool\/corrections\.json`/);
});

test('three accepted answers are allowed (spelling variants)', () => {
  const ec = numberOf('error_correction');
  const result = convert(raws(), [
    fix({
      question: ec,
      addAcceptedAnswers: ['She does go to work every day.', 'She goes to work each day.', 'She goes to work daily.'],
    }),
  ]);
  assert.deepEqual(result.problems, []);
  assert.equal(result.pool!.sets[3]!.questions[ec - 1]!.acceptedAnswers?.length, 3);
});

const correctionProblems: [string, Correction, RegExp][] = [
  ['a date not in this build', fix({ date: '2026-09-28', addAcceptedAnswers: ['x'] }), /matches no question \(date not in this build\)/],
  ['a question number past the set', fix({ question: 6, addAcceptedAnswers: ['x'] }), /matches no question \(no such question\)/],
  ['a hint removed from a question without one', fix({ question: numberOf('error_correction'), removeHint: true }), /has no hint/],
  ['a wrong answer that is not there', fix({ removeWrongAnswers: ['gone'] }), /"gone" matches 0, needs exactly 1/],
  ['a wrong answer removed below the minimum', fix({ removeWrongAnswers: ['go'] }), /after the owner corrections \(wrong_answer_count\)/],
  ['an accepted answer that is the key', fix({ addAcceptedAnswers: ['Goes.'] }), /"Goes\." is the key/],
  ['an accepted answer that is a predicted wrong one', fix({ addAcceptedAnswers: ['is going'] }), /is also a predicted wrong answer/],
  [
    'an accepted answer that is the sentence to correct',
    fix({ question: numberOf('error_correction'), addAcceptedAnswers: ['she go to work every day'] }),
    /is the sentence to correct/,
  ],
  ['an accepted answer listed twice', fix({ addAcceptedAnswers: ['does go', 'Does go.'] }), /listed twice/],
];
for (const [name, correction, pattern] of correctionProblems) {
  test(`${name} writes nothing and names the date and question`, () => {
    const result = convert(raws(), [correction]);
    assert.equal(result.pool, undefined);
    assert.equal(result.review, undefined);
    assert.equal(result.problems.length, 1);
    assert.match(result.problems[0]!, new RegExp(`^${correction.date}`));
    assert.match(result.problems[0]!, pattern);
  });
}

const file = (corrections: unknown[], formatVersion: unknown = 1) => JSON.stringify({ formatVersion, corrections });

test('a corrections file is read', () => {
  const parsed = parseCorrections(file([{ date: CORRECTED, question: 1, reason: 'Why.', addAcceptedAnswers: ['a'] }]));
  assert.deepEqual(parsed.problems, []);
  assert.deepEqual(parsed.corrections, [{ date: CORRECTED, question: 1, reason: 'Why.', addAcceptedAnswers: ['a'] }]);
});

const fileProblems: [string, string, RegExp][] = [
  ['not JSON', '{', /not JSON/],
  ['another format version', file([], 2), /formatVersion 2, needs 1/],
  ['no list', JSON.stringify({ formatVersion: 1 }), /not \{"formatVersion"/],
  ['an unknown field (a typo)', file([{ date: CORRECTED, question: 1, reason: 'Why.', addAcceptedAnswer: ['a'] }]), /unknown field addAcceptedAnswer/],
  ['no reason', file([{ date: CORRECTED, question: 1, addAcceptedAnswers: ['a'] }]), /no "reason"/],
  ['no change', file([{ date: CORRECTED, question: 1, reason: 'Why.' }]), /no change/],
  ['a question number of 0', file([{ date: CORRECTED, question: 0, reason: 'Why.', removeHint: true }]), /"question" is not a number from 1/],
  ['a bad date', file([{ date: '2026-10-32', question: 1, reason: 'Why.', removeHint: true }]), /"date" is not a YYYY-MM-DD date/],
  ['removeHint false', file([{ date: CORRECTED, question: 1, reason: 'Why.', removeHint: false }]), /"removeHint" can only be true/],
  ['an empty answer list', file([{ date: CORRECTED, question: 1, reason: 'Why.', addAcceptedAnswers: [] }]), /"addAcceptedAnswers" is not a list/],
  ['a blank wrong answer', file([{ date: CORRECTED, question: 1, reason: 'Why.', removeWrongAnswers: [' '] }]), /"removeWrongAnswers" is not a list/],
  [
    'the same question twice',
    file([
      { date: CORRECTED, question: 1, reason: 'Why.', removeHint: true },
      { date: CORRECTED, question: 1, reason: 'Why.', addAcceptedAnswers: ['a'] },
    ]),
    /corrected twice/,
  ],
];
for (const [name, text, pattern] of fileProblems) {
  test(`a corrections file with ${name} is a problem, and no correction is used`, () => {
    const parsed = parseCorrections(text);
    assert.deepEqual(parsed.corrections, []);
    assert.equal(parsed.problems.length, 1);
    assert.match(parsed.problems[0]!, pattern);
  });
}

test('the committed corrections file reads without problems', () => {
  const parsed = parseCorrections(readFileSync('tool/fallback_pool/corrections.json', 'utf8'));
  assert.deepEqual(parsed.problems, []);
});
