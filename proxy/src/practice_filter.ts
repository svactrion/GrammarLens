import { blankCount } from './shared_daily_test';

/**
 * The guard on the practice route (owner decision 2026-11-19, phase C3 of
 * docs/TOPICS.md). A `fill_in_blank` item with no blank cannot be answered
 * as meant: the app shows it with one short box and nothing marks where the
 * answer goes. Nothing on the practice path stopped such an item (the
 * schema cannot require a blank), and the topics measurement met them: 1 in
 * 33 sets in the first run, 3 in 6 in the Conditionals re-measurement.
 *
 * The response is filtered, never the request: an item of type
 * `fill_in_blank` whose "context" and "instruction" hold no blank (a run of
 * two or more underscores, the app's rule) is removed and the rest is
 * served, so such a set arrives a question short. Only when nothing at all
 * would be left is the response rejected: the app cannot show an empty set.
 * A response the check does not touch is served as it always was, the same
 * object.
 */

export interface PracticeFilterResult {
  /** What to serve: the model's response, without the removed items. */
  content: unknown;
  /** Items in the response; null when it has no `items` array. */
  received: number | null;
  /** fill_in_blank items without a blank that were removed. */
  removed: number;
  /** Items served; 0 when rejected; null when there is no `items` array. */
  served: number | null;
  /** Nothing was left to serve: the caller answers with an upstream error. */
  rejected: boolean;
}

function isBlanklessFillIn(entry: unknown): boolean {
  if (typeof entry !== 'object' || entry === null || Array.isArray(entry)) return false;
  const item = entry as Record<string, unknown>;
  return item.type === 'fill_in_blank' && blankCount(item.context, item.instruction) === 0;
}

export function filterPracticeSet(content: unknown): PracticeFilterResult {
  const items = (content as { items?: unknown } | null)?.items;
  if (typeof content !== 'object' || content === null || !Array.isArray(items)) {
    return { content, received: null, removed: 0, served: null, rejected: false };
  }
  const kept = items.filter((entry) => !isBlanklessFillIn(entry));
  const removed = items.length - kept.length;
  if (removed === 0) return { content, received: items.length, removed: 0, served: items.length, rejected: false };
  const rejected = kept.length === 0;
  return {
    content: { ...(content as Record<string, unknown>), items: kept },
    received: items.length,
    removed,
    served: rejected ? 0 : kept.length,
    rejected,
  };
}

/**
 * One line per practice response that has an `items` array, so the rate of
 * blank-less items on the live path can be read from the logs.
 *
 * PRIVACY CONTRACT — only the fields built below: the event and counts.
 * Never an item, a topic, a device id or any text of the response.
 */
export function logPracticeFilter(result: PracticeFilterResult): void {
  if (result.received === null) return;
  console.log(
    JSON.stringify({
      event: 'practice_filter',
      received: result.received,
      removed: result.removed,
      served: result.served,
      rejected: result.rejected,
    }),
  );
}
