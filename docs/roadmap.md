# GrammarLens — Roadmap & Status

**Purpose of this file:** single source of truth for where the project stands.
Read this first in any new working session (chat or Claude Code) to get context
without re-explaining history.

**Last updated:** 2026-08-24

---

## Why this project exists

Personal product case study — building product management capability by
actually shipping something, and creating a portfolio piece that demonstrates
end-to-end product thinking (research → definition → build → iteration → learning),
not just a finished app.

Originally started during a job application process. That process ended, the
product continues.

---

## Where we are now

**Status: MVP complete, tested with real users, closed. V2 in definition —
see `docs/prd-v2.md`.**

### Shipped

**Core product**
- Topic selection → session length (Quick 3 / Standard 5 / Extended 10)
- One-question-at-a-time flow with progress bar, Back / Skip-Next, exit confirmation
- Mixed question types: sentence writing, error correction, fill-in-the-blank
- LLM-generated question sets (Claude Sonnet, structured JSON)
- Batch evaluation at the end → Results screen
- Plain-language feedback with grammar rule as secondary caption
- Deterministic skipped-answer handling (empty ≠ wrong)
- Error profile stored locally (sqflite), fed by every session
- Review tab: weak spots with frequency/recency stats, sortable
- Weak-spot detail screen → summary of past mistakes → targeted fresh practice

**Design**
- Material 3, custom identity: orange primary / deep blue accent
- Light mode (orange background) + dark mode (neutral dark, orange accents)
- Animated bottom nav, full-screen loading states, semantic result colors
- Per-topic icons, home cards showing personal progress stats
- Responsive sizing, no hardcoded pixel values
- Empty states: shared `EmptyState` widget (icon + title/description + optional
  CTA); Review's no-weak-spots state now has a "Start practicing" CTA, and
  weak-spot detail's empty mistake list uses the same icon+text pattern
- Keyboard-aware bottom button on practice questions: the primary
  Skip/Next/Submit button now stays pinned above the on-screen keyboard on
  every free-text question type (fill-in-the-blank, error correction,
  sentence writing), instead of sitting behind it. Answers the T1 finding in
  `docs/prd.md` §2.2 Theme 2. Two follow-up fixes from testing this on a real
  device: the question header (context/instruction/hint) now lives in its
  own scroll region, separate from the answer field, so it no longer gets
  dragged half off screen by the keyboard's "scroll the focused field into
  view" behavior; and tapping anywhere outside the field dismisses the
  keyboard, not just its own "Done" key

**Documentation**
- `docs/prd.md` — MVP: problem, personas, interview findings (§2.1), usability
  testing findings (§2.2), scope decisions
- `docs/prd-v2.md` — v2 scope, evidence-vs-bet labeling, screen architecture,
  open decisions
- `docs/build-log.md` — chronological record of decisions and bugs
- `README.md` — product overview, screenshots, key product decisions
- Public write-up on Medium

**User research**
- 3-participant usability testing (T1–T3), full core loop, think-aloud +
  structured questions. Below the original 5+ target — proceeding with 3 was
  a deliberate call, not an oversight; findings weighted accordingly (see
  `docs/prd.md` §2.2 for the sample-size note and per-theme evidence
  strength). Headline results: plain-language feedback strongly reconfirmed
  (3/3, consistent with §2.1 Theme 2); multiple-choice question format
  rejected outright (3/3, consistent with §2.1 Theme 3) — closes the
  MC-based word-form category as a candidate

**V2 Phase 1 — Onboarding + Home + Settings** (`docs/prd-v2.md` §4, §5, §10)
- First-launch flow: one-sentence Welcome/value intro → two-field onboarding
  (name + learning goal only — age/occupation deliberately deferred, see the
  onboarding screen's doc comment). Guest-first, no signup: the profile
  saves straight to the existing local sqlite store, and its presence is
  what "onboarding complete" means — returning launches skip straight to
  Home
- Home replaced: was the topic list, now mode selection with a personalized
  greeting ("Welcome back, {name}") and three mode cards — Topic Practice
  (active, opens the unchanged MVP loop, now its own TopicPracticeScreen),
  Streak Mode and Voice Practice (not built yet; tapping either is
  informative rather than a dead disabled card)
- Settings screen, new: theme (proper light/dark/system, replacing the old
  quick toggle), name edit, optional age/occupation fields, and a "reset
  progress" action — scoped to practice history only, keeps the guest
  identity intact
- Bottom nav: three tabs now (Home / Review / Settings)

**V2 Phase 1 — revision round**, three fixes found testing the above on a
real device:
- Onboarding: centered text/labels (was left-aligned); the learning-goal
  option cards were unreadable in light mode (transparent fill on the vivid
  orange page, faint border) — now use an explicit surface color and a
  stronger border, light mode only, dark mode left untouched
- Streak/Voice "coming soon" messaging moved off the app-wide SnackBar
  (which queued on repeat taps and kept showing after navigating away,
  since it lives above the Navigator) onto a proper modal `showDialog`,
  matching the app's existing confirm-dialog look
- Home's mode cards: vertical list → 2-column grid, room to grow into more
  modes without a layout rethink

**V2 Phase 2 — Premium / early-access screen** (`docs/prd-v2.md` §6, §10 item 2)
- New `PremiumScreen`, reached from a fourth Home mode card ("Early
  Access", fills out the 2×2 grid alongside Topic Practice / Streak Mode /
  Voice Practice). Informational only, per §6: no payment flow, no price,
  no buy button anywhere on it
- Content: the required framing line ("You're one of our first users —
  everything is free while we're in early access") plus a short list of
  what premium will include — unlimited Streak Mode, AI Voice Practice —
  each tagged "Coming soon" since neither feature exists yet either.
  Deliberately did not say "free forever" or unqualified "free" (§6:
  becomes a constraint once real pricing ships)
- Verified in both themes on the iOS simulator via a temporary,
  untracked debug-harness entry point (same technique as Phase 1 — direct
  render, no tap automation), deleted after use

---

## What's next

**MVP is closed. Work continues in v2 — see `docs/prd-v2.md`.**

### Decision: "make the MVP try-able" dropped (2026-08-24)
The previous next-item was distributing the MVP build so people could try it.
Dropped in favor of going public with v2 instead: seven people have already
used the core loop in person, and another small private round would mostly
repeat what we know. A public launch is the more useful test, and it needs
what a bare practice loop lacks — a reason to return, an identity, a
commercial frame. Recorded as a deliberate reversal, not silent drift.

**Decision (2026-08-24): lean launch.** Public launch now comes *before*
streak mode, not after — see `docs/prd-v2.md` §10 for the reasoning
(launching exists to get real retention signal on the validated core loop;
building a zero-evidence bet before measuring that defeats the point).

### 1. Pre-launch checklist
See `docs/prd-v2.md` §10.1 — distribution channel decision, API key safety
approach, minimal retention measurement, device coverage, feedback channel,
privacy note. Several of these are still open decisions, not just tasks.

### 2. Public launch
Topic mode + onboarding + premium teaser only. No streak mode yet.

### 3. Streak mode (post-launch fast-follow)
Built after real D1/D7 data exists, not before. Carries the open cost
decision (`docs/prd-v2.md` §7.1). Instrument per-session token usage while
building it.

### 4. Rewarded video gate on streak (free tier)

### 5. Cost measurement, resolve open decisions §7.1 / §7.2

### Later phases (post-v2)
Accounts + backend → social / competition → AI voice practice mode.

### Carried over from MVP Iteration 3 (unscheduled, absorbed into v2 work)
- Review tab icon visibility — single-participant, low priority; the new Home
  and post-results navigation in v2 may make this moot
- Positive micro-feedback on answering — single-participant; overlaps with
  streak mode's feedback design
- Placement/diagnostic test — partially addressed by v2's onboarding
  "learning goal" question feeding topic suggestions
- Partial-answer submission for error-correction on mobile — still tension
  with "graded on the fix, not the format" (build-log, 2026-07-24); needs its
  own product decision
- ~~Verify whether typos get misgraded as grammar errors~~ — checked
  2026-08-24, no issue found, no prompt change needed

---

## Backlog (not scheduled)

- Per-question instant feedback instead of batch evaluation (costs ~5x more
  LLM calls — evaluate against value before doing it)
- Word-form / inflection question type — MC version rejected (5 of 7 tested
  users across both research rounds reject multiple-choice, see `docs/prd.md`
  §2.2 Theme 1); if revisited, must use existing production-based question
  types
- Spaced repetition scheduling for weak spots (currently recency/frequency only)
- More topics beyond the initial five
- Accounts + cloud sync (out of scope for MVP by design)
- Custom loading animations
- Turkish UI option (currently English-only interface)

---

## Working principles (carried forward)

- **No fake it.** Nothing in the repo, README, or write-ups claims work that
  wasn't done. Unfinished items stay unchecked.
- **Decisions before code.** Every meaningful change is written down with its
  reason — that record is the actual portfolio value, more than the code.
- **Small commits.** One coherent change per commit so problems stay isolated.
- **User feedback beats taste.** Changes driven by what users did, not what
  looked nicer in the moment.
- **Deterministic where possible.** Don't ask the model for things the code
  can know for certain.

---

## Session workflow

To resume work in a new session:
1. Read this file + `docs/build-log.md`
2. Pick the next item from "What's next"
3. Work in small batches, test on the iOS simulator, commit each batch
4. Update this file when a section is completed
