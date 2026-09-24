# GrammarLens — case study source material

**What this is:** raw material for a case study, not the case study. Facts
only, each with its source. No narrative is built here.

**Sources and how they are cited:**
- `BL <date> (<heading words>)` = the `docs/build-log.md` entry with that
  date and heading.
- `roadmap.md § <section> › "<item>"` = a section of `docs/roadmap.md`, then the bold item title inside it, so the reference survives line shifts.
- `PRD2 §x` = `docs/prd-v2.md` section, only where the roadmap or build log
  points to it for the reasoning.
- `git <hash>` = a commit, only where the build log and roadmap do not
  record the event.
- **[not in record]** = the build log and roadmap do not state this. Left
  blank on purpose; find a source or leave it out of the case study.

**Status words** are the project's own (roadmap.md § Launch scope (status words)): "implemented" means code
and automated tests exist; "device-confirmed" means the owner confirmed it on
a physical phone. Nothing below is marked done unless the record says so.

**Cut-off:** the build log's last entry, 2026-09-24 (build 3 submitted for
App Store review).

---

## 1. Timeline

| Date | Milestone | Source |
|---|---|---|
| 2026-07-19 | First commit ("Initial commit"). | git `2575bff` |
| 2026-07-20 | Model choice Opus → Sonnet, before the first commit of app code; app scaffolded with the Claude API, first running build. | BL 2026-07-20 |
| 2026-07-21 | First UX finding from testing: a summary of past mistakes is needed before targeted practice (P0 for Iteration 1). | BL 2026-07-21 |
| 2026-07-24 | Iteration 2 shipped, driven by four interview findings (question mix, plain-language feedback, Review stats, skipped ≠ wrong). | BL 2026-07-24 |
| 2026-07-25 | Visual identity pass (Material 3, orange/blue, light + dark). | BL 2026-07-25 |
| 2026-08-24 | "Make the MVP try-able" dropped; lean launch decided (public launch before streak mode). | roadmap.md § What's next › Decision: "make the MVP try-able" dropped (and "lean launch") |
| 2026-08-24 | v2 Phase 1 (Welcome, onboarding, Home, Settings) and Phase 2 (informational Premium/early-access screen) shipped. | BL 2026-08-24 |
| 2026-09-02 | v2.1 pivot: free Daily Test + trial + paid Topic Practice; RevenueCat chosen; Daily Test data layer, screens and Day-0 flow built. | BL 2026-09-02 |
| 2026-09-05 | Design audit written; v2.2 B-structure batch (Premium screen merge, two-plan pricing, Home as a "today" screen, Daily Test feeds the error profile). | BL 2026-09-05 (v2.2 structure batch …), (Home rebuilt …), (Daily Test now feeds …) |
| 2026-09-06 | Anthropic API key moved out of the client behind an operation-based Cloudflare Workers proxy. | BL 2026-09-06 |
| 2026-09-07 | Proxy on the permanent domain `api.ahmettayfur.com`; Turkish-keyboard letter variants no longer graded as mistakes. | BL 2026-09-07 (both entries) |
| 2026-09-08 → 09-10 | B-polish: D2 (one blue) closed 09-08, D1 (hybrid theme) closed 09-09, D5 and the app icon 09-10. | roadmap.md § What's next › 2. v2.2 — structure, then finish › B-polish; BL 2026-09-08, 2026-09-09, 2026-09-10 |
| 2026-09-13 | Firebase project connected (Analytics + Crashlytics collecting). | roadmap.md § Where we are now › Current wiring › "Firebase — connected" |
| 2026-09-14 | First run on a physical iPhone (every earlier check was simulator-only); bank account submitted to App Store Connect. | BL 2026-09-14; roadmap.md § What's next › 1. Pre-launch checklist › "Bank account submitted 2026-09-14" |
| 2026-09-15 | Paid Apps Agreement Active; free-tier "Practice this" leak closed; avatar carousel and illustrated avatar set; Premium redesign batches 0–4. | roadmap.md § Where we are now › Current wiring › "Paid Apps Agreement"; BL 2026-09-15 (all entries) |
| 2026-09-16 | iOS minimum 13.0 → 15.0; v2/v3 boundary defined (`v2-snapshot`); EU DSA resubmitted after a rejection. | BL 2026-09-16 (all entries) |
| 2026-09-17 | Subscription products created (Ready to Submit); first sandbox purchase on a device; history rewritten to remove personal data; destructive migration and non-atomic Daily Test completion fixed; Monthly Climb moved to the new branch `monthly-climb-v2`. | BL 2026-09-17 (all entries) |
| 2026-09-18 | Monthly Climb on Home; device feedback packages 1 and 2 (device-confirmed); Premium 4a–4c; Nunito Sans; Profile tab and text size; medal rule v1. | BL 2026-09-18 (all entries) |
| 2026-09-19 | Plan change: `monthly-climb-v2` becomes the launch branch; gamification ships in the first release. | roadmap.md § Launch scope (plan change) |
| 2026-09-21 | Launch-checklist code items: session cap 10 → 5, debug tools out of release, privacy note corrected, proxy logging, age/occupation removed, Day-0 climb animation, Daily Test stops sending weak spots. | BL 2026-09-21 (all entries) |
| 2026-09-22 | AI permission before Topic Practice; fixed first-day Daily Test; paywall moved to Home after the first climb; tomorrow's Daily Test prepared in the background; EU DSA trader verification Active. | BL 2026-09-22 (all entries); roadmap.md § Where we are now › Current wiring › "EU DSA" |
| 2026-09-23 | `monthly-climb-v2` merged into `main` (`--no-ff`, `a0723c6`; branch kept). | BL 2026-09-24 (build 3 submitted …) |
| 2026-09-23 | Build 1 (`1.0.0+1`) uploaded to TestFlight. | BL 2026-09-24 (build 3 submitted …) |
| 2026-09-23 | Submission prep: version `1.0.0+1`, export compliance key, launch screen colors; practice-results offer card. | BL 2026-09-23 (submission prep …), (practice results …) |
| 2026-09-24 | Per-question Daily Test explanation; Daily Test token budget measured and raised; proxy deployed; build 2 archived (uploaded later the same day, see the next rows). | BL 2026-09-24 (Daily Test: a per-question explanation), (… output measured …), (proxy deployed; build 2 archived) |
| 2026-09-24 | Portrait lock on iPhone and iPad; build 3 (`1.0.0+3`) archived. | BL 2026-09-24 (portrait lock …) |
| 2026-09-24 | Builds 2 and 3 uploaded; build 3 submitted to App Store review with both subscriptions and their group. Not approved yet; manual release selected. | BL 2026-09-24 (build 3 submitted …) |

---

## 2. Decisions

| Decision | Date | Reasoning (as recorded) | Alternatives (as recorded) | Outcome | Source |
|---|---|---|---|---|---|
| **Free-tier practice quota:** a free user gets 1 "Practice this" session per day, always the 3-question length, no length picker; the gate lives inside `launchPracticeSet`, not in each screen. | 2026-09-15 | A free user could trigger billed generation from Review with no entitlement check. The check moved into the one function every generation goes through so no caller can skip it. A free session could previously pick the most expensive length. Quota is spent only on generation success. | Separate "limit reached" dialog: not built; the same Premium screen as Home's locked card is used. The number 1 itself: [not in record]. | Implemented, 251 tests. Two events (`free_practice_used`, `free_practice_quota_exhausted`) added so post-launch data can show whether 1 is right. | BL 2026-09-15 (free-tier "Practice this" leak …); roadmap.md § Where we are now › Shipped › "2026-09-15 — Free tier practice quota" |
| **Premium daily session cap 10 → 5.** | 2026-09-21 | Margin: at ~$0.034/session (an unmeasured estimate), 10 sessions/day is ~$10.20/month against ~$3.54/month net annual revenue. Also closes the proxy-headroom conflict: 5 sessions = 10 proxy units + 1 Daily Test unit, inside `DEVICE_DAILY_LIMIT` = 15. | Recorded on 2026-09-15 as the open choice: raise `DEVICE_DAILY_LIMIT` to ~25, or lower the cap to 7. | Implemented, automated tests only. `DEVICE_DAILY_LIMIT` unchanged at 15. Nothing in `lib/` says "unlimited". | BL 2026-09-21 (launch checklist: code items); roadmap.md § Launch scope › Launch checklist, code items › "Session cap 10 → 5", roadmap.md § Where we are now › Shipped › "Open decision … proxy quota headroom for premium"; PRD2 §13.8 |
| **Monthly Climb in the first release** (it had been planned as post-launch v3). | 2026-09-19 | `main` was never shipped, so gamification is part of launch, not an add-on; it is the whole engagement layer and the ledger every other item reads; analytics must be in the first build because a missing baseline cannot be recovered. | Earlier plan: v3, after launch, not merged into `main` (roadmap.md § Later phases (post-v2) › "v3 — planned" (2026-09-18 record)). Weekly cycle ("Weekly Climb" draft) superseded by a monthly one; the reason for weekly → monthly is [not in record] (BL 2026-09-16 says that redesign happened outside this repo). | Implemented. Device-confirmed: result CTA (package 1), Home scrolling (package 2), locked medal shell. Not device-confirmed: `In progress` card, finalized history, v17 migration. A full launch acceptance pass is recorded as open. | roadmap.md § Launch scope (plan change), roadmap.md § Launch scope › In scope (launch), Monthly Climb and medals rows, roadmap.md § Later phases (post-v2) › "v3 — superseded 2026-09-19"; BL 2026-09-16 (pre-v3 repo snapshot …), BL 2026-09-18 |
| **Avatar system:** stock avatars, chosen in Settings, not in onboarding (2026-08-24); random avatar assigned at onboarding (2026-09-05); carousel of 12 illustrated avatars replaces the grid (2026-09-15); colored ring removed (2026-09-15); CC BY 4.0 credits screen (2026-09-21). | 2026-08-24 → 2026-09-21 | Settings, because every onboarding field before the user sees value costs completions. Random at onboarding because new users saw a placeholder despite avatars existing. Carousel because selection changed the tile's footprint and reflowed the grid (see §5). Credits because the licence requires attribution. | Upload-your-own-photo: deferred (PRD2 §11). A grid: replaced after the layout bug. An inline carousel on Profile: rejected 2026-09-21 (a horizontal `PageView` inside the page's vertical list; autosave, geometry and `Hero` live in the pushed screen). Ring palette expanded to 10 colors, then deleted outright. | Implemented. Carousel verified on simulator/harness; Credits and Profile layout: automated tests only, device check pending. | BL 2026-08-24 (item 5); BL 2026-09-05 (Home rebuilt …); BL 2026-09-15 (avatar picker …), (Avatar presentation …); BL 2026-09-21 (Profile layout rework …); roadmap.md § Launch scope › Launch checklist, code items › "Avatar attribution (CC BY 4.0) + Profile layout rework" |
| **B-polish after B-structure.** | Started 2026-09-08 | Design audit's own sequencing: polishing screens whose structure is about to change is wasted work. | Back button: Direction A (bordered circle everywhere) vs B (plain chevron); B chosen after on-device mockups. Coloring the session-length card green/red per length: rejected (green/red already mean correct/incorrect). Dial showing minutes: rejected (no session timing is measured). | D1, D2, D5 closed; contrast failures closed; spacing scale only partial (used in a few screens). | roadmap.md § Where we are now › Shipped › "v2.2 B-polish — visual-polish tour", roadmap.md § What's next › 2. v2.2 — structure, then finish › B-polish; BL 2026-09-08, BL 2026-09-10 (Batch 0 …) |
| **AI permission screen before Topic Practice.** | 2026-09-22 | App Review guideline 5.1.2(i): explicit permission before personal data goes to a third-party AI. Only `score_answers` carries user text. The check sits inside `launchPracticeSet`, after the quota checks and before the length picker. Fails closed; versioned (`consent_version` 1). | [not in record] as named alternatives. Recorded design choices: back or system back counts as decline; declining costs nothing and the Daily Test never asks; no claim about the provider's retention or training. | Implemented, automated tests only; device check pending. Outside the repo at the time: privacy policy naming Anthropic, App Store privacy label, review notes. | BL 2026-09-22 (AI permission … part 1), (… part 2); roadmap.md § Launch scope › Launch checklist, code items › "AI permission before Topic Practice"; PRD2 §13.13 |
| **Shared Daily Test generation deferred** (one set per day for everyone). | Recorded 2026-09-21 | No users yet, so no saving to capture; better decided after proxy token-log data shows what a Daily Test really costs. | Current per-device generation stays. Trade-offs recorded: personalization lost, scheduled generation plus storage is a new failure source (fallback mandatory), a time-zone rule is needed. Earlier (2026-09-02) a "cohort" plan was corrected because no shared backend existed. | Post-launch item. On 2026-09-24 repeated topics and scenarios across 5 sampled generations were recorded as a related post-launch item. | roadmap.md § Out of scope › "Shared Daily Test", roadmap.md § Post-launch tasks › "Daily Test sets repeat"; BL 2026-09-21 (launch checklist: code items); BL 2026-09-02 (correction made mid-session) |
| **Offer card on the practice results screen** (replaced a line + outlined button). | 2026-09-23 | A free user who has just used the day's free practice saw only "Back to topics". The card groups chip, title, message, two benefits and the Premium button, from an owner mockup used for hierarchy only. | First version the same day: a line and an outlined "See Premium" under a filled "Back to topics". Mockup's blue surface, gradient, illustration and icon style: not reproduced. `LockedPremiumPill`: not used ("locked" meaning). | Implemented; device-confirmed 2026-09-24. | BL 2026-09-23 (Premium prompt …), (… offer card), (… benefit icons), (build 3 submitted …); roadmap.md § Launch scope › Launch checklist, code items › "Premium offer card on the practice results screen" |
| **Portrait lock on iPhone and iPad; iPad support kept.** | 2026-09-24 | App Store Connect asked for 13-inch iPad screenshots because the device family is `"1,2"`. iPad kept on purpose for school and classroom iPads. Every screen is a single vertical column; landscape was never designed or checked. | Implied by the record: dropping iPad support (keep `"1,2"` was the decision). | Implemented; device-confirmed on iPhone, iPad tried only in the simulator. Accepted costs: no rotation on an iPad in a keyboard case or stand; no Split View / Slide Over (`UIRequiresFullScreen = true`). | BL 2026-09-24 (portrait lock …), (build 3 submitted …); roadmap.md § Launch scope › Launch checklist, code items › "Portrait-only on iPhone and iPad" |
| **v2.1 free / trial / paid split.** | 2026-09-02 | Topic Practice calls Sonnet every session; a permanently free, unlimited version scales cost with users (~$90–270/mo at 100 DAU, rough estimate). | Hard paywall in front of all value: rejected (nobody would experience the feedback 3/3 testers praised). A free launch (2026-09-14): rejected, because funnel work is a project goal. | Built; functionally complete end to end on 2026-09-02. | BL 2026-09-02; roadmap.md § What's next › 1. Pre-launch checklist › "Bank account is a tax decision" (free launch rejected) |
| **Operation-based proxy, not a forwarding proxy.** | 2026-09-06 | A forwarding proxy would still let a client send any system prompt and `max_tokens` through the real key, could not validate, and could not reason about cost per operation. | Forwarding proxy: rejected for those reasons. | Deployed; on `api.ahmettayfur.com` since 2026-09-07. | BL 2026-09-06; BL 2026-09-07 |
| **Trial length:** 3 days (09-02) → 7 days (09-05) → annual 7 / monthly 3 (09-17). | 2026-09-02 → 2026-09-17 | 3 days chosen weighing habit formation against the "forget to cancel" lever. Per-plan: steer users to annual (recorded as a bet, not a finding). Reason for 3 → 7: [not in record]. | 7 days was weighed against 3 on 2026-09-02. | Read live from RevenueCat; no day count in app copy. | BL 2026-09-02; BL 2026-09-05 (v2.2 structure batch …); BL 2026-09-17 (Per-plan trial length …); roadmap.md § Launch scope › Launch checklist, code items › "Trial-length wording" |
| **Fixed, hand-written first-day Daily Test.** | 2026-09-22 | Every new user sees it, so an odd question or wrong key there costs the most; generation meant a wait, a proxy call and an unread answer key. | A preload on "Get started" (built the same day): removed, because an AI set would replace the fixed one. | Implemented, automated tests only. Difficulty recorded as a hypothesis to read from `set_source = bundled`. | BL 2026-09-22 (first Daily Test: preload …), (a fixed first Daily Test …); roadmap.md § Launch scope › Launch checklist, code items › "Fixed first-day Daily Test" |
| **First-day paywall moved to Home, after the climb, once.** | 2026-09-22 | The Day-0 result screen ended in a paywall card right after the first win, before the mountain moved. Hypothesis: the moment after a visible win converts better. | Paywall card at the end of the Day-0 result screen: removed. | Implemented; the flow (climb, then paywall) device-confirmed 2026-09-22. | BL 2026-09-22 (the first-day paywall moves to Home …); BL 2026-09-24 (build 3 submitted …); roadmap.md § Launch scope › Launch checklist, code items › "First-day paywall on Home"; PRD2 §13.14 |

---

## 3. Reverted or rejected

| What | When | Why (as recorded) | Source |
|---|---|---|---|
| **"Practice sessions" row in the Premium comparison table** (Free 1 a day, Premium 5 a day), added in `1be6314`, reverted with `git revert`. | 2026-09-23 | At 375x667 the plan cards' visible part above the fixed footer fell from 78 to about 30 pt at Medium and from 33 pt to none at Large. Owner: hiding the purchase cards is not acceptable. Writing "5 a day" into an existing row was also rejected (it blurs that row's meaning). The gap stays as a post-launch item. | BL 2026-09-23 (Premium comparison table: session row added, then reverted); roadmap.md § Post-launch tasks › "Premium comparison table does not show the daily session limit" |
| **Sending "Back to topics" to the paywall.** | 2026-09-23 | Recorded only as the outcome: owner decision after a read-only Batch 0 that "Back to topics" stays the primary button, "unchanged in look and behavior", and nothing modal is added. The idea itself and the reason for rejecting it: **[not in record]**. A related earlier call (2026-09-18): no paywall redirection in the first result-screen package. | BL 2026-09-23 (Premium prompt on the practice results screen); roadmap.md § Launch scope › Launch checklist, code items › "Premium offer card on the practice results screen"; BL 2026-09-18 (Device feedback package 1 …) |
| **`codex/monthly-climb` branch not rebased; deleted.** | 2026-09-17 | It sat on pre-rewrite history carrying personal data, and predated both data-integrity fixes; a rebase would have replayed its superseded versions of that logic. Its working-tree changes were applied fresh as a patch onto `monthly-climb-v2` (from `main` at `0deb213`); conflicts resolved keeping `main`'s migration and atomic completion. Branch and worktree removed after checking every file was on the new branch. | BL 2026-09-17 (History rewrite …), (Monthly Climb transplanted …) |
| "Make the MVP try-able" (private distribution of the MVP). | 2026-08-24 | Seven people had already used the core loop in person; another small private round would repeat what is known. | roadmap.md § What's next › Decision: "make the MVP try-able" dropped |
| Free launch (Free Apps Agreement, no bank account). | 2026-09-14 | Funnel work is one of the project's goals; shipping free defers it. | roadmap.md § What's next › 1. Pre-launch checklist › "Bank account is a tax decision" (free launch rejected) |
| `extendBody: true` for the floating nav bar. | 2026-08-24 | Hid Home's last grid row behind the bar; two fix attempts opened a `SliverList` virtualization bug. Reversed in the next round by fixing the actual cause (the `bottomNavigationBar` slot). | BL 2026-08-24 (Home + nav bar revision round; round 2) |
| Active-tab dot on the nav bar. | 2026-09-02 | Added then removed the same day: over-decorated once seen on device. | BL 2026-09-02 |
| Pinning Restore Purchases / legal links to the bottom with `Expanded`. | [date not in record; paywall follow-up, see BL 2026-09-02] | Turned a short gap into a large void; reverted to one flowing list. | roadmap.md § Where we are now › Shipped › "Paywall follow-up: fixed an invisible Restore Purchases button" |
| General fuzzy / edit-distance answer matching. | 2026-09-07 | One character is often the grammar point ("stay" vs "stays"); a closed set of seven Turkish letter pairs is folded instead. | BL 2026-09-07 (dev config reverted …) |
| Ad-copy headline "Personalized feedback, not a feature list". | 2026-09-16 | Traced to no spec doc (`git log -S`: written as ad copy in `4d327b7`). | BL 2026-09-16 (Two checks …); roadmap.md § Where we are now › Shipped › "2026-09-16 — Premium screen: on-device review fixes" |
| First avatar-picker enlargement (radius 80 / viewportFraction 0.6). | 2026-09-15 | Neighbors shrank to a sliver; reduced to 64 / 0.5, later 80 / 0.5 once the real constraint was measured. | BL 2026-09-15 (Avatar picker screen …), (Settings' avatar picker: bigger …) |
| Apple's "Monthly with a 12-Month Commitment" billing. | 2026-09-17 | Not part of the pricing decision; the disclosure block cannot state a commitment term. | BL 2026-09-17 (Savings-badge fix …); roadmap.md § Where we are now › Current wiring › "Subscription products" ("Decided against") |
| Premium footer that capped its height and scrolled inside itself. | 2026-09-22 | Two scrollables made tests ambiguous and a second scroll area in a paywall is worse UX; replaced by a height rule that moves the links back to the body at large text. | BL 2026-09-22 (Premium: legal links in the fixed footer …) |
| First-Daily-Test preload on "Get started". | 2026-09-22 | Removed the same day when the first test became a fixed set (a preload's AI set would replace it). | BL 2026-09-22 (a fixed first Daily Test …) |

---

## 4. Measurements

Only figures the record states as measured. Estimates are in their own
subsection and labeled as such.

### 4.1 Test counts (Flutter suite unless stated)

| Date | Count | Source |
|---|---|---|
| 2026-08-24 | 47, then 48 | BL 2026-08-24 |
| 2026-09-02 | 85 | BL 2026-09-02 |
| 2026-09-05 | 88 → 176 across the day's batches (130 + 1 skipped at the structure batch) | BL 2026-09-05 (all entries) |
| 2026-09-06 | 191 + 1 skipped; proxy 39 | BL 2026-09-06 |
| 2026-09-07 | 192, then 204; proxy 40 | BL 2026-09-07 (both entries) |
| 2026-09-08 / 09 | 227 | BL 2026-09-08, 2026-09-09 |
| 2026-09-10 | 237 | BL 2026-09-10 |
| 2026-09-15 | 251 → 340 across the day's batches | BL 2026-09-15 (all entries) |
| 2026-09-16 | 355 | BL 2026-09-16 |
| 2026-09-17 | 357, then 363, then 381 on `monthly-climb-v2` | BL 2026-09-17 |
| 2026-09-18 | 389 → 436 | BL 2026-09-18 (all entries) |
| 2026-09-23 | 851 (843 before), then 858 (855 before) | BL 2026-09-23 (Premium prompt …), (… offer card) |
| 2026-09-24 | 875, 878; proxy 68, 70 | BL 2026-09-24 (explanation), (weak-spot detail), (output measured) |
| 2026-09-24 | 883 Flutter + 70 proxy at build 3 | BL 2026-09-24 (portrait lock …); roadmap.md § Launch scope › Launch checklist, code items › "Build 3 (1.0.0+3)" |

The count between 436 (2026-09-18) and 843 (2026-09-23) is not recorded per
batch in the build log.

### 4.2 Daily Test token measurements (local `wrangler dev`, Sonnet 4.6, 5-item sets)

| | Output tokens (5 runs) | Input tokens | Headroom |
|---|---|---|---|
| Before (shared limit 2048) | 1632, 1470, 1527, 1497, 1481 | 1166 each | worst case 416 of 2048 (20.3%) |
| After (own limit 3072, "fewer than 25 words") | 1496, 1436, 1319, 1486, 1335 | 1173 each | worst case 1576 of 3072 (51.3%) |

- Explanation length before: 18–43 words, mean ~29. After: min 12, median 21,
  mean 20.0, max 27; 5 of 25 at 25–27 words. 25/25 explanations present in
  both rounds; every response parsed.
- Live check after deploy: HTTP 200 in 27.6 s, 5 questions, explanations of
  16, 18, 23, 22 and 27 words.

Source: BL 2026-09-24 (Daily Test: output measured …), (proxy deployed …);
roadmap.md § Launch scope › Launch checklist, code items › "Daily Test explains every answer".

### 4.3 Cost estimates (all unmeasured, as the record says)

- ~$90–270/month at 100 DAU, ~$900–2,700/month at 1,000 DAU for a free,
  unlimited Topic Practice (rough estimates). BL 2026-09-02.
- ~$0.034 per Topic Practice session; 10 sessions/day ≈ $10.20/month against
  ≈ $3.54/month net annual revenue. roadmap.md § Launch scope › Launch checklist, code items › "Session cap 10 → 5"; PRD2 §13.7, §13.8.
- Explanation field: +150–250 output tokens per set, roughly $0.002–0.004 per
  device per day on Sonnet 4.6 (estimate made before the measurement in §4.2).
  roadmap.md § Launch scope › Launch checklist, code items › "Daily Test explains every answer".
- The token log is deployed and accumulating; every unit-economics figure
  stays an estimate until weeks of traffic are measured. roadmap.md § Launch scope › Launch checklist, code items › "Proxy token logging".

### 4.4 Screen and layout measurements

| What | Figure | Source |
|---|---|---|
| Premium before the 2026-09-08 reorder | "Start free trial" needed 1357 px of scrolling past an 844 px viewport (390x844) | BL 2026-09-08 |
| Premium fixed footer, 2026-09-15 | 160.0 / 174.0 pt at 320x568 (1.0 / 1.3x), 160.0 / 170.0 pt at 375x667; worst case 30.6% of viewport | BL 2026-09-15 (Premium redesign, Batch 2 …) |
| Premium at 375x667, 2026-09-16 | footer top at 507 pt, plan cards' bottom at ~706–710 pt | roadmap.md § Where we are now › Shipped › "2026-09-16 — Premium screen: on-device review fixes" (known debt) |
| Premium legal links before 2026-09-22 | 236 pt (Medium) / 291 pt (Large) below the fold at 375x667; plan cards at most a 10 pt sliver | BL 2026-09-22 (Premium: legal links …) |
| Premium footer after 2026-09-22 | 218 / 222 pt (33%) at Medium / Large; 321 / 327 pt at 1.6x system text; after spacing pass 196 / 200 / 295 pt | BL 2026-09-22 (legal links …), (Premium footer: tighter …) |
| Comparison-table overflow | 52 px at 320 wide @2x text, 126 px at 393 @3x | BL 2026-09-21 (launch checklist: code items) |
| Session row cost | plan cards visible above the footer: 78 → ~30 pt (Medium), 33 → 0 pt (Large) at 375x667 | BL 2026-09-23 (… session row …) |
| Avatar illustrations | fill ratio 63% (Giraffe, width) to 99% (Snail, height) | BL 2026-09-15 (Settings' avatar picker …) |
| Avatar picker | center diameter 128 → 160 pt; neighbor peek 51.2 → 64 pt, same at 320 and 375 pt | BL 2026-09-15 (Settings' avatar picker …) |
| Contrast | Premium strip 9.79:1 light / 7.13:1 dark; old checkmark 2.53:1 dark (fails 3:1); dark strip after fix 9.34:1; destructive `#DC3232` 4.62:1 text, 3.67 / 3.08:1 against dialog | BL 2026-09-15 (Batch 0), BL 2026-09-16; BL 2026-09-21 (destructive action colors) |
| Onboarding disabled button | ~2.24:1 light / ~2.78:1 dark, pixel-sampled on device | BL 2026-09-09 (D1 Batch 3 …) |
| Savings badge | showed "Save 31%" against a true 30.44% | BL 2026-09-17 (Savings-badge fix …) |
| Build 3 | IPA 30.3 MB, archive 225.0 MB | BL 2026-09-24 (portrait lock …) |
| Nunito Sans asset | 571,240 bytes | BL 2026-09-18 (app typography …) |

---

## 5. Bugs found and fixed

### 5.1 The five asked about

| Bug | Root cause (as recorded) | How it was caught | Source |
|---|---|---|---|
| **Paywall bypass: free users reached billed practice** (Review → weak spot → "Practice this"). | `launchPracticeSet` checked only the blanket daily cap. Entitlement was checked only as a navigation guard in Home's tap handlers; Review pushed the detail screen with no `SubscriptionService` in scope. No test file existed for either screen. | Device-verified bug report (free user, after "Maybe later"). It had been noted and deferred on 2026-09-05. | BL 2026-09-15 (free-tier "Practice this" leak …); BL 2026-09-05 (Home rebuilt …) |
| **Avatar grid reflow** when the last avatar in a row was selected. | `AvatarTile` wrapped the selected tile in extra border + padding, so it grew 5 px; the `Wrap` recomputed its line breaks. | Device-verified bug report; diagnosed before code changed. Fix: selection may never change a widget's footprint; grid replaced by a carousel. | BL 2026-09-15 (avatar picker: layout-bug diagnosis …) |
| **Daily Test explanation missing** on correct, skipped and unpredicted-wrong cards. | By design: grading is local and the set only carried comments for predicted wrong answers. This contradicted the App Store description ("you see why each answer was right or wrong"). | Diagnosis on 2026-09-24; the "Spot on…" text seen on a device turned out to be from Topic Practice. Fix: one explanation per question, generated in the same call. | BL 2026-09-24 (Daily Test: a per-question explanation); roadmap.md § Launch scope › Launch checklist, code items › "Daily Test explains every answer" |
| **Topic name repeated** ("…with Modal Past Forms in Modal Past Forms."). | A Daily Test mistake stores its topic id as the error type, and `humanizeSlug` turns it into exactly the topic title, so both template slots got the same value. `WeakSpotCard` had the same doubling fixed on 2026-09-05; this screen was missed. | Seen on a device. | BL 2026-09-24 (weak-spot detail: the topic name once); roadmap.md § Launch scope › Launch checklist, code items › "Weak-spot detail no longer repeats the topic name" |
| **`.DS_Store` files would ship inside the app.** | Flutter bundles every file in a registered asset folder; `.DS_Store` is gitignored, so only a build taken on a Mac that has them is affected. | Recorded as a known limit while adding the benefit icons; closed the same day by `scripts/preflight.sh` deleting them (it removed three). | BL 2026-09-23 (Premium offer card: benefit icons), (preflight removes `.DS_Store` …) |

### 5.2 Others with a recorded root cause

| Bug | Root cause | Caught by | Source |
|---|---|---|---|
| Daily Test crashed on every real generation. | Parser expected fields under an `item` key the schema never asked for. | First real API call; tests stubbed the service. | BL 2026-09-05 (continued) |
| App crashed opening the paywall. | Any `Purchases.*` call before `configure()` is a native `fatalError`, not a catchable Dart exception. | On-device verification on the simulator. | roadmap.md § Where we are now › Shipped › "Paywall screen built and reachable from Premium" (the bug paragraph) |
| Messages never went away. | A SnackBar with an action defaults `persist` to true; one app-wide `ScaffoldMessenger`. | A widget test that behaved inexplicably. | BL 2026-09-05 (message/error behavior …) |
| Turkish-keyboard letters graded as grammar mistakes. | Exact comparison; "same word, different keyboard" never considered. | Live verification on 2026-09-07. | BL 2026-09-07 (dev config reverted …) |
| Savings badge overstated (31% vs 30.44%). | Percentage computed from a truncated per-month price, then rounded up. | Real prices on a physical iPhone. | BL 2026-09-17 (Savings-badge fix …) |
| Any schema bump would wipe user data. | `onUpgrade` dropped and recreated every table on any version change. | Read-only verification of another branch's claims. | BL 2026-09-17 (Two pre-launch data-integrity fixes …) |
| Daily Test completion could double-log or lose mistakes. | Two independent, un-awaited writes. | Same verification pass. | BL 2026-09-17 (Two pre-launch data-integrity fixes …) |
| Premium vertical overlap. | Ordinary overflow tests only catch horizontal `RenderFlex` overflow. | On-device review. | BL 2026-09-16 (Two checks …); roadmap.md § Where we are now › Shipped › "2026-09-16 — Premium screen: on-device review fixes" |
| Day-0 climb did not animate. | The Day-0 flow ended before any Home existed, so Home had no earlier position to animate from. | Found on device. | BL 2026-09-21 (launch checklist: Day-0 climb animation) |
| Device id creation race. | Check-then-insert; overlapping first calls hit a UNIQUE error. | New tests for the preload. | BL 2026-09-22 (first Daily Test: preload …) |

---

## 6. Debts left on purpose

| Debt | Why it was left (as recorded) | Source |
|---|---|---|
| Premium comparison table does not show the daily session difference that the offer card promises. | Adding a row hides the plan cards at 375x667; fix by restructuring the table, not appending. | roadmap.md § Post-launch tasks › "Premium comparison table does not show the daily session limit" |
| Daily Test sets repeat topics and scenarios. | Same prompt for everyone; revisit with shared Daily Test generation. | roadmap.md § Post-launch tasks › "Daily Test sets repeat" |
| Shared Daily Test generation. | No users yet, no saving; decide after token-log data. | roadmap.md § Out of scope › "Shared Daily Test" |
| Unit economics unmeasured; token logs have no persistent storage. | Weeks of real traffic needed; Workers Analytics Engine recommended, not built. | roadmap.md § Launch scope › Launch checklist, code items › "Proxy token logging"; PRD2 §13.10 |
| GDPR Art. 27 EU representative not appointed. | Sole developer in Türkiye, EU not a primary market, pseudonymous data only. Revisit if EU users become material or EU marketing starts. | roadmap.md § Where we are now › Current wiring › "GDPR Art. 27 EU representative" |
| `hasFullAccess` swallows a RevenueCat failure and returns false. | Changing it changes the contract for every caller. | roadmap.md § Launch scope › Launch checklist, code items › "Premium offer card on the practice results screen" (known limit); BL 2026-09-23 (Premium prompt …) |
| Launch screen follows the system appearance, not the in-app theme. | iOS limitation noted as a known limit. | roadmap.md § Launch scope › Launch checklist, code items › "Submission prep" |
| `LaunchImage` placeholder build warning. | Invisible over the background color; not a blocker. | roadmap.md § Launch scope › Launch checklist, code items › "Build 2 (1.0.0+2)" |
| AOT release binary not inspected for debug-tool strings; empty `debug_settings` table still created. | Removing the table needs a schema change; the iOS binary check was blocked at the time and not done since. | roadmap.md § Launch scope › Launch checklist, code items › "Developer/debug tools out of release builds" |
| Premium plan cards at 375x667 need a scroll. | Only 393x852 was brought fully above the fold; to be checked on TestFlight. | roadmap.md § What's next › 1. Pre-launch checklist › "Open debt … plan cards don't clear the fixed footer at 375×667", roadmap.md § What's next › TestFlight pre-submission checklist |
| Spacing scale only partly adopted. | Foundation only; the rest of the app not migrated. | roadmap.md § What's next › 2. v2.2 › B-polish › "Introduce a spacing scale" |
| Developer-account membership address left incomplete. | Independent of DSA, not public, would need a certified translation for no benefit. | roadmap.md § Where we are now › Current wiring › "EU DSA"; BL 2026-09-16 (EU DSA …) |
| Daily Test error-profile entry does not store the new explanation. | Recorded as a possible follow-up, not part of the change. | BL 2026-09-24 (Daily Test: a per-question explanation) |
| Explanation word limit followed "mostly, not always" (5/25 over 25 words). | Nothing depends on length; owner's call, no further prompt change. | BL 2026-09-24 (… output measured …) |
| Out-of-scope launch items: mountain geometry, themes, final medal art, Home medal shortcut, v3 Home redesign, Turkish UI, theme toggle. | Each has its own recorded reason. | roadmap.md § Out of scope (after launch) |
| Pre-rewrite mirror backup `~/GrammarLens-backup.git`. | Kept until one week after launch, then deleted; never pushed. | roadmap.md § Post-launch tasks › "Delete ~/GrammarLens-backup.git" |
