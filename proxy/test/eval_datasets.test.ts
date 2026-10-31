import { describe, expect, it } from 'vitest';
import {
  CONTRACTIONS,
  KEYBOARD_CLASSES,
  KEYBOARD_VARIANTS,
  KEYBOARD_VARIANTS_PER_QUESTION,
  MULTI_BLANK_ITEMS,
  POOL_DATES,
  assembleBlanks,
  buildLiveSheet,
  buildPoolGate,
  buildPoolScoring,
  buildSynth,
  contractionVariant,
  keyFactory,
  keyboardVariants,
  multiBlankAnswers,
  nearMiss,
  renderSynthReview,
  selectLiveSets,
  spellingVariant,
  type LiveSetFile,
} from '../eval/lib/datasets';
import { parseCsv, seededRandom } from '../eval/lib/labels';
import type { SharedQuestion } from '../src/shared_daily_test';

function question(overrides: Partial<SharedQuestion> = {}): SharedQuestion {
  return {
    id: 'fb01_1',
    type: 'fill_in_blank',
    context: 'I can\'t afford ____ all my vegetables here.',
    instruction: 'Fill in the blank with the correct form of the verb (buy).',
    topicId: 'gerundVsInfinitive',
    correctAnswer: 'to buy',
    explanation: "'Afford' takes a to-infinitive.",
    commonWrongAnswers: [
      { answer: 'buying', comment: 'c1' },
      { answer: 'buy', comment: 'c2' },
    ],
    ...overrides,
  };
}

const pool = {
  sets: [
    { questions: [question(), question({ id: 'fb01_2', correctAnswer: 'am cooking', acceptedAnswers: ["'m cooking"] })] },
    {
      questions: [
        question({
          id: 'fb02_1',
          type: 'error_correction',
          context: 'He can make a cake.',
          instruction: 'Rewrite the sentence.',
          correctAnswer: 'He could make a cake.',
          commonWrongAnswers: [{ answer: 'He can make a cake', comment: 'unchanged' }],
        }),
      ],
    },
  ],
};

describe('assembleBlanks (the app\'s rule, ported for the synthetic set)', () => {
  it('puts each box into its blank and keeps an empty box\'s blank', () => {
    expect(assembleBlanks('I enjoy ____ (swim), but ____ (learn) tennis.', [{ text: 'swimming' }, { text: '' }])).toBe(
      'I enjoy swimming (swim), but ____ (learn) tennis.',
    );
  });
  it('removes a no-article blank with its space and capitalises a sentence start', () => {
    expect(assembleBlanks('____ honesty matters, so she gave me ____ honest answer.', [{ text: '', noArticle: true }, { text: 'an' }])).toBe(
      'Honesty matters, so she gave me an honest answer.',
    );
    expect(assembleBlanks('We had ____ lunch at ____ café.', [{ text: '', noArticle: true }, { text: 'a' }])).toBe('We had lunch at a café.');
  });
  it('is empty when every box is empty (a skipped question)', () => {
    expect(assembleBlanks('a ____ b ____', [{ text: '' }, { text: ' ' }])).toBe('');
  });
});

describe('keyboard variants', () => {
  it('has one transform per class of the folding table, each changing the text or declining', () => {
    expect(KEYBOARD_CLASSES).toEqual(['fullwidth', 'acute', 'umlaut', 'turkish', 'smart_apostrophe', 'nbsp', 'arabic_digits', 'zero_width']);
    expect(KEYBOARD_VARIANTS.fullwidth.apply('to buy')).toBe('ｔｏ　ｂｕｙ');
    expect(KEYBOARD_VARIANTS.turkish.apply('cooking')).toBe('cookıng');
    expect(KEYBOARD_VARIANTS.acute.apply('xyz')).toBeNull();
    expect(KEYBOARD_VARIANTS.arabic_digits.apply('since 2018')).toBe('since ٢٠١٨');
    expect(KEYBOARD_VARIANTS.smart_apostrophe.apply('am cooking')).toBeNull();
    expect(KEYBOARD_VARIANTS.smart_apostrophe.apply("isn't")).toBe('isn’t');
  });
  it(`gives at most ${KEYBOARD_VARIANTS_PER_QUESTION} per answer, rotating so every class is used`, () => {
    const seen = new Set<string>();
    for (let n = 0; n < 8; n++) {
      const v = keyboardVariants("since 2018 we haven't", n);
      expect(v.length).toBe(KEYBOARD_VARIANTS_PER_QUESTION);
      for (const x of v) seen.add(x.cls);
    }
    expect(seen.size).toBe(KEYBOARD_CLASSES.length);
  });
});

describe('contractions, spellings, near-misses', () => {
  it('contracts and expands unambiguous pairs, never \'s or \'d', () => {
    expect(contractionVariant('I am tired')).toBe("I'm tired");
    expect(contractionVariant("She isn't here")).toBe('She is not here');
    expect(contractionVariant('am cooking')).toBe("'m cooking");
    expect(contractionVariant("'re cleaning")).toBe('are cleaning');
    expect(contractionVariant("He's gone")).toBeNull();
    expect(CONTRACTIONS.some(([, s]) => s.endsWith("'s") || s.endsWith("'d"))).toBe(false);
  });
  it('swaps a British and an American spelling', () => {
    expect(spellingVariant('this neighbourhood')).toBe('this neighborhood');
    expect(spellingVariant('my favorite')).toBe('my favourite');
    expect(spellingVariant('must')).toBeNull();
  });
  it('writes one real mistake near the key by a fixed rule', () => {
    expect(nearMiss({ type: 'fill_in_blank', correctAnswer: 'to buy' })).toEqual({ rule: 'to_plus_ing', typed: 'to buying' });
    expect(nearMiss({ type: 'fill_in_blank', correctAnswer: 'swimming' })).toEqual({ rule: 'ing_to_base', typed: 'swimm' });
    expect(nearMiss({ type: 'fill_in_blank', correctAnswer: 'must' })).toEqual({ rule: 'add_s', typed: 'musts' });
    expect(nearMiss({ type: 'fill_in_blank', correctAnswer: 'have to' })).toEqual({ rule: 'drop_last_word', typed: 'have' });
    expect(nearMiss({ type: 'error_correction', context: 'He can make a cake.', correctAnswer: 'He could make a cake.' })).toEqual({
      rule: 'original_sentence',
      typed: 'He can make a cake.',
    });
  });
});

describe('S-pool', () => {
  it('turns every key, accepted answer and predicted wrong answer into a labelled answer', () => {
    const answers = buildPoolScoring(pool);
    expect(answers.map((a) => [a.id, a.truth])).toEqual([
      ['pool:fb01_1:key', true],
      ['pool:fb01_1:wrong:1', false],
      ['pool:fb01_1:wrong:2', false],
      ['pool:fb01_2:key', true],
      ['pool:fb01_2:accepted:1', true],
      ['pool:fb01_2:wrong:1', false],
      ['pool:fb01_2:wrong:2', false],
      ['pool:fb02_1:key', true],
      ['pool:fb02_1:wrong:1', false],
    ]);
    expect(answers[0]?.item).toEqual({
      id: 'fb01_1',
      type: 'fill_in_blank',
      prompt: 'I can\'t afford ____ all my vegetables here.\nFill in the blank with the correct form of the verb (buy).',
    });
    expect(answers[4]?.userAnswer).toBe("'m cooking");
  });

  it('maps each correction to the live question by date and number, and fails on a missing one', () => {
    const live: LiveSetFile[] = [{ date: '2026-09-30', promptVersion: 2, questions: [question({ id: 'live-a' }), question({ id: 'live-b' })] }];
    expect(buildPoolGate(live, [{ date: '2026-09-30', question: 2, addAcceptedAnswers: ['x'], removeWrongAnswers: ['y'], removeHint: true }])).toEqual([
      { date: '2026-09-30', questionId: 'live-b', acceptAlso: ['x'], movedFromWrong: ['y'], hintRemoved: true },
    ]);
    expect(() => buildPoolGate(live, [{ date: '2026-10-01', question: 1 }])).toThrow(/no such live question/);
  });
});

describe('S-live', () => {
  const live: LiveSetFile[] = [
    { date: '2026-09-28', promptVersion: 1, questions: [question({ id: 'v1' })] },
    { date: '2026-10-07', promptVersion: 2, questions: [question({ id: 'a' }), question({ id: 'b' })] },
    { date: POOL_DATES[0], promptVersion: 2, questions: [question({ id: 'pool' })] },
    { date: '2026-09-29', promptVersion: 2, questions: [question({ id: 'c' })] },
  ];
  it('keeps the prompt-v2 sets the owner has not reviewed, in date order', () => {
    expect(selectLiveSets(live).map((s) => s.date)).toEqual(['2026-09-29', '2026-10-07']);
  });
  it('writes a deterministic blind sheet whose keys never read as numbers', () => {
    const a = buildLiveSheet(selectLiveSets(live));
    const b = buildLiveSheet(selectLiveSets(live));
    expect(a.csv).toBe(b.csv);
    expect(a.rows).toBe(3);
    const rows = parseCsv(a.csv);
    expect(rows).toHaveLength(3);
    for (const row of rows) {
      expect(row.key).toMatch(/^k[0-9a-f]{7}$/);
      expect(row.label).toBe('');
      expect(a.mapping[row.key as string]).toMatchObject({ source: 'S-live' });
    }
    const k = keyFactory(seededRandom(1));
    expect(k()).toMatch(/^k[0-9a-f]{7}$/);
  });
});

describe('S-synth', () => {
  const synth = buildSynth(pool);
  it('writes keyboard variants, a contraction where the key allows one, and a near-miss per question', () => {
    const kinds = (id: string) => synth.filter((a) => a.item.id === id).map((a) => a.kind);
    expect(kinds('fb01_1').filter((k) => k.startsWith('kb:'))).toHaveLength(3);
    expect(kinds('fb01_1')).toContain('nearmiss:to_plus_ing');
    expect(kinds('fb01_2')).toContain('contraction');
    expect(kinds('fb02_1')).toContain('nearmiss:original_sentence');
    expect(synth.every((a) => (a.kind.startsWith('nearmiss') ? !a.truth : a.truth || a.blanks !== undefined))).toBe(true);
  });
  it('has unique ids and a review note on every answer', () => {
    expect(new Set(synth.map((a) => a.id)).size).toBe(synth.length);
    expect(synth.every((a) => typeof a.review === 'string' && a.review.length > 0)).toBe(true);
  });
  it('covers each multi-blank item with four cases whose verdict follows the per-blank truth', () => {
    const cases = multiBlankAnswers();
    expect(cases).toHaveLength(MULTI_BLANK_ITEMS.length * 4);
    for (const c of cases) {
      expect(c.blanks).toBeDefined();
      expect(c.truth).toBe(c.blanks!.every((b) => b.accepted));
      expect(c.blanks!.length).toBe(MULTI_BLANK_ITEMS.find((i) => i.id === c.item.id)!.keys.length);
    }
    const empty = cases.find((c) => c.id === 'synth:debug_gerund_2:one_empty')!;
    expect(empty.userAnswer).toBe('I enjoy swimming (swim), but this year I have decided ____ (learn) tennis.');
    expect(empty.truth).toBe(false);
    const article = cases.find((c) => c.id === 'synth:debug_articles_2:all_right')!;
    expect(article.userAnswer).toBe('Honesty matters to her, so she gave me an honest answer.');
    expect(article.truth).toBe(true);
    const wrongArticle = cases.find((c) => c.id === 'synth:debug_articles_3:article_where_none')!;
    expect(wrongArticle.userAnswer).toBe('We had the lunch at a small café near the station.');
    expect(wrongArticle.blanks![0]!.accepted).toBe(false);
  });
  it('renders the review with every id and verdict', () => {
    const md = renderSynthReview(synth);
    for (const a of synth) expect(md).toContain(`\`${a.id}\` ${a.truth ? 'CORRECT' : 'WRONG'}`);
  });
});
