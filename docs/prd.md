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

**Initial validation:** Beyond my own experience, classmates in my English course show the same pattern (e.g. widespread difficulty with modal verbs). See §2.1 for findings from four interviews conducted during the build week.

## 2.1 Interview Findings

Short informal interviews with four English learners (three classmates from my English course, plus a self-interview — see note below). All are fluent-but-informal speakers preparing for or affected by IELTS requirements. Findings below are paraphrased summaries of what participants reported, not verbatim transcripts.

**Participants**

| ID | Profile | Background |
|----|---------|------------|
| P1 | 24, university student | Learned English through games and Discord; strong accent and fluency, weak academic writing |
| P2 | 27, digital marketing specialist | Erasmus experience, learned via media; wide vocabulary, struggles with IELTS grammar criteria |
| P3 | 29, sales specialist | Uses English daily at work; high confidence, unaware of his own recurring errors |
| P4 | 25, recent graduate | Intuitive speaker; IELTS preparation triggered overthinking that disrupted natural fluency |

**Note on P4:** P4 is the author of this document (self-interview). Included deliberately — I am within the target segment — and flagged here for transparency.

### Theme 1 — Fluency without explicit rule knowledge

All four participants can communicate comfortably but cannot name or apply the rules behind what they produce. P1 reported being told repeatedly about tense inconsistency in IELTS writing (starting a sentence in present, ending in past) and having essentially no working model of English punctuation. P4 described knowing structures intuitively but freezing once forced to identify them by name.

*Confirms the core problem statement in §1.*

### Theme 2 — Grammar terminology is a barrier, not a help

P1 reported that being told to "use Past Perfect Continuous" is meaningless to him even though he uses the structure daily. P4 reported that explanations referencing terms like "noun clause" are harder to parse than the mistake itself. Both prefer feedback phrased as "this sounds more natural" over rule-based correction.

*Challenges the current UI: GrammarLens surfaces rule names (e.g. "Gerund vs. Infinitive") as primary labels.*

### Theme 3 — Multiple-choice and fill-in-the-blank practice feels useless

P1 reported that gap-fill exercises frustrate him because real communication never presents blanks with options. P2 reported that selecting answers doesn't improve her English since comprehension isn't her problem — production is. P3 avoids structured grammar study entirely and only does mock tests.

*Direct tension with the MVP's current question mix, which is majority fill-in-the-blank and error-correction.*

### Theme 4 — Demand for personalized error statistics

P3's stated ideal tool tracks his chronic mistakes and reports their frequency (e.g. how often he drops third-person -s, or substitutes simple past for present perfect) without teaching rules at all. P2 wants to be pushed beyond her habitual sentence patterns rather than just corrected.

*Strongly validates the error-profile and Review features — the product's main differentiator.*

### Theme 5 — Correction timing and tone affect willingness to practice

P4 reported that real-time correction during speaking damages confidence and disrupts flow, preferring a summary after finishing. P2 reported that beginner-level apps feel condescending to advanced learners.

*Implication: feedback should arrive after completion (as it currently does) and should never be pitched at beginner level.*

### Tensions and surprises

1. **The strongest validation and the strongest challenge came from the same segment.** Participants want personalized error tracking (Theme 4 — what GrammarLens does well) but reject the exercise format used to collect that data (Theme 3 — what GrammarLens currently relies on).
2. **Rule names may be a liability.** The MVP treats rule identification as a feature; two participants treat grammar terminology as an obstacle.
3. **P3 denies having a grammar problem while describing several.** Self-reported weak spots are unreliable — supporting the case for a system that detects errors from actual output rather than asking users what they struggle with.

### Implications for Iteration 2 (candidates, not commitments)

- Shift the question mix toward free production (sentence/short-paragraph writing) and reduce gap-fill weight
- Present feedback in plain language first, with the rule name as secondary/optional detail
- Consider surfacing error frequency statistics more prominently in Review, since this was the most requested feature

## 2.2 Usability Testing Findings (Round 1)

Structured usability tests with three participants (T1–T3), distinct from the
§2.1 interview participants (P1–P4), same target segment (informally-fluent,
IELTS/TOEFL-prep). Each completed the full core loop — topic selection →
practice → error report → Review — using a think-aloud protocol, followed by
a short structured interview. Sessions were captured live and reorganized
into a template with AI assistance; quotes below are paraphrased and
reorganized, not verbatim transcripts, consistent with the treatment of §2.1.

**Sample size note:** target for this round was 5+ testers (§6 Success
Criteria); proceeding with 3 was a deliberate scope decision made mid-round,
not an oversight. Several findings below are supported by a single
participant and are flagged as such — read them as directional, not
saturated.

**Participants**

| ID | Profile | Background |
|----|---------|------------|
| T1 | 23, architecture graduate student, IELTS Academic (target band 7.0) | Informal learner (shows, YouTube, games); fluent speaking, struggles with grammar in academic writing |
| T2 | 27, software developer, TOEFL (target 100+) | Learned through work and technical reading; comfortable speaking, confuses tenses in complex sentences |
| T3 | 22, business undergraduate, IELTS (Erasmus application) | Learned via school and foreign shows; high confidence, practices casually with peers |

### Theme 1 — Multiple-choice format rejected outright

Asked directly whether they'd prefer selecting answers from options instead
of producing them, all three rejected the idea unprompted and independently.
T1: "would be boring and artificial — constructing the sentence myself
without options is far more useful." T2: "that would make it just another
ordinary test app — being productive is more instructive." T3: "if there
were options I'd just gamble; without them I actually had to prove I knew
it."

*Confirms and strengthens §2.1 Theme 3 (P1, P2 also rejected gap-fill/MC).
Combined across both rounds, 5 of 7 people interviewed reject multiple-choice
as a practice format. This closes the "word-form (V1/V2/V3) multiple-choice"
concept discussed as a candidate iteration — if a word-form topic is added,
it should use the existing production-based question types, not a new MC
mechanic.*

### Theme 2 — Mobile input friction during production tasks

T1 hit a moment where the on-screen keyboard covered the "Next" button on a
sentence-writing question and had to scroll to find it. T2 separately found
typing full corrected sentences on mobile "a bit tiring" for longer items and
suggested being able to submit just the corrected fragment.

*Two independent reports pointing at the same general area (long-form typing
on a phone keyboard), though the specific complaints differ. The first part
(keyboard covering the button) is a low-cost UI fix. The second (partial-
answer submission) risks reopening the "graded on the fix, not the format"
decision already made in Iteration 2 (build-log, 2026-07-24) — needs its own
decision, not a quick patch.*

### Theme 3 — Uncertainty about where to start (single participant)

T1 hesitated roughly 15–20 seconds on the topic selection screen, looked for
a "Start" or "assess my level" entry point, and later said: "I wish the app
gave me a mixed 10-question test upfront to point me somewhere." T2 and T3
did not report this when asked directly — T2's uncertainty was unrelated
(see Theme 4), and T3 answered "no" outright.

*Correction: an earlier draft of these session notes attributed this finding
to both T1 and T2. T2's own answer to the direct question ("didn't happen
when choosing the topic") contradicts that — corrected here to a
single-participant finding.*

*Distinct from the "random topic picker" idea discussed earlier (which read
as gamification, already out of scope per §5) — T1 is describing a
diagnostic/placement mechanism, not a randomizer. This reopens a decision §5
deliberately deferred ("Placement/level testing — out of scope, v2
candidate"). One data point isn't enough to reverse that decision, but worth
watching for in future rounds.*

### Theme 4 — Anxiety about typo vs. grammar-error distinction (single participant, unconfirmed)

T2 raised a hypothetical concern mid-session: "what if I make a typo and the
system reads it as a grammar mistake?" No actual typo-related misgrading
occurred during the session — this was a stated worry, not an observed
failure.

*Not confirmed as a real defect. Verify by deliberately testing typo input
against the current scoring prompt before treating this as an engineering
task.*

### Theme 5 — Review tab low visibility (single participant)

T1 needed to be redirected to the Review tab after finishing the error
report, describing the icon as "faded, didn't catch my attention at all." T2
and T3 both navigated to Review unprompted.

*Weak signal (1 of 3) against 2 of 3 finding it without help — lower
priority than Theme 2.*

### Theme 6 — Desire for positive micro-feedback (single participant)

T3, after a correct answer produced only a plain green checkmark, said: "a
sound or a small congratulatory animation wouldn't hurt — it felt very
'exam-like.'"

*Distinct from the gamification concepts (streaks, leagues, random wheel)
already ruled out of MVP scope in §5 — this is a request for lightweight
feedback on individual answers, not a game mechanic. Single data point; a
cheap backlog candidate, not an immediate action.*

### Theme 7 — Core value proposition strongly reconfirmed

All three, without prompting, specifically praised the plain-language
explanations over rule/terminology-first feedback. T1: "it didn't just state
the rule — it said 'you're talking about a missed opportunity in the past,
so you need past-tense modals,' like a person would." T2: "it says 'the
action started in the past and is still going' instead of naming 'Present
Perfect Continuous' — it gives you the logic." T3: "the explanations don't
make me memorize rules like school did."

*Strongest, most consistent finding across both research rounds (§2.1 Theme
2 and this round). No action needed — validates keeping the Iteration 2
direction (plain-language first, rule name secondary) as-is.*

### Implications for next iteration (candidates, not commitments)

- Keyboard-aware padding on production question screens (Theme 2) — low
  cost, two-participant evidence, good first candidate
- Formal decision against the MC-based word-form category as originally
  conceived (Theme 1) — if a word-form topic is still wanted, scope it as
  production-based like existing topics
- Verify (don't yet fix) typo-vs-grammar scoring behavior before any prompt
  change (Theme 4)
- Placement/diagnostic test concept (Theme 3) reopens a deliberately-deferred
  §5 decision — single data point, watch for repetition in future rounds
  rather than building now
- Review tab visibility (Theme 5) and micro-feedback on correct answers
  (Theme 6) — low priority, single-participant, cheap backlog candidates

---

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
