import type { ScoreAnswersRequest } from './validation';

/**
 * The structured scoring fields of 1.4.0 D11 (`summary`, `blanks`;
 * docs/1.4.0-server-batch0-report.md §4.2), checked against the request
 * before the response goes to the app. The schema guarantees the shape; what
 * it cannot guarantee is that the model counted the blanks the way the app
 * does, or kept `isCorrect` consistent with the entries. Both are repaired
 * here, deterministically, so the client's rule (a verdict per blank, correct
 * only when every blank is accepted) never meets a response that contradicts
 * it. The six fields every client has read since 1.0.0 are never touched
 * except `isCorrect`, and that only to agree with the model's own entries.
 */

/** A blank in a prompt: a run of two or more underscores, the app's rule
 * (`lib/utils/blanks.dart`, `blankCount` in `shared_daily_test.ts`). */
const BLANK = /_{2,}/g;

/** How many `blanks` entries an item's prompt calls for: one per blank of a
 * fill_in_blank prompt, else one (a blank-less fill-in, an error correction,
 * a sentence). */
export function expectedBlankEntries(type: string, prompt: string): number {
  if (type !== 'fill_in_blank') return 1;
  return Math.max(1, prompt.match(BLANK)?.length ?? 0);
}

export interface ScoreFeedbackCheck {
  /** The response to send: the model's, with the repairs applied. */
  content: unknown;
  /** Items whose `blanks` and `summary` were removed (count mismatch, bad
   * indexes): the client renders the paragraph for them. */
  structuredDropped: number;
  /** Items whose `isCorrect` was set to the entries' verdict. */
  verdictReconciled: number;
  /** Items the model answered. */
  items: number;
}

function isEntry(value: unknown): value is { index: number; correctAnswer: string; accepted: boolean; note: string } {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) return false;
  const e = value as Record<string, unknown>;
  return (
    typeof e.index === 'number' &&
    Number.isInteger(e.index) &&
    typeof e.correctAnswer === 'string' &&
    typeof e.accepted === 'boolean' &&
    typeof e.note === 'string'
  );
}

/**
 * Per item: `blanks` must have exactly [expectedBlankEntries] well-formed
 * entries indexed 0 … n − 1 in order, else `blanks` and `summary` are removed;
 * then `isCorrect` is made to agree with `every(accepted)`. An item the
 * request does not know, or a response that is not `{feedback: [...]}`, is
 * passed through unchanged (the client's own parsing decides).
 */
export function checkScoreFeedback(request: ScoreAnswersRequest, content: unknown): ScoreFeedbackCheck {
  if (typeof content !== 'object' || content === null || Array.isArray(content)) {
    return { content, structuredDropped: 0, verdictReconciled: 0, items: 0 };
  }
  const feedback = (content as Record<string, unknown>).feedback;
  if (!Array.isArray(feedback)) return { content, structuredDropped: 0, verdictReconciled: 0, items: 0 };

  const byId = new Map(request.items.map((item) => [item.id, item]));
  let structuredDropped = 0;
  let verdictReconciled = 0;
  const repaired = feedback.map((raw) => {
    if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return raw;
    const item = { ...(raw as Record<string, unknown>) };
    const requested = typeof item.itemId === 'string' ? byId.get(item.itemId) : undefined;
    if (!requested) return raw;
    const blanks = item.blanks;
    const expected = expectedBlankEntries(requested.type, requested.prompt);
    const wellFormed =
      Array.isArray(blanks) && blanks.length === expected && blanks.every((e, i) => isEntry(e) && e.index === i);
    if (!wellFormed) {
      if (blanks !== undefined || item.summary !== undefined) structuredDropped++;
      delete item.blanks;
      delete item.summary;
      return item;
    }
    const verdict = (blanks as { accepted: boolean }[]).every((e) => e.accepted);
    if (item.isCorrect !== verdict) {
      item.isCorrect = verdict;
      verdictReconciled++;
    }
    return item;
  });
  return { content: { ...(content as Record<string, unknown>), feedback: repaired }, structuredDropped, verdictReconciled, items: repaired.length };
}

/**
 * PRIVACY CONTRACT — counts only: how many items the model answered, how many
 * lost their structured fields, how many had their verdict reconciled. Never
 * an item id, a prompt, an answer or a note.
 */
export function logScoreFeedback(check: ScoreFeedbackCheck): void {
  console.log(
    JSON.stringify({
      event: 'score_feedback',
      items: check.items,
      structured_dropped: check.structuredDropped,
      verdict_reconciled: check.verdictReconciled,
    }),
  );
}
