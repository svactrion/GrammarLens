import type { AnthropicOperation } from './anthropic';

/** The two cost centres the unit economics care about. `generate_practice_set`
 * and `score_answers` are the two calls of one Topic Practice session. */
export type UsageKind = 'daily_test' | 'topic_practice';

export function usageKind(op: AnthropicOperation['op']): UsageKind {
  return op === 'generate_daily_test' ? 'daily_test' : 'topic_practice';
}

/** How many questions the call covered — a request size, never its content. */
function itemCount(operation: AnthropicOperation): number {
  return operation.op === 'score_answers' ? operation.request.items.length : operation.request.count;
}

/** Whole milliseconds since [startedAt] (a `Date.now()` reading). In Workers
 * the clock only advances across I/O, which is exactly what is measured here:
 * the wait on Anthropic. */
export function elapsedMs(startedAt: number): number {
  return Math.max(0, Math.round(Date.now() - startedAt));
}

/** A duration, or null if the caller did not have a usable one. */
export function durationField(value: number | undefined): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? Math.round(value) : null;
}

function tokenCount(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
}

/**
 * Writes one line per Anthropic call to the Workers log stream (Workers Logs
 * / `wrangler tail`), so real per-operation token cost can be measured.
 *
 * PRIVACY CONTRACT — this line may contain only the fields built below:
 * operation names, a question count, two token counts and how long the call
 * took (`duration_ms`, wall time from just before the request to Anthropic
 * until its body was read, so the real cost of a Daily Test in seconds can be
 * measured). All are names or numbers. It must never be extended with anything
 * from the request (deviceId, prompts, questions, answers) or the response
 * (generated text). The fields are assembled explicitly from `operation.op`,
 * the numeric `usage` fields and the caller's timing for exactly that reason:
 * nothing is spread or stringified from a wider object. `usage` is the only
 * part of Anthropic's response read here.
 */
export function logUsage(operation: AnthropicOperation, usage: unknown, durationMs?: number): void {
  const raw = typeof usage === 'object' && usage !== null ? (usage as Record<string, unknown>) : {};
  console.log(
    JSON.stringify({
      event: 'anthropic_usage',
      kind: usageKind(operation.op),
      operation: operation.op,
      item_count: itemCount(operation),
      input_tokens: tokenCount(raw.input_tokens),
      output_tokens: tokenCount(raw.output_tokens),
      duration_ms: durationField(durationMs),
    }),
  );
}
