# Build Log

Chronological record of what happened after [`prd.md`](prd.md), during MVP
build-out. Two records merged into one timeline: engineering work done in
this Claude Code session, and product decisions made in a separate advisory
Claude session Ahmet uses for product calls — each entry is tagged
`[Engineering]` or `[Product]`.

## 2026-07-20

- **[Product]** Model choice: Opus → Sonnet, decided right after the initial
  scaffold proposal, before the first commit. Practice-item generation and
  scoring don't need Opus-level capability; Sonnet is materially cheaper and
  faster, and per-session cost matters for an LLM-native product.
- **[Engineering]** Scaffolded the app and integrated the Claude API
  (Sonnet) for practice-set generation and answer scoring — first running
  build.

## 2026-07-21

- **[Engineering]** Fixed CORS: browser calls to the Anthropic API were
  blocked. Added the `anthropic-dangerous-direct-browser-access` header —
  web-prototype-only, not needed for mobile builds.
- **[Engineering]** Fixed a 401 "invalid API key" error right after the CORS
  fix — `flutter run` had been restarted without `--dart-define`, so the key
  never reached the build. Fixed by exporting the key in the shell and
  passing it explicitly.
- **[Engineering]** Fixed the Review tab hanging on a loading spinner
  forever: `sqflite` has no web driver, so every DB read/write threw
  silently on web, and the `FutureBuilder` only checked `snapshot.hasData` —
  never `hasError` — so it never left the spinner. Added
  `sqflite_common_ffi_web` with a `kIsWeb` factory switch, and gave Review
  proper empty / error / retry states.
- **[Engineering]** That fix introduced a follow-on crash:
  `setState(() => _weakSpots = future)`'s arrow body returns the value of
  its expression — the assignment's value, i.e. the `Future` itself — which
  Flutter's `setState` rejects at runtime ("callback argument returned a
  Future"). Fixed with a block body. Also noticed Home and Review each had
  their own copy of "generate → navigate → handle errors"; unified both into
  one shared helper so this class of bug can't diverge between the two
  paths again.
- **[Product]** UX finding from testing: tapping a weak spot jumps straight
  into freshly generated practice questions, but the expected flow was to
  first see a summary of the past mistakes being targeted. Decision: add an
  error-summary screen before targeted practice — **P0 for Iteration 1**.

## 2026-07-24

- **[Engineering]** Iteration 2 shipped, driven by the four interview
  findings in [`prd.md`](prd.md) §2.1: question mix rebalanced toward
  production (2 sentence-writing, 2 error-correction, 1 fill-in-blank per
  set); feedback and Review now lead with a plain-language explanation and
  demote the rule name to a secondary caption; Review shows prominent
  count/recency stats ("N times · last seen ...") with a Recent/Most
  frequent sort persisted locally; Results shows the user's own answer next
  to the correction; and practice items render `context` and `instruction`
  as two distinct blocks instead of one paragraph.
- **[Product]** Skipped ≠ wrong. Found during my own testing of the app: an
  unanswered item was being scored red/incorrect and counted against the
  score, and the model's `errorType` for a blank answer varies every run
  ("You left this one blank", "Nothing was written here", ...), so matching
  against it to detect skips was unreliable. Decision: detect "skipped"
  deterministically in our own code from the raw answer text
  (empty/whitespace), never from the model's output — skipped items get a
  neutral color, are excluded from the correct/incorrect count, and are
  never written to the error profile.
- **[Product]** Error-correction items are graded on the grammar fix, not
  on format. Found during my own testing: writing just the corrected
  word/phrase instead of rewriting the full sentence was marked wrong even
  when the grammar fix itself was right. Decision: mark it correct if the
  target mistake is genuinely fixed, regardless of whether the full
  sentence was rewritten, with a short explanation note encouraging the
  full-sentence habit — only mark it "Needs work" when the grammatical
  correction itself is wrong, incomplete, or introduces a new mistake.
- **[Product]** Context and instruction are separate fields, not one
  string. Found during my own testing: the scenario setup and the actual
  task ran together as one long paragraph, making items look longer and
  more intimidating than they are. Decision: have generation return
  `context` and `instruction` as separate JSON fields so the UI can render
  them as two visually distinct blocks (plain-text context, then a bold
  instruction line).

## 2026-07-25

- **[Engineering]** Visual identity pass: adopted Material 3 with a
  hand-built orange/royal-blue `ColorScheme` (`lib/theme.dart`), an animated
  `google_nav_bar` bottom nav, full-screen animated loading states for
  generation/scoring, semantic (soft green/rose/cream) result colors via a
  `ThemeExtension`, and centered screen headers throughout. Iterated live on
  the iOS simulator against Ahmet's feedback each round. Light mode uses a
  vivid orange page background with blue accents; dark mode intentionally
  diverges to a neutral dark surface with orange/blue accents rather than a
  dark-orange background, which read as harsh/muddy in early passes.

## 2026-08-07

- **[Product]** Empty states, roadmap item 1. Reviewed every screen that
  renders from a list that can be zero-length. Review's "no weak spots"
  state already existed but was a dead end; gave it a CTA that jumps to the
  Practice tab. Weak-spot detail's empty mistake list was a bare `Text`
  inconsistent with Review's icon+text treatment; brought it in line.
  Deliberately left two screens alone: Results' feedback list can't
  actually render empty (minimum session length is 3, never 0), and Home
  already degrades gracefully per-card ("Not started yet") on first run
  rather than showing a blank page — neither reads as broken, so no
  speculative empty-state code was added for them.
- **[Engineering]** Extracted the icon+title/description+CTA pattern into a
  shared `EmptyState` widget (`lib/widgets/empty_state.dart`) instead of
  copy-pasting it a second time, with a `dense` inline variant for empty
  states that sit inside a screen that already has its own CTA elsewhere.

## 2026-08-24

- **[Product]** Typo vs. grammar-error distinction verified, no issue found.
  `docs/prd.md` §2.2 Theme 4 flagged an unconfirmed, single-participant
  concern (T2 worried a typo might get misread as a grammar mistake).
  Deliberately tested with a misspelled word in an otherwise grammatically
  correct sentence — scoring did not misclassify it. No prompt change made;
  removed from the Iteration 3 candidate list in `docs/roadmap.md`.
- **[Engineering]** Shipped v2 Phase 1 (`docs/prd-v2.md` §4, §5, §10) in
  three commits, one per screen group: (1) Welcome + two-field onboarding
  (name + learning goal, guest-first — no signup, profile save doubles as
  the "onboarding complete" flag), (2) Home rewritten from topic list to
  mode selection with a personalized greeting, old topic list moved
  unchanged into its own `TopicPracticeScreen`, (3) Settings screen built
  from scratch (proper light/dark/system theme picker, name edit, optional
  age/occupation, scoped "reset progress" that keeps the guest identity).
  `StorageService` gets a `user_profile` table (schema bump to v6, same
  drop/recreate-on-upgrade convention as the rest of the schema) and
  `resetProgressData()`. Existing Topic Practice and Review flows untouched
  — this phase only added navigation and new screens around them, per
  scope. Verified per-commit on an iOS simulator in both themes; tap
  automation in this sandboxed environment turned out unreliable enough
  (intermittent Accessibility-permission failures, no working mechanism to
  reliably synthesize touches) that verification leaned on a temporary
  debug-harness entry point (render a target screen directly, no taps
  needed) plus one genuine end-to-end run whose saved profile was checked
  directly in the on-device sqlite file.
- **[Engineering]** v2 Phase 1 revision round, three fixes found testing the
  above on a real device, each its own commit: (1) onboarding text/labels
  centered, and the learning-goal option cards fixed in light mode only —
  their unselected fill was transparent, invisible against light mode's
  vivid orange page background (dark mode's near-black page happened to
  make the same transparent fill look fine, which is presumably how this
  shipped unnoticed); (2) Streak/Voice "coming soon" messaging moved from
  `ScaffoldMessenger`'s app-wide SnackBar to a screen-scoped `showDialog` —
  the SnackBar bug (stacked on repeat taps, kept showing after navigating
  away) traced to that messenger living above the Navigator, shared by
  every Scaffold in the tree rather than scoped to Home; a same-frame
  double-tap test pins the fix down alongside the existing barrier-modality
  behavior; (3) Home's mode cards moved from a vertical list to a
  2-column `GridView`. Verified in both themes via the same debug-harness
  technique as the initial Phase 1 build.
- **[Product]** Shipped v2 Phase 2 — Premium / early-access screen
  (`docs/prd-v2.md` §6, `docs/roadmap.md` "What's next" item 1, now closed).
  New `PremiumScreen`, reached from a fourth Home mode card ("Early
  Access") that fills out the mode grid to a full 2x2 alongside Topic
  Practice, Streak Mode, and Voice Practice. Informational only, exactly
  per §6's scope: no payment flow, no price, no buy button, no credit-card
  field anywhere on the screen — a new `premium_screen_test.dart` asserts
  that directly (no `TextField`, no `FilledButton`/`ElevatedButton`, no
  `$`, no "Buy"/"Subscribe"/"Upgrade" text) rather than relying on a human
  catching a regression later. Content: the required framing line verbatim
  ("You're one of our first users — everything is free while we're in
  early access"), plus two feature tiles — unlimited Streak Mode, AI Voice
  Practice — each carrying its own "Coming soon" badge since neither
  feature is built yet either; a closing line makes that explicit.
  Deliberately avoided "free forever" or unqualified "free" per §6's
  reasoning: an unbounded promise made now becomes a constraint the moment
  real pricing ships. Verified in both light and dark mode on the iOS
  simulator via the same temporary, untracked debug-harness technique used
  for Phase 1 (direct-render entry point, no tap automation — deleted
  after use, never committed).
- **[Product]** Five independent pre-launch/polish items shipped, each its
  own commit (`docs/prd-v2.md` §10.1, §11):
  1. **Daily session cap.** `docs/prd-v2.md` §10.1's cost guardrail.
     `StorageService` gets a `daily_session_usage` table keyed by local
     calendar day (schema v7) and `getSessionCountForToday()` /
     `recordSessionStarted()`. `launchPracticeSet` — the single choke point
     both TopicPracticeScreen and Review's "Practice this" already funnel
     through — checks the count before the length picker even opens, so a
     session at the cap never reaches `generatePracticeSet` at all; a
     session only counts once generation actually succeeds, and both the
     check and the write fail open on a storage error rather than blocking
     practice over it (same posture as `app.dart`'s profile/theme loads).
     Covered by a real-sqlite (ffi) test for the storage layer and a
     fake-`StorageService` widget test for the UI gate — a first attempt at
     the widget test against the real ffi-backed store reliably hung
     `flutter test` (real I/O doesn't play well inside `testWidgets`' fake-
     async zone), so it was rebuilt against an in-memory fake instead,
     matching how the rest of the suite already treats StorageService in a
     `testWidgets` context.
  2. **Onboarding privacy note.** One line under the goal options stating
     the collected name/goal stay on-device only — closes §10.1's privacy-
     note item, aimed at strangers hitting onboarding pre-launch who
     (unlike the in-person testers earlier rounds had) haven't seen the app
     do anything yet.
  3. **Firebase Analytics + Crashlytics — code scaffold, no project
     connected.** New `AnalyticsService` (`firebase_analytics`) with three
     custom events — `onboarding_completed`, `mode_selected` (topic/streak/
     voice/early_access), `session_completed` — threaded through
     `FirstLaunchFlow`, `HomeScreen`, and the full practice-launch →
     `PracticeScreen` → `ResultsScreen` chain (both the Home and Review
     entry points). `main.dart` wires Crashlytics's global
     `FlutterError`/`PlatformDispatcher` hooks. Connecting an actual
     Firebase project needs an interactive `flutterfire configure` run
     against a real Google/Firebase account — not something a coding
     session can do — so `Firebase.initializeApp()` (no explicit `options`,
     relying on native config files that don't exist yet) is wrapped in
     try/catch and every `AnalyticsService` method is a safe no-op until a
     project exists. Verified by actually building and running the app on
     the iOS simulator with the packages present but unconfigured: native
     Firebase CocoaPods resolve and build fine, Dart-side init fails
     silently with no console noise, nothing else about the app changes.
     Also excluded `build/` from `flutter analyze` (adding the packages
     made an SPM/CocoaPods checkout vendor the flutterfire monorepo's own
     internal test suite underneath it, which the analyzer had started
     trying to lint) and gitignored Xcode's shared-workspace SPM
     resolution state (`Package.resolved`, machine-specific, regenerates on
     any build).
  4. **Early Access given a distinct look on Home.** Found while building
     the above: as a fourth tile in the 2×2 mode grid, Early Access (a
     commercial framing per §6) looked identical to Topic/Streak/Voice
     (actual practice modes), implying it was one. Pulled it out of the
     grid entirely into its own full-width banner below — outlined/tinted
     fill instead of the grid tiles' solid card look, horizontal
     icon+text+chevron instead of their icon-on-top layout — so it reads as
     a different category of thing on sight.
  5. **Avatar picker, §11 promoted from the parking lot.** Eight local
     stock emoji avatars on fixed background colors (`lib/models/avatar.dart`,
     `lib/widgets/avatar_circle.dart`) — no upload pipeline, no image
     assets. `Avatar` itself stays free of any Flutter dependency, same
     reasoning as `AppThemeMode`; the emoji/color mapping lives in the
     UI-layer `AvatarCircle` widget. Picker placed in Settings rather than
     onboarding — onboarding's own doc comment already argues every field
     asked before the user has seen value costs completions, and age/
     occupation already established the pattern of optional profile
     embellishments living in Settings instead. The chosen avatar (or a
     generic placeholder icon) shows next to Home's personalized greeting.
     `UserProfile` gains a nullable `avatar` field, `StorageService`'s
     `user_profile` table gets an `avatar` column (schema v8).

  All five verified in both light and dark mode via the same temporary,
  untracked debug-harness technique as Phase 1/2 (deleted after use, never
  committed); full test suite (47 tests across 9 files) and `flutter
  analyze` clean after each commit.
- **[Product]** Home + nav bar revision round, referencing Kick/Instagram's
  nav design, four independent commits:
  1. **Floating, frosted-glass nav bar.** `app.dart`'s `bottomNavigationBar`
     rebuilt: margins from all three screen edges, `BorderRadius.circular(32)`
     pill shape, `ClipRRect` + `BackdropFilter(ImageFilter.blur(...))` +
     a translucent `colorScheme.surfaceContainerLow` container (alpha 0.55
     dark / 0.68 light) with a soft border and shadow. `GNav` itself goes
     transparent so it doesn't paint a second opaque surface on top —
     existing active-tab styling (icon+label, selected pill) untouched.
     First attempt also set `extendBody: true` so screen content would draw
     (and visibly blur) behind the bar; this reliably hid the last row of
     Home's mode grid underneath the bar on the unscrolled, resting screen
     — content there simply isn't behind glass, it's behind an
     opaque-looking pill with nothing readable through it. Chased two fix
     attempts (reserving clearance as trailing `ListView` padding, then as
     an outer `Padding` shrinking the scroll viewport — the latter
     triggered `SliverList`'s cache-extent virtualization to skip building
     the now out-of-viewport banner entirely on the first frame, so it just
     never appeared) before concluding the "blur reveals scrolled content"
     effect wasn't worth the risk class it opened up. Dropped
     `extendBody`; Scaffold's default behavior (reserving the bar's
     reported height above `body`) costs nothing and can't overlap by
     construction.
  2. **Early Access banner contrast.** Found while re-screenshotting the
     new nav bar in light mode: the banner's outlined/tinted treatment (10%
     secondary alpha fill, thin border) read as washed out against the
     vivid orange page — confirms the exact complaint that prompted this
     task. Solid `colorScheme.secondary` fill + `onSecondary` text/icons
     (the same pairing `FilledButton` uses) fixed it in both themes.
  3. **Avatar moved to the trailing edge.** Row order swapped (greeting
     first, avatar last), `mainAxisAlignment: MainAxisAlignment.spaceBetween`
     with a `Flexible` (not `Expanded`) greeting `Text` so the avatar lands
     flush against the trailing edge regardless of greeting length, and a
     long name truncates instead of pushing the avatar off-screen.
  4. **Avatar tap → Settings.** New nullable `HomeScreen.onAvatarTap`,
     wrapped around `AvatarCircle` with an `InkWell(customBorder:
     CircleBorder())` for a circular ripple; `app.dart` wires it to
     `setState(() => _tabIndex = 2)`, the same pattern `ReviewScreen`'s
     `onGoToPractice` already uses to switch tabs from inside a screen that
     doesn't own the bottom-nav state itself.

  All four verified in both light and dark mode via the same temporary,
  untracked debug-harness technique as earlier phases (deleted after use,
  never committed) — light-mode verification needed a temporary, also-
  reverted-before-commit `themeMode: ThemeMode.light` override in
  `app.dart`, since the simulator's `simctl ui appearance` toggle doesn't
  reliably propagate to an already-running debug build's system-brightness
  detection. Full test suite (48 tests) and `flutter analyze` clean after
  each commit.
- **[Product]** Nav bar revision round 2 + avatar shape, three independent
  commits — the previous round's nav bar rewrite didn't actually hit the
  target Ahmet was pointing at:
  1. **Genuinely floating nav bar.** Ahmet's report: the pill shape had
     changed, but there was still an opaque/solid background spanning the
     entire bottom of the screen behind it, so on Settings the Save button
     stacked ugly against it. Root cause: the previous rewrite still used
     Scaffold's `bottomNavigationBar` slot — that slot wraps its child in
     an opaque `Material` sized to the full width of the screen's bottom
     *regardless* of what's inside it, so even a transparent, rounded pill
     sitting inside that slot left a solid strip painted behind it and
     across its margins. Fixed by dropping the slot entirely: `body`
     becomes a `Stack` with the tab content filling it and the pill as a
     `Positioned` overlay near the bottom, wrapped in `SafeArea(top: false)`
     for the home-indicator inset. Nothing paints anything outside the
     pill's own rounded bounds now. Re-added `navBarClearance`
     (`lib/utils/layout_constants.dart`, same name/value class as the
     previous round's abandoned attempt, this time actually landed) as
     each tab screen's own trailing `ListView` padding — deliberately
     *not* an outer `Padding` shrinking the scroll viewport, which is what
     caused last round's `SliverList` cache-extent bug (content built
     outside the visible frame just never rendering). Padding inside the
     scrollable, with the viewport left full height, has no such issue:
     content sits behind the bar at rest (confirmed via screenshot — the
     Save button and "Data" section label were visibly readable through/
     around the pill, not blocked by a wall), and can be scrolled fully
     clear of it.
  2. **Active tab: translucent highlight instead of solid fill.** Solid
     `colorScheme.secondary` + white text swapped for a 30%-alpha tint of
     the same color, with the accent carried by icon/text
     (`activeColor`/`textStyle`) instead of a filled block. Confirmed via
     `google_nav_bar`'s source that `tabBackgroundColor` already only
     paints for the currently-active tab (inactive tabs animate their fill
     to fully transparent internally) — no per-tab conditional needed,
     just a lower-alpha color. (The package also exposes a per-tab
     `shadow`/`tabShadow` prop, considered for the "or a subtle shadow"
     half of the ask, but `GNav` applies `tabShadow` to *every* tab
     uniformly regardless of active state, which would have put a faint
     shadow silhouette behind inactive icons too — skipped in favor of the
     translucency-only approach, which the ask named as sufficient on its
     own.)
  3. **Avatar shape: circle → rounded square.** `AvatarCircle` renamed to
     `AvatarTile` (`lib/widgets/avatar_circle.dart` →
     `lib/widgets/avatar_tile.dart`) since the old name would be actively
     misleading post-change. `radius` kept as the sizing parameter (half
     the tile's side) so call sites in Home and Settings didn't need
     other changes; corner radius is `radius * 0.6` (scales with size
     rather than a fixed pixel value). Selection ring switched from a
     circular border to a matching rounded-rect border; Home's avatar tap
     `InkWell` switched from `CircleBorder` to a matching
     `RoundedRectangleBorder` so the ripple doesn't visibly mismatch the
     new tile shape.

  All three verified on Home, Review, and Settings in both themes via the
  same temporary, untracked debug-harness technique as earlier rounds
  (deleted after use). Full test suite (48 tests) and `flutter analyze`
  clean after each commit.

## 2026-09-02

- **[Product]** v2.1 pivot: free/trial/paid split, replacing "everything free
  during early access" — full reasoning in `docs/prd-v2.md` §12. Short
  version: Topic Practice triggers a real Sonnet API call every session
  regardless of payment status, and a permanently free, unlimited Topic
  Practice scales cost directly with user count (~$90-270/mo at 100 DAU,
  ~$900-2,700/mo at 1,000 DAU on rough estimates — real token measurement
  still pending, §7.1). Ruled out a hard paywall in front of all value —
  would have meant nobody ever experiences the plain-language feedback 3/3
  usability testers praised, undercutting the one thing v2 launch is
  supposed to measure (§9). Landed on: a free, deterministic, no-LLM-eval
  "Daily Test" everyone gets forever, plus a time-boxed free trial of real
  Topic Practice for new users, converting to paid via standard App Store
  auto-renewable subscription mechanics.
- **[Product]** RevenueCat chosen over hand-rolling receipt validation/
  entitlement tracking — free under $2,500 tracked monthly revenue, well
  within reach for a while; also gives trial-to-paid conversion/churn
  reporting for free, which App Store Connect's own reporting doesn't do
  well and a solo PM needs.
- **[Product]** 3-day trial length, Ahmet's call after weighing the
  trade-off: shorter trials are a known "user forgets to cancel" growth
  lever (the ethically grayer reason 3-day trials are popular industry-
  wide), 7 days gives a fuller habit-formation window for what's meant to
  be a daily habit product. Chose 3.
- **[Product]** Daily Test's "why was this wrong" commentary designed to
  stay clear of multiple-choice: literal "you picked B, correct was A"
  framing requires closed-option UI, which `docs/prd.md` §2.2 Theme 1
  already closed out (5 of 7 users across two research rounds rejected
  MC). Landed on: free-text answer types stay (fill-in-the-blank/error-
  correction), with 2-3 predicted common-wrong-answers and pre-written
  comments generated alongside the question at generation time, matched
  by normalized string comparison at check time — feels personal, costs
  nothing extra since it rides on the one generation call.
- **[Product]** Correction made mid-session: the original "cohort/bucket"
  plan to make Daily Test generation scale-independent assumed a shared
  backend that doesn't exist — GrammarLens is guest-first/local-only
  (`prd-v2.md` §5) by deliberate design, so there's no server to generate
  once and serve to every device. Every device generates its own Daily
  Test regardless, which makes cohort-bucketing pointless (it saves
  nothing without sharing) but also means direct per-device
  personalization against the user's own local error profile is
  effectively free — simplified to that instead. The real cost lever is
  generation-once-per-day-per-device plus zero eval calls, not sharing.
- **[Engineering]** Nav bar: removed the `google_nav_bar` active-tab
  background block (two prior revision rounds tried to fix its alignment/
  padding against the floating pill and didn't land) in favor of icon-fill
  + accent color + bold label only, no background shape. A small active-
  state dot was added then removed the same day per feedback (over-
  decorated once seen on-device).
- **[Engineering]** Home cleanup: Streak Mode / Voice Practice tiles
  removed entirely (App Store 2.1 completeness risk for "coming soon"
  tiles that read as core features, plus redundant with the Premium
  screen's existing coming-soon list). Topic Practice became a single
  full-width card.
- **[Engineering]** RevenueCat scaffold: added `purchases_flutter`, new
  `SubscriptionService` mirroring `AnalyticsService`'s safe-no-op-until-
  configured pattern (the Firebase precedent) — `hasFullAccess`,
  `purchasePackage()`, `restorePurchases()`, all fail closed to `false`/
  an error state rather than crash with no RevenueCat account connected.
  Entitlement id `premium`, product id `grammarlens_premium_monthly` —
  placeholders until a real App Store Connect product exists.
- **[Engineering]** Daily Test data layer: new model + once-per-calendar-
  day-per-device generation (cached locally, new schema version),
  deterministic checking against the correct answer / common-wrong-answer
  set / generic fallback, unit-tested. `DailyTestScreen` +
  `DailyTestResultScreen` built reusing Topic Practice's existing UI
  patterns (keyboard-aware bottom button, header/answer-field kept in
  separate scroll regions, empty-answer ≠ wrong handling) rather than
  reinventing them; the result screen left an explicit extension slot for
  the paywall CTA, filled in later rather than rewritten. Wired into Home
  as a second real card. (Hit the already-known `ANTHROPIC_API_KEY` via
  `--dart-define` requirement here too — not a new issue, just newly hit
  testing this flow.)
- **[Engineering]** `PaywallScreen`: price/trial terms pulled live from
  RevenueCat's offering (not hardcoded), Restore Purchases, Privacy
  Policy/Terms links wired to empty `AppLinks` constants (no hosted pages
  exist yet — a real gap, not a placeholder standing in for one). First
  commit shipped without Restore Purchases or the legal links visible
  (caught from a review screenshot); a follow-up commit added both and
  tightened the layout. Premium/"Early Access" screen copy revised from
  "everything free during early access" to the actual free/trial/paid
  matrix.
- **[Engineering]** Full flow wiring: Home's Topic Practice card now
  reactively checks `SubscriptionService.hasFullAccess` via new
  `addAccessListener`/`removeAccessListener`, so a trial starting or
  expiring updates the card without an app restart; locked state reuses
  the old Voice Practice tile's lock-icon treatment and routes to
  `PaywallScreen`. `PaywallScreen` gained a "Maybe later" skip action and
  a context-dependent `onDone` callback. The first-launch Day-0 flow
  (Welcome → Onboarding → Daily Test → result-with-paywall-pitch → Home)
  required extending `FirstLaunchFlow`'s existing widget-swap state
  machine rather than using `Navigator.push`, to avoid breaking the
  reactive `home:` swap the app relies on — both exit paths (trial start
  or skip) land on Home; returning launches are unaffected. Bug found and
  fixed along the way: `sqflite_common_ffi` hangs indefinitely inside
  `testWidgets()`'s fake-async binding (works fine under plain `test()`)
  — worked around with an in-memory fake `StorageService` for the new
  integration test. 85 tests green, including a new
  `first_launch_flow_test.dart` driving the full Day-0 flow through both
  exits.
- **[Product]** Result: v2.1's free/trial/paid flow is functionally
  complete end-to-end. Three concrete pre-launch blockers remain, none of
  them code: no real RevenueCat/App Store Connect product connected, no
  Privacy Policy/Terms of Service pages exist yet, and a dedicated
  visual-polish pass across Daily Test/Paywall/Premium is still pending
  (deliberately deferred until the flow was functionally done).

## 2026-09-05

- **[Engineering]** Build-time config centralized, decided ahead of the
  planned Cloudflare Workers proxy migration (API key moving out of the
  client entirely, not yet started): rather than fix the immediate
  symptom (Daily Test throwing `ANTHROPIC_API_KEY is not set` on every IDE
  run) with a one-off workaround, consolidated all `String.fromEnvironment`
  reads behind a new `AppConfig` (`lib/config/app_config.dart`) so the
  proxy migration later only touches one file, not every call site. Four
  independent commits: (1) `AppConfig` itself (`anthropicApiKey`,
  `isConfigured`), `ClaudeService` reads through it instead of calling
  `String.fromEnvironment` directly, small new test; (2)
  `--dart-define-from-file` scheme — `config/dev.example.json` committed
  as the template, real `config/dev.json` gitignored, `.vscode/launch.json`
  committed wiring VS Code's Run/Debug to it (`.vscode/` itself stays
  gitignored via a `.vscode/*` / `!.vscode/launch.json` pair, since the
  rest of that folder is editor-local state); (3) the missing-key
  exception message rewritten to name the actual fix (copy
  `config/dev.example.json`, see README) instead of just repeating the
  bare `--dart-define` flag it already required; (4) a short README
  "Local setup" section, including the Xcode caveat found while checking
  this — a direct Xcode Run doesn't pass `--dart-define`/
  `--dart-define-from-file` flags at all, so the key still needs
  `flutter run` or the VS Code config. `subscription_service.dart`'s
  separate `REVENUECAT_API_KEY` read was deliberately left untouched —
  out of scope for this batch, and not a secrecy concern the way the
  Anthropic key is (RevenueCat's SDK key is meant to be public). `flutter
  analyze` and the full test suite (88 tests) clean after every commit.
- **[Product]** Ran a git-history secret scan as a standalone check (no
  code change): searched all 79 commits across all refs for the `sk-ant`
  pattern and for any committed file with an env/config/secret-like name.
  No real Anthropic API key has ever been committed — the only `sk-ant`
  hit is the placeholder string in this batch's own new README section,
  and the only env-like filename ever added is `config/dev.example.json`
  (this batch), which has only ever held an empty placeholder value.

## 2026-09-05 (continued)

- **[Engineering]** Bug found the first time Daily Test actually reached a
  real API call (the previous entry's config fix is what finally let it
  get that far): every generation crashed after a long loading spinner
  with `type 'Null' is not a subtype of type 'Map<String, dynamic>' in
  type cast`. Diagnosed by tracing the full generate → parse → save →
  read chain rather than guessing — root cause was a **schema mismatch
  in our own code**, not bad API data or a half-written cache row (the
  two hypotheses considered and ruled out in turn):
  - `ClaudeService.generateDailyTestQuestions`'s JSON schema asks the API
    for `id`/`type`/`context`/`instruction`/`hint` as flat sibling fields
    on each question, alongside `topicId`/`correctAnswer`/
    `commonWrongAnswers`. The API was returning exactly that shape.
  - `DailyTestQuestion.fromJson` (`lib/models/daily_test_question.dart`),
    however, expected those five fields nested under an `item` key —
    a shape the schema never asked for and the API never sent.
    `json['item']` was therefore always `null`, and casting it to
    `Map<String, dynamic>` crashed on every real generation call. Topic
    Practice's own generation never hit this: `PracticeItem.fromJson`
    there already reads the same flat shape directly, no wrapper
    assumed.
  - Confirmed hypothesis (b) — a half-generated set cached and read back
    broken — did not apply: `DailyTestService.getTodaysSet` awaits
    `generateDailyTestQuestions` fully before ever calling
    `saveDailyTestSet`, so the thrown parse exception propagated before
    anything reached storage. Nothing partial was ever written; this
    already held before the fix, and a new regression test
    (`daily_test_service_test.dart`) now locks it down explicitly with a
    `ClaudeService` fake that fails partway through generation, plus a
    doc comment on `getTodaysSet` stating the invariant so a future
    save-as-you-go refactor doesn't quietly reintroduce it.
  - Why the existing test suite missed this: `daily_test_service_test.dart`
    stubs `ClaudeService` entirely, so it never exercised the real
    `generateDailyTestQuestions` parsing path — the only path the bug
    lived in.

  Fixed across four commits: (1) made `DailyTestQuestion.fromJson`/
  `toJson` use the same flat shape as the actual request schema and the
  local cache — one schema instead of two silently drifting apart, no
  storage schema bump needed since the cache is a pure daily-regenerated
  cache, not data worth preserving across an update; (2) added
  `requireJsonField<T>` (`lib/utils/json_parsing.dart`), which fails with
  a message naming the missing/wrong-typed field instead of an opaque
  cast error, applied to `PracticeItem` and
  `DailyTestQuestion`/`CommonWrongAnswer`'s required fields — the parse
  chain this bug lived in; (3) a regression test
  (`daily_test_question_parsing_test.dart`) feeding a fixed JSON object
  shaped exactly like the real request schema straight into the parser,
  no network involved, plus a missing-field case and a round-trip check;
  (4) the failed-generation-never-cached invariant test and doc comment
  above. `flutter analyze` and the full test suite (92 tests) clean
  after each commit.

## 2026-09-05 (terminal ergonomics + debug entitlement override)

- **[Engineering]** Terminal-first completion of A1's config batch.
  `.vscode/launch.json` solved this for VS Code, but development on this
  project actually happens from the terminal / Claude Code, and retyping
  `--dart-define-from-file=config/dev.json` by hand every run isn't
  sustainable. Added `scripts/dev.sh` (executable, resolves the repo root
  from its own location so it works from any cwd, forwards extra args to
  `flutter run`) and rewrote README's "Local setup" section to lead with
  it — VS Code's launch config is now the documented *alternative*, not
  the only path. Also added an explicit note that release/TestFlight
  builds need the same flag (`flutter build ipa
  --dart-define-from-file=...`), which `flutter build ipa` alone won't
  warn about; the same class of mistake already happened once for a
  plain `flutter run` (2026-07-21 above).
- **[Product]** Debug-only entitlement override, decided ahead of doing
  any visual work on Topic Practice/Daily Test/Paywall: as a real free
  user by default, the developer couldn't reach or preview any gated
  screen without an actual RevenueCat subscription (none exists), and
  had no easy way to check what a free user actually sees either.
  Deliberately scoped to mirror what `SubscriptionService.hasFullAccess`
  already distinguishes — **exactly two states, not three**: RevenueCat
  entitlements are active or they aren't, and an active trial and a paid
  subscriber already collapse into the same boolean there (see
  `hasFullAccess`'s own doc comment) — there is no separate "trial" state
  anywhere in the app to preview. So the override is `bool?`
  (`null`/`false`/`true` → Real/Free/Full access), not a three-way enum
  invented for this.
- **[Engineering]** Implemented across four commits, smallest-first:
  1. `StorageService`: new `debug_settings` table (schema v10, same
     drop/recreate-on-upgrade convention as the rest of the schema),
     `get`/`setDebugAccessOverride` mirroring `getThemeMode`/
     `setThemeMode`'s single-row-table pattern exactly — no new storage
     dependency.
  2. `SubscriptionService`: `hasFullAccess` now checks
     `debugAccessOverride` first, so the override goes through the exact
     path every gated screen (Home's Topic Practice card, the paywall)
     already calls — no gating logic duplicated anywhere new.
     `setDebugAccessOverride` notifies every listener already registered
     via `addAccessListener` with the resulting value, the same thing a
     real RevenueCat entitlement change already does — reused, not
     reimplemented. Gated on a new `debugModeForTesting` static
     (`@visibleForTesting`, defaults to `kDebugMode`) rather than
     checking `kDebugMode` inline: every debug-override method checks
     this instead, so a test can flip it to simulate "as if this were a
     release build" and prove the override is a complete no-op —
     `flutter test` can't compile an actual release binary, so this is
     the seam that makes that guarantee testable at all. The real
     release-safety mechanism is still `kDebugMode` itself, a
     compile-time constant that folds to `false` in an actual release
     build and lets the Dart compiler eliminate everything behind it —
     this seam only lets the *logic* of that gate be exercised from a
     test, it doesn't replace the compile-time elimination.
  3. `SettingsScreen`: new "Developer" section, rendered only
     `if (kDebugMode)`, a `SegmentedButton` (Real/Free/Full access)
     mapped onto the `bool?` override. The initial selection reads
     `subscriptionService.debugAccessOverride` directly (not storage
     again) so it can never show something SubscriptionService isn't
     actually enforcing.
  4. `app.dart`: loads the persisted override into `SubscriptionService`
     at startup (debug builds only, same fail-open-on-storage-error
     posture as the existing theme/profile loads) so a developer's prior
     choice takes effect before Home ever checks `hasFullAccess` — not
     only after Settings happens to be reopened.

  With the override off, `hasFullAccess` is bit-for-bit the same code
  path as before this batch. `flutter analyze` and the full test suite
  (109 tests, including a dedicated `subscription_service_debug_override_test.dart`
  covering the release-simulation case) clean after every commit.

## 2026-09-05 (message/error behavior — visual polish is a separate, later pass)

- **[Engineering]** Messages that never went away, across the whole app:
  SnackBars stuck on screen, their own Dismiss action not working, and
  surviving navigation to a different screen. Two distinct root causes,
  both real, not one:
  1. **A SnackBar with an action defaults `persist` to `true`**
     (`SnackBar`'s own doc comment / `snack_bar.dart` source: `persist =
     persist ?? action != null`) — meaning `error_banner.dart`'s original
     "add a Dismiss action so a 10s-duration error is actually readable"
     fix silently disabled auto-dismiss entirely, regardless of the
     duration set. This is the real reason messages never went away on
     their own — not a queuing artifact, the duration was never honored
     to begin with. Found by reading Flutter's own scaffold.dart/
     snack_bar.dart source after a widget test kept failing in a way that
     made no sense otherwise (a plain `pump(duration)` + `pumpAndSettle()`
     worked with no action attached, and stopped working the moment one
     was added — regardless of what that action's `onPressed` did).
  2. `MaterialApp` provides exactly one `ScaffoldMessenger` for the whole
     app (every `Scaffold` below it shares that same one), so a message
     shown on one screen visually survives navigating to another (no
     per-route scoping) and a repeated `showSnackBar` call enqueues
     rather than replaces. The same failure mode had already forced one
     call site (Streak/Voice's "coming soon" message) off SnackBar
     entirely once before, onto a dialog (2026-08-24 above) — this fixes
     it generally instead of moving each offending call site one at a
     time.

  Fixed with a single `AppMessenger` helper (`lib/utils/app_messenger.dart`)
  that every existing call site now routes through — `error_banner.dart`
  retired, no parallel path left: a `scaffoldMessengerKey` +
  `NavigatorObserver` wired into `MaterialApp` (`app.dart`) so a route
  change clears a lingering message; `AppMessenger.show` always clears
  before showing so a repeat call replaces rather than stacks; and
  `persist: false` set explicitly so the fixed duration is actually
  honored despite the Dismiss action. Bottom-nav tab switches aren't
  Navigator routes (an `IndexedStack` swap), so app.dart's new
  `_switchTab` clears directly before flipping `_tabIndex`, rather than
  relying on the `NavigatorObserver`, which would never see it. New
  `app_messenger_test.dart` covers all four guarantees (auto-dismiss,
  Dismiss actually closing it, a Navigator push/pop clearing a lingering
  message, and a repeat trigger replacing rather than queuing) end to
  end through a real `MaterialApp`/`Navigator`, not by inspecting
  internals.
- **[Product]** Daily Test's load failure used to surface as a raw
  SnackBar (a type-cast error, an API-key message — whatever the
  underlying exception happened to say) and then leave the screen
  entirely, via the same `_leave()` call every other exit path used —
  hitting a first-time user mid-Day-0-flow with a scary error and no way
  to retry. Given its own in-screen error state instead: reuses
  `EmptyState`'s existing icon+title/description+CTA pattern (deliberately
  not a new visual treatment — a dedicated visual-polish pass is planned
  separately and this batch is explicitly behavior-only) with one human
  sentence and a "Try again" button that calls `_load()` again. The raw
  exception string is shown only `if (kDebugMode)`, directly below the
  human sentence — never in a release build. AppBar title/progress-bar
  conditions switched from checking `!_loading` to checking
  `_dailyTestSet != null`, since the error state also has `_loading ==
  false` but nothing to read `.questions.length` from. New
  `daily_test_screen_test.dart` (an in-memory fake `StorageService`, same
  shape as `first_launch_flow_test.dart`'s own — real
  `sqflite_common_ffi` hangs inside `testWidgets()`'s fake-async binding,
  a landmine that file already hit and documented) drives a flaky fake
  `ClaudeService` through: the error state itself, "Try again" actually
  re-invoking generation, a second failure not crashing, the debug-only
  detail text, and — the invariant locked down last batch — that a
  failed attempt is never cached as today's test, only a real success is.
- **[Engineering]** `StorageService.resetOnboarding` (debug-only): deletes
  the saved profile so `getUserProfile()` is null again — the app's only
  "onboarding complete" signal — without touching practice history,
  theme, or daily caches. Deliberately the opposite scope of the
  existing `resetProgressData` (keeps identity, clears history; this one
  clears only identity). Wired into Settings' "Developer" section
  (alongside A2's entitlement override) as a "Reset first-launch state"
  button, `if (kDebugMode)`-gated the same way — needed to re-trigger the
  Day-0 flow for the upcoming visual-polish pass without reinstalling the
  app each time. Deliberately no confirmation dialog, unlike "Reset
  progress data" right below it: this is a fast, repeatable developer
  action expected to get tapped a lot during that pass, not a real user
  giving up real progress. `app.dart` wires the callback to
  `setState(() => _profile = null)`, the same signal a null profile
  already means everywhere else in the app.
- **[Product]** `flutter analyze` and the full test suite (126 tests)
  clean after every commit in this batch.
