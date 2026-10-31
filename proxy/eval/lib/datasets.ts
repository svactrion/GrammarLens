import type { SharedQuestion } from '../../src/shared_daily_test';
import { buildLabelSheet, seededRandom, toCsv, type LabelItem } from './labels';

/**
 * The labelled test sets of the 1.4.0 server package measurement
 * (docs/1.4.0-server-batch0-report.md §3.1), built from inputs that live in
 * the repo: the fallback pool (owner-reviewed, 10 corrections), the live sets
 * exported read-only from KV (`eval/data/live-sets/`), and a handful of
 * multi-blank practice items from the app's debug sets. Pure: no network, no
 * files; `eval/run.ts sets` reads the inputs and writes `eval/data/`.
 *
 * Sets:
 * - S-pool (scoring): every pool question with its key, its owner-accepted
 *   answers and its predicted wrong answers as labelled learner answers.
 * - S-pool (gate): the same seven dates as the cron published them, with the
 *   owner's corrections as the truth a checker should rediscover.
 * - S-live: the prompt-v2 live sets the owner has not reviewed, as a blind
 *   label sheet (one row per question, random keys, shuffled).
 * - S-synth: learner answers of known quality written by rule: keyboard
 *   variants per language family, contractions and spelling variants, partial
 *   multi-blank answers, and near-misses that are real mistakes.
 * - S-gen and S-free: sheet templates, filled after the generation calls.
 */

// ---------------------------------------------------------------------------
// Shapes

export type ScoredItemType = 'fill_in_blank' | 'error_correction' | 'sentence_writing';

/** One scoring request item, exactly as the app sends it (`validation.ts`). */
export interface ScoringItem {
  id: string;
  type: ScoredItemType;
  /** `PracticeItem.fullText`: the context, a newline, the instruction. */
  prompt: string;
}

/** Per-blank truth of a multi-blank answer, in blank order. `user` is the
 * box's text, `''` for a box left empty; `noArticle` for the "—" box. */
export interface BlankTruth {
  index: number;
  correct: string;
  user: string;
  noArticle?: boolean;
  accepted: boolean;
}

/** A learner answer whose verdict is known. */
export interface LabelledAnswer {
  /** Unique across the sets: `<set>:<question>:<kind>[:n]`. */
  id: string;
  set: 'S-pool' | 'S-synth';
  item: ScoringItem;
  /** The wire `userAnswer`: a single box's text, or the assembled sentence. */
  userAnswer: string;
  /** What the scorer should say for `isCorrect`. */
  truth: boolean;
  /** Why the answer is in the set: `key`, `accepted`, `predicted_wrong`,
   * `kb:<class>`, `contraction`, `spelling`, `partial:<case>`,
   * `nearmiss:<rule>`. */
  kind: string;
  /** The key, for the report's reader. */
  correctAnswer: string;
  blanks?: BlankTruth[];
  /** Flagged for the owner's review (S-synth only). */
  review?: string;
}

/** A pool question's owner corrections, as the gate measurement's truth. */
export interface GateTruth {
  date: string;
  questionId: string;
  /** Answers the owner accepts besides the key (`addAcceptedAnswers`). */
  acceptAlso: string[];
  /** Predicted wrong answers the owner moved into the accepted ones. */
  movedFromWrong: string[];
  /** Whether the owner removed the hint. */
  hintRemoved: boolean;
}

export interface PoolCorrection {
  date: string;
  question: number;
  reason?: string;
  removeHint?: boolean;
  removeWrongAnswers?: string[];
  addAcceptedAnswers?: string[];
}

export interface LiveSetFile {
  date: string;
  promptVersion: number;
  generatedAt?: string;
  attempt?: number;
  questions: SharedQuestion[];
}

/** A multi-blank practice item with its per-blank key, from the app's debug
 * sets (`lib/utils/debug_practice_sets.dart`); the keys are the obvious
 * ones and the owner reviews them with S-synth. */
export interface MultiBlankItem {
  id: string;
  topicId: string;
  context: string;
  instruction: string;
  /** One entry per blank: the typed form, or `null` for "no article". */
  keys: (string | null)[];
}

// ---------------------------------------------------------------------------
// Inputs that are constants

/** The pool's seven sets in order, as published (`tool/fallback_pool`,
 * fb01 … fb07). */
export const POOL_DATES = [
  '2026-09-30',
  '2026-10-01',
  '2026-10-02',
  '2026-10-03',
  '2026-10-04',
  '2026-10-05',
  '2026-10-06',
] as const;

export const MULTI_BLANK_ITEMS: readonly MultiBlankItem[] = [
  {
    id: 'debug_articles_2',
    topicId: 'articles',
    context: '____ honesty matters to her, so she gave me ____ honest answer.',
    instruction: 'Fill in each blank with a, an or the, or tap — for no article.',
    keys: [null, 'an'],
  },
  {
    id: 'debug_articles_3',
    topicId: 'articles',
    context: 'We had ____ lunch at ____ small café near ____ station.',
    instruction: 'Fill in each blank with a, an or the, or tap — for no article.',
    keys: [null, 'a', 'the'],
  },
  {
    id: 'debug_articles_4',
    topicId: 'articles',
    context: '____ sun was setting when ____ old man sat down on ____ bench and opened ____ newspaper.',
    instruction: 'Fill in each blank with a, an or the, or tap — for no article.',
    keys: ['The', 'an', 'a', 'a'],
  },
  {
    id: 'debug_gerund_2',
    topicId: 'gerundVsInfinitive',
    context: 'I enjoy ____ (swim), but this year I have decided ____ (learn) tennis.',
    instruction: 'Fill in each blank with the right form of the verb.',
    keys: ['swimming', 'to learn'],
  },
  {
    id: 'debug_gerund_3',
    topicId: 'gerundVsInfinitive',
    context: 'She stopped ____ (smoke) last year, she avoids ____ (go) to smoky bars, and she plans ____ (run) a marathon.',
    instruction: 'Fill in each blank with the right form of the verb.',
    keys: ['smoking', 'going', 'to run'],
  },
];

// ---------------------------------------------------------------------------
// Helpers shared with the app's behaviour

const BLANK = /_{2,}/g;

export function fullText(context: string | undefined, instruction: string): string {
  return context === undefined || context.trim().length === 0 ? instruction : `${context}\n${instruction}`;
}

/**
 * The app's `assembleBlanks` (lib/utils/blank_assembly.dart) for the cases the
 * synthetic set needs: each box's text put into its blank; a "no article" box
 * removes its blank and the space after it, capitalising the next word when
 * the blank began the sentence; an empty box keeps its blank.
 */
export function assembleBlanks(text: string, answers: readonly { text: string; noArticle?: boolean }[]): string {
  const blanks = [...text.matchAll(BLANK)].map((m) => ({ start: m.index ?? 0, end: (m.index ?? 0) + m[0].length }));
  if (!answers.some((a) => a.noArticle || a.text.trim().length > 0)) return '';
  let result = text;
  for (let i = blanks.length - 1; i >= 0; i--) {
    const blank = blanks[i] as { start: number; end: number };
    const answer = answers[i] ?? { text: '' };
    if (answer.noArticle) {
      const sentenceStart = startsSentence(result, blank.start);
      let next: number;
      if (result[blank.end] === ' ') {
        result = result.slice(0, blank.start) + result.slice(blank.end + 1);
        next = blank.start;
      } else if (blank.start > 0 && result[blank.start - 1] === ' ') {
        result = result.slice(0, blank.start - 1) + result.slice(blank.end);
        next = blank.start - 1;
      } else {
        result = result.slice(0, blank.start) + result.slice(blank.end);
        next = blank.start;
      }
      if (sentenceStart) {
        while (next < result.length && ' "“‘('.includes(result[next] as string)) next++;
        if (next < result.length) {
          result = result.slice(0, next) + (result[next] as string).toUpperCase() + result.slice(next + 1);
        }
      }
    } else if (answer.text.trim().length > 0) {
      result = result.slice(0, blank.start) + answer.text.trim() + result.slice(blank.end);
    }
  }
  return result;
}

function startsSentence(text: string, start: number): boolean {
  let i = start - 1;
  while (i >= 0 && text[i] === ' ') i--;
  if (i < 0) return true;
  const ch = text[i] as string;
  return '"“‘(\n.?!'.includes(ch);
}

// ---------------------------------------------------------------------------
// S-pool

function poolQuestionDate(id: string): string | undefined {
  const m = /^fb(\d\d)_/.exec(id);
  if (!m) return undefined;
  return POOL_DATES[Number(m[1]) - 1];
}

function poolItem(q: SharedQuestion): ScoringItem {
  return { id: q.id, type: q.type, prompt: fullText(q.context, q.instruction) };
}

/** Every pool question's key, accepted answers and predicted wrong answers as
 * labelled learner answers, in pool order. */
export function buildPoolScoring(pool: { sets: { questions: SharedQuestion[] }[] }): LabelledAnswer[] {
  const out: LabelledAnswer[] = [];
  for (const set of pool.sets) {
    for (const q of set.questions) {
      const item = poolItem(q);
      const base = { set: 'S-pool' as const, item, correctAnswer: q.correctAnswer };
      out.push({ ...base, id: `pool:${q.id}:key`, userAnswer: q.correctAnswer, truth: true, kind: 'key' });
      (q.acceptedAnswers ?? []).forEach((a, i) => {
        out.push({ ...base, id: `pool:${q.id}:accepted:${i + 1}`, userAnswer: a, truth: true, kind: 'accepted' });
      });
      q.commonWrongAnswers.forEach((w, i) => {
        out.push({ ...base, id: `pool:${q.id}:wrong:${i + 1}`, userAnswer: w.answer, truth: false, kind: 'predicted_wrong' });
      });
    }
  }
  return out;
}

/** The owner's corrections as the gate's truth, one entry per corrected
 * question, keyed by the live set's date and the question's id in it. */
export function buildPoolGate(liveSets: readonly LiveSetFile[], corrections: readonly PoolCorrection[]): GateTruth[] {
  const out: GateTruth[] = [];
  for (const c of corrections) {
    const set = liveSets.find((s) => s.date === c.date);
    const q = set?.questions[c.question - 1];
    if (!q) throw new Error(`correction ${c.date} q${c.question}: no such live question in eval/data/live-sets`);
    out.push({
      date: c.date,
      questionId: q.id,
      acceptAlso: [...(c.addAcceptedAnswers ?? [])],
      movedFromWrong: [...(c.removeWrongAnswers ?? [])],
      hintRemoved: c.removeHint === true,
    });
  }
  return out;
}

// ---------------------------------------------------------------------------
// S-live

/** The live sets S-live labels: prompt v2, not in the pool (the owner has
 * labelled those), in date order. */
export function selectLiveSets(liveSets: readonly LiveSetFile[]): LiveSetFile[] {
  const pool = new Set<string>(POOL_DATES);
  return [...liveSets].filter((s) => s.promptVersion >= 2 && !pool.has(s.date)).sort((a, b) => a.date.localeCompare(b.date));
}

/** Keys that no spreadsheet reads as a number: a letter, then seven hex
 * digits. */
export function keyFactory(random: () => number): () => string {
  return () => `k${Math.floor(random() * 0xfffffff).toString(16).padStart(7, '0')}`;
}

export const S_LIVE_SEED = 20261031;

/** The blind sheet and its mapping, deterministic for [seed] so a rebuild
 * never changes a sheet the owner has started. */
export function buildLiveSheet(sets: readonly LiveSetFile[], seed = S_LIVE_SEED): { csv: string; mapping: Record<string, unknown>; rows: number } {
  const items: LabelItem[] = sets.flatMap((s) => s.questions.map((q) => ({ source: 'S-live', date: s.date, questionId: q.id, question: q })));
  const random = seededRandom(seed);
  const sheet = buildLabelSheet(items, keyFactory(random), random);
  const columns = [
    'key',
    'topic',
    'type',
    'context',
    'instruction',
    'hint',
    'correct_answer',
    'predicted_wrong_answers',
    'explanation',
    'label',
    'defect_types',
    'accept_also',
    'note',
  ];
  return { csv: toCsv(columns, sheet.rows), mapping: sheet.mapping, rows: sheet.rows.length };
}

// ---------------------------------------------------------------------------
// S-synth: keyboard variants

export type KeyboardClass = 'fullwidth' | 'acute' | 'umlaut' | 'turkish' | 'smart_apostrophe' | 'nbsp' | 'arabic_digits' | 'zero_width';

/** The language families the eight-class folding table serves (report §2.2),
 * one transform each; a transform returns null when the answer has nothing
 * it could change. */
export const KEYBOARD_VARIANTS: Readonly<Record<KeyboardClass, { languages: string; apply: (s: string) => string | null }>> = {
  fullwidth: {
    languages: 'ja, ko',
    apply: (s) => {
      const out = s.replace(/[!-~]/g, (ch) => String.fromCharCode(ch.charCodeAt(0) - 0x21 + 0xff01)).replaceAll(' ', '　');
      return out === s ? null : out;
    },
  },
  acute: {
    languages: 'es, pt-BR',
    apply: (s) => replaceFirst(s, /[aeiou]/, { a: 'á', e: 'é', i: 'í', o: 'ó', u: 'ú' }),
  },
  umlaut: {
    languages: 'de',
    apply: (s) => replaceFirst(s, /[aou]/, { a: 'ä', o: 'ö', u: 'ü' }),
  },
  turkish: {
    languages: 'tr',
    // The dotless i first (the owner's 2026-09-07 case, "cookıng"), then the
    // other letters a Turkish layout puts next to their plain forms.
    apply: (s) => replaceFirst(s, /i/, { i: 'ı' }) ?? replaceFirst(s, /[scg]/, { s: 'ş', c: 'ç', g: 'ğ' }),
  },
  smart_apostrophe: {
    languages: 'every iOS keyboard with smart punctuation',
    apply: (s) => (s.includes("'") ? s.replaceAll("'", '’') : null),
  },
  nbsp: {
    languages: 'ja, ko, ar (and iOS after a full stop)',
    apply: (s) => (s.includes(' ') ? s.replace(' ', ' ') : null),
  },
  arabic_digits: {
    languages: 'ar',
    apply: (s) => (/\d/.test(s) ? s.replace(/\d/g, (d) => String.fromCharCode(0x0660 + Number(d))) : null),
  },
  zero_width: {
    languages: 'ar (ZWNJ), copied text',
    apply: (s) => (s.length > 1 ? `${s[0]}​${s.slice(1)}` : null),
  },
};

function replaceFirst(s: string, pattern: RegExp, map: Record<string, string>): string | null {
  const m = pattern.exec(s);
  if (!m || m.index === undefined) return null;
  return s.slice(0, m.index) + (map[m[0]] as string) + s.slice(m.index + 1);
}

export const KEYBOARD_CLASSES = Object.keys(KEYBOARD_VARIANTS) as KeyboardClass[];

/** At most this many keyboard variants per question (report §3.1: 7 classes
 * sampled 3 per question), rotated so every class appears equally often. */
export const KEYBOARD_VARIANTS_PER_QUESTION = 3;

export function keyboardVariants(answer: string, rotation: number): { cls: KeyboardClass; typed: string }[] {
  const applicable = KEYBOARD_CLASSES.map((cls) => ({ cls, typed: KEYBOARD_VARIANTS[cls].apply(answer) })).filter(
    (v): v is { cls: KeyboardClass; typed: string } => v.typed !== null,
  );
  if (applicable.length <= KEYBOARD_VARIANTS_PER_QUESTION) return applicable;
  const start = rotation % applicable.length;
  return Array.from({ length: KEYBOARD_VARIANTS_PER_QUESTION }, (_, i) => applicable[(start + i) % applicable.length] as { cls: KeyboardClass; typed: string });
}

// ---------------------------------------------------------------------------
// S-synth: contractions, spelling, near-misses

/** Unambiguous contraction pairs, both directions. `'s` and `'d` are left
 * out on purpose (report §1.2). */
export const CONTRACTIONS: readonly [full: string, short: string][] = [
  ['I am', "I'm"],
  ['you are', "you're"],
  ['we are', "we're"],
  ['they are', "they're"],
  ['I have', "I've"],
  ['we have', "we've"],
  ['they have', "they've"],
  ['is not', "isn't"],
  ['are not', "aren't"],
  ['was not', "wasn't"],
  ['were not', "weren't"],
  ['do not', "don't"],
  ['does not', "doesn't"],
  ['did not', "didn't"],
  ['have not', "haven't"],
  ['has not', "hasn't"],
  ['had not', "hadn't"],
  ['will not', "won't"],
  ['cannot', "can't"],
  ['could not', "couldn't"],
  ['would not', "wouldn't"],
  ['should not', "shouldn't"],
  ['must not', "mustn't"],
];

export function contractionVariant(answer: string): string | null {
  for (const [full, short] of CONTRACTIONS) {
    if (answer.includes(full)) return answer.replace(full, short);
    if (answer.includes(short)) return answer.replace(short, full);
  }
  // A fill-in answer that starts with the verb only: "am cooking" ↔ "'m cooking".
  if (/^am /.test(answer)) return answer.replace(/^am /, "'m ");
  if (/^'m /.test(answer)) return answer.replace(/^'m /, 'am ');
  if (/^are /.test(answer)) return answer.replace(/^are /, "'re ");
  if (/^'re /.test(answer)) return answer.replace(/^'re /, 'are ');
  return null;
}

/** British and American spellings that are not a grammar difference. */
export const SPELLINGS: readonly [a: string, b: string][] = [
  ['neighbourhood', 'neighborhood'],
  ['colour', 'color'],
  ['favourite', 'favorite'],
  ['behaviour', 'behavior'],
  ['travelling', 'traveling'],
  ['travelled', 'traveled'],
  ['cancelled', 'canceled'],
  ['organise', 'organize'],
  ['organised', 'organized'],
  ['realise', 'realize'],
  ['realised', 'realized'],
  ['recognise', 'recognize'],
  ['apologise', 'apologize'],
  ['centre', 'center'],
  ['theatre', 'theater'],
  ['programme', 'program'],
  ['practise', 'practice'],
  ['licence', 'license'],
  ['grey', 'gray'],
];

export function spellingVariant(answer: string): string | null {
  for (const [a, b] of SPELLINGS) {
    if (answer.includes(a)) return answer.replace(a, b);
    if (answer.includes(b)) return answer.replace(b, a);
  }
  return null;
}

function ing(verb: string): string {
  if (/ie$/.test(verb)) return `${verb.slice(0, -2)}ying`;
  if (/[^e]e$/.test(verb)) return `${verb.slice(0, -1)}ing`;
  return `${verb}ing`;
}

/** One answer that is a real mistake, one or two characters or one word
 * away from the key: the kind of near-miss the keyboard rule must not
 * forgive. For an `error_correction` item the original sentence itself. */
export function nearMiss(q: { type: ScoredItemType; context?: string; correctAnswer: string }): { rule: string; typed: string } | null {
  const key = q.correctAnswer.trim();
  if (q.type === 'error_correction') {
    return q.context && q.context.trim().length > 0 ? { rule: 'original_sentence', typed: q.context.trim() } : null;
  }
  const to = /^to ([a-z]+)$/i.exec(key);
  if (to) return { rule: 'to_plus_ing', typed: `to ${ing(to[1] as string)}` };
  if (/^[a-z]+ing$/i.test(key)) return { rule: 'ing_to_base', typed: key.replace(/ing$/i, '') };
  const words = key.split(' ');
  if (words.length === 1) return /s$/i.test(key) ? { rule: 'drop_s', typed: key.slice(0, -1) } : { rule: 'add_s', typed: `${key}s` };
  return { rule: 'drop_last_word', typed: words.slice(0, -1).join(' ') };
}

// ---------------------------------------------------------------------------
// S-synth: multi-blank partial answers

interface BoxState {
  text: string;
  noArticle?: boolean;
}

function boxesFor(item: MultiBlankItem, override: (i: number, key: string | null) => BoxState | undefined): BoxState[] {
  return item.keys.map((key, i) => override(i, key) ?? (key === null ? { text: '', noArticle: true } : { text: key }));
}

function blankTruths(item: MultiBlankItem, boxes: readonly BoxState[], acceptedOverride?: (i: number) => boolean): BlankTruth[] {
  return item.keys.map((key, i) => {
    const box = boxes[i] as BoxState;
    const matches = key === null ? box.noArticle === true : !box.noArticle && box.text.trim().length > 0;
    return {
      index: i,
      correct: key ?? '—',
      user: box.text,
      ...(box.noArticle ? { noArticle: true } : {}),
      accepted: acceptedOverride ? acceptedOverride(i) : matches,
    };
  });
}

function multiBlankAnswer(item: MultiBlankItem, kind: string, boxes: readonly BoxState[], truths: BlankTruth[], review: string): LabelledAnswer {
  const text = fullText(item.context, item.instruction);
  return {
    id: `synth:${item.id}:${kind}`,
    set: 'S-synth',
    item: { id: item.id, type: 'fill_in_blank', prompt: text },
    userAnswer: assembleBlanks(item.context, boxes),
    truth: truths.every((t) => t.accepted),
    kind: `partial:${kind}`,
    correctAnswer: assembleBlanks(item.context, boxesFor(item, () => undefined)),
    blanks: truths,
    review,
  };
}

/** For each multi-blank item: every box right; one box wrong; one box left
 * empty; a "no article" box wrongly filled (articles) or a keyboard variant
 * in one box (verbs). */
export function multiBlankAnswers(items: readonly MultiBlankItem[] = MULTI_BLANK_ITEMS): LabelledAnswer[] {
  const out: LabelledAnswer[] = [];
  for (const item of items) {
    const right = boxesFor(item, () => undefined);
    out.push(multiBlankAnswer(item, 'all_right', right, blankTruths(item, right), 'every box as the key'));

    const wrongIndex = item.keys.findIndex((k) => k !== null);
    const wrongBoxes = boxesFor(item, (i, key) => {
      if (i !== wrongIndex || key === null) return undefined;
      const miss = nearMiss({ type: 'fill_in_blank', correctAnswer: key });
      return { text: miss ? miss.typed : `${key}s` };
    });
    out.push(
      multiBlankAnswer(
        item,
        'one_wrong',
        wrongBoxes,
        blankTruths(item, wrongBoxes, (i) => i !== wrongIndex),
        `box ${wrongIndex + 1} wrong ("${wrongBoxes[wrongIndex]?.text}"), the rest right`,
      ),
    );

    const emptyIndex = item.keys.length - 1;
    const emptyBoxes = boxesFor(item, (i) => (i === emptyIndex ? { text: '' } : undefined));
    out.push(
      multiBlankAnswer(item, 'one_empty', emptyBoxes, blankTruths(item, emptyBoxes, (i) => i !== emptyIndex), `box ${emptyIndex + 1} left empty (its ____ stays in the sentence), the rest right`),
    );

    const noArticleIndex = item.keys.indexOf(null);
    if (noArticleIndex >= 0) {
      const filled = boxesFor(item, (i) => (i === noArticleIndex ? { text: 'the' } : undefined));
      out.push(
        multiBlankAnswer(item, 'article_where_none', filled, blankTruths(item, filled, (i) => i !== noArticleIndex), `box ${noArticleIndex + 1} should be "—" (no article) but holds "the"`),
      );
    } else {
      const kbIndex = 0;
      const key = item.keys[kbIndex] as string;
      const typed = KEYBOARD_VARIANTS.turkish.apply(key) ?? KEYBOARD_VARIANTS.acute.apply(key) ?? key;
      const kb = boxesFor(item, (i) => (i === kbIndex ? { text: typed } : undefined));
      out.push(multiBlankAnswer(item, 'keyboard_in_box', kb, blankTruths(item, kb), `box 1 typed as "${typed}" (a keyboard variant of "${key}"), the rest right`));
    }
  }
  return out;
}

// ---------------------------------------------------------------------------
// S-synth, assembled

/** The synthetic set: for every pool question, up to three keyboard variants
 * of the key (correct), a contraction and a spelling variant where the key
 * allows one (correct), one near-miss (wrong); then the multi-blank cases. */
export function buildSynth(pool: { sets: { questions: SharedQuestion[] }[] }, items: readonly MultiBlankItem[] = MULTI_BLANK_ITEMS): LabelledAnswer[] {
  const out: LabelledAnswer[] = [];
  let n = 0;
  for (const set of pool.sets) {
    for (const q of set.questions) {
      const item = poolItem(q);
      const base = { set: 'S-synth' as const, item, correctAnswer: q.correctAnswer };
      for (const v of keyboardVariants(q.correctAnswer, n)) {
        out.push({
          ...base,
          id: `synth:${q.id}:kb:${v.cls}`,
          userAnswer: v.typed,
          truth: true,
          kind: `kb:${v.cls}`,
          review: `the key typed on a ${KEYBOARD_VARIANTS[v.cls].languages} keyboard (${v.cls})`,
        });
      }
      const contraction = contractionVariant(q.correctAnswer);
      if (contraction) {
        out.push({ ...base, id: `synth:${q.id}:contraction`, userAnswer: contraction, truth: true, kind: 'contraction', review: 'the key with a contraction expanded or made: is it still right here?' });
      }
      const spelling = spellingVariant(q.correctAnswer);
      if (spelling) {
        out.push({ ...base, id: `synth:${q.id}:spelling`, userAnswer: spelling, truth: true, kind: 'spelling', review: 'the key in the other English spelling' });
      }
      const miss = nearMiss(q);
      if (miss) {
        out.push({
          ...base,
          id: `synth:${q.id}:nearmiss:${miss.rule}`,
          userAnswer: miss.typed,
          truth: false,
          kind: `nearmiss:${miss.rule}`,
          review: `a real mistake close to the key (${miss.rule.replaceAll('_', ' ')}): must be marked wrong`,
        });
      }
      n++;
    }
  }
  out.push(...multiBlankAnswers(items));
  const ids = new Set<string>();
  for (const a of out) {
    if (ids.has(a.id)) throw new Error(`duplicate synthetic id ${a.id}`);
    ids.add(a.id);
  }
  return out;
}

/** The owner's 15-minute review of S-synth: one line per answer, grouped by
 * question, with the expected verdict; he strikes any line he disagrees
 * with (the id goes into `eval/data/s-synth-exclusions.txt`). */
export function renderSynthReview(answers: readonly LabelledAnswer[]): string {
  const out: string[] = [
    '# S-synth — synthetic learner answers for the owner\'s review',
    '',
    'Each line: the expected verdict, the answer as typed, and why it is in the set. Every answer is right or wrong **by construction**; your job is to catch the ones where the construction is wrong for this question (a "contraction" that does not fit, a near-miss that is in fact acceptable, a keyboard variant that changed the meaning). Put the id of any line you disagree with, one per line, into `proxy/eval/data/s-synth-exclusions.txt`; those answers are left out of the run. About 15 minutes.',
    '',
    `${answers.length} answers.`,
    '',
  ];
  let lastItem = '';
  for (const a of answers) {
    if (a.item.id !== lastItem) {
      lastItem = a.item.id;
      out.push('', `## ${a.item.id} — key: ${JSON.stringify(a.correctAnswer)}`, '', `> ${a.item.prompt.replaceAll('\n', '\n> ')}`, '');
    }
    const verdict = a.truth ? 'CORRECT' : 'WRONG  ';
    const typed = JSON.stringify(a.userAnswer);
    const blanks = a.blanks ? ` — per blank: ${a.blanks.map((b) => `${b.index + 1}: ${b.noArticle ? '—' : JSON.stringify(b.user)} ${b.accepted ? '✓' : '✗'}`).join(', ')}` : '';
    out.push(`- \`${a.id}\` ${verdict} ${typed} — ${a.review ?? a.kind}${blanks}`);
  }
  out.push('');
  return out.join('\n');
}

// ---------------------------------------------------------------------------
// Templates

export const S_GEN_COLUMNS = ['key', 'topic', 'type', 'context', 'instruction', 'hint', 'label', 'note'] as const;
export const S_GEN_LABELS = ['ok', 'ambiguous', 'blank_count_wrong', 'unnatural', 'other'] as const;
export const S_FREE_COLUMNS = ['key', 'type', 'context', 'instruction', 'learner_answer', 'label', 'note'] as const;
export const S_FREE_LABELS = ['correct', 'wrong'] as const;

export function genSheetTemplate(): string {
  return toCsv(S_GEN_COLUMNS, []);
}

export function freeSheetTemplate(): string {
  return toCsv(S_FREE_COLUMNS, []);
}

// ---------------------------------------------------------------------------
// Summary for the hand-over

export function summarize(pool: LabelledAnswer[], gate: GateTruth[], liveRows: number, synth: LabelledAnswer[]): string {
  const count = (list: readonly LabelledAnswer[], pred: (a: LabelledAnswer) => boolean) => list.filter(pred).length;
  return [
    `S-pool scoring: ${pool.length} labelled answers (${count(pool, (a) => a.kind === 'key')} keys, ${count(pool, (a) => a.kind === 'accepted')} accepted, ${count(pool, (a) => a.kind === 'predicted_wrong')} predicted wrong)`,
    `S-pool gate: ${gate.length} corrected questions (${gate.reduce((n, g) => n + g.acceptAlso.length, 0)} accepted answers to rediscover)`,
    `S-live: ${liveRows} questions on the blind sheet`,
    `S-synth: ${synth.length} answers (${count(synth, (a) => a.kind.startsWith('kb:'))} keyboard, ${count(synth, (a) => a.kind === 'contraction')} contraction, ${count(synth, (a) => a.kind === 'spelling')} spelling, ${count(synth, (a) => a.kind.startsWith('nearmiss'))} near-miss, ${count(synth, (a) => a.kind.startsWith('partial'))} multi-blank)`,
  ].join('\n');
}
