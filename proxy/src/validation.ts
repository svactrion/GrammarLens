import { isKnownTopicId } from './topics';
import { ProxyError } from './types';

const MAX_DEVICE_ID_LENGTH = 128;
const MAX_ITEMS = 20;
const MAX_TEXT_LENGTH = 2000;
const MAX_ID_LENGTH = 100;

function fail(detail: string): never {
  throw new ProxyError('invalid_request', 400, detail);
}

/** Rejects anything except a plain JSON object with exactly [allowedKeys]. */
function requireObjectWithOnlyKeys(
  value: unknown,
  allowedKeys: readonly string[],
): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    fail('Request body must be a JSON object.');
  }
  const obj = value as Record<string, unknown>;
  const allowed = new Set(allowedKeys);
  for (const key of Object.keys(obj)) {
    if (!allowed.has(key)) fail(`Unexpected field: "${key}".`);
  }
  return obj;
}

function requireDeviceId(obj: Record<string, unknown>): string {
  const v = obj.deviceId;
  if (typeof v !== 'string' || v.length === 0 || v.length > MAX_DEVICE_ID_LENGTH) {
    fail('"deviceId" must be a non-empty string.');
  }
  return v;
}

function requireCount(obj: Record<string, unknown>, max = 10): number {
  const v = obj.count;
  if (typeof v !== 'number' || !Number.isInteger(v) || v < 1 || v > max) {
    fail(`"count" must be an integer between 1 and ${max}.`);
  }
  return v;
}

function requireTopicId(value: unknown, field: string): string {
  if (!isKnownTopicId(value)) fail(`"${field}" is not a recognized topic id.`);
  return value;
}

export interface GeneratePracticeSetRequest {
  deviceId: string;
  topicId: string;
  count: number;
}

export function validateGeneratePracticeSet(body: unknown): GeneratePracticeSetRequest {
  const obj = requireObjectWithOnlyKeys(body, ['deviceId', 'topicId', 'count']);
  return {
    deviceId: requireDeviceId(obj),
    topicId: requireTopicId(obj.topicId, 'topicId'),
    count: requireCount(obj),
  };
}

export interface WeakSpotInput {
  topicId: string;
  frequency: number;
}

export interface GenerateDailyTestRequest {
  deviceId: string;
  count: number;
  weakSpots: WeakSpotInput[];
}

export function validateGenerateDailyTest(body: unknown): GenerateDailyTestRequest {
  const obj = requireObjectWithOnlyKeys(body, ['deviceId', 'count', 'weakSpots']);
  const deviceId = requireDeviceId(obj);
  const count = requireCount(obj);

  const rawWeakSpots = obj.weakSpots;
  if (!Array.isArray(rawWeakSpots) || rawWeakSpots.length > MAX_ITEMS) {
    fail(`"weakSpots" must be an array of at most ${MAX_ITEMS} items.`);
  }
  const weakSpots = rawWeakSpots.map((entry, index) => {
    const spot = requireObjectWithOnlyKeys(entry, ['topicId', 'frequency']);
    const topicId = requireTopicId(spot.topicId, `weakSpots[${index}].topicId`);
    const frequency = spot.frequency;
    if (typeof frequency !== 'number' || !Number.isInteger(frequency) || frequency < 0 || frequency > 100000) {
      fail(`"weakSpots[${index}].frequency" must be a non-negative integer.`);
    }
    return { topicId, frequency };
  });

  return { deviceId, count, weakSpots };
}

const KNOWN_ITEM_TYPES = new Set(['fill_in_blank', 'error_correction', 'sentence_writing']);

export interface ScoreItemInput {
  id: string;
  type: string;
  prompt: string;
  userAnswer: string;
}

export interface ScoreAnswersRequest {
  deviceId: string;
  items: ScoreItemInput[];
}

function requireBoundedString(value: unknown, field: string, maxLength: number, allowEmpty: boolean): string {
  if (typeof value !== 'string' || value.length > maxLength || (!allowEmpty && value.length === 0)) {
    fail(`"${field}" must be a string of at most ${maxLength} characters${allowEmpty ? '' : ', non-empty'}.`);
  }
  return value;
}

export function validateScoreAnswers(body: unknown): ScoreAnswersRequest {
  const obj = requireObjectWithOnlyKeys(body, ['deviceId', 'items']);
  const deviceId = requireDeviceId(obj);

  const rawItems = obj.items;
  if (!Array.isArray(rawItems) || rawItems.length === 0 || rawItems.length > MAX_ITEMS) {
    fail(`"items" must be a non-empty array of at most ${MAX_ITEMS} items.`);
  }
  const items = rawItems.map((entry, index) => {
    const item = requireObjectWithOnlyKeys(entry, ['id', 'type', 'prompt', 'userAnswer']);
    const type = item.type;
    if (typeof type !== 'string' || !KNOWN_ITEM_TYPES.has(type)) {
      fail(`"items[${index}].type" is not a recognized item type.`);
    }
    return {
      id: requireBoundedString(item.id, `items[${index}].id`, MAX_ID_LENGTH, false),
      type,
      prompt: requireBoundedString(item.prompt, `items[${index}].prompt`, MAX_TEXT_LENGTH, false),
      // Empty is valid here — an unanswered (skipped) question.
      userAnswer: requireBoundedString(item.userAnswer, `items[${index}].userAnswer`, MAX_TEXT_LENGTH, true),
    };
  });

  return { deviceId, items };
}
