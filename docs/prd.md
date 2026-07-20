# PRD — GrammarLens (working title)

**Version:** 0.1 (MVP)
**Author:** Ahmet Emin Tayfur
**Date:** July 2026
**Status:** Approved for build

---

## 1. Problem Statement

Many English learners became fluent through immersion — foreign friends, games, series — rather than formal study. Their grammar knowledge is *implicit*: they can produce mostly-correct sentences by feel, but they can't explain or reliably apply the underlying rules. Exams like IELTS demand *explicit* grammar accuracy, and this is where this segment gets stuck.

I am this user. Preparing for IELTS, my recurring weak spots are things like:

- **Gerund vs. infinitive** — knowing when it's "I enjoy *swimming*" vs. "I want *to swim*"
- **Modal verbs** — observed in my English course as well: classmates consistently struggle with modals
- **Modal past forms** — e.g. that *will → would* and *can → could* in past/reported contexts

The deeper problem isn't learning a rule once — it's **retention**. Two pain points from my own study routine:

1. I learn by writing things down, but rewriting the same material for revision kills motivation.
2. Fast-consumption AI practice (see §3) helps in the moment but fades quickly — weak long-term retention.

## 2. Target User

**Primary persona:** 20–30 years old, Turkish native speaker, B1–C1 English level, preparing for an exam (IELTS/TOEFL) or professional English requirement. Learned English informally (conversation, media), so speaking fluency exceeds explicit grammar accuracy. Studies roughly 1 hour/day; realistic in-app attention span is a 10–15 minute focused session, not the full hour.

**Initial validation:** Beyond my own experience, classmates in my English course show the same pattern (e.g. widespread difficulty with modal verbs). Structured interviews with 3–5 of them are planned during the build week and will be added to this document.

## 3. Current Alternatives & Why They Fall Short

**Beginner apps (Duolingo etc.):** Start too low, progress too slowly for a B1+ user. Not targeted at specific weak topics.

**Grammar books / handwriting notes:** Effective for first-pass learning (writing helps me memorize) but revision requires rewriting — tedious and demotivating.

**General LLM chat (my Gemini experiment):** I fed Gemini a topic plus vocabulary I'd collected; it generated a test, scored my answers, and produced an error report. This worked well as *reinforcement* — but it was fast consumption with weak retention, required manual setup every session, and kept no memory of my error history across sessions.

**Private tutoring:** Personalized but expensive; not a daily-practice tool.

**The gap:** No tool combines *topic-targeted practice generation* + *instant scoring with error explanation* + *a persistent error profile that drives spaced, regenerated review*. That combination is only possible with an LLM — which is why this is an AI-first product, not an AI-flavored one.

## 4. Solution — Core Loop

1. **Pick a topic** (e.g. Gerund vs. Infinitive, Modal Verbs) from a curated list.
2. **App generates a fresh practice set** via LLM: a short mix of fill-in-the-blank, error-correction, and 1–2 sentence-writing items (structured JSON output).
3. **User answers** in-app; LLM **scores instantly** and returns an **error report**: what was wrong → which rule applies → corrected version → short explanation.
4. Mistakes are written to a local **error profile** (topic × error type × frequency).
5. **Review tab:** the app resurfaces the user's weak spots on later days with *newly generated* questions targeting the same error types — revision without rewriting, repetition without repeating content.

Step 5 is the differentiator. Static apps rotate a fixed question bank; generic LLM chat forgets you between sessions. GrammarLens remembers *your* error patterns and regenerates fresh practice around them.

## 5. MVP Scope

**In scope:**

- Topic list (starting set: Gerund vs. Infinitive, Modal Verbs, Modal Past Forms, Tense Selection, Articles)
- LLM-generated practice sets (structured JSON; fill-in-blank, error correction, sentence writing)
- Instant scoring + error report screen
- Local error profile (on-device storage; no accounts)
- Review tab driven by the error profile
- Single language pair: Turkish → English

**Deliberately out of scope (v2 candidates):**

- Speech/audio features — different problem, heavy integration cost
- Gamification, streaks, leagues — retention should first come from usefulness
- Placement/level testing — user self-selects topics in MVP
- Accounts & cloud sync — local storage is enough to validate the loop
- Multiple language pairs — depth before breadth

## 6. Success Criteria (prototype)

- 5+ real testers (English-course classmates) complete at least one full loop (topic → practice → error report)
- Qualitative: testers rate the error report as genuinely useful (would they use it before an exam?)
- At least one tester returns to the Review tab on a later day unprompted
- At least one meaningful iteration shipped based on tester feedback, documented in the repo

## 7. Technical Notes

- **Client:** Flutter (iOS simulator first; physical iPhone testing if time allows)
- **AI:** Anthropic API with structured JSON outputs for both set generation and scoring
- **Storage:** Local (shared_preferences / SQLite — decided during build)
- **Development:** AI-assisted via Claude Code; process documented publicly in this repo

## 8. Timeline (1-week sprint)

| Day | Goal |
|-----|------|
| 1 | PRD committed; project skeleton generated; topic list + first LLM prompt working |
| 2–3 | Core loop v1: topic → generated set → answering UI → scoring + error report |
| 4 | Error profile + Review tab |
| 5 | User testing with classmates; collect feedback |
| 6 | Iteration + polish |
| 7 | README update, screen recordings, Medium draft, LinkedIn post |

---

*This document is a living artifact — user research findings and iteration decisions will be appended as they happen.*
