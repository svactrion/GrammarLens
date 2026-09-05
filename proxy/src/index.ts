import { requireAppToken } from './auth';
import { callAnthropic } from './anthropic';
import { reserveQuota } from './quota';
import { ProxyError, type Env } from './types';
import {
  validateGenerateDailyTest,
  validateGeneratePracticeSet,
  validateScoreAnswers,
} from './validation';

/** Hard cap on request body size, checked before JSON parsing — cheap
 * defense against an oversized payload regardless of what's inside it. */
const MAX_BODY_BYTES = 20_000;

async function readJsonBody(request: Request): Promise<unknown> {
  const contentLength = request.headers.get('content-length');
  if (contentLength && Number.parseInt(contentLength, 10) > MAX_BODY_BYTES) {
    throw new ProxyError('invalid_request', 400, 'Request body too large.');
  }
  const text = await request.text();
  if (text.length > MAX_BODY_BYTES) {
    throw new ProxyError('invalid_request', 400, 'Request body too large.');
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new ProxyError('invalid_request', 400, 'Request body must be valid JSON.');
  }
}

async function handleOperation(
  request: Request,
  env: Env,
  op: 'generate_practice_set' | 'generate_daily_test' | 'score_answers',
): Promise<Response> {
  requireAppToken(request, env.APP_TOKEN);

  const body = await readJsonBody(request);

  let deviceId: string;
  let result: unknown;
  switch (op) {
    case 'generate_practice_set': {
      const req = validateGeneratePracticeSet(body);
      deviceId = req.deviceId;
      await reserveQuota(env, deviceId);
      result = await callAnthropic(env, { op, request: req });
      break;
    }
    case 'generate_daily_test': {
      const req = validateGenerateDailyTest(body);
      deviceId = req.deviceId;
      await reserveQuota(env, deviceId);
      result = await callAnthropic(env, { op, request: req });
      break;
    }
    case 'score_answers': {
      const req = validateScoreAnswers(body);
      deviceId = req.deviceId;
      await reserveQuota(env, deviceId);
      result = await callAnthropic(env, { op, request: req });
      break;
    }
  }

  return Response.json(result);
}

const ROUTES: Record<string, 'generate_practice_set' | 'generate_daily_test' | 'score_answers'> = {
  '/v1/generate-practice-set': 'generate_practice_set',
  '/v1/generate-daily-test': 'generate_daily_test',
  '/v1/score-answers': 'score_answers',
};

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response('ok', { status: 200 });
    }

    if (request.method !== 'POST') {
      return new Response('Not found', { status: 404 });
    }

    const op = ROUTES[url.pathname];
    if (!op) {
      return new Response('Not found', { status: 404 });
    }

    try {
      return await handleOperation(request, env, op);
    } catch (e) {
      if (e instanceof ProxyError) return e.toResponse();
      console.error('Unhandled error', e);
      return new ProxyError('internal_error', 500, 'Something went wrong.').toResponse();
    }
  },
};
