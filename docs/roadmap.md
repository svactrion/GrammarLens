# GrammarLens — Roadmap & Status

**Purpose of this file:** single source of truth for where the project stands.
Read this first in any new working session (chat or Claude Code) to get context
without re-explaining history.

**Last updated:** August 2026

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

**Status: MVP complete and polished, not yet tested with real users.**

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
  `docs/prd.md` §2.2 Theme 2

**Documentation**
- `docs/prd.md` — problem, personas, interview findings (§2.1), usability
  testing findings (§2.2), scope decisions
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

---

## What's next

### 1. Iteration 3 (driven by testing, not by taste)
Candidates from `docs/prd.md` §2.2, in priority order:

- Verify (don't yet fix) whether typos get misgraded as grammar errors —
  single-participant concern, unconfirmed, check before touching the scoring
  prompt
- Review tab icon visibility — single-participant, low priority
- Small positive micro-feedback on correct answers (sound/animation) —
  single-participant, cheap if pursued, not urgent
- Placement/diagnostic test at first launch — single participant asked for
  this; reopens a decision deliberately deferred in §5. Don't build off one
  data point — watch for repetition in future testing rounds
- Partial-answer submission for error-correction on mobile — tension with
  the existing "graded on the fix, not the format" decision (build-log,
  2026-07-24); needs its own product decision, not a quick patch

### 2. Make it try-able
Right now it only runs on the developer machine, so nobody can experience it.

Options to evaluate:
- Web build deployed to free hosting (fastest, but exposes API key in browser —
  acceptable only with a limited/disposable key)
- TestFlight (proper iOS distribution, requires Apple Developer account, $99/yr)
- Screen-recorded demo video (no distribution, but linkable everywhere)

Decision pending — depends on whether the goal is "people actually use it" or
"people can see it working."

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
