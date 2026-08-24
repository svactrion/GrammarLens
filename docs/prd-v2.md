# PRD v2 — GrammarLens

**Version:** 2.0 (draft)
**Author:** Ahmet Emin Tayfur
**Date:** August 2026
**Status:** Draft — scope agreed, open decisions listed in §7
**Supersedes:** nothing. `prd.md` (v0.1 MVP) stays as the historical record of
the MVP's problem definition, user research, and scope decisions. This
document covers what comes after it.

---

## 1. Why v2, and what changed

The MVP validated its core hypothesis. Across two research rounds (four
interviews in `prd.md` §2.1, three usability tests in §2.2), the strongest and
most repeated finding was that plain-language, personalized error feedback is
genuinely valued — all three usability testers praised it unprompted, and it
was the one thing nobody criticized in either round.

What the MVP did *not* establish is whether anyone comes back. Retention was
never measured, because the MVP never left the developer machine.

**Decision: skip "make the MVP try-able," go public with v2 instead.**
The MVP roadmap's next item was distributing the current build so people could
try it. That is now dropped. Rationale: seven people have already used or
discussed the core loop in person; another small private round would repeat
what we know. The more valuable test is a public one — and a public launch
needs the things a bare practice loop doesn't have (a reason to return, an
identity, a sense that the product is going somewhere). Those are v2.

This is a deliberate reversal of a documented plan, recorded here rather than
made silently.

---

## 2. What v2 is

A single-player grammar practice tool becomes a product with a reason to open
it daily:

- **Two practice modes** instead of one — the existing topic-based deep
  practice, plus a fast streak mode
- **A user identity** — lightweight onboarding, a name, personalization
- **A commercial frame** — users understand this will be a paid product, and
  that they're getting it free right now
- **Room for social** — a data model that doesn't have to be rebuilt when
  friend comparison and competition arrive

## 3. Evidence status — read this before building anything

This is the most important section of this document for anyone (including
future me) evaluating these decisions.

The MVP's features traced back to user research. **Most of v2's do not.** That
is a legitimate way to build — not every feature can wait for a user to
request it, and users rarely ask for things they haven't seen. But it must be
labeled honestly, because a bet that gets described as a research finding
corrupts every decision made downstream from it.

### Backed by research

| Feature | Evidence |
|---|---|
| Onboarding "why are you learning English" question feeding topic suggestions | T1 hesitated on topic selection and asked for guidance on where to start (§2.2 Theme 3). Single participant — directional, not saturated |
| Keeping plain-language feedback as the core of topic mode | 3/3 usability testers, consistent with §2.1 Theme 2. Strongest finding in the project |
| Some form of positive feedback on answering | T3 found the app "very exam-like" and wanted small acknowledgment (§2.2 Theme 6). Single participant |
| No multiple-choice question format anywhere in v2 | 5 of 7 people across both rounds rejected MC/gap-fill (§2.2 Theme 1, §2.1 Theme 3). This is the one thing v2 must not do |

### Deliberate bets — zero user evidence

Nobody in either research round asked for any of the following. They are
product bets based on category patterns and strategy, to be validated after
launch, not before:

- **Streak mode** — bet: a fast, low-friction mode creates a daily habit that
  deep practice alone doesn't
- **Accounts and social comparison** — bet: competing with friends drives
  return visits in this segment
- **Paywall framing before charging** — bet: signaling future paid status
  increases perceived value and urgency
- **Rewarded video to unlock streak runs** — bet: users accept a 30s ad for a
  free feature and it makes premium legible
- **AI voice practice mode** — bet: speaking practice is the premium-worthy
  feature. Note this reverses `prd.md` §5, which excluded speech as "a
  different problem, heavy integration cost." That reasoning still stands; the
  bet is that it's worth the cost as a paid differentiator

**Known tension to watch:** the validated core value is calm, unhurried,
mistake-focused learning. Streak mode is pressure, speed, and punishment for
error — and T3 already told us the app felt too exam-like. These two products
can coexist, but if streak mode starts shaping the tone of the whole app, v2
has damaged the one thing users actually praised. Post-launch, watch whether
streak users ever come back to topic mode, or whether the modes cannibalize
each other.

---

## 4. Screen architecture

```
First launch
  └─ Welcome / value intro
      └─ Onboarding (name + learning goal)
          └─ Home

Returning launch
  └─ Home

Home (mode selection, personalized greeting)
  ├─ Topic Practice  (existing MVP loop)
  ├─ Streak Mode     (new)
  ├─ Voice Practice  (premium — later phase, locked placeholder in v2)
  ├─ Review tab      (existing)
  ├─ Settings        (new)
  └─ Premium / early-access screen  (new)
```

### Home
Replaces the current topic-list-first home. Personalized greeting using the
onboarding name ("Welcome back, Ahmet"), then mode cards. Existing per-topic
progress stats move into topic mode's own screen rather than the top level.

### Onboarding
Two fields only: **name** and **learning goal** (exam prep / work / general).
Age and occupation are deliberately deferred to Settings or a later prompt.

*Rationale:* every field asked before the user has experienced value costs
completions, and this is an unknown app. Name earns its place by powering
personalization; learning goal earns its place by feeding topic suggestions —
which partially answers T1's "I don't know where to start." Age and occupation
are currently marketing data only, with no in-product use, so they don't
justify their friction yet.

### Settings
Does not exist today. Minimum: theme (light/dark/system), name edit, data
reset (currently only possible by deleting the app), and optional profile
fields (age, occupation) for users who want to fill them in.

### Premium / early-access screen
Shows what premium will include and states clearly that it's free right now.
**No payment flow in v2.** See §6.

---

## 5. Account model — guest-first

**Decision: guest-first, account optional.**

Onboarding does not require signup. The user enters a name, picks a goal, and
starts practicing immediately. Data stays local (existing sqflite error
profile). An account is only required for features that genuinely need a
server: friend comparison, competition, cross-device sync.

*Rationale:* requiring registration before any value is delivered is the
single most expensive thing a new app can do to its funnel, and this app has
no brand recognition to spend. Guest-first also means streak mode, onboarding,
personalization and the paywall screen can all ship without standing up
backend infrastructure — the largest and least reversible cost in v2.

*Consequence to accept:* until an account exists, uninstalling loses the error
profile and streak history. Acceptable during early access; becomes a real
retention problem once users have meaningful history, which is the natural
trigger for adding accounts.

---

## 6. Monetization framing (v2 = signal only, no revenue)

**Paywall screen with no payment flow.** The screen presents premium features
and positions current access as free early-access.

Copy direction — say "free during early access," **not** "free" or "free
forever." An unbounded promise made now becomes a constraint when pricing
actually launches. Framing that gives the user standing without over-promising:
*"You're one of our first users — everything is free while we're in early
access."*

**Rewarded video to start a streak run (free tier).** Free users watch a ~30s
rewarded video before a streak run; premium starts immediately.

*Note on the economics:* banner advertising cannot cover LLM inference costs
at any realistic impression volume for an app this size — rewarded video is
the only format where the math works at all, which is why it's the format
chosen. But at early user counts, ad revenue is not the point; bounding cost
is. The video gate's real function in v2 is making the premium value
proposition legible, not funding inference.

**Explicitly not in v2:** payment processing, subscription management, pricing
decisions, refunds. Those come when there's usage data to price against.

---

## 7. Open decisions

Recorded as open, with options, rather than decided by default.

### 7.1 Streak mode evaluation — how do we know an answer is correct?

Streak mode has to end the streak the moment an answer is wrong, which means
per-answer evaluation. The MVP evaluates in a batch at the end of a session
specifically to avoid this cost (roadmap backlog: "~5x more LLM calls").

| Option | Cost | Trade-off |
|---|---|---|
| Per-answer LLM call, Haiku | Low — a short verify call is a fraction of a cent; a 20-question run is roughly a cent | Fresh, generated questions; Haiku is well-matched to "is this right or wrong," which is far simpler than generating personalized explanations |
| Per-answer LLM call, Sonnet | ~2x Haiku | Only worth it if streak answers need real feedback, which arguably defeats the mode's speed |
| Pre-generated pool + deterministic checking in code | Near zero | Cheapest and instant, but questions repeat and lose the "always fresh" property that differentiates the product |

**Leaning:** Haiku for verification, Sonnet reserved for topic mode's feedback
— the actual differentiator. **Decision deferred to end of v2**, to be made
against measured cost-per-session rather than estimates.

**Prerequisite:** instrument token usage per session so this decision is made
on a real number.

### 7.2 Free-tier usage cap

A daily cap on free sessions would bound inference cost and give the premium
tier a natural shape. Not yet decided — needs the cost measurement from 7.1
first. If adopted, it should be the primary free/premium boundary rather than
inventing an artificial one later.

### 7.3 Streak content selection

"Random questions" was the initial idea. Alternative: draw from the user's own
error profile, which would connect streak mode to the validated
personalization value instead of running parallel to it. Unresolved — random
is simpler, error-profile-driven is more consistent with what users praised.

---

## 7.4 Infrastructure sequencing (rejected-for-now stack proposal)

A separate AI tool was asked to propose a production stack for this project
without visibility into this document — it recommended Supabase, RevenueCat,
PostHog, OneSignal, and Firebase Crashlytics, plus a Clean
Architecture/MVVM restructure and an ASO keyword strategy, all up front. None
of it traces to anything in §3's evidence table; it's generic "freemium app"
best practice, not GrammarLens-specific. Recorded here so the reasoning for
not doing this now isn't lost if the same proposal resurfaces.

| Tool | What it's for | Why not now | Right time |
|---|---|---|---|
| Supabase | Backend, DB, auth | Directly contradicts §5's guest-first decision, made deliberately to avoid standing up backend infra before it's needed | Post-v2, when accounts/social genuinely require a server (see §10 "Later phases") |
| RevenueCat | Subscription/IAP management | §6 explicitly excludes payment processing from v2 | Once a real pricing decision is made, after early-access data exists — likely post-launch |
| PostHog | Product analytics, paywall funnels | No traffic yet to analyze; would be tracking empty channels | Phase 6 (public launch) — this one does map to a real need, §9's success criteria (onboarding completion, D1/D7 retention, mode split) require *some* event tracking, so revisit vendor choice then rather than defaulting to PostHog now |
| OneSignal | Push notifications (streak-break reminders) | Not just premature — in tension with the validated value prop. §3 already flags that streak mode risks pushing the app toward pressure/exam-like feeling (T3's complaint); a "your streak is dying" push is that risk in its most direct form. Building the retention mechanic before the mode it retains users into even exists, and before knowing whether streak mode itself damages the calm/mistake-focused core, is backwards | After streak mode ships and its usage data is visible — and even then, reconsider the framing (not punitive) before defaulting to streak-break alerts |
| Firebase Crashlytics | Crash reporting | Lowest-risk of the five, but no urgency — single-developer testing on a simulator sees crashes directly | Reasonable to add around Phase 6 when usage moves outside the developer's own machine |
| Clean Architecture / MVVM restructure | Folder structure to modularly fit the above | Speculative generality — restructuring around five integrations none of which are being built yet | Introduce structure incrementally as each integration actually lands, not ahead of it |
| ASO / AppTweak keyword strategy | Store listing optimization | No store distribution channel has been decided yet | Right before actual store submission, once a distribution decision is made |

---

## 8. Out of scope for v2

- Payment processing and pricing (see §6)
- Friend comparison, leaderboards, competition modes — depend on accounts and
  a backend; v2's job is to not block them
- AI voice practice — premium placeholder only in v2; built in a later phase
- Multiple language pairs
- Spaced repetition scheduling (still in backlog from MVP)

---

## 9. Success criteria

The MVP's criteria were qualitative because it had no users. V2 launches
publicly, so these are measurable:

- **Onboarding completion rate** — what share of first launches reach Home
- **Day-1 / Day-7 return rate** — the retention question the MVP could never
  answer
- **Mode split** — do users adopt streak mode, topic mode, or both? If streak
  users never touch topic mode, the tension flagged in §3 is real
- **Streak mode's effect on topic mode** — complement or cannibalization
- **Qualitative:** does the plain-language feedback still get praised once
  users arrive without a researcher sitting next to them?

---

## 10. Sequencing

Ordered by dependency and risk, not excitement:

1. **Onboarding + Home + Settings** — no backend, no new LLM cost, unblocks
   personalization and the new navigation
2. **Premium / early-access screen** — a screen with copy; cheap, and it makes
   the commercial frame real before any mechanic depends on it
3. **Streak mode** — the largest new surface, and the one carrying the open
   cost decision. Instrument token usage here
4. **Rewarded video gate** — after streak mode exists to gate
5. **Cost measurement + decisions 7.1 / 7.2** — with real numbers
6. **Public launch**
7. *(Later phases)* accounts + backend → social/competition → AI voice mode

---

*Living document. Open decisions in §7 get resolved in place, with the
reasoning kept, not overwritten.*
