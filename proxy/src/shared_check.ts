import { foldKeyboardVariants, normalizeAnswer, type SharedQuestion } from './shared_daily_test';

/**
 * The check call's pure parts (docs/1.1.0-shared-daily-test-quality.md §2,
 * §8; decisions 2026-09-27): what the checker model is asked for, how its
 * answer is read, and how the proxy turns it into publish or reject. The
 * decision is the proxy's, made field by field; the model's own verdict can
 * only add a rejection, never publish against the fields.
 *
 * Nothing here calls Anthropic (the request is built in `anthropic.ts` as the
 * `check_shared_daily_test` operation) and nothing here is wired to the cron
 * yet: that is P7.
 */

/** Stored with a set the check published, and bumped on any change to the
 * checker's prompt, schema or decision rules. */
export const CHECK_VERSION = 1;

/**
 * Checker candidates (decision 6 and its 2026-09-27 follow-up): a model
 * different from the generator and at least as strong. `claude-sonnet-5` is
 * the default candidate while the generator is `claude-sonnet-4-6`;
 * `claude-opus-5-5` if the generator becomes `claude-sonnet-5`;
 * `claude-sonnet-4-6` is measured for comparison. All run with adaptive
 * thinking.
 */
export type CheckerModel = 'claude-sonnet-5' | 'claude-sonnet-4-6' | 'claude-opus-5-5';

export const CHECKER_MODEL: CheckerModel = 'claude-sonnet-5';

/** At most this many alternatives become `acceptedAnswers`; more means the
 * question does not test one thing (§2.3 rule 6). */
export const MAX_ACCEPTED_ANSWERS = 2;
export const MAX_ACCEPTED_ANSWER_LENGTH = 300;

export interface CheckSharedDailyTestRequest {
  readonly questions: readonly SharedQuestion[];
  /** `questions.length`, read by the usage log's `item_count`. */
  readonly count: number;
  readonly model: CheckerModel;
}

export function sharedCheckRequest(
  questions: readonly SharedQuestion[],
  model: CheckerModel = CHECKER_MODEL,
): CheckSharedDailyTestRequest {
  return { questions, count: questions.length, model };
}

// ---------------------------------------------------------------------------
// The checker's answer

export const ORIGINAL_SENTENCE_VALUES = ['clearly_wrong', 'acceptable', 'not_applicable'] as const;
export const CORRECT_ANSWER_VALUES = ['correct', 'incorrect', 'uncertain'] as const;
export const RULE_FIELD_VALUES = ['hint', 'explanation', 'comment'] as const;
export const VERDICT_VALUES = ['pass', 'pass_with_alternatives', 'reject'] as const;

/** One question's review, as the checker's structured output gives it (§2.2). */
export interface QuestionCheck {
  id: string;
  originalSentence: (typeof ORIGINAL_SENTENCE_VALUES)[number];
  correctAnswer: (typeof CORRECT_ANSWER_VALUES)[number];
  acceptableAlternatives: string[];
  acceptableWrongAnswers: string[];
  incorrectRuleFields: (typeof RULE_FIELD_VALUES)[number][];
  explanationExcludesAlternatives: boolean;
  verdict: (typeof VERDICT_VALUES)[number];
}

function isOneOf<T extends string>(values: readonly T[], value: unknown): value is T {
  return typeof value === 'string' && (values as readonly string[]).includes(value);
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every((v) => typeof v === 'string');
}

function readCheck(entry: unknown): QuestionCheck | null {
  if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) return null;
  const e = entry as Record<string, unknown>;
  if (
    typeof e.id !== 'string' ||
    !isOneOf(ORIGINAL_SENTENCE_VALUES, e.originalSentence) ||
    !isOneOf(CORRECT_ANSWER_VALUES, e.correctAnswer) ||
    !isStringArray(e.acceptableAlternatives) ||
    !isStringArray(e.acceptableWrongAnswers) ||
    !Array.isArray(e.incorrectRuleFields) ||
    !e.incorrectRuleFields.every((f) => isOneOf(RULE_FIELD_VALUES, f)) ||
    typeof e.explanationExcludesAlternatives !== 'boolean' ||
    !isOneOf(VERDICT_VALUES, e.verdict)
  ) {
    return null;
  }
  return {
    id: e.id,
    originalSentence: e.originalSentence,
    correctAnswer: e.correctAnswer,
    acceptableAlternatives: e.acceptableAlternatives,
    acceptableWrongAnswers: e.acceptableWrongAnswers,
    incorrectRuleFields: e.incorrectRuleFields as QuestionCheck['incorrectRuleFields'],
    explanationExcludesAlternatives: e.explanationExcludesAlternatives,
    verdict: e.verdict,
  };
}

/**
 * The checker's answer, one review per question by id, or null when it cannot
 * be used (§2.3 row 0, `check_unreadable`): not `{questions: [...]}`, a
 * different number of reviews, an unknown, missing or repeated id, or a field
 * outside its fixed values. A null is a failed check, not a rejection.
 */
export function parseCheckOutput(
  output: unknown,
  questions: readonly SharedQuestion[],
): Map<string, QuestionCheck> | null {
  if (typeof output !== 'object' || output === null || Array.isArray(output)) return null;
  const raw = (output as Record<string, unknown>).questions;
  if (!Array.isArray(raw) || raw.length !== questions.length) return null;
  const ids = new Set(questions.map((q) => q.id));
  const checks = new Map<string, QuestionCheck>();
  for (const entry of raw) {
    const check = readCheck(entry);
    if (check === null || !ids.has(check.id) || checks.has(check.id)) return null;
    checks.set(check.id, check);
  }
  return checks;
}

// ---------------------------------------------------------------------------
// The decision (§2.3, approved as written 2026-09-27)

/** Why the check rejected a question, as a fixed vocabulary (it is logged). */
export type CheckRejection =
  | 'original_not_wrong' // error_correction: the "flawed" sentence is acceptable
  | 'key_incorrect' // correctAnswer is not correct (or the checker is unsure)
  | 'wrong_rule' // a hint, explanation or comment states a false rule
  | 'wrong_answer_acceptable' // a predicted wrong answer is in fact acceptable
  | 'explanation_excludes_alternative' // the explanation rules out an accepted answer
  | 'ambiguous_question' // more than MAX_ACCEPTED_ANSWERS alternatives
  | 'alternative_is_original' // an "alternative" is the flawed sentence itself
  | 'alternative_conflicts_wrong_answer' // an alternative is a predicted wrong answer
  | 'checker_verdict'; // every field passes but the checker still says reject

export type QuestionDecision = { pass: true; acceptedAnswers: string[] } | { pass: false; reason: CheckRejection };

function sameAnswer(a: string, b: string): boolean {
  const na = normalizeAnswer(a);
  const nb = normalizeAnswer(b);
  return na === nb || foldKeyboardVariants(na) === foldKeyboardVariants(nb);
}

/**
 * The alternatives worth keeping: noise is dropped rather than rejected
 * (§2.3): anything blank, too long, the key itself once normalized or folded,
 * or a repeat of an earlier alternative. The text is kept as the checker wrote
 * it, trimmed.
 */
function cleanAlternatives(question: SharedQuestion, alternatives: readonly string[]): string[] {
  const kept: string[] = [];
  for (const raw of alternatives) {
    const alternative = raw.trim();
    if (alternative.length === 0 || alternative.length > MAX_ACCEPTED_ANSWER_LENGTH) continue;
    if (normalizeAnswer(alternative).length === 0) continue;
    if (sameAnswer(alternative, question.correctAnswer)) continue;
    if (kept.some((k) => sameAnswer(k, alternative))) continue;
    kept.push(alternative);
  }
  return kept;
}

/** One question against its review, rows 1–9 of §2.3 in order. */
export function decideQuestion(question: SharedQuestion, check: QuestionCheck): QuestionDecision {
  const reject = (reason: CheckRejection): QuestionDecision => ({ pass: false, reason });

  if (question.type === 'error_correction' && check.originalSentence !== 'clearly_wrong') {
    return reject('original_not_wrong');
  }
  if (check.correctAnswer !== 'correct') return reject('key_incorrect');
  if (check.incorrectRuleFields.length > 0) return reject('wrong_rule');
  if (check.acceptableWrongAnswers.length > 0) return reject('wrong_answer_acceptable');

  const alternatives = cleanAlternatives(question, check.acceptableAlternatives);
  if (alternatives.length > 0 && check.explanationExcludesAlternatives) {
    return reject('explanation_excludes_alternative');
  }
  if (alternatives.length > MAX_ACCEPTED_ANSWERS) return reject('ambiguous_question');
  const context = question.context;
  if (question.type === 'error_correction' && context !== undefined && alternatives.some((a) => sameAnswer(a, context))) {
    return reject('alternative_is_original');
  }
  if (alternatives.some((a) => question.commonWrongAnswers.some((w) => sameAnswer(a, w.answer)))) {
    return reject('alternative_conflicts_wrong_answer');
  }
  if (check.verdict === 'reject') return reject('checker_verdict');
  return { pass: true, acceptedAnswers: alternatives };
}

export type CheckedSetDecision =
  | {
      outcome: 'publish';
      /** In plan order, each with `acceptedAnswers` (possibly empty). */
      questions: SharedQuestion[];
      alternativesAdded: number;
      /** Questions (or, over-generated, candidates) the check rejected. */
      questionsRejected: number;
    }
  | { outcome: 'reject'; reason: CheckRejection; questionsRejected: number }
  | { outcome: 'unreadable' };

/**
 * One candidate per slot (strategy S1): published only if every question
 * passes. A rejection carries the first failing question's reason, in plan
 * order, and how many failed.
 */
export function decideCheckedSet(questions: readonly SharedQuestion[], output: unknown): CheckedSetDecision {
  return selectCandidates(
    questions.map((q) => [q]),
    output,
  );
}

/**
 * Over-generated candidates (strategy S2, owner addition A), grouped by plan
 * slot: every slot needs one candidate that passes, and the one chosen is the
 * passing candidate with the fewest accepted alternatives (an item with a
 * single right answer is the better item), then the first. The output must
 * review every candidate. A slot with no passing candidate rejects the set with
 * the reason of that slot's first candidate.
 */
export function selectCandidates(candidates: readonly (readonly SharedQuestion[])[], output: unknown): CheckedSetDecision {
  const all = candidates.flat();
  const checks = parseCheckOutput(output, all);
  if (checks === null) return { outcome: 'unreadable' };

  const decided = candidates.map((slot) =>
    slot.map((question) => ({ question, decision: decideQuestion(question, checks.get(question.id) as QuestionCheck) })),
  );
  const questionsRejected = decided.flat().filter((d) => !d.decision.pass).length;

  const chosen: SharedQuestion[] = [];
  for (const slot of decided) {
    let best: { question: SharedQuestion; acceptedAnswers: string[] } | null = null;
    for (const { question, decision } of slot) {
      if (decision.pass && (best === null || decision.acceptedAnswers.length < best.acceptedAnswers.length)) {
        best = { question, acceptedAnswers: decision.acceptedAnswers };
      }
    }
    if (best === null) {
      const first = slot[0]?.decision;
      return {
        outcome: 'reject',
        reason: first && !first.pass ? first.reason : 'checker_verdict',
        questionsRejected,
      };
    }
    chosen.push({ ...best.question, acceptedAnswers: best.acceptedAnswers });
  }
  return {
    outcome: 'publish',
    questions: chosen,
    alternativesAdded: chosen.reduce((n, q) => n + (q.acceptedAnswers?.length ?? 0), 0),
    questionsRejected,
  };
}

// ---------------------------------------------------------------------------
// Grading order with acceptedAnswers — the contract batch C1 implements in Dart

export type GradeKind = 'correct' | 'keyboardVariant' | 'accepted' | 'commonWrong' | 'fallback';

export interface GradableQuestion {
  correctAnswer: string;
  acceptedAnswers?: readonly string[];
  commonWrongAnswers: readonly { answer: string }[];
}

/**
 * TypeScript statement of how the app will grade once it reads
 * `acceptedAnswers` (§8.2): correct → keyboard variant of correct → an accepted
 * answer (exact or keyboard variant) → a predicted wrong answer → fallback. The
 * first two and the last two are `checkDailyTestAnswer`
 * (lib/utils/answer_matching.dart) as it is today. `test/fixtures/
 * daily_test_grading.json` is the contract; the Dart test reading it comes in
 * C1. The proxy uses this only to prove that the rules above leave every
 * branch reachable.
 */
export function gradeAnswer(question: GradableQuestion, input: string): GradeKind {
  const user = normalizeAnswer(input);
  const correct = normalizeAnswer(question.correctAnswer);
  if (user === correct) return 'correct';
  if (foldKeyboardVariants(user) === foldKeyboardVariants(correct)) return 'keyboardVariant';
  for (const accepted of question.acceptedAnswers ?? []) {
    const normalized = normalizeAnswer(accepted);
    if (user === normalized || foldKeyboardVariants(user) === foldKeyboardVariants(normalized)) return 'accepted';
  }
  for (const wrong of question.commonWrongAnswers) {
    if (user === normalizeAnswer(wrong.answer)) return 'commonWrong';
  }
  return 'fallback';
}
