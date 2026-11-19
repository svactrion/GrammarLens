import { FIRST_WAVE_TOPICS, TOPICS, topicById, type TopicInfo } from '../../src/topics';
import { keyFactory } from './datasets';
import { seededRandom, shuffle, toCsv } from './labels';
import type { AnswerVerdict } from './topics_analysis';
import { HINT_CARDS, duplicateGroups, duplicatePairs, type ItemCheckRecord } from './topics_checks';
import type { AnswerProblem, TopicAnswer, TopicItem } from './topics_measurement';

/**
 * Phase B of the 1.5.0 first-wave topics measurement (docs/TOPICS.md): the
 * blind label sheet (three files), the reader that checks a filled sheet,
 * and the details file for after the labels. Pure: `eval/run.ts topics
 * analyze` writes the files into the run folder, which is not in the
 * repository (generated content never goes into a commit).
 *
 * Blind means: the sheet shows what a learner sees and the built answers,
 * and nothing else. No automatic flag, no gate result, no scorer verdict or
 * explanation, and not which built answer is the key, the second answer or
 * a mistake (owner decision, T-14).
 */

/** Fixes the sheet's order, keys and letters, so a rebuild never changes a
 * sheet someone has started. */
export const SHEET_SEED = 20261119;

export const LETTERS = ['A', 'B', 'C', 'D'] as const;
export type Letter = (typeof LETTERS)[number];

export const VERDICTS = ['ok', 'defect'] as const;
export const WHY_VALUES = ['several_answers', 'off_topic', 'bad_english', 'hint_wrong', 'level', 'other'] as const;
export const ANSWER_LABELS = ['right', 'wrong', 'unsure'] as const;
export type AnswerLabel = (typeof ANSWER_LABELS)[number];

export const SHEET_COLUMNS = ['key', 'verdict', 'why', 'note', 'also_accept', ...LETTERS] as const;

/** What a cell holds for a letter the question has no answer under. Not a
 * dash: the CSV writer would guard it with an apostrophe, as a formula. */
export const NO_ANSWER = 'n/a';

/** A cell that says nothing: empty, the marker, or a dash typed for it. */
const isBlank = (value: string) => value === '' || value === NO_ANSWER || value === '-';

/** The question types as the app names them (`lib/l10n/app_en.arb`). */
export const TYPE_NAMES: Readonly<Record<TopicItem['type'], string>> = {
  fill_in_blank: 'Fill in the blank',
  error_correction: 'Find and correct the error',
  sentence_writing: 'Write a sentence',
};

export interface SheetMappingRow {
  key: string;
  itemId: string;
  topicId: string;
  set: number;
  index: number;
  /** The built answer's id under each letter the question has. */
  letters: Partial<Record<Letter, string>>;
}

export interface SheetMapping {
  seed: number;
  rows: SheetMappingRow[];
}

export interface TopicSheet {
  /** The file to read. */
  questionsText: string;
  /** The file to fill. */
  labelsCsv: string;
  /** The file nobody opens until the sheet is filled. */
  mapping: SheetMapping;
  questions: number;
  answers: number;
}

const title = (topicId: string) => topicById(topicId, true)?.title ?? topicId;

/** The topics [items] has questions of, in the tables' order: the
 * first-wave topics, then the live ones. */
export function topicsOf(items: readonly { topicId: string }[]): TopicInfo[] {
  const present = new Set(items.map((i) => i.topicId));
  return [...FIRST_WAVE_TOPICS, ...TOPICS].filter((t) => present.has(t.id));
}

function indented(text: string): string[] {
  return text.split(/\r?\n/).map((line) => `    ${line}`);
}

/**
 * The blind sheet for [items] and their built [answers]: every question, in
 * an order mixed across topics, under an opaque key, with its built answers
 * under letters in a shuffled order. A question that failed the gate or has
 * no built answers is on it like any other.
 */
export function buildTopicSheet(items: readonly TopicItem[], answers: readonly TopicAnswer[], seed = SHEET_SEED): TopicSheet {
  const random = seededRandom(seed);
  const newKey = keyFactory(random);
  const byItem = new Map<string, TopicAnswer[]>();
  for (const a of answers) byItem.set(a.itemId, [...(byItem.get(a.itemId) ?? []), a]);
  const used = new Set<string>();
  const rows = shuffle(items, random).map((item) => {
    let key = newKey();
    while (used.has(key)) key = newKey();
    used.add(key);
    const lettered = shuffle(byItem.get(item.id) ?? [], random).slice(0, LETTERS.length);
    const letters: Partial<Record<Letter, string>> = {};
    lettered.forEach((a, i) => {
      letters[LETTERS[i] as Letter] = a.id;
    });
    return { item, lettered, row: { key, itemId: item.id, topicId: item.topicId, set: item.set, index: item.index, letters } };
  });

  const topics = topicsOf(items).map((topic) => ({ topic }));
  const text: string[] = [
    'FIRST-WAVE TOPICS: THE LABEL SHEET, THE QUESTIONS',
    '',
    `${rows.length} practice questions, in mixed order. Read each one here and write`,
    'your labels into labels.csv, in the row with the same key.',
    '',
    'What you see for a question is what a learner sees in the app: the topic,',
    'the type, the context, the instruction and the hint (when it has them).',
    'Under it are answers that were written for the question, some right and',
    'some wrong, in no particular order.',
    '',
    'For each question, in labels.csv:',
    '  verdict      ok, or defect. A defect: a careful learner would be taught',
    '               something false, be marked wrong for a right answer they are',
    '               likely to give, or could not tell what is asked.',
    '  why          for a defect, one or more of (separated by ;):',
    `               ${WHY_VALUES.join(' | ')}`,
    '               several_answers: more than one answer is right and the',
    '               question does not say which it wants. off_topic: it does not',
    '               practise its topic. bad_english: the question itself has an',
    '               error or is unnatural. hint_wrong: the hint, or the topic\'s',
    '               hint card below, says something false for this question.',
    '               level: too easy or too hard for B1-C1.',
    '  note         anything, in your own words (expected with "other").',
    '  also_accept  answers that must count as right and are not among the',
    '               listed ones, separated by |.',
    `  A, B, C, D   for each listed answer: ${ANSWER_LABELS.join(' | ')}. Would a teacher`,
    '               accept it as an answer to this question? A fill-in-the-blank',
    '               answer is the word(s) for the blank, or the whole sentence',
    '               when the question has several blanks. A letter the question',
    `               does not have is already "${NO_ANSWER}": leave it.`,
    '',
    'Label from the question alone. Do not open the "private" folder or any other',
    'file of this run folder until every row is filled.',
    '',
    '================================================================',
    'HINT CARDS (the card the app shows for the topic, on every question)',
    '================================================================',
    '',
  ];
  for (const t of topics) {
    text.push(t.topic.title);
    for (const line of HINT_CARDS[t.topic.id] ?? []) text.push(`  - ${line}`);
    text.push('');
  }
  text.push('================================================================', `QUESTIONS (${rows.length})`, '================================================================', '');
  rows.forEach(({ item, lettered, row }, n) => {
    text.push(`---- ${row.key}  (${n + 1} of ${rows.length}) ----`, `Topic: ${title(item.topicId)}`, `Type:  ${TYPE_NAMES[item.type]}`);
    if (item.context !== undefined) text.push('Context:', ...indented(item.context));
    text.push('Instruction:', ...indented(item.instruction));
    if (item.hint !== undefined) text.push('Hint:', ...indented(item.hint));
    text.push('Answers:');
    if (lettered.length === 0) text.push('    (none were written for this question)');
    lettered.forEach((a, i) => text.push(`  ${LETTERS[i]}) ${a.userAnswer.replace(/\r?\n/g, ' / ')}`));
    text.push('');
  });

  const csvRows = rows.map(({ row }) => ({
    key: row.key,
    verdict: '',
    why: '',
    note: '',
    also_accept: '',
    ...Object.fromEntries(LETTERS.map((l) => [l, row.letters[l] === undefined ? NO_ANSWER : ''])),
  }));
  return {
    questionsText: `${text.join('\n')}\n`,
    labelsCsv: toCsv(SHEET_COLUMNS, csvRows),
    mapping: { seed, rows: rows.map((r) => r.row) },
    questions: rows.length,
    answers: rows.reduce((n, r) => n + r.lettered.length, 0),
  };
}

// ---------------------------------------------------------------------------
// Reading a filled sheet

export interface QuestionLabel {
  key: string;
  itemId: string;
  verdict: (typeof VERDICTS)[number];
  why: string[];
  note: string;
  alsoAccept: string[];
  /** The label of each built answer, by the answer's id. */
  answers: Map<string, AnswerLabel>;
}

export interface SheetProblem {
  key: string;
  problem: string;
}

export interface ReadSheet {
  /** Rows that are fully and validly labelled. */
  labels: QuestionLabel[];
  /** Keys of rows nobody has touched yet. */
  unlabelled: string[];
  /** Rows that are started and have something to fix, one entry per fault. */
  problems: SheetProblem[];
}

/** A leading apostrophe a spreadsheet may keep is dropped; spacing too. */
const clean = (value: string | undefined) => (value ?? '').replace(/^'/, '').trim();

/** Why the file cannot be read as the sheet at all, or null. */
export function sheetHeaderProblem(csvText: string): string | null {
  const first = (csvText.startsWith('﻿') ? csvText.slice(1) : csvText).split(/\r?\n/)[0] ?? '';
  if (first.includes(';') && !first.includes(',')) return `labels.csv uses ";" between cells; it must be "," (first line: ${SHEET_COLUMNS.join(',')}).`;
  const header = first.split(',').map((h) => h.replace(/^"|"$/g, '').trim());
  const missing = SHEET_COLUMNS.filter((c) => !header.includes(c));
  return missing.length > 0 ? `labels.csv has no column ${missing.join(', ')}; its first line must be ${SHEET_COLUMNS.join(',')}.` : null;
}

/**
 * The labels of a filled (or half-filled) sheet against its [mapping]. Every
 * row that is unlabelled is named, and so is every value outside the
 * vocabulary: a missing or unknown verdict, a defect without a reason, a
 * reason on a row that is not a defect, an answer without a label or with an
 * unknown one, a label under a letter the question does not have, a key the
 * sheet does not know, a key that is there twice, and a row that is gone.
 */
export function readTopicLabels(rows: readonly Record<string, string>[], mapping: SheetMapping): ReadSheet {
  const labels: QuestionLabel[] = [];
  const unlabelled: string[] = [];
  const problems: SheetProblem[] = [];
  const known = new Map(mapping.rows.map((r) => [r.key, r]));
  const seen = new Set<string>();
  for (const raw of rows) {
    const key = clean(raw.key);
    const row = known.get(key);
    if (!row) {
      problems.push({ key: key || '(empty)', problem: 'a key the sheet does not have (was it changed by a spreadsheet?)' });
      continue;
    }
    if (seen.has(key)) {
      problems.push({ key, problem: 'the key is in the file twice' });
      continue;
    }
    seen.add(key);
    const verdict = clean(raw.verdict).toLowerCase();
    const why = clean(raw.why).toLowerCase().split(/[;|,]/).map((w) => w.trim()).filter((w) => w.length > 0);
    const note = clean(raw.note);
    const alsoAccept = clean(raw.also_accept).split('|').map((a) => a.trim()).filter((a) => a.length > 0);
    const cells = LETTERS.map((letter) => ({ letter, answerId: row.letters[letter], value: clean(raw[letter]).toLowerCase() }));
    const touched = verdict !== '' || why.length > 0 || note !== '' || alsoAccept.length > 0 || cells.some((c) => !isBlank(c.value));
    if (!touched) {
      unlabelled.push(key);
      continue;
    }
    const faults: string[] = [];
    if (verdict === '') faults.push('no verdict');
    else if (!(VERDICTS as readonly string[]).includes(verdict)) faults.push(`verdict "${verdict}" (${VERDICTS.join(' | ')})`);
    for (const w of why) if (!(WHY_VALUES as readonly string[]).includes(w)) faults.push(`why "${w}" (${WHY_VALUES.join(' | ')})`);
    if (verdict === 'defect' && why.length === 0) faults.push('a defect without a why');
    if (verdict === 'ok' && why.length > 0) faults.push('a why on a row that is not a defect');
    if (why.includes('other') && note === '') faults.push('why "other" without a note');
    const answers = new Map<string, AnswerLabel>();
    for (const c of cells) {
      if (c.answerId === undefined) {
        if (!isBlank(c.value)) faults.push(`${c.letter}: the question has no answer ${c.letter}`);
      } else if (isBlank(c.value)) faults.push(`${c.letter}: no label`);
      else if (!(ANSWER_LABELS as readonly string[]).includes(c.value)) faults.push(`${c.letter}: "${c.value}" (${ANSWER_LABELS.join(' | ')})`);
      else answers.set(c.answerId, c.value as AnswerLabel);
    }
    if (faults.length > 0) {
      for (const problem of faults) problems.push({ key, problem });
      continue;
    }
    labels.push({ key, itemId: row.itemId, verdict: verdict as QuestionLabel['verdict'], why, note, alsoAccept, answers });
  }
  for (const row of mapping.rows) if (!seen.has(row.key)) problems.push({ key: row.key, problem: 'the row is missing from the file' });
  return { labels, unlabelled, problems };
}

/** What `topics analyze` prints about the sheet. */
export function renderSheetStatus(read: ReadSheet, questions: number): string {
  const lines = [`Label sheet: ${read.labels.length} of ${questions} rows labelled, ${read.unlabelled.length} not started, ${new Set(read.problems.map((p) => p.key)).size} with something to fix.`];
  if (read.unlabelled.length > 0) lines.push(`Not labelled: ${read.unlabelled.join(', ')}`);
  for (const p of read.problems) lines.push(`Fix ${p.key}: ${p.problem}`);
  return lines.join('\n');
}

// ---------------------------------------------------------------------------
// The details file (for after the labels)

const KIND_NAMES: Readonly<Record<TopicAnswer['kind'], string>> = { key: 'key', variant: 'second answer', mistake1: 'mistake 1', mistake2: 'mistake 2' };

export interface DetailsInput {
  items: readonly TopicItem[];
  answers: readonly TopicAnswer[];
  checks: readonly ItemCheckRecord[];
  answerProblems: readonly AnswerProblem[];
  verdicts: ReadonlyMap<string, AnswerVerdict>;
  mapping: SheetMapping;
  /** The run folder, for the heading. */
  runDir: string;
}

/**
 * Everything the sheet hides, per question in the run's order: the gate,
 * the automatic flags, each built answer with its kind, its truth by
 * construction and the scorer's verdict and explanation; then the groups of
 * resembling questions side by side.
 */
export function renderDetails(input: DetailsInput): string {
  const rowOf = new Map(input.mapping.rows.map((r) => [r.itemId, r]));
  const checkOf = new Map(input.checks.map((c) => [c.itemId, c]));
  const out: string[] = [
    '****************************************************************',
    'DO NOT OPEN THIS FILE BEFORE THE LABEL SHEET IS FILLED.',
    'It shows, for every question, what the sheet hides on purpose: the',
    'automatic flags, the gate, which built answer is the key, and what the',
    'scorer said. Reading it first would colour the labels.',
    '****************************************************************',
    '',
    `First-wave topics measurement: details of ${input.runDir}`,
    `${input.items.length} questions, ${input.answers.length} built answers.`,
    '',
  ];
  const describe = (item: TopicItem): string[] => [
    ...(item.context === undefined ? [] : ['  Context:', ...indented(item.context)]),
    '  Instruction:',
    ...indented(item.instruction),
    ...(item.hint === undefined ? [] : ['  Hint:', ...indented(item.hint)]),
  ];
  for (const item of input.items) {
    const row = rowOf.get(item.id);
    const check = checkOf.get(item.id);
    const letterOf = new Map(Object.entries(row?.letters ?? {}).map(([letter, id]) => [id, letter]));
    out.push(
      '================================================================',
      `${item.id}   sheet key ${row?.key ?? '(not on the sheet)'}   ${title(item.topicId)}, set ${item.set}, question ${item.index + 1}   ${TYPE_NAMES[item.type]}`,
      '================================================================',
      ...describe(item),
      `  Gate: ${check === undefined ? 'no record' : check.gate.length === 0 ? 'passed' : `FAILED: ${check.gate.join(', ')}`}`,
    );
    if (check && check.notRun.length > 0) out.push(`  Checks not run (no key): ${check.notRun.join(', ')}`);
    if (!check || check.flags.length === 0) out.push('  Flags: none');
    else for (const f of check.flags) out.push(`  Flag [${f.check}] ${f.code}: ${f.detail}`);
    for (const p of input.answerProblems.filter((x) => x.itemId === item.id)) out.push(`  Writer note: ${p.code}: ${p.detail}`);
    const mine = input.answers.filter((a) => a.itemId === item.id);
    if (mine.length === 0) out.push('  Built answers: none');
    for (const a of mine) {
      const v = input.verdicts.get(a.id);
      const scorer = v === undefined ? 'not scored' : `${v.isCorrect ? 'correct' : 'needs work'}${v.isCorrect === a.truth ? '' : '   <-- DIFFERS from the truth by construction'}`;
      out.push(
        `  ${letterOf.get(a.id) ?? '?'}) ${KIND_NAMES[a.kind]} (built as ${a.truth ? 'right' : 'wrong'}${a.breaks ? `; breaks: ${a.breaks}` : ''})`,
        ...indented(a.userAnswer),
        `      scorer: ${scorer}`,
      );
      if (v) out.push(`      corrected: ${v.correctedAnswer.replace(/\r?\n/g, ' / ')}`, `      explanation: ${v.explanation.replace(/\r?\n/g, ' ')}`);
    }
    out.push('');
  }

  out.push('################################################################', 'RESEMBLING QUESTIONS, SIDE BY SIDE', '################################################################', '');
  const pairs = duplicatePairs(input.items);
  for (const t of topicsOf(input.items).map((topic) => ({ topic }))) {
    const mine = input.items.filter((i) => i.topicId === t.topic.id);
    const myPairs = pairs.filter((p) => p.a.topicId === t.topic.id);
    const groups = duplicateGroups(mine, myPairs).sort((a, b) => b.length - a.length);
    out.push(`==== ${t.topic.title}: ${groups.length} group${groups.length === 1 ? '' : 's'} ====`, '');
    groups.forEach((group, g) => {
      const ids = new Set(group.map((i) => i.id));
      out.push(`-- ${t.topic.title}, group ${g + 1}: ${group.length} questions, in ${new Set(group.map((i) => i.set)).size} set(s) --`);
      for (const item of group) out.push(`${item.id}   sheet key ${rowOf.get(item.id)?.key ?? '?'}   ${TYPE_NAMES[item.type]}`, ...describe(item));
      out.push('  Pairs:');
      for (const p of myPairs.filter((x) => ids.has(x.a.id))) {
        out.push(`    ${p.a.id} ~ ${p.b.id}: ${p.same ? 'same words' : `${Math.round(p.similarity * 100)} % of the scenario words`}, ${p.inSet ? 'inside a set' : 'across sets'}`);
      }
      out.push('');
    });
  }
  return `${out.join('\n')}\n`;
}
