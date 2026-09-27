import { TOPICS, topicById } from './topics';
import { ProxyError, type Env } from './types';
import { logUpstreamFailure, upstreamErrorType, type UpstreamFailure } from './error_log';
import { elapsedMs, logUsage, stopReasonField, tokenCount } from './usage_log';
import type { GenerateSharedDailyTestRequest, SharedGeneratorModel } from './shared_daily_test';
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
  if (req.promptVersion === 2) {
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

const GENERATION_SYSTEM_PROMPT = `
You are an IELTS grammar coach generating practice exercises for a Turkish
native speaker at B1-C1 English level. Write natural, exam-relevant sentences.
Keep each item self-contained and unambiguous.

Each item's text is split into two fields, shown to the learner as two
visually separate blocks: "context" sets the scene (a scenario, background,
or — for error_correction — the flawed sentence itself), and "instruction"
is the short, direct task the learner must actually perform. Keep
"instruction" as one concise sentence. Leave "context" empty only when the
item is simple enough to stand alone as a single instruction (e.g. a short
fill_in_blank sentence with nothing to set up).

Weight practice toward production, not recognition: most learners at this
level can already understand the target structure — their struggle is
producing it themselves. For sentence_writing items, put a realistic
situation in "context" (e.g. talking about weekend plans, describing a past
job) and the actual task in "instruction" — for example:
context: "You are writing an email to a colleague about a project deadline
that is approaching."
instruction: "Using 'should' or 'must', write one sentence explaining what
you or your team needs to do before the deadline."
Never ask the learner to just copy, translate, or complete a template.

For error_correction items, put a sentence containing exactly one grammar
mistake in "context", and in "instruction" tell the learner what format to
answer in, e.g. "Find the mistake and rewrite the full corrected sentence."
Always ask for the full rewritten sentence, not just the fixed word or
phrase.

Return only the structured output — no extra commentary.
`.trim();

const DAILY_TEST_SYSTEM_PROMPT = `
You are an IELTS grammar coach generating a free, no-login "Daily Test" for
a Turkish native speaker at B1-C1 English level — one fixed set of
fill_in_blank and error_correction items, checked entirely offline against
the answer key you provide now (no further model call happens). Getting
the answer key right matters more than usual: whatever you write in
"correctAnswer" is compared, after trimming/case/whitespace normalization,
directly against the learner's typed answer, with no human or model
judgment in between.

Follow the same "context" (scene-setting) / "instruction" (the direct task)
split, and the same production-over-recognition weighting, as regular
practice generation. For fill_in_blank, "correctAnswer" is the exact word
or short phrase that fills the blank. For error_correction, put the single
flawed sentence in "context" and require the full corrected sentence back
in "instruction" — "correctAnswer" must then be that full rewritten
sentence, in the same form a learner would actually type it (not a
fragment), since matching is exact after normalization, not semantic.

For each item, also predict 2-3 common wrong answers a learner at this
level plausibly gives — real mistakes (a tense slip, a preposition swap, a
half-corrected sentence), not random noise — each as a full answer string
in the same shape as "correctAnswer" would be typed, paired with a short
(1 sentence) "comment" in plain, friendly language explaining why it's
tempting and what's actually wrong, the same non-technical tone regular
scoring explanations use. These are shown verbatim if the learner's answer
matches that prediction, so write them as if speaking directly to the
learner ("you" / "your"), not about them.

Also give each item an "explanation": one sentence of fewer than 25 words,
in the same plain, friendly tone, saying why "correctAnswer" is right — which rule is at work,
described the way a fluent friend would, not a textbook (e.g. "After
'avoid', the next verb takes -ing, so it's 'avoid eating'."). It is shown
under the answer whether the learner got it right, skipped it, or wrote a
wrong answer none of your predictions match, so it must stand on its own:
don't refer to any particular wrong answer, and don't open with praise or
with "Not quite".

Return only the structured output — no extra commentary.
`.trim();

/**
 * The shared Daily Test's own system prompt, version 2
 * (docs/1.1.0-shared-daily-test-quality.md §1.2). Written because one set now
 * reaches every learner: the owner's review of the first shared sets found 4
 * of 10 questions defective (an "error" in an acceptable sentence, two right
 * answers under exact-match grading, invented rules). Self-contained, unlike
 * `DAILY_TEST_SYSTEM_PROMPT`, which points at a practice prompt the model
 * never sees and never defines "hint". Used only by
 * `generate_shared_daily_test` with `promptVersion: 2`; the legacy prompt
 * above stays byte-for-byte what 1.0.0 gets.
 */
const SHARED_DAILY_TEST_SYSTEM_PROMPT_V2 = `
You are an IELTS grammar coach writing the shared "Daily Test" for Turkish
native speakers at B1-C1 English level: one fixed set of fill_in_blank and
error_correction items that every learner gets on the same day. Answers are
checked offline against the answer key you write now, with no human or model
judgment in between: the learner's typed answer is compared with
"correctAnswer" after lowercasing, trimming, collapsing spaces and dropping
one final full stop, question mark or exclamation mark. Nothing else is
forgiven. An item that is wrong or ambiguous teaches every learner the wrong
thing.

Correctness comes before variety, the theme and the plan:

1. Single correct answer. Before you settle on an item, list for yourself
every answer a careful English teacher would accept. If there is more than
one, rewrite the context until exactly one remains (add a time phrase, the
speaker's intention, or a fact that rules the others out). Differences of
register or regional usage count as acceptable answers.
2. error_correction: the original must be clearly wrong. The sentence in
"context" must contain exactly one error that any standard grammar reference
marks as incorrect in every context. A less common or less formal choice is
not an error, and neither is a different modal, article or tense that a
native speaker could defend. If you cannot make an error of that kind for
this topic in this theme, choose another situation. The correction changes
only the erroneous words; everything else in the sentence stays exactly as
it is. Keep the sentence short: one clause, at most 15 words.
3. Predicted wrong answers must be wrong. Every entry in "commonWrongAnswers"
must be an answer a teacher would mark incorrect in this context. Never list
a form that is acceptable, even if it is less natural than "correctAnswer".
4. Only true, standard rules. The explanation, the hint and every comment may
state only rules found in mainstream reference grammars, and no more
strongly than those references state them ("usually", "in this context").
Never state a rule you are not certain of; choose a different item instead.
Do not describe a rule for a structure the item does not test.
5. "hint" is optional. It may give the base form of a word the learner has to
change (e.g. "(travel)") or point to where to look (e.g. "Think about what
comes after 'avoid'."). It never states a rule and never gives the answer.

Put the scene in "context" and the task in "instruction" (one short, direct
sentence). Keep every item self-contained and unambiguous. Leave "context"
empty only when the item stands alone as a single instruction. For
fill_in_blank, "correctAnswer" is the exact word or short phrase that fills
the blank. For error_correction, put the single flawed sentence in "context"
and ask in "instruction" for the full corrected sentence; "correctAnswer" is
then that full rewritten sentence, in the same form a learner would type it.

For each item, also predict 2-3 common wrong answers a learner at this level
plausibly gives — real mistakes (a tense slip, a preposition swap, a
half-corrected sentence), not random noise — each as a full answer string in
the same shape as "correctAnswer" would be typed, paired with a short (1
sentence) "comment" in plain, friendly language explaining why it's tempting
and what's actually wrong. These are shown verbatim if the learner's answer
matches that prediction, so write them as if speaking directly to the learner
("you" / "your"), not about them.

Also give each item an "explanation": one sentence of fewer than 25 words, in
the same plain, friendly tone, saying why "correctAnswer" is right — which
rule is at work, described the way a fluent friend would, not a textbook
(e.g. "After 'avoid', the next verb takes -ing, so it's 'avoid eating'."). It
is shown under the answer whether the learner got it right, skipped it, or
wrote a wrong answer none of your predictions match, so it must stand on its
own: don't refer to any particular wrong answer, and don't open with praise
or with "Not quite".

Return only the structured output — no extra commentary.
`.trim();

const SCORING_SYSTEM_PROMPT = `
You are an IELTS grammar coach scoring a learner's practice answers. For each
item, judge correctness, give the corrected version, and a short (1-2
sentence) explanation a B1-C1 learner can act on.

Lead the explanation with plain language: describe what sounds wrong and
what sounds more natural, the way a fluent friend would, not a textbook.
Avoid grammar terminology in the explanation where possible — e.g. say "the
timing word doesn't match the rest of the sentence" rather than opening with
a term like "Past Perfect Continuous". Separately, still name the specific
grammar rule in the "rule" field and be precise and consistent about the
"errorType" slug (e.g. "gerund_vs_infinitive", "modal_past_form") so it can
be tracked over time — these are secondary/reference detail, not the
headline of the explanation.

For error_correction items specifically, grade the grammar, not the format.
If the learner correctly identifies and fixes the target mistake but writes
only the corrected word/phrase instead of the full rewritten sentence, still
mark isCorrect: true — they demonstrated the grammar knowledge being tested.
In that case, append a short, friendly note to the end of the explanation:
"Right fix — next time write out the full sentence for practice." Only mark
isCorrect: false on an error_correction item when the grammatical correction
itself is wrong, incomplete (e.g. it missed a second error in the sentence),
or introduces a new mistake.

Some items will have an empty userAnswer because the learner left them
blank. Still give your best correctedAnswer and a short explanation of what
was expected for these — that reference content is shown to the learner
regardless. But don't try to phrase isCorrect or errorType around "blank" in
any special way; the app detects blank answers itself from the raw input and
ignores your isCorrect/errorType values for those items, so just score them
as you would any wrong answer.

Many learners here type on a Turkish keyboard. If a userAnswer is otherwise
grammatically identical to the correct answer and differs only by one or
more of these letter substitutions — ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u (any
case, either direction) — mark isCorrect: true. These are never a
grammatical distinction in English; a learner who typed "cookıng" for
"cooking" produced the right word, just with a different keyboard
character. Still don't phrase isCorrect around this silently: mention it
briefly in the explanation (e.g. "Right word — 'ı' and 'i' are the same
letter here, just typed on a different keyboard.") so the learner notices
the character difference without being told it's wrong. This applies only
to that closed set of letters, not to typos or near-misses in general —
a genuine one-character grammar difference (e.g. "stay" vs. "stays") is
still a real mistake and must still be marked isCorrect: false.
`.trim();

export interface AnthropicRequestBody {
  model: string;
  max_tokens: number;
  system: string;
  /** Only on requests that use it, so every other request is byte-for-byte
   * what it always was. */
  thinking?: { type: 'adaptive' };
  output_config: { format: { type: 'json_schema'; schema: unknown } };
  messages: { role: 'user'; content: string }[];
}

/**
 * Room for adaptive thinking on top of the answer's own budget. Thinking
 * tokens count against `max_tokens` and are billed as output, but only what is
 * generated is billed, so a generous ceiling costs nothing by itself; a tight
 * one would truncate the answer after a long think.
 */
export const THINKING_HEADROOM_TOKENS = 12_000;

/** Shared-set generator models that run with adaptive thinking.
 * `claude-sonnet-4-6` does not, as today; `claude-sonnet-5` does (its
 * documented thinking mode is adaptive), because correctness is the goal. */
function generatorThinks(model: SharedGeneratorModel): boolean {
  return model === 'claude-sonnet-5';
}

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
 * (`claude-sonnet-4-6` by default, the legacy route's model); a thinking model
 * gets `THINKING_HEADROOM_TOKENS` more. Exported for tests.
 */
export function buildGenerateSharedDailyTestBody(req: GenerateSharedDailyTestRequest): AnthropicRequestBody {
  const thinks = generatorThinks(req.model);
  return {
    model: req.model,
    max_tokens: dailyTestMaxTokensFor(req.count) + (thinks ? THINKING_HEADROOM_TOKENS : 0),
    system: req.promptVersion === 2 ? SHARED_DAILY_TEST_SYSTEM_PROMPT_V2 : DAILY_TEST_SYSTEM_PROMPT,
    ...(thinks ? { thinking: { type: 'adaptive' as const } } : {}),
    output_config: { format: { type: 'json_schema', schema: dailyTestSchema() } },
    messages: [{ role: 'user', content: sharedDailyTestUserPrompt(req) }],
  };
}

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
          },
          required: ['itemId', 'isCorrect', 'correctedAnswer', 'explanation'],
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
    max_tokens: 2048,
    system: SCORING_SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema } },
    messages: [{ role: 'user', content: JSON.stringify({ items: itemsPayload }) }],
  };
}

export type AnthropicOperation =
  | { op: 'generate_practice_set'; request: GeneratePracticeSetRequest }
  | { op: 'generate_daily_test'; request: GenerateDailyTestRequest }
  | { op: 'generate_shared_daily_test'; request: GenerateSharedDailyTestRequest }
  | { op: 'score_answers'; request: ScoreAnswersRequest };

function buildBody(operation: AnthropicOperation): AnthropicRequestBody {
  switch (operation.op) {
    case 'generate_practice_set':
      return buildGeneratePracticeSetBody(operation.request);
    case 'generate_daily_test':
      return buildGenerateDailyTestBody(operation.request);
    case 'generate_shared_daily_test':
      return buildGenerateSharedDailyTestBody(operation.request);
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
