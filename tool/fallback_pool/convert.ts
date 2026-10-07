/**
 * The pure part of the fallback-pool export (docs/1.1.0-shared-daily-test.md
 * §5; owner decision 2026-09-30): turns shared sets the live cron published
 * into the app's bundled pool asset (`assets/daily_test_fallback/pool.json`)
 * and a review file for the owner.
 *
 * Every set goes through the proxy's own gate (`validateSharedSet` with the
 * date's `dailyPlan`, imported from `proxy/src/shared_daily_test.ts`, so the
 * rules cannot drift), and must be prompt v2. Only the questions are kept:
 * `date`, `generatedAt`, `attempt` and `promptVersion` are dropped, and the
 * ids become `fbNN_i` (NN the set's place in the pool, i its question), so a
 * pool set's ids never look like a shared set's.
 *
 * Then the owner's corrections (`corrections.json`, roadmap P13) are applied:
 * other accepted answers added, a predicted wrong answer removed, a hint
 * removed. Each names its set by publication date and its question by number,
 * never by `fbNN` (those change with the dates chosen). The corrected set goes
 * through the same gate again, and its `acceptedAnswers` through the rules the
 * check call's alternatives follow; a correction that matches no question is
 * an error, never skipped.
 *
 * Never imported by the Worker; bundled and run by `scripts/fallback_pool.sh`.
 */
import { MAX_ACCEPTED_ANSWER_LENGTH } from '../../proxy/src/shared_check';
import {
  dailyPlan,
  dayNumberOf,
  foldKeyboardVariants,
  normalizeAnswer,
  validateSharedSet,
  type SharedQuestion,
} from '../../proxy/src/shared_daily_test';

/** The asset format the app reads (`FallbackPool.formatVersion`). */
export const POOL_FORMAT_VERSION = 1;

/** The prompt version the pool accepts: the cron's live one (report §16). */
export const REQUIRED_PROMPT_VERSION = 2;

/** Sets in the pool (owner decision, report §13 answer 3). */
export const POOL_SIZE = 7;

export interface RawSet {
  /** The date asked for (the KV key `set:{date}`). */
  date: string;
  /** What `wrangler kv key get` printed. */
  text: string;
}

/** A pool question: a shared question, with `acceptedAnswers` only when an
 * owner correction added some (live sets carry none, and the gate drops the
 * field). */
export type PoolQuestion = SharedQuestion;

/** The corrections file's shape (`corrections.json`). */
export const CORRECTIONS_FORMAT_VERSION = 1;

/** One owner correction of one question (roadmap P13). */
export interface Correction {
  /** The set's publication date, `YYYY-MM-DD` (the KV key `set:{date}`). */
  date: string;
  /** The question's number in that set, from 1, as `review.md` numbers it
   * (plan order, the order the gate returns). */
  question: number;
  /** Why, in a short sentence: shown in `review.md`. */
  reason: string;
  /** Removes the question's hint; the question must have one. */
  removeHint?: true;
  /** Predicted wrong answers to remove, each matching exactly one of the
   * question's (as graded: normalized). */
  removeWrongAnswers?: string[];
  /** Other answers graded as correct. */
  addAcceptedAnswers?: string[];
}

const CORRECTION_KEYS = new Set(['date', 'question', 'reason', 'removeHint', 'removeWrongAnswers', 'addAcceptedAnswers']);

export interface Pool {
  formatVersion: number;
  sets: { questions: PoolQuestion[] }[];
}

export interface ConvertResult {
  /** Present only when every set passed and the count is right. */
  pool?: Pool;
  /** One line per problem; empty when [pool] is present. */
  problems: string[];
  /** The owner's review file (Markdown); written only with [pool]. */
  review?: string;
}

/**
 * The JSON object in [text]: `wrangler` may print notices before it, so the
 * object starts at the first `{`.
 */
export function parseKvOutput(text: string): unknown {
  const start = text.indexOf('{');
  if (start < 0) throw new Error('no JSON object in the output');
  return JSON.parse(text.slice(start));
}

/**
 * Reads `corrections.json`: `{"formatVersion": 1, "corrections": [...]}`.
 * Anything malformed is a problem, so a typo can never quietly drop a
 * correction.
 */
export function parseCorrections(text: string): { corrections: Correction[]; problems: string[] } {
  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch (e) {
    return { corrections: [], problems: [`corrections: not JSON (${(e as Error).message})`] };
  }
  const file = json as Record<string, unknown> | null;
  if (typeof file !== 'object' || file === null || Array.isArray(file) || !Array.isArray(file.corrections)) {
    return { corrections: [], problems: ['corrections: not {"formatVersion": 1, "corrections": [...]}'] };
  }
  if (file.formatVersion !== CORRECTIONS_FORMAT_VERSION) {
    return { corrections: [], problems: [`corrections: formatVersion ${JSON.stringify(file.formatVersion)}, needs ${CORRECTIONS_FORMAT_VERSION}`] };
  }
  const problems: string[] = [];
  const corrections: Correction[] = [];
  const seen = new Set<string>();
  file.corrections.forEach((entry: unknown, i: number) => {
    const where = `corrections[${i}]`;
    if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) {
      problems.push(`${where}: not an object`);
      return;
    }
    const c = entry as Record<string, unknown>;
    const unknown = Object.keys(c).filter((k) => !CORRECTION_KEYS.has(k));
    const strings = (value: unknown) =>
      Array.isArray(value) && value.length > 0 && value.every((v) => typeof v === 'string' && v.trim().length > 0);
    if (unknown.length > 0) problems.push(`${where}: unknown field ${unknown.join(', ')}`);
    else if (typeof c.date !== 'string' || dayNumberOf(c.date) === null) problems.push(`${where}: "date" is not a YYYY-MM-DD date`);
    else if (typeof c.question !== 'number' || !Number.isInteger(c.question) || c.question < 1) {
      problems.push(`${where}: "question" is not a number from 1`);
    } else if (typeof c.reason !== 'string' || c.reason.trim().length === 0) problems.push(`${where}: no "reason"`);
    else if (c.removeHint !== undefined && c.removeHint !== true) problems.push(`${where}: "removeHint" can only be true`);
    else if (c.removeWrongAnswers !== undefined && !strings(c.removeWrongAnswers)) {
      problems.push(`${where}: "removeWrongAnswers" is not a list of answers`);
    } else if (c.addAcceptedAnswers !== undefined && !strings(c.addAcceptedAnswers)) {
      problems.push(`${where}: "addAcceptedAnswers" is not a list of answers`);
    } else if (c.removeHint === undefined && c.removeWrongAnswers === undefined && c.addAcceptedAnswers === undefined) {
      problems.push(`${where}: no change`);
    } else if (seen.has(`${c.date}#${c.question}`)) {
      problems.push(`${where}: ${c.date} question ${c.question} is corrected twice; use one entry`);
    } else {
      seen.add(`${c.date}#${c.question}`);
      corrections.push(c as unknown as Correction);
    }
  });
  return { corrections: problems.length > 0 ? [] : corrections, problems };
}

/** Whether two answers grade as the same one (normalized, or folded). */
function sameAnswer(a: string, b: string): boolean {
  const na = normalizeAnswer(a);
  const nb = normalizeAnswer(b);
  return na === nb || foldKeyboardVariants(na) === foldKeyboardVariants(nb);
}

/**
 * [question] with [correction] applied, or the problem. Wrong answers are
 * matched as graded (normalized), and each must match exactly one.
 */
function applyCorrection(question: SharedQuestion, correction: Correction): SharedQuestion | string {
  const { hint, ...rest } = question;
  let corrected: SharedQuestion = { ...question };
  if (correction.removeHint) {
    if (hint === undefined) return 'has no hint to remove';
    corrected = rest;
  }
  for (const remove of correction.removeWrongAnswers ?? []) {
    const matches = corrected.commonWrongAnswers.filter((w) => normalizeAnswer(w.answer) === normalizeAnswer(remove));
    if (matches.length !== 1) return `predicted wrong answer ${JSON.stringify(remove)} matches ${matches.length}, needs exactly 1`;
    corrected = { ...corrected, commonWrongAnswers: corrected.commonWrongAnswers.filter((w) => w !== matches[0]) };
  }
  if (correction.addAcceptedAnswers) {
    corrected = { ...corrected, acceptedAnswers: [...(question.acceptedAnswers ?? []), ...correction.addAcceptedAnswers.map((a) => a.trim())] };
  }
  return corrected;
}

/**
 * The rules an alternative of the check call follows
 * (docs/1.1.0-shared-daily-test-quality.md §8.2), so every accepted answer is
 * reachable and leaves every predicted wrong answer reachable too: non-blank,
 * at most [MAX_ACCEPTED_ANSWER_LENGTH] characters, not the key, not the
 * flawed sentence of an `error_correction`, not a predicted wrong answer, no
 * two alike (all as graded: normalized, then folded). §8.2's cap of 2 entries
 * is not applied: it is the check call's sign of a question that tests more
 * than one thing, and an owner correction may list spelling variants.
 */
function acceptedAnswerProblem(question: SharedQuestion): string | null {
  const accepted = question.acceptedAnswers ?? [];
  for (const [i, answer] of accepted.entries()) {
    const quoted = JSON.stringify(answer);
    if (normalizeAnswer(answer).length === 0) return `accepted answer ${quoted} is blank`;
    if (answer.length > MAX_ACCEPTED_ANSWER_LENGTH) return `accepted answer ${quoted} is over ${MAX_ACCEPTED_ANSWER_LENGTH} characters`;
    if (sameAnswer(answer, question.correctAnswer)) return `accepted answer ${quoted} is the key`;
    if (question.type === 'error_correction' && question.context !== undefined && sameAnswer(answer, question.context)) {
      return `accepted answer ${quoted} is the sentence to correct`;
    }
    if (question.commonWrongAnswers.some((w) => sameAnswer(answer, w.answer))) {
      return `accepted answer ${quoted} is also a predicted wrong answer`;
    }
    if (accepted.slice(0, i).some((earlier) => sameAnswer(earlier, answer))) return `accepted answer ${quoted} is listed twice`;
  }
  return null;
}

export function convert(
  raws: readonly RawSet[],
  corrections: readonly Correction[] = [],
  expectedCount = POOL_SIZE,
): ConvertResult {
  const problems: string[] = [];
  const kept: { date: string; attempt: unknown; questions: SharedQuestion[] }[] = [];

  if (raws.length !== expectedCount) {
    problems.push(`expected ${expectedCount} dates, got ${raws.length}`);
  }
  const dates = new Set<string>();
  for (const raw of raws) {
    if (dates.has(raw.date)) {
      problems.push(`${raw.date}: listed twice`);
      continue;
    }
    dates.add(raw.date);
    if (dayNumberOf(raw.date) === null) {
      problems.push(`${raw.date}: not a YYYY-MM-DD date`);
      continue;
    }
    let set: Record<string, unknown>;
    try {
      const parsed = parseKvOutput(raw.text);
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) throw new Error('not an object');
      set = parsed as Record<string, unknown>;
    } catch (e) {
      problems.push(`${raw.date}: unreadable (${(e as Error).message}); is the set published?`);
      continue;
    }
    if (set.date !== raw.date) {
      problems.push(`${raw.date}: the stored set says date ${JSON.stringify(set.date)}`);
      continue;
    }
    if (set.promptVersion !== REQUIRED_PROMPT_VERSION) {
      problems.push(`${raw.date}: promptVersion ${JSON.stringify(set.promptVersion)}, needs ${REQUIRED_PROMPT_VERSION}`);
      continue;
    }
    const result = validateSharedSet(set, dailyPlan(raw.date));
    if (!result.ok) {
      problems.push(`${raw.date}: rejected by the proxy gate (${result.reason})`);
      continue;
    }
    kept.push({ date: raw.date, attempt: set.attempt, questions: result.questions });
  }
  if (problems.length > 0) return { problems };

  // The owner's corrections, then the gate again on every corrected set.
  const notes = kept.map((set) => set.questions.map((): Correction | undefined => undefined));
  for (const correction of corrections) {
    const where = `${correction.date} question ${correction.question}`;
    const n = kept.findIndex((k) => k.date === correction.date);
    const set = kept[n];
    const question = set?.questions[correction.question - 1];
    if (set === undefined || question === undefined) {
      problems.push(`${where}: the correction matches no question (${set === undefined ? 'date not in this build' : 'no such question'})`);
      continue;
    }
    const corrected = applyCorrection(question, correction);
    if (typeof corrected === 'string') {
      problems.push(`${where}: ${corrected}`);
      continue;
    }
    set.questions[correction.question - 1] = corrected;
    notes[n]![correction.question - 1] = correction;
  }
  for (const [n, set] of kept.entries()) {
    if (!notes[n]!.some((c) => c !== undefined)) continue;
    const again = validateSharedSet({ questions: set.questions }, dailyPlan(set.date));
    if (!again.ok) {
      problems.push(`${set.date}: rejected by the proxy gate after the owner corrections (${again.reason})`);
      continue;
    }
    set.questions.forEach((q, i) => {
      const problem = acceptedAnswerProblem(q);
      if (problem !== null) problems.push(`${set.date} question ${i + 1}: ${problem}`);
    });
  }
  if (problems.length > 0) return { problems };

  const sets = kept.map((set, n) => ({
    questions: set.questions.map((q, i): PoolQuestion => {
      const { acceptedAnswers, ...rest } = q;
      return {
        ...rest,
        id: `${poolPrefix(n)}_${i + 1}`,
        ...(acceptedAnswers && acceptedAnswers.length > 0 ? { acceptedAnswers } : {}),
      };
    }),
  }));
  return {
    pool: { formatVersion: POOL_FORMAT_VERSION, sets },
    problems: [],
    review: reviewMarkdown(
      kept.map((k, n) => ({ date: k.date, questions: sets[n]!.questions, corrections: notes[n] })),
    ),
  };
}

export function poolPrefix(index: number): string {
  return `fb${String(index + 1).padStart(2, '0')}`;
}

/** What [correction] changed, in one line for the review. */
function correctionSummary(correction: Correction): string {
  const changes = [
    ...(correction.removeHint ? ['hint removed'] : []),
    ...(correction.removeWrongAnswers ?? []).map((a) => `predicted wrong removed: "${a}"`),
    ...(correction.addAcceptedAnswers ?? []).map((a) => `accepted added: "${a}"`),
  ];
  return `${changes.join('; ')} — ${correction.reason}`;
}

/** Question texts and answers only, one section per set, with each owner
 * correction and the accepted answers it added. */
export function reviewMarkdown(
  sets: readonly { date: string; questions: readonly PoolQuestion[]; corrections?: readonly (Correction | undefined)[] }[],
): string {
  const lines = [
    '# Daily Test fallback pool — owner review',
    '',
    'Live-generated sets (prompt v2, `claude-sonnet-5-5` at `low` effort), each passed the proxy gate again at export,',
    'and again after the owner corrections.',
    'Question text and answers only. Regenerated by `scripts/fallback_pool.sh build`; do not edit by hand:',
    'corrections go in `tool/fallback_pool/corrections.json`.',
    '',
  ];
  sets.forEach((set, n) => {
    lines.push(`## ${poolPrefix(n)} — published for ${set.date}`, '');
    set.questions.forEach((q, i) => {
      lines.push(`${i + 1}. \`${q.type}\` · ${q.topicId}`);
      if (q.context !== undefined) lines.push(`   - Context: ${q.context}`);
      lines.push(`   - Instruction: ${q.instruction}`);
      if (q.hint !== undefined) lines.push(`   - Hint: ${q.hint}`);
      lines.push(`   - **Answer:** ${q.correctAnswer}`);
      if (q.acceptedAnswers && q.acceptedAnswers.length > 0) {
        lines.push(`   - **Also accepted:** ${q.acceptedAnswers.join(' · ')}`);
      }
      lines.push(`   - Predicted wrong: ${q.commonWrongAnswers.map((w) => w.answer).join(' · ')}`);
      const correction = set.corrections?.[i];
      if (correction !== undefined) lines.push(`   - *Owner correction:* ${correctionSummary(correction)}`);
    });
    lines.push('');
  });
  return lines.join('\n');
}
