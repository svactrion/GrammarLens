import { describe, expect, it } from 'vitest';
import hintsSource from '../../lib/data/topic_hints.dart?raw';
import {
  CHECK_IDS,
  HINT_CARDS,
  NEAR_DUPLICATE_SIMILARITY,
  answersByItem,
  changedWords,
  checkHintCard,
  checkItems,
  checkLengthLevel,
  checkSingleAnswer,
  checkTopic,
  findDuplicates,
  gateProblems,
  gateSet,
  hasPassive,
  jaccard,
  keySentence,
  renderCheckSummary,
  scenarioWords,
  summarizeChecks,
  type ItemAnswers,
} from '../eval/lib/topics_checks';
import { finalTopics } from '../eval/lib/topics_final';
import { CONTROL_TOPIC_ID, builtAnswersFrom, measuredTopics, topicItemsFrom, type TopicItem } from '../eval/lib/topics_measurement';

type Raw = { type: 'fill_in_blank' | 'error_correction' | 'sentence_writing'; context?: string; instruction: string; hint?: string };

const FIX = 'Find the mistake and rewrite the full corrected sentence.';

/** One item of [topicId] with its key (and variant), as a run would have it. */
function made(topicId: string, raw: Raw, key?: string[], variant: string[] = [], set = 1): { item: TopicItem; answers: ItemAnswers } {
  const item = topicItemsFrom(topicId, set, { items: [{ id: 'x', ...raw }] }).items[0] as TopicItem;
  if (!key) return { item, answers: {} };
  const built = builtAnswersFrom([item], { answers: [{ itemId: item.id, key, variant, mistakes: [] }] });
  return { item, answers: answersByItem(built.answers).get(item.id) ?? {} };
}

const codes = (flags: { code: string }[] | null) => (flags === null ? null : flags.map((f) => f.code));

describe('topics checks: the gate', () => {
  const good = {
    items: [
      { id: 'a', type: 'sentence_writing', context: 'A situation.', instruction: 'Write one sentence with "if".' },
      { id: 'b', type: 'sentence_writing', context: 'Another one.', instruction: 'Write one sentence with "unless".' },
      { id: 'c', type: 'error_correction', context: 'If it will rain, we stay home.', instruction: FIX },
      { id: 'd', type: 'error_correction', context: 'If I would know, I would tell you.', instruction: FIX },
      { id: 'e', type: 'fill_in_blank', instruction: 'If she ____ (study), she will pass.' },
    ],
  };

  it('a set of five in the 2 : 2 : 1 mix with sound items passes', () => {
    const gate = gateSet('conditionals', 3, good);
    expect(gate.passed).toBe(true);
    expect(gate.problems).toEqual([]);
    expect(gate.items).toHaveLength(5);
    expect(gate.items[0]?.id).toBe('conditionals.3.0');
  });

  it('names what is wrong with a set', () => {
    expect(gateSet('conditionals', 1, { nope: true })).toMatchObject({ passed: false, problems: ['not_a_set'], items: [] });
    expect(gateSet('conditionals', 1, { items: good.items.slice(0, 4) }).problems).toEqual(['wrong_count:4']);
    expect(gateSet('conditionals', 1, { items: [...good.items.slice(0, 4), { id: 'z', type: 'poem', instruction: 'x' }] }).problems).toEqual(['malformed_entries:1', 'wrong_count:4']);
    const mix = gateSet('conditionals', 1, { items: [...good.items.slice(0, 4), { id: 'e', type: 'error_correction', context: 'If he come, tell me.', instruction: FIX }] });
    expect(mix.problems).toEqual(['wrong_mix:2/3/0']);
    expect(mix.passed).toBe(false);
  });

  it("the prompt's own rules, per item", () => {
    expect(gateProblems({ type: 'fill_in_blank', blanks: 0 })).toEqual(['fill_in_blank_without_blank']);
    expect(gateProblems({ type: 'fill_in_blank', blanks: 4 })).toEqual([]);
    expect(gateProblems({ type: 'fill_in_blank', blanks: 5 })).toEqual(['more_than_4_blanks']);
    expect(gateProblems({ type: 'error_correction', blanks: 0 })).toEqual(['error_correction_without_sentence']);
    expect(gateProblems({ type: 'error_correction', context: 'Two words', blanks: 0 })).toEqual(['error_correction_without_sentence']);
    expect(gateProblems({ type: 'error_correction', context: 'She go home.', blanks: 0 })).toEqual([]);
    expect(gateProblems({ type: 'sentence_writing', blanks: 0 })).toEqual([]);
    const bad = gateSet('conditionals', 1, { items: [...good.items.slice(0, 4), { id: 'e', type: 'fill_in_blank', instruction: 'No blank here.' }] });
    expect(bad.problems).toEqual([]);
    expect(bad.passed).toBe(false);
  });
});

describe('topics checks: the item is about its topic', () => {
  it('passes an item whose key shows the structure, or whose text names the topic', () => {
    expect(codes(checkTopic(...args(made('conditionals', { type: 'fill_in_blank', instruction: 'If she ____ (study), she will pass.' }, ['studies']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('passiveVoice', { type: 'error_correction', context: 'The bridge built in 1990.', instruction: FIX }, ['The bridge was built in 1990.']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('passiveVoice', { type: 'sentence_writing', instruction: 'Write one sentence in the passive about your city.' }, ['I love my city.']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('relativeClauses', { type: 'sentence_writing', instruction: 'Describe your teacher in one sentence.' }, ['My teacher is a woman who loves books.']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('comparativesSuperlatives', { type: 'fill_in_blank', instruction: 'This is ____ (good) film I know.' }, ['the best']))))).toEqual([]);
  });

  it('flags an item with no sign of its topic', () => {
    expect(codes(checkTopic(...args(made('conditionals', { type: 'error_correction', context: 'She go to school every day.', instruction: FIX }, ['She goes to school every day.']))))).toEqual(['no_sign_of_topic']);
    expect(codes(checkTopic(...args(made('passiveVoice', { type: 'sentence_writing', instruction: 'Describe your morning in one sentence.' }, ['I usually drink coffee and read the news.']))))).toEqual(['no_sign_of_topic']);
    expect(codes(checkTopic(...args(made('relativeClauses', { type: 'fill_in_blank', instruction: 'Who ____ (call) you yesterday?' }, ['called']))))).toEqual(['no_sign_of_topic']);
  });

  it('prepositions and articles: the blank or the correction must be of the word class', () => {
    expect(codes(checkTopic(...args(made('prepositions', { type: 'fill_in_blank', instruction: 'She is good ____ maths.' }, ['at']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('prepositions', { type: 'fill_in_blank', instruction: 'It ____ (depend) the weather.' }, ['depends on']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('prepositions', { type: 'fill_in_blank', instruction: 'She ____ (go) to school in the morning.' }, ['goes']))))).toEqual(['no_sign_of_topic']);
    expect(codes(checkTopic(...args(made('prepositions', { type: 'error_correction', context: 'We arrived to the station at noon.', instruction: FIX }, ['We arrived at the station at noon.']))))).toEqual([]);
    expect(codes(checkTopic(...args(made('prepositions', { type: 'error_correction', context: 'We arrives at the station at noon.', instruction: FIX }, ['We arrive at the station at noon.']))))).toEqual(['no_sign_of_topic']);
    expect(codes(checkTopic(...args(made(CONTROL_TOPIC_ID, { type: 'fill_in_blank', instruction: '____ water is essential.' }, ['—']))))).toEqual([]);
    expect(codes(checkTopic(...args(made(CONTROL_TOPIC_ID, { type: 'error_correction', context: 'She is a honest person.', instruction: FIX }, ['She is an honest person.']))))).toEqual([]);
  });

  it('without a key it runs on the text alone, or says it did not run', () => {
    expect(codes(checkTopic(...args(made('conditionals', { type: 'error_correction', context: 'If it will rain, we stay.', instruction: FIX }))))).toEqual([]);
    expect(checkTopic(...args(made('conditionals', { type: 'sentence_writing', instruction: 'Write one sentence about your plans.' })))).toBeNull();
  });

  it('be + past participle is found with adverbs between, not in an active sentence', () => {
    expect(hasPassive('The report has been carefully written.')).toBe(true);
    expect(hasPassive("It's made in Italy.")).toBe(true);
    expect(hasPassive('The window got broken.')).toBe(true);
    expect(hasPassive('She is writing a report.')).toBe(false);
    expect(hasPassive('They built the bridge in 1990.')).toBe(false);
  });

  it('changedWords is what a correction took out and put in', () => {
    expect(changedWords('We arrived to the station.', 'We arrived at the station.')).toEqual({ removed: ['to'], added: ['at'] });
    expect(changedWords('Same words.', 'same words')).toEqual({ removed: [], added: [] });
  });
});

function args(m: { item: TopicItem; answers: ItemAnswers }): [TopicItem, ItemAnswers] {
  return [m.item, m.answers];
}

describe('topics checks: a blank has one natural answer', () => {
  const risk = (topicId: string, instruction: string, key: string[], variant: string[] = []) => checkSingleAnswer(...args(made(topicId, { type: 'fill_in_blank', instruction }, key, variant)));

  it('only fill_in_blank items are checked; without a key it does not run', () => {
    expect(checkSingleAnswer(...args(made('relativeClauses', { type: 'error_correction', context: 'The man which called is here.', instruction: FIX }, ['The man who called is here.'], ['The man that called is here.'])))).toEqual([]);
    expect(checkSingleAnswer(...args(made('relativeClauses', { type: 'fill_in_blank', instruction: 'The man ____ called is here.' })))).toBeNull();
  });

  it('a second correct answer from the writer is flagged with both', () => {
    const flags = risk('prepositions', 'I will see you ____ the morning.', ['in'], ['during']);
    expect(flags?.[0]).toEqual({ check: 'single_answer', code: 'second_answer_listed', detail: 'key: in; also correct: during' });
  });

  it('who / that and which / that in a defining clause, not after a comma', () => {
    expect(codes(risk('relativeClauses', 'The man ____ called is here.', ['who']))).toEqual(['several_answers_fit']);
    expect(risk('relativeClauses', 'The book ____ I bought is great.', ['which'])?.[0]?.detail).toContain('can be left out');
    expect(codes(risk('relativeClauses', 'My brother, ____ lives in Rome, is a chef.', ['who']))).toEqual([]);
    expect(codes(risk('relativeClauses', 'The man ____ car was stolen is here.', ['whose']))).toEqual([]);
    expect(codes(risk('relativeClauses', 'The town ____ I grew up is small.', ['where']))).toEqual(['several_answers_fit']);
  });

  it('prepositions that compete in the same place', () => {
    expect(codes(risk('prepositions', 'She is waiting ____ the station.', ['at']))).toEqual(['several_answers_fit']);
    expect(codes(risk('prepositions', 'We play tennis ____ the weekend.', ['at']))).toEqual(['several_answers_fit']);
    expect(codes(risk('prepositions', 'She was born ____ 1990.', ['in']))).toEqual([]);
    expect(codes(risk('prepositions', 'Wait here ____ I come back.', ['until']))).toEqual(['several_answers_fit']);
    expect(codes(risk('prepositions', 'I often think ____ my old school.', ['about']))).toEqual(['several_answers_fit']);
    expect(codes(risk('prepositions', 'It depends ____ the weather.', ['on']))).toEqual([]);
  });

  it('conditionals: was / were, the modal of the result, if / when', () => {
    expect(codes(risk('conditionals', 'If I ____ you, I would apologise.', ['were']))).toEqual(['several_answers_fit']);
    expect(codes(risk('conditionals', 'If I had time, I ____ help you.', ['would']))).toEqual(['several_answers_fit']);
    expect(codes(risk('conditionals', '____ you heat ice, it melts.', ['if']))).toEqual(['several_answers_fit']);
    expect(codes(risk('conditionals', 'If she ____ (study), she will pass.', ['studies']))).toEqual([]);
  });

  it('passive: a verb in brackets and nothing that fixes the time', () => {
    expect(codes(risk('passiveVoice', 'The report ____ (write) by the team.', ['was written']))).toEqual(['several_answers_fit']);
    expect(codes(risk('passiveVoice', 'The bridge ____ (build) in 1990.', ['was built']))).toEqual([]);
    expect(codes(risk('passiveVoice', 'The letters ____ (deliver) every morning.', ['are delivered']))).toEqual([]);
  });

  it('comparatives: adjectives that take both forms, and free variants', () => {
    expect(codes(risk('comparativesSuperlatives', 'She is ____ (clever) than her brother.', ['cleverer']))).toEqual(['several_answers_fit']);
    expect(codes(risk('comparativesSuperlatives', 'This road is ____ (simple) of all.', ['the most simple']))).toEqual(['several_answers_fit']);
    expect(codes(risk('comparativesSuperlatives', 'We walked ____ (far) than planned.', ['further']))).toEqual(['several_answers_fit']);
    expect(codes(risk('comparativesSuperlatives', 'He is ____ (tall) than me.', ['taller']))).toEqual([]);
  });

  it('every blank of a multi-blank item is looked at', () => {
    const flags = risk('relativeClauses', 'The girl ____ won lives in a town ____ I know well.', ['who', 'that']);
    expect(flags?.map((f) => f.detail.slice(0, 7))).toEqual(['blank 1', 'blank 2']);
  });
});

describe('topics checks: duplicates', () => {
  const set = (n: number, raws: Raw[]) => topicItemsFrom('conditionals', n, { items: raws.map((r, i) => ({ id: `i${i}`, ...r })) }).items;

  it('the same words in a set and across sets, on both items', () => {
    const a = set(1, [{ type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic.', instruction: FIX }, { type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic.', instruction: FIX }]);
    const b = set(2, [{ type: 'error_correction', context: 'if it will rain tomorrow, we will cancel the picnic', instruction: FIX }]);
    const found = findDuplicates([...a, ...b]);
    expect(found.get('conditionals.1.0')?.map((f) => f.code).sort()).toEqual(['duplicate_across_sets', 'duplicate_in_set']);
    expect(found.get('conditionals.2.0')?.map((f) => f.code)).toEqual(['duplicate_across_sets', 'duplicate_across_sets']);
    expect(found.get('conditionals.1.1')?.[0]?.detail).toBe('same words as conditionals.1.0');
  });

  it('a near-duplicate shares most of its scenario words; a shared stock instruction is not one', () => {
    const items = [
      ...set(1, [{ type: 'error_correction', context: 'If the company would have invested in new equipment, the factory would not have closed.', instruction: FIX }]),
      ...set(2, [{ type: 'error_correction', context: 'If the company had invested in new equipment earlier, the factory would not close.', instruction: FIX }]),
      ...set(3, [{ type: 'error_correction', context: 'If I will see her at the party tonight, I will tell her the news.', instruction: FIX }]),
    ];
    const found = findDuplicates(items);
    expect(found.get('conditionals.1.0')?.[0]?.code).toBe('near_duplicate_across_sets');
    expect(found.get('conditionals.1.0')?.[0]?.detail).toMatch(/^\d+ % of the scenario words shared with conditionals\.2\.0$/);
    expect(found.has('conditionals.3.0')).toBe(false);
    expect(NEAR_DUPLICATE_SIMILARITY).toBe(0.6);
  });

  it('items of different topics, and items too short to compare, are not paired', () => {
    const other = topicItemsFrom('passiveVoice', 1, { items: [{ id: 'p', type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic.', instruction: FIX }] }).items;
    const mine = set(1, [{ type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic.', instruction: FIX }, { type: 'fill_in_blank', instruction: 'If he ____ , tell me.' }, { type: 'fill_in_blank', instruction: 'If she ____ , tell me.' }]);
    expect(findDuplicates([...other, ...mine]).size).toBe(0);
  });

  it('scenario words leave out function words and the stock words of instructions', () => {
    expect([...scenarioWords({ type: 'sentence_writing', context: 'You are writing to a colleague.', instruction: 'Using "if", write one sentence.' })].sort()).toEqual(['colleague', 'writing']);
    expect(jaccard(new Set(['a', 'b']), new Set(['b', 'c']))).toBeCloseTo(1 / 3);
    expect(jaccard(new Set(), new Set(['b']))).toBe(0);
  });
});

describe('topics checks: length and level', () => {
  it('a normal item has no flag', () => {
    expect(checkLengthLevel(...args(made('conditionals', { type: 'error_correction', context: 'If it will rain, we will stay home.', instruction: FIX }, ['If it rains, we will stay home.'])))).toEqual([]);
  });

  it("the proxy's own limits, the one-sentence instruction, and the level proxies", () => {
    const long = made('conditionals', { type: 'sentence_writing', context: `${'word '.repeat(420)}.`, instruction: 'Write one sentence. Then write another. And a third.' });
    expect(codes(checkLengthLevel(...args(long)))).toEqual(['text_over_2000_characters', 'instruction_not_one_sentence', 'sentence_over_35_words']);
    const hard = made('passiveVoice', { type: 'fill_in_blank', instruction: 'The internationalization of telecommunications ____ (discuss) at the interdisciplinary congress last year. Fill in the blank.' });
    expect(codes(checkLengthLevel(...args(hard)))).toEqual(['several_very_long_words']);
  });

  it('an error correction whose key changes more than one short run', () => {
    const rewrite = made('conditionals', { type: 'error_correction', context: 'If it will rain, we are going to stay at home all day long.', instruction: FIX }, ['Should it rain tomorrow, the whole family stays indoors and watches films.']);
    expect(codes(checkLengthLevel(...args(rewrite)))).toEqual(['correction_over_4_words']);
    const twoFixes = made('conditionals', { type: 'error_correction', context: 'If it will rain, we stay at home and my sister watch films.', instruction: FIX }, ['If it rains, we stay at home and my sister watches films.']);
    expect(codes(checkLengthLevel(...args(twoFixes)))).toEqual(['correction_over_4_words']);
  });
});

describe('topics checks: the hint card', () => {
  it("the cards are the app's, line for line", () => {
    // Every topic the measurement can meet: the first run's six, and since the
    // final configuration the other four live topics.
    const measured = finalTopics().map((m) => m.topic.id);
    expect(measured).toHaveLength(10);
    expect(measuredTopics().every((m) => measured.includes(m.topic.id))).toBe(true);
    expect(Object.keys(HINT_CARDS).sort()).toEqual([...measured].sort());
    for (const [topicId, lines] of Object.entries(HINT_CARDS)) {
      const start = hintsSource.indexOf(`TopicId.${topicId}: [`);
      expect(start).toBeGreaterThan(0);
      const block = hintsSource.slice(start, hintsSource.indexOf('],', start));
      const dartLines = [...block.matchAll(/^\s*(?:'((?:[^'\\]|\\.)*)'|"((?:[^"\\]|\\.)*)"),\s*$/gm)].map((m) => (m[1] ?? m[2] ?? '').replace(/\\'/g, "'"));
      expect(dartLines).toEqual([...lines]);
    }
  });

  const card = (topicId: string, raw: Raw, key: string[]) => checkHintCard(...args(made(topicId, raw, key)));
  const sw: Raw = { type: 'sentence_writing', instruction: 'Write one sentence.' };

  it('conditionals: will / would in the if-part conflicts; what the card has no line for is silent', () => {
    expect(codes(card('conditionals', sw, ['If it rains, we will stay home.']))).toEqual([]);
    expect(codes(card('conditionals', sw, ['If I had known, I would have called.']))).toEqual([]);
    expect(card('conditionals', sw, ['If you will follow me, I will show you the room.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(card('conditionals', sw, ['Unless it rains, we will go.'])?.[0]).toMatchObject({ code: 'card_silent' });
    expect(card('conditionals', sw, ['If I had studied medicine, I would be a doctor now.'])?.[0]?.detail).toContain('mixed conditional');
    expect(card('conditionals', sw, ['If you heat ice, it melts.'])?.[0]?.detail).toContain('general truth');
    expect(card('conditionals', { type: 'fill_in_blank', instruction: 'If she ____ (study), she will pass.' }, ['will study'])?.[0]).toMatchObject({ code: 'card_conflict' });
  });

  it('passive: the card applies when the key has be + past participle', () => {
    expect(codes(card('passiveVoice', sw, ['The bridge was built in 1990.']))).toEqual([]);
    expect(codes(card('passiveVoice', sw, ['They built the bridge in 1990.']))).toEqual(['card_silent']);
  });

  it('prepositions: at / on / in against the card for days, months, years and clock times', () => {
    expect(codes(card('prepositions', sw, ['We met on Monday in May at 5 pm.']))).toEqual([]);
    expect(card('prepositions', sw, ['The course starts on May 5th.'])?.[0]?.detail).toContain('in: inside or a period');
    expect(card('prepositions', sw, ['We met in Monday.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(card('prepositions', sw, ['She was born at 1990.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(codes(card('prepositions', sw, ['It depends on the weather.']))).toEqual([]);
  });

  it('relative clauses: "that" after a comma conflicts; "whom" is on no line', () => {
    expect(codes(card('relativeClauses', sw, ['The man who called is here.']))).toEqual([]);
    expect(card('relativeClauses', sw, ['My car, that I bought last year, is fast.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(card('relativeClauses', sw, ['The man to whom I spoke left.'])?.[0]).toMatchObject({ code: 'card_silent' });
    expect(card('relativeClauses', sw, ['The man standing there is my uncle.'])?.[0]).toMatchObject({ code: 'card_silent' });
  });

  it('comparatives: more with -er, a superlative without "the", and forms the card lacks', () => {
    expect(codes(card('comparativesSuperlatives', sw, ['She is taller than her brother and the best in her class.']))).toEqual([]);
    expect(codes(card('comparativesSuperlatives', sw, ['It is one of the two biggest cities and my oldest friend lives there.']))).toEqual([]);
    expect(card('comparativesSuperlatives', sw, ['This is more easier than that.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(card('comparativesSuperlatives', sw, ['She runs fastest in the mornings.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(card('comparativesSuperlatives', sw, ['He is as tall as his father.'])?.[0]).toMatchObject({ code: 'card_silent' });
    expect(codes(card('comparativesSuperlatives', sw, ['The forest is other than I remember, and more modest.']))).toEqual([]);
  });

  it('the control: a / an by sound', () => {
    expect(codes(card(CONTROL_TOPIC_ID, sw, ['She is an honest person at a university an hour away.']))).toEqual([]);
    expect(card(CONTROL_TOPIC_ID, sw, ['He ate a apple.'])?.[0]).toMatchObject({ code: 'card_conflict' });
    expect(card(CONTROL_TOPIC_ID, sw, ['It is an useful tool.'])?.[0]).toMatchObject({ code: 'card_conflict' });
  });

  it('a fill_in_blank key is read as the completed sentence; without a key it does not run', () => {
    const m = made('relativeClauses', { type: 'fill_in_blank', instruction: 'My car, ____ I bought last year, is fast.' }, ['that']);
    expect(keySentence(m.item, m.answers.key as NonNullable<ItemAnswers['key']>)).toBe('My car, that I bought last year, is fast.');
    expect(codes(checkHintCard(m.item, m.answers))).toEqual(['card_conflict']);
    expect(checkHintCard(m.item, {})).toBeNull();
  });
});

describe('topics checks: recorded per item', () => {
  const content = {
    items: [
      { id: 'a', type: 'sentence_writing', context: 'You are giving advice to a friend.', instruction: 'Using "if", write one sentence.' },
      { id: 'b', type: 'sentence_writing', context: 'You are talking about your weekend.', instruction: 'Write one sentence about your plans.' },
      { id: 'c', type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic.', instruction: FIX },
      { id: 'd', type: 'error_correction', context: 'If it will rain tomorrow, we will cancel the picnic.', instruction: FIX },
      { id: 'e', type: 'fill_in_blank', instruction: 'If I ____ you, I would apologise.' },
    ],
  };
  const gate = gateSet('conditionals', 1, content);
  const written = {
    answers: [
      { itemId: 'conditionals.1.0', key: ['If I were you, I would rest.'], variant: [], mistakes: [{ answer: ['If I would be you, I would rest.'], breaks: 'would in the if-part' }] },
      { itemId: 'conditionals.1.2', key: ['If it rains tomorrow, we will cancel the picnic.'], variant: [], mistakes: [] },
      { itemId: 'conditionals.1.4', key: ['were'], variant: ['was'], mistakes: [] },
    ],
  };
  const records = checkItems(gate.items, builtAnswersFrom(gate.items, written).answers);

  it('one record per item, with every flag and what could not run', () => {
    expect(records.map((r) => r.itemId)).toEqual(gate.items.map((i) => i.id));
    expect(records[0]).toMatchObject({ topicId: 'conditionals', set: 1, index: 0, type: 'sentence_writing', gate: [], flags: [], notRun: [] });
    // No key: the topic check has nothing to go on, the card check cannot run.
    expect(records[1]?.notRun).toEqual(['topic', 'hint_card']);
    expect(records[2]?.flags.map((f) => f.code)).toEqual(['duplicate_in_set']);
    expect(records[3]?.flags.map((f) => f.code)).toEqual(['duplicate_in_set']);
    expect(records[3]?.notRun).toEqual(['hint_card']);
    expect(records[4]?.flags.map((f) => f.code)).toEqual(['second_answer_listed', 'several_answers_fit']);
    for (const r of records) for (const f of r.flags) expect(CHECK_IDS).toContain(f.check);
  });

  it('the summary counts flagged items per check and topic', () => {
    const summary = summarizeChecks(records);
    expect(summary).toHaveLength(1);
    expect(summary[0]).toMatchObject({ topicId: 'conditionals', items: 5, gateFailed: 0 });
    expect(summary[0]?.flagged).toEqual({ topic: 0, single_answer: 1, duplicate: 2, length_level: 0, hint_card: 0 });
    expect(summary[0]?.notRun).toEqual({ topic: 1, single_answer: 0, duplicate: 0, length_level: 0, hint_card: 2 });
    expect(renderCheckSummary(summary)).toContain('| conditionals | 5 | 0 | 0 (1 not run) | 1 | 2 | 0 | 0 (2 not run) |');
  });
});
