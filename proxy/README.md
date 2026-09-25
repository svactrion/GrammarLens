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
| `GET /health` | liveness check, no auth |

Every operation route requires an `x-grammarlens-token` header matching the
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
2. `npm run deploy` (`wrangler deploy`).
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
  `generate_shared_daily_test` (1.1.0's one set per date, not wired to a route or
  schedule yet) are both `daily_test`. `item_count` is the number of questions
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

`failure` is one of `network_error`, `http_error`, `unreadable_body`,
`no_text_block`, `invalid_json_content`. `upstream_error_type` is Anthropic's
error `type` only if it is one of its documented values, otherwise `unknown`.
The upstream response body and exception messages are never logged, since
both can contain request or response text; `test/error_log.test.ts` plants
secrets in each place and checks all console output. The catch-all in
`src/index.ts` logs an unexpected error the same way, as
`{"event":"unhandled_error","kind":...,"operation":...,"error":"TypeError"}`:
only a category (a built-in error name, `other_error` or `non_error`), never
the message or stack. Every `console` call in `src/` now writes one of these
three fixed-field lines (`anthropic_usage`, `anthropic_failure`,
`unhandled_error`).

Deployed.

`DEVICE_DAILY_LIMIT`/`GLOBAL_DAILY_LIMIT` (plain vars in `wrangler.jsonc`,
not secret) are conservative placeholder defaults, not measured numbers —
same status as `StorageService.dailySessionLimit` on the client side (see
`docs/prd-v2.md` §7.2). Adjust and redeploy as real usage data comes in.

## Known tradeoff: quota isn't atomic

`src/quota.ts` reads then writes two KV counters per request (device +
global), with no compare-and-swap — two requests landing at nearly the same
instant can both read the same pre-increment count and both proceed. This
is a documented, accepted tradeoff at this project's traffic scale (a
personal project, pre-launch, a handful of testers), not something worth a
Durable Object for yet. If real concurrent traffic ever makes the overshoot
matter, that's the fix to reach for then.
