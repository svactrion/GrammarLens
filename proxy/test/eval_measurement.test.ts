import { describe, expect, it } from 'vitest';
import {
  FALLBACK_SCORING,
  PRODUCTION_PRACTICE,
  PRODUCTION_SCORING,
  THINKING_HEADROOM_TOKENS,
  buildBody,
  buildGeneratePracticeSetBodyFor,
  buildScoreAnswersBodyFor,
  scoreMaxTokensFor,
} from '../src/anthropic';
import { GENERATION_SYSTEM_PROMPT_LIVE_2026_10, SCORING_SYSTEM_PROMPT_LIVE_2026_10 } from '../src/prompts';
import type { LabelledAnswer, LiveSetFile } from '../eval/lib/datasets';
import {
  ANSWERS_PER_CALL,
  DROP_ORDER,
  GENERATION_CELLS,
  MEASURE_SPEND_CAP_USD,
  REPEAT_CELLS,
  SCORING_CELLS,
  buildFreeSheet,
  buildGenSheet,
  charactersPerToken,
  fitCap,
  groupAnswers,
  planMeasurement,
  readApiError,
  renderStageReport,
  sFreeAnswersFrom,
  sFreeCalls,
  sFreePlaceholders,
  sFreeSelection,
  sGenItemsFrom,
  summarize,
  totalUsd,
  type SGenItem,
} from '../eval/lib/measurement';
import { parseCsv } from '../eval/lib/labels';
import { PRICES } from '../eval/lib/matrix';

const scoreReq = { deviceId: 'd', items: [{ id: 'q1', type: 'fill_in_blank', prompt: 'I saw ___ cat.\nFill in the blank.', userAnswer: 'the' }] };
const genReq = { deviceId: 'd', topicId: 'articles', count: 5 };

describe('the builders\' variant seams (1.4.0 measurement)', () => {
  it('production sends the default variants: the routes are unchanged by the seam', () => {
    expect(buildBody({ op: 'score_answers', request: scoreReq })).toEqual(buildScoreAnswersBodyFor(scoreReq, PRODUCTION_SCORING));
    expect(buildBody({ op: 'generate_practice_set', request: genReq })).toEqual(buildGeneratePracticeSetBodyFor(genReq, PRODUCTION_PRACTICE));
    expect(PRODUCTION_SCORING).toEqual({ model: 'claude-haiku-5-5', thinking: true, effort: 'low', prompt: 'd3d11' });
    expect(FALLBACK_SCORING).toEqual({ model: 'claude-sonnet-5-5', thinking: true, effort: 'low', prompt: 'd3d11' });
    expect(PRODUCTION_PRACTICE).toEqual({ model: 'claude-sonnet-5-5', thinking: true, effort: 'low', prompt: 'd3' });
  });

  it('the live scoring variant is the 2026-10 request: the Turkish paragraph, six fields, 2,048 tokens, no thinking', () => {
    const live = buildScoreAnswersBodyFor(scoreReq, { model: 'claude-sonnet-4-6', prompt: 'live' });
    expect(live.system).toBe(SCORING_SYSTEM_PROMPT_LIVE_2026_10);
    expect(live.system).toContain('ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u');
    expect(live.system).not.toContain('"blanks"');
    expect(live.max_tokens).toBe(2048);
    expect(live.thinking).toBeUndefined();
    const item = (live.output_config.format.schema as { properties: { feedback: { items: { required: string[] } } } }).properties.feedback.items;
    expect(item.required).toEqual(['itemId', 'isCorrect', 'correctedAnswer', 'explanation']);
    expect(live.messages).toEqual(buildScoreAnswersBodyFor(scoreReq, PRODUCTION_SCORING).messages);
  });

  it('a thinking cell adds adaptive thinking, the headroom and its effort', () => {
    const c5 = buildScoreAnswersBodyFor(scoreReq, { model: 'claude-sonnet-5-5', thinking: true, effort: 'medium', prompt: 'd3d11' });
    expect(c5.model).toBe('claude-sonnet-5-5');
    expect(c5.thinking).toEqual({ type: 'adaptive' });
    expect(c5.max_tokens).toBe(scoreMaxTokensFor(1) + THINKING_HEADROOM_TOKENS);
    expect(c5.output_config.effort).toBe('medium');
    const gE = buildGeneratePracticeSetBodyFor(genReq, { model: 'claude-haiku-5-5', thinking: true, effort: 'low', prompt: 'live' });
    expect(gE.system).toBe(GENERATION_SYSTEM_PROMPT_LIVE_2026_10);
    expect(gE.system).toContain('Turkish');
    expect(gE.thinking).toEqual({ type: 'adaptive' });
    expect(gE.max_tokens).toBe(2048 + THINKING_HEADROOM_TOKENS);
  });
});

function answer(id: string, itemId: string): LabelledAnswer {
  return { id, set: 'S-pool', item: { id: itemId, type: 'fill_in_blank', prompt: 'We saw ___ cat.\nFill in the blank.' }, userAnswer: 'the', truth: true, kind: 'key', correctAnswer: 'the' };
}

function set(date: string, n = 5): LiveSetFile {
  return {
    date,
    promptVersion: 2,
    questions: Array.from({ length: n }, (_, i) => ({
      id: `${date}-q${i}`,
      type: 'fill_in_blank' as const,
      context: 'We waited for ___ bus.',
      instruction: 'Fill in the blank.',
      topicId: 'articles',
      correctAnswer: 'the',
      explanation: 'The rule picks this form.',
      commonWrongAnswers: [
        { answer: 'a', comment: 'c' },
        { answer: 'an', comment: 'c' },
      ],
    })),
  };
}

describe('the measurement plan', () => {
  const answers = [
    ...Array.from({ length: 12 }, (_, i) => answer(`a${i}`, `item${i % 4}`)),
  ];
  const inputs = { pool: answers, synth: [], sFree: sFreePlaceholders(10), gateSets: [set('2026-10-07'), set('2026-10-08')], seed: 1 };
  const ratio = charactersPerToken();
  const plan = planMeasurement(inputs, ratio);

  it('calibrates the characters per token on the measured v2 request (2.3: the measured input counts the schema grammar too, so estimates are upper bounds)', () => {
    expect(ratio).toBeGreaterThan(2);
    expect(ratio).toBeLessThan(5);
  });

  it('never puts two answers of one question into the same scoring call', () => {
    const groups = groupAnswers(answers, 1);
    for (const g of groups) {
      expect(g.length).toBeLessThanOrEqual(ANSWERS_PER_CALL);
      expect(new Set(g.map((a) => a.item.id)).size).toBe(g.length);
    }
    expect(groups.flat()).toHaveLength(answers.length);
  });

  it('plans every cell: 5 generations per cell, 12 Daily Test calls, 2 checkers × sets × 2 repeats, and the scoring groups per cell twice', () => {
    const count = (stage: string) => plan.filter((c) => c.stage === stage).length;
    expect(count('generation')).toBe(GENERATION_CELLS.length * 5);
    expect(count('daily_test')).toBe(12);
    expect(count('gate')).toBe(2 * inputs.gateSets.length * 2);
    const groups = groupAnswers([...answers, ...inputs.sFree], 1).length;
    expect(count('scoring')).toBe(SCORING_CELLS.length * groups);
    expect(REPEAT_CELLS).toEqual(['C1', 'C4', 'C8']);
    expect(count('scoring_repeat')).toBe(REPEAT_CELLS.length * groups);
    expect(new Set(plan.filter((c) => c.stage === 'scoring_repeat').map((c) => c.group))).toEqual(new Set(REPEAT_CELLS));
    expect(count('s_free')).toBe(15);
    expect(new Set(plan.map((c) => c.customId)).size).toBe(plan.length);
  });

  it('prices every model it uses and sums the groups to the total', () => {
    for (const c of plan) expect(PRICES[c.model]).toBeDefined();
    const rows = summarize(plan);
    expect(rows.reduce((n, r) => n + r.costUsd, 0)).toBeCloseTo(totalUsd(plan), 6);
    expect(rows.find((r) => r.group === 'C7')?.model).toBe('claude-haiku-5-5');
  });

  it("drops whole groups in the documented order when the cap is short (C8's repeat, C4's, C1's, the gate repeat, C6, C5, the Sonnet checker), never the baseline", () => {
    const fit = fitCap(plan, 0.5);
    expect(fit.dropped.slice(0, 3)).toEqual(['scoring_repeat / C8', 'scoring_repeat / C4', 'scoring_repeat / C1']);
    expect(fit.dropped[3]).toMatch(/^gate .* r2$/);
    expect(fit.kept.some((c) => c.group === 'C1' && c.stage === 'scoring')).toBe(true);
    expect(fit.kept.some((c) => c.stage === 'generation')).toBe(true);
    expect(DROP_ORDER.map((d) => d.priority)).toEqual([8, 7, 6, 5, 4, 3, 2, 1]);
    expect(fitCap(plan, MEASURE_SPEND_CAP_USD).dropped).toEqual([]);
  });
});

describe('stage 1 pieces', () => {
  const content = {
    items: [
      { id: 'a', type: 'fill_in_blank', context: 'We saw ____ cat.', instruction: 'Fill in the blank.' },
      { id: 'b', type: 'sentence_writing', instruction: 'Write one sentence with "should".', hint: 'advice' },
      { id: 'a', type: 'error_correction', context: 'x y z', instruction: 'dup id' },
      { id: 'c', type: 'nonsense', instruction: 'bad type' },
      { type: 'fill_in_blank', instruction: 'no id' },
    ],
  };

  it('reads the generated items with unique ids per cell and drops malformed entries', () => {
    const { items, dropped } = sGenItemsFrom('G-B', 'articles', content);
    expect(items.map((i) => i.id)).toEqual(['G-B:articles:a', 'G-B:articles:b']);
    expect(items[0]?.prompt).toBe('We saw ____ cat.\nFill in the blank.');
    expect(items[1]).toMatchObject({ type: 'sentence_writing', hint: 'advice', prompt: 'Write one sentence with "should".' });
    expect(dropped).toBe(3);
    expect(sGenItemsFrom('G-A', 'articles', 'garbage')).toEqual({ items: [], dropped: 0 });
  });

  it('selects the D3 cells\' items for S-free with alternating targets, five per writer call', () => {
    const items: SGenItem[] = (['G-A', 'G-B', 'G-D', 'G-F', 'G-C'] as const).flatMap((cell) =>
      Array.from({ length: 3 }, (_, i) => ({ id: `${cell}:t:${i}`, cell, topicId: 't', type: 'sentence_writing' as const, instruction: 'x', prompt: 'x' })),
    );
    const selection = sFreeSelection(items);
    expect(selection).toHaveLength(9);
    expect(new Set(selection.map((s) => s.item.cell))).toEqual(new Set(['G-B', 'G-D', 'G-F']));
    expect(selection.map((s) => s.target)).toEqual(['error', 'correct', 'error', 'correct', 'error', 'correct', 'error', 'correct', 'error']);
    expect(sFreeCalls(selection).map((c) => c.length)).toEqual([5, 4]);
    const answers = sFreeAnswersFrom(selection.slice(0, 2), { answers: [{ itemId: 'G-B:t:0', answer: ' We should go. ' }, { itemId: 'ghost', answer: 'x' }, { itemId: 'G-B:t:1', answer: '' }] });
    expect([...answers]).toEqual([['G-B:t:0', 'We should go.']]);
  });

  it('writes blind sheets with letter-prefixed keys and the cell only in the mapping', () => {
    const items: SGenItem[] = [
      { id: 'G-B:t:0', cell: 'G-B', topicId: 'articles', type: 'fill_in_blank', context: 'c', instruction: 'i', prompt: 'c\ni' },
      { id: 'G-E:t:1', cell: 'G-E', topicId: 'articles', type: 'sentence_writing', instruction: 'i2', prompt: 'i2' },
    ];
    const gen = buildGenSheet(items, 7);
    expect(gen.rows).toHaveLength(2);
    for (const r of gen.rows) {
      expect(r.key).toMatch(/^k[0-9a-f]{7}$/);
      expect(Object.keys(r)).toEqual(['key', 'topic', 'type', 'context', 'instruction', 'hint', 'label', 'note']);
      expect(JSON.stringify(r)).not.toContain('G-');
      expect(gen.mapping[r.key as string]?.cell).toMatch(/^G-/);
    }
    const free = buildFreeSheet([{ item: items[0] as SGenItem, target: 'error', answer: 'We saw cat.' }], 8);
    expect(free.rows[0]).toMatchObject({ learner_answer: 'We saw cat.', label: '' });
    expect(JSON.stringify(free.rows)).not.toContain('error');
    expect(Object.values(free.mapping)[0]).toEqual({ cell: 'G-B', itemId: 'G-B:t:0', target: 'error' });
    expect(buildGenSheet(items, 7).rows).toEqual(gen.rows);
    expect(parseCsv('\ufeffkey,label\r\nk1,ok\r\n')).toEqual([{ key: 'k1', label: 'ok' }]);
  });

  it('reports measured against estimated per group', () => {
    const plan = planMeasurement({ pool: [], synth: [], sFree: [], gateSets: [], seed: 1 }, 2.33);
    const planned = plan.filter((c) => c.stage === 'generation' && c.group === 'G-A');
    const measured = planned.map((c, i) => ({ customId: c.customId, stage: c.stage, group: c.group, model: c.model, status: i === 0 ? 'http_error' : 'ok', inputTokens: 900, outputTokens: 1000, costUsd: i === 0 ? 0 : 0.02, durationMs: 8000 }));
    const report = renderStageReport('t', planned, measured);
    expect(report).toContain('| generation | G-A | 5 | 4 | 1 | 0 |');
    expect(report).toContain('→ 900');
    expect(report).toContain('measured $0.08');
  });
});

describe('readApiError', () => {
  it('keeps the type and the message (the 2026-10-31 workspace message included), truncated, never failing on a strange body', () => {
    const body = {
      type: 'error',
      error: {
        type: 'invalid_request_error',
        message: 'This API key is not scoped to a workspace, so this request must include the anthropic-workspace-id header with the ID of the workspace to use.',
      },
    };
    expect(readApiError(body)).toEqual({ errorType: 'invalid_request_error', errorMessage: body.error.message });
    expect(readApiError({ error: { type: 'x', message: 'y'.repeat(500) } }).errorMessage).toHaveLength(300);
    expect(readApiError({})).toEqual({ errorType: 'unknown', errorMessage: '' });
    expect(readApiError('text')).toEqual({ errorType: 'unknown', errorMessage: '' });
    expect(readApiError(null)).toEqual({ errorType: 'unknown', errorMessage: '' });
  });
});
