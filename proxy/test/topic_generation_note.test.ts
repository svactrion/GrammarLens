import { describe, expect, it } from 'vitest';
import { PRODUCTION_PRACTICE, buildBody, buildGeneratePracticeSetBodyFor } from '../src/anthropic';
import { GENERATION_SYSTEM_PROMPT, PRACTICE_BLANKS_RULE, PRACTICE_BLANKS_RULE_UNTIL_2026_11 } from '../src/prompts';
import { FIRST_WAVE_TOPICS, FIRST_WAVE_TOPICS_ENABLED, TOPICS, isKnownTopicId, topicById } from '../src/topics';
import { validateGeneratePracticeSet } from '../src/validation';
import dartTopics from '../../lib/data/topics.dart?raw';
import dartHints from '../../lib/data/topic_hints.dart?raw';
import englishStrings from '../../lib/l10n/app_en.arb?raw';

/**
 * The generation note (docs/TOPICS.md, phase C2; owner decision
 * 2026-11-18): one sentence the worker adds to the topic line of the
 * practice request for Conditionals, so the generator writes the three
 * types the hint card teaches and no mixed conditional. Nothing else in any
 * request changes.
 */

const NOTE = 'Use the first, second and third conditional only; no mixed conditional (a past condition with a present result, or a present condition with a past result).';

/** SHA-256 of each topic's practice request body, at 5 and at 3 questions,
 * as the builder made it on 2026-11-18 before the note existed (device id
 * "device", the production variant, the first-wave topics known): the
 * requests the first topics run measured. Since phase C3 every request also
 * differs from these by the prompt's line on blanks (and by a theme line
 * when the worker gives one; none is given here). */
const BEFORE_THE_NOTE: Readonly<Record<string, readonly [string, string]>> = {
  gerundVsInfinitive: ['d7884e7c9eebaeb815b2bc954f7c1c0b196241098c2a688f198df83c6fa55de0', '7cc7bc94beabf54d88e1d1b3f006071968fbba5d38bce1db2913f266bd48b711'],
  modalVerbs: ['181904142c3116386728ce220a9b7be07d3fd977ae5ede8e04d5ecff9c46cc43', '8d5aebc040b2f49d633749ff46b56d869eccff67e2215e38318e3082078c69eb'],
  modalPastForms: ['d2d214d9bd119871f412855675c197b24944875bfb9789f6bd0337ee267537b4', '55dd0dbfc0e8f3b3e053ea6cfe437d5aeda078dea71413b9eed069805a3c709e'],
  tenseSelection: ['731176deb709ebd49b419372597fe6ce16c09718c950ac11ca2078d39a58642d', '7af9236bc502b9b266929b8ad856ac47ec465645afe0fa975708b994a99e4253'],
  articles: ['b2ffd091aac4f1b91d55310e55679257feaa9038ef2c76f995da2fba0c5608b7', 'f2fe2c4050b5762cd389f5b70a4c524fb140dbffd3017f42ee24cfa72072286c'],
  conditionals: ['2d2120a4a7abf57cb67ef97f2a38238f591be4f80c3efe94ccf05c7be753f4da', '53116e90f0b322840fdf15d63ac9746b76d2657b8c4220d7cb56be60aa226210'],
  passiveVoice: ['252ea175388ad2cc71abcfa282760a2c1157ef1eafef09c29f1fb1a5324b2795', 'f8b73905c578d443c0840ae022254fcf7faa80857384279579439bcf4efbd908'],
  prepositions: ['22040888a64b8bc6478972465aab24603133c797fa363f407f4b9d846766b900', '6559e18d0236a39c99deba89803dedd018c4f77834cc1ac59933cb184b59e62d'],
  relativeClauses: ['844de8a9847a5a3909cf11dfb40e7ca0ecaa610a84c6918735b7108cd5070cbd', 'c4dad4001490a08e246b6fc3ba58d7b9ca4480af8295f289c3adef66af5597c3'],
  comparativesSuperlatives: ['36a27ea50340684e30f67a6a593022d1acb1eeadfbbb84312c7dd20adc3ab5ad', '410628f507aaf2d5bf97beb3262c2e7800d2ecdb4a18da15c2d9b21a46616f00'],
};

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

const body = (topicId: string, count: number) => buildGeneratePracticeSetBodyFor({ deviceId: 'device', topicId, count }, PRODUCTION_PRACTICE, true);

/** [request] with the prompt's line on blanks as it was before phase C3. */
function withEarlierBlanksLine<T extends { system: string }>(request: T): T {
  expect(request.system).toContain(PRACTICE_BLANKS_RULE);
  return { ...request, system: request.system.replace(PRACTICE_BLANKS_RULE, PRACTICE_BLANKS_RULE_UNTIL_2026_11) };
}

describe('the generation note', () => {
  it('is on Conditionals and on no other topic', () => {
    expect(topicById('conditionals', true)?.generationNote).toBe(NOTE);
    for (const topic of [...TOPICS, ...FIRST_WAVE_TOPICS]) {
      if (topic.id !== 'conditionals') expect(topic.generationNote).toBeUndefined();
    }
  });

  it('ends the topic line of the Conditionals request, and is in no other topic\'s request', () => {
    const conditionals = topicById('conditionals', true);
    expect(body('conditionals', 5).messages[0]?.content).toBe(
      `Topic: "Conditionals" — ${conditionals?.description} ${NOTE}\nGenerate exactly 5 fresh practice items: 2 sentence_writing, 2 error_correction, and 1 fill_in_blank. Each "id" must be a short unique slug.`,
    );
    for (const topic of [...TOPICS, ...FIRST_WAVE_TOPICS]) {
      if (topic.id === 'conditionals') continue;
      const text = JSON.stringify(body(topic.id, 5));
      expect(text).not.toContain('mixed conditional');
      expect(text).not.toContain(NOTE);
    }
  });

  it('the requests of the five live topics are what the first run measured, but for the line on blanks', async () => {
    expect(TOPICS.map((t) => t.id)).toEqual(['gerundVsInfinitive', 'modalVerbs', 'modalPastForms', 'tenseSelection', 'articles']);
    for (const topic of TOPICS) {
      expect([await sha256(JSON.stringify(withEarlierBlanksLine(body(topic.id, 5)))), await sha256(JSON.stringify(withEarlierBlanksLine(body(topic.id, 3))))]).toEqual(BEFORE_THE_NOTE[topic.id]);
      expect(await sha256(JSON.stringify(body(topic.id, 5)))).not.toBe(BEFORE_THE_NOTE[topic.id]?.[0]);
      // The builder's request for the switch off, with no theme, is the same body.
      expect(buildBody({ op: 'generate_practice_set', request: { deviceId: 'device', topicId: topic.id, count: 5 } })).toEqual(body(topic.id, 5));
    }
  });

  it('the requests of the other four first-wave topics are what the first run measured, but for the line on blanks', async () => {
    for (const topic of FIRST_WAVE_TOPICS) {
      if (topic.id === 'conditionals') continue;
      expect([await sha256(JSON.stringify(withEarlierBlanksLine(body(topic.id, 5)))), await sha256(JSON.stringify(withEarlierBlanksLine(body(topic.id, 3))))]).toEqual(BEFORE_THE_NOTE[topic.id]);
    }
  });

  it('the Conditionals request differs from the first run\'s by the note and the line on blanks alone', async () => {
    for (const [i, count] of [5, 3].entries()) {
      const now = withEarlierBlanksLine(body('conditionals', count));
      expect(await sha256(JSON.stringify(now))).not.toBe(BEFORE_THE_NOTE.conditionals?.[i]);
      const withoutNote = { ...now, messages: now.messages.map((m) => ({ ...m, content: m.content.replace(` ${NOTE}`, '') })) };
      expect(await sha256(JSON.stringify(withoutNote))).toBe(BEFORE_THE_NOTE.conditionals?.[i]);
    }
  });

  it('changes no prompt but the topic line: the system prompt is the production one, untouched by the note', () => {
    expect(body('conditionals', 5).system).toBe(GENERATION_SYSTEM_PROMPT);
    expect(GENERATION_SYSTEM_PROMPT).not.toContain('mixed conditional');
    expect(body('conditionals', 5).output_config).toEqual(body('articles', 5).output_config);
    const scoring = buildBody({ op: 'score_answers', request: { deviceId: 'device', items: [{ id: 'a', type: 'fill_in_blank', prompt: 'If I ____ you, I would go.', userAnswer: 'were' }] } });
    expect(JSON.stringify(scoring)).not.toContain('mixed conditional');
  });

  it('is generation-only: not in the app\'s topic data, its hint cards or its strings', () => {
    for (const source of [dartTopics, dartHints, englishStrings]) {
      expect(source).not.toContain('mixed conditional');
      expect(source).not.toContain('generationNote');
    }
    // The hint card it is written for is unchanged: three types and the if-part rule.
    expect(dartHints).toContain("'If + present, will + verb: real future',");
    expect(dartHints).toContain("'If + past, would + verb: unreal now',");
    expect(dartHints).toContain("'If + had + p.p., would have + p.p.: past',");
  });

  it('the route accepts the first-wave ids: the switch is on (phase D), and the request carries the topic line', () => {
    expect(FIRST_WAVE_TOPICS_ENABLED).toBe(true);
    for (const topic of FIRST_WAVE_TOPICS) {
      expect(isKnownTopicId(topic.id)).toBe(true);
      expect(validateGeneratePracticeSet({ deviceId: 'device', topicId: topic.id, count: 5 })).toEqual({ deviceId: 'device', topicId: topic.id, count: 5 });
      const body = buildBody({ op: 'generate_practice_set', request: { deviceId: 'device', topicId: topic.id, count: 5 } });
      expect(body.messages[0]?.content.startsWith(`Topic: "${topic.title}" — ${topic.description}`)).toBe(true);
    }
    expect(() => validateGeneratePracticeSet({ deviceId: 'device', topicId: 'notATopic', count: 5 })).toThrow('not a recognized topic id');
  });
});
