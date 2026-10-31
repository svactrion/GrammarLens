import { TOPICS, topicById } from './topics';
import { ProxyError, type Env } from './types';
import { logUpstreamFailure, upstreamErrorType, type UpstreamFailure } from './error_log';
import {
  DAILY_TEST_SYSTEM_PROMPT,
  GENERATION_SYSTEM_PROMPT,
  SCORING_SYSTEM_PROMPT,
  SHARED_CHECK_SYSTEM_PROMPT,
  SHARED_DAILY_TEST_SYSTEM_PROMPT_V2,
  SHARED_DAILY_TEST_SYSTEM_PROMPT_V3,
} from './prompts';
import { elapsedMs, logUsage, stopReasonField, tokenCount } from './usage_log';
import {
  GENERATOR_MODELS,
  type GenerateSharedDailyTestRequest,
  type GeneratorEffort,
} from './shared_daily_test';
import {
  CORRECT_ANSWER_VALUES,
  ORIGINAL_SENTENCE_VALUES,
  RULE_FIELD_VALUES,
  VERDICT_VALUES,
  type CheckSharedDailyTestRequest,
} from './shared_check';
import type {
  GenerateDailyTestRequest,
  GeneratePracticeSetRequest,
  ScoreAnswersRequest,
} from './validation';

const ENDPOINT = 'https://api.anthropic.com/v1/messages';
const MODEL = 'claude-sonnet-4-6';
const API_VERSION = '2023-06-01';
const TOPIC_IDS = TOPICS.map((t) => t.id);

/** Scaled off the 2048-token baseline tuned for a 5-item set (see the old
 * client-side ClaudeService, which this ports from). */
function maxTokensFor(count: number): number {
  return Math.min(8192, Math.max(1024, Math.ceil((2048 * count) / 5)));
}

/** Daily Test's own budget, scaled the same way off 3072 tokens for a 5-item
 * set. Its items carry an answer key, 2-3 predicted wrong answers with
 * comments and an explanation, so they run longer than practice items: 5
 * sampled 5-item sets (2026-09-24) used 1470-1632 output tokens, which left
 * only ~20% of the shared 2048 baseline. Kept separate so practice generation
 * is unaffected. */
export function dailyTestMaxTokensFor(count: number): number {
  return Math.min(8192, Math.max(1024, Math.ceil((3072 * count) / 5)));
}

/** Keeps a 2:2:1 sentence_writing : error_correction : fill_in_blank ratio at any count. */
function itemMix(count: number): string {
  const sentenceWriting = Math.round(count * 0.4);
  const errorCorrection = Math.round(count * 0.4);
  const fillInBlank = count - sentenceWriting - errorCorrection;
  return `${sentenceWriting} sentence_writing, ${errorCorrection} error_correction, and ${fillInBlank} fill_in_blank`;
}

/**
 * The same for every user: a varied general mix across all topics. Nothing
 * about the device or its history goes into the prompt, so the Daily Test
 * sends no user data to Anthropic.
 */
function dailyTestUserPrompt(count: number): string {
  const allTitles = TOPICS.map((t) => t.title).join(', ');
  return `Generate exactly ${count} Daily Test questions. Cover a varied general mix across these topics: ${allTitles}.`;
}

/** Upper bounds on the "do not reuse" list, so a long history can never grow
 * the prompt without limit (7 days x 5 answers is the intended size). */
const MAX_AVOID_ANSWERS = 35;
const MAX_AVOID_ANSWER_LENGTH = 100;

/**
 * The shared Daily Test's user prompt: the day's plan (topic order, each
 * slot's type, the scenario theme) and the correct answers of recent sets to
 * stay away from. Built only from the fixed topic table, the plan and
 * model-written answers, never from anything a user sent. Any change here is a
 * new prompt version (`SharedPromptVersion`).
 */
function sharedDailyTestUserPrompt(req: GenerateSharedDailyTestRequest): string {
  const slots = req.plan.slots
    .map((slot, i) => {
      const topic = topicById(slot.topicId);
      const title = topic ? `${topic.title} — ${topic.description}` : slot.topicId;
      return `${i + 1}. topicId "${slot.topicId}" (${title}): ${slot.type}`;
    })
    .join('\n');

  const avoid = [
    ...new Set(
      req.avoidAnswers
        .map((a) => a.trim().slice(0, MAX_AVOID_ANSWER_LENGTH))
        .filter((a) => a.length > 0),
    ),
  ].slice(0, MAX_AVOID_ANSWERS);

  const lines =
    req.candidatesPerSlot === 2
      ? [
          `Generate exactly ${req.count} Daily Test questions, two candidates for each slot below: both candidates of slot 1 first, then both of slot 2, and so on, each with exactly the topicId and type given:`,
          slots,
          `Today's scenario theme is "${req.plan.theme}": set every question in a different everyday situation within that theme.`,
          "The two candidates of a slot test the same topic in different situations. Only one of them will be used, so each must be complete on its own.",
        ]
      : [
          `Generate exactly ${req.count} Daily Test questions, one for each slot below, in this order, each with exactly the topicId and type given:`,
          slots,
          `Today's scenario theme is "${req.plan.theme}": set every question in a different everyday situation within that theme.`,
        ];
  if (req.promptVersion >= 2) {
    lines.push(
      "If a slot's type cannot be written for its topic in today's theme without breaking the correctness rules, keep the topic and type, and move the situation to a different part of the theme.",
    );
  }
  lines.push('Each "id" must be a short unique slug.');
  if (avoid.length > 0) {
    lines.push(
      `These answers were used on recent days. Do not reuse them, or the situations they came from: ${avoid
        .map((a) => JSON.stringify(a))
        .join(', ')}.`,
    );
  }
  return lines.join('\n');
}

export interface AnthropicRequestBody {
  model: string;
  max_tokens: number;
  system: string;
  /** Only on requests that use it, so every other request is byte-for-byte
   * what it always was. */
  thinking?: { type: 'adaptive' };
  /** `effort` only on requests that set one, like `thinking`. */
  output_config: { format: { type: 'json_schema'; schema: unknown }; effort?: GeneratorEffort };
  messages: { role: 'user'; content: string }[];
}

/**
 * Room for adaptive thinking on top of the answer's own budget. Thinking
 * tokens count against `max_tokens` and are billed as output, but only what is
 * generated is billed, so a generous ceiling costs nothing by itself; a tight
 * one would truncate the answer after a long think.
 */
export const THINKING_HEADROOM_TOKENS = 12_000;

function buildGeneratePracticeSetBody(req: GeneratePracticeSetRequest): AnthropicRequestBody {
  const topic = topicById(req.topicId);
  if (!topic) throw new ProxyError('invalid_request', 400, 'Unknown topicId.');

  const schema = {
    type: 'object',
    properties: {
      items: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            type: { type: 'string', enum: ['fill_in_blank', 'error_correction', 'sentence_writing'] },
            context: { type: 'string' },
            instruction: { type: 'string' },
            hint: { type: 'string' },
          },
          required: ['id', 'type', 'instruction'],
          additionalProperties: false,
        },
      },
    },
    required: ['items'],
    additionalProperties: false,
  };

  return {
    model: MODEL,
    max_tokens: maxTokensFor(req.count),
    system: GENERATION_SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema } },
    messages: [
      {
        role: 'user',
        content:
          `Topic: "${topic.title}" — ${topic.description}\n` +
          `Generate exactly ${req.count} fresh practice items: ${itemMix(req.count)}. Each "id" must be a short unique slug.`,
      },
    ],
  };
}

/** The Daily Test's structured-output schema, shared by the legacy
 * per-device set and the shared set so both stay parseable by the same
 * `DailyTestQuestion.fromJson`. Changing it changes the legacy route too,
 * which `test/index.test.ts` pins byte for byte. */
function dailyTestSchema() {
  return {
    type: 'object',
    properties: {
      questions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            type: { type: 'string', enum: ['fill_in_blank', 'error_correction'] },
            context: { type: 'string' },
            instruction: { type: 'string' },
            hint: { type: 'string' },
            topicId: { type: 'string', enum: TOPIC_IDS },
            correctAnswer: { type: 'string' },
            explanation: { type: 'string' },
            commonWrongAnswers: {
              type: 'array',
              items: {
                type: 'object',
                properties: { answer: { type: 'string' }, comment: { type: 'string' } },
                required: ['answer', 'comment'],
                additionalProperties: false,
              },
            },
          },
          required: [
            'id',
            'type',
            'instruction',
            'topicId',
            'correctAnswer',
            'explanation',
            'commonWrongAnswers',
          ],
          additionalProperties: false,
        },
      },
    },
    required: ['questions'],
    additionalProperties: false,
  };
}

/**
 * Prompt version 2's schema: the Daily Test schema with each question one of
 * two shapes, told apart by `type` (`const`), so that an `error_correction`
 * question must carry "context", where its flawed sentence goes. The
 * structured outputs grammar supports `anyOf` and `const` but no `minLength`,
 * so an empty "context" still parses; `validateSharedSet` rejects it
 * (`error_correction_missing_sentence`). Version 1 and the legacy route keep
 * `dailyTestSchema()` unchanged.
 */
function sharedDailyTestSchemaV2() {
  const base = dailyTestSchema();
  const item = base.properties.questions.items;
  const shape = (type: 'fill_in_blank' | 'error_correction', required: readonly string[]) => ({
    ...item,
    properties: { ...item.properties, type: { type: 'string', const: type } },
    required: [...required],
  });
  return {
    ...base,
    properties: {
      questions: {
        type: 'array',
        items: {
          anyOf: [
            shape('fill_in_blank', item.required),
            shape('error_correction', [...item.required.slice(0, 2), 'context', ...item.required.slice(2)]),
          ],
        },
      },
    },
  };
}

function buildGenerateDailyTestBody(req: GenerateDailyTestRequest): AnthropicRequestBody {
  return {
    model: MODEL,
    max_tokens: dailyTestMaxTokensFor(req.count),
    system: DAILY_TEST_SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema: dailyTestSchema() } },
    messages: [{ role: 'user', content: dailyTestUserPrompt(req.count) }],
  };
}

/**
 * The shared set reuses the legacy Daily Test's schema and token budget (their
 * output was measured on 2026-09-24); the user prompt carries the day's plan.
 * Version 1 also reuses the legacy system prompt; version 2 has its own
 * (`SHARED_DAILY_TEST_SYSTEM_PROMPT_V2`). The model is the request's own
 * (`SHARED_GENERATOR` by default); how each model is asked (thinking, and so
 * `THINKING_HEADROOM_TOKENS` more) comes from `GENERATOR_MODELS`, and an
 * `effort` is sent only when the request has one. Exported for tests.
 */
export function buildGenerateSharedDailyTestBody(req: GenerateSharedDailyTestRequest): AnthropicRequestBody {
  const thinks = GENERATOR_MODELS[req.model].adaptiveThinking;
  return {
    model: req.model,
    max_tokens: dailyTestMaxTokensFor(req.count) + (thinks ? THINKING_HEADROOM_TOKENS : 0),
    system:
      req.promptVersion === 3
        ? SHARED_DAILY_TEST_SYSTEM_PROMPT_V3
        : req.promptVersion === 2
          ? SHARED_DAILY_TEST_SYSTEM_PROMPT_V2
          : DAILY_TEST_SYSTEM_PROMPT,
    ...(thinks ? { thinking: { type: 'adaptive' as const } } : {}),
    output_config: {
      format: { type: 'json_schema', schema: req.promptVersion >= 2 ? sharedDailyTestSchemaV2() : dailyTestSchema() },
      ...(req.effort ? { effort: req.effort } : {}),
    },
    messages: [{ role: 'user', content: sharedDailyTestUserPrompt(req) }],
  };
}

function sharedCheckSchema() {
  return {
    type: 'object',
    properties: {
      questions: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            id: { type: 'string' },
            originalSentence: { type: 'string', enum: [...ORIGINAL_SENTENCE_VALUES] },
            correctAnswer: { type: 'string', enum: [...CORRECT_ANSWER_VALUES] },
            acceptableAlternatives: { type: 'array', items: { type: 'string' } },
            acceptableWrongAnswers: { type: 'array', items: { type: 'string' } },
            incorrectRuleFields: { type: 'array', items: { type: 'string', enum: [...RULE_FIELD_VALUES] } },
            explanationExcludesAlternatives: { type: 'boolean' },
            verdict: { type: 'string', enum: [...VERDICT_VALUES] },
          },
          required: [
            'id',
            'originalSentence',
            'correctAnswer',
            'acceptableAlternatives',
            'acceptableWrongAnswers',
            'incorrectRuleFields',
            'explanationExcludesAlternatives',
            'verdict',
          ],
          additionalProperties: false,
        },
      },
    },
    required: ['questions'],
    additionalProperties: false,
  };
}

/** The review's own share of `max_tokens`, per question (a review is ~100-150
 * tokens; the rest of the budget is thinking). */
const CHECK_TOKENS_PER_QUESTION = 400;

/**
 * The check request: every checker candidate runs with adaptive thinking, and
 * sees the questions exactly as a learner would, plus the key, the predicted
 * wrong answers and the explanation; never `acceptedAnswers` (the check is what
 * adds them). Exported for tests and the local measurement E.
 */
export function buildCheckSharedDailyTestBody(req: CheckSharedDailyTestRequest): AnthropicRequestBody {
  const questions = req.questions.map((q) => ({
    id: q.id,
    type: q.type,
    topicId: q.topicId,
    ...(q.context === undefined ? {} : { context: q.context }),
    instruction: q.instruction,
    ...(q.hint === undefined ? {} : { hint: q.hint }),
    correctAnswer: q.correctAnswer,
    commonWrongAnswers: q.commonWrongAnswers.map((w) => ({ answer: w.answer, comment: w.comment })),
    explanation: q.explanation,
  }));
  return {
    model: req.model,
    max_tokens: Math.max(2048, CHECK_TOKENS_PER_QUESTION * req.count) + THINKING_HEADROOM_TOKENS,
    system: SHARED_CHECK_SYSTEM_PROMPT,
    thinking: { type: 'adaptive' },
    output_config: { format: { type: 'json_schema', schema: sharedCheckSchema() } },
    messages: [
      {
        role: 'user',
        content: `Review these ${req.count} questions:\n${JSON.stringify({ questions })}`,
      },
    ],
  };
}

/**
 * Scoring's output budget. 2,048 fitted ≈ 140 output tokens per item for up
 * to 10 items; the structured fields of 1.4.0 D11 (one note per blank plus a
 * summary) take ≈ 220 per item, so the budget scales with the count: 400 per
 * item, never under the old 2,048, capped like the generators. Only what is
 * generated is billed.
 */
export function scoreMaxTokensFor(count: number): number {
  return Math.min(8192, Math.max(2048, 400 * count));
}

/**
 * Scoring's structured-output schema. The first six fields are what every
 * client has read since 1.0.0; `summary` and `blanks` were added by 1.4.0 D11
 * (docs/1.4.0-server-batch0-report.md §4.1–4.2) as required here, so the
 * model always writes them, and additive for the client, which treats them
 * as optional. `src/score_feedback.ts` checks them against the request before
 * they go out.
 */
function buildScoreAnswersBody(req: ScoreAnswersRequest): AnthropicRequestBody {
  const schema = {
    type: 'object',
    properties: {
      feedback: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            itemId: { type: 'string' },
            isCorrect: { type: 'boolean' },
            errorType: { type: 'string' },
            rule: { type: 'string' },
            correctedAnswer: { type: 'string' },
            explanation: { type: 'string' },
            summary: { type: 'string' },
            blanks: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  index: { type: 'integer' },
                  correctAnswer: { type: 'string' },
                  accepted: { type: 'boolean' },
                  note: { type: 'string' },
                },
                required: ['index', 'correctAnswer', 'accepted', 'note'],
                additionalProperties: false,
              },
            },
          },
          required: ['itemId', 'isCorrect', 'correctedAnswer', 'explanation', 'summary', 'blanks'],
          additionalProperties: false,
        },
      },
    },
    required: ['feedback'],
    additionalProperties: false,
  };

  const itemsPayload = req.items.map((item) => ({
    id: item.id,
    type: item.type,
    prompt: item.prompt,
    userAnswer: item.userAnswer,
  }));

  return {
    model: MODEL,
    max_tokens: scoreMaxTokensFor(req.items.length),
    system: SCORING_SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema } },
    messages: [{ role: 'user', content: JSON.stringify({ items: itemsPayload }) }],
  };
}

export type AnthropicOperation =
  | { op: 'generate_practice_set'; request: GeneratePracticeSetRequest }
  | { op: 'generate_daily_test'; request: GenerateDailyTestRequest }
  | { op: 'generate_shared_daily_test'; request: GenerateSharedDailyTestRequest }
  | { op: 'check_shared_daily_test'; request: CheckSharedDailyTestRequest }
  | { op: 'score_answers'; request: ScoreAnswersRequest };

/** The exact request body an operation sends. Exported for the local
 * measurement E, which submits the same bodies through the Batches API. */
export function buildBody(operation: AnthropicOperation): AnthropicRequestBody {
  switch (operation.op) {
    case 'generate_practice_set':
      return buildGeneratePracticeSetBody(operation.request);
    case 'generate_daily_test':
      return buildGenerateDailyTestBody(operation.request);
    case 'generate_shared_daily_test':
      return buildGenerateSharedDailyTestBody(operation.request);
    case 'check_shared_daily_test':
      return buildCheckSharedDailyTestBody(operation.request);
    case 'score_answers':
      return buildScoreAnswersBody(operation.request);
  }
}

/**
 * What one call cost and how it ended, for a caller that must report it in its
 * own log line (the shared-set cron). Only numbers and fixed vocabularies, the
 * same fields `logUsage` / `logUpstreamFailure` already write; never content.
 * Fields stay undefined when the call never got that far (no tokens for a call
 * that got no answer).
 */
export interface CallMeta {
  durationMs?: number;
  inputTokens?: number | null;
  outputTokens?: number | null;
  stopReason?: string | null;
  failure?: UpstreamFailure;
}

export interface CallOptions {
  /** Aborts the request to Anthropic; an abort is logged as `timeout`. */
  signal?: AbortSignal;
  /** Filled in as the call goes, success or failure. */
  meta?: CallMeta;
}

/**
 * Calls Anthropic for the given operation and returns the already-parsed,
 * schema-shaped JSON object (e.g. `{ items: [...] }`) — never Anthropic's
 * raw response envelope, and never its raw error body on failure (that's
 * an explicit requirement, not an oversight: a client must never see
 * Anthropic's own error text, which can carry implementation detail that
 * isn't ours to expose).
 */
export async function callAnthropic(
  env: Env,
  operation: AnthropicOperation,
  options: CallOptions = {},
): Promise<unknown> {
  const body = buildBody(operation);
  const { signal, meta } = options;

  function failed(
    failure: UpstreamFailure,
    details: { httpStatus?: number; errorType?: string; durationMs: number },
  ): void {
    logUpstreamFailure(operation, failure, details);
    if (meta) {
      meta.failure = failure;
      meta.durationMs = details.durationMs;
    }
  }

  // Timing covers only the wait on Anthropic (not validation or the quota
  // check), which is the part whose duration the Daily Test's load time
  // depends on. See `logUsage` for what may be logged.
  const startedAt = Date.now();
  let response: Response;
  try {
    response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': env.ANTHROPIC_API_KEY,
        'anthropic-version': API_VERSION,
      },
      body: JSON.stringify(body),
      // Only set when a caller asked for it, so the request of a call without
      // one is exactly what it always was.
      ...(signal ? { signal } : {}),
    });
  } catch {
    // No exception object is logged: its message can carry request text.
    failed(signal?.aborted ? 'timeout' : 'network_error', { durationMs: elapsedMs(startedAt) });
    throw new ProxyError('upstream_error', 502, 'Could not reach the upstream service.');
  }

  if (response.status !== 200) {
    // Logged server-side only (visible via `wrangler tail`) and never
    // forwarded to the client. Only the status and Anthropic's error type are
    // kept; the body itself can echo request or response text, so it is read
    // for that one whitelisted field and then dropped.
    let errorType = 'unknown';
    try {
      errorType = upstreamErrorType(await response.text());
    } catch {
      // Body unreadable: the status alone is logged.
    }
    failed('http_error', {
      httpStatus: response.status,
      errorType,
      durationMs: elapsedMs(startedAt),
    });
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an error.');
  }

  let decoded: { content?: { type: string; text?: string }[]; usage?: unknown; stop_reason?: unknown };
  try {
    decoded = (await response.json()) as typeof decoded;
  } catch {
    failed(signal?.aborted ? 'timeout' : 'unreadable_body', {
      httpStatus: response.status,
      durationMs: elapsedMs(startedAt),
    });
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an unexpected response.');
  }
  // Logged before the content is checked: a response that later fails to
  // parse was still billed, and that cost belongs in the measurement.
  const billedMs = elapsedMs(startedAt);
  logUsage(operation, decoded.usage, billedMs, decoded.stop_reason);
  if (meta) {
    const usage =
      typeof decoded.usage === 'object' && decoded.usage !== null ? (decoded.usage as Record<string, unknown>) : {};
    meta.durationMs = billedMs;
    meta.inputTokens = tokenCount(usage.input_tokens);
    meta.outputTokens = tokenCount(usage.output_tokens);
    meta.stopReason = stopReasonField(decoded.stop_reason);
  }
  const textBlock = decoded.content?.find((block) => block.type === 'text');
  if (!textBlock?.text) {
    failed('no_text_block', {
      httpStatus: response.status,
      durationMs: elapsedMs(startedAt),
    });
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an unexpected response.');
  }

  try {
    return JSON.parse(textBlock.text);
  } catch {
    // The parse exception's message quotes the start of the model's text
    // (which can contain the user's own words), so it is not logged.
    failed('invalid_json_content', {
      httpStatus: response.status,
      durationMs: elapsedMs(startedAt),
    });
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an unexpected response.');
  }
}
