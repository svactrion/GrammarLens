import { TOPICS } from './topics';

/**
 * The shared Daily Test: one set per calendar date, generated once by the
 * proxy and served to every 1.1.0+ client (docs/1.1.0-shared-daily-test.md).
 * This module holds the pure parts — the date window, the day's plan, and the
 * automatic quality gate a generated set must pass before it is published.
 * It has no binding, route or schedule of its own, and it never calls
 * Anthropic: generation goes through `callAnthropic` with the
 * `generate_shared_daily_test` operation.
 *
 * The legacy `POST /v1/generate-daily-test` (1.0.0 clients) does not use
 * anything here and must not change (§1, Option A).
 */

/** Questions in one shared set — the same length as the 1.0.0 Daily Test. */
export const SHARED_SET_QUESTION_COUNT = 5;

/**
 * Stored with every published set. Bump it on any change to what the
 * generation request asks for (the user prompt below, the Daily Test system
 * prompt or schema it reuses, the plan), so a set can always be traced to the
 * prompt that produced it. `test/shared_daily_test.test.ts` pins a fingerprint
 * of the request to this number.
 */
export const SHARED_PROMPT_VERSION = 1;

/** Hard cap on an explanation's length. The prompt asks for fewer than 25
 * words; 35 sits above the measured maximum (27, 2026-09-24), so an ordinary
 * output is never rejected, and every rejection is a paid retry. */
export const EXPLANATION_MAX_WORDS = 35;

// ---------------------------------------------------------------------------
// Dates

const MS_PER_DAY = 86_400_000;
const DATE_PATTERN = /^(\d{4})-(\d{2})-(\d{2})$/;

/**
 * Local calendar dates in use somewhere on Earth run from UTC today − 1
 * (UTC−12) to UTC today + 1 (UTC+14); a client asking for its *tomorrow*
 * adds one more. Anything outside is refused, which also covers a device
 * with a wrong clock (it then gets the bundled fallback).
 */
export const SERVING_WINDOW = { daysBefore: 1, daysAfter: 2 } as const;

/**
 * Days since 1970-01-01 for a real calendar date written exactly as
 * `YYYY-MM-DD` (the client's local `dayKey`), or null for anything else:
 * another shape, a non-string, or a date that does not exist (2026-02-30,
 * 2027-02-29). Pure calendar arithmetic through `Date.UTC`, so no time zone
 * or daylight saving is involved: the date is a label, not an instant.
 */
export function dayNumberOf(value: unknown): number | null {
  if (typeof value !== 'string') return null;
  const match = DATE_PATTERN.exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const ms = Date.UTC(year, month - 1, day);
  const back = new Date(ms);
  // Date.UTC rolls an impossible day over (Feb 30 → Mar 2) and maps years
  // 0-99 to 1900-1999; reading the fields back rejects both.
  if (back.getUTCFullYear() !== year || back.getUTCMonth() !== month - 1 || back.getUTCDate() !== day) {
    return null;
  }
  return ms / MS_PER_DAY;
}

/** The `YYYY-MM-DD` date of a day number from [dayNumberOf]. */
export function dateOfDayNumber(dayNumber: number): string {
  return new Date(dayNumber * MS_PER_DAY).toISOString().slice(0, 10);
}

/** Today's day number on the UTC calendar. */
export function utcDayNumber(now: Date = new Date()): number {
  return Math.floor(now.getTime() / MS_PER_DAY);
}

/** Whether [value] is a real date inside [SERVING_WINDOW] around UTC today. */
export function isInServingWindow(value: unknown, now: Date = new Date()): boolean {
  const dayNumber = dayNumberOf(value);
  if (dayNumber === null) return false;
  const offset = dayNumber - utcDayNumber(now);
  return offset >= -SERVING_WINDOW.daysBefore && offset <= SERVING_WINDOW.daysAfter;
}

// ---------------------------------------------------------------------------
// The day's plan

/** Approved by the owner on 2026-09-26 (report §8, §13 item 4). */
export const SCENARIO_THEMES: readonly string[] = [
  'work',
  'travel',
  'health',
  'study',
  'family',
  'technology',
  'food',
  'money',
  'sport',
  'environment',
  'shopping',
  'housing',
  'media',
  'science',
];

export type SharedItemType = 'fill_in_blank' | 'error_correction';

export interface PlanSlot {
  readonly topicId: string;
  readonly type: SharedItemType;
}

/**
 * What a date's set must contain: one question per topic, in [slots] order,
 * each of the slot's type, all set in [theme]. Every 1.0.0 set came out with
 * the same topic order and recurring scenarios because every request was the
 * same (build log 2026-09-24); the plan varies them by date.
 */
export interface DailyPlan {
  readonly date: string;
  readonly slots: readonly PlanSlot[];
  readonly theme: string;
}

/** mulberry32: a tiny seeded generator, so a date always gives the same plan. */
function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffled<T>(items: readonly T[], random: () => number): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j] as T, out[i] as T];
  }
  return out;
}

/**
 * The plan for [date], a function of the date alone: a retry or a
 * regeneration of the same date asks for the same plan.
 *
 * - Topic order: a date-seeded permutation of all five topics.
 * - Type split: 3 fill_in_blank / 2 error_correction or 2 / 3, alternating by
 *   day. The alternation flips at every 14-day theme cycle, so a theme does not
 *   always get the same split. Which slots get which type is shuffled too.
 * - Theme: the 14 themes in turn, so none repeats within 14 days.
 *
 * Throws on an invalid date: callers pass dates they already checked.
 */
export function dailyPlan(date: string): DailyPlan {
  const dayNumber = dayNumberOf(date);
  if (dayNumber === null) throw new Error('dailyPlan needs a YYYY-MM-DD calendar date.');

  const random = seededRandom(dayNumber * 2654435761);
  const topics = shuffled(
    TOPICS.map((t) => t.id),
    random,
  );
  const cycle = Math.floor(dayNumber / SCENARIO_THEMES.length);
  const fillCount = (dayNumber + cycle) % 2 === 0 ? 3 : 2;
  const types = shuffled<SharedItemType>(
    topics.map((_, i) => (i < fillCount ? 'fill_in_blank' : 'error_correction')),
    random,
  );

  return {
    date,
    slots: topics.map((topicId, i) => ({ topicId, type: types[i] as SharedItemType })),
    theme: SCENARIO_THEMES[dayNumber % SCENARIO_THEMES.length] as string,
  };
}

/** What `callAnthropic` needs for the `generate_shared_daily_test` operation. */
export interface GenerateSharedDailyTestRequest {
  readonly plan: DailyPlan;
  /** Equal to `plan.slots.length`; kept as its own field so the usage log's
   * `item_count` reads it the same way as for every other operation. */
  readonly count: number;
  /** Correct answers from recent published sets, for "do not reuse" in the
   * prompt. Model-written text, never anything from a user. */
  readonly avoidAnswers: readonly string[];
}

export function sharedDailyTestRequest(
  plan: DailyPlan,
  avoidAnswers: readonly string[] = [],
): GenerateSharedDailyTestRequest {
  return { plan, count: plan.slots.length, avoidAnswers };
}

// ---------------------------------------------------------------------------
// Answer normalization — a port of lib/utils/answer_matching.dart

/**
 * TypeScript port of Dart's `normalizeAnswer` (lib/utils/answer_matching.dart):
 * curly quotes to straight, trim, collapse whitespace, lowercase, drop one
 * trailing `.`/`!`/`?`. The app grades with the Dart version, so this one
 * must give the same result for every input; `test/fixtures/
 * answer_normalization.json` (values produced by the Dart code) is the
 * contract both sides are tested against.
 *
 * One real difference is handled here: JavaScript lowercases `İ` (U+0130) to
 * `i` + a combining dot (two code units), while Dart gives a plain `i`.
 */
export function normalizeAnswer(raw: string): string {
  const straightened = raw
    .replaceAll('\u2019', "'")
    .replaceAll('\u2018', "'")
    .replaceAll('\u201C', '"')
    .replaceAll('\u201D', '"');
  const collapsed = straightened
    .trim()
    .replace(/\s+/g, ' ')
    .replaceAll('\u0130', 'i')
    .toLowerCase();
  return collapsed.replace(/[.!?]$/, '');
}

const KEYBOARD_VARIANT_FOLD: Readonly<Record<string, string>> = {
  'ı': 'i',
  'ş': 's',
  'ğ': 'g',
  'ç': 'c',
  'ö': 'o',
  'ü': 'u',
};

/** Port of Dart's `foldKeyboardVariants`: Turkish-keyboard letters to the
 * plain letter they stand for. Applied to already-normalized text. */
export function foldKeyboardVariants(input: string): string {
  return input
    .split('')
    .map((ch) => KEYBOARD_VARIANT_FOLD[ch] ?? ch)
    .join('');
}

// ---------------------------------------------------------------------------
// The quality gate

/** Why a generated set was not published, as a fixed vocabulary (it is logged). */
export type SharedSetRejection =
  | 'not_an_object' // the content is not `{questions: [...]}`
  | 'wrong_question_count' // not exactly one question per plan slot
  | 'missing_field' // a required text is absent, not a string, or blank
  | 'text_too_long' // an id over 100 characters, any other text over 2000
  | 'duplicate_id'
  | 'plan_mismatch' // a topic or type the plan does not ask for, or a topic twice
  | 'wrong_answer_count' // not 2-3 predicted wrong answers
  | 'blank_correct_answer' // correctAnswer normalizes to nothing
  | 'wrong_answer_matches_correct' // a predicted wrong answer grades as correct
  | 'duplicate_wrong_answer'
  | 'unchanged_error_correction' // the "correction" equals the flawed sentence
  | 'explanation_not_one_sentence'
  | 'explanation_too_long'
  | 'explanation_bad_opening'; // opens with praise or "Not quite"

export interface SharedWrongAnswer {
  answer: string;
  comment: string;
}

/** One validated question, in the shape `DailyTestQuestion.fromJson` reads. */
export interface SharedQuestion {
  id: string;
  type: SharedItemType;
  context?: string;
  instruction: string;
  hint?: string;
  topicId: string;
  correctAnswer: string;
  explanation: string;
  commonWrongAnswers: SharedWrongAnswer[];
}

export type SharedSetValidation =
  | { ok: true; questions: SharedQuestion[] }
  | { ok: false; reason: SharedSetRejection };

const MAX_ID_LENGTH = 100;
const MAX_TEXT_LENGTH = 2000;

/** A sentence end followed by the start of another sentence. */
const SECOND_SENTENCE = /[.!?]["'\u2019\u201D)]*\s+["'\u2018\u201C(]*[A-Z]/;

/** Praise or the "Not quite" line: the explanation is shown on every kind of
 * card (correct, skipped, wrong), so it must not open with a verdict. A single
 * word only counts when punctuation follows it ("Great!"), not in a sentence
 * that happens to start with it. */
const BAD_OPENING =
  /^(?:(?:not quite|well done|good job|great job|nice job|nice work|spot on|good try|nice try)\b|(?:great|excellent|perfect|correct|nice|right|good|wrong)\s*[!,.\u2014-])/i;

class Rejected extends Error {
  constructor(readonly reason: SharedSetRejection) {
    super(reason);
  }
}

function text(value: unknown, maxLength = MAX_TEXT_LENGTH): string {
  if (typeof value !== 'string' || value.trim().length === 0) throw new Rejected('missing_field');
  if (value.length > maxLength) throw new Rejected('text_too_long');
  return value;
}

function optionalText(value: unknown): string | undefined {
  if (value === undefined) return undefined;
  if (typeof value !== 'string') throw new Rejected('missing_field');
  if (value.length > MAX_TEXT_LENGTH) throw new Rejected('text_too_long');
  return value;
}

function wordCount(value: string): number {
  return value.trim().split(/\s+/).length;
}

/**
 * The automatic check a generated set must pass before anyone can be served
 * it (report §8). A set everyone gets must not be one with a broken answer key,
 * so the rules mirror how the app grades (`checkDailyTestAnswer`: correct,
 * then keyboard variant, then each predicted wrong answer).
 *
 * On success the questions are returned **in plan order**, rebuilt from the
 * known fields only, with their text unchanged. On failure only the first
 * broken rule is reported; the set is not published and the attempt counts
 * against the date's cap.
 */
export function validateSharedSet(content: unknown, plan: DailyPlan): SharedSetValidation {
  try {
    return { ok: true, questions: checkSet(content, plan) };
  } catch (e) {
    if (e instanceof Rejected) return { ok: false, reason: e.reason };
    throw e;
  }
}

function checkSet(content: unknown, plan: DailyPlan): SharedQuestion[] {
  if (typeof content !== 'object' || content === null || Array.isArray(content)) {
    throw new Rejected('not_an_object');
  }
  const raw = (content as Record<string, unknown>).questions;
  if (!Array.isArray(raw)) throw new Rejected('not_an_object');
  if (raw.length !== plan.slots.length) throw new Rejected('wrong_question_count');

  const bySlot = new Map<number, SharedQuestion>();
  const ids = new Set<string>();
  for (const entry of raw) {
    const question = checkQuestion(entry);

    if (ids.has(question.id)) throw new Rejected('duplicate_id');
    ids.add(question.id);

    const slot = plan.slots.findIndex((s) => s.topicId === question.topicId);
    if (slot < 0 || bySlot.has(slot) || plan.slots[slot]?.type !== question.type) {
      throw new Rejected('plan_mismatch');
    }
    bySlot.set(slot, question);
  }
  return plan.slots.map((_, i) => bySlot.get(i) as SharedQuestion);
}

function checkQuestion(entry: unknown): SharedQuestion {
  if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
    throw new Rejected('missing_field');
  }
  const q = entry as Record<string, unknown>;

  const id = text(q.id, MAX_ID_LENGTH);
  const type = q.type;
  if (type !== 'fill_in_blank' && type !== 'error_correction') throw new Rejected('plan_mismatch');
  const topicId = text(q.topicId, MAX_ID_LENGTH);
  const instruction = text(q.instruction);
  const context = optionalText(q.context);
  const hint = optionalText(q.hint);
  const correctAnswer = text(q.correctAnswer);
  const explanation = text(q.explanation);

  const rawWrong = q.commonWrongAnswers;
  if (!Array.isArray(rawWrong)) throw new Rejected('missing_field');
  const commonWrongAnswers = rawWrong.map((w): SharedWrongAnswer => {
    if (typeof w !== 'object' || w === null || Array.isArray(w)) throw new Rejected('missing_field');
    const wrong = w as Record<string, unknown>;
    return { answer: text(wrong.answer), comment: text(wrong.comment) };
  });
  if (commonWrongAnswers.length < 2 || commonWrongAnswers.length > 3) {
    throw new Rejected('wrong_answer_count');
  }

  // The answer key, read the way the app grades it.
  const correct = normalizeAnswer(correctAnswer);
  if (correct.length === 0) throw new Rejected('blank_correct_answer');
  const correctFolded = foldKeyboardVariants(correct);
  const seen = new Set<string>();
  for (const { answer } of commonWrongAnswers) {
    const normalized = normalizeAnswer(answer);
    // The app checks correct and keyboard variant first, so such a
    // prediction could never be shown: the model confused its own key.
    if (normalized === correct || foldKeyboardVariants(normalized) === correctFolded) {
      throw new Rejected('wrong_answer_matches_correct');
    }
    if (seen.has(normalized)) throw new Rejected('duplicate_wrong_answer');
    seen.add(normalized);
  }
  if (type === 'error_correction' && context !== undefined && normalizeAnswer(context) === correct) {
    throw new Rejected('unchanged_error_correction');
  }

  const trimmedExplanation = explanation.trim();
  if (SECOND_SENTENCE.test(trimmedExplanation)) throw new Rejected('explanation_not_one_sentence');
  if (wordCount(trimmedExplanation) > EXPLANATION_MAX_WORDS) throw new Rejected('explanation_too_long');
  if (BAD_OPENING.test(trimmedExplanation)) throw new Rejected('explanation_bad_opening');

  return {
    id,
    type,
    ...(context === undefined ? {} : { context }),
    instruction,
    ...(hint === undefined ? {} : { hint }),
    topicId,
    correctAnswer,
    explanation,
    commonWrongAnswers,
  };
}
