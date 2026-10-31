import { describe, expect, it } from 'vitest';
import * as prompts from '../src/prompts';
import anthropicSource from '../src/anthropic.ts?raw';

/**
 * The owner's design constraint (2026-10-31): every system prompt lives in
 * `src/prompts.ts`, apart from the request builders, so a prompt change never
 * touches a builder and the measurement harness can treat prompts as data.
 */
describe('prompts module', () => {
  it('exports the five system prompts, each a non-empty trimmed string', () => {
    const names = [
      'GENERATION_SYSTEM_PROMPT',
      'DAILY_TEST_SYSTEM_PROMPT',
      'SHARED_DAILY_TEST_SYSTEM_PROMPT_V2',
      'SCORING_SYSTEM_PROMPT',
      'SHARED_CHECK_SYSTEM_PROMPT',
    ] as const;
    for (const name of names) {
      const value = prompts[name];
      expect(typeof value).toBe('string');
      expect(value).toBe(value.trim());
      expect(value.length).toBeGreaterThan(200);
    }
  });

  it('assumes no Turkish learner or keyboard anywhere but the legacy prompt (1.4.0 D3)', () => {
    expect(prompts.GENERATION_SYSTEM_PROMPT).not.toContain('Turkish');
    expect(prompts.SHARED_DAILY_TEST_SYSTEM_PROMPT_V3).not.toContain('Turkish');
    expect(prompts.SCORING_SYSTEM_PROMPT).not.toContain('Turkish');
    expect(prompts.SHARED_CHECK_SYSTEM_PROMPT).not.toContain('Turkish');
    // Left as they were: the legacy 1.0.0 prompt (owner, 2026-10-31) and
    // version 2, kept buildable for the v2/v3 comparison.
    expect(prompts.DAILY_TEST_SYSTEM_PROMPT).toContain('Turkish');
    expect(prompts.SHARED_DAILY_TEST_SYSTEM_PROMPT_V2).toContain('Turkish');
  });

  it('leaves no prompt text in the request builders', () => {
    expect(anthropicSource).not.toContain('You are an IELTS grammar coach');
    expect(anthropicSource).not.toContain('You review English grammar exercises');
  });
});
