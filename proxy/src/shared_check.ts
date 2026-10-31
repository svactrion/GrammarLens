import { foldKeyboardVariants, normalizeAnswer, type SharedQuestion, type SharedWrongAnswer } from './shared_daily_test';

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

/** Stored with a set the check annotated, and bumped on any change to the
 * checker's prompt, schema or decision rules. 2: the prompt made
 * language-neutral (1.4.0 D3, 2026-10-31); 1 never ran in production. */
export const CHECK_VERSION = 2;

/**
 * Checker candidates (decision 6 and its 2026-09-27 follow-up): a model
 * different from the generator and at least as strong. `claude-sonnet-5` is
 * the default candidate while the generator is `claude-sonnet-4-6`;
 * `claude-opus-5-5` if the generator becomes `claude-sonnet-5`;
 * `claude-sonnet-4-6` is measured for comparison. All run with adaptive
 * thinking.
 */
export type CheckerModel = 'claude-sonnet-5' | 'claude-sonnet-4-6' | 'claude-opus-5-5' | 'claude-sonnet-5-5';

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

// ---------------------------------------------------------------------------
// Annotate-after-publish (P14; docs/1.4.0-server-batch0-report.md §1.3–1.4,
// owner decisions 2026-10-31)

/**
 * The two gates the owner asked to have built behind one constant (§5.3);
 * the choice follows the measurement report. `agreement`: an answer is
 * written only when every checker proposed it. `single_review`: one checker,
 * and the owner's weekly look at `review:{date}` is the second reviewer.
 */
export type AnnotationGate = 'agreement' | 'single_review';

export const ANNOTATION_GATE: AnnotationGate = 'single_review'; // owner, 2026-10-31, after the measurement: the second checker filtered one answer in 37

/** The checkers each gate runs, in call order. The agreement pair differs in
 * model family from each other and from the generator. */
export const ANNOTATION_CHECKERS: Readonly<Record<AnnotationGate, readonly CheckerModel[]>> = {
  agreement: ['claude-opus-5-5', 'claude-sonnet-5-5'],
  single_review: ['claude-opus-5-5'],
};

/** What the annotation step found and did not write, as a fixed vocabulary
 * (it goes into `review:{date}` and the log). */
export type AnnotationFindingCode =
  | 'original_not_wrong' // error_correction: a checker could defend the "flawed" sentence
  | 'key_incorrect' // a checker doubts the key
  | 'wrong_rule' // a checker names a false rule in the hint, explanation or a comment
  | 'checker_verdict' // a checker says reject although its fields pass
  | 'explanation_excludes_alternative' // the explanation rules out what would be accepted: nothing written
  | 'ambiguous_question' // more than MAX_ACCEPTED_ANSWERS candidates: nothing written
  | 'alternative_is_original' // the flawed sentence itself was proposed
  | 'alternative_conflicts_wrong_answer' // a candidate is still a predicted wrong answer
  | 'alternative_not_plain' // a candidate does not fold to itself (§1.4 rule 2)
  | 'key_not_plain' // the key does not fold to itself: the folding could collide
  | 'proposed_by_one_model' // under the agreement gate: not every checker proposed it
  | 'move_leaves_no_wrong_answer' // moving the acceptable wrong answers would empty the list
  | 'alternative_unshifted' // a reported-speech item: the alternative keeps the unshifted form the item tests
  | 'alternative_defeats_rule' // a deduction item: the alternative replaces the deduction modal with a prediction
  | 'alternative_changes_other_words'; // error_correction: the alternative edits words the key leaves alone

export interface AnnotationFinding {
  questionId: string;
  code: AnnotationFindingCode;
  /** Which checker, where one is responsible. */
  model?: CheckerModel;
  /** The answers or fields concerned: model-written text, never a user's. */
  answers?: string[];
}

export interface QuestionAnnotation {
  /** The question's accepted answers after the step: what it had, plus what
   * was written now. */
  acceptedAnswers: string[];
  /** The predicted wrong answers after the moves, in their original order. */
  commonWrongAnswers: SharedWrongAnswer[];
  findings: AnnotationFinding[];
  /** How many answers this step added (alternatives and moves). */
  added: number;
  moved: number;
}

export interface CheckerReview {
  model: CheckerModel;
  check: QuestionCheck;
}

/** An answer that is plain under the folding: the key and every accepted
 * answer must be, so a fold can only move a learner's text towards them. */
export function isPlainAnswer(answer: string): boolean {
  const normalized = normalizeAnswer(answer);
  return foldKeyboardVariants(normalized) === normalized;
}

// ---------------------------------------------------------------------------
// The tested-rule filters (owner, 2026-10-31)

/** Backshift pairs: the unshifted form a reported-speech item tests against
 * its shifted form. The modal and going-to pairs are judged across pairs
 * (an alternative with "will" against a key with "could" keeps an unshifted
 * form); the auxiliary pairs only like for like, since "is" and "have" occur
 * in sentences for other reasons. */
const BACKSHIFT_MODALS: readonly [unshifted: string, shifted: string][] = [
  ['is going to', 'was going to'],
  ['are going to', 'were going to'],
  ['am going to', 'was going to'],
  ['will', 'would'],
  ['can', 'could'],
  ['may', 'might'],
  ['shall', 'should'],
];
const BACKSHIFT_AUXILIARIES: readonly [unshifted: string, shifted: string][] = [
  ['has', 'had'],
  ['have', 'had'],
  ['is', 'was'],
  ['are', 'were'],
];

const REPORTED_SPEECH = /\b(said|told|asked|reported|replied|explained|promised|announced|mentioned|reported speech|backshift\w*)\b/i;

function words(text: string): string[] {
  return normalizeAnswer(text).replace(/[^\p{L}\p{N}' ]/gu, ' ').split(/\s+/).filter(Boolean);
}

function containsPhrase(haystack: readonly string[], phrase: string): boolean {
  const needle = phrase.split(' ');
  return haystack.some((_, i) => needle.every((w, j) => haystack[i + j] === w));
}

/**
 * A reported-speech item (its text or explanation speaks of saying, telling
 * or reporting) whose key carries a shifted form: an alternative that carries
 * the unshifted counterpart of any shifted form the key uses keeps exactly
 * the form the item tests ("he will fix" against "he could fix"; "will"
 * against "would"), so it is right English and wrong here.
 */
export function isUnshiftedAlternative(question: SharedQuestion, alternative: string): boolean {
  const text = `${question.context ?? ''} ${question.instruction} ${question.hint ?? ''} ${question.explanation}`;
  if (!REPORTED_SPEECH.test(text)) return false;
  const key = words(question.correctAnswer);
  const alt = words(alternative);
  const keyHasShiftedModal = BACKSHIFT_MODALS.some(([, shifted]) => containsPhrase(key, shifted));
  const altKeepsUnshiftedModal = BACKSHIFT_MODALS.some(([unshifted]) => containsPhrase(alt, unshifted) && !containsPhrase(key, unshifted));
  if (keyHasShiftedModal && altKeepsUnshiftedModal) return true;
  return BACKSHIFT_AUXILIARIES.some(([unshifted, shifted]) => containsPhrase(key, shifted) && containsPhrase(alt, unshifted) && !containsPhrase(key, unshifted));
}

const DEDUCTION = /\b(deduc\w*|certain\w*|logical\w*|evidence|conclu\w*|must be|sure that)\b/i;
const PREDICTION_FORMS = ['will', 'is going to', 'are going to', 'shall'];

/** A deduction item ("must" with an explanation about certainty or a logical
 * conclusion): a prediction form in place of the deduction modal defeats the
 * rule ("will" for "must"). */
export function defeatsDeduction(question: SharedQuestion, alternative: string): boolean {
  const key = words(question.correctAnswer);
  if (!containsPhrase(key, 'must')) return false;
  if (!DEDUCTION.test(question.explanation) && !DEDUCTION.test(question.hint ?? '')) return false;
  const alt = words(alternative);
  return PREDICTION_FORMS.some((f) => containsPhrase(alt, f)) && !containsPhrase(alt, 'must');
}

/**
 * error_correction: the key changes one span of the flawed sentence and
 * keeps every other word. An alternative that loses one of those kept words
 * ("an orange" where the key keeps "oranges" and only drops the article)
 * corrects something else or the wrong thing; an alternative that rephrases
 * the erroneous span and its neighbours while keeping the other words ("was
 * not able to find" for "could not find") is left to the other rules.
 * Measured after normalization, order-free.
 */
export function changesOtherWords(question: SharedQuestion, alternative: string): boolean {
  if (question.type !== 'error_correction' || question.context === undefined) return false;
  const original = words(question.context);
  const key = words(question.correctAnswer);
  let prefix = 0;
  while (prefix < original.length && prefix < key.length && original[prefix] === key[prefix]) prefix++;
  let suffix = 0;
  while (suffix < original.length - prefix && suffix < key.length - prefix && original[original.length - 1 - suffix] === key[key.length - 1 - suffix]) suffix++;
  const kept = [...original.slice(0, prefix), ...original.slice(original.length - suffix)];
  const available = new Map<string, number>();
  for (const w of words(alternative)) available.set(w, (available.get(w) ?? 0) + 1);
  for (const w of kept) {
    const n = available.get(w) ?? 0;
    if (n === 0) return true;
    available.set(w, n - 1);
  }
  return false;
}

/** The entries of [first] that every other list also holds. */
function agreedAnswers(lists: readonly (readonly string[])[]): string[] {
  const [first = [], ...rest] = lists;
  return first.filter((a) => rest.every((list) => list.some((b) => sameAnswer(a, b))));
}

/**
 * One published question against the checkers' reviews, add-only: nothing
 * here can reject or change the question's texts; it can add accepted
 * answers, move an acceptable predicted wrong answer into them (owner
 * decision 2 of 2026-09-28, implemented here), and record findings. Rules,
 * in order (§1.4): gather what every checker agrees on; an explanation that
 * excludes the candidates, or more than [MAX_ACCEPTED_ANSWERS] of them, means
 * nothing is written; then each candidate is dropped if it is the original
 * sentence, still a predicted wrong answer, or not plain; a move that would
 * leave no wrong answer is not made.
 */
export function annotateQuestion(question: SharedQuestion, reviews: readonly CheckerReview[]): QuestionAnnotation {
  const findings: AnnotationFinding[] = [];
  const finding = (code: AnnotationFindingCode, extra: Omit<AnnotationFinding, 'questionId' | 'code'> = {}) =>
    findings.push({ questionId: question.id, code, ...extra });

  for (const { model, check } of reviews) {
    if (question.type === 'error_correction' && check.originalSentence !== 'clearly_wrong') finding('original_not_wrong', { model });
    if (check.correctAnswer !== 'correct') finding('key_incorrect', { model });
    if (check.incorrectRuleFields.length > 0) finding('wrong_rule', { model, answers: [...check.incorrectRuleFields] });
    if (check.verdict === 'reject') finding('checker_verdict', { model });
  }
  if (!isPlainAnswer(question.correctAnswer)) finding('key_not_plain', { answers: [question.correctAnswer] });

  const alternativesPer = reviews.map((r) => cleanAlternatives(question, r.check.acceptableAlternatives));
  const movesPer = reviews.map((r) =>
    question.commonWrongAnswers.filter((w) => r.check.acceptableWrongAnswers.some((a) => sameAnswer(a, w.answer))).map((w) => w.answer),
  );
  const agreedAlternatives = agreedAnswers(alternativesPer);
  const agreedMoves = agreedAnswers(movesPer);
  reviews.forEach((r, i) => {
    const alone = [...(alternativesPer[i] ?? []), ...(movesPer[i] ?? [])].filter(
      (a) => !agreedAlternatives.some((b) => sameAnswer(a, b)) && !agreedMoves.some((b) => sameAnswer(a, b)),
    );
    if (alone.length > 0) finding('proposed_by_one_model', { model: r.model, answers: alone });
  });

  let candidates = [...agreedAlternatives];
  let moves = [...agreedMoves];
  const untouched = { acceptedAnswers: [...(question.acceptedAnswers ?? [])], commonWrongAnswers: [...question.commonWrongAnswers] };

  if (moves.length > 0 && question.commonWrongAnswers.every((w) => moves.some((m) => sameAnswer(m, w.answer)))) {
    finding('move_leaves_no_wrong_answer', { answers: moves });
    moves = [];
  }
  const all = [...candidates, ...moves.filter((m) => !candidates.some((c) => sameAnswer(c, m)))];
  if (all.length > 0 && reviews.some((r) => r.check.explanationExcludesAlternatives)) {
    finding('explanation_excludes_alternative', { answers: all });
    return { ...untouched, findings, added: 0, moved: 0 };
  }
  if (all.length > MAX_ACCEPTED_ANSWERS) {
    finding('ambiguous_question', { answers: all });
    return { ...untouched, findings, added: 0, moved: 0 };
  }

  const remainingWrong = question.commonWrongAnswers.filter((w) => !moves.some((m) => sameAnswer(m, w.answer)));
  const context = question.context;
  candidates = candidates.filter((a) => {
    if (question.type === 'error_correction' && context !== undefined && sameAnswer(a, context)) {
      finding('alternative_is_original', { answers: [a] });
      return false;
    }
    if (remainingWrong.some((w) => sameAnswer(a, w.answer))) {
      finding('alternative_conflicts_wrong_answer', { answers: [a] });
      return false;
    }
    return true;
  });
  const plain = (a: string) => {
    if (isPlainAnswer(a)) return true;
    finding('alternative_not_plain', { answers: [a] });
    return false;
  };
  candidates = candidates.filter(plain);
  moves = moves.filter(plain);
  // The three rules of 2026-10-31 (owner, after the measurement: 6 of 23
  // written answers defeated the tested rule while being right English).
  const defeats = (a: string): AnnotationFindingCode | null => {
    if (isUnshiftedAlternative(question, a)) return 'alternative_unshifted';
    if (defeatsDeduction(question, a)) return 'alternative_defeats_rule';
    if (changesOtherWords(question, a)) return 'alternative_changes_other_words';
    return null;
  };
  const ruleFilter = (a: string) => {
    const code = defeats(a);
    if (code === null) return true;
    finding(code, { answers: [a] });
    return false;
  };
  candidates = candidates.filter(ruleFilter);
  moves = moves.filter(ruleFilter);
  const finalWrong = question.commonWrongAnswers.filter((w) => !moves.some((m) => sameAnswer(m, w.answer)));

  const accepted = [...untouched.acceptedAnswers];
  let added = 0;
  for (const a of [...candidates, ...moves]) {
    if (accepted.some((b) => sameAnswer(a, b)) || sameAnswer(a, question.correctAnswer)) continue;
    accepted.push(a);
    added++;
  }
  return { acceptedAnswers: accepted, commonWrongAnswers: finalWrong, findings, added, moved: moves.length };
}

export type SetAnnotation =
  | {
      outcome: 'annotated';
      /** The published questions, in order, with the step's changes. */
      questions: SharedQuestion[];
      added: number;
      moved: number;
      findings: AnnotationFinding[];
    }
  | { outcome: 'unreadable'; model: CheckerModel };

/** Every checker's output against the published questions. One unreadable
 * review makes the whole step unusable (the set is left as it is and the
 * step is retried on a later run). */
export function annotateSet(questions: readonly SharedQuestion[], outputs: readonly { model: CheckerModel; output: unknown }[]): SetAnnotation {
  const parsed: { model: CheckerModel; checks: Map<string, QuestionCheck> }[] = [];
  for (const { model, output } of outputs) {
    const checks = parseCheckOutput(output, questions);
    if (checks === null) return { outcome: 'unreadable', model };
    parsed.push({ model, checks });
  }
  const annotated: SharedQuestion[] = [];
  const findings: AnnotationFinding[] = [];
  let added = 0;
  let moved = 0;
  for (const q of questions) {
    const result = annotateQuestion(
      q,
      parsed.map((p) => ({ model: p.model, check: p.checks.get(q.id) as QuestionCheck })),
    );
    annotated.push({
      ...q,
      commonWrongAnswers: result.commonWrongAnswers,
      ...(result.acceptedAnswers.length > 0 ? { acceptedAnswers: result.acceptedAnswers } : {}),
    });
    findings.push(...result.findings);
    added += result.added;
    moved += result.moved;
  }
  return { outcome: 'annotated', questions: annotated, added, moved, findings };
}

/**
 * Whether [after] is [before] with nothing but accepted answers added and
 * predicted wrong answers moved into them: the only write the annotation
 * step may make to a published set (owner decision 2 of 2026-10-31). Same
 * questions in the same order, every text identical; `commonWrongAnswers` a
 * subsequence of before's, each removed one present in `acceptedAnswers`;
 * before's accepted answers all kept.
 */
export function isAdditivePatch(before: readonly SharedQuestion[], after: readonly SharedQuestion[]): boolean {
  if (before.length !== after.length) return false;
  const fields = ['id', 'type', 'context', 'instruction', 'hint', 'topicId', 'correctAnswer', 'explanation'] as const;
  for (let i = 0; i < before.length; i++) {
    const b = before[i] as SharedQuestion;
    const a = after[i] as SharedQuestion;
    if (fields.some((f) => b[f] !== a[f])) return false;
    let j = 0;
    for (const w of b.commonWrongAnswers) {
      const kept = a.commonWrongAnswers[j];
      if (kept && kept.answer === w.answer && kept.comment === w.comment) {
        j++;
      } else if (!(a.acceptedAnswers ?? []).some((x) => sameAnswer(x, w.answer))) {
        return false;
      }
    }
    if (j !== a.commonWrongAnswers.length) return false;
    if (a.commonWrongAnswers.length === 0) return false;
    if ((b.acceptedAnswers ?? []).some((x) => !(a.acceptedAnswers ?? []).some((y) => sameAnswer(x, y)))) return false;
  }
  return true;
}
