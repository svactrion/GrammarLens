import type { ScoreAnswersRequest } from './validation';

/**
 * The scorer's response checked against the request: has every answer that
 * was sent got a usable verdict, and is there nothing else in it?
 *
 * Owner decision 2026-11-19 (docs/TOPICS.md phase D; the finding is in
 * docs/1.5.0-topics-progress.md, "a set where the scorer leaves an answer
 * out"). In the topics measurement the production scorer left 3 of 1,190
 * answers without a usable verdict: one response gave feedback for one of
 * the answers it was sent, one gave feedback under an id that was not asked.
 * The schema fixes the shape of an entry, not how many there are or which
 * ids they carry, and the app builds its result from the entries that came:
 * the learner got a result a question short, and was not told.
 *
 * The route now asks the scorer once more when a response is incomplete, and
 * answers with the usual upstream error when the second one is incomplete
 * too. The app then keeps the answers on the screen with its message, and
 * the learner sends them again. No app version is needed for this.
 */

export interface ScoreVerdictGaps {
  /** Answers the request sent. */
  requested: number;
  /** Of them, without a usable verdict in the response. */
  missing: number;
  /** Entries of the response that belong to no answer of the request: an id
   * that was not asked, a second entry for an id, or not an entry at all. */
  extra: number;
}

/** A usable verdict: an entry for an id of the request that says whether
 * the answer is correct. The rest of the entry is the schema's business
 * (and {@link checkScoreFeedback}'s). */
export function scoreVerdictGaps(request: ScoreAnswersRequest, content: unknown): ScoreVerdictGaps {
  const requested = request.items.length;
  const feedback =
    typeof content === 'object' && content !== null && !Array.isArray(content) ? (content as Record<string, unknown>).feedback : undefined;
  if (!Array.isArray(feedback)) return { requested, missing: requested, extra: 0 };

  const open = new Set(request.items.map((item) => item.id));
  let extra = 0;
  for (const raw of feedback) {
    const entry = typeof raw === 'object' && raw !== null && !Array.isArray(raw) ? (raw as Record<string, unknown>) : null;
    const id = entry !== null && typeof entry.itemId === 'string' ? entry.itemId : null;
    if (entry !== null && id !== null && open.has(id) && typeof entry.isCorrect === 'boolean') open.delete(id);
    else extra++;
  }
  return { requested, missing: open.size, extra };
}

export function isCompleteScore(gaps: ScoreVerdictGaps): boolean {
  return gaps.missing === 0 && gaps.extra === 0;
}

/**
 * How long the first attempt may have taken for a second one to be worth
 * making. The app gives a request 40 s (`defaultRequestTimeout` in
 * `lib/services/claude_service.dart`), and a second scoring takes about as
 * long as the first: past this the answer would arrive after the app has
 * given up, so the route answers with the error at once instead.
 */
export const SCORE_RETRY_MAX_FIRST_MS = 18_000;

export type ScoreIncompleteOutcome = 'retry' | 'failed' | 'failed_no_time';

/**
 * One line per incomplete scoring response, so its rate on the live path
 * can be read from the logs.
 *
 * PRIVACY CONTRACT — only the fields built below: the event, counts, the
 * attempt and what the route did. Never an item id, a prompt, an answer or
 * any text of the response.
 */
export function logScoreIncomplete(gaps: ScoreVerdictGaps, attempt: 1 | 2, outcome: ScoreIncompleteOutcome): void {
  console.log(
    JSON.stringify({
      event: 'score_incomplete',
      attempt,
      requested: gaps.requested,
      missing: gaps.missing,
      extra: gaps.extra,
      outcome,
    }),
  );
}
