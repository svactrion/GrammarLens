import { hasSentenceToCorrect } from './shared_daily_test';

/**
 * The legacy route's response check (1.0.0 clients, `POST
 * /v1/generate-daily-test`; docs/1.1.0-shared-daily-test-quality.md §14.4 item
 * 5, option L3, owner decision 2026-09-28). The model sometimes leaves an
 * `error_correction` question without its sentence (E: 19 of 28 from
 * `claude-sonnet-4-6`), and 1.0.0 then shows an instruction about "this
 * sentence" with nothing to correct. Such questions are dropped, by the same
 * rule the shared set's gate uses (`hasSentenceToCorrect`). The request to
 * Anthropic is untouched; only the response is looked at.
 */

/** Questions a 1.0.0 set needs after a drop. Fewer is the existing upstream
 * error, which 1.0.0 shows as "Couldn't load today's test" with "Try again";
 * an empty list would crash its Daily Test screen. */
export const LEGACY_MIN_QUESTIONS = 3;

export interface LegacyFilterResult {
  /** What to serve: [content] itself when nothing was removed. */
  content: unknown;
  /** Entries in `questions`, or null when there is no `questions` array. */
  received: number | null;
  removed: number;
  served: number | null;
  /** Something was removed and fewer than [LEGACY_MIN_QUESTIONS] remain. */
  rejected: boolean;
}

function isSentencelessErrorCorrection(entry: unknown): boolean {
  if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) return false;
  const question = entry as Record<string, unknown>;
  return question.type === 'error_correction' && !hasSentenceToCorrect(question.context);
}

/**
 * Drops sentenceless `error_correction` questions and nothing else: every
 * other entry, and every field of the content, is served exactly as the model
 * wrote it. A response without a `questions` array passes through, as before.
 * The floor applies only when something was removed, so a response the check
 * does not touch is served as it always was.
 */
export function filterLegacyDailyTest(content: unknown): LegacyFilterResult {
  const questions = (content as { questions?: unknown } | null)?.questions;
  if (typeof content !== 'object' || content === null || !Array.isArray(questions)) {
    return { content, received: null, removed: 0, served: null, rejected: false };
  }
  const kept = questions.filter((entry) => !isSentencelessErrorCorrection(entry));
  const removed = questions.length - kept.length;
  if (removed === 0) return { content, received: questions.length, removed: 0, served: questions.length, rejected: false };
  const rejected = kept.length < LEGACY_MIN_QUESTIONS;
  return {
    content: { ...(content as Record<string, unknown>), questions: kept },
    received: questions.length,
    removed,
    served: rejected ? 0 : kept.length,
    rejected,
  };
}

/**
 * One line per legacy Daily Test response that has a `questions` array, so the
 * legacy rate of sentenceless questions can be measured for the first time.
 *
 * PRIVACY CONTRACT — only the fields built below: the event and operation
 * names, three counts and a fixed outcome word. Never anything from the
 * request (deviceId) or the response (question text). Do not add fields
 * without keeping that true.
 */
export function logLegacyFilter(result: LegacyFilterResult): void {
  if (result.received === null) return;
  console.log(
    JSON.stringify({
      event: 'legacy_daily_test_filter',
      operation: 'generate_daily_test',
      received_count: result.received,
      removed_count: result.removed,
      served_count: result.served,
      outcome: result.rejected ? 'rejected' : 'served',
    }),
  );
}
