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
