import { describe, expect, it } from 'vitest';
import { THINKING_HEADROOM_TOKENS, buildGenerateSharedDailyTestBody, dailyTestMaxTokensFor } from '../src/anthropic';
import { SHARED_GENERATOR, dailyPlan, sharedDailyTestRequest, type DailyPlan } from '../src/shared_daily_test';
import {
  COMPARE_DATES,
  COMPARE_SPEND_CAP_USD,
  COMPARE_VARIANTS,
  comparisonBody,
  estimatedCostUsd,
  fitsCap,
  gateResult,
  planComparison,
  renderComparisonReport,
  renderQuestions,
  summarizeComparison,
  worstCaseCostUsd,
  type CompareRecord,
} from '../eval/lib/compare';
import { EVAL_DATES } from '../eval/lib/matrix';

const DATE = '2026-10-10';

/** A set for [plan] that passes validateSharedSet, with a planted key and
 * explanation that must never reach questions.md. */
function validSet(plan: DailyPlan) {
  return {
    questions: plan.slots.map((slot, i) =>
      slot.type === 'fill_in_blank'
        ? {
            id: `q${i}`,
            type: slot.type,
            context: `We waited for ___ bus ${i}.`,
            instruction: 'Fill in the blank.',
            topicId: slot.topicId,
            correctAnswer: `KEY-SECRET ${i}`,
            explanation: 'EXPLANATION-SECRET picks this form.',
            commonWrongAnswers: [
              { answer: `wrong ${i} one`, comment: 'WRONG-SECRET does not fit.' },
              { answer: `wrong ${i} two`, comment: 'This one misses the rule.' },
            ],
          }
        : {
            id: `q${i}`,
            type: slot.type,
            context: `Flawed sentence number ${i}.`,
            instruction: 'Rewrite the full corrected sentence.',
            topicId: slot.topicId,
            correctAnswer: `KEY-SECRET sentence number ${i}.`,
            explanation: 'EXPLANATION-SECRET follows the rule.',
            commonWrongAnswers: [
              { answer: `Half fixed number ${i}.`, comment: 'Only part is fixed.' },
              { answer: `Flawed sentence number ${i}.`, comment: 'Unchanged.' },
            ],
          },
    ),
  };
}

function record(fields: Partial<CompareRecord> & Pick<CompareRecord, 'variant'>): CompareRecord {
  const v = COMPARE_VARIANTS.find((x) => x.id === fields.variant);
  return {
    customId: `cmp_${fields.variant}_${fields.date ?? DATE}`,
    date: DATE,
    model: v?.model ?? 'claude-sonnet-5',
    status: 'ok',
    inputTokens: 2400,
    outputTokens: 4000,
    stopReason: 'end_turn',
    durationMs: 40_000,
    costUsd: 0.0448,
    content: validSet(dailyPlan(fields.date ?? DATE)),
    ...fields,
  };
}

describe('generator comparison: plan and requests', () => {
  const plan = planComparison();

  it('makes 9 synchronous calls: 3 variants × E\'s 3 dates, date by date', () => {
    expect(COMPARE_DATES).toEqual(EVAL_DATES);
    expect(plan).toHaveLength(9);
    expect(plan.map((r) => r.variant)).toEqual(['V1', 'V2', 'V3', 'V1', 'V2', 'V3', 'V1', 'V2', 'V3']);
    expect(new Set(plan.map((r) => r.customId)).size).toBe(9);
  });

  it('compares prompt v2 with claude-sonnet-5, claude-sonnet-5-5, and claude-sonnet-5-5 at low effort', () => {
    expect(COMPARE_VARIANTS).toEqual([
      { id: 'V1', model: 'claude-sonnet-5' },
      { id: 'V2', model: 'claude-sonnet-5-5' },
      { id: 'V3', model: 'claude-sonnet-5-5', effort: 'low' },
    ]);
  });

  it('V3, the owner\'s choice, sends exactly what the cron sends for that date (with no avoid list)', () => {
    expect(SHARED_GENERATOR).toEqual({ model: 'claude-sonnet-5-5', effort: 'low' });
    expect(comparisonBody({ customId: 'x', variant: 'V3', date: DATE })).toEqual(
      buildGenerateSharedDailyTestBody(sharedDailyTestRequest(dailyPlan(DATE))),
    );
  });

  it('V2 differs from V1 only in the model; V3 only adds effort "low"', () => {
    const v1 = comparisonBody({ customId: 'x', variant: 'V1', date: DATE });
    const v2 = comparisonBody({ customId: 'x', variant: 'V2', date: DATE });
    const v3 = comparisonBody({ customId: 'x', variant: 'V3', date: DATE });
    expect(v2).toEqual({ ...v1, model: 'claude-sonnet-5-5' });
    expect(v3).toEqual({ ...v2, output_config: { ...v2.output_config, effort: 'low' } });
    for (const body of [v1, v2, v3]) {
      expect(body.thinking).toEqual({ type: 'adaptive' });
      expect(body.max_tokens).toBe(dailyTestMaxTokensFor(5) + THINKING_HEADROOM_TOKENS);
      expect(JSON.stringify(body)).not.toContain('temperature');
    }
  });
});

describe('generator comparison: the $1 cap', () => {
  const plan = planComparison();

  it('estimates well under the cap, while all 9 at worst case would pass it', () => {
    const est = plan.reduce((s, r) => s + estimatedCostUsd(r), 0);
    const worst = plan.reduce((s, r) => s + worstCaseCostUsd(r), 0);
    expect(COMPARE_SPEND_CAP_USD).toBe(1);
    expect(est).toBeCloseTo(0.4436, 3);
    expect(worst).toBeGreaterThan(COMPARE_SPEND_CAP_USD);
  });

  it('prices the worst case as every max_tokens token billed as output', () => {
    // 2,390 × 1.25 input at $2 + 15,072 output at $10, per million.
    expect(worstCaseCostUsd(plan[0] as (typeof plan)[number])).toBeCloseTo((2390 * 1.25 * 2 + 15_072 * 10) / 1e6, 9);
  });

  it('makes a call only if its worst case still fits, so measured spend never passes $1', () => {
    const request = plan[0] as (typeof plan)[number];
    const worst = worstCaseCostUsd(request);
    expect(fitsCap(0, request)).toBe(true);
    expect(fitsCap(1 - worst, request)).toBe(true);
    expect(fitsCap(1 - worst + 0.0001, request)).toBe(false);
    // Spending the worst case on every call it allows never passes the cap.
    let spent = 0;
    for (const r of plan) if (fitsCap(spent, r)) spent += worstCaseCostUsd(r);
    expect(spent).toBeLessThanOrEqual(COMPARE_SPEND_CAP_USD);
  });
});

describe('generator comparison: summary', () => {
  it('counts passing sets, rejection codes and call failures per variant', () => {
    const plan = dailyPlan(DATE);
    const sentenceless = validSet(plan);
    const ec = sentenceless.questions.findIndex((q) => q.type === 'error_correction');
    delete (sentenceless.questions[ec] as Record<string, unknown>).context;
    const summaries = summarizeComparison([
      record({ variant: 'V1' }),
      record({ variant: 'V1', date: '2026-10-11', content: validSet(dailyPlan('2026-10-11')) }),
      record({ variant: 'V2', content: sentenceless }),
      record({ variant: 'V2', date: '2026-10-11', status: 'unparseable', content: undefined, stopReason: 'max_tokens', outputTokens: 15_072 }),
      record({ variant: 'V3', status: 'http_error', httpStatus: 400, errorType: 'invalid_request_error', inputTokens: undefined, outputTokens: undefined, stopReason: undefined, costUsd: 0, content: undefined }),
      record({ variant: 'V3', date: '2026-10-11', status: 'skipped_budget', inputTokens: undefined, outputTokens: undefined, durationMs: undefined, costUsd: 0, content: undefined }),
    ]);
    const [v1, v2, v3] = summaries as [(typeof summaries)[number], (typeof summaries)[number], (typeof summaries)[number]];
    expect([v1.passed, v1.sent, v1.rejections]).toEqual([2, 2, {}]);
    expect([v2.passed, v2.sent, v2.rejections]).toEqual([0, 2, { error_correction_missing_sentence: 1, unparseable: 1 }]);
    expect(v2.errorCorrection.withoutSentence).toBe(1);
    expect(v2.stopReasons).toEqual({ end_turn: 1, max_tokens: 1 });
    expect([v3.sent, v3.skippedBudget, v3.rejections]).toEqual([1, 1, { http_400_invalid_request_error: 1 }]);
    expect(v3.avgInputTokens).toBeNull();
    expect(v3.stopReasons).toEqual({});
  });

  it('counts sentenceless error_correction questions even when the gate stopped at another problem', () => {
    const full = validSet(dailyPlan(DATE));
    // One question short: the gate stops at the count before it reads any question.
    const set = { questions: full.questions.slice(0, 4) };
    for (const q of set.questions) if (q.type === 'error_correction') (q as Record<string, unknown>).context = '  ';
    const [v1] = summarizeComparison([record({ variant: 'V1', content: set })]);
    expect(gateResult(record({ variant: 'V1', content: set }))).toEqual({ passed: false, reason: 'wrong_question_count' });
    const total = set.questions.filter((q) => q.type === 'error_correction').length;
    expect(v1?.errorCorrection).toEqual({ total, withoutSentence: total });
  });

  it('averages tokens, cost and time over billed calls, and counts calls over 90 s and 150 s', () => {
    const [v1] = summarizeComparison([
      record({ variant: 'V1', inputTokens: 2000, outputTokens: 4000, costUsd: 0.044, durationMs: 60_000 }),
      record({ variant: 'V1', date: '2026-10-11', content: validSet(dailyPlan('2026-10-11')), inputTokens: 3000, outputTokens: 8000, costUsd: 0.086, durationMs: 120_000 }),
      record({ variant: 'V1', date: '2026-10-13', content: validSet(dailyPlan('2026-10-13')), inputTokens: 2500, outputTokens: 15_072, costUsd: 0.156, durationMs: 160_000, stopReason: 'max_tokens' }),
    ]);
    expect(v1?.avgInputTokens).toBe(2500);
    expect(v1?.avgOutputTokens).toBeCloseTo(9024, 0);
    expect(v1?.costPerSetUsd).toBeCloseTo(0.0953, 4);
    expect(v1?.totalCostUsd).toBeCloseTo(0.286, 6);
    expect(v1?.avgDurationS).toBeCloseTo(113.33, 2);
    expect(v1?.maxDurationS).toBe(160);
    expect(v1?.overLimit).toEqual({ 90: 2, 150: 1 });
  });

  it('writes a report with one row per variant and no generated text', () => {
    const report = renderComparisonReport(summarizeComparison([record({ variant: 'V1' })]), {
      dates: COMPARE_DATES,
      generatedAt: '2026-09-29T00:00:00.000Z',
    });
    expect(report).toContain('| V1: v2 + claude-sonnet-5, effort default | 1 of 1 |');
    expect(report).toContain('| V3: v2 + claude-sonnet-5-5, effort low | 0 of 0 |');
    expect(report).not.toContain('SECRET');
    expect(report).not.toContain('Flawed sentence');
  });
});

describe('generator comparison: questions.md', () => {
  it('holds only each question\'s sentence and instruction: no key, wrong answers or explanation', () => {
    const plan = dailyPlan(DATE);
    const text = renderQuestions([record({ variant: 'V2' }), record({ variant: 'V1', date: '2026-10-11', status: 'skipped_budget', content: undefined })]);
    expect(text).toContain('## V2: v2 + claude-sonnet-5-5, effort default — 2026-10-10 — passes the gate');
    expect(text).toContain('We waited for ___ bus');
    expect(text).toContain('Rewrite the full corrected sentence.');
    expect(text).toContain(`1. [${plan.slots[0]?.topicId} · ${plan.slots[0]?.type}]`);
    expect(text).not.toContain('SECRET');
    expect(text).not.toContain('2026-10-11'); // a call left out for the cap has no section
  });

  it('marks a missing sentence and a rejected set', () => {
    const set = validSet(dailyPlan(DATE));
    const ec = set.questions.findIndex((q) => q.type === 'error_correction');
    delete (set.questions[ec] as Record<string, unknown>).context;
    const text = renderQuestions([record({ variant: 'V1', content: set })]);
    expect(text).toContain('rejected: error_correction_missing_sentence');
    expect(text).toContain('(no sentence)');
  });
});
