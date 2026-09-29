import { env } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { THINKING_HEADROOM_TOKENS, buildCheckSharedDailyTestBody, callAnthropic } from '../src/anthropic';
import {
  CHECKER_MODEL,
  CHECK_VERSION,
  MAX_ACCEPTED_ANSWERS,
  decideCheckedSet,
  decideQuestion,
  gradeAnswer,
  parseCheckOutput,
  selectCandidates,
  sharedCheckRequest,
  type CheckRejection,
  type CheckerModel,
  type QuestionCheck,
} from '../src/shared_check';
import type { SharedQuestion } from '../src/shared_daily_test';
import grading from './fixtures/daily_test_grading.json';

// ---------------------------------------------------------------------------
// Fixtures

function fillIn(overrides: Partial<SharedQuestion> = {}): SharedQuestion {
  return {
    id: 'q-modal',
    type: 'fill_in_blank',
    context: 'You ___ show your passport at the gate.',
    instruction: 'Fill in the blank with a modal verb that means it is required.',
    topicId: 'modalVerbs',
    correctAnswer: 'must',
    explanation: "'Must' says something is required, like a rule at the airport.",
    commonWrongAnswers: [
      { answer: 'might', comment: "'Might' is only a possibility, not a rule." },
      { answer: 'can', comment: "'Can' gives permission; here it's a requirement." },
    ],
    ...overrides,
  };
}

function errorCorrection(overrides: Partial<SharedQuestion> = {}): SharedQuestion {
  return {
    id: 'q-tense',
    type: 'error_correction',
    context: 'When we arrived, the plane already left.',
    instruction: 'Find the mistake and rewrite the full corrected sentence.',
    topicId: 'tenseSelection',
    correctAnswer: 'When we arrived, the plane had already left.',
    explanation: 'The plane left before you arrived, so the earlier action takes the past perfect.',
    commonWrongAnswers: [
      { answer: 'When we arrived, the plane has already left.', comment: "'Has left' is for now." },
      { answer: 'When we arrived, the plane already left.', comment: 'That is the sentence unchanged.' },
    ],
    ...overrides,
  };
}

/** A clean review of [question]. */
function review(question: SharedQuestion, overrides: Partial<QuestionCheck> = {}): QuestionCheck {
  return {
    id: question.id,
    originalSentence: question.type === 'error_correction' ? 'clearly_wrong' : 'not_applicable',
    correctAnswer: 'correct',
    acceptableAlternatives: [],
    acceptableWrongAnswers: [],
    incorrectRuleFields: [],
    explanationExcludesAlternatives: false,
    verdict: 'pass',
    ...overrides,
  };
}

const rejected = (reason: CheckRejection) => ({ pass: false, reason });

// ---------------------------------------------------------------------------
// The request

describe('check_shared_daily_test request', () => {
  const questions = [fillIn(), errorCorrection({ acceptedAnswers: ['NEVER SENT'] })];

  it('defaults to claude-sonnet-5 and counts the questions', () => {
    expect(CHECKER_MODEL).toBe('claude-sonnet-5');
    expect(sharedCheckRequest(questions)).toEqual({ questions, count: 2, model: 'claude-sonnet-5' });
  });

  it.each<CheckerModel>(['claude-sonnet-5', 'claude-sonnet-4-6', 'claude-opus-5-5'])(
    'sends %s with adaptive thinking and room for it',
    (model) => {
      const body = buildCheckSharedDailyTestBody(sharedCheckRequest(questions, model));
      expect(body.model).toBe(model);
      expect(body.thinking).toEqual({ type: 'adaptive' });
      expect(body.max_tokens).toBe(2048 + THINKING_HEADROOM_TOKENS);
    },
  );

  it('scales the review budget with the number of questions (10 over-generated candidates)', () => {
    const ten = Array.from({ length: 10 }, (_, i) => fillIn({ id: `q${i}` }));
    expect(buildCheckSharedDailyTestBody(sharedCheckRequest(ten)).max_tokens).toBe(4000 + THINKING_HEADROOM_TOKENS);
  });

  it("sends each question as a learner sees it, with the key, predictions and explanation, never acceptedAnswers", () => {
    const content = buildCheckSharedDailyTestBody(sharedCheckRequest(questions)).messages[0]?.content ?? '';
    expect(content.startsWith('Review these 2 questions:\n')).toBe(true);
    const sent = JSON.parse(content.slice(content.indexOf('\n') + 1)) as { questions: Record<string, unknown>[] };
    expect(sent.questions.map((q) => q.id)).toEqual(['q-modal', 'q-tense']);
    expect(Object.keys(sent.questions[1] ?? {})).toEqual([
      'id',
      'type',
      'topicId',
      'context',
      'instruction',
      'correctAnswer',
      'commonWrongAnswers',
      'explanation',
    ]);
    expect(content).not.toContain('NEVER SENT');
    expect(content).not.toContain('acceptedAnswers');
  });

  it('asks for the §2.2 review fields, each from its fixed values', () => {
    const body = buildCheckSharedDailyTestBody(sharedCheckRequest(questions));
    const item = (
      body.output_config.format.schema as {
        properties: { questions: { items: { required: string[]; properties: Record<string, { enum?: string[] }> } } };
      }
    ).properties.questions.items;
    expect(item.required).toEqual([
      'id',
      'originalSentence',
      'correctAnswer',
      'acceptableAlternatives',
      'acceptableWrongAnswers',
      'incorrectRuleFields',
      'explanationExcludesAlternatives',
      'verdict',
    ]);
    expect(item.properties.originalSentence?.enum).toEqual(['clearly_wrong', 'acceptable', 'not_applicable']);
    expect(item.properties.correctAnswer?.enum).toEqual(['correct', 'incorrect', 'uncertain']);
    expect(item.properties.verdict?.enum).toEqual(['pass', 'pass_with_alternatives', 'reject']);
    expect(body.system).toContain('Assume the set may contain mistakes');
  });

  it(`is pinned to CHECK_VERSION ${CHECK_VERSION}`, () => {
    // If this changes, the checker's prompt or schema changed: bump
    // CHECK_VERSION, then pin the new fingerprint here.
    const body = JSON.stringify(buildCheckSharedDailyTestBody(sharedCheckRequest([fillIn(), errorCorrection()])));
    let hash = 0x811c9dc5;
    for (let i = 0; i < body.length; i++) {
      hash ^= body.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    expect({ version: CHECK_VERSION, fingerprint: hash.toString(16) }).toEqual({ version: 1, fingerprint: '3c489122' });
  });
});

describe('callAnthropic with check_shared_daily_test', () => {
  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  let logged: string[] = [];

  beforeEach(() => {
    logged = [];
    console.log = (...args: unknown[]) => {
      logged.push(args.map(String).join(' '));
    };
    globalThis.fetch = (async () =>
      new Response(
        JSON.stringify({
          content: [
            { type: 'thinking', thinking: '' },
            { type: 'text', text: JSON.stringify({ questions: [review(fillIn())] }) },
          ],
          usage: { input_tokens: 2800, output_tokens: 2400 },
          stop_reason: 'end_turn',
        }),
        { status: 200 },
      )) as typeof fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
  });

  it('logs nothing of the questions or the review: numbers and names only', async () => {
    const secret = 'CHECK-CONTENT-SECRET-4410';
    const q = fillIn({ context: secret, explanation: secret, commonWrongAnswers: [{ answer: secret, comment: secret }, { answer: 'x', comment: secret }] });
    globalThis.fetch = (async () =>
      new Response(
        JSON.stringify({
          content: [{ type: 'text', text: JSON.stringify({ questions: [review(q, { acceptableAlternatives: [secret] })] }) }],
          usage: { input_tokens: 1, output_tokens: 1 },
          stop_reason: 'end_turn',
        }),
        { status: 200 },
      )) as typeof fetch;
    await callAnthropic(env, { op: 'check_shared_daily_test', request: sharedCheckRequest([q]) });
    expect(logged).toHaveLength(1);
    expect(logged.join('\n')).not.toContain(secret);
  });

  it('reads the text block after thinking, and files the call as daily_test cost (decision 11)', async () => {
    const result = await callAnthropic(env, { op: 'check_shared_daily_test', request: sharedCheckRequest([fillIn()]) });
    expect(result).toEqual({ questions: [review(fillIn())] });
    expect(logged.map((l) => JSON.parse(l) as unknown)).toEqual([
      {
        event: 'anthropic_usage',
        kind: 'daily_test',
        operation: 'check_shared_daily_test',
        item_count: 1,
        input_tokens: 2800,
        output_tokens: 2400,
        stop_reason: 'end_turn',
        duration_ms: expect.any(Number),
      },
    ]);
  });
});

// ---------------------------------------------------------------------------
// Reading the review

describe('parseCheckOutput', () => {
  const questions = [fillIn(), errorCorrection()];
  const good = () => ({ questions: questions.map((q) => review(q) as unknown as Record<string, unknown>) });

  it('reads one review per question, by id, in any order', () => {
    const output = good();
    output.questions.reverse();
    expect([...(parseCheckOutput(output, questions)?.keys() ?? [])].sort()).toEqual(['q-modal', 'q-tense']);
  });

  it.each([
    ['not an object', () => 'text'],
    ['no questions array', () => ({ reviews: [] })],
    ['a review missing', () => ({ questions: good().questions.slice(1) })],
    ['an unknown id', () => ({ questions: [good().questions[0], { ...good().questions[1], id: 'other' }] })],
    ['a repeated id', () => ({ questions: [good().questions[0], good().questions[0]] })],
    ['a value outside the enum', () => ({ questions: [good().questions[0], { ...good().questions[1], verdict: 'ok' }] })],
    ['a rule field outside the enum', () => ({ questions: [good().questions[0], { ...good().questions[1], incorrectRuleFields: ['title'] }] })],
    ['alternatives that are not strings', () => ({ questions: [good().questions[0], { ...good().questions[1], acceptableAlternatives: [1] }] })],
    ['a missing boolean', () => ({ questions: [good().questions[0], { ...good().questions[1], explanationExcludesAlternatives: undefined }] })],
  ])('is unusable with %s', (_name, output) => {
    expect(parseCheckOutput(output(), questions)).toBeNull();
  });
});

// ---------------------------------------------------------------------------
// The decision table (§2.3)

describe('decideQuestion — §2.3 rows in order', () => {
  it('passes a clean review with no alternatives', () => {
    expect(decideQuestion(fillIn(), review(fillIn()))).toEqual({ pass: true, acceptedAnswers: [] });
  });

  it('1. rejects an error_correction whose original is not clearly wrong', () => {
    const q = errorCorrection();
    expect(decideQuestion(q, review(q, { originalSentence: 'acceptable' }))).toEqual(rejected('original_not_wrong'));
    expect(decideQuestion(q, review(q, { originalSentence: 'not_applicable' }))).toEqual(rejected('original_not_wrong'));
    // Only error_correction has an original to judge.
    expect(decideQuestion(fillIn(), review(fillIn(), { originalSentence: 'acceptable' })).pass).toBe(true);
  });

  it('2. rejects a key that is incorrect or uncertain', () => {
    expect(decideQuestion(fillIn(), review(fillIn(), { correctAnswer: 'incorrect' }))).toEqual(rejected('key_incorrect'));
    expect(decideQuestion(fillIn(), review(fillIn(), { correctAnswer: 'uncertain' }))).toEqual(rejected('key_incorrect'));
  });

  it('3. rejects a false rule in the hint, explanation or a comment', () => {
    for (const field of ['hint', 'explanation', 'comment'] as const) {
      expect(decideQuestion(fillIn(), review(fillIn(), { incorrectRuleFields: [field] }))).toEqual(rejected('wrong_rule'));
    }
  });

  it('4. rejects an acceptable predicted wrong answer', () => {
    expect(decideQuestion(fillIn(), review(fillIn(), { acceptableWrongAnswers: ['can'] }))).toEqual(
      rejected('wrong_answer_acceptable'),
    );
  });

  it('5. rejects an explanation that rules out an alternative', () => {
    const check = review(fillIn(), { acceptableAlternatives: ['have to'], explanationExcludesAlternatives: true });
    expect(decideQuestion(fillIn(), check)).toEqual(rejected('explanation_excludes_alternative'));
  });

  it(`6. accepts up to ${MAX_ACCEPTED_ANSWERS} alternatives and rejects more`, () => {
    const two = review(fillIn(), { acceptableAlternatives: ['have to', 'need to'], verdict: 'pass_with_alternatives' });
    expect(decideQuestion(fillIn(), two)).toEqual({ pass: true, acceptedAnswers: ['have to', 'need to'] });
    const three = review(fillIn(), { acceptableAlternatives: ['have to', 'need to', 'should'] });
    expect(decideQuestion(fillIn(), three)).toEqual(rejected('ambiguous_question'));
  });

  it('7. rejects an alternative that is the flawed sentence itself', () => {
    const q = errorCorrection();
    const check = review(q, { acceptableAlternatives: ['when we arrived,   the plane ALREADY left'] });
    expect(decideQuestion(q, check)).toEqual(rejected('alternative_is_original'));
  });

  it('8. rejects an alternative that is a predicted wrong answer, also by keyboard variant', () => {
    expect(decideQuestion(fillIn(), review(fillIn(), { acceptableAlternatives: ['Might.'] }))).toEqual(
      rejected('alternative_conflicts_wrong_answer'),
    );
    const q = fillIn({ commonWrongAnswers: [{ answer: 'going', comment: 'c' }, { answer: 'goes', comment: 'c' }] });
    expect(decideQuestion(q, review(q, { acceptableAlternatives: ['goıng'] }))).toEqual(
      rejected('alternative_conflicts_wrong_answer'),
    );
  });

  it('9. rejects when every field passes but the verdict says reject', () => {
    expect(decideQuestion(fillIn(), review(fillIn(), { verdict: 'reject' }))).toEqual(rejected('checker_verdict'));
  });

  it('drops noise instead of rejecting: blanks, over-long text, the key again, repeats', () => {
    const check = review(fillIn(), {
      acceptableAlternatives: ['  ', '.', 'x'.repeat(301), 'MUST.', 'muşt', 'have to', ' Have to ', 'need to'],
      verdict: 'pass_with_alternatives',
    });
    expect(decideQuestion(fillIn(), check)).toEqual({ pass: true, acceptedAnswers: ['have to', 'need to'] });
  });

  it('applies the rows in table order: the earliest failing row is the reason', () => {
    const q = errorCorrection();
    const everything = review(q, {
      originalSentence: 'acceptable',
      correctAnswer: 'incorrect',
      incorrectRuleFields: ['explanation'],
      acceptableWrongAnswers: ['x'],
      verdict: 'reject',
    });
    expect(decideQuestion(q, everything)).toEqual(rejected('original_not_wrong'));
    expect(decideQuestion(q, { ...everything, originalSentence: 'clearly_wrong' })).toEqual(rejected('key_incorrect'));
    expect(decideQuestion(q, { ...everything, originalSentence: 'clearly_wrong', correctAnswer: 'correct' })).toEqual(
      rejected('wrong_rule'),
    );
  });
});

describe("the owner's reviewed cases (2026-09-26/27), as a checker that sees them would report them", () => {
  // Paraphrased from the owner's review (docs/1.1.0-shared-daily-test-quality.md §0).
  it('(a) a right key with an invented rule in the hint and explanation → wrong_rule', () => {
    const q = fillIn({ id: 'a', topicId: 'modalPastForms', correctAnswer: 'should have come', hint: 'In reported speech, should becomes should have.' });
    expect(decideQuestion(q, review(q, { incorrectRuleFields: ['hint', 'explanation'], verdict: 'reject' }))).toEqual(
      rejected('wrong_rule'),
    );
  });

  it('(b) "must" and "should" both defensible → published, with "should" accepted', () => {
    const q = fillIn({ id: 'b' });
    const check = review(q, { acceptableAlternatives: ['should'], verdict: 'pass_with_alternatives' });
    expect(decideQuestion(q, check)).toEqual({ pass: true, acceptedAnswers: ['should'] });
  });

  it('(c) an acceptable sentence "corrected" by a false rule, with a right answer listed as wrong → original_not_wrong', () => {
    const q = errorCorrection({
      id: 'c',
      topicId: 'modalVerbs',
      context: 'I knew I must study harder.',
      correctAnswer: 'I knew I should study harder.',
      commonWrongAnswers: [
        { answer: 'I knew I had to study harder.', comment: 'c' },
        { answer: 'I knew I must studied harder.', comment: 'c' },
      ],
    });
    const check = review(q, {
      originalSentence: 'acceptable',
      acceptableWrongAnswers: ['I knew I had to study harder.'],
      incorrectRuleFields: ['explanation'],
      verdict: 'reject',
    });
    expect(decideQuestion(q, check)).toEqual(rejected('original_not_wrong'));
  });

  it('(d) no clear error to correct → original_not_wrong', () => {
    const q = errorCorrection({
      id: 'd',
      topicId: 'articles',
      context: 'I usually go to a library on campus.',
      correctAnswer: 'I usually go to the library on campus.',
    });
    expect(decideQuestion(q, review(q, { originalSentence: 'acceptable', verdict: 'reject' }))).toEqual(
      rejected('original_not_wrong'),
    );
  });
});

// ---------------------------------------------------------------------------
// Whole sets

describe('decideCheckedSet (one candidate per slot)', () => {
  const questions = [fillIn(), errorCorrection()];

  it('publishes when every question passes, in order, each with acceptedAnswers (possibly empty)', () => {
    const output = {
      questions: [
        review(questions[1] as SharedQuestion),
        review(questions[0] as SharedQuestion, { acceptableAlternatives: ['have to'], verdict: 'pass_with_alternatives' }),
      ],
    };
    expect(decideCheckedSet(questions, output)).toEqual({
      outcome: 'publish',
      questions: [
        { ...questions[0], acceptedAnswers: ['have to'] },
        { ...questions[1], acceptedAnswers: [] },
      ],
      alternativesAdded: 1,
      questionsRejected: 0,
    });
  });

  it('rejects the set for one failing question, with the first reason in plan order and the count', () => {
    const output = {
      questions: [
        review(questions[0] as SharedQuestion, { correctAnswer: 'incorrect' }),
        review(questions[1] as SharedQuestion, { originalSentence: 'acceptable' }),
      ],
    };
    expect(decideCheckedSet(questions, output)).toEqual({ outcome: 'reject', reason: 'key_incorrect', questionsRejected: 2 });
  });

  it('is unreadable, not a rejection, when the review cannot be used', () => {
    expect(decideCheckedSet(questions, { questions: [review(fillIn())] })).toEqual({ outcome: 'unreadable' });
  });
});

describe('selectCandidates (two candidates per slot, strategy S2)', () => {
  const slotA = [fillIn({ id: 'a1' }), fillIn({ id: 'a2' })];
  const slotB = [errorCorrection({ id: 'b1' }), errorCorrection({ id: 'b2' })];

  it('chooses the passing candidate with the fewest alternatives, then the first', () => {
    const output = {
      questions: [
        review(slotA[0] as SharedQuestion, { acceptableAlternatives: ['have to'] }),
        review(slotA[1] as SharedQuestion),
        review(slotB[0] as SharedQuestion),
        review(slotB[1] as SharedQuestion),
      ],
    };
    const decision = selectCandidates([slotA, slotB], output);
    expect(decision.outcome).toBe('publish');
    if (decision.outcome !== 'publish') return;
    expect(decision.questions.map((q) => q.id)).toEqual(['a2', 'b1']);
    expect(decision.alternativesAdded).toBe(0);
  });

  it('fills a slot from its second candidate when the first fails', () => {
    const output = {
      questions: [
        review(slotA[0] as SharedQuestion, { correctAnswer: 'incorrect' }),
        review(slotA[1] as SharedQuestion),
        review(slotB[0] as SharedQuestion),
        review(slotB[1] as SharedQuestion, { originalSentence: 'acceptable' }),
      ],
    };
    const decision = selectCandidates([slotA, slotB], output);
    expect(decision).toMatchObject({ outcome: 'publish', questionsRejected: 2 });
    if (decision.outcome === 'publish') expect(decision.questions.map((q) => q.id)).toEqual(['a2', 'b1']);
  });

  it("rejects when a slot has no passing candidate, with that slot's first reason", () => {
    const output = {
      questions: [
        review(slotA[0] as SharedQuestion),
        review(slotA[1] as SharedQuestion),
        review(slotB[0] as SharedQuestion, { originalSentence: 'acceptable' }),
        review(slotB[1] as SharedQuestion, { correctAnswer: 'uncertain' }),
      ],
    };
    expect(selectCandidates([slotA, slotB], output)).toEqual({
      outcome: 'reject',
      reason: 'original_not_wrong',
      questionsRejected: 2,
    });
  });

  it('needs a review of every candidate', () => {
    const output = { questions: [review(slotA[0] as SharedQuestion), review(slotB[0] as SharedQuestion)] };
    expect(selectCandidates([slotA, slotB], output)).toEqual({ outcome: 'unreadable' });
  });
});

// ---------------------------------------------------------------------------
// Grading with acceptedAnswers (the contract for C1)

describe('gradeAnswer — test/fixtures/daily_test_grading.json', () => {
  it.each(grading.cases)('grades $input as $kind', ({ input, kind }) => {
    expect(gradeAnswer(grading.question, input)).toBe(kind);
  });

  it('grades like today without acceptedAnswers', () => {
    const { acceptedAnswers: _unused, ...legacy } = grading.question;
    expect(gradeAnswer(legacy, 'I knew I should study harder.')).toBe('fallback');
  });

  it('leaves every branch reachable in a set the check published', () => {
    const q = errorCorrection();
    const check = review(q, {
      acceptableAlternatives: ['When we arrived, the plane had left already.'],
      verdict: 'pass_with_alternatives',
    });
    const decision = decideCheckedSet([q], { questions: [check] });
    expect(decision.outcome).toBe('publish');
    if (decision.outcome !== 'publish') return;
    const published = decision.questions[0] as SharedQuestion;
    expect(gradeAnswer(published, published.correctAnswer)).toBe('correct');
    for (const accepted of published.acceptedAnswers ?? []) expect(gradeAnswer(published, accepted)).toBe('accepted');
    for (const wrong of published.commonWrongAnswers) expect(gradeAnswer(published, wrong.answer)).toBe('commonWrong');
  });
});
