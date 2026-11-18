import { describe, expect, it } from 'vitest';
import { PRODUCTION_PRACTICE, PRODUCTION_SCORING, buildBody, buildGeneratePracticeSetBodyFor, buildScoreAnswersBodyFor } from '../src/anthropic';
import { GENERATION_SYSTEM_PROMPT, SCORING_SYSTEM_PROMPT } from '../src/prompts';
import { FIRST_WAVE_TOPICS, FIRST_WAVE_TOPICS_ENABLED, TOPICS } from '../src/topics';
import { PRICES, costOf } from '../eval/lib/matrix';
import { MEASURE_SPEND_CAP_USD, charactersPerToken, renderStageReport } from '../eval/lib/measurement';
import {
  ANSWER_WRITER,
  ANSWER_WRITER_SYSTEM_PROMPT,
  CONTROL_TOPIC_ID,
  SETS_FOR_CONTROL,
  SETS_PER_NEW_TOPIC,
  TOPICS_DRY_RUN_LIMIT_USD,
  TOPICS_SPEND_CAP_USD,
  answerWriterBody,
  answerWriterCall,
  blankSourceText,
  builtAnswersFrom,
  fitsTopicsCap,
  fnv1a,
  generationBody,
  generationCalls,
  generationId,
  measuredTopics,
  normalizeAnswer,
  placeholderAnswers,
  placeholderItems,
  planCost,
  planTopicsDryRun,
  planWorstCase,
  pricedModel,
  renderTopicsDryRun,
  scoringCalls,
  topicItemsFrom,
  wireAnswer,
  type TopicItem,
} from '../eval/lib/topics_measurement';

/** A generated set as the practice path returns it. */
const SET = {
  items: [
    { id: 'sw-1', type: 'sentence_writing', context: 'You are describing your neighbour to a friend.', instruction: 'Using "who", write one sentence about what your neighbour does.' },
    { id: 'sw-2', type: 'sentence_writing', context: 'You are recommending a café.', instruction: 'Using "where", write one sentence about the café.', hint: 'where + clause' },
    { id: 'ec-1', type: 'error_correction', context: 'The woman which lives next door is a doctor.', instruction: 'Find the mistake and rewrite the full corrected sentence.' },
    { id: 'ec-2', type: 'error_correction', context: 'This is the book who I told you about.', instruction: 'Find the mistake and rewrite the full corrected sentence.' },
    { id: 'fb-1', type: 'fill_in_blank', instruction: 'The man ____ car was stolen called the police, ____ arrived quickly.' },
  ],
};

function items(): TopicItem[] {
  return topicItemsFrom('relativeClauses', 2, SET).items;
}

function item(id: string): TopicItem {
  return items().find((i) => i.sourceId === id) as TopicItem;
}

describe('the topics measurement: what is measured', () => {
  it('five first-wave topics with six sets each, and one live topic as the control with three', () => {
    const measured = measuredTopics();
    expect(measured.filter((m) => !m.control).map((m) => m.topic.id)).toEqual(FIRST_WAVE_TOPICS.map((t) => t.id));
    expect(measured.filter((m) => !m.control).every((m) => m.sets === SETS_PER_NEW_TOPIC)).toBe(true);
    expect(SETS_PER_NEW_TOPIC).toBe(6);
    const control = measured.filter((m) => m.control);
    expect(control).toHaveLength(1);
    expect(control[0]?.topic.id).toBe(CONTROL_TOPIC_ID);
    expect(control[0]?.sets).toBe(SETS_FOR_CONTROL);
    expect(SETS_FOR_CONTROL).toBe(3);
    expect(TOPICS.some((t) => t.id === CONTROL_TOPIC_ID)).toBe(true);
  });

  it('the budget: a $15 cap, a $12 dry-run limit, apart from the 1.4.0 cap', () => {
    expect(TOPICS_SPEND_CAP_USD).toBe(15);
    expect(TOPICS_DRY_RUN_LIMIT_USD).toBe(12);
    expect(MEASURE_SPEND_CAP_USD).toBe(30);
  });
});

describe('the topics measurement: generation through the live practice path', () => {
  it('the control topic sends byte for byte what the route sends', () => {
    expect(generationBody(CONTROL_TOPIC_ID)).toEqual(buildBody({ op: 'generate_practice_set', request: { deviceId: 'measurement', topicId: CONTROL_TOPIC_ID, count: 5 } }));
  });

  it('a first-wave topic gets the production prompt, model, effort and schema, with its own title and description', () => {
    const control = generationBody(CONTROL_TOPIC_ID);
    for (const topic of FIRST_WAVE_TOPICS) {
      const body = generationBody(topic.id);
      expect(body.model).toBe(PRODUCTION_PRACTICE.model);
      expect(body.system).toBe(GENERATION_SYSTEM_PROMPT);
      expect(body.thinking).toEqual({ type: 'adaptive' });
      expect(body.output_config).toEqual(control.output_config);
      expect(body.output_config.effort).toBe(PRODUCTION_PRACTICE.effort);
      expect(body.max_tokens).toBe(control.max_tokens);
      expect(body.messages[0]?.content).toBe(
        `Topic: "${topic.title}" — ${topic.description}\nGenerate exactly 5 fresh practice items: 2 sentence_writing, 2 error_correction, and 1 fill_in_blank. Each "id" must be a short unique slug.`,
      );
    }
  });

  it('the switch is a parameter of the measurement: the constant stays off and the route still refuses the ids', () => {
    expect(FIRST_WAVE_TOPICS_ENABLED).toBe(false);
    for (const topic of FIRST_WAVE_TOPICS) {
      const request = { deviceId: 'measurement', topicId: topic.id, count: 5 };
      expect(() => buildBody({ op: 'generate_practice_set', request })).toThrow('Unknown topicId.');
      expect(() => buildGeneratePracticeSetBodyFor(request, PRODUCTION_PRACTICE)).toThrow('Unknown topicId.');
      expect(() => buildGeneratePracticeSetBodyFor(request, PRODUCTION_PRACTICE, false)).toThrow('Unknown topicId.');
    }
  });

  it('33 calls, one id per topic and set', () => {
    const calls = generationCalls();
    expect(calls).toHaveLength(5 * 6 + 3);
    expect(new Set(calls.map((c) => c.customId)).size).toBe(33);
    expect(calls[0]?.customId).toBe(generationId('conditionals', 1));
    expect(calls.every((c) => c.stage === 'generation' && c.model === 'claude-sonnet-5-5')).toBe(true);
    expect(calls.filter((c) => c.group === CONTROL_TOPIC_ID)).toHaveLength(3);
  });

  it('a model without a price stops the plan', () => {
    expect(pricedModel('claude-haiku-5-5')).toBe('claude-haiku-5-5');
    expect(() => pricedModel('some-new-model')).toThrow('No price');
  });
});

describe('the topics measurement: generated items', () => {
  it('reads a set as the app would show and send it', () => {
    const parsed = topicItemsFrom('relativeClauses', 2, SET);
    expect(parsed.isSet).toBe(true);
    expect(parsed.dropped).toBe(0);
    expect(parsed.items.map((i) => i.id)).toEqual(['relativeClauses.2.0', 'relativeClauses.2.1', 'relativeClauses.2.2', 'relativeClauses.2.3', 'relativeClauses.2.4']);
    expect(parsed.items.map((i) => i.sourceId)).toEqual(['sw-1', 'sw-2', 'ec-1', 'ec-2', 'fb-1']);
    const ec = parsed.items[2] as TopicItem;
    expect(ec.prompt).toBe('The woman which lives next door is a doctor.\nFind the mistake and rewrite the full corrected sentence.');
    expect(ec.blanks).toBe(0);
    const fb = parsed.items[4] as TopicItem;
    expect(fb.prompt).toBe(fb.instruction);
    expect(fb.blanks).toBe(2);
    expect(parsed.items[1]?.hint).toBe('where + clause');
  });

  it('drops what the practice path would not accept, and says a non-set is not one', () => {
    const parsed = topicItemsFrom('conditionals', 1, { items: [{ id: 'a', type: 'essay', instruction: 'x' }, { id: 'b', type: 'fill_in_blank', instruction: 'If it ____ , we stay.' }, { type: 'fill_in_blank', instruction: 'no id' }] });
    expect(parsed.items).toHaveLength(1);
    expect(parsed.dropped).toBe(2);
    expect(topicItemsFrom('conditionals', 1, { questions: [] })).toEqual({ items: [], dropped: 0, isSet: false });
    expect(topicItemsFrom('conditionals', 1, undefined).isSet).toBe(false);
  });

  it("the blanks are counted where the app fills them (its blankSourceText)", () => {
    expect(blankSourceText('She ____ here.', 'Fill in the blank.')).toBe('She ____ here.');
    expect(blankSourceText('A ____ b.', 'C ____ d.')).toBe('A ____ b.\nC ____ d.');
    expect(blankSourceText('Background.', 'She ____ here.')).toBe('She ____ here.');
    expect(blankSourceText(undefined, 'She ____ here.')).toBe('She ____ here.');
  });
});

describe('the topics measurement: the answer writer', () => {
  it('one harness call per set: the writer model at low effort, the items as the learner sees them', () => {
    const body = answerWriterBody(items());
    expect(body.model).toBe(ANSWER_WRITER);
    expect(body.system).toBe(ANSWER_WRITER_SYSTEM_PROMPT);
    expect(body.thinking).toEqual({ type: 'adaptive' });
    expect(body.output_config.effort).toBe('low');
    const sent = JSON.parse(body.messages[0]?.content ?? '{}') as { items: Record<string, unknown>[] };
    expect(sent.items).toHaveLength(5);
    expect(sent.items[4]).toEqual({ itemId: 'relativeClauses.2.4', type: 'fill_in_blank', topic: 'Relative Clauses', text: item('fb-1').prompt, blanks: 2 });
    const call = answerWriterCall('relativeClauses', 2, items());
    expect(call.customId).toBe('tans_relativeClauses_2');
    expect(call.stage).toBe('answers');
  });

  it('the wire answer: a single box, an assembled sentence, a written sentence', () => {
    const single = topicItemsFrom('prepositions', 1, { items: [{ id: 'f', type: 'fill_in_blank', instruction: 'She is good ____ maths.' }] }).items[0] as TopicItem;
    expect(wireAnswer(single, ['at'])).toEqual({ userAnswer: 'at', fills: ['at'] });
    expect(wireAnswer(single, ['at', 'in'])).toBeNull();
    expect(wireAnswer(item('fb-1'), ['whose', 'who'])).toEqual({
      userAnswer: 'The man whose car was stolen called the police, who arrived quickly.',
      fills: ['whose', 'who'],
    });
    expect(wireAnswer(item('ec-1'), ['The woman who lives next door is a doctor.'])).toEqual({ userAnswer: 'The woman who lives next door is a doctor.' });
    expect(wireAnswer(item('ec-1'), [])).toBeNull();
    expect(wireAnswer(item('ec-1'), ['  '])).toBeNull();
  });

  it('a blank that takes no word is assembled as the app assembles "no article"', () => {
    const article = topicItemsFrom('articles', 1, { items: [{ id: 'f', type: 'fill_in_blank', instruction: '____ water is essential for ____ life on ____ planet.' }] }).items[0] as TopicItem;
    expect(wireAnswer(article, ['—', '-', 'the'])).toEqual({ userAnswer: 'Water is essential for life on the planet.', fills: ['—', '—', 'the'] });
  });

  const WRITTEN = {
    answers: [
      { itemId: 'relativeClauses.2.0', key: ['My neighbour is a nurse who works nights.'], variant: ['ignored for a written sentence'], mistakes: [{ answer: ['My neighbour is a nurse which works nights.'], breaks: 'which for a person' }, { answer: ['extra'], breaks: 'x' }] },
      { itemId: 'relativeClauses.2.2', key: ['The woman who lives next door is a doctor.'], variant: ['The woman that lives next door is a doctor.'], mistakes: [{ answer: ['The woman which lives next door is a doctor.'], breaks: 'original left' }, { answer: ['The woman whom lives next door is a doctor.'], breaks: 'whom as subject' }] },
      { itemId: 'relativeClauses.2.3', key: ['This is the book who I told you about.'], variant: [], mistakes: [{ answer: ['this is the book who I told you about'], breaks: 'same as key' }, { answer: ['This is the book what I told you about.'], breaks: 'what' }] },
      { itemId: 'relativeClauses.2.4', key: ['whose', 'who'], variant: ['whose'], mistakes: [{ answer: ['who', 'who'], breaks: 'who for possession' }, { answer: ['whose', 'that'], breaks: 'that after a comma' }] },
      { itemId: 'unknown', key: ['x'], variant: [], mistakes: [] },
    ],
  };

  it('builds the key, the variant and the mistakes with their verdict by construction', () => {
    const built = builtAnswersFrom(items(), WRITTEN);
    const of = (id: string) => built.answers.filter((a) => a.itemId === id);
    expect(of('relativeClauses.2.0').map((a) => [a.kind, a.truth])).toEqual([['key', true], ['mistake1', false]]);
    expect(of('relativeClauses.2.2').map((a) => [a.kind, a.truth])).toEqual([['key', true], ['variant', true], ['mistake1', false], ['mistake2', false]]);
    expect(of('relativeClauses.2.2')[2]?.breaks).toBe('original left');
    const fb = of('relativeClauses.2.4');
    expect(fb.map((a) => a.kind)).toEqual(['key', 'mistake1', 'mistake2']);
    expect(fb[0]?.userAnswer).toBe('The man whose car was stolen called the police, who arrived quickly.');
    expect(fb[0]?.fills).toEqual(['whose', 'who']);
    expect(fb[2]?.userAnswer).toBe('The man whose car was stolen called the police, that arrived quickly.');
    // The scorer gets the question's own prompt and type.
    expect(fb[0]?.item).toEqual({ id: `q${fnv1a('relativeClauses.2.4')}`, type: 'fill_in_blank', prompt: item('fb-1').prompt });
  });

  it('records what it could not use, per item', () => {
    const { answers, problems } = builtAnswersFrom(items(), WRITTEN);
    const codes = (id: string) => problems.filter((p) => p.itemId === id).map((p) => p.code);
    expect(codes('relativeClauses.2.1')).toEqual(['no_entry']);
    expect(answers.some((a) => a.itemId === 'relativeClauses.2.1')).toBe(false);
    // The key repeats the flawed sentence; the first mistake equals the key.
    expect(codes('relativeClauses.2.3')).toEqual(['key_equals_original', 'mistake_equals_right_answer', 'mistakes_missing']);
    // A variant with one entry for two blanks does not fit.
    expect(codes('relativeClauses.2.4')).toEqual(['variant_unusable']);
    expect(codes('relativeClauses.2.0')).toEqual([]);
    expect(builtAnswersFrom(items(), null).problems.map((p) => p.code)).toEqual(['no_entry', 'no_entry', 'no_entry', 'no_entry', 'no_entry']);
  });

  it('an item without a usable key gets no answers at all', () => {
    const built = builtAnswersFrom(items(), { answers: [{ itemId: 'relativeClauses.2.4', key: ['whose'], variant: [], mistakes: [{ answer: ['who', 'who'], breaks: 'x' }] }] });
    expect(built.answers).toEqual([]);
    expect(built.problems.find((p) => p.itemId === 'relativeClauses.2.4')?.code).toBe('key_unusable');
  });

  it('answer ids are opaque, unique and stable: the scorer cannot read the verdict from them', () => {
    const a = builtAnswersFrom(items(), WRITTEN).answers;
    const b = builtAnswersFrom(items(), WRITTEN).answers;
    expect(a.map((x) => x.id)).toEqual(b.map((x) => x.id));
    expect(new Set(a.map((x) => x.id)).size).toBe(a.length);
    for (const answer of a) {
      expect(answer.id).toMatch(/^a[0-9a-f]{8}$/);
      expect(answer.item.id).toMatch(/^q[0-9a-f]{8}$/);
    }
  });

  it('normalizeAnswer ignores case, spacing, typographic quotes and the final stop', () => {
    expect(normalizeAnswer('  It’s  done. ')).toBe(normalizeAnswer("it's done"));
    expect(normalizeAnswer('who')).not.toBe(normalizeAnswer('that'));
  });
});

describe('the topics measurement: scoring with the production cell', () => {
  const answers = () => placeholderAnswers([...placeholderItems('conditionals', 1), ...placeholderItems('conditionals', 2)]);

  it('every call is the production scoring request for one set: five answers at most, never two answers to one question', () => {
    const built = answers();
    const calls = scoringCalls(built);
    expect(calls.flatMap((c) => c.answerIds).sort()).toEqual(built.map((a) => a.id).sort());
    const byId = new Map(built.map((a) => [a.id, a]));
    for (const { call, answerIds } of calls) {
      expect(answerIds.length).toBeLessThanOrEqual(5);
      expect(new Set(answerIds.map((id) => byId.get(id)?.item.id)).size).toBe(answerIds.length);
      expect(new Set(answerIds.map((id) => byId.get(id)?.set)).size).toBe(1);
      expect(call.model).toBe(PRODUCTION_SCORING.model);
      expect(call.model).toBe('claude-haiku-5-5');
      expect(call.body.system).toBe(SCORING_SYSTEM_PROMPT);
      expect(call.body.output_config.effort).toBe('low');
      const request = { deviceId: 'measurement', items: answerIds.map((id) => ({ id, type: byId.get(id)?.item.type as string, prompt: byId.get(id)?.item.prompt as string, userAnswer: byId.get(id)?.userAnswer as string })) };
      expect(call.body).toEqual(buildScoreAnswersBodyFor(request, PRODUCTION_SCORING));
      expect(call.body).toEqual(buildBody({ op: 'score_answers', request }));
    }
  });

  it('what the scorer sees carries no kind and no verdict', () => {
    for (const { call } of scoringCalls(answers())) {
      const sent = JSON.parse(call.body.messages[0]?.content ?? '{}') as { items: Record<string, string>[] };
      for (const sentItem of sent.items) {
        expect(Object.keys(sentItem)).toEqual(['id', 'type', 'prompt', 'userAnswer']);
        expect(sentItem.id).toMatch(/^a[0-9a-f]{8}$/);
      }
    }
  });

  it('resuming: the same answers give the same calls, another set adds calls without changing these, a changed set gets new ids', () => {
    const first = scoringCalls(answers()).map((c) => c.call.customId);
    expect(scoringCalls(answers()).map((c) => c.call.customId)).toEqual(first);
    expect(new Set(first).size).toBe(first.length);
    expect(first.every((id) => /^tscore_[0-9a-f]{8}$/.test(id))).toBe(true);
    // A third set generated on a later run of the folder.
    const more = scoringCalls([...answers(), ...placeholderAnswers(placeholderItems('conditionals', 3))]).map((c) => c.call.customId);
    expect(more.slice(0, first.length)).toEqual(first);
    expect(more.length).toBeGreaterThan(first.length);
    // Set 1 loses three answers: its calls are new, set 2's are the same.
    const set2 = scoringCalls(placeholderAnswers(placeholderItems('conditionals', 2))).map((c) => c.call.customId);
    const changed = scoringCalls(answers().slice(3)).map((c) => c.call.customId);
    expect(set2.every((id) => changed.includes(id))).toBe(true);
    expect(changed.filter((id) => !set2.includes(id)).some((id) => first.includes(id))).toBe(false);
  });
});

describe('the topics measurement: the dry run and the cap', () => {
  const ratio = charactersPerToken();
  const plan = planTopicsDryRun(ratio);

  it('the calls per stage', () => {
    expect(plan.generation).toHaveLength(33);
    expect(plan.answers).toHaveLength(33);
    // 33 sets × (2 written × 2 + 2 corrections × 4 + 1 blank item × 4) answers, five to a call.
    expect(plan.answerCount).toBe(33 * 16);
    // A question has at most four answers and a call takes one per question: four calls a set.
    expect(plan.scoring).toHaveLength(33 * 4);
    expect(new Set([...plan.generation, ...plan.answers, ...plan.scoring].map((c) => c.customId)).size).toBe(33 + 33 + 132);
  });

  it("the estimate comes from matrix.ts's prices and stays under the dry-run limit", () => {
    const all = [...plan.generation, ...plan.answers, ...plan.scoring];
    const byHand = all.reduce((n, c) => n + (c.estimate.inputTokens * PRICES[c.model].input + c.estimate.outputTokens * PRICES[c.model].output) / 1_000_000, 0);
    expect(planCost(all)).toBeCloseTo(byHand, 10);
    expect(planCost(all)).toBeCloseTo(all.reduce((n, c) => n + costOf(c.model, c.estimate, true), 0), 10);
    expect(planCost(all)).toBeGreaterThan(0.5);
    expect(planCost(all)).toBeLessThanOrEqual(TOPICS_DRY_RUN_LIMIT_USD);
  });

  it('the printout names the stages, the calls, the spend and both limits, and nothing else', () => {
    const summary = renderTopicsDryRun(plan, ratio);
    expect(summary.totalCalls).toBe(198);
    expect(summary.withinLimit).toBe(true);
    expect(summary.text).toContain('dry run (no API call)');
    expect(summary.text).toContain('| generation | Topic Practice sets, the live practice path | claude-sonnet-5-5 | 33 |');
    expect(summary.text).toContain('| answers | the answer writer, one call per set | claude-sonnet-5-5 | 33 |');
    expect(summary.text).toContain("| scoring | the production scoring cell (C8), one set's questions a call | claude-haiku-5-5 | 132 |");
    expect(summary.text).toContain(`**$${summary.totalUsd.toFixed(2)}**`);
    expect(summary.text).toContain('within the dry-run limit of $12.00');
    expect(summary.text).toContain('Hard cap on measured spend: $15.00');
    expect(summary.text).toContain('articles × 3 (control)');
  });

  it('even the worst case (every call writing all its max_tokens) stays under the cap', () => {
    const all = [...plan.generation, ...plan.answers, ...plan.scoring];
    expect(planWorstCase(all)).toBeGreaterThan(planCost(all));
    expect(planWorstCase(all)).toBeLessThan(TOPICS_SPEND_CAP_USD);
    const summary = renderTopicsDryRun(plan, ratio);
    expect(summary.worstCaseUsd).toBeCloseTo(planWorstCase(all), 10);
    expect(summary.text).toContain(`Worst case, every call writing all its max_tokens allows: $${summary.worstCaseUsd.toFixed(2)} (under the cap).`);
  });

  it('an estimate over the limit is said to be over', () => {
    const big = { ...plan, scoring: Array.from({ length: 9000 }, () => plan.scoring[0] as (typeof plan.scoring)[number]) };
    const summary = renderTopicsDryRun(big, ratio);
    expect(summary.withinLimit).toBe(false);
    expect(summary.text).toContain('OVER the dry-run limit of $12.00');
  });

  it('the cap check before every call: spent + estimate × 1.25 ≤ cap', () => {
    expect(fitsTopicsCap(0, 0.02)).toBe(true);
    expect(fitsTopicsCap(14.97, 0.02)).toBe(true);
    expect(fitsTopicsCap(14.98, 0.02)).toBe(false);
    expect(fitsTopicsCap(15, 0)).toBe(true);
    expect(fitsTopicsCap(15.01, 0)).toBe(false);
    expect(fitsTopicsCap(0, 12)).toBe(true);
    expect(fitsTopicsCap(0, 12.01)).toBe(false);
    expect(fitsTopicsCap(3.99, 0.02, 4)).toBe(false);
  });

  it("the run's stage report reads the topics plan (measured against the estimate)", () => {
    const calls = [...plan.generation.slice(0, 2), ...plan.scoring.slice(0, 1)];
    const report = renderStageReport('t', calls, [
      { customId: calls[0]?.customId as string, stage: 'generation', group: 'conditionals', model: 'claude-sonnet-5-5', status: 'ok', inputTokens: 1000, outputTokens: 600, costUsd: 0.008, durationMs: 6000 },
      { customId: calls[1]?.customId as string, stage: 'generation', group: 'conditionals', model: 'claude-sonnet-5-5', status: 'skipped_budget', costUsd: 0 },
    ]);
    expect(report).toContain('| generation | conditionals | 2 | 1 | 0 | 1 |');
    expect(report).toContain('| scoring | C8 | 1 | 0 | 0 | 0 |');
  });
});
