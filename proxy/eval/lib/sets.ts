import { dailyPlan, validateSharedCandidates, validateSharedSet, type SharedQuestion } from '../../src/shared_daily_test';
import type { CheckerId, EvalModel, ReferenceId, Stage, VariantId } from './matrix';
import { generationVariant } from './matrix';

/**
 * One call E made (or skipped), as kept in the run's private folder. Content
 * is the parsed structured output; it never goes into the progress log.
 */
export interface CallRecord {
  customId: string;
  kind: 'generation' | 'check';
  stage: Stage;
  sync: boolean;
  model: EvalModel;
  variant?: VariantId;
  checker?: CheckerId;
  date?: string;
  reference?: ReferenceId;
  repeat?: number;
  status:
    | 'ok'
    | 'unparseable' // a text block that is not JSON, or none
    | 'http_error'
    | 'network_error'
    | 'errored' // a batch result of type "errored" (not billed)
    | 'expired' // a batch result of type "expired" (not billed)
    | 'canceled'
    | 'skipped_budget'
    | 'skipped_dependency'; // its set was not generated or did not pass the validator
  httpStatus?: number;
  errorType?: string;
  inputTokens?: number;
  outputTokens?: number;
  stopReason?: string | null;
  /** Synchronous calls only: request to full response. */
  durationMs?: number;
  costUsd: number;
  content?: unknown;
}

/** A generated set as the proxy's own gate reads it. */
export type GeneratedSet =
  | { valid: true; candidates: SharedQuestion[][] }
  | { valid: false; reason: string };

/** Runs a generation's content through the gate its strategy uses:
 * `validateSharedSet` (one per slot) or `validateSharedCandidates` (two). */
export function readGeneratedSet(record: CallRecord): GeneratedSet {
  if (record.kind !== 'generation' || !record.variant || !record.date) throw new Error('Not a generation record.');
  if (record.status !== 'ok') return { valid: false, reason: record.status };
  const variant = generationVariant(record.variant);
  const plan = dailyPlan(record.date);
  if (variant.candidatesPerSlot === 1) {
    const result = validateSharedSet(record.content, plan);
    return result.ok ? { valid: true, candidates: result.questions.map((q) => [q]) } : { valid: false, reason: result.reason };
  }
  const result = validateSharedCandidates(record.content, plan, variant.candidatesPerSlot);
  return result.ok ? { valid: true, candidates: result.candidates } : { valid: false, reason: result.reason };
}

/** A reference set's questions, from a stored `set:{date}` record or any
 * `{questions: [...]}`. Only the fields the checker reads are kept. */
export function readReferenceSet(json: unknown): SharedQuestion[] {
  const raw = (json as { questions?: unknown } | null)?.questions;
  if (!Array.isArray(raw) || raw.length === 0) throw new Error('A reference set needs a non-empty "questions" array.');
  return raw.map((q: Record<string, unknown>) => {
    for (const field of ['id', 'type', 'topicId', 'instruction', 'correctAnswer', 'explanation']) {
      if (typeof q[field] !== 'string') throw new Error(`A reference question has no "${field}".`);
    }
    if (!Array.isArray(q.commonWrongAnswers)) throw new Error('A reference question has no "commonWrongAnswers".');
    return {
      id: q.id as string,
      type: q.type as SharedQuestion['type'],
      ...(typeof q.context === 'string' ? { context: q.context } : {}),
      instruction: q.instruction as string,
      ...(typeof q.hint === 'string' ? { hint: q.hint } : {}),
      topicId: q.topicId as string,
      correctAnswer: q.correctAnswer as string,
      explanation: q.explanation as string,
      commonWrongAnswers: (q.commonWrongAnswers as { answer: string; comment: string }[]).map((w) => ({
        answer: w.answer,
        comment: w.comment,
      })),
    };
  });
}

export type ReferenceSets = Partial<Record<ReferenceId, SharedQuestion[]>>;
