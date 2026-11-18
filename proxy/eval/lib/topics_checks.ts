import { ERROR_CORRECTION_MAX_EDIT_WORDS, hasSentenceToCorrect, isSingleShortEdit } from '../../src/shared_daily_test';
import { ITEMS_PER_SET } from './measurement';
import { topicItemsFrom, type TopicAnswer, type TopicItem } from './topics_measurement';

/**
 * The automatic checks of the 1.5.0 first-wave topics measurement
 * (docs/TOPICS.md, phase A): run on every generated question and recorded
 * per item. Pure, no model call.
 *
 * A flag is a reason for a person to look, not a verdict: the checks are
 * word-level rules that know nothing about meaning, so they miss things and
 * they flag things that are fine. The owner's labels (phase C) are the
 * verdict; the report shows how the flags relate to them.
 */

export type CheckId = 'topic' | 'single_answer' | 'duplicate' | 'length_level' | 'hint_card';
export const CHECK_IDS: readonly CheckId[] = ['topic', 'single_answer', 'duplicate', 'length_level', 'hint_card'];

export interface CheckFlag {
  check: CheckId;
  code: string;
  detail: string;
}

// ---------------------------------------------------------------------------
// Words

const WORD = /[a-z]+(?:'[a-z]+)?/g;

export function wordsOf(text: string): string[] {
  return text.toLowerCase().replace(/[‘’]/g, "'").match(WORD) ?? [];
}

/** The words [to] has that [from] lacks, and the other way round, as
 * multisets: what an error correction changed. */
export function changedWords(from: string, to: string): { removed: string[]; added: string[] } {
  const count = (ws: string[]) => {
    const m = new Map<string, number>();
    for (const w of ws) m.set(w, (m.get(w) ?? 0) + 1);
    return m;
  };
  const a = count(wordsOf(from));
  const b = count(wordsOf(to));
  const minus = (x: Map<string, number>, y: Map<string, number>) => [...x.entries()].flatMap(([w, n]) => Array.from({ length: Math.max(0, n - (y.get(w) ?? 0)) }, () => w));
  return { removed: minus(a, b), added: minus(b, a) };
}

// ---------------------------------------------------------------------------
// The gate: what the practice path itself requires

/**
 * The practice path has no semantic gate: the structured-output schema and
 * the app's parser decide what a learner sees (decision T-4). The
 * measurement's gate is that acceptance plus the prompt's rules a program
 * can check: a fill_in_blank item has one to four blanks, an
 * error_correction item carries its sentence.
 */
export function gateProblems(item: Pick<TopicItem, 'type' | 'context' | 'blanks'>): string[] {
  const problems: string[] = [];
  if (item.type === 'fill_in_blank' && item.blanks === 0) problems.push('fill_in_blank_without_blank');
  if (item.type === 'fill_in_blank' && item.blanks > 4) problems.push('more_than_4_blanks');
  if (item.type === 'error_correction' && !hasSentenceToCorrect(item.context)) problems.push('error_correction_without_sentence');
  return problems;
}

export interface SetGate {
  topicId: string;
  set: number;
  items: TopicItem[];
  /** Set-level problems: `not_a_set`, `malformed_entries:<n>`,
   * `wrong_count:<n>`, `wrong_mix:<sw>/<ec>/<fib>`. */
  problems: string[];
  /** No set-level problem and no item-level one. */
  passed: boolean;
}

/** One generation call's output through the gate. The requested set is five
 * items in the 2 : 2 : 1 mix the request names. */
export function gateSet(topicId: string, set: number, content: unknown): SetGate {
  const parsed = topicItemsFrom(topicId, set, content);
  const problems: string[] = [];
  if (!parsed.isSet) problems.push('not_a_set');
  if (parsed.dropped > 0) problems.push(`malformed_entries:${parsed.dropped}`);
  if (parsed.isSet && parsed.items.length !== ITEMS_PER_SET) problems.push(`wrong_count:${parsed.items.length}`);
  const n = (type: TopicItem['type']) => parsed.items.filter((i) => i.type === type).length;
  if (parsed.items.length === ITEMS_PER_SET && (n('sentence_writing') !== 2 || n('error_correction') !== 2 || n('fill_in_blank') !== 1)) {
    problems.push(`wrong_mix:${n('sentence_writing')}/${n('error_correction')}/${n('fill_in_blank')}`);
  }
  return { topicId, set, items: parsed.items, problems, passed: problems.length === 0 && parsed.items.every((i) => gateProblems(i).length === 0) };
}

// ---------------------------------------------------------------------------
// The key sentence

/** The built answers of one item, by kind. */
export interface ItemAnswers {
  key?: TopicAnswer;
  variant?: TopicAnswer;
}

export function answersByItem(answers: readonly TopicAnswer[]): Map<string, ItemAnswers> {
  const out = new Map<string, ItemAnswers>();
  for (const a of answers) {
    if (a.kind !== 'key' && a.kind !== 'variant') continue;
    const entry = out.get(a.itemId) ?? {};
    entry[a.kind] = a;
    out.set(a.itemId, entry);
  }
  return out;
}

/** The key as a full sentence: a fill_in_blank item's text with the key in
 * its blanks, else the key itself. */
export function keySentence(item: TopicItem, key: TopicAnswer): string {
  if (item.type !== 'fill_in_blank' || !key.fills) return key.userAnswer;
  let i = 0;
  return item.blankSource.replace(/_{2,}/g, () => {
    const fill = key.fills?.[i++] ?? '';
    return fill === '—' ? '' : fill;
  });
}

// ---------------------------------------------------------------------------
// 1. The item is about its topic

const PREPOSITIONS = new Set(
  'at on in to for from with about of by into onto over under between among through during since until till before after above below behind beside besides against across along around towards toward upon within without off out up down near despite throughout past'.split(
    ' ',
  ),
);
const ARTICLES = new Set(['a', 'an', 'the']);

const BE = "(?:am|is|are|was|were|be|been|being|get|gets|got|getting|[a-z]+'(?:s|re|m))";
const BETWEEN = "(?:\\s+(?:not|never|always|also|just|already|still|often|usually|now|currently|recently|finally|soon|being|been|[a-z]+ly))?".repeat(2);
const IRREGULAR_PARTICIPLES = new Set(
  'made built written given taken done seen known told sold sent held kept found paid said shown spoken stolen broken chosen driven eaten forgotten grown hidden thrown worn won taught caught bought brought thought left lost met put read run set cut hit hurt shut spent heard led laid born begun drawn drunk flown frozen sung sunk torn woken shot struck sought fed fought bent bound dealt dug hung lit meant rung risen shaken spread stuck sworn swept understood withdrawn overcome become come beaten bitten blown felt lent let quit rebuilt redone rewritten undone upset withheld mistaken forbidden forgiven hit split cast cost'.split(
    ' ',
  ),
);
const PASSIVE = new RegExp(`\\b${BE}${BETWEEN}\\s+([a-z]+)`, 'gi');

/** be (or get) + a past participle, with up to two adverbs between. */
export function hasPassive(text: string): boolean {
  const t = text.toLowerCase().replace(/[‘’]/g, "'");
  for (const m of t.matchAll(PASSIVE)) {
    const w = m[1] as string;
    if (IRREGULAR_PARTICIPLES.has(w) || (w.length > 3 && w.endsWith('ed'))) return true;
  }
  return false;
}

function isParticiple(word: string): boolean {
  return word === 'been' || IRREGULAR_PARTICIPLES.has(word) || (word.length > 3 && (word.endsWith('ed') || word.endsWith('en')));
}

const TOPIC_TERMS: Readonly<Record<string, RegExp>> = {
  conditionals: /\bconditionals?\b|\bif[- ]clause/i,
  passiveVoice: /\bpassive\b/i,
  prepositions: /\bprepositions?\b/i,
  relativeClauses: /\brelative (?:clause|pronoun)/i,
  comparativesSuperlatives: /\bcomparatives?\b|\bsuperlatives?\b/i,
  articles: /\barticles?\b/i,
};

const RELATIVE_AFTER_NOUN = /\b(?:the|a|an|this|that|these|those|my|your|his|her|its|our|their|some|any|every|each|one|two|many|several|[a-z]+'s)\s+(?:[a-z'-]+\s+){1,3}(?:that|where|when|why)\b/i;

const TOPIC_SIGNS: Readonly<Record<string, (sentence: string) => boolean>> = {
  conditionals: (s) => /\b(?:if|unless|provided|providing|supposing|otherwise|wish|wishes|wished)\b|\bas long as\b|\bin case\b|^\s*(?:had|were|should)\b[^?]*,/i.test(s),
  passiveVoice: hasPassive,
  prepositions: (s) => wordsOf(s).some((w) => PREPOSITIONS.has(w)),
  relativeClauses: (s) => (/\b(?:who|whom|whose|which)\b/i.test(s) && !/^\s*(?:who|whom|whose|which)\b[^.]*\?\s*$/i.test(s)) || /,\s*(?:where|when)\b/i.test(s) || RELATIVE_AFTER_NOUN.test(s),
  comparativesSuperlatives: (s) => /\b(?:than|more|most|less|least|better|best|worse|worst|further|farther|furthest|farthest)\b|\bas\s+[a-z]+\s+as\b|\bthe\s+[a-z]+est\b/i.test(s),
  articles: (s) => wordsOf(s).some((w) => ARTICLES.has(w)),
};

const CLOSED_CLASS: Readonly<Record<string, ReadonlySet<string>>> = { prepositions: PREPOSITIONS, articles: ARTICLES };

/**
 * No sign of the topic in the item: its text does not name the topic, and
 * the key (or, without one, the text) does not show the structure. For the
 * two closed-class topics a fill_in_blank or error_correction item must put
 * the word class into the blank or into the correction, which is stricter.
 * Null when there is no key and the text alone shows nothing (not run).
 */
export function checkTopic(item: TopicItem, answers: ItemAnswers): CheckFlag[] | null {
  const sign = TOPIC_SIGNS[item.topicId];
  const terms = TOPIC_TERMS[item.topicId];
  if (!sign || !terms) return [];
  const text = `${item.context ?? ''}\n${item.instruction}\n${item.hint ?? ''}`;
  if (terms.test(text)) return [];
  const flag = (detail: string): CheckFlag[] => [{ check: 'topic', code: 'no_sign_of_topic', detail }];
  const key = answers.key;
  if (!key) return sign(text) ? [] : null;
  const closed = CLOSED_CLASS[item.topicId];
  if (closed && item.type === 'fill_in_blank' && key.fills) {
    const inBlank = key.fills.some((f) => f === '—' || wordsOf(f).some((w) => closed.has(w)));
    return inBlank ? [] : flag(`no blank takes the topic's word class; key: ${key.fills.join(' / ')}`);
  }
  if (closed && item.type === 'error_correction' && item.context) {
    const { removed, added } = changedWords(item.context, key.userAnswer);
    const touched = [...removed, ...added].some((w) => closed.has(w));
    return touched ? [] : flag(`the correction changes ${[...removed, '→', ...added].join(' ') || 'nothing'}, not the topic's word class`);
  }
  return sign(keySentence(item, key)) || sign(text) ? [] : flag('neither the text nor the key shows the structure');
}

// ---------------------------------------------------------------------------
// 2. A blank has one natural answer

const PLACES_IN_OR_AT = new Set('office station airport school university college hospital restaurant hotel cinema library shop supermarket bank gym theatre theater cafe café museum mall pool stadium'.split(' '));
const PERIODS_IN_OR_DURING = new Set('summer winter spring autumn fall holidays holiday vacation night day week month year morning afternoon evening meeting lesson class flight trip journey war'.split(' '));
const SUBJECT_AFTER_OBJECT_PRONOUN = new Set('i you he she we they it my your his her our their the a an this that these those'.split(' '));
const FREE_VARIANTS: readonly (readonly string[])[] = [
  ['till', 'until'],
  ['toward', 'towards'],
  ['round', 'around'],
  ['among', 'amongst'],
  ['farther', 'further'],
  ['farthest', 'furthest'],
  ['elder', 'older'],
  ['eldest', 'oldest'],
  ['provided', 'providing'],
];
/** Adjectives that take both -er / -est and more / most. */
const BOTH_COMPARATIVE_FORMS = new Set('clever simple quiet narrow common polite gentle friendly likely pleasant handsome cruel stupid shallow lively lonely sincere mature remote secure obscure'.split(' '));
const TIME_MARKERS =
  /\b(?:yesterday|tomorrow|ago|last|next|now|currently|every|always|usually|often|since|already|yet|just|recently|soon|nowadays|today|tonight|still|when|while|before|after|by the time|at the moment|so far|these days|in \d{4}|in the (?:past|future)|for (?:\w+ )?(?:years|months|weeks|days|hours|centuries|decades))\b/i;
const VERB_HINT = /\(\s*(?:to\s+)?[a-z]+(?:\s+[a-z]+)?\s*\)/i;

function stem(word: string): string {
  return word.replace(/iest$|ier$/, 'y').replace(/est$|er$/, '');
}

interface BlankInContext {
  fill: string;
  /** Lower-cased text before and after the blank, to the line's ends. */
  before: string;
  after: string;
}

function blanksInContext(item: TopicItem, fills: readonly string[]): BlankInContext[] {
  const out: BlankInContext[] = [];
  const pattern = /_{2,}/g;
  let i = 0;
  for (let m = pattern.exec(item.blankSource); m !== null; m = pattern.exec(item.blankSource)) {
    const lineStart = item.blankSource.lastIndexOf('\n', m.index) + 1;
    const lineEnd = item.blankSource.indexOf('\n', m.index);
    out.push({
      fill: (fills[i++] ?? '').toLowerCase(),
      before: item.blankSource.slice(lineStart, m.index).toLowerCase(),
      after: item.blankSource.slice(m.index + m[0].length, lineEnd < 0 ? undefined : lineEnd).toLowerCase(),
    });
  }
  return out;
}

/** The reason more than one answer may fit this blank, or null. */
export function severalAnswersRisk(topicId: string, blank: BlankInContext): string | null {
  const { fill, before, after } = blank;
  const next = wordsOf(after).slice(0, 4);
  const previous = wordsOf(before).slice(-3);
  const free = FREE_VARIANTS.find((g) => g.includes(fill));
  if (free) return `${free.join(' / ')} are free variants`;

  if (topicId === 'relativeClauses' && ['who', 'which', 'that', 'whom'].includes(fill)) {
    if (/,\s*$/.test(before)) return fill === 'whom' ? 'who / whom after a comma' : null;
    const omit = next[0] !== undefined && SUBJECT_AFTER_OBJECT_PRONOUN.has(next[0]) ? ', and the pronoun can be left out (it is the object)' : '';
    if (fill === 'whom') return `whom / who / that in a defining clause${omit}`;
    return `${fill === 'which' ? 'which / that' : fill === 'who' ? 'who / that' : 'that / who / which'} both fit a defining clause${omit}`;
  }
  if (topicId === 'relativeClauses' && fill === 'where' && !/,\s*$/.test(before)) return 'where / in which (at which) both fit';

  if (topicId === 'prepositions') {
    if ((fill === 'in' || fill === 'at') && next.some((w) => PLACES_IN_OR_AT.has(w))) return 'in / at both fit this place';
    if ((fill === 'on' || fill === 'at') && next.some((w) => w === 'weekend' || w === 'weekends')) return 'at / on the weekend (British / American)';
    if ((fill === 'in' || fill === 'on') && next.some((w) => ['street', 'road', 'team', 'weekend'].includes(w))) return 'in / on both occur here';
    if ((fill === 'in' || fill === 'during') && next.some((w) => PERIODS_IN_OR_DURING.has(w))) return 'in / during both fit this period';
    if ((fill === 'about' || fill === 'on') && previous.some((w) => ['book', 'lecture', 'report', 'talk', 'article', 'presentation', 'documentary', 'course'].includes(w))) return 'about / on both fit after this noun';
    if ((fill === 'about' || fill === 'of') && previous.some((w) => ['think', 'thinking', 'thought', 'hear', 'heard', 'dream', 'dreamed', 'dreamt', 'dreaming'].includes(w))) return 'about / of both follow this verb';
  }

  if (topicId === 'conditionals') {
    if ((fill === 'was' || fill === 'were') && /\bif\s+(?:i|he|she|it)\s*$/.test(before)) return 'was / were after "if I / he / she / it"';
    if (['would', 'could', 'might'].includes(fill)) return 'would / could / might can all open the result clause';
    if ((fill === 'if' || fill === 'when') && !/\b(?:will|would|won't|wouldn't|'ll|'d)\b/.test(`${before} ${after}`)) return 'if / when both fit a general truth';
  }

  // The learner chooses the tense of "be" (the fill has it), the verb is
  // given in brackets, and nothing in the sentence fixes the time.
  if (topicId === 'passiveVoice' && /\b(?:am|is|are|was|were|be|been|being)\b/.test(fill) && VERB_HINT.test(`${before} ${after}`) && !TIME_MARKERS.test(`${before} ${after}`)) {
    return 'no time marker in the sentence: more than one tense of the passive fits';
  }

  if (topicId === 'comparativesSuperlatives') {
    const ws = wordsOf(fill);
    const last = ws[ws.length - 1] ?? '';
    const periphrastic = ws.length >= 2 && ['more', 'most'].includes(ws[ws.length - 2] as string) && BOTH_COMPARATIVE_FORMS.has(last);
    const inflected = /(?:er|est)$/.test(last) && (BOTH_COMPARATIVE_FORMS.has(stem(last)) || BOTH_COMPARATIVE_FORMS.has(`${stem(last)}e`));
    if (periphrastic || inflected) return `"${last}" takes both -er / -est and more / most`;
  }
  return null;
}

/**
 * fill_in_blank only: the writer found a second correct answer, or a blank's
 * key is a word a known alternative competes with. Null without a key.
 */
export function checkSingleAnswer(item: TopicItem, answers: ItemAnswers): CheckFlag[] | null {
  if (item.type !== 'fill_in_blank') return [];
  const key = answers.key;
  if (!key?.fills) return null;
  const flags: CheckFlag[] = [];
  const variant = answers.variant?.fills;
  if (variant) flags.push({ check: 'single_answer', code: 'second_answer_listed', detail: `key: ${key.fills.join(' / ')}; also correct: ${variant.join(' / ')}` });
  blanksInContext(item, key.fills).forEach((blank, i) => {
    const risk = severalAnswersRisk(item.topicId, blank);
    if (risk) flags.push({ check: 'single_answer', code: 'several_answers_fit', detail: `blank ${i + 1} ("${blank.fill}"): ${risk}` });
  });
  return flags;
}

// ---------------------------------------------------------------------------
// 3. Duplicates and near-duplicates

const STOPWORDS = new Set(
  'a an the and or but so if of to in on at for from with by about as is are was were be been being am do does did have has had will would can could should may might must not no it its this that these those i you he she we they me him her us them my your his our their one write rewrite sentence find mistake full corrected correct using use fill blank each word form verb brackets complete'.split(
    ' ',
  ),
);

/** The words that carry an item's scenario: an error_correction item's
 * sentence, otherwise its whole text, without function words and the stock
 * words of instructions. */
export function scenarioWords(item: Pick<TopicItem, 'type' | 'context' | 'instruction'>): Set<string> {
  const text = item.type === 'error_correction' && item.context ? item.context : `${item.context ?? ''} ${item.instruction}`;
  return new Set(wordsOf(text).filter((w) => w.length > 2 && !STOPWORDS.has(w)));
}

export function jaccard(a: ReadonlySet<string>, b: ReadonlySet<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let shared = 0;
  for (const w of a) if (b.has(w)) shared++;
  return shared / (a.size + b.size - shared);
}

/** At or above this share of common scenario words two items are "near". */
export const NEAR_DUPLICATE_SIMILARITY = 0.6;
/** Below this many scenario words an item is too short to compare. */
const MIN_SCENARIO_WORDS = 4;

/**
 * Per item, its duplicates among the same topic's items: the same words
 * (`duplicate_…`) or mostly the same scenario words (`near_duplicate_…`),
 * `…in_set` or `…across_sets`. Each pair is flagged on both items.
 */
export function findDuplicates(items: readonly TopicItem[]): Map<string, CheckFlag[]> {
  const out = new Map<string, CheckFlag[]>();
  const add = (id: string, flag: CheckFlag) => out.set(id, [...(out.get(id) ?? []), flag]);
  const prepared = items.map((item) => ({ item, text: wordsOf(item.prompt).join(' '), words: scenarioWords(item) }));
  for (let i = 0; i < prepared.length; i++) {
    for (let j = i + 1; j < prepared.length; j++) {
      const a = prepared[i] as (typeof prepared)[number];
      const b = prepared[j] as (typeof prepared)[number];
      if (a.item.topicId !== b.item.topicId) continue;
      const same = a.text === b.text;
      const similarity = jaccard(a.words, b.words);
      const near = !same && a.item.type === b.item.type && Math.min(a.words.size, b.words.size) >= MIN_SCENARIO_WORDS && similarity >= NEAR_DUPLICATE_SIMILARITY;
      if (!same && !near) continue;
      const where = a.item.set === b.item.set ? 'in_set' : 'across_sets';
      const code = `${same ? 'duplicate' : 'near_duplicate'}_${where}`;
      const detail = (other: TopicItem) => `${same ? 'same words as' : `${Math.round(similarity * 100)} % of the scenario words shared with`} ${other.id}`;
      add(a.item.id, { check: 'duplicate', code, detail: detail(b.item) });
      add(b.item.id, { check: 'duplicate', code, detail: detail(a.item) });
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// 4. Length and level

/** The proxy's limits on a scoring request (`validation.ts`): an item whose
 * text or id passes them cannot be scored at all. */
export const MAX_PROMPT_LENGTH = 2_000;
export const MAX_ITEM_ID_LENGTH = 100;
/** Level proxies for B1-C1 (decision T-6): a sentence longer than this many
 * words, or this many words of 15 letters or more in one item. */
export const MAX_SENTENCE_WORDS = 35;
export const LONG_WORD_LETTERS = 15;
export const MAX_LONG_WORDS = 2;

function sentencesOf(text: string): string[] {
  return text
    .split(/(?<=[.!?])\s+|\n+/)
    .map((s) => s.trim())
    .filter((s) => /[a-z]/i.test(s));
}

/** Length against the existing limits, and the level proxies. The edit limit
 * of an error correction needs the key; without one that part is skipped. */
export function checkLengthLevel(item: TopicItem, answers: ItemAnswers): CheckFlag[] {
  const flags: CheckFlag[] = [];
  const flag = (code: string, detail: string) => flags.push({ check: 'length_level', code, detail });
  if (item.prompt.length > MAX_PROMPT_LENGTH) flag('text_over_2000_characters', `${item.prompt.length} characters: the proxy would reject its scoring request`);
  if (item.sourceId.length > MAX_ITEM_ID_LENGTH) flag('id_over_100_characters', `${item.sourceId.length} characters`);
  if (item.type !== 'fill_in_blank' && sentencesOf(item.instruction).length > 1) flag('instruction_not_one_sentence', `${sentencesOf(item.instruction).length} sentences (the prompt asks for one)`);
  const sentences = sentencesOf(`${item.context ?? ''}\n${item.instruction}`);
  const longest = sentences.reduce((n, s) => Math.max(n, wordsOf(s).length), 0);
  if (longest > MAX_SENTENCE_WORDS) flag('sentence_over_35_words', `${longest} words`);
  const long = [...new Set(wordsOf(item.prompt).filter((w) => w.replace(/'/g, '').length >= LONG_WORD_LETTERS))];
  if (long.length >= MAX_LONG_WORDS) flag('several_very_long_words', long.join(', '));
  const key = answers.key;
  if (item.type === 'error_correction' && item.context && key) {
    const original = wordsOf(item.context).join(' ');
    const corrected = wordsOf(key.userAnswer).join(' ');
    if (original !== corrected && !isSingleShortEdit(original, corrected)) {
      flag('correction_over_4_words', `the key changes more than one run of ${ERROR_CORRECTION_MAX_EDIT_WORDS} words: more than one mistake, or a rewrite`);
    }
  }
  return flags;
}

// ---------------------------------------------------------------------------
// 5. The hint card's rule agrees with the key

/**
 * The app's hint cards for the measured topics, copied from
 * `lib/data/topic_hints.dart` (`kTopicHints`); `test/eval_topics_checks.test.ts`
 * fails when a copy and the Dart source differ.
 */
export const HINT_CARDS: Readonly<Record<string, readonly string[]>> = {
  articles: ['a / an: one of many, or first mention', 'an before a vowel sound: an hour', 'the: specific, known, or the only one', 'No article: general plural or uncountable'],
  conditionals: ['If + present, will + verb: real future', 'If + past, would + verb: unreal now', 'If + had + p.p., would have + p.p.: past', 'No "will" or "would" in the if-part'],
  passiveVoice: ['be + past participle: is made, was built', 'The tense lives in "be": is / was / has been', 'by + doer, only when it matters', 'Modal passive: can be done, must be paid'],
  prepositions: ['at: a point (at 5, at the door)', 'on: a surface or a day (on Monday)', 'in: inside or a period (in May, in 2020)', 'Verb + preposition: depend on, listen to'],
  relativeClauses: ['who: people · which: things · that: both', 'whose: belonging (the man whose car…)', 'where / when: places and times', 'Commas: extra info, no "that"'],
  comparativesSuperlatives: ['Short: -er / the -est (tall, the tallest)', 'Long: more / the most (more useful)', 'Irregular: good → better → the best', 'than after a comparative; the before -est'],
};

const DAYS = new Set('monday tuesday wednesday thursday friday saturday sunday mondays tuesdays wednesdays thursdays fridays saturdays sundays'.split(' '));
/** "may" too: right after at / on / in it is the month, not the modal. */
const MONTHS = new Set('january february march april may june july august september october november december'.split(' '));
const VOWEL_LETTER_CONSONANT_SOUND = /^(?:uni|use|usu|uti|eu|one|once|ub|ur[aeiou]|u[sk]\b|ufo)/;
const CONSONANT_LETTER_VOWEL_SOUND = /^(?:hour|honest|honou?r|heir|mba|mp3|fbi|x-ray|xray|sms|nhs|mri|hr\b|sos)/;

/** Words in -er / -est that are not comparatives or superlatives. */
const NOT_COMPARATIVE = new Set(
  'other another never ever after over under water paper number together however whether rather either neither teacher mother father brother sister daughter summer winter dinner computer manager customer member answer remember consider offer order center centre letter matter power flower tower shower corner border leader reader writer driver player worker farmer lawyer officer partner partner neighbour neighbor weather leather feather together december november october september later former proper eager clever bitter tender sober sinister interest forest honest modest request suggest protest harvest contest invest digest arrest guest quest chest priest earnest dishonest forester poster master sister minister register character chapter quarter soccer cancer danger finger hunger anger butter laptop wonder gender tender deliver discover cover recover prefer refer differ suffer enter alter utter'.split(
    ' ',
  ),
);
const SUPERLATIVE_DETERMINERS = new Set('the my your his her its our their whose at'.split(' '));

type CardRule = (sentence: string) => { conflict?: string; silent?: string };

function ifPart(sentence: string): string | null {
  const m = /\bif\b([^,.;?!]*)/i.exec(sentence);
  return m ? (m[1] as string) : null;
}

const CARD_RULES: Readonly<Record<string, CardRule>> = {
  conditionals: (s) => {
    const part = ifPart(s);
    if (part === null) return { silent: 'the key has no "if": the card speaks of if-sentences only (unless, wish, inversion…)' };
    const lower = part.toLowerCase().replace(/[\u2018\u2019]/g, "'");
    if (/\b(?:will|would|won't|wouldn't)\b|'ll\b/.test(lower)) return { conflict: `line 4 (${HINT_CARDS.conditionals?.[3]}): the key's if-part has will / would` };
    const rest = s.toLowerCase().replace(/[\u2018\u2019]/g, "'").replace(lower, ' ');
    const hadParticiple = [...lower.matchAll(/\bhad(?:n't)?\s+(?:not\s+|never\s+|already\s+)?([a-z]+)/g)].some((m) => isParticiple(m[1] as string));
    if (hadParticiple && /\bwill\b|\bwon't\b|'ll\b/.test(rest)) return { conflict: `line 3 (${HINT_CARDS.conditionals?.[2]}): if + had + participle with "will"` };
    if (hadParticiple && /\bwould\b|\bwouldn't\b|'d\b/.test(rest) && !/\bwould(?:n't|\s+not|\s+never)?\s+have\b|\bwould've\b/.test(rest)) {
      return { silent: 'a mixed conditional (if + had + participle, would + verb): no line of the card has it' };
    }
    if (!/\b(?:will|would|won't|wouldn't|can|can't|could|couldn't|may|might|should|shouldn't|must|shall)\b|'ll\b|'d\b/.test(rest)) {
      return { silent: 'no will / would in the result (a general truth or an instruction): no line of the card has it' };
    }
    return {};
  },
  passiveVoice: (s) => (hasPassive(s) ? {} : { silent: 'the key has no be + past participle: the card does not apply' }),
  prepositions: (s) => {
    const tokens = wordsOf(
      s
        .replace(/\b\d{1,2}:\d{2}\b(?:\s*(?:am|pm|a\.m\.|p\.m\.))?|\b\d{1,2}\s*(?:am|pm|a\.m\.|p\.m\.|o['\u2019]clock)/gi, ' clocktime ')
        .replace(/\b(?:1[5-9]|20)\d{2}\b/g, ' yearnumber '),
    );
    for (let i = 0; i < tokens.length - 1; i++) {
      const prep = tokens[i] as string;
      if (prep !== 'at' && prep !== 'on' && prep !== 'in') continue;
      const next = tokens[i + 1] === 'the' ? tokens[i + 2] : tokens[i + 1];
      if (next === undefined) continue;
      const cards = DAYS.has(next) ? 'on' : MONTHS.has(next) || next === 'yearnumber' ? 'in' : next === 'clocktime' ? 'at' : null;
      if (cards && cards !== prep) {
        const line = cards === 'on' ? 1 : cards === 'in' ? 2 : 0;
        return { conflict: `line ${line + 1} (${HINT_CARDS.prepositions?.[line]}): the key has "${prep} ${next === 'yearnumber' ? 'a year' : next === 'clocktime' ? 'a clock time' : next}"` };
      }
    }
    return {};
  },
  relativeClauses: (s) => {
    if (/,\s*that\b/i.test(s) && !/\b(?:so|such|said|say|says|think|thought|believe|believed|know|knew|fact|is|was)\s*,\s*that\b/i.test(s)) return { conflict: `line 4 (${HINT_CARDS.relativeClauses?.[3]}): the key has "that" after a comma` };
    if (/\bwhom\b/i.test(s)) return { silent: '"whom" is on no line of the card' };
    if (!/\b(?:who|which|that|whose|where|when)\b/i.test(s)) return { silent: 'the key has none of the card\'s words (who, which, that, whose, where, when)' };
    return {};
  },
  comparativesSuperlatives: (s) => {
    const lower = s.toLowerCase().replace(/[\u2018\u2019]/g, "'");
    const tokens = wordsOf(lower);
    for (let i = 1; i < tokens.length; i++) {
      const word = tokens[i] as string;
      if ((tokens[i - 1] === 'more' || tokens[i - 1] === 'most') && /(?:er|est)$/.test(word) && word.length > 4 && !NOT_COMPARATIVE.has(word)) {
        return { conflict: `lines 1-2: the key has "${tokens[i - 1]} ${word}" (more / most together with -er / -est)` };
      }
    }
    for (let i = 0; i < tokens.length; i++) {
      const word = tokens[i] as string;
      const superlative = word === 'best' || word === 'worst' || (/est$/.test(word) && word.length > 4 && !NOT_COMPARATIVE.has(word));
      if (!superlative) continue;
      const before = tokens.slice(Math.max(0, i - 3), i);
      if (!before.some((w) => SUPERLATIVE_DETERMINERS.has(w) || w.endsWith("'s"))) {
        return { conflict: `line 4 (${HINT_CARDS.comparativesSuperlatives?.[3]}): the key has "${word}" without "the"` };
      }
    }
    if (!/\b(?:than|more|most|better|best|worse|worst)\b/.test(lower) && !tokens.some((w) => /(?:er|est)$/.test(w) && w.length > 4 && !NOT_COMPARATIVE.has(w))) {
      return { silent: 'the key has no -er / -est, more / most or than (as … as, less…): no line of the card has it' };
    }
    return {};
  },
  articles: (s) => {
    const tokens = s.toLowerCase().replace(/[‘’]/g, "'").match(/[a-z0-9][a-z0-9'-]*/g) ?? [];
    for (let i = 0; i < tokens.length - 1; i++) {
      const article = tokens[i];
      const next = tokens[i + 1] as string;
      if (article !== 'a' && article !== 'an') continue;
      const vowelSound = (/^[aeiou]/.test(next) && !VOWEL_LETTER_CONSONANT_SOUND.test(next)) || CONSONANT_LETTER_VOWEL_SOUND.test(next) || /^(?:8|11\b|18\b)/.test(next);
      if ((article === 'an') !== vowelSound) return { conflict: `line 2 (${HINT_CARDS.articles?.[1]}): the key has "${article} ${next}"` };
    }
    return {};
  },
};

/**
 * The key against the topic's hint card: `card_conflict` when the key does
 * what a line of the card says not to (or the opposite of what it says),
 * `card_silent` when the card has no line for the key's structure. Null
 * without a key.
 */
export function checkHintCard(item: TopicItem, answers: ItemAnswers): CheckFlag[] | null {
  const rule = CARD_RULES[item.topicId];
  if (!rule) return [];
  if (!answers.key) return null;
  const { conflict, silent } = rule(keySentence(item, answers.key));
  if (conflict) return [{ check: 'hint_card', code: 'card_conflict', detail: conflict }];
  if (silent) return [{ check: 'hint_card', code: 'card_silent', detail: silent }];
  return [];
}

// ---------------------------------------------------------------------------
// Every check, per item

export interface ItemCheckRecord {
  itemId: string;
  topicId: string;
  set: number;
  index: number;
  type: TopicItem['type'];
  /** The gate's item-level problems; empty when the item passed. */
  gate: string[];
  flags: CheckFlag[];
  /** Checks that need the key and had none. */
  notRun: CheckId[];
}

export function checkItems(items: readonly TopicItem[], answers: readonly TopicAnswer[]): ItemCheckRecord[] {
  const byItem = answersByItem(answers);
  const duplicates = findDuplicates(items);
  return items.map((item) => {
    const mine = byItem.get(item.id) ?? {};
    const flags: CheckFlag[] = [];
    const notRun: CheckId[] = [];
    const take = (check: CheckId, result: CheckFlag[] | null) => {
      if (result === null) notRun.push(check);
      else flags.push(...result);
    };
    take('topic', checkTopic(item, mine));
    take('single_answer', checkSingleAnswer(item, mine));
    take('duplicate', duplicates.get(item.id) ?? []);
    take('length_level', checkLengthLevel(item, mine));
    take('hint_card', checkHintCard(item, mine));
    return { itemId: item.id, topicId: item.topicId, set: item.set, index: item.index, type: item.type, gate: gateProblems(item), flags, notRun };
  });
}

export interface TopicCheckSummary {
  topicId: string;
  items: number;
  gateFailed: number;
  /** Items with at least one flag of the check. */
  flagged: Record<CheckId, number>;
  notRun: Record<CheckId, number>;
}

/** Per topic: how many items each check flagged, for the run's summary. */
export function summarizeChecks(records: readonly ItemCheckRecord[]): TopicCheckSummary[] {
  const zero = () => Object.fromEntries(CHECK_IDS.map((c) => [c, 0])) as Record<CheckId, number>;
  const out = new Map<string, TopicCheckSummary>();
  for (const r of records) {
    const s = out.get(r.topicId) ?? { topicId: r.topicId, items: 0, gateFailed: 0, flagged: zero(), notRun: zero() };
    s.items++;
    if (r.gate.length > 0) s.gateFailed++;
    for (const check of CHECK_IDS) {
      if (r.flags.some((f) => f.check === check)) s.flagged[check]++;
      if (r.notRun.includes(check)) s.notRun[check]++;
    }
    out.set(r.topicId, s);
  }
  return [...out.values()];
}

export function renderCheckSummary(summaries: readonly TopicCheckSummary[]): string {
  return [
    '| Topic | Items | Gate failed | Topic | One answer | Duplicate | Length / level | Hint card |',
    '|---|---|---|---|---|---|---|---|',
    ...summaries.map((s) => `| ${s.topicId} | ${s.items} | ${s.gateFailed} | ${CHECK_IDS.map((c) => `${s.flagged[c]}${s.notRun[c] > 0 ? ` (${s.notRun[c]} not run)` : ''}`).join(' | ')} |`),
  ].join('\n');
}
