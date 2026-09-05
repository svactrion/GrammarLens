import { describe, expect, it } from 'vitest';
import { requireAppToken } from '../src/auth';
import { ProxyError } from '../src/types';

function req(headers: Record<string, string> = {}): Request {
  return new Request('https://example.com/v1/generate-practice-set', { headers });
}

describe('requireAppToken', () => {
  it('passes silently when the header matches the expected token', () => {
    expect(() => requireAppToken(req({ 'x-grammarlens-token': 'secret' }), 'secret')).not.toThrow();
  });

  it('throws unauthorized when the header is missing', () => {
    expect(() => requireAppToken(req(), 'secret')).toThrowError(ProxyError);
    try {
      requireAppToken(req(), 'secret');
      expect.fail('should have thrown');
    } catch (e) {
      expect(e).toBeInstanceOf(ProxyError);
      expect((e as ProxyError).code).toBe('unauthorized');
      expect((e as ProxyError).status).toBe(401);
    }
  });

  it('throws unauthorized when the header value is wrong', () => {
    expect(() => requireAppToken(req({ 'x-grammarlens-token': 'wrong' }), 'secret')).toThrow(ProxyError);
  });

  it('throws unauthorized for a value of a different length than expected (not just wrong content)', () => {
    expect(() => requireAppToken(req({ 'x-grammarlens-token': 'sec' }), 'secret')).toThrow(ProxyError);
    expect(() =>
      requireAppToken(req({ 'x-grammarlens-token': 'secretsecretsecret' }), 'secret'),
    ).toThrow(ProxyError);
  });
});
