import { env } from 'cloudflare:test';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { buildGenerateSharedDailyTestBody, callAnthropic, dailyTestMaxTokensFor } from '../src/anthropic';
import {
  EXPLANATION_MAX_WORDS,
  SCENARIO_THEMES,
  SHARED_PROMPT_VERSION,
  SHARED_SET_QUESTION_COUNT,
  dailyPlan,
  dateOfDayNumber,
  dayNumberOf,
  foldKeyboardVariants,
  isInServingWindow,
  normalizeAnswer,
  sharedDailyTestRequest,
  validateSharedSet,
  type DailyPlan,
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
      expectRejected(withQuestion(0, (q) => (q.type = 'error_correction')), 'plan_mismatch');
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

describe('generate_shared_daily_test request', () => {
  const plan = PLAN;

  it('reuses the legacy Daily Test model, system prompt, schema and budget; only the user prompt differs', () => {
    const body = buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan));
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

  it(`is pinned to SHARED_PROMPT_VERSION ${SHARED_PROMPT_VERSION}`, () => {
    // A fingerprint of the full request for a fixed plan and avoid list. If it
    // changes, the shared prompt changed: bump SHARED_PROMPT_VERSION, then
    // update the fingerprint here.
    const body = JSON.stringify(buildGenerateSharedDailyTestBody(sharedDailyTestRequest(plan, ['admit'])));
    let hash = 0x811c9dc5;
    for (let i = 0; i < body.length; i++) {
      hash ^= body.charCodeAt(i);
      hash = Math.imul(hash, 0x01000193) >>> 0;
    }
    expect({ version: SHARED_PROMPT_VERSION, fingerprint: hash.toString(16) }).toMatchInlineSnapshot(`
      {
        "fingerprint": "c1a5703",
        "version": 1,
      }
    `);
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
