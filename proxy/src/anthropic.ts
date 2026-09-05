import { TOPICS, topicById } from './topics';
import { ProxyError, type Env } from './types';
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

/** Keeps a 2:2:1 sentence_writing : error_correction : fill_in_blank ratio at any count. */
function itemMix(count: number): string {
  const sentenceWriting = Math.round(count * 0.4);
  const errorCorrection = Math.round(count * 0.4);
  const fillInBlank = count - sentenceWriting - errorCorrection;
  return `${sentenceWriting} sentence_writing, ${errorCorrection} error_correction, and ${fillInBlank} fill_in_blank`;
}

/** Ranked by summed frequency per topic, most frequent first; empty input asks for general variety. */
function dailyTestUserPrompt(count: number, weakSpots: GenerateDailyTestRequest['weakSpots']): string {
  if (weakSpots.length === 0) {
    const allTitles = TOPICS.map((t) => t.title).join(', ');
    return `Generate exactly ${count} Daily Test questions. This user has no practice history yet, so cover a varied general mix across these topics: ${allTitles}.`;
  }

  const frequencyByTopic = new Map<string, number>();
  for (const spot of weakSpots) {
    frequencyByTopic.set(spot.topicId, (frequencyByTopic.get(spot.topicId) ?? 0) + spot.frequency);
  }
  const rankedTitles = [...frequencyByTopic.keys()]
    .sort((a, b) => (frequencyByTopic.get(b) ?? 0) - (frequencyByTopic.get(a) ?? 0))
    .map((id) => topicById(id)?.title ?? id);

  return `Generate exactly ${count} Daily Test questions. Bias topic selection toward this user's most frequent error categories, most frequent first: ${rankedTitles.join(', ')}. Still include some variety rather than every question targeting the same topic.`;
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
`.trim();

interface AnthropicRequestBody {
  model: string;
  max_tokens: number;
  system: string;
  output_config: { format: { type: 'json_schema'; schema: unknown } };
  messages: { role: 'user'; content: string }[];
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

function buildGenerateDailyTestBody(req: GenerateDailyTestRequest): AnthropicRequestBody {
  const schema = {
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
          required: ['id', 'type', 'instruction', 'topicId', 'correctAnswer', 'commonWrongAnswers'],
          additionalProperties: false,
        },
      },
    },
    required: ['questions'],
    additionalProperties: false,
  };

  return {
    model: MODEL,
    max_tokens: maxTokensFor(req.count),
    system: DAILY_TEST_SYSTEM_PROMPT,
    output_config: { format: { type: 'json_schema', schema } },
    messages: [{ role: 'user', content: dailyTestUserPrompt(req.count, req.weakSpots) }],
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
  | { op: 'score_answers'; request: ScoreAnswersRequest };

function buildBody(operation: AnthropicOperation): AnthropicRequestBody {
  switch (operation.op) {
    case 'generate_practice_set':
      return buildGeneratePracticeSetBody(operation.request);
    case 'generate_daily_test':
      return buildGenerateDailyTestBody(operation.request);
    case 'score_answers':
      return buildScoreAnswersBody(operation.request);
  }
}

/**
 * Calls Anthropic for the given operation and returns the already-parsed,
 * schema-shaped JSON object (e.g. `{ items: [...] }`) — never Anthropic's
 * raw response envelope, and never its raw error body on failure (that's
 * an explicit requirement, not an oversight: a client must never see
 * Anthropic's own error text, which can carry implementation detail that
 * isn't ours to expose).
 */
export async function callAnthropic(env: Env, operation: AnthropicOperation): Promise<unknown> {
  const body = buildBody(operation);

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
    });
  } catch (e) {
    console.error('Anthropic request failed to send', e);
    throw new ProxyError('upstream_error', 502, 'Could not reach the upstream service.');
  }

  if (response.status !== 200) {
    // Logged server-side only (visible via `wrangler tail`) — never
    // forwarded to the client.
    console.error('Anthropic returned', response.status, await response.text());
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an error.');
  }

  const decoded = (await response.json()) as { content?: { type: string; text?: string }[] };
  const textBlock = decoded.content?.find((block) => block.type === 'text');
  if (!textBlock?.text) {
    console.error('Anthropic response had no text content block', decoded);
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an unexpected response.');
  }

  try {
    return JSON.parse(textBlock.text);
  } catch (e) {
    console.error('Anthropic text content was not valid JSON', e);
    throw new ProxyError('upstream_error', 502, 'The upstream service returned an unexpected response.');
  }
}
