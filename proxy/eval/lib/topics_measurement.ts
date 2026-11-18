import {
  PRODUCTION_PRACTICE,
  PRODUCTION_SCORING,
  THINKING_HEADROOM_TOKENS,
  buildGeneratePracticeSetBodyFor,
  buildScoreAnswersBodyFor,
  type AnthropicRequestBody,
} from '../../src/anthropic';
import { FIRST_WAVE_TOPICS, topicById, type TopicInfo } from '../../src/topics';
import { validateScoreAnswers } from '../../src/validation';
import { assembleBlanks, type ScoredItemType } from './datasets';
import { PRICES, costOf, type EvalModel } from './matrix';
import {
  ANSWERS_PER_CALL,
  ITEMS_PER_SET,
  estimateInputTokens,
  generationOutputTokens,
  groupAnswers,
  sGenItemsFrom,
  scoringRequest,
  thinkingTokens,
  type PlannedCall,
} from './measurement';

/**
 * The 1.5.0 first-wave topics measurement (docs/TOPICS.md, phase A): which
 * calls it makes, with which request body, and what each is expected to
 * cost. Pure: no network, no files. `eval/run.ts topics` does the I/O.
 *
 * Three stages:
 * 1. `generation`: Topic Practice sets through the live practice path
 *    ({@link PRODUCTION_PRACTICE}, the production prompt, model and effort),
 *    with the first-wave topics known **for this request only** (the
 *    builder's parameter; `FIRST_WAVE_TOPICS_ENABLED` stays false).
 * 2. `answers`: a practice item carries no answer key, so one harness call
 *    per generated set writes each item's key, a second correct answer when
 *    one exists, and typical learner mistakes (decision T-2).
 * 3. `scoring`: every built answer through the production scoring cell
 *    ({@link PRODUCTION_SCORING}: 1.4.0's C8, `claude-haiku-5-5`, `low`,
 *    D3 + D11).
 *
 * The automatic checks on the generated items are in `topics_checks.ts`.
 */

/** Measured spend is never allowed past this (docs/TOPICS.md, Rules). */
export const TOPICS_SPEND_CAP_USD = 15;
/** The dry run's estimate must stay at or under this, so the cap has room. */
export const TOPICS_DRY_RUN_LIMIT_USD = 12;
/** The margin on a call's estimate in the cap check, as in `run.ts`. */
export const TOPICS_CAP_MARGIN = 1.25;

export const SETS_PER_NEW_TOPIC = 6;
/** The control: a topic that is already live, measured the same way
 * (decision T-3). */
export const CONTROL_TOPIC_ID = 'articles';
export const SETS_FOR_CONTROL = 3;

/** Fixes which answers of a set share a scoring call. */
export const TOPICS_SEED = 20261118;

/** The answer writer: the 1.4.0 S-free writer's model and effort. */
export const ANSWER_WRITER: EvalModel = 'claude-sonnet-5-5';

export interface MeasuredTopic {
  topic: TopicInfo;
  sets: number;
  control: boolean;
}

/**
 * The five first-wave topics, six sets each, then the control, three. With
 * [only] (a re-measurement, `--only <topicId>`): that one topic alone, with
 * the sets it has in the full measurement.
 */
export function measuredTopics(only?: string): MeasuredTopic[] {
  const control = topicById(CONTROL_TOPIC_ID);
  if (!control) throw new Error(`The control topic ${CONTROL_TOPIC_ID} is not a live topic.`);
  const all = [...FIRST_WAVE_TOPICS.map((topic) => ({ topic, sets: SETS_PER_NEW_TOPIC, control: false })), { topic: control, sets: SETS_FOR_CONTROL, control: true }];
  if (only === undefined) return all;
  const one = all.filter((t) => t.topic.id === only);
  if (one.length === 0) throw new Error(`--only ${only}: not a measured topic (${all.map((t) => t.topic.id).join(', ')}).`);
  return one;
}

/**
 * The first run of the measurement (the owner's, 2026-11-18): its folder
 * under `eval/out/` and what it spent ($0.7636 measured, "$0.76" in its log;
 * rounded up here). The $15.00 cap is on the measurement as a whole, so a
 * later run counts this as already spent; the figure stands in only when the
 * folder itself is not there to be read.
 */
export const TOPICS_FIRST_RUN = { folder: 'topics-2026-11-18T16-35-34-632Z', spendUsd: 0.77 } as const;

/**
 * What the measurement's other runs have spent: the measured spend of every
 * other `topics-…` folder under `eval/out/` ([folders], the current run's
 * own left out by the caller), with the first run's known spend when its
 * folder is not among them. Never less than what is known to be spent.
 */
export function priorTopicsSpend(folders: readonly { name: string; spendUsd: number }[]): number {
  const read = folders.reduce((n, f) => n + f.spendUsd, 0);
  return folders.some((f) => f.name === TOPICS_FIRST_RUN.folder) ? read : read + TOPICS_FIRST_RUN.spendUsd;
}

/** A model the harness has a price for; a production model without one
 * stops the plan instead of running unpriced. */
export function pricedModel(model: string): EvalModel {
  if (!(model in PRICES)) throw new Error(`No price in eval/lib/matrix.ts for ${model}.`);
  return model as EvalModel;
}

// ---------------------------------------------------------------------------
// Stage 1: generation

export const generationId = (topicId: string, set: number) => `tgen_${topicId}_${set}`;
export const answersId = (topicId: string, set: number) => `tans_${topicId}_${set}`;

/** What the proxy would send for one Topic Practice set of [topicId] with the
 * first-wave switch on: the production variant, the app's Standard length. */
export function generationBody(topicId: string): AnthropicRequestBody {
  return buildGeneratePracticeSetBodyFor({ deviceId: 'measurement', topicId, count: ITEMS_PER_SET }, PRODUCTION_PRACTICE, true);
}

function planned(customId: string, stage: PlannedCall['stage'], group: string, model: EvalModel, body: AnthropicRequestBody, outputTokens: number, ratio?: number): PlannedCall {
  return { customId, stage, group, model, body, estimate: { inputTokens: estimateInputTokens(body, ratio), outputTokens }, dropPriority: 1 };
}

/** 33 calls (6 with [only] a new topic): every set of a topic sends the same
 * body, as every user's request for that topic does. */
export function generationCalls(ratio?: number, only?: string): PlannedCall[] {
  const model = pricedModel(PRODUCTION_PRACTICE.model);
  const outputTokens = generationOutputTokens({ ...PRODUCTION_PRACTICE, id: 'G-D', model });
  const calls: PlannedCall[] = [];
  for (const { topic, sets } of measuredTopics(only)) {
    for (let set = 1; set <= sets; set++) calls.push(planned(generationId(topic.id, set), 'generation', topic.id, model, generationBody(topic.id), outputTokens, ratio));
  }
  return calls;
}

// ---------------------------------------------------------------------------
// Generated items

const BLANK = /_{2,}/g;

/** One generated practice item, as the app would show and send it. */
export interface TopicItem {
  /** `<topicId>.<set>.<position>`: unique in the run, never sent anywhere. */
  id: string;
  topicId: string;
  /** 1-based. */
  set: number;
  /** Position in the set, 0-based. */
  index: number;
  /** The model's own id for the item. */
  sourceId: string;
  type: ScoredItemType;
  context?: string;
  instruction: string;
  hint?: string;
  /** `PracticeItem.fullText`: what scoring gets as the item's prompt. */
  prompt: string;
  /** The text the blanks are filled in (the app's `blankSourceText`). */
  blankSource: string;
  blanks: number;
}

/** The app's `blankSourceText` (lib/utils/blank_assembly.dart): the context
 * when it has the blanks, both fields when both do, else the instruction. */
export function blankSourceText(context: string | undefined, instruction: string): string {
  const inContext = context !== undefined && /_{2,}/.test(context);
  const inInstruction = /_{2,}/.test(instruction);
  if (inContext && inInstruction) return `${context}\n${instruction}`;
  if (inContext) return context as string;
  return instruction;
}

/** The items of one generation call, accepted as the practice path accepts
 * them (1.4.0's `sGenItemsFrom`: an id, a known type, an instruction);
 * [dropped] counts the entries left out. */
export function topicItemsFrom(topicId: string, set: number, content: unknown): { items: TopicItem[]; dropped: number; isSet: boolean } {
  const isSet = Array.isArray((content as { items?: unknown } | null)?.items);
  const parsed = sGenItemsFrom('G-D', topicId, content);
  const items = parsed.items.map((item, index) => {
    const blankSource = blankSourceText(item.context, item.instruction);
    return {
      id: `${topicId}.${set}.${index}`,
      topicId,
      set,
      index,
      sourceId: item.id.slice(`G-D:${topicId}:`.length),
      type: item.type,
      ...(item.context === undefined ? {} : { context: item.context }),
      instruction: item.instruction,
      ...(item.hint === undefined ? {} : { hint: item.hint }),
      prompt: item.prompt,
      blankSource,
      blanks: blankSource.match(BLANK)?.length ?? 0,
    };
  });
  return { items, dropped: parsed.dropped, isSet };
}

// ---------------------------------------------------------------------------
// Stage 2: the answer writer (a harness prompt, not a proxy prompt)

export const ANSWER_WRITER_SYSTEM_PROMPT = `
You write the answer material for a test of an automatic scorer of English
grammar practice items, made for B1-C1 learners whose first language is not
English. For each item you get its "itemId", its "type", the "topic" it
practises, its "text" as the learner sees it, and "blanks": how many blanks
the text has (a blank is a run of two or more underscores).

Every answer is a list of strings. For a fill_in_blank item it has exactly
one string per blank, in the order the blanks appear: what goes into that
blank and nothing else; write "—" for a blank that takes no word. For an
error_correction item it has exactly one string: the full rewritten
sentence. For a sentence_writing item it has exactly one string: one
sentence that does the task.

For each item return:
- "key": the answer a careful teacher would put in the answer key: fully
  correct, and the most natural one.
- "variant": a second answer that is also fully correct and natural here and
  differs from the key in the structure the topic tests (for example "that"
  where the key has "who"). A contraction, a spelling variant or a change
  outside the tested structure does not count. Only when one really exists;
  otherwise an empty list. For sentence_writing always an empty list.
- "mistakes": exactly two for fill_in_blank and error_correction, exactly
  one for sentence_writing. Each is the answer of a B1-B2 learner with
  exactly one typical mistake in the structure the topic tests and nothing
  else wrong: "answer" in the same list form, and "breaks", the rule it
  breaks, in a few words. A mistake must be clearly wrong, never a
  defensible alternative, and the two must be different mistakes. For
  error_correction a mistake may leave the original error in place or fix
  it wrongly.

Return one entry per item with its "itemId". Return only the structured
output.
`.trim();

const ANSWER_LIST = { type: 'array', items: { type: 'string' } } as const;

/** The writer's own output budget, before thinking. */
const ANSWER_WRITER_MAX_TOKENS = 2_048;

export function answerWriterBody(items: readonly Pick<TopicItem, 'id' | 'type' | 'topicId' | 'prompt' | 'blanks'>[]): AnthropicRequestBody {
  return {
    model: ANSWER_WRITER,
    max_tokens: ANSWER_WRITER_MAX_TOKENS + THINKING_HEADROOM_TOKENS,
    system: ANSWER_WRITER_SYSTEM_PROMPT,
    thinking: { type: 'adaptive' },
    output_config: {
      format: {
        type: 'json_schema',
        schema: {
          type: 'object',
          properties: {
            answers: {
              type: 'array',
              items: {
                type: 'object',
                properties: {
                  itemId: { type: 'string' },
                  key: ANSWER_LIST,
                  variant: ANSWER_LIST,
                  mistakes: {
                    type: 'array',
                    items: {
                      type: 'object',
                      properties: { answer: ANSWER_LIST, breaks: { type: 'string' } },
                      required: ['answer', 'breaks'],
                      additionalProperties: false,
                    },
                  },
                },
                required: ['itemId', 'key', 'variant', 'mistakes'],
                additionalProperties: false,
              },
            },
          },
          required: ['answers'],
          additionalProperties: false,
        },
      },
      effort: 'low',
    },
    messages: [
      {
        role: 'user',
        content: JSON.stringify({
          items: items.map((i) => ({ itemId: i.id, type: i.type, topic: topicById(i.topicId, true)?.title ?? i.topicId, text: i.prompt, blanks: i.blanks })),
        }),
      },
    ],
  };
}

/** ≈ 200 output tokens per item (four short answers, two rule notes, the
 * JSON around them) plus `low` thinking. */
export const ANSWER_WRITER_OUTPUT_TOKENS = 200 * ITEMS_PER_SET + thinkingTokens({ thinking: true, effort: 'low' });

export function answerWriterCall(topicId: string, set: number, items: readonly TopicItem[], ratio?: number): PlannedCall {
  return planned(answersId(topicId, set), 'answers', topicId, ANSWER_WRITER, answerWriterBody(items), ANSWER_WRITER_OUTPUT_TOKENS, ratio);
}

// ---------------------------------------------------------------------------
// Built answers

export type AnswerKind = 'key' | 'variant' | 'mistake1' | 'mistake2';

/** One answer with its verdict by construction: the key and the variant are
 * right, a mistake is wrong. */
export interface TopicAnswer {
  /** Opaque (`a` + eight hex digits): it is the item id the scorer sees, so
   * it must not say which kind of answer this is. */
  id: string;
  itemId: string;
  topicId: string;
  /** The generated set the question is in, 1-based. */
  set: number;
  kind: AnswerKind;
  /** The question as scoring gets it. `item.id` is the same for every answer
   * to one question, so the grouping keeps them in different calls; the id
   * the scorer sees for the item is this answer's own opaque `id`. */
  item: { id: string; type: ScoredItemType; prompt: string };
  /** The wire `userAnswer`: a single box's text, the assembled sentence of a
   * multi-blank item, or the written sentence. */
  userAnswer: string;
  /** fill_in_blank: what went into each blank. */
  fills?: string[];
  truth: boolean;
  /** A mistake: the rule the writer says it breaks. */
  breaks?: string;
}

/** What the writer's entry for one item could not be used for. */
export interface AnswerProblem {
  itemId: string;
  code:
    | 'no_entry'
    | 'key_unusable'
    | 'key_equals_original'
    | 'variant_unusable'
    | 'variant_equals_key'
    | 'mistake_unusable'
    | 'mistake_equals_right_answer'
    | 'mistakes_missing'
    | 'answer_too_long';
  detail: string;
}

export interface BuiltAnswers {
  answers: TopicAnswer[];
  problems: AnswerProblem[];
}

/** FNV-1a, 32 bits, as eight hex digits. */
export function fnv1a(text: string): string {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return (h >>> 0).toString(16).padStart(8, '0');
}

/** Case, spacing, typographic quotes and the final full stop do not make two
 * answers different. */
export function normalizeAnswer(text: string): string {
  return text
    .toLowerCase()
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/[.!?]+$/, '');
}

const NO_WORD = new Set(['—', '–', '-', '']);

/** The proxy's own limit on a scoring request's texts (`validation.ts`). */
const MAX_WIRE_LENGTH = 2_000;

function stringList(value: unknown): string[] | null {
  return Array.isArray(value) && value.every((v) => typeof v === 'string') ? (value as string[]).map((v) => v.trim()) : null;
}

/** The wire answer for [list] on [item], or null when the list does not fit
 * the item (the wrong number of entries, or nothing in it). */
export function wireAnswer(item: TopicItem, list: readonly string[]): { userAnswer: string; fills?: string[] } | null {
  if (item.type !== 'fill_in_blank') {
    const sentence = list[0]?.trim() ?? '';
    return list.length === 1 && sentence.length > 0 ? { userAnswer: sentence } : null;
  }
  if (item.blanks === 0 || list.length !== item.blanks) return null;
  const fills = list.map((f) => (NO_WORD.has(f) ? '—' : f));
  if (item.blanks === 1) return { userAnswer: fills[0] as string, fills };
  const assembled = assembleBlanks(item.blankSource, fills.map((f) => (f === '—' ? { text: '', noArticle: true } : { text: f })));
  return assembled.length > 0 ? { userAnswer: assembled, fills } : null;
}

/**
 * The answers built from the writer's output for one set's [items]: per item
 * the key, the variant when there is one, and two mistakes (one for
 * sentence_writing), each only when it fits the item and differs from the
 * answers before it. An item without a usable key gets no answers at all.
 */
export function builtAnswersFrom(items: readonly TopicItem[], content: unknown): BuiltAnswers {
  const raw = (content as { answers?: unknown[] } | null)?.answers;
  const entries = new Map<string, Record<string, unknown>>();
  if (Array.isArray(raw)) {
    for (const entry of raw) {
      const e = (entry ?? {}) as Record<string, unknown>;
      if (typeof e.itemId === 'string' && !entries.has(e.itemId)) entries.set(e.itemId, e);
    }
  }
  const answers: TopicAnswer[] = [];
  const problems: AnswerProblem[] = [];
  const usedIds = new Set<string>();
  for (const item of items) {
    const problem = (code: AnswerProblem['code'], detail: string) => problems.push({ itemId: item.id, code, detail });
    const entry = entries.get(item.id);
    if (!entry) {
      problem('no_entry', 'the writer returned nothing for this item');
      continue;
    }
    const questionId = `q${fnv1a(item.id)}`;
    const taken: string[] = [];
    const add = (kind: AnswerKind, wire: { userAnswer: string; fills?: string[] }, truth: boolean, breaks?: string) => {
      let id = `a${fnv1a(`${item.id}|${kind}|${wire.userAnswer}`)}`;
      for (let n = 1; usedIds.has(id); n++) id = `a${fnv1a(`${item.id}|${kind}|${wire.userAnswer}|${n}`)}`;
      usedIds.add(id);
      taken.push(normalizeAnswer(wire.userAnswer));
      answers.push({
        id,
        itemId: item.id,
        topicId: item.topicId,
        set: item.set,
        kind,
        item: { id: questionId, type: item.type, prompt: item.prompt },
        userAnswer: wire.userAnswer,
        ...(wire.fills ? { fills: wire.fills } : {}),
        truth,
        ...(breaks ? { breaks } : {}),
      });
    };
    const fits = (wire: { userAnswer: string } | null): wire is { userAnswer: string; fills?: string[] } => wire !== null && wire.userAnswer.length <= MAX_WIRE_LENGTH;

    const keyList = stringList(entry.key);
    const key = keyList ? wireAnswer(item, keyList) : null;
    if (!fits(key)) {
      problem(key ? 'answer_too_long' : 'key_unusable', `key: ${JSON.stringify(entry.key ?? null).slice(0, 120)} for ${item.blanks} blank(s)`);
      continue;
    }
    if (item.type === 'error_correction' && item.context !== undefined && normalizeAnswer(key.userAnswer) === normalizeAnswer(item.context)) {
      problem('key_equals_original', 'the key is the sentence to correct, unchanged');
    }
    add('key', key, true);

    const variantList = stringList(entry.variant) ?? [];
    if (item.type !== 'sentence_writing' && variantList.length > 0) {
      const variant = wireAnswer(item, variantList);
      if (!fits(variant)) problem('variant_unusable', `variant: ${JSON.stringify(variantList).slice(0, 120)}`);
      else if (taken.includes(normalizeAnswer(variant.userAnswer))) problem('variant_equals_key', variant.userAnswer.slice(0, 120));
      else add('variant', variant, true);
    }

    const wanted = item.type === 'sentence_writing' ? 1 : 2;
    const mistakes = Array.isArray(entry.mistakes) ? entry.mistakes : [];
    let built = 0;
    for (const m of mistakes) {
      if (built === wanted) break;
      const e = (m ?? {}) as Record<string, unknown>;
      const list = stringList(e.answer);
      const mistake = list ? wireAnswer(item, list) : null;
      if (!fits(mistake)) {
        problem('mistake_unusable', `mistake: ${JSON.stringify(e.answer ?? null).slice(0, 120)}`);
        continue;
      }
      if (taken.includes(normalizeAnswer(mistake.userAnswer))) {
        problem('mistake_equals_right_answer', mistake.userAnswer.slice(0, 120));
        continue;
      }
      built++;
      add(built === 1 ? 'mistake1' : 'mistake2', mistake, false, typeof e.breaks === 'string' ? e.breaks.trim() : undefined);
    }
    if (built < wanted) problem('mistakes_missing', `${built} of ${wanted} mistakes built`);
  }
  return { answers, problems };
}

// ---------------------------------------------------------------------------
// Stage 3: scoring with the production cell

/** Measured in the 1.4.0 run for this cell (C8, 600 scoring calls of five
 * answers): 2,538 output tokens a call, thinking included; the report's
 * formula (220 an answer + 400) under-estimated Haiku by 1.7 ×. */
export const SCORING_OUTPUT_TOKENS_PER_ANSWER = Math.ceil(2_538 / ANSWERS_PER_CALL);

export interface ScoringCall {
  call: PlannedCall;
  /** The opaque ids of the answers in the call, in request order. */
  answerIds: string[];
}

/**
 * The scoring calls for [answers]. A call holds answers to the questions of
 * one generated set, at most one answer per question and five in all: what
 * the app sends when a learner finishes a Standard set, with right and wrong
 * answers mixed by a shuffle fixed per set (1.4.0's grouping, {@link
 * TOPICS_SEED}). Because a set's calls depend on that set alone, a folder
 * resumed after some sets failed scores only the new sets; and a call's id
 * carries a hash of its answers, so a call whose answers changed is a new
 * call, never an old record read as this one. Every request is checked with
 * the proxy's own `validateScoreAnswers`.
 */
export function scoringCalls(answers: readonly TopicAnswer[], ratio?: number): ScoringCall[] {
  const model = pricedModel(PRODUCTION_SCORING.model);
  const bySet = new Map<string, TopicAnswer[]>();
  for (const a of answers) {
    const key = `${a.topicId}.${a.set}`;
    bySet.set(key, [...(bySet.get(key) ?? []), a]);
  }
  const calls: ScoringCall[] = [];
  for (const [key, inSet] of bySet) {
    for (const group of groupAnswers(inSet, TOPICS_SEED + Number.parseInt(fnv1a(key).slice(0, 6), 16))) {
      const request = validateScoreAnswers(scoringRequest(group));
      const body = buildScoreAnswersBodyFor(request, PRODUCTION_SCORING);
      const answerIds = group.map((a) => a.id);
      calls.push({
        call: planned(`tscore_${fnv1a(answerIds.join('|'))}`, 'scoring', 'C8', model, body, SCORING_OUTPUT_TOKENS_PER_ANSWER * group.length, ratio),
        answerIds,
      });
    }
  }
  return calls;
}

// ---------------------------------------------------------------------------
// The dry run: the plan before anything is generated

const PLACEHOLDER_ITEMS: readonly { type: ScoredItemType; context?: string; instruction: string }[] = [
  {
    type: 'sentence_writing',
    context: 'You are writing an email to a colleague about a project deadline that is approaching this week.',
    instruction: 'Using a relative clause with "which" or "whose", write one sentence describing the report your team must finish.',
  },
  {
    type: 'sentence_writing',
    context: 'You are telling a friend about two flats you visited at the weekend and which one you prefer.',
    instruction: 'Write one sentence comparing the two flats, using a comparative form and "than".',
  },
  {
    type: 'error_correction',
    context: 'If the company would have invested in new equipment last year, the factory would not have closed.',
    instruction: 'Find the mistake and rewrite the full corrected sentence.',
  },
  {
    type: 'error_correction',
    context: 'The new library, that was opened by the mayor last month, is visited from hundreds of students every day.',
    instruction: 'Find the mistake and rewrite the full corrected sentence.',
  },
  {
    type: 'fill_in_blank',
    instruction: 'The conference will be held ____ the main hall ____ Friday morning, so please arrive ____ time. Fill in each blank with one preposition.',
  },
];

/** One set of made-up items of the expected shape (the 2 : 2 : 1 mix), for
 * the estimate only. */
export function placeholderItems(topicId: string, set: number): TopicItem[] {
  return PLACEHOLDER_ITEMS.map((p, index) => {
    const blankSource = blankSourceText(p.context, p.instruction);
    return {
      id: `${topicId}.${set}.${index}`,
      topicId,
      set,
      index,
      sourceId: `placeholder-${index}`,
      type: p.type,
      ...(p.context === undefined ? {} : { context: p.context }),
      instruction: p.instruction,
      prompt: p.context === undefined ? p.instruction : `${p.context}\n${p.instruction}`,
      blankSource,
      blanks: blankSource.match(BLANK)?.length ?? 0,
    };
  });
}

/** The most answers an item can get (key, variant, two mistakes; a written
 * sentence: key and one mistake), with made-up texts of a realistic length. */
export function placeholderAnswers(items: readonly TopicItem[]): TopicAnswer[] {
  const sentence = 'If the company had invested in new equipment last year, the factory would not have closed so suddenly.';
  return items.flatMap((item) => {
    const kinds: AnswerKind[] = item.type === 'sentence_writing' ? ['key', 'mistake1'] : ['key', 'variant', 'mistake1', 'mistake2'];
    return kinds.map((kind) => ({
      id: `a${fnv1a(`${item.id}|${kind}`)}`,
      itemId: item.id,
      topicId: item.topicId,
      set: item.set,
      kind,
      item: { id: `q${fnv1a(item.id)}`, type: item.type, prompt: item.prompt },
      userAnswer: item.type === 'fill_in_blank' ? item.blankSource.replace(BLANK, 'in') : sentence,
      truth: kind === 'key' || kind === 'variant',
    }));
  });
}

export interface TopicsPlan {
  generation: PlannedCall[];
  answers: PlannedCall[];
  scoring: PlannedCall[];
  /** Answers the scoring estimate assumes (the upper bound). */
  answerCount: number;
}

/** Every call the measurement makes if nothing fails, the later stages on
 * placeholders: an upper bound, since not every item gets a variant. */
export function planTopicsDryRun(ratio?: number, only?: string): TopicsPlan {
  const generation = generationCalls(ratio, only);
  const answers: PlannedCall[] = [];
  const built: TopicAnswer[] = [];
  for (const { topic, sets } of measuredTopics(only)) {
    for (let set = 1; set <= sets; set++) {
      const items = placeholderItems(topic.id, set);
      answers.push(answerWriterCall(topic.id, set, items, ratio));
      built.push(...placeholderAnswers(items));
    }
  }
  return { generation, answers, scoring: scoringCalls(built, ratio).map((s) => s.call), answerCount: built.length };
}

export const planCost = (calls: readonly PlannedCall[]) => calls.reduce((n, c) => n + costOf(c.model, c.estimate, true), 0);

/** What [calls] cost if every one wrote all its `max_tokens` allows
 * (thinking included): the most the plan can cost with no call repeated. */
export const planWorstCase = (calls: readonly PlannedCall[]) => calls.reduce((n, c) => n + costOf(c.model, { inputTokens: c.estimate.inputTokens, outputTokens: c.body.max_tokens }, true), 0);

/** Whether a call may be made: what is spent plus its estimate with the
 * margin must stay within the cap (docs/TOPICS.md, Rules). */
export function fitsTopicsCap(spentUsd: number, estimateUsd: number, capUsd = TOPICS_SPEND_CAP_USD): boolean {
  return spentUsd + estimateUsd * TOPICS_CAP_MARGIN <= capUsd;
}

const usd = (n: number) => `$${n.toFixed(2)}`;

export interface DryRunSummary {
  text: string;
  totalCalls: number;
  totalUsd: number;
  worstCaseUsd: number;
  /** The estimate is within the dry-run limit and, with what earlier runs
   * spent, within the cap. */
  withinLimit: boolean;
}

/** A re-measurement: the one topic measured, and what the measurement's
 * earlier runs have spent (it counts against the same cap). */
export interface DryRunScope {
  only?: string;
  priorSpendUsd?: number;
}

/** The dry run's printout: the calls per stage and the estimated spend. */
export function renderTopicsDryRun(plan: TopicsPlan, ratio: number, scope: DryRunScope = {}): DryRunSummary {
  const topics = measuredTopics(scope.only);
  const prior = scope.priorSpendUsd ?? 0;
  const sets = topics.reduce((n, t) => n + t.sets, 0);
  const stages: { name: string; what: string; calls: PlannedCall[] }[] = [
    { name: 'generation', what: 'Topic Practice sets, the live practice path', calls: plan.generation },
    { name: 'answers', what: 'the answer writer, one call per set', calls: plan.answers },
    { name: 'scoring', what: 'the production scoring cell (C8), one set\'s questions a call', calls: plan.scoring },
  ];
  const mean = (calls: readonly PlannedCall[], pick: (c: PlannedCall) => number) => (calls.length === 0 ? 0 : Math.round(calls.reduce((n, c) => n + pick(c), 0) / calls.length));
  const all = stages.flatMap((s) => s.calls);
  const totalUsd = planCost(all);
  const worstCaseUsd = planWorstCase(all);
  const withinLimit = totalUsd <= TOPICS_DRY_RUN_LIMIT_USD && prior + totalUsd * TOPICS_CAP_MARGIN <= TOPICS_SPEND_CAP_USD;
  const lines = [
    scope.only === undefined ? 'First-wave topics measurement — dry run (no API call)' : `First-wave topics measurement, ${scope.only} only (a re-measurement) — dry run (no API call)`,
    '',
    `Topics: ${topics.map((t) => `${t.topic.id} × ${t.sets}${t.control ? ' (control)' : ''}`).join(', ')}.`,
    `${sets} sets of ${ITEMS_PER_SET} = ${sets * ITEMS_PER_SET} questions; at most ${plan.answerCount} built answers to score.`,
    `Characters per input token (calibrated on a measured request): ${ratio.toFixed(2)}.`,
    '',
    '| Stage | What | Model | Calls | Mean input | Mean output (incl. thinking) | Cost per call | Cost |',
    '|---|---|---|---|---|---|---|---|',
    ...stages.map((s) => {
      const cost = planCost(s.calls);
      return `| ${s.name} | ${s.what} | ${s.calls[0]?.model ?? '–'} | ${s.calls.length} | ${mean(s.calls, (c) => c.estimate.inputTokens)} | ${mean(s.calls, (c) => c.estimate.outputTokens)} | $${(s.calls.length === 0 ? 0 : cost / s.calls.length).toFixed(4)} | ${usd(cost)} |`;
    }),
    `| **Total** | | | **${all.length}** | | | | **${usd(totalUsd)}** |`,
    '',
    `Estimated spend ${usd(totalUsd)}: ${totalUsd <= TOPICS_DRY_RUN_LIMIT_USD ? 'within' : 'OVER'} the dry-run limit of ${usd(TOPICS_DRY_RUN_LIMIT_USD)}. Hard cap on measured spend: ${usd(TOPICS_SPEND_CAP_USD)}; a call is made only while spent + its estimate × ${TOPICS_CAP_MARGIN} stays within it, else it is skipped and recorded.`,
    ...(prior > 0
      ? [
          `The cap is on the measurement as a whole: earlier runs spent ${usd(prior)}, so this run starts at ${usd(prior)} spent and may add ${usd(TOPICS_SPEND_CAP_USD - prior)}. With this estimate the measurement comes to ${usd(prior + totalUsd)} of ${usd(TOPICS_SPEND_CAP_USD)}${prior + totalUsd * TOPICS_CAP_MARGIN <= TOPICS_SPEND_CAP_USD ? '' : ': OVER the cap with the margin'}.`,
        ]
      : []),
    `Worst case, every call writing all its max_tokens allows: ${usd(worstCaseUsd)}${prior > 0 ? `, with the earlier runs ${usd(prior + worstCaseUsd)}` : ''} (${prior + worstCaseUsd <= TOPICS_SPEND_CAP_USD ? 'under' : 'over'} the cap).`,
    'The scoring row is an upper bound: it assumes a second correct answer for every item that can have one.',
  ];
  return { text: lines.join('\n'), totalCalls: all.length, totalUsd, worstCaseUsd, withinLimit };
}
