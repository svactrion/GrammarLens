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

function tokenCount(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
}

/**
 * Writes one line per Anthropic call to the Workers log stream (Workers Logs
 * / `wrangler tail`), so real per-operation token cost can be measured.
 *
 * PRIVACY CONTRACT — this line may contain only the fields built below:
 * operation names, a question count and two token counts. It must never be
 * extended with anything from the request (deviceId, prompts, questions,
 * answers, weak spots) or the response (generated text). The fields are
 * assembled explicitly from `operation.op` and the numeric `usage` fields
 * for exactly that reason: nothing is spread or stringified from a wider
 * object. `usage` is the only part of Anthropic's response read here.
 */
export function logUsage(operation: AnthropicOperation, usage: unknown): void {
  const raw = typeof usage === 'object' && usage !== null ? (usage as Record<string, unknown>) : {};
  console.log(
    JSON.stringify({
      event: 'anthropic_usage',
      kind: usageKind(operation.op),
      operation: operation.op,
      item_count: itemCount(operation),
      input_tokens: tokenCount(raw.input_tokens),
      output_tokens: tokenCount(raw.output_tokens),
    }),
  );
}
