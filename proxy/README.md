# grammarlens-proxy

A Cloudflare Workers proxy that sits in front of the Anthropic API for
GrammarLens. See `docs/build-log.md` (repo root) for the full decision and
why this is operation-based rather than a forwarding proxy — in short: the
app never sends a raw Anthropic request. It sends an operation name and a
small structured payload (a topic id, a count, a list of answers); this
worker owns the model, system prompt, `max_tokens`, and response schema for
each operation, and is the only thing that ever holds the real Anthropic
API key.

## Operations

| Route | Mirrors |
| --- | --- |
| `POST /v1/generate-practice-set` | `ClaudeService.generatePracticeSet` |
| `POST /v1/generate-daily-test` | `ClaudeService.generateDailyTestQuestions` |
| `POST /v1/score-answers` | `ClaudeService.scoreAnswers` |
| `GET /v1/shared-daily-test/{date}` | the 1.1.0 client's shared Daily Test read (client side not built yet) |
| `GET /health` | liveness check, no auth |
| *(cron, hourly)* | shared Daily Test generation — see below |

Every operation route (the `POST` routes) requires an `x-grammarlens-token` header matching the
`APP_TOKEN` secret (see `src/auth.ts`), validates its body strictly (`src/
validation.ts` — unknown fields are rejected, not ignored), reserves a slot
against the per-device and global daily quota (`src/quota.ts`) before ever
calling Anthropic, and never forwards Anthropic's own error body to the
client (`src/anthropic.ts` maps everything to a generic `upstream_error`).

## Local development

1. `npm install`
2. Copy `.dev.vars.example` to `.dev.vars` and fill in a real Anthropic API
   key (`.dev.vars` is gitignored). `APP_TOKEN` can be any string locally —
   it just has to match what the Flutter app sends (see the repo root
   README's "Local setup").
3. `npm run dev` — starts `wrangler dev` on `http://localhost:8787`, with a
   local (not production) KV namespace, so quota counters here never touch
   the real deployed ones.
4. Smoke-test without spending a real Anthropic call:
   ```
   curl http://localhost:8787/health
   ```

## Testing

`npm test` runs the suite (`@cloudflare/vitest-pool-workers` — real Workers
runtime via Miniflare, not a Node approximation): auth, per-operation
validation, quota (device + global caps, UTC-day reset), and the full fetch
handler with the outbound call to Anthropic mocked (never a real network
call). `npm run typecheck` runs `tsc --noEmit` on its own — Vitest's esbuild
transform doesn't typecheck.

## Deploying

1. One-time secrets (per environment, never committed):
   ```
   wrangler secret put ANTHROPIC_API_KEY
   wrangler secret put APP_TOKEN
   ```
2. `npm run deploy` (`scripts/check-placeholders.mjs`, then `wrangler deploy`).
   The check refuses to deploy while `wrangler.jsonc` still has a
   `REPLACE_WITH_…` placeholder (the `DAILY_SETS_KV` id until the namespace is
   created). A bare `npx wrangler deploy` skips it.
3. `wrangler tail` to watch logs live — the only place upstream error
   detail and validation-rejection reasons are visible (never sent to the
   client).

## Token usage log

Every successful Anthropic call writes one JSON line with `console.log`
(`src/usage_log.ts`), which Workers Logs collects (`observability` is enabled
in `wrangler.jsonc`) and `wrangler tail` shows live:

```json
{"event":"anthropic_usage","kind":"topic_practice","operation":"score_answers","item_count":5,"input_tokens":1100,"output_tokens":400,"stop_reason":"end_turn","duration_ms":6200}
```

- `kind` is `daily_test` or `topic_practice`; a practice session is two lines
  (`generate_practice_set` + `score_answers`), so per-session cost is the sum of
  the two averages. `generate_daily_test` (1.0.0's per-device set) and
  `generate_shared_daily_test` (1.1.0's one set per date, made by the hourly
  cron) are both `daily_test`. `item_count` is the number of questions
  the call covered.
- `stop_reason` is why generation stopped, one of Anthropic's documented values
  (`end_turn`, `max_tokens`, `stop_sequence`, `tool_use`, `pause_turn`,
  `refusal`, `model_context_window_exceeded`), `unknown` for anything else, or
  `null` when absent. `max_tokens` means a truncated response.
- Token counts come from the `usage` object Anthropic returns; a missing or
  non-numeric value is logged as `null`. Logged even if the content later
  fails to parse, because the call was still billed.
- `duration_ms` is the wall time of the call to Anthropic, from just before
  the request until its body was read (not validation or the quota check); in
  Workers the clock advances across I/O, which is what is being measured. It
  is what tells you how long a Daily Test really takes to generate (compare it
  with `output_tokens`: generation time is mostly output-token bound). It is
  also on the failure line below, so a hang or a slow timeout shows up next to
  the successes.
- **Nothing user-related is ever logged by this line** — no device id, prompt,
  question, answer or generated text. The line is built field by
  field, and `test/usage_log.test.ts` checks every console channel for
  planted secrets. Do not add fields without keeping that true.
- Measuring: filter Workers Logs on `event = anthropic_usage`, average
  `input_tokens`/`output_tokens` per `operation`, multiply by the model's
  per-token prices. Workers Logs keeps data for a short, plan-dependent window
  (check the current Cloudflare limits), so export what matters.

### Failure log

A failed Anthropic call writes one `console.error` JSON line (`src/error_log.ts`):

```json
{"event":"anthropic_failure","kind":"topic_practice","operation":"score_answers","failure":"http_error","http_status":429,"upstream_error_type":"rate_limit_error","duration_ms":31000}
```

`failure` is one of `network_error`, `timeout` (the caller's abort signal
fired; only the shared-set cron sets one), `http_error`, `unreadable_body`,
`no_text_block`, `invalid_json_content`. `upstream_error_type` is Anthropic's
error `type` only if it is one of its documented values, otherwise `unknown`.
The upstream response body and exception messages are never logged, since
both can contain request or response text; `test/error_log.test.ts` plants
secrets in each place and checks all console output. The catch-all in
`src/index.ts` logs an unexpected error the same way, as
`{"event":"unhandled_error","kind":...,"operation":...,"error":"TypeError"}`:
only a category (a built-in error name, `other_error` or `non_error`), never
the message or stack. Every `console` call in `src/` now writes one of these
fixed-field lines: `anthropic_usage`, `anthropic_failure`, `unhandled_error`,
`legacy_daily_test_filter` (below), and the shared-set cron's
`shared_set_generation` and `shared_set_cron` (below).

Deployed.

### Legacy Daily Test response check

`POST /v1/generate-daily-test` (1.0.0) drops `error_correction` questions that
have no sentence to correct from the response (`src/legacy_daily_test.ts`;
`docs/1.1.0-shared-daily-test-quality.md` §14.4, option L3). The rule is the
shared set gate's (`hasSentenceToCorrect`: a `context` of at least 3 words
with a letter). Every other question is served exactly as the model wrote it.
If something was dropped and fewer than 3 questions remain, the route answers
the existing `502 upstream_error` ("The upstream service returned an
unexpected response."), which 1.0.0 shows as "Couldn't load today's test"
with "Try again". The request to Anthropic, the quota unit and the cost are
unchanged. One line per response with a `questions` array:

```json
{"event":"legacy_daily_test_filter","operation":"generate_daily_test","received_count":5,"removed_count":1,"served_count":4,"outcome":"served"}
```

`outcome` is `served` or `rejected` (`served_count` 0). Counts only, no
content; `test/legacy_daily_test.test.ts` plants secrets and checks all
console output. Legacy rate of sentenceless questions = sum of
`removed_count` / sum of `received_count`.

Deployed 2026-09-29 (D-L, version `45cf4ef3-5a8b-43e7-a351-22bc4f504140`).

`DEVICE_DAILY_LIMIT`/`GLOBAL_DAILY_LIMIT` (plain vars in `wrangler.jsonc`,
not secret) are conservative placeholder defaults, not measured numbers —
same status as `StorageService.dailySessionLimit` on the client side (see
`docs/prd-v2.md` §7.2). Adjust and redeploy as real usage data comes in.

## Shared Daily Test generation (cron)

For 1.1.0 (`docs/1.1.0-shared-daily-test.md`): one Daily Test set per calendar
date, generated here once for every 1.1.0+ client. The generation (P2) and
the read route (P3, below) were first deployed on 2026-09-26; no app build
calls the read route yet.
The 1.0.0 route `POST /v1/generate-daily-test` sends the same request, and
`test/index.test.ts` pins it byte for byte; only its response is checked
(above).

- **Trigger:** `triggers.crons` in `wrangler.jsonc`, `7 * * * *` (hourly, UTC),
  handled by `scheduled` in `src/index.ts` → `runSharedGeneration`
  (`src/shared_generation.ts`).
- **What a run does:** checks UTC today … UTC today + 3, nearest first, and
  makes **at most one** Anthropic call, for the first date with no set, no
  attempt in progress and attempts left. A run where every date already has a
  set only reads KV (4 reads) and makes no outbound request.
- **Cost bounds:** at most one generation per run; at most 3 attempts per date
  (`attempts:{date}`), counted before the call. No quota is reserved: no device
  is involved.
- **Write-once:** `set:{date}` is written only if still absent right before the
  write, and never overwritten. An attempt holds its date for 3 minutes (a
  lease in its attempt record), so a run that overlaps one waiting on Anthropic
  skips that date. KV has no compare-and-swap: two runs that both read the date
  as free within the same few milliseconds could still both generate.
- **Storage:** KV namespace `DAILY_SETS_KV`. `set:{date}` →
  `{date, promptVersion, generatedAt, attempt, questions}`, kept 35 days;
  `attempts:{date}` → `{count, leaseUntil}`, kept 7 days.
- **Quality gate:** `validateSharedSet` (`src/shared_daily_test.ts`). A rejected
  set is not written; the next hourly run retries within the cap. Among its
  rules: an `error_correction` answer may change only one contiguous span of
  the flawed sentence, at most 4 words on each side
  (`error_correction_multi_edit`, 2026-09-27).
- **Prompt versions:** 2 (its own system prompt with correctness rules,
  `docs/1.1.0-shared-daily-test-quality.md` §1.2) is what the cron sends and
  stores as `promptVersion`, since 2026-09-29 (path A, report §16), without a
  check call. 1 (the legacy Daily Test system prompt plus the day's plan) is
  what every set published before that was generated with. Each version is
  pinned by a request fingerprint test, and the cron's own request by another
  (`test/shared_generation.test.ts`).
- **Generator:** `SHARED_GENERATOR` in `src/shared_daily_test.ts`, one line:
  a model and optionally an `effort` (`{ model: 'claude-sonnet-5-5', effort:
  'low' }` since 2026-09-29, the owner's choice after the comparison).
  How each model is asked is in `GENERATOR_MODELS` next to it:
  `claude-sonnet-4-6` without thinking, `claude-sonnet-5` and
  `claude-sonnet-5-5` with adaptive thinking and `THINKING_HEADROOM_TOKENS`
  more. An `effort` is sent (in `output_config`) only when set.
- **Generation variants** (for the local measurements): the shared request
  also takes any of those models, an effort, and 1 or 2 candidates per plan
  slot (`validateSharedCandidates` drops a candidate that breaks a content rule
  and rejects only when a slot has none left). The cron uses the defaults. The
  legacy route's model is its own constant and does not follow these options.
- **Check call — built, not wired** (P6, 2026-09-27): operation
  `check_shared_daily_test` (`src/shared_check.ts`, request in `anthropic.ts`):
  an adversarial review of a generated set with adaptive thinking
  (`claude-sonnet-5` by default; `claude-sonnet-4-6` and `claude-opus-5-5` are
  also buildable), whose structured review the proxy turns into publish or
  reject by a fixed table (`decideQuestion`, `decideCheckedSet`,
  `selectCandidates` for over-generated sets). Up to 2 alternatives become a
  question's `acceptedAnswers`. Filed as `daily_test` cost. `CHECK_VERSION` 1,
  pinned by a request fingerprint. Nothing calls it yet: the two-phase cron is
  P7, after 1.1.0 (path A, 2026-09-29).
- **Timeout:** 150 s on the Anthropic call (`GENERATION_TIMEOUT_MS`, 90 s
  before 2026-09-29; a thinking model's 15,072-token budget takes ≈ 155 s,
  report §15.2), logged as `failure: "timeout"`.
- **Kill switch:** var `SHARED_DAILY_TEST_ENABLED`. Only `"true"` turns it on;
  anything else and the run touches neither KV nor Anthropic, and logs only
  `{"event":"shared_set_cron","enabled":false}`. The tests set it themselves
  (`vitest.config.ts` for the Worker routes, explicitly in the direct calls),
  so `"false"` in `wrangler.jsonc` turns no test red; a test only checks that
  the value there is `"true"` or `"false"`.

Each paid attempt writes one line (besides the usual `anthropic_usage`, and
`anthropic_failure` when it failed):

```json
{"event":"shared_set_generation","date":"2026-10-08","attempt":1,"outcome":"published","reason":null,"failure":null,"stop_reason":"end_turn","input_tokens":1500,"output_tokens":1400,"duration_ms":27600,"prompt_version":2}
```

`outcome` is `published`, `rejected` (`reason` is the `validateSharedSet`
code), `upstream_failed` (`failure` is the `anthropic_failure` category) or
`already_published` (another run published the date meanwhile; this paid
result was dropped). Billed but not published = `anthropic_usage` lines for
`generate_shared_daily_test` minus `published` lines. The date is a calendar
label, not about anyone; no generated text is ever logged
(`test/shared_generation.test.ts` plants secrets in the content and the avoid
list and checks all console output).

Reading a set by hand:
`npx wrangler kv key get --binding DAILY_SETS_KV --remote "set:2026-10-08"`.

## Shared Daily Test read route

`GET /v1/shared-daily-test/{date}` (`src/shared_read.ts`), `{date}` being the
app's local calendar day, `YYYY-MM-DD`. Checks, in this order, with nothing
read from the cache or KV until all four pass:

1. **App token** (`x-grammarlens-token`) → else `401 unauthorized`.
2. **Date format**: a real calendar date written exactly as `YYYY-MM-DD` →
   else `400 invalid_request`.
3. **Window** `[UTC today − 1, UTC today + 2]` (every local date in use on
   Earth, plus "tomorrow" for the prefetch) → else `404 not_found`.
4. **Kill switch**: `SHARED_DAILY_TEST_ENABLED` exactly `"true"` → else
   `404 not_found`, even for a set that is already cached.

Then the Cache API (`caches.default`, per data center; a synthetic key
`https://shared-daily-test.cache.grammarlens/set/{date}` that never includes
the token; kept 3600 s), then `DAILY_SETS_KV.get("set:{date}", {cacheTtl:
3600})`. A found set answers `200` with `{date, promptVersion, questions}` and
`Cache-Control: private, max-age=0` (the app stores it itself). A missing or
unusable set is `404 {"error":"not_found","message":"No shared Daily Test for
this date."}` and is not cached, so a set published later is found on the next
read. **A miss never generates.**

The route takes no body and no device id and reserves no quota. It lives in
modules that import neither `anthropic.ts` nor `quota.ts`;
`test/shared_read.test.ts` checks that import graph, and that every case (hit,
miss, out of window, malformed date, bad token, switch off) makes no outbound
request and leaves `QUOTA_KV` untouched. A pulled set (the owner deleting
`set:{date}`) can still be served for up to an hour from a data center's cache
and KV's read cache.

## Local measurement E (not deployed)

`eval/` holds the local measurement of the shared Daily Test quality step
(`docs/1.1.0-shared-daily-test-quality.md` §13.6): `npm run eval -- dry-run`
prints its requests and estimated cost without calling the API; `run` (3
dates; `--add-dates` adds more to a finished run) and `analyze` need the
owner's approval. `eval/README.md` is the owner's checklist.
It uses the Worker's own request builders and gates, bundled for Node; the
Worker never imports it. Its outputs (`eval/out/`), inputs (`eval/input/`) and
bundle (`eval/.build/`) are gitignored.

The **generator comparison** (2026-09-29, report §16) lives in the same place:
`npm run eval -- compare --dry-run` prints its 9 calls and estimated cost
(≈ $0.44); `compare` runs prompt v2 with `claude-sonnet-5` and
`claude-sonnet-5-5` (default and `low` effort) on 3 dates, at most $1, and
needs the owner's approval. Checklist: the second half of `eval/README.md`.

## Known tradeoff: quota isn't atomic

`src/quota.ts` reads then writes two KV counters per request (device +
global), with no compare-and-swap — two requests landing at nearly the same
instant can both read the same pre-increment count and both proceed. This
is a documented, accepted tradeoff at this project's traffic scale (a
personal project, pre-launch, a handful of testers), not something worth a
Durable Object for yet. If real concurrent traffic ever makes the overshoot
matter, that's the fix to reach for then.
