import type { SharedQuestion } from '../../src/shared_daily_test';

/**
 * The owner's blind label sheet for E (docs/1.1.0-shared-daily-test-quality.md
 * §13.6): one row per question, under a random key, in a shuffled order. Which
 * variant (or reference set) a row came from is only in the mapping file, kept
 * apart until labelling is done. Pure: `eval/run.ts` writes the files.
 */

/** Where a labelled question came from. */
export interface LabelSource {
  /** A generation variant (`G1`…`G5`) or a reference set (`R1`…`R3`). */
  source: string;
  /** The generated set's date; absent for a reference set. */
  date?: string;
  questionId: string;
}

export interface LabelItem extends LabelSource {
  question: SharedQuestion;
}

export const LABEL_VALUES = ['ok', 'defect', 'minor'] as const;
export type LabelValue = (typeof LABEL_VALUES)[number];

export const DEFECT_TYPES = [
  'original_not_wrong',
  'key_incorrect',
  'multiple_answers',
  'wrong_answer_acceptable',
  'wrong_rule',
  'other',
] as const;

/** Shown columns first, then the four the owner fills in. */
export const LABEL_COLUMNS = [
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
] as const;

/** mulberry32: a seeded generator, so a run's shuffle can be reproduced from
 * the seed kept in its private folder. */
export function seededRandom(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function shuffle<T>(items: readonly T[], random: () => number): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [out[i], out[j]] = [out[j] as T, out[i] as T];
  }
  return out;
}

/**
 * The sheet's rows and the mapping from each row's key to its source. Keys
 * come from [newKey] (random, so they say nothing about the source) and must be
 * unique; the rows are shuffled with [random].
 */
export function buildLabelSheet(
  items: readonly LabelItem[],
  newKey: () => string,
  random: () => number,
): { rows: Record<(typeof LABEL_COLUMNS)[number], string>[]; mapping: Record<string, LabelSource> } {
  const mapping: Record<string, LabelSource> = {};
  const rows = items.map((item) => {
    let key = newKey();
    while (key in mapping) key = newKey();
    mapping[key] = {
      source: item.source,
      ...(item.date === undefined ? {} : { date: item.date }),
      questionId: item.questionId,
    };
    const q = item.question;
    return {
      key,
      topic: q.topicId,
      type: q.type,
      context: q.context ?? '',
      instruction: q.instruction,
      hint: q.hint ?? '',
      correct_answer: q.correctAnswer,
      predicted_wrong_answers: q.commonWrongAnswers.map((w) => `${w.answer} — ${w.comment}`).join(' || '),
      explanation: q.explanation,
      label: '',
      defect_types: '',
      accept_also: '',
      note: '',
    };
  });
  return { rows: shuffle(rows, random), mapping };
}

// ---------------------------------------------------------------------------
// CSV (RFC 4180), opened in a spreadsheet by the owner

/** A cell a spreadsheet would read as a formula gets a leading apostrophe:
 * model-written text must never run as one. */
function cell(value: string): string {
  const safe = /^[=+\-@\t\r]/.test(value) ? `'${value}` : value;
  return /[",\r\n]/.test(safe) ? `"${safe.replaceAll('"', '""')}"` : safe;
}

/** With a byte-order mark, so a spreadsheet reads it as UTF-8 (curly quotes,
 * Turkish letters). */
export function toCsv(columns: readonly string[], rows: readonly Record<string, string>[]): string {
  const lines = [columns.map(cell).join(','), ...rows.map((row) => columns.map((c) => cell(row[c] ?? '')).join(','))];
  return `﻿${lines.join('\r\n')}\r\n`;
}

/** Parses RFC 4180 CSV (quoted cells, doubled quotes, newlines inside quotes,
 * CRLF or LF), dropping a leading byte-order mark. Rows as header → value. */
export function parseCsv(text: string): Record<string, string>[] {
  const input = text.startsWith('﻿') ? text.slice(1) : text;
  const records: string[][] = [];
  let record: string[] = [];
  let value = '';
  let quoted = false;
  for (let i = 0; i < input.length; i++) {
    const ch = input[i] as string;
    if (quoted) {
      if (ch === '"') {
        if (input[i + 1] === '"') {
          value += '"';
          i++;
        } else {
          quoted = false;
        }
      } else {
        value += ch;
      }
    } else if (ch === '"') {
      quoted = true;
    } else if (ch === ',') {
      record.push(value);
      value = '';
    } else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && input[i + 1] === '\n') i++;
      record.push(value);
      records.push(record);
      record = [];
      value = '';
    } else {
      value += ch;
    }
  }
  if (value.length > 0 || record.length > 0) {
    record.push(value);
    records.push(record);
  }
  const [header, ...body] = records.filter((r) => !(r.length === 1 && r[0] === ''));
  if (!header) return [];
  return body.map((r) => Object.fromEntries(header.map((h, i) => [h, r[i] ?? ''])));
}

// ---------------------------------------------------------------------------
// Reading the filled-in sheet

export interface OwnerLabel {
  label: LabelValue;
  defectTypes: string[];
  acceptAlso: string[];
}

export interface ReadLabels {
  labels: Map<string, OwnerLabel>;
  /** Keys with no label yet. */
  unlabelled: string[];
  /** Keys whose label or defect type is not one of the allowed values. */
  invalid: string[];
}

/** The owner's labels by key. A leading apostrophe a spreadsheet may keep is
 * ignored; case and spacing too. */
export function readLabels(rows: readonly Record<string, string>[]): ReadLabels {
  const labels = new Map<string, OwnerLabel>();
  const unlabelled: string[] = [];
  const invalid: string[] = [];
  const clean = (v: string | undefined) => (v ?? '').replace(/^'/, '').trim();
  for (const row of rows) {
    const key = clean(row.key);
    const label = clean(row.label).toLowerCase();
    if (label === '') {
      unlabelled.push(key);
      continue;
    }
    const defectTypes = clean(row.defect_types)
      .split(';')
      .map((t) => t.trim().toLowerCase())
      .filter((t) => t.length > 0);
    if (
      !(LABEL_VALUES as readonly string[]).includes(label) ||
      defectTypes.some((t) => !(DEFECT_TYPES as readonly string[]).includes(t))
    ) {
      invalid.push(key);
      continue;
    }
    labels.set(key, {
      label: label as LabelValue,
      defectTypes,
      acceptAlso: clean(row.accept_also)
        .split('|')
        .map((a) => a.trim())
        .filter((a) => a.length > 0),
    });
  }
  return { labels, unlabelled, invalid };
}
