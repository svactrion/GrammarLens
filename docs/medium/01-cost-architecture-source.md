# Medium article 1 — where the cost leaks: source material

**What this is:** raw material for the first Medium article (to be written
in Turkish): where cost leaks in an AI app, from the free Daily Test assumed
to cost nothing, to one generation per device, to the shared Daily Test.
Facts only, each with its source. Not a draft.

**Sources and how they are cited** (the same scheme as
`docs/case-study-material.md`):
- `BL <date> (<heading words>)` = the `docs/build-log.md` entry with that
  date and heading.
- `roadmap § <section> › "<item>"` = a section of `docs/roadmap.md`, then
  the bold item inside it.
- `PRD2 §x` = `docs/prd-v2.md`; `SDT §x` = `docs/1.1.0-shared-daily-test.md`;
  `SDTQ §x` = `docs/1.1.0-shared-daily-test-quality.md`.
- **measured** / **estimate**: as the source labels the figure. A cost
  computed from measured token counts at list price is marked measured
  only where the source calls it measured.

**Cut-off:** the build log's entries up to 2026-10-04.

---

## 1. Chronology

| Date | Decision or finding | Source |
|---|---|---|
| 2026-07-20 | Model choice Opus → Sonnet before the first commit: generation and scoring "don't need Opus-level capability"; Sonnet is cheaper and faster, and per-session cost matters. | BL 2026-07-20 |
| 2026-09-02 | v2.1 split: free Daily Test, trial, paid Topic Practice. A free, unlimited Topic Practice is estimated at ~$90–270/month at 100 DAU. The free Daily Test's marginal API cost is written as "~0 (deterministik)", on the plan that one set a day is generated for everyone. | BL 2026-09-02; PRD2 §12.1, §12.2 |
| 2026-09-02 | Same day, corrected: one shared set needs a backend, and there is none; every device generates its own Daily Test. Estimate ~$0.01–0.015 per device per day; a shared set is noted as a later step "if usage grows". | PRD2 §12.8 (Düzeltme, Güncel karar) |
| 2026-09-06 | API key moved out of the client behind an operation-based Cloudflare Workers proxy; the proxy owns model, prompts, schemas and `max_tokens`, and keeps per-device and global daily caps, counted before the Anthropic call. A forwarding proxy rejected: it "can't reason about cost per operation". | BL 2026-09-06 |
| 2026-09-07 | Unit economics: Daily Test generation $0.021, Topic Practice session $0.034 (estimates, Sonnet 4.6 at $3/$15 per MTok; §12.4 had priced Sonnet 5 at $2/$10). A free user who opens the app daily: ~$0.63/month, "returns nothing". Device cap 30 → 15 operations a day; `GLOBAL_DAILY_LIMIT` 300 bounds total spend at ~$300/month. | PRD2 §13.7 |
| 2026-09-15 | Paywall gap, cost side: Review's "Practice this" started billed practice for free users with no entitlement check, bounded only by the shared 10-a-day cap, and could pick the longest (10-question) length. Fixed: the check inside `launchPracticeSet`; free users get 1 session a day, 3 questions; quota spent only on a successful generation. | BL 2026-09-15 (free-tier "Practice this" leak …) |
| 2026-09-21 | Premium session cap 10 → 5: at ~$0.034 a session, 10 a day is ~$10.20/month against ~$3.54/month net annual revenue (estimates). | BL 2026-09-21 (launch checklist: code items); PRD2 §13.8 |
| 2026-09-21 | Token logging deployed: one line per successful Anthropic call into Workers Logs (kind, operation, item count, input/output tokens). Persistent storage proposed, not built (Workers Analytics Engine recommended). | PRD2 §13.10; roadmap § Launch scope › "Proxy token logging" |
| 2026-09-21 | Daily Test stops sending weak spots; the prompt becomes a fixed general mix. Reasons include "after launch the Daily Test moves to one shared set". | BL 2026-09-21 (Daily Test: weak spots no longer sent); PRD2 §13.12 |
| 2026-09-21 | Shared Daily Test recorded as post-launch: "there are no users today, so there is no saving to capture"; decide after token-log data. | roadmap § Post-launch tasks › "Shared Daily Test" |
| 2026-09-22 | Fixed, hand-written first-day Daily Test: generating it meant "a proxy call and its cost for every install" and an unread answer key. Later days unchanged. | BL 2026-09-22 (a fixed first Daily Test …) |
| 2026-09-22 | Tomorrow's set generated in the background after each completion: "one extra `generate_daily_test` per active day, moved from tomorrow's open to today's completion"; a skipped day "wastes one generation". | BL 2026-09-22 (tomorrow's Daily Test …) |
| 2026-09-22 | Shared Daily Test direction decided: one set per day for all users, post-launch; timing "after 4 weeks of proxy token-log data". | roadmap § Post-launch tasks › "Shared Daily Test"; PRD2 §13.12 (update note) |
| 2026-09-24 | Per-question explanation added to the Daily Test; output measured over 10 local runs: 1166–1173 input, 1319–1632 output tokens, ≈ $0.023–0.028 per set, above the $0.021 estimate. Daily Test gets its own token limit (2048 → 3072). | BL 2026-09-24 (Daily Test: output measured …); PRD2 §13.7 (measurement note) |
| 2026-09-24 | Prefetch waste recorded: "every install that stops after the Day-0 test pays for one generation; skipped days waste the prepared set". | roadmap § Post-launch tasks › "Prefetch waste" |
| 2026-09-26 | Shared Daily Test moved into 1.1.0 and designed: one set per date, generated by an hourly cron three UTC days ahead, stored in KV, served by a read route that never calls Anthropic; bundled fallback pool; 1.0.0's per-device route left unchanged (Option A). | SDT §0; BL 2026-09-26 (… owner decisions) |
| 2026-09-26 | First deploy; first cron run: 1,380 input + 1,620 output tokens (≈ $0.028), CPU 8 ms of the Free plan's 10 ms. Owner review of the first set: the validator checks structure, not grammar; a daily verification call estimated at ~1–2 cents/day. | BL 2026-09-26 (… first deploy) |
| 2026-09-27 | Quality: 4 of 10 reviewed questions defective; plan: prompt v2, a separate check call before publishing, `acceptedAnswers`. | SDTQ §0; BL 2026-09-27 (… owner decisions, P4) |
| 2026-09-28 | Measurement E: $2.849 measured over 60 billed calls (estimate $2.06, +38%, "almost all of it thinking output"). Labelled defect rate for v2 sets 30% of questions. | SDTQ §14.1, §16.1 |
| 2026-09-29 | Path A: 1.1.0 ships with prompt v2 and a Sonnet generator, without the check call; check call and repairs (P7a–c) after 1.1.0. | SDTQ §16.1; BL 2026-09-29 (… D-L deployed, path A …) |
| 2026-09-29 | Generator comparison ($0.385 measured): `claude-sonnet-5` $0.055/set, `claude-sonnet-5-5` default effort $0.054/set, `claude-sonnet-5-5` `effort: "low"` $0.019/set; all 3 of 3 passed the gate; owner saw "no clear quality difference". `claude-sonnet-5-5` at `low` chosen. | SDTQ §16.5; BL 2026-09-29 (… generator comparison …) |
| 2026-09-30 | Client C1: the 1.1.0 Daily Test reads the shared set and never calls the per-device route; the prefetch becomes "a free read of tomorrow's shared set". Verified on a device. | BL 2026-09-30 (… client C1 …), (… C1 verified …); roadmap § Post-launch tasks › "Prefetch waste" (update) |
| 2026-10-04 | No persistent storage for token cost data for now; the measure of real cost is the Anthropic Console's monthly usage; Workers Analytics Engine waits for real users. | BL 2026-10-04 (token cost data: no persistent storage for now) |

## 2. First look vs real problem

| First look (quoted) | What overturned it | Source |
|---|---|---|
| Free tier's marginal API cost: "~0 (deterministik)" | Same day: "GrammarLens'te backend yok … her cihaz kendi Günlük Test'ini kendi API çağrısıyla üretmek zorunda." | PRD2 §12.2; §12.8 |
| "Gerçek maliyet avantajı paylaşımdan değil … günde yalnızca 1 kez üretilmesi … ve hiç LLM değerlendirme çağrısı yapmaması" | §13.7: "A free user who opens the app daily costs ~$0.63/month and returns nothing. That, not the subscription price, is the structural cost exposure." | PRD2 §12.8; §13.7 |
| Daily Test generation $0.021 (estimate) | 10 measured runs after the explanation field: ≈ $0.023–0.028 per set. | PRD2 §13.7 (table; measurement note) |
| §12.4 priced at $2/$10 per MTok (Sonnet 5) | "The model actually deployed is Sonnet 4.6 at $3/$15 — 50% higher per token." | PRD2 §13.7 |
| Shared generation: "no users today, so there is no saving to capture"; decide "after 4 weeks of proxy token-log data" | Moved into 1.1.0 on 2026-09-26, before that data existed. The reason for the timing is not in the record (§7). | roadmap § Post-launch tasks › "Shared Daily Test"; BL 2026-09-26 |
| Daily verification call "~1–2 cents/day" | Measured in E: a check of 5 questions with `claude-opus-5-5` ≈ $0.047 (mean). | BL 2026-09-26 (… first deploy); SDTQ §15.4 |
| E estimate $2.06 | Measured $2.849, "+38%, almost all of it thinking output". | SDTQ §14.1 |
| Day-0 test fixed and hand-written, no generation | Its completion still triggers tomorrow's prefetch: "every install that stops after the Day-0 test pays for one generation". | BL 2026-09-22 (a fixed first Daily Test …); roadmap § Post-launch tasks › "Prefetch waste" |

## 3. Decisions and reasons

| Decision | Chosen | Rejected | Reason (as recorded) | Source |
|---|---|---|---|---|
| Model | Sonnet | Opus | Practice generation and scoring don't need Opus; Sonnet cheaper and faster. | BL 2026-07-20 |
| Proxy shape | Operation-based proxy | Forwarding proxy | A forwarding proxy lets a client send any system prompt and `max_tokens` through the real key, cannot validate, and "can't reason about cost per operation". | BL 2026-09-06 |
| Quotas | Per-device and global caps, reserved before the call; device cap 30 → 15 | — | Reserving before the call "counts the attempt, not just a success — that's what actually bounds spend"; at 30 a device could cost ~$30/month. | BL 2026-09-06; PRD2 §13.7 |
| Free tier | Free Daily Test + paid Topic Practice + trial | Hard paywall; free launch | Hard paywall: nobody would experience the feedback testers praised. Free launch: funnel work is a project goal. | `case-study-material.md` §2 ("v2.1 free / trial / paid split") |
| Paywall gap | Entitlement check inside `launchPracticeSet`; free 1 session/day, 3 questions | Before: entitlement checked only in Home's tap handlers. A separate "limit reached" dialog: not built | One function every generation goes through, so no caller can skip it. The limit of 1: to cap the cost of each free user and to point anyone who wants more practice to Premium (recorded after the fact, 2026-10-04). | BL 2026-09-15; BL 2026-10-04 (free practice limit …) |
| Session cap | 10 → 5 | Raise `DEVICE_DAILY_LIMIT` to ~25; cap 7 | Margin at ~$0.034/session; 5 sessions fit inside the device limit of 15. | PRD2 §13.8; `case-study-material.md` §2 |
| First-day test | Fixed, hand-written set | Generated set; a preload on "Get started" | Every new user sees it; generating it meant a wait, a call and its cost for every install, and an unread key. | BL 2026-09-22 (a fixed first Daily Test …) |
| 1.0.0 route | Option A: unchanged, per device | B: shared set on the old route ("broken product", repeats); C: a different stored set per call (KV writes, still repeat risk) | 1.0.0 clients must not get repeated tests. Accepted: each 1.0.0 device keeps costing one generation per active day until it updates. | SDT §1; BL 2026-09-26 (… owner decisions) |
| Generation trigger | Cron only, hourly, 3 days ahead, at most 3 attempts per date | Generate on first request with a lock; cron + on-demand backup | A lock needs D1 or a Durable Object; the first user would wait ~27 s+; the read route never reaches Anthropic. | SDT §3 |
| Storage | KV namespace + Cache API | D1, R2, Cache API alone | Write-once, read-many, ~6 KB values. | SDT §4 |
| Fallback | Bundled pool (7 live sets, owner-reviewed and corrected) | Per-device generation as a fallback | B "raises cost in exactly the situations where the proxy is already unhealthy". | SDT §5; BL 2026-10-04 (… the fallback pool final …) |
| Evaluation | On the device, deterministic; explanations generated with the set | Personal AI evaluation | "Daily Test cost becomes fully independent of the number of users", and the Daily Test stays free of the AI permission. | BL 2026-09-26 (… owner decisions) |
| Quality step for 1.1.0 | Path A: prompt v2 + Sonnet generator, no check call | Plan D: generator + `claude-opus-5-5` check call (≈ $0.096/day normal) | Recorded as the owner's path; P7a–c move after 1.1.0. | SDTQ §16.1, §15.4 |
| Generator | `claude-sonnet-5-5`, `effort: "low"` | `claude-sonnet-5` default; `claude-sonnet-5-5` default | All passed 3 of 3; no clear quality difference seen; V3 $0.019 vs $0.054–0.055 per set, 11.4 s vs 39–48 s average. | SDTQ §16.5 |
| Token cost storage | None for now; the Anthropic Console's monthly usage | Workers Analytics Engine; Logpush to R2; a daily aggregate in KV or D1 | No users, no data to lose; §13.10 was written while every device generated its own Daily Test. | BL 2026-10-04 (token cost data …); PRD2 §13.10 |

## 4. Costs paid

| Decision | Cost (as recorded) | Source |
|---|---|---|
| Daily Test stops using weak spots | Personalization lost: "a shared set cannot be chosen by an error profile"; removed on 2026-09-21, ahead of the shared set. | roadmap § Post-launch tasks › "Shared Daily Test"; PRD2 §13.12 |
| Shared Daily Test | Scheduled generation and storage are "a new source of failure, so a fallback is mandatory"; a time-zone rule needed. | roadmap § Post-launch tasks › "Shared Daily Test" |
| Shared Daily Test | One set reaches every user: 4 of 10 reviewed questions defective in the first sets; in the owner's review of 35 live questions, 6 had a right or defensible answer graded "Needs work" (P12). | SDTQ §0; BL 2026-10-04 (… P12, P13, P14 …) |
| Option A | Each 1.0.0 device keeps costing one generation per active day until it updates. | BL 2026-09-26 (… owner decisions) |
| Path A | "Without the check call, nothing between the generator and the learner judges grammar." Check call and repairs deferred (P7a–c); other accepted answers on live sets deferred (P14). | SDTQ §16.1; roadmap § 1.1.0 — release candidate › "Moved out of 1.1.0" |
| Evaluation on device | A personal AI "why was this wrong?" explanation becomes a low-priority draft. | BL 2026-09-26 (… owner decisions) |
| Same prompt for everyone | Sets repeat topics and scenarios across days and users (observed across 5 sampled generations). | roadmap § Post-launch tasks › "Daily Test sets repeat" |
| Free quota | A free user who uses the Daily Test and the practice session daily: about $1.72–1.86/month on 1.0.0 (part estimate), returning nothing. | PRD2 §13.7 (measurement note) |
| Prefetch | A skipped day wastes one generation (1.0.0); stale rows never deleted until C3. | BL 2026-09-22 (tomorrow's Daily Test …); roadmap § Post-launch tasks › "Prefetch waste" |
| No persistent token storage | Only the total is visible, not the split per session; Workers Logs is not persistent (3 days on Workers Free per Cloudflare's docs; the account's setting not verified). | BL 2026-10-04 (token cost data …) |

## 5. Numbers

| What | Value | Unit | Label | How obtained | Source |
|---|---|---|---|---|---|
| Free unlimited Topic Practice | ~$90–270 (100 DAU); ~$900–2,700 (1,000 DAU) | per month | estimate | rough, no token measurement | PRD2 §12.1 |
| Daily Test, per device (§12.8) | ~$0.01–0.015 ⚠ | per device per day | estimate | generation only, rough | PRD2 §12.8 |
| Daily Test generation (§13.7) | $0.021 ⚠ | per set | estimate | modelled prompt/completion sizes, Sonnet 4.6 | PRD2 §13.7 |
| Daily Test set, 1.0.0 route with explanations | ≈ $0.023–0.028 ⚠ | per set | measured | 10 local runs, 2026-09-24, Sonnet 4.6 list price | PRD2 §13.7 (measurement note); BL 2026-09-24 |
| Topic Practice session | $0.034 | per session | estimate | modelled, 5 items | PRD2 §13.7 |
| Free daily user (§13.7 table) | ~$0.63 ⚠ | per month | estimate | 30 Daily Tests × $0.021 | PRD2 §13.7 |
| Free daily user, Daily Test only (measurement note) | $0.70–0.84 ⚠ | per month | measured tokens | 30 × $0.023–0.028 | PRD2 §13.7 (measurement note) |
| Free daily user, Daily Test + daily practice | ≈ $1.72–1.86 | per month | part measured, part estimate | $0.70–0.84 + 30 × $0.034 | PRD2 §13.7 (measurement note) |
| Premium, typical | $1.43 | per device per month | estimate | 20 days, 30 sessions | PRD2 §13.7 |
| Net revenue | $5.09 (monthly plan); $3.54 (annual) | per month | — | after Apple's 15% | PRD2 §13.7 |
| Device cap | 30 → 15 | operations per day | — | decision 2026-09-07 | PRD2 §13.7 |
| Global spend bound | ~$300 | per month | estimate | `GLOBAL_DAILY_LIMIT` 300 | PRD2 §13.7 |
| Session cap worst case | ~$10.20 (10/day) → ~$5.10 (5/day) | per device per month | estimate | × $0.034 | PRD2 §13.8 |
| Shared set, plan before the build | $0.023–0.028, at most ~$0.084 ⚠ | per day | from the measured per-set figure | 1 generation per date, 3 attempts max | SDT §0, §3 |
| First live cron run | ≈ $0.028; 1,380 in / 1,620 out tokens; CPU 8 ms | per set | measured | 1 run, 2026-09-26 | BL 2026-09-26 (… first deploy) |
| Highest cron CPU | 8.73 | ms (of 10) | measured | dashboard readings | roadmap § Version naming (1.1.0 row) |
| Daily check call (first guess) | ~$0.01–0.02 ⚠ | per day | estimate | — | BL 2026-09-26 (… first deploy) |
| Check of 5 questions, `claude-opus-5-5` | ≈ $0.047 ⚠ | per check | measured (mean) | E, 2026-09-28 | SDTQ §15.4 |
| Plan D (generator + check) | ≈ $0.096 (≈ $2.9/month) | per day | built from measured means | normal case | SDTQ §15.4 |
| E run | $2.849 (estimate $2.06) | total | measured | 60 billed calls, 2026-09-28 | SDTQ §14.1 |
| Defects in v2 sets | 30 | % of questions | measured (owner labels) | E, 2026-09-28 | SDTQ §16.1 |
| Defects in first sets | 4 of 10 | questions | owner review | sets of 2026-09-26 and 2026-09-27 | SDTQ §0 |
| Generator comparison | $0.385 | total | measured | 3 variants × 3 sets, 2026-09-29 | SDTQ §16.5 |
| `claude-sonnet-5`, default | $0.055; 2,873 / 4,944 tokens; 48.4 s avg | per set | measured | 3 runs | SDTQ §16.5 |
| `claude-sonnet-5-5`, default | $0.054; 2,875 / 4,792 tokens; 39.1 s avg | per set | measured | 3 runs | SDTQ §16.5 |
| `claude-sonnet-5-5`, `low` (chosen) | $0.019; 2,875 / 1,354 tokens; 11.4 s avg | per set | measured | 3 runs | SDTQ §16.5, §16.7 |
| Shared set, normal | ≈ $0.57 | per month | estimate | 30 × $0.019 | SDTQ §16.7 |
| Shared set, all 3 attempts | ≈ $0.057/day; ≈ $1.71/month | — | estimate | 3 × $0.019 | SDTQ §16.7 |
| Shared set, absolute ceiling | ≈ $0.47/day; ≈ $14/month | — | estimate | 3 attempts at the full thinking budget | SDTQ §16.7 |
| Fallback pool authoring (option in the plan) | ~$0.025 per set; ~$0.35 for 14 | one-time | estimate | — | SDT §5 |
| Workers Logs retention | 3 days (Free), 7 days (Paid) | days | — | Cloudflare docs, read 2026-10-04; account setting not verified | BL 2026-10-04 (token cost data …) |

⚠ **Conflicting figures:**
- Daily Test per set or per day: ~$0.01–0.015 (§12.8, rough), $0.021 (§13.7,
  modelled), ≈ $0.023–0.028 (10 measured runs, after the explanation field).
  Different dates, prompts and pricing bases.
- Free daily user: ~$0.63/month (§13.7 table) vs $0.70–0.84 (measurement
  note, Daily Test only); the note says it replaces the earlier figure.
- Shared set per day: $0.023–0.028 (SDT §0, 2026-09-26, the 1.0.0 prompt on
  Sonnet 4.6) vs ≈ $0.019 (SDTQ §16.7, prompt v2 on `claude-sonnet-5-5`
  `low`). Different model and prompt.
- Check call: ~1–2 cents/day (2026-09-26 guess) vs ≈ $0.047 per check
  (measured in E).

## 6. How I'll know

Under the 2026-10-04 decision:

| What | Where | When | Source |
|---|---|---|---|
| Total API spend | Anthropic Console, monthly usage | monthly | BL 2026-10-04 (token cost data …) |
| Practice sessions' cost | Console total minus the shared Daily Test (one call a day, a fixed item) | monthly | BL 2026-10-04 (token cost data …) |
| 1.0.0 legacy calls | Also inside the Console total while 1.0.0 devices are in use; a separate key for the cron would split them (not built) | — | SDT §10 option 3; BL 2026-10-04 |
| Per-call tokens and operation | Workers Logs, `event = anthropic_usage` | only within the retention window (3 days on Free) | `proxy/README.md` "Token usage log"; BL 2026-10-04 |
| Shared vs fallback share | Firebase, `set_source` on `daily_test_completed` | after release | roadmap § 1.1.0 — release candidate › "Analytics" |
| Free practice use | `free_practice_used`, `free_practice_quota_exhausted` | quota model decided with 4 weeks of data | `case-study-material.md` §2; roadmap § Post-launch tasks › "Free practice quota model" |
| Cost guardrail | Anthropic console spend + Cloudflare per-Worker request counts | set after week 4 | `docs/analytics-plan.md` (cost guardrail signal) |

**Cannot be read under this decision:**
- Cost per session or per operation over time (only the total).
- Any per-call data older than the Workers Logs retention.
- Whether a timed-out or unparseable generation was billed: "not answerable
  with the current logs" (SDT §10).
- Cost per user or per tier: the Console spend is "a rough total, not a
  per-user or per-tier figure", and Firebase cannot derive cost
  (`docs/analytics-plan.md`, cost guardrail signal).

## 7. Not found

- Why the shared Daily Test moved into 1.1.0 (2026-09-24 / 2026-09-26)
  before the "4 weeks of proxy token-log data" set as its timing.
- Why the device cap started at 30 operations a day.
- A real-traffic cost figure for any operation: no token-log reading of
  live traffic is recorded.
- Any actual monthly total from the Anthropic Console.
- Whether local development uses the same Anthropic key or workspace as the
  deployed proxy (it would then be in the Console total).
- A threshold for "when real users arrive" (Workers Analytics Engine).
- The number of 1.0.0 devices (1.0.0 is not released).
- Workers Logs retention as set in this Cloudflare account (not verified).
