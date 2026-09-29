import { env } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import {
  THINKING_HEADROOM_TOKENS,
  buildGenerateSharedDailyTestBody,
  callAnthropic,
  dailyTestMaxTokensFor,
} from '../src/anthropic';
import {
  ERROR_CORRECTION_MAX_EDIT_WORDS,
  ERROR_CORRECTION_MIN_WORDS,
  EXPLANATION_MAX_WORDS,
  SCENARIO_THEMES,
  SHARED_PROMPT_VERSION,
  SHARED_SET_QUESTION_COUNT,
  dailyPlan,
  dateOfDayNumber,
  dayNumberOf,
  foldKeyboardVariants,
  isInServingWindow,
  isSingleShortEdit,
  GENERATOR_MODELS,
  SHARED_GENERATOR,
  normalizeAnswer,
  sharedDailyTestRequest,
  validateSharedCandidates,
  validateSharedSet,
  type DailyPlan,
  type SharedGenerationOptions,
  type SharedPromptVersion,
  type SharedSetRejection,
} from '../src/shared_daily_test';
import { TOPICS } from '../src/topics';
import normalizationCases from './fixtures/answer_normalization.json';

const at = (iso: string) => new Date(iso);

describe('dayNumberOf', () => {
  it('reads real calendar dates, including leap days', () => {
    expect(dayNumberOf('1970-01-01')).toBe(0);
    expect(dayNumberOf('2026-09-26')).toBe(20_722);
    expect(dayNumberOf('2028-02-29')).not.toBeNull();
    expect(dayNumberOf('2000-02-29')).not.toBeNull();
  });

  it.each([
    ['2027-02-29'], // not a leap year
    ['2100-02-29'], // century, not a leap year
    ['2026-02-30'],
    ['2026-04-31'],
    ['2026-13-01'],
    ['2026-00-10'],
    ['2026-09-00'],
    ['0050-01-01'], // Date.UTC would read this as 1950
    ['2026-9-26'],
    ['2026-09-26T00:00'],
    [' 2026-09-26'],
    ['2026-09-26 '],
    ['26-09-2026'],
    [''],
  ])('rejects %j', (value) => {
    expect(dayNumberOf(value)).toBeNull();
  });

  it('rejects anything that is not a string', () => {
    for (const value of [20260926, null, undefined, {}, ['2026-09-26']]) {
      expect(dayNumberOf(value)).toBeNull();
    }
  });

  it('round-trips through dateOfDayNumber across month, year and leap boundaries', () => {
    for (const date of ['2026-01-31', '2026-02-28', '2026-12-31', '2027-01-01', '2028-02-29', '2028-03-01']) {
      expect(dateOfDayNumber(dayNumberOf(date) as number)).toBe(date);
    }
    expect(dateOfDayNumber((dayNumberOf('2028-02-28') as number) + 1)).toBe('2028-02-29');
    expect(dateOfDayNumber((dayNumberOf('2027-02-28') as number) + 1)).toBe('2027-03-01');
  });
});

describe('isInServingWindow — [UTC today − 1, UTC today + 2]', () => {
  const now = at('2026-09-26T12:00:00Z');

  it('accepts −1, 0, +1 and +2, and refuses −2 and +3', () => {
    expect(isInServingWindow('2026-09-24', now)).toBe(false); // −2
    expect(isInServingWindow('2026-09-25', now)).toBe(true); // −1
    expect(isInServingWindow('2026-09-26', now)).toBe(true); // 0
    expect(isInServingWindow('2026-09-27', now)).toBe(true); // +1
    expect(isInServingWindow('2026-09-28', now)).toBe(true); // +2
    expect(isInServingWindow('2026-09-29', now)).toBe(false); // +3
  });

  it('moves with the UTC date, not the hour', () => {
    const firstMs = at('2026-09-26T00:00:00.000Z');
    const lastMs = at('2026-09-26T23:59:59.999Z');
    for (const t of [firstMs, lastMs]) {
      expect(isInServingWindow('2026-09-25', t)).toBe(true);
      expect(isInServingWindow('2026-09-28', t)).toBe(true);
      expect(isInServingWindow('2026-09-24', t)).toBe(false);
      expect(isInServingWindow('2026-09-29', t)).toBe(false);
    }
    const nextDay = at('2026-09-27T00:00:00.000Z');
    expect(isInServingWindow('2026-09-25', nextDay)).toBe(false);
    expect(isInServingWindow('2026-09-29', nextDay)).toBe(true);
  });

  it('crosses a month end', () => {
    const now2 = at('2026-09-30T08:00:00Z');
    expect(isInServingWindow('2026-10-02', now2)).toBe(true); // +2
    expect(isInServingWindow('2026-10-03', now2)).toBe(false); // +3
    expect(isInServingWindow('2026-09-29', now2)).toBe(true); // −1
  });

  it('crosses a year end, in both directions', () => {
    const newYearsEve = at('2026-12-31T23:00:00Z');
    expect(isInServingWindow('2027-01-02', newYearsEve)).toBe(true); // +2
    expect(isInServingWindow('2027-01-03', newYearsEve)).toBe(false); // +3
    expect(isInServingWindow('2026-12-30', newYearsEve)).toBe(true); // −1
    expect(isInServingWindow('2026-12-29', newYearsEve)).toBe(false); // −2

    const newYearsDay = at('2027-01-01T00:30:00Z');
    expect(isInServingWindow('2026-12-31', newYearsDay)).toBe(true); // −1
    expect(isInServingWindow('2026-12-30', newYearsDay)).toBe(false); // −2
    expect(isInServingWindow('2027-01-03', newYearsDay)).toBe(true); // +2
  });

  it('counts a leap day as a day', () => {
    const leap = at('2028-02-28T10:00:00Z');
    expect(isInServingWindow('2028-02-29', leap)).toBe(true); // +1
    expect(isInServingWindow('2028-03-01', leap)).toBe(true); // +2
    expect(isInServingWindow('2028-03-02', leap)).toBe(false); // +3

    const afterLeap = at('2028-03-01T10:00:00Z');
    expect(isInServingWindow('2028-02-29', afterLeap)).toBe(true); // −1
    expect(isInServingWindow('2028-02-28', afterLeap)).toBe(false); // −2

    const noLeap = at('2027-02-28T10:00:00Z');
    expect(isInServingWindow('2027-03-02', noLeap)).toBe(true); // +2 (no Feb 29)
    expect(isInServingWindow('2027-03-03', noLeap)).toBe(false); // +3
  });

  it('refuses an invalid date even when it would fall inside the window', () => {
    expect(isInServingWindow('2027-02-29', at('2027-02-28T10:00:00Z'))).toBe(false);
    expect(isInServingWindow('2026-9-26', now)).toBe(false);
    expect(isInServingWindow(undefined, now)).toBe(false);
  });
});

describe('dailyPlan', () => {
  const topicIds = TOPICS.map((t) => t.id);

  it('is a function of the date alone: the same date always gives the same plan', () => {
    const first = dailyPlan('2026-10-05');
    const again = dailyPlan('2026-10-05');
    expect(again).toEqual(first);
    // Not the same object, so nothing is cached between calls.
    expect(again).not.toBe(first);
  });

  it('keeps a pinned date pinned, so a regeneration of the same date asks for the same plan', () => {
    // If this fails, the plan algorithm changed: that is a new
    // SHARED_PROMPT_VERSION, and sets already published were planned by the old one.
    expect(dailyPlan('2026-10-05')).toMatchInlineSnapshot(`
      {
        "date": "2026-10-05",
        "slots": [
          {
            "topicId": "modalPastForms",
            "type": "error_correction",
          },
          {
            "topicId": "articles",
            "type": "error_correction",
          },
          {
            "topicId": "modalVerbs",
            "type": "fill_in_blank",
          },
          {
            "topicId": "tenseSelection",
            "type": "error_correction",
          },
          {
            "topicId": "gerundVsInfinitive",
            "type": "fill_in_blank",
          },
        ],
        "theme": "housing",
      }
    `);
  });

  it('covers every topic exactly once, with a 3/2 or 2/3 split, and a theme from the list', () => {
    for (let day = dayNumberOf('2026-09-01') as number; day < (dayNumberOf('2027-09-01') as number); day++) {
      const plan = dailyPlan(dateOfDayNumber(day));
      expect(plan.slots.map((s) => s.topicId).sort()).toEqual([...topicIds].sort());
      const fills = plan.slots.filter((s) => s.type === 'fill_in_blank').length;
      expect([2, 3]).toContain(fills);
      expect(plan.slots).toHaveLength(SHARED_SET_QUESTION_COUNT);
      expect(SCENARIO_THEMES).toContain(plan.theme);
    }
  });

  it('uses every one of the 14 themes in any 14 consecutive days', () => {
    for (const start of ['2026-10-01', '2026-12-25', '2028-02-20']) {
      const first = dayNumberOf(start) as number;
      const themes = new Set(Array.from({ length: 14 }, (_, i) => dailyPlan(dateOfDayNumber(first + i)).theme));
      expect(themes.size).toBe(14);
    }
    expect(SCENARIO_THEMES).toHaveLength(14);
  });

  it('alternates the 3/2 and 2/3 split day by day', () => {
    const first = dayNumberOf('2026-10-01') as number;
    const fills = (day: number) =>
      dailyPlan(dateOfDayNumber(day)).slots.filter((s) => s.type === 'fill_in_blank').length;
    let alternations = 0;
    for (let d = first; d < first + 60; d++) if (fills(d) !== fills(d + 1)) alternations++;
    // Every day flips, except once at each 14-day theme boundary.
    expect(alternations).toBeGreaterThanOrEqual(55);
  });

  it('gives a theme a different split in the next 14-day cycle', () => {
    const d = dayNumberOf('2026-10-01') as number;
    const fills = (day: number) =>
      dailyPlan(dateOfDayNumber(day)).slots.filter((s) => s.type === 'fill_in_blank').length;
    expect(dailyPlan(dateOfDayNumber(d)).theme).toBe(dailyPlan(dateOfDayNumber(d + 14)).theme);
    expect(fills(d)).not.toBe(fills(d + 14));
  });

  it('varies the topic order across days (the 1.0.0 sets always had the same order)', () => {
    const first = dayNumberOf('2026-10-01') as number;
    const orders = new Set(
      Array.from({ length: 14 }, (_, i) =>
        dailyPlan(dateOfDayNumber(first + i))
          .slots.map((s) => s.topicId)
          .join(','),
      ),
    );
    expect(orders.size).toBeGreaterThanOrEqual(10);
    const leads = new Set(
      Array.from({ length: 30 }, (_, i) => dailyPlan(dateOfDayNumber(first + i)).slots[0]?.topicId),
    );
    expect(leads.size).toBe(5);
  });

  it('refuses a date that is not a real calendar date', () => {
    expect(() => dailyPlan('2027-02-29')).toThrow();
    expect(() => dailyPlan('tomorrow')).toThrow();
  });
});

describe('normalizeAnswer / foldKeyboardVariants — same results as the Dart code', () => {
  it('matches every normalize case produced by lib/utils/answer_matching.dart', () => {
    expect(normalizationCases.normalize.length).toBeGreaterThan(10);
    for (const { input, expected } of normalizationCases.normalize) {
      expect(normalizeAnswer(input), JSON.stringify(input)).toBe(expected);
    }
  });

  it('matches every fold case produced by the Dart code', () => {
    for (const { input, expected } of normalizationCases.fold) {
      expect(foldKeyboardVariants(input), JSON.stringify(input)).toBe(expected);
    }
  });

  it("lowercases '\u0130' to a plain 'i' like Dart, not to JavaScript's 'i' + combining dot", () => {
    expect('\u0130'.toLowerCase()).toBe('i\u0307'); // the JavaScript behavior being corrected
    expect(normalizeAnswer('\u0130S')).toBe('is');
  });
});

// ---------------------------------------------------------------------------
// validateSharedSet

const PLAN: DailyPlan = {
  date: '2026-10-05',
  theme: 'travel',
  slots: [
    { topicId: 'articles', type: 'fill_in_blank' },
    { topicId: 'modalPastForms', type: 'error_correction' },
    { topicId: 'gerundVsInfinitive', type: 'fill_in_blank' },
    { topicId: 'tenseSelection', type: 'error_correction' },
    { topicId: 'modalVerbs', type: 'fill_in_blank' },
  ],
};

type Question = Record<string, unknown>;

function validQuestions(): Question[] {
  return [
    {
      id: 'q-articles',
      type: 'fill_in_blank',
      context: 'We stayed at ___ hotel you recommended.',
      instruction: 'Fill in the blank with the correct article.',
      topicId: 'articles',
      correctAnswer: 'the',
      explanation: "Use 'the' when both speakers know which hotel is meant.",
      commonWrongAnswers: [
        { answer: 'a', comment: "'A' is for any hotel, but you mean one you both know." },
        { answer: 'an', comment: "'An' goes before a vowel sound, and this one is specific anyway." },
      ],
    },
    {
      id: 'q-modal-past',
      type: 'error_correction',
      context: 'You must have told me the train was cancelled, I waited for an hour.',
      instruction: 'Find the mistake and rewrite the full corrected sentence.',
      topicId: 'modalPastForms',
      correctAnswer: 'You should have told me the train was cancelled, I waited for an hour.',
      explanation: "For a past duty that wasn't done, use 'should have' plus the past participle.",
      commonWrongAnswers: [
        {
          answer: 'You must told me the train was cancelled, I waited for an hour.',
          comment: "'Must' can't take a past form here; you need 'should have told'.",
        },
        {
          answer: 'You should told me the train was cancelled, I waited for an hour.',
          comment: "After 'should' for the past, add 'have': 'should have told'.",
        },
        {
          answer: 'You must have told me the train was cancelled, I waited for an hour.',
          comment: "'Must have' guesses about the past; here you mean it was the right thing to do.",
        },
      ],
    },
    {
      id: 'q-gerund',
      type: 'fill_in_blank',
      context: 'I really enjoy ___ by train.',
      instruction: 'Fill in the blank with the correct form of the verb in brackets.',
      hint: '(travel)',
      topicId: 'gerundVsInfinitive',
      correctAnswer: 'travelling',
      explanation: "After 'enjoy', the next verb takes the -ing form.",
      commonWrongAnswers: [
        { answer: 'to travel', comment: "'Enjoy' is followed by -ing, not 'to'." },
        { answer: 'travel', comment: "The verb after 'enjoy' needs -ing." },
      ],
    },
    {
      id: 'q-tense',
      type: 'error_correction',
      context: 'When we arrived, the plane already left.',
      instruction: 'Find the mistake and rewrite the full corrected sentence.',
      topicId: 'tenseSelection',
      correctAnswer: 'When we arrived, the plane had already left.',
      explanation: 'The plane left before you arrived, so the earlier action takes the past perfect.',
      commonWrongAnswers: [
        { answer: 'When we arrived, the plane has already left.', comment: "'Has left' is for now; this is before a past moment." },
        { answer: 'When we arrived, the plane was already leaving.', comment: 'That says it was still leaving; it had gone.' },
      ],
    },
    {
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
    },
  ];
}

function validate(questions: Question[], plan: DailyPlan = PLAN) {
  return validateSharedSet({ questions }, plan);
}

function expectRejected(questions: Question[], reason: SharedSetRejection, plan: DailyPlan = PLAN) {
  expect(validate(questions, plan)).toEqual({ ok: false, reason });
}

/** The valid set with one question changed. */
function withQuestion(index: number, change: (q: Question) => void): Question[] {
  const questions = validQuestions();
  change(questions[index] as Question);
  return questions;
}

describe('validateSharedSet', () => {
  it('passes a well-formed set and returns it in plan order, text unchanged', () => {
    const shuffled = validQuestions().reverse();
    const result = validate(shuffled);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.questions.map((q) => q.topicId)).toEqual(PLAN.slots.map((s) => s.topicId));
    expect(result.questions).toEqual(validQuestions());
  });

  it('keeps only the known fields, and optional ones only when present', () => {
    const questions = withQuestion(0, (q) => {
      q.extra = 'dropped';
      delete q.context;
    });
    const result = validate(questions);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    const first = result.questions[0] as unknown as Record<string, unknown>;
    expect(Object.keys(first).sort()).toEqual(
      ['commonWrongAnswers', 'correctAnswer', 'explanation', 'id', 'instruction', 'topicId', 'type'].sort(),
    );
  });

  describe('not_an_object', () => {
    it('rejects content that is not {questions: [...]}', () => {
      for (const content of [null, 'text', [], { items: [] }, { questions: 'x' }]) {
        expect(validateSharedSet(content, PLAN)).toEqual({ ok: false, reason: 'not_an_object' });
      }
    });
  });

  describe('wrong_question_count', () => {
    it('rejects too few and too many questions', () => {
      expectRejected(validQuestions().slice(0, 4), 'wrong_question_count');
      expectRejected([...validQuestions(), { ...validQuestions()[0], id: 'q-extra' }], 'wrong_question_count');
      expectRejected([], 'wrong_question_count');
    });
  });

  describe('missing_field', () => {
    it.each(['id', 'topicId', 'instruction', 'correctAnswer', 'explanation', 'commonWrongAnswers'])(
      'rejects a question without %s',
      (field) => {
        expectRejected(
          withQuestion(1, (q) => {
            delete q[field];
          }),
          'missing_field',
        );
      },
    );

    it('rejects blank or non-string required text', () => {
      expectRejected(withQuestion(0, (q) => (q.instruction = '   ')), 'missing_field');
      expectRejected(withQuestion(0, (q) => (q.correctAnswer = 7)), 'missing_field');
      expectRejected(withQuestion(0, (q) => (q.context = 42)), 'missing_field');
      expectRejected(withQuestion(0, (q) => (q.hint = null)), 'missing_field');
    });

    it('rejects a blank predicted answer or comment, and a question that is not an object', () => {
      expectRejected(
        withQuestion(2, (q) => (q.commonWrongAnswers = [{ answer: 'x', comment: '' }, { answer: 'y', comment: 'c' }])),
        'missing_field',
      );
      expectRejected(
        withQuestion(2, (q) => (q.commonWrongAnswers = [{ answer: 'x' }, { answer: 'y', comment: 'c' }])),
        'missing_field',
      );
      const questions = validQuestions();
      questions[3] = 'not a question' as unknown as Question;
      expectRejected(questions, 'missing_field');
    });
  });

  describe('text_too_long', () => {
    it('rejects an id over 100 characters and any other text over 2000', () => {
      expectRejected(withQuestion(0, (q) => (q.id = 'x'.repeat(101))), 'text_too_long');
      expectRejected(withQuestion(0, (q) => (q.context = 'x'.repeat(2001))), 'text_too_long');
      expect(validate(withQuestion(0, (q) => (q.id = 'x'.repeat(100)))).ok).toBe(true);
    });
  });

  describe('duplicate_id', () => {
    it('rejects two questions with the same id', () => {
      expectRejected(withQuestion(4, (q) => (q.id = 'q-articles')), 'duplicate_id');
    });
  });

  describe('plan_mismatch', () => {
    it('rejects a type the plan does not give that topic', () => {
      // An otherwise valid error-correction item, so only the type is wrong.
      expectRejected(
        withQuestion(0, (q) => {
          q.type = 'error_correction';
          q.context = 'We stayed at a hotel you recommended.';
          q.correctAnswer = 'We stayed at the hotel you recommended.';
        }),
        'plan_mismatch',
      );
    });

    it('rejects an unknown type or topic', () => {
      expectRejected(withQuestion(0, (q) => (q.type = 'sentence_writing')), 'plan_mismatch');
      expectRejected(withQuestion(0, (q) => (q.topicId = 'phrasalVerbs')), 'plan_mismatch');
    });

    it('rejects a topic twice (and so another missing)', () => {
      expectRejected(
        withQuestion(4, (q) => {
          q.topicId = 'articles';
        }),
        'plan_mismatch',
      );
    });
  });

  describe('wrong_answer_count', () => {
    it('rejects fewer than 2 or more than 3 predicted wrong answers', () => {
      expectRejected(
        withQuestion(0, (q) => (q.commonWrongAnswers = (q.commonWrongAnswers as unknown[]).slice(0, 1))),
        'wrong_answer_count',
      );
      expectRejected(
        withQuestion(0, (q) => (q.commonWrongAnswers = [])),
        'wrong_answer_count',
      );
      expectRejected(
        withQuestion(1, (q) =>
          (q.commonWrongAnswers as unknown[]).push({ answer: 'You should had told me.', comment: 'c' }),
        ),
        'wrong_answer_count',
      );
      // 3 is fine (question 1 already has 3).
      expect(validate(validQuestions()).ok).toBe(true);
    });
  });

  describe('blank_correct_answer', () => {
    it('rejects a correct answer that normalizes to nothing', () => {
      expectRejected(withQuestion(0, (q) => (q.correctAnswer = ' . ')), 'blank_correct_answer');
    });
  });

  describe('wrong_answer_matches_correct', () => {
    it('rejects a prediction equal to the key after normalizing (case, spaces, final full stop, curly quotes)', () => {
      expectRejected(
        withQuestion(3, (q) => {
          (q.commonWrongAnswers as { answer: string }[])[1] = {
            answer: '  when we arrived,  the plane HAD already left ',
            comment: 'c',
          } as never;
        }),
        'wrong_answer_matches_correct',
      );
      expectRejected(
        withQuestion(0, (q) => {
          q.correctAnswer = "isn't";
          q.commonWrongAnswers = [
            { answer: 'isn\u2019t', comment: 'c' },
            { answer: 'aren\u2019t', comment: 'c' },
          ];
        }),
        'wrong_answer_matches_correct',
      );
    });

    it('rejects a prediction that is the key typed with Turkish-keyboard letters', () => {
      expectRejected(
        withQuestion(2, (q) => {
          q.commonWrongAnswers = [
            { answer: 'travellıng', comment: 'c' },
            { answer: 'to travel', comment: 'c' },
          ];
        }),
        'wrong_answer_matches_correct',
      );
    });
  });

  describe('duplicate_wrong_answer', () => {
    it('rejects two predictions that normalize to the same answer', () => {
      expectRejected(
        withQuestion(2, (q) => {
          q.commonWrongAnswers = [
            { answer: 'to travel', comment: 'c1' },
            { answer: 'To travel.', comment: 'c2' },
          ];
        }),
        'duplicate_wrong_answer',
      );
    });
  });

  describe('unchanged_error_correction', () => {
    it('rejects an error-correction key that is the flawed sentence itself', () => {
      expectRejected(
        withQuestion(3, (q) => (q.correctAnswer = 'when we arrived, the plane already left')),
        'unchanged_error_correction',
      );
    });

    it('does not apply the rule to fill-in-the-blank', () => {
      expect(validate(withQuestion(0, (q) => (q.context = 'the'))).ok).toBe(true);
    });
  });

  describe('error_correction_missing_sentence', () => {
    // E, 2026-09-28: 19 of 28 error_correction questions from claude-sonnet-4-6
    // had no "context" at all, and no other field held the sentence to correct.
    const tenseWith = (edit: (q: Question) => void) => withQuestion(3, edit);

    it('rejects an error_correction question with no "context" field', () => {
      expectRejected(tenseWith((q) => delete q.context), 'error_correction_missing_sentence');
    });

    it('rejects an empty or whitespace-only "context"', () => {
      expectRejected(tenseWith((q) => (q.context = '')), 'error_correction_missing_sentence');
      expectRejected(tenseWith((q) => (q.context = ' \n\t ')), 'error_correction_missing_sentence');
    });

    it(`rejects a "context" of fewer than ${ERROR_CORRECTION_MIN_WORDS} words with a letter`, () => {
      expectRejected(tenseWith((q) => (q.context = '...')), 'error_correction_missing_sentence');
      expectRejected(tenseWith((q) => (q.context = '— 1 2 3 —')), 'error_correction_missing_sentence');
      expectRejected(tenseWith((q) => (q.context = 'Plane left.')), 'error_correction_missing_sentence');
    });

    it(`accepts a sentence of ${ERROR_CORRECTION_MIN_WORDS} words`, () => {
      expect(
        validate(
          tenseWith((q) => {
            q.context = 'She go home.';
            q.correctAnswer = 'She goes home.';
            q.commonWrongAnswers = [
              { answer: 'She going home.', comment: 'c1' },
              { answer: 'She go home.', comment: 'c2' },
            ];
          }),
        ).ok,
      ).toBe(true);
    });

    it('is reported before the other rules, whatever else is wrong with the question', () => {
      expectRejected(
        tenseWith((q) => {
          delete q.context;
          q.commonWrongAnswers = [];
        }),
        'error_correction_missing_sentence',
      );
    });

    it('does not apply to fill-in-the-blank, which may leave "context" out', () => {
      expect(validate(withQuestion(0, (q) => delete q.context)).ok).toBe(true);
      expect(validate(withQuestion(0, (q) => (q.context = ''))).ok).toBe(true);
    });

    it('drops a two-candidate answer\'s sentenceless candidate, and rejects when both of a slot\'s are', () => {
      const pair = validQuestions().flatMap((q) => [
        { ...q, id: `${String(q.id)}-a` },
        { ...q, id: `${String(q.id)}-b` },
      ]);
      const tenseA = pair.find((q) => q.id === 'q-tense-a') as Question;
      delete tenseA.context;
      const one = validateSharedCandidates({ questions: pair }, PLAN, 2);
      expect(one.ok && one.dropped).toEqual([{ slot: 3, reason: 'error_correction_missing_sentence' }]);
      (pair.find((q) => q.id === 'q-tense-b') as Question).context = '  ';
      expect(validateSharedCandidates({ questions: pair }, PLAN, 2)).toEqual({
        ok: false,
        reason: 'error_correction_missing_sentence',
      });
    });
  });

  describe('error_correction_multi_edit', () => {
    const ARRIVED = 'When we arrived, the plane already left.';
    /** The valid set with its tense item's flawed sentence and key replaced. */
    const tense = (correctAnswer: string, context = ARRIVED) =>
      withQuestion(3, (q) => {
        q.context = context;
        q.correctAnswer = correctAnswer;
      });
    const passes = (correctAnswer: string, context?: string) => expect(validate(tense(correctAnswer, context)).ok).toBe(true);
    const fails = (correctAnswer: string, context?: string) =>
      expectRejected(tense(correctAnswer, context), 'error_correction_multi_edit');

    it('accepts one fix: an inserted, a replaced or a removed word', () => {
      passes('When we arrived, the plane had already left.'); // the valid set's own item
      passes('When we arrived, the plane had left.', 'When we arrived, the plane has left.');
      passes('When we arrived, the plane had left.', 'When we arrived, the plane had had left.');
    });

    it(`allows a span of ${ERROR_CORRECTION_MAX_EDIT_WORDS} words on each side and rejects ${ERROR_CORRECTION_MAX_EDIT_WORDS + 1}`, () => {
      passes('When we arrived, w x y z left.', 'When we arrived, a b c d left.');
      fails('When we arrived, v w x y z left.', 'When we arrived, a b c d e left.');
      fails('When we arrived, the plane left.', 'When we arrived, the plane a b c d e left.');
      fails('When we arrived, the plane a b c d e left.', 'When we arrived, the plane left.');
    });

    it('rejects two fixes far apart, and a rewritten sentence', () => {
      fails(
        'When we arrived at the station, the plane had already left.',
        'When we arrive at the station, the plane already left.',
      );
      fails('The plane had left before we got there.');
    });

    it('compares normalized text: case, spacing, curly quotes and the final full stop are not edits', () => {
      passes("WHEN we arrived,   the plane's door HAD already closed", 'When we arrived, the plane\u2019s door already closed.');
    });

    it('does not apply to fill-in-the-blank', () => {
      expect(validate(withQuestion(0, (q) => (q.context = 'a b c d e f g h'))).ok).toBe(true);
    });

    it('still reports an unchanged sentence as unchanged_error_correction', () => {
      expectRejected(tense('When we arrived, the plane already left.'), 'unchanged_error_correction');
    });

    it("does not catch the owner's one-word cases from 2026-09-26/27: judging those is the checker's job", () => {
      // Paraphrased from the owner's review (docs/1.1.0-shared-daily-test-quality.md §0):
      // the original was already acceptable, and the key changes one word.
      expect(isSingleShortEdit('i knew i must study harder', 'i knew i should study harder')).toBe(true);
      expect(isSingleShortEdit('i go to a library on campus', 'i go to the library on campus')).toBe(true);
    });
  });

  describe('isSingleShortEdit', () => {
    it.each([
      ['a b c', 'a x c', true],
      ['a b c', 'a b c d', true],
      ['a b c d', 'a b c', true],
      ['x a b', 'a b', true],
      ['a b a', 'a a', true], // repeated words: prefix and suffix never overlap
      ['a a a', 'a a', true],
      ['a b c d e f a b a', 'a b a', false], // 6 words removed; an overlap would count 4
      ['a', 'b c d e', true],
      ['a', 'b c d e f', false],
      ['a b c d e f', 'x', false],
      ['a b c d e f g', 'x b c d e f y', false], // two fixes 5 words apart
      ['a b c d e f g', 'x b c y e f g', true], // two fixes inside 4 words
    ])('%j -> %j: %s', (from, to, expected) => {
      expect(isSingleShortEdit(from, to)).toBe(expected);
    });
  });

  describe('explanation_not_one_sentence', () => {
    it('rejects two sentences', () => {
      expectRejected(
        withQuestion(0, (q) => (q.explanation = "Use 'the' for a known hotel. It is specific here.")),
        'explanation_not_one_sentence',
      );
      expectRejected(
        withQuestion(0, (q) => (q.explanation = "It's specific! Use 'the'.")),
        'explanation_not_one_sentence',
      );
    });

    it("allows a quoted word, 'e.g.' and a final full stop inside one sentence", () => {
      expect(
        validate(withQuestion(0, (q) => (q.explanation = "Use 'the' for one known thing, e.g. the hotel you named."))).ok,
      ).toBe(true);
      expect(
        validate(withQuestion(2, (q) => (q.explanation = "After 'enjoy', the verb takes -ing, so it's 'enjoy travelling'."))).ok,
      ).toBe(true);
    });
  });

  describe('explanation_too_long', () => {
    it(`allows exactly ${EXPLANATION_MAX_WORDS} words and rejects ${EXPLANATION_MAX_WORDS + 1}`, () => {
      const words = (n: number) => Array.from({ length: n }, () => 'word').join(' ') + '.';
      expect(EXPLANATION_MAX_WORDS).toBe(35);
      expect(validate(withQuestion(0, (q) => (q.explanation = words(35)))).ok).toBe(true);
      expectRejected(withQuestion(0, (q) => (q.explanation = words(36))), 'explanation_too_long');
    });
  });

  describe('explanation_bad_opening', () => {
    it.each([
      'Not quite: use the.',
      'Great, the hotel is specific.',
      "Perfect \u2014 use 'the' for a known hotel.",
      'Well done, the hotel is specific.',
      'Correct \u2014 it is specific.',
    ])(
      'rejects %j',
      (explanation) => {
        expectRejected(withQuestion(0, (q) => (q.explanation = explanation)), 'explanation_bad_opening');
      },
    );

    it('allows a sentence that merely starts with such a word', () => {
      expect(
        validate(withQuestion(0, (q) => (q.explanation = "Great Britain aside, use 'the' for a hotel you both know."))).ok,
      ).toBe(true);
      expect(
        validate(withQuestion(0, (q) => (q.explanation = "Correct article use here means 'the' for a known hotel."))).ok,
      ).toBe(true);
    });
  });
});

// ---------------------------------------------------------------------------
// The generation request

/** FNV-1a over the full generation request for [PLAN] and a fixed avoid list. */
function requestFingerprint(options: SharedGenerationOptions): string {
  const body = JSON.stringify(buildGenerateSharedDailyTestBody(sharedDailyTestRequest(PLAN, ['admit'], options)));
  let hash = 0x811c9dc5;
  for (let i = 0; i < body.length; i++) {
    hash ^= body.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16);
}

/** Prompt version 1 as it was measured and published: `claude-sonnet-4-6`,
 * the legacy route's model. */
const V1_LEGACY: SharedGenerationOptions = { promptVersion: 1, model: 'claude-sonnet-4-6' };

describe('generate_shared_daily_test request', () => {
  const plan = PLAN;

  it('version 1 reuses the legacy Daily Test model, system prompt, schema and budget; only the user prompt differs', () => {
    const body = buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan, [], V1_LEGACY));
    expect(body.max_tokens).toBe(dailyTestMaxTokensFor(5));
    expect(body.max_tokens).toBe(3072);
    expect(body.model).toBe('claude-sonnet-4-6');
    expect(body.system).toContain('"explanation": one sentence of fewer than 25 words');
    const schema = body.output_config.format.schema as {
      properties: { questions: { items: { required: string[] } } };
    };
    expect(schema.properties.questions.items.required).toEqual([
      'id',
      'type',
      'instruction',
      'topicId',
      'correctAnswer',
      'explanation',
      'commonWrongAnswers',
    ]);
    expect(body.messages).toHaveLength(1);
  });

  it('asks for every slot in plan order, with its topicId and type, and the theme', () => {
    const content = buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan)).messages[0]?.content ?? '';
    expect(content).toContain('Generate exactly 5 Daily Test questions');
    let last = -1;
    plan.slots.forEach((slot, i) => {
      const line = `${i + 1}. topicId "${slot.topicId}"`;
      const at = content.indexOf(line);
      expect(at, line).toBeGreaterThan(last);
      expect(content.slice(at).split('\n')[0]).toMatch(new RegExp(`: ${slot.type}$`));
      last = at;
    });
    expect(content).toContain('"travel"');
    expect(content).not.toContain('recent days');
  });

  it('adds the avoid list, trimmed, de-duplicated, quoted and capped at 35', () => {
    const avoid = ['  had already left ', 'had already left', '', 'admit', ...Array.from({ length: 50 }, (_, i) => `a${i}`)];
    const content =
      buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan, avoid)).messages[0]?.content ?? '';
    const line = content.split('\n').find((l) => l.includes('recent days')) ?? '';
    expect(line).toContain('"had already left", "admit"');
    expect(line.match(/"/g)?.length).toBe(35 * 2);
    expect(line).not.toContain('""');
    expect(line).toContain('"a32"');
    expect(line).not.toContain('"a33"');
  });

  it('carries nothing but the plan and the avoid list: no date, no device, no user text', () => {
    const body = JSON.stringify(buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan)));
    expect(body).not.toContain('2026-10-05');
    expect(body).not.toContain('deviceId');
  });

  // With the model that generated every set so far, so the pins stay what E
  // and the published v1 sets used.
  const fingerprint = (promptVersion: SharedPromptVersion) =>
    requestFingerprint({ promptVersion, model: 'claude-sonnet-4-6' });

  it.each([
    [1, 'c1a5703'],
    [2, '3b9d4a6b'],
  ] as const)('pins prompt version %i to its request fingerprint', (version, expected) => {
    // If a fingerprint changes, that prompt changed: make it a new version
    // instead, and pin the new one here. Version 1 is what every published set
    // so far was generated with. Version 2 was re-pinned once, before any set
    // was published with it (2026-09-28: `context` required for
    // error_correction in its schema; E measured the earlier 22121840).
    expect(fingerprint(version)).toBe(expected);
  });

  it(`builds version ${SHARED_PROMPT_VERSION} by default, the one the cron uses (path A, 2026-09-29)`, () => {
    expect(SHARED_PROMPT_VERSION).toBe(2);
    expect(sharedDailyTestRequest(plan).promptVersion).toBe(2);
    expect(buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan))).toEqual(
      buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan, [], { promptVersion: 2 })),
    );
  });
});

describe('generate_shared_daily_test request, prompt version 2', () => {
  const plan = PLAN;
  // The same model for both, so only the prompt differs.
  const v1 = buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan, ['admit'], V1_LEGACY));
  const v2 = buildGenerateSharedDailyTestBody(
    sharedDailyTestRequest(plan, ['admit'], { promptVersion: 2, model: 'claude-sonnet-4-6' }),
  );
  const v2User = v2.messages[0]?.content ?? '';

  it('keeps the model and token budget of version 1 (and so of the legacy route)', () => {
    expect(v2.model).toBe(v1.model);
    expect(v2.max_tokens).toBe(v1.max_tokens);
    expect(v2.messages).toHaveLength(1);
  });

  it("uses version 1's schema with each question one of two shapes, error_correction requiring \"context\"", () => {
    type Obj = Record<string, unknown> & { properties: Record<string, unknown>; required: string[] };
    const schemaOf = (body: typeof v1) => (body.output_config.format.schema as { properties: { questions: { items: unknown } } });
    const v1Item = schemaOf(v1).properties.questions.items as Obj;
    const [fill, ec] = (schemaOf(v2).properties.questions.items as { anyOf: Obj[] }).anyOf as [Obj, Obj];
    for (const [shape, type] of [
      [fill, 'fill_in_blank'],
      [ec, 'error_correction'],
    ] as const) {
      expect(shape.properties).toEqual({ ...v1Item.properties, type: { type: 'string', const: type } });
      expect(shape.additionalProperties).toBe(false);
    }
    expect(fill.required).toEqual(v1Item.required);
    expect(fill.required).not.toContain('context');
    expect(new Set(ec.required)).toEqual(new Set([...v1Item.required, 'context']));
    // Everything outside the questions' items is version 1's.
    const withoutItems = (body: typeof v1) => {
      const schema = structuredClone(schemaOf(body));
      schema.properties.questions.items = null;
      return { ...body.output_config, format: { ...body.output_config.format, schema } };
    };
    expect(withoutItems(v2)).toEqual(withoutItems(v1));
  });

  it('uses only schema keywords structured outputs documents as supported (no oneOf, if, minLength, pattern)', () => {
    const json = JSON.stringify(v2.output_config);
    for (const keyword of ['oneOf', '"if"', 'minLength', 'maxLength', 'pattern', 'minimum']) expect(json).not.toContain(keyword);
  });

  it('has its own system prompt, not the legacy Daily Test one', () => {
    expect(v2.system).not.toBe(v1.system);
    expect(v1.system).toContain('as regular');
    // Self-contained: no pointer to a practice prompt the model never sees.
    expect(v2.system).not.toContain('practice generation');
  });

  it('states the five correctness rules', () => {
    for (const rule of [
      '1. Single correct answer.',
      '2. error_correction: the original must be clearly wrong.',
      '3. Predicted wrong answers must be wrong.',
      '4. Only true, standard rules.',
      '5. "hint" is optional.',
    ]) {
      expect(v2.system).toContain(rule);
    }
    expect(v2.system).toContain('at most 15 words');
    expect(v2.system).toContain('self-contained and unambiguous');
  });

  it('keeps the explanation and predicted-wrong-answer instructions of version 1', () => {
    expect(v2.system).toContain('"explanation": one sentence of fewer than 25 words');
    expect(v2.system).toContain('predict 2-3 common wrong answers');
    expect(v2.system).toContain('don\'t open with praise');
  });

  it('adds the keep-the-slot clause to the user prompt, and nothing else changes there', () => {
    const v1User = v1.messages[0]?.content ?? '';
    const clause = v2User.split('\n').find((l) => l.startsWith("If a slot's type cannot be written")) ?? '';
    expect(clause).toContain('keep the topic and type');
    expect(v1User).not.toContain(clause);
    expect(v2User.split('\n').filter((l) => l !== clause)).toEqual(v1User.split('\n'));
  });
});

describe('generate_shared_daily_test request, generation variants (owner additions A and B)', () => {
  const build = (options: SharedGenerationOptions) => buildGenerateSharedDailyTestBody(sharedDailyTestRequest(PLAN, [], options));
  const base = build({ promptVersion: 2, model: 'claude-sonnet-4-6' });

  it('defaults to SHARED_GENERATOR: claude-sonnet-5, no effort field, adaptive thinking, one question per slot', () => {
    expect(SHARED_GENERATOR).toEqual({ model: 'claude-sonnet-5' });
    const request = sharedDailyTestRequest(PLAN);
    expect(request).toMatchObject({ model: 'claude-sonnet-5', candidatesPerSlot: 1, count: 5 });
    expect('effort' in request).toBe(false);
    const body = buildGenerateSharedDailyTestBody(request);
    expect(body.model).toBe('claude-sonnet-5');
    expect(body.thinking).toEqual({ type: 'adaptive' });
    expect('effort' in body.output_config).toBe(false);
    expect(body.max_tokens).toBe(dailyTestMaxTokensFor(5) + THINKING_HEADROOM_TOKENS);
  });

  it('keeps how each model is asked in one table: only claude-sonnet-4-6 runs without thinking', () => {
    expect(GENERATOR_MODELS).toEqual({
      'claude-sonnet-4-6': { adaptiveThinking: false },
      'claude-sonnet-5': { adaptiveThinking: true },
      'claude-sonnet-5-5': { adaptiveThinking: true },
    });
    const noThinking = build({ promptVersion: 2, model: 'claude-sonnet-4-6' });
    expect('thinking' in noThinking).toBe(false);
    expect(noThinking.max_tokens).toBe(dailyTestMaxTokensFor(5));
  });

  it('claude-sonnet-5-5 is asked like claude-sonnet-5: adaptive thinking and headroom, only the model differs', () => {
    const five = build({ promptVersion: 2, model: 'claude-sonnet-5' });
    const fiveFive = build({ promptVersion: 2, model: 'claude-sonnet-5-5' });
    expect(fiveFive).toEqual({ ...five, model: 'claude-sonnet-5-5' });
  });

  it.each(['low', 'medium', 'high'] as const)('sends effort "%s" in output_config only when asked, nothing else changes', (effort) => {
    const plain = build({ promptVersion: 2, model: 'claude-sonnet-5-5' });
    const withEffort = build({ promptVersion: 2, model: 'claude-sonnet-5-5', effort });
    expect(withEffort.output_config).toEqual({ ...plain.output_config, effort });
    expect({ ...withEffort, output_config: plain.output_config }).toEqual(plain);
    expect('effort' in plain.output_config).toBe(false);
  });

  it('an explicit model does not inherit the default generator\'s effort', () => {
    expect('effort' in sharedDailyTestRequest(PLAN, [], { model: 'claude-sonnet-5-5' })).toBe(false);
    expect(sharedDailyTestRequest(PLAN, [], { model: 'claude-sonnet-5-5', effort: 'low' }).effort).toBe('low');
  });

  it('claude-sonnet-5 gets adaptive thinking and thinking headroom; nothing else changes', () => {
    const body = build({ promptVersion: 2, model: 'claude-sonnet-5' });
    expect(body.model).toBe('claude-sonnet-5');
    expect(body.thinking).toEqual({ type: 'adaptive' });
    expect(body.max_tokens).toBe(dailyTestMaxTokensFor(5) + THINKING_HEADROOM_TOKENS);
    expect({ ...body, model: base.model, max_tokens: base.max_tokens, thinking: undefined }).toEqual({
      ...base,
      thinking: undefined,
    });
  });

  it('two candidates per slot ask for 10 questions, grouped by slot, with the budget for 10', () => {
    const request = sharedDailyTestRequest(PLAN, [], { promptVersion: 2, model: 'claude-sonnet-4-6', candidatesPerSlot: 2 });
    expect(request.count).toBe(10);
    const body = buildGenerateSharedDailyTestBody(request);
    expect(body.max_tokens).toBe(dailyTestMaxTokensFor(10));
    const content = body.messages[0]?.content ?? '';
    expect(content).toContain('Generate exactly 10 Daily Test questions, two candidates for each slot below');
    expect(content).toContain('Only one of them will be used');
    // The same slot lines and the v2 clause as the one-candidate request.
    const baseContent = base.messages[0]?.content ?? '';
    for (const line of baseContent.split('\n').slice(1)) expect(content).toContain(line);
    expect(build({ promptVersion: 2, model: 'claude-sonnet-5', candidatesPerSlot: 2 }).max_tokens).toBe(
      dailyTestMaxTokensFor(10) + THINKING_HEADROOM_TOKENS,
    );
  });

  it.each([
    // Re-pinned with version 2 (2026-09-28); E measured 9391a5af, f04badb8, 98f1bfc3.
    ['G3: v2, claude-sonnet-5', { promptVersion: 2, model: 'claude-sonnet-5' }, 'ac736d3e'],
    ['G4: v2, two candidates', { promptVersion: 2, model: 'claude-sonnet-4-6', candidatesPerSlot: 2 }, 'aac0a37'],
    ['G5: v2, claude-sonnet-5, two candidates', { promptVersion: 2, model: 'claude-sonnet-5', candidatesPerSlot: 2 }, '8a3ca186'],
  ] as const)('pins the measured variant %s to its request fingerprint', (_name, options, expected) => {
    expect(requestFingerprint(options)).toBe(expected);
  });
});

describe('validateSharedCandidates (two candidates per slot)', () => {
  /** Both candidates of every slot, in plan order: the valid set twice, ids made unique. */
  function tenCandidates(): Question[] {
    return validQuestions().flatMap((q) => [
      { ...q, id: `${String(q.id)}-a` },
      { ...q, id: `${String(q.id)}-b` },
    ]);
  }
  const candidates = (questions: Question[]) => validateSharedCandidates({ questions }, PLAN, 2);
  const at = (questions: Question[], id: string) => questions.find((q) => q.id === id) as Question;

  it('groups two valid candidates per slot, in plan order, and drops nothing', () => {
    const result = candidates(tenCandidates().reverse());
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.candidates.map((slot) => slot.map((q) => q.topicId))).toEqual(
      PLAN.slots.map((s) => [s.topicId, s.topicId]),
    );
    expect(result.dropped).toEqual([]);
  });

  it("drops a candidate that breaks a content rule and keeps its slot's other one", () => {
    const questions = tenCandidates();
    at(questions, 'q-tense-a').correctAnswer = 'The plane had left before we got there.';
    const result = candidates(questions);
    expect(result.ok).toBe(true);
    if (!result.ok) return;
    expect(result.candidates[3]?.map((q) => q.id)).toEqual(['q-tense-b']);
    expect(result.dropped).toEqual([{ slot: 3, reason: 'error_correction_multi_edit' }]);
  });

  it('rejects the answer when both candidates of a slot break a rule, with the first reason', () => {
    const questions = tenCandidates();
    at(questions, 'q-modal-a').explanation = 'Great! It is must.';
    at(questions, 'q-modal-b').commonWrongAnswers = [];
    expect(candidates(questions)).toEqual({ ok: false, reason: 'explanation_not_one_sentence' });
  });

  it('rejects the whole answer for its shape: count, plan, three in one slot, a duplicate id', () => {
    expect(candidates(tenCandidates().slice(1))).toEqual({ ok: false, reason: 'wrong_question_count' });
    expect(validateSharedCandidates('nope', PLAN, 2)).toEqual({ ok: false, reason: 'not_an_object' });

    const wrongType = tenCandidates();
    at(wrongType, 'q-articles-a').type = 'error_correction';
    expect(candidates(wrongType)).toEqual({ ok: false, reason: 'plan_mismatch' });

    const threeInSlot = tenCandidates();
    at(threeInSlot, 'q-modal-a').topicId = 'articles';
    at(threeInSlot, 'q-modal-a').type = 'fill_in_blank';
    expect(candidates(threeInSlot)).toEqual({ ok: false, reason: 'plan_mismatch' });

    const duplicate = tenCandidates();
    at(duplicate, 'q-modal-b').id = 'q-modal-a';
    expect(candidates(duplicate)).toEqual({ ok: false, reason: 'duplicate_id' });
  });

  it('with one candidate per slot, accepts exactly what validateSharedSet accepts', () => {
    const result = validateSharedCandidates({ questions: validQuestions() }, PLAN, 1);
    const set = validateSharedSet({ questions: validQuestions() }, PLAN);
    expect(result.ok && set.ok).toBe(true);
    if (result.ok && set.ok) expect(result.candidates.map((slot) => slot[0])).toEqual(set.questions);
  });
});

describe('callAnthropic with generate_shared_daily_test', () => {
  const originalFetch = globalThis.fetch;
  const originalLog = console.log;
  let logged: string[] = [];
  let sentBodies: string[] = [];

  beforeEach(() => {
    logged = [];
    sentBodies = [];
    console.log = (...args: unknown[]) => {
      logged.push(args.map(String).join(' '));
    };
    globalThis.fetch = (async (_url: unknown, init?: RequestInit) => {
      sentBodies.push(String(init?.body));
      return new Response(
        JSON.stringify({
          content: [{ type: 'text', text: JSON.stringify({ questions: validQuestions() }) }],
          usage: { input_tokens: 1500, output_tokens: 1400 },
          stop_reason: 'end_turn',
        }),
        { status: 200 },
      );
    }) as typeof fetch;
  });

  afterEach(() => {
    globalThis.fetch = originalFetch;
    console.log = originalLog;
  });

  it('logs an over-generated request with the number of questions asked for', async () => {
    const request = sharedDailyTestRequest(PLAN, [], { promptVersion: 2, model: 'claude-sonnet-5', candidatesPerSlot: 2 });
    await callAnthropic(env, { op: 'generate_shared_daily_test', request });

    expect(sentBodies).toEqual([JSON.stringify(buildGenerateSharedDailyTestBody(request))]);
    expect(JSON.parse(logged[0] ?? '{}')).toMatchObject({ kind: 'daily_test', item_count: 10 });
  });

  it('sends the shared body, returns the parsed content, and logs it as daily_test cost', async () => {
    const request = sharedDailyTestRequest(PLAN);
    const result = await callAnthropic(env, { op: 'generate_shared_daily_test', request });

    expect(result).toEqual({ questions: validQuestions() });
    expect(sentBodies).toEqual([JSON.stringify(buildGenerateSharedDailyTestBody(request))]);
    expect(logged.map((l) => JSON.parse(l) as unknown)).toEqual([
      {
        event: 'anthropic_usage',
        kind: 'daily_test',
        operation: 'generate_shared_daily_test',
        item_count: 5,
        input_tokens: 1500,
        output_tokens: 1400,
        stop_reason: 'end_turn',
        duration_ms: expect.any(Number),
      },
    ]);
  });
});
