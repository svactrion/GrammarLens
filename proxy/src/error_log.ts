import type { AnthropicOperation } from './anthropic';
import { durationField, usageKind } from './usage_log';

/** What went wrong with an upstream (Anthropic) call, as a fixed vocabulary. */
export type UpstreamFailure =
  | 'network_error' // the request never got a response
  | 'timeout' // the caller's abort signal fired first (the shared-set cron only)
  | 'http_error' // a non-200 response
  | 'unreadable_body' // a 200 whose body was not JSON
  | 'no_text_block' // a 200 without a text content block
  | 'invalid_json_content'; // the text block was not valid JSON

/** Anthropic's documented error `type` values. Anything else is logged as
 * `unknown`, so a value can only ever come from this list, never from text
 * the upstream (or a user) supplied. */
const KNOWN_UPSTREAM_ERROR_TYPES: ReadonlySet<string> = new Set([
  'invalid_request_error',
  'authentication_error',
  'billing_error',
  'permission_error',
  'not_found_error',
  'request_too_large',
  'rate_limit_error',
  'timeout_error',
  'api_error',
  'overloaded_error',
]);

/**
 * Reads only `error.type` out of an Anthropic error body and returns it if it
 * is a known value; the rest of the body is never kept. Unparseable or
 * unexpected bodies give `unknown`. The body may echo request or response
 * text, which is why nothing else from it is used.
 */
export function upstreamErrorType(bodyText: string): string {
  try {
    const parsed: unknown = JSON.parse(bodyText);
    const type = (parsed as { error?: { type?: unknown } } | null)?.error?.type;
    return typeof type === 'string' && KNOWN_UPSTREAM_ERROR_TYPES.has(type) ? type : 'unknown';
  } catch {
    return 'unknown';
  }
}

/**
 * Writes one line to the Workers log stream for a failed Anthropic call.
 *
 * PRIVACY CONTRACT — only the fields built below are ever logged: the
 * operation, its kind, the failure category, the HTTP status, a whitelisted
 * Anthropic error type and how long the call had been running (`duration_ms`,
 * a number, so a hang or a slow timeout shows up next to the successes). Never the upstream response body or any exception
 * object/message (both can carry text from the request or the response), and
 * never anything from the request. Do not add fields without keeping that true.
 */
export function logUpstreamFailure(
  operation: AnthropicOperation,
  failure: UpstreamFailure,
  details: { httpStatus?: number; errorType?: string; durationMs?: number } = {},
): void {
  console.error(
    JSON.stringify({
      event: 'anthropic_failure',
      kind: usageKind(operation.op),
      operation: operation.op,
      failure,
      http_status: details.httpStatus ?? null,
      upstream_error_type: details.errorType ?? null,
      duration_ms: durationField(details.durationMs),
    }),
  );
}

/** Built-in error class names that are safe to log as-is. Anything else (a
 * custom class, a thrown string or object) is categorized, never echoed. */
const KNOWN_ERROR_NAMES: ReadonlySet<string> = new Set([
  'Error',
  'TypeError',
  'RangeError',
  'SyntaxError',
  'ReferenceError',
  'EvalError',
  'URIError',
]);

/** Category of an unexpected error: a built-in error name, `other_error` for
 * any other Error, or `non_error` for something that was not an Error at all. */
export function errorCategory(e: unknown): string {
  if (!(e instanceof Error)) return 'non_error';
  return KNOWN_ERROR_NAMES.has(e.name) ? e.name : 'other_error';
}

/**
 * Writes one line for an error nothing else handled (the catch-all in
 * `index.ts`): the operation, its kind and the error's category.
 *
 * PRIVACY CONTRACT — never the error's message, stack or cause, and never
 * anything from the request: an unexpected error's message can quote request
 * or response text. Only the fields built below are logged.
 */
export function logUnhandledError(op: AnthropicOperation['op'], e: unknown): void {
  console.error(
    JSON.stringify({
      event: 'unhandled_error',
      kind: usageKind(op),
      operation: op,
      error: errorCategory(e),
    }),
  );
}
