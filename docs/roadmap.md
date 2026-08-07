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

**Documentation**
- `docs/prd.md` — problem, personas, interview findings (§2.1), scope decisions
- `docs/build-log.md` — chronological record of decisions and bugs
- `README.md` — product overview, screenshots, key product decisions
- Public write-up on Medium

---

## What's next

### 1. Empty states (small, do first)
Screens currently show nothing when there's no data yet. A new user opening
Review sees a blank screen with no explanation.

- Review with no weak spots → icon + "No weak spots yet. Practice a topic and
  your mistakes will show up here." + CTA to start practicing
- Any other screen that can render empty (check results/detail paths)
- First-run state on home if it reads as empty

### 2. Real user testing (highest portfolio value)
The one unchecked box in the README. Everything else is self-assessment.

- 5+ testers from the English course
- Watch them use it in person rather than sending a link — observe where they
  hesitate, what they expect, what they misread
- Capture: where they got stuck, what they said out loud, whether they'd use
  it again before an exam
- Write findings into `docs/prd.md` as a testing section, same format as the
  interview findings

### 3. Iteration 3 (driven by testing, not by taste)
Scope defined *after* testing, not before. Likely candidates based on what
testing usually surfaces: onboarding/first-run clarity, question wording,
feedback length, session length defaults.

### 4. Make it try-able
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
- Word-form / inflection question type (drafted, deliberately postponed)
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
