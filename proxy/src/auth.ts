import { ProxyError } from './types';

const HEADER = 'x-grammarlens-token';

/**
 * Constant-time string comparison — cheap to do right, even though this
 * token is known to be extractable from a shipped app binary and is
 * explicitly not the sole defense (see Env.APP_TOKEN's doc comment). Plain
 * `===` would leak a timing side-channel for no reason.
 */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return diff === 0;
}

/** Throws a ProxyError('unauthorized') unless the request carries the right token. */
export function requireAppToken(request: Request, expected: string): void {
  const provided = request.headers.get(HEADER);
  if (!provided || !timingSafeEqual(provided, expected)) {
    throw new ProxyError('unauthorized', 401, 'Missing or invalid app token.');
  }
}
