# GrammarLens — Roadmap & Status

**Purpose of this file:** single source of truth for where the project stands.
Read this first in any new working session (chat or Claude Code) to get context
without re-explaining history.

**Last updated:** 2026-09-05 (v2.2 planning — design audit, monetization decisions)

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
  Streak Mode and AI Practice Partner (not built yet; tapping either is
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
  AI Practice Partner). Informational only, per §6: no payment flow, no
  price, no buy button anywhere on it
- Content: the required framing line ("You're one of our first users —
  everything is free while we're in early access") plus a short list of
  what premium will include — unlimited Streak Mode, AI Practice Partner —
  each tagged "Coming soon" since neither feature exists yet either.
  Deliberately did not say "free forever" or unqualified "free" (§6:
  becomes a constraint once real pricing ships)
- Verified in both themes on the iOS simulator via a temporary,
  untracked debug-harness entry point (same technique as Phase 1 — direct
  render, no tap automation), deleted after use

**V2 Phase 2 continued — pre-launch checklist progress, Home polish,
avatar picker** (`docs/prd-v2.md` §10.1, §11), five independent commits:
- **Daily session cap.** Client-side cost guardrail (§10.1): `StorageService`
  tracks practice sessions started per local calendar day (schema v7);
  `launchPracticeSet` checks it before even opening the length picker and
  shows a "That's all for today" dialog instead of triggering generation
  once the limit (10/day, a placeholder default — see §7.2) is reached. A
  session only counts once generation actually succeeds; both the check and
  the write fail open on a storage error
- **Onboarding privacy note.** One line under the goal options: data stays
  on-device, never sent to a server (§10.1's privacy-note item, closed)
- **Firebase Analytics + Crashlytics — code scaffold only, no project
  connected.** `AnalyticsService` wraps three custom events
  (`onboarding_completed`, `mode_selected`, `session_completed`) plus
  Crashlytics's global error hooks in `main.dart`. Connecting an actual
  Firebase project needs an interactive `flutterfire configure` run against
  a real account, which isn't something that can be done inside a coding
  session — so `Firebase.initializeApp()` is wrapped in try/catch and every
  `AnalyticsService` call is a safe no-op until that happens. Verified the
  app still builds and runs normally on iOS with the packages present but
  unconfigured
- **Early Access given a distinct look on Home.** As a fourth grid tile it
  read identically to the three practice-mode cards, implying it was one.
  Pulled into its own full-width outlined/tinted banner below the grid —
  commercial framing, not a mode, now reads that way on sight
- **Avatar picker (§11), promoted from the parking lot.** Eight local stock
  emoji avatars, no upload pipeline. Picker lives in Settings (not
  onboarding, consistent with onboarding's "every field costs completions"
  stance); the chosen avatar shows next to Home's personalized greeting.
  `UserProfile` gains a nullable `avatar` field (schema v8)

**Home + nav bar revision round**, referencing Kick/Instagram's nav design,
four independent commits:
- **Floating, frosted-glass nav bar.** Replaced the flush, flat-background
  bottom bar with a pill: margins from all three screen edges, fully
  rounded corners, translucent `BackdropFilter`-blurred container. Existing
  active-tab styling (icon+label, selected pill) untouched — only the bar's
  own surface changed. Deliberately not `extendBody: true` (letting screen
  content draw behind the bar): a first attempt at that hid Home's mode
  grid's last row underneath the bar on an unscrolled screen instead of
  stopping above it — a real regression for a cosmetic "blur reveals
  scrolled content" nicety. Scaffold's default behavior (reserving the
  bar's height above `body`) avoids that risk entirely and still delivers
  the floating/rounded/translucent look
- **Early Access banner contrast.** The outlined/tinted treatment (10%
  secondary fill, thin border) read as washed out against the vivid orange
  page — too close to the page color to register as its own surface.
  Switched to a solid `colorScheme.secondary` fill with `onSecondary` text,
  the same pairing `FilledButton` already uses — reads clearly against both
  the orange page and the cream/white mode cards
- **Avatar moved to the trailing edge.** Was leading the greeting text;
  swapped order (greeting first, avatar last) with a `spaceBetween` Row so
  the avatar sits flush against the screen's trailing edge instead of
  floating near the center-left
- **Avatar tap → Settings.** The avatar is the user's own identity marker
  and Settings is where it's actually edited, so tapping it jumps there
  directly — wired the same way `ReviewScreen`'s `onGoToPractice` already
  switches tabs, a nullable callback set by `app.dart`

**Nav bar revision round 2 + avatar shape**, three independent commits —
the first revision round's nav bar didn't actually hit the target:
- **Genuinely floating nav bar.** The previous pill still used Scaffold's
  `bottomNavigationBar` slot, which wraps its child in an opaque `Material`
  spanning the full width of the screen's bottom regardless of what's
  inside it — so a solid strip was painted behind the pill and across its
  margins on every screen, most visibly on scrollable Settings where
  content (the Save button) stacked ugly against an invisible boundary.
  Replaced with a `Stack`: tab content fills the whole body, the pill is a
  `Positioned` overlay near the bottom — nothing paints anything outside
  the pill's own rounded bounds, so content now genuinely scrolls behind
  it, Instagram-style. Each tab screen's scrollable content gets extra
  bottom padding (`navBarClearance`) so an important control can be
  scrolled fully clear of the bar rather than staying stuck under it. This
  also reverses the previous round's "don't use extendBody" call — that
  call was avoiding the *symptom* (content hidden behind an opaque
  boundary) without addressing the actual cause (the slot itself), which
  this round fixes properly
- **Active tab: translucent highlight, not a solid block.** Was a solid
  `colorScheme.secondary` fill with white text; switched to a soft 30%-
  alpha tint with the accent color carried by the icon/text instead — GNav
  already only renders the tab background for whichever tab is selected,
  so this reads as a gentle "you're here" marker rather than a filled pill
- **Avatar shape: circle → rounded square.** Both Home's greeting avatar
  and Settings' picker grid. `AvatarCircle` renamed to `AvatarTile`
  (the old name would be actively misleading now); corner radius scales
  with size instead of being fixed. Selection ring and the avatar's tap
  ripple both updated to match the new shape

**Nav bar revision round 3: drop the active-tab indicator entirely.** Two
prior rounds tried to fix the active tab's `tabBackgroundColor` block —
first a solid fill, then a translucent tint — and neither ever sat flush
against the floating pill's edges; the block is painted by `GNav`'s own
internal animated icon+label layout, which has no seam to fix that
geometry from outside. Rather than a third attempt at re-geometrying it,
removed the block outright and replaced `GNav`/`google_nav_bar` with a
small custom row widget (`_FloatingNavBar` in `app.dart`) so the active
tab is communicated purely by icon + color + a small dot: outline icon
swaps to filled, icon/label recolor to the accent blue, label goes bold,
and a 4px accent dot appears centered beneath — no background shape at
all, Instagram-style. `google_nav_bar` is no longer a dependency.

**Removed Streak Mode and AI Practice Partner from Home.** Both were
"coming soon"/"premium" tiles in Home's mode grid leading only to an
informational dialog — neither is actually built. Per `docs/prd-v2.md`
§12.6, that's an Apple App Review completeness risk (tiles for
core-looking features that don't do anything) and pure duplication
besides, since the Premium screen (reached via the Early Access banner)
already lists "unlimited Streak Mode" and "AI Practice Partner" as
coming-soon premium features. Removed
the tiles, their tap dialogs, and the now-dead `_showComingSoonDialog`
machinery; Topic Practice — the only real mode — is now a single
full-width card instead of a lone tile in an otherwise-empty 2-column
grid.

**RevenueCat integration scaffold — code only, no product connected yet.**
Added `SubscriptionService` (`lib/services/subscription_service.dart`),
wrapping `purchases_flutter`'s SDK configuration, entitlement check
(`hasFullAccess`), `purchasePackage`, and `restorePurchases`, initialized
in main.dart the same "safe no-op until configured" way Firebase already
is: no RevenueCat public SDK key set at build time (or `Purchases.configure`
throwing) means every method degrades to its safe default
(`false`/`PurchaseOutcome.failure`) instead of crashing, matching
`AnalyticsService`'s pattern for an unconnected Firebase project. Same
caveat as that Firebase entry: **no RevenueCat account or App Store
Connect product exists yet** — entitlement id `premium` and product id
`grammarlens_premium_monthly` are just the identifiers reserved for when
one is created. This batch is the service layer only: no paywall UI, no
gating of Topic Practice, nothing wired to a purchase button — later
batches consume this.

**Daily Test — data/logic layer only, not reachable from any screen yet.**
The free tier's fixed daily set (PRD v2 §12.2, §12.5, §12.8): 5
fill-in-the-blank/error-correction questions (no multiple-choice —
conclusively rejected in user research, `docs/prd.md` §2.2 Theme 1),
generated once per calendar day per device and graded entirely offline.
Added `DailyTestQuestion`/`DailyTestSet` (`lib/models/`), a local schema
v9 cache table in `StorageService` (`daily_test_sets` — a separate
per-day cache from Topic Practice's session-cap table, deliberately not
sharing or touching it), `ClaudeService.generateDailyTestQuestions`
(structured JSON: each question's correct answer plus 2-3 predicted
common wrong answers with pre-written comments, generated up front so no
second LLM call is needed to grade), and `answer_matching.dart`'s
deterministic checker (normalize → exact match → common-wrong match →
generic fallback). Personalizes by biasing topic selection toward the
device's local error profile (`StorageService.getWeakSpots`) when one
exists, general/varied mix otherwise — same single generation call
either way. `DailyTestService` ties it together (get-cached-or-generate,
mark-completed) for a future screen to call. No UI, no Home/onboarding
wiring, no paywall/entitlement checks — next batch.

**Daily Test — screens built, still not reachable from Home/onboarding.**
`DailyTestScreen` (`lib/screens/daily_test_screen.dart`) and
`DailyTestResultScreen` (`daily_test_result_screen.dart`) on top of the
previous batch's data layer. The question flow deliberately mirrors
PracticeScreen's layout — same progress bar, same keyboard-aware bottom
button, same header/answer split into separate scroll regions (the
hard-won fix for the keyboard dragging the question off screen, not
worth regressing here) — but simpler: fixed 5-question count, no length
picker, no submit-time API call (grading is instant and local via
`checkDailyTestAnswer`). The result screen reuses `SemanticColors` and
`MistakeBreakdown` for the same correct/incorrect/skipped card treatment
Topic Practice's ResultsScreen already uses, plus an optional
`bottomBuilder` extension point (deliberately no hardcoded "Back to
Home") for the next batch's trial/paywall pitch. Verified via a
temporary debug harness (both screens, both themes) — no real entry
point exists yet; wiring into Home is the next batch. Also: gave
`StorageService` an injectable `dbName` so the growing set of
ffi-backed test files (this batch added a third) stop racing on the
same real db path under `flutter test`'s default concurrency.

**Daily Test is now reachable from Home.** A second full-width card,
stacked above Topic Practice (Daily Test leads since it's the always-
free entry point — Topic Practice becomes trial/paid-gated once the
paywall exists), wired to the existing `DailyTestScreen` →
`DailyTestResultScreen` flow via `DailyTestService`; no new generation/
caching/checking logic, just the entry point and an analytics identifier
(`AnalyticsService.modeDailyTest`) to match. No entitlement/paywall
gating yet on either card — anyone can open both, same as before; that
depends on the paywall screen, which doesn't exist yet. The first-launch
Day-0 flow (PRD v2 §12.3's "Welcome → Onboarding → Daily Test → Results
→ paywall pitch" sequence) is also still pending — this batch only
covers Daily Test's placement inside the existing Home, not onboarding.
Verified on the real running app (not a debug harness) for Home itself;
the flow screens (unchanged from the previous batch) were re-confirmed
via the same temporary harness technique, since there's no way to script
a real tap in this environment — a unit test asserts the Daily Test
card's tap handler is wired distinctly from Topic Practice/Early Access
as a deterministic proxy for that gap.

**Paywall screen built and reachable from Premium — not yet gating Topic
Practice or wired into onboarding.** New `PaywallScreen`
(`lib/screens/paywall_screen.dart`), on top of the RevenueCat scaffold
service layer from the batch above. Leads with the personalized-feedback
pitch (docs/prd.md §2.1 Theme 2 / §2.2 Theme 7 — the thing every one of
the three usability testers praised unprompted), then price/trial terms
read live from `SubscriptionService.getOfferings` (new method added this
batch) rather than hardcoded, a Restore Purchases action, and Privacy
Policy/Terms links wired to a new `AppLinks` constant
(`lib/utils/app_links.dart`) that is **still empty** — no hosted pages
exist yet, confirmed, not an oversight. **This is a real pre-launch
blocker**: the App Store requires a working Privacy Policy link for any
app that collects data, and a Terms link specifically for auto-renewable
subscriptions (PRD v2 §10.1, §12.6). PremiumScreen's copy is revised to
match: it no longer claims "everything is free while we're in early
access" (PRD v2 §12.2's real split — Daily Test free, Topic Practice
3-day-trial-then-paid, Streak/Voice paid once built), and gained a "Start
free trial" button navigating to `PaywallScreen`.

Neither screen is wired to anything else yet: Topic Practice still opens
directly with no entitlement check, and the Day-0 onboarding flow (PRD v2
§12.3's "Daily Test result → paywall pitch" step, `DailyTestResultScreen`'s
`bottomBuilder` extension point from the previous batch) still isn't
connected to this screen. Both are later batches.

**A real bug found and fixed while verifying this on the iOS simulator:**
calling any `Purchases.*` method before `Purchases.configure()` succeeds
throws a *native* Swift `fatalError` (`Purchases has not been
configured`), not a catchable Dart exception — it crashed the app outright
the first time `PaywallScreen` actually called `getOfferings()` on-device,
despite `SubscriptionService`'s existing try/catch blocks (which cannot
catch a native fatal error). Since no RevenueCat API key is set at build
time, the app never calls `Purchases.configure()`, so this was live in
`hasFullAccess`/`purchasePackage`/`restorePurchases` since the RevenueCat
scaffold batch too — nothing had exercised them from the UI until this
batch's paywall screen did. Fixed with an explicit `_configured` flag,
set only after `Purchases.configure` actually succeeds; every method now
checks it and returns its safe default *before* touching the SDK, instead
of trusting a try/catch that structurally can't contain this failure.
Re-verified on-device after the fix: the paywall now shows its
"pricing unavailable" state, not a crash — this is also the state real
testing hits today, since no RevenueCat/App Store Connect product exists
yet either. Screenshotted in both light and dark mode (PremiumScreen and
PaywallScreen); `flutter analyze` and the full test suite (including new
`paywall_screen_test.dart` and updated `premium_screen_test.dart`,
against a faked `SubscriptionService` — the real one hangs indefinitely
against RevenueCat's platform channel with no engine to answer it in a
plain widget test) are clean.

**Paywall follow-up: fixed an invisible Restore Purchases button in light
mode.** A quick correction on the batch above. Restore Purchases and the
Privacy Policy/Terms links were already there, but an unstyled
`TextButton` defaults to Material 3's `colorScheme.primary` — which in
this app's light theme *is* the page's own vivid-orange background (the
exact clash `theme.dart`'s `filledButtonTheme` comment already documents
working around for `FilledButton`). Result: Restore Purchases rendered
orange-on-orange and was completely invisible in light mode, never caught
before because earlier verification only screenshotted the top of the
scrollable screen. Fixed with an explicit `foregroundColor:
colorScheme.secondary` on both that button and the legal links. The legal
links also changed from a tap-triggers-a-SnackBar pattern to a properly
disabled (`onPressed: null`) button while `AppLinks`' URLs are still
empty — simpler, and reads correctly as "not yet available" rather than
a live-looking link that does something unexpected. Also tried, then
reverted, pinning Restore Purchases/the legal links to the true bottom of
the screen via an `Expanded` split (matching `practice_screen.dart`'s
pinned-button pattern) to address a reported empty-space gap — that
actually made it worse, turning a short gap into a large deliberate-
looking void; reverted to a single flowing list, which keeps these
elements tightly grouped right after whatever pricing content precedes
them. Re-verified on-device in both themes; `flutter analyze` and the
full test suite are clean.

**The v2.1 free/trial/paid flow is now wired end-to-end (PRD v2 §12.3).**
Everything built across the RevenueCat scaffold, Daily Test, and paywall
batches above is now actually connected — routing and gating logic only,
no new screens:

- **Topic Practice gated by entitlement on Home**, live. `HomeScreen` now
  checks `SubscriptionService.hasFullAccess` on load and subscribes to a
  new `SubscriptionService.addAccessListener`/`removeAccessListener` pair
  (wrapping `Purchases.addCustomerInfoUpdateListener`, which — unlike
  every other `Purchases.*` call — is a local, SDK-config-independent
  operation, so it's safe to register even before/without a configured
  project). A trial starting or expiring updates the card without an app
  restart. Locked state reuses the old Voice Practice tile's lock-icon
  visual language (muted icon-avatar fill + a small lock glyph next to
  the title) adapted to the current full-width card layout; tapping a
  locked card opens `PaywallScreen` instead of `TopicPracticeScreen`.
- **`PaywallScreen` gained a "Maybe later" skip**, below Restore
  Purchases/the legal links, plus an `onDone` callback so where it leads
  depends on how the screen was reached: null (Home's locked card,
  Premium's CTA) just pops; the Day-0 flow below passes a real callback.
  The primary button also now repurposes itself to "Continue" once a
  trial has actually started, instead of adding a second button.
- **The Day-0 first-launch flow** (Welcome → Onboarding → Daily Test →
  Result-with-paywall-pitch → Home) is real. `FirstLaunchFlow` gained
  `dailyTest`/`dailyTestResult` steps to its existing widget-swap state
  machine — deliberately *not* routed via `Navigator.push`: this flow has
  no nested Navigator, so a `pushReplacement` (which is what
  `DailyTestScreen` normally uses to reach results) would replace the
  app's root route entirely and break the reactive `home:`-swap
  app.dart's onboarding-complete transition depends on. `DailyTestScreen`
  gained optional `onFinished`/`onExit` callbacks (null keeps its
  existing pushReplacement/pop behavior for Home's own entry point)
  specifically so the Day-0 case can reach results and handle "leave"
  through plain state changes instead. The result screen's `bottomBuilder`
  slot (built but left empty in the Daily Test screens batch) now shows a
  short pitch + "Start free trial"/"Maybe later" — tapping "Start free
  trial" pushes the real `PaywallScreen` (a genuine, poppable excursion on
  top of the still-intact root route); either skip path calls
  `FirstLaunchFlow`'s own finish, which hands the already-saved profile to
  `onComplete` exactly like plain onboarding-complete always has. Onboarding
  completing a *second* time (returning launches) is unaffected — that
  distinction was already fully carried by "does a profile exist," no new
  flag needed.
- **The daily session cap is untouched** — confirmed by diff, not just
  assumption: `practice_launch.dart`/`storage_service.dart`'s cap logic
  has zero coupling to `SubscriptionService`, so it applies the same way
  to trial and paid users as it always has, independent of Daily Test's
  own separate once-a-day generation.

Also fixed along the way: a `testWidgets()`-only hang discovered while
building `first_launch_flow_test.dart` — genuine `sqflite_common_ffi` I/O
(which works fine in a plain `test()`, per the existing ffi-backed test
files) stalls indefinitely inside `flutter_test`'s fake-async test
binding. Worked around with an in-memory fake `StorageService` for that
one test file rather than real ffi.

Verified on-device in both themes (locked Topic Practice card, Day-0
result-with-paywall screen); `flutter analyze` and the full test suite
(85 tests, including a new `first_launch_flow_test.dart` driving the
entire Day-0 flow through both exit paths) are clean.

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
See `docs/prd-v2.md` §10.1. Done: daily session cap, privacy note, minimal
analytics (code scaffold — no Firebase project connected yet, needs an
interactive `flutterfire configure` run against a real account), and now
the full v2.1 free/trial/paid flow (previous section) — functionally
complete, but not launch-ready. Still open: distribution channel
decision, API key safety approach, device coverage, feedback channel —
several of these are open decisions, not just tasks. **Blocker status, reconciled 2026-09-05** (previous
entries here were partly stale and partly optimistic — corrected against what
actually exists):
- **RevenueCat / App Store Connect: nothing done.** No RevenueCat account, no
  project, no App Store Connect app record, no products, no agreements/tax/
  banking section. The Apple Developer membership is paid and the account is
  approved — that is the only part that is real. Purchases still fail safe in
  the app.
- **Privacy Policy / Terms: still do not exist** (`AppLinks` in
  `lib/utils/app_links.dart` is empty). Blocked behind a domain purchase by
  choice: the pages will live on a real domain rather than a default
  subdomain. The text does not depend on the domain and can be written first,
  but it does depend on the API-key architecture decision below.
- **API key safety is a launch blocker, not an open decision.** The key is
  compiled into the binary via `--dart-define`, which is extractable from a
  shipped build. Decision taken 2026-09-05: move it behind a Cloudflare
  Workers proxy that holds the key as a secret, accepts only GrammarLens's
  request shape (fixed model and max-token ceiling, so it cannot be used as a
  general-purpose proxy) and rate-limits per device. Not built yet.
- **Visual polish: audited, not yet applied.** A screen-by-screen review was
  done on 2026-09-05 and written up in `docs/design-audit.md`, with the
  decisions it produced. The work itself is the v2.2 block below.
- **README overhaul: confirmed applied** (verified against the repo
  2026-09-05). Closed.

### 2. v2.2 — structure, then finish
Decisions in `docs/prd-v2.md` §13 and `docs/design-audit.md` §5.

**B-structure** (do first — polishing screens whose structure is about to
change is wasted work):
- Merge Early Access and Paywall into one Premium screen; retire the "Early
  Access" name
- Replace the 3-day trial with the 7-day card-up-front model everywhere; trial
  length and prices from a single source, never hardcoded copy
- Add the required App Store disclosure block to the purchase point
- Remove unbuilt features from the purchase surface
- Rebuild Home as a "today" screen (Daily Test state, Topic Practice, weak
  spots, quiet premium row) — explicitly *not* by restoring coming-soon cards
- Demote Skip from primary on Daily Test questions
- Fix the nav bar overlapping scrollable content
- Fix the duplicated topic label in Review

**B-polish** (after the above): apply the hybrid theme rule across screens,
collapse to a single blue, introduce a spacing scale, fix the contrast
failures listed in the audit. Verify every batch on-device in dark mode.

### 3. Public launch
Topic mode + onboarding + premium teaser only. No streak mode yet.

### 4. Streak mode (post-launch fast-follow)
Built after real D1/D7 data exists, not before. Carries the open cost
decision (`docs/prd-v2.md` §7.1). Instrument per-session token usage while
building it.

### 5. Rewarded video gate on streak (free tier)

### 6. Cost measurement, resolve open decisions §7.1 / §7.2

### Later phases (post-v2)
Accounts + backend → social / competition → AI Practice Partner.

**Heads-up, not yet decided (2026-09-02):** Ahmet has flagged a possible
v3/v4 gamification iteration further out, which would likely bring another
visual design pass. Recorded here only so it isn't lost — no scope, no
screens, no commitment yet. Needs its own decision pass when we get there.

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
- **Typos misgraded as grammar errors — reopened 2026-09-06.** The
  2026-08-24 check concluded "no issue found"; that check missed the case
  that actually matters for this audience. Using the app on a Turkish
  keyboard, an answer typed as "cookıng" (dotless ı) against the expected
  "cooking" is marked "Needs work" with no explanation — the two strings are
  near-indistinguishable at body-text size. Scoring behaved correctly; the
  product decision behind it did not. Two harms: the feedback is negative and
  unexplained, and since Daily Test now feeds the error profile, it writes a
  grammar weak spot the user does not actually have, corrupting the data the
  free tier's value rests on. Turkish-keyboard character substitutions
  (ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u) are never grammatical distinctions in
  English and must not be scored as grammar errors

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
