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

## 2026-09-05 (rename: "AI Voice Practice" → "AI Practice Partner")

- **[Product]** Renamed the not-yet-built speaking-mode feature from "AI
  Voice Practice" to "AI Practice Partner" everywhere it's still a live,
  current-state name: the Premium/Early Access screen's coming-soon tile
  (`lib/screens/premium_screen.dart`), its test
  (`premium_screen_test.dart`), and every place `docs/prd-v2.md`/
  `docs/roadmap.md` describe it as a current or still-planned feature.
  Decision: a benefit-focused name ("a practice partner") reads better
  for a coming-soon marketing tile than a name that just states the
  underlying tech ("voice"). The feature itself is still not built — the
  "Coming soon" badge is untouched, nothing about scope or timeline
  changed here, only the label.
  - Deliberately left alone: `docs/build-log.md`'s own past entries
    (this file is a chronological record, not rewritten after the fact —
    they correctly describe what the feature was called *at the time*),
    and a handful of code comments/tests in `home_screen.dart`,
    `analytics_service.dart`, and `home_screen_test.dart` that explicitly
    describe the *old, already-removed* Home grid tile named "Voice
    Practice" (see 2026-09-02 above) — renaming those would misdescribe
    history the same way editing build-log would.
  - Also left alone: the "Streak/Voice" shorthand used in a few places
    in `docs/prd-v2.md`/`docs/roadmap.md` as a compact stand-in for
    "Streak Mode and [this feature]" — not a literal instance of the
    feature's own name, and "Streak/AI Practice Partner" wouldn't read
    as a shorthand at all.

## 2026-09-05 (v2.2 structure batch: Premium screen merge, 7-day trial,
two-plan pricing, disclosure gate)

- **[Product]** `docs/design-audit.md` (new) and `docs/prd-v2.md` §13
  were authored outside this session, ahead of this batch — a
  screen-by-screen review of the app as it looked on device, split into
  system-level causes, screen-specific defects, and taste (only the
  first two justify code changes), plus the decisions it produced.
  Committed as written, not rewritten. This batch implements §13's
  **B-structure** half only (§10.1/roadmap.md's own split): the Premium
  screen merge, the 7-day trial, two-plan pricing, the disclosure gate,
  and pulling unbuilt features off the purchase surface. Home's "today"
  screen rework, the nav-bar overlap fix, the Review duplicate-label
  bug, and demoting Skip on Daily Test are **not** in this batch —
  separate work, tracked in `docs/roadmap.md`.
- **[Engineering]** Merged the Early Access and Paywall screens into one
  `PremiumScreen` (PRD v2 §13.1) across two commits: the free/trial/paid
  table (Early Access's content) followed by the purchase block, price,
  and required disclosure (Paywall's content), initially still a single
  package the way Paywall always worked, then upgraded to a real
  monthly/annual picker. `PaywallScreen` is deleted; every caller (Home's
  locked Topic Practice card and its own Premium row, the Day-0 pitch in
  `first_launch_flow.dart`) now pushes `PremiumScreen`. "Early Access" is
  retired everywhere it named this screen — the AppBar title (now
  "Premium", also fixing Paywall's own AppBar bug where it read "Topic
  Practice"), Home's banner (renamed `_PremiumBanner`),
  `AnalyticsService.modeEarlyAccess` (now `modePremium`, value
  `"premium"`) — while deliberately left alone wherever it names the
  *already-removed* Home grid tile from 2026-09-02, the same
  don't-rewrite-history reasoning as the rename batch above. New
  `PremiumScreen.sourceContext` (nullable): mechanism for a future caller
  to open this screen already naming what prompted it (a specific weak
  spot, per PRD v2 §13.5) — no caller passes a value yet, mechanism only.
- **[Engineering]** Replaced the 3-day trial with 7 days from a single
  source: `SubscriptionService.trialLengthDays`, read by Home's locked
  card, the free/trial/paid table, and the Day-0 pitch — the one place
  "7" is written by hand, so it can't drift between them. The
  purchase/disclosure block itself still prefers the *live* package's
  own `introductoryPrice` over this constant wherever a real product
  exists (unchanged behavior, already correct) — the constant is
  specifically the fallback for copy that has no package to read from.
  A mismatch between what's displayed and what's actually configured on
  App Store Connect is a review rejection reason, not a preference.
- **[Product]** Two-plan pricing (PRD v2 §13.3): monthly and annual,
  annual preselected, the annual plan's big figure showing its
  per-month equivalent with the real annual total underneath and a
  "Save X%" badge. Every figure is read from the two real
  `Package.storeProduct`s — the per-month equivalent is
  `StoreProduct.pricePerMonth`/`pricePerMonthString`, which RevenueCat/
  StoreKit itself computes and formats in the viewer's currency from the
  real annual price (used directly rather than reimplementing currency
  formatting, which risks assuming a "$" prefix that breaks for every
  other currency); the savings percentage compares that figure against
  the real monthly product's price. An offering with only one of the two
  plans configured is treated the same as no offering at all — the
  existing honest "unavailable" state, not a picker with one dead
  option. No invented social proof anywhere on the screen.
- **[Product]** Nothing unbuilt is sold (PRD v2 §13.4): "Unlimited Streak
  Mode" and "AI Practice Partner", both still just "Coming soon" tags on
  the old Early Access screen, are gone from the merged Premium screen
  entirely — that screen now takes money, and Apple expects advertised
  subscription features to actually exist.
- **[Engineering]** The required App Store disclosure block (trial
  length, price after it, renewal period, auto-renews-unless-cancelled,
  Privacy/Terms links) already existed on the old Paywall screen,
  generated from real product data — ported unchanged. Added a real
  pre-submission gate for the one known gap it can't close on its own
  (`AppLinks`' Privacy Policy/Terms URLs still being empty, a known
  launch blocker): `test/app_links_test.dart` is a `skip()`'d test
  asserting those URLs are non-empty, with a loud reason printed on
  every test run, so it can't be silently forgotten without permanently
  turning the suite red (which just trains everyone to ignore red);
  `scripts/preflight.sh` is the actual gate, run right before
  `flutter build ipa` per README's updated Local setup section, exiting
  non-zero naming exactly what's still missing. The existing green
  regression test (legal links render disabled, not dead-but-clickable,
  while the URLs are empty) stays as a separate, permanent test.
- **[Product]** `flutter analyze` and the full test suite (130 passing,
  1 deliberately skipped with a printed reason) clean after every
  commit in this batch.

## 2026-09-05 (Home rebuilt as a "today" screen, PRD v2 §13.5)

- **[Product]** Verified from code, before writing anything, per the
  task's own request: does Daily Test feed the error profile the same
  way Topic Practice does? No.
  `StorageService.insertErrors` — the only write path into
  `error_entries`, which `getWeakSpots` reads — is called from exactly
  one place in the whole codebase, `ResultsScreen._saveErrors` (Topic
  Practice's results screen). `DailyTestService`/
  `DailyTestResultScreen` only ever *read* `getWeakSpots` (to bias
  which topics Daily Test generates), never write to it. Consequence: a
  user who has never had Topic Practice access will never accumulate
  weak spots — Topic Practice is the sole source. Home's weak-spots
  section (item 4 below) genuinely won't render for such a user, not
  "locked", just empty, per its own no-empty-state rule. It *is* real
  and reachable for a user whose trial has since expired but who
  generated weak spots while it was active — that's the actual case
  the "locked row → Premium naming it" behavior serves.
- **[Engineering]** A second, related gap found while tracing this, not
  asked but directly blocking item 2 as written: `daily_test_sets`
  persisted only the question set and a completion timestamp, never
  the user's answers or a score — `DailyTestResultScreen` computed
  everything from an in-memory answers map that vanished once the
  session ended. "Existing data" alone could say whether today's test
  was done, but not what the score was, and there was nothing to
  reconstruct "view the result again" from. Fixed with the minimal
  addition actually needed, not a new tracking system: one nullable
  `answers_json` column on the same `daily_test_sets` row (schema
  v10 → v11, same drop/recreate convention as the rest of the schema).
  `StorageService.markDailyTestCompleted`/`DailyTestService.markCompleted`
  now take the answers map alongside the timestamp;
  `DailyTestResultScreen` skips re-marking completion when reopened
  against an already-completed set (a view-again, not a fresh finish)
  instead of re-writing the same data every time it's viewed. New
  `computeDailyTestScore` (`answer_matching.dart`) gives Home's summary
  an aggregate-only score without duplicating
  `DailyTestResultScreen`'s own per-item detail logic.
- **[Engineering]** Onboarding now assigns `Avatar.random()` when
  building the profile, instead of leaving it null — every new user
  used to see the generic placeholder glyph on Home despite eight
  stock avatars existing, since nobody saw one of them until they
  visited Settings. No schema change: `user_profile.avatar` has been
  nullable since schema v8; this only changes what gets written into
  it. Settings' existing picker still changes it any time.
  `Avatar.random([Random?])` takes an injectable `Random` for
  deterministic tests.
- **[Product]** Home rebuilt from a mode-selection menu into a "today"
  screen (PRD v2 §13.5): two practice cards and a banner, half the
  screen empty since Streak Mode/Voice Practice were removed. Not
  fixed by restoring those cards — they were removed for being dead
  coming-soon tiles, and refilling that space with cards for features
  that don't exist would repeat exactly the mistake removing them
  fixed (`docs/design-audit.md`). The actual gap: Home already had real
  data (today's Daily Test state, the error profile) and showed none
  of it.
  - **Today** (largest, topmost block): Daily Test's real state, read
    directly from `StorageService.getDailyTestSetForToday()` — never
    triggers generation itself. Not solved: an invitation, tapping
    opens Daily Test. Solved: the score plus "new test tomorrow" and a
    tap that replays the existing `DailyTestResultScreen` with the
    persisted answers (see the schema addition above) rather than a
    new screen.
  - **Topic Practice**: unchanged behavior, locked/unlocked as before.
  - **Your weak spots**: the 2-3 most frequent
    (`getWeakSpots(limit: 3, sortOrder: frequent)`, same aggregation
    Review's own "Most frequent" sort already uses). No empty state —
    Review already covers "no weak spots yet", so the section simply
    doesn't render when there are none, per the finding above. Locked
    for a free user; tapping a locked row opens `PremiumScreen` naming
    that weak spot via `sourceContext` — the first real caller of the
    mechanism added in the Premium-screen-merge batch, unused until
    now.
  - **Premium row**: shown only to a free user, demoted from a
    solid-fill banner to a single quiet line (no Card, no fill, no
    elevation) — that treatment made sense when Premium was one of
    only three things on the screen, not once Home leads with real
    data above it.
  - Entitlement transitions still flow through the existing
    `addAccessListener` mechanism, untouched — Topic Practice, the
    weak-spot rows, and the Premium row's visibility all still update
    live without a restart.
  - Noted, not fixed, out of scope for this batch: Review's own
    weak-spot → "Practice this" flow (`practice_launch.dart`) has no
    entitlement check at all — a free user can already reach a real,
    billed Topic Practice generation through Review today, bounded
    only by the daily session cap, not by `hasFullAccess`. Home's new
    weak-spot row is correctly gated per this batch's spec; Review's
    equivalent path predates it and isn't touched here.
- **[Product]** `flutter analyze` and the full test suite (142 passing,
  1 deliberately skipped with a printed reason) clean after every
  commit in this batch.

## 2026-09-05 (Daily Test now feeds the error profile)

- **[Product]** Pre-check, per the task's own request: is "Daily Test
  mistakes don't feed the error profile" a conscious, documented
  decision? Searched `build-log.md`, `prd.md`, and `prd-v2.md` for any
  written rationale. None exists — the gap was found and *noted* in
  the entry directly above this one ("Consequence: a user who has
  never had Topic Practice access will never accumulate weak
  spots... `DailyTestService`/`DailyTestResultScreen` only ever *read*
  `getWeakSpots`, never write to it"), but noting a gap is not the
  same as deciding it should stay a gap, and nothing in any doc argues
  for that. So: not a conscious decision, proceeding to fix it.
  Decision made now, to close that gap: the free tier diagnoses, the
  paid tier treats. Daily Test is free and accumulates the user's weak
  spots; targeted practice on those weak spots is Topic Practice,
  which is subscription-gated. This way the user sees their own
  mistakes before paying, rather than a free tier that produces a
  score with no lasting record and a paid tier that's the only thing
  that ever populates Review.
- **[Engineering]** Implementation, deliberately not a second
  parallel-write path: `ErrorEntry` gained a `source` field
  (`ErrorSource.topicPractice` / `.dailyTest`, schema v11 → v12,
  `DEFAULT 'topic_practice'` since every row written before this
  column existed really was one) so a stored mistake's origin is
  distinguishable — not used by any reader yet, but the task
  anticipated needing it later. `DailyTestResultScreen` now writes
  wrong (never skipped — the existing empty-answer-isn't-an-error rule
  is unchanged) answers through the exact same
  `StorageService.insertErrors` call `ResultsScreen._saveErrors`
  already uses (via a new `DailyTestService.recordErrors` passthrough),
  not a second write path — `getWeakSpots`' aggregation was already
  source-agnostic (`GROUP BY topic_id, error_type`) and stays that way,
  so both flows feed one unified weak-spot view. Guarded on the same
  "is this a fresh finish, not a re-view" check `_markCompleted`
  already had, so reopening an already-completed set (Home's "view
  result again") doesn't re-log the same mistakes and inflate their
  frequency.
  Daily Test has no LLM scoring call, so its records are honestly
  thinner than Topic Practice's, not padded to look equivalent:
  `explanation` is set to `AnswerMatchResult.comment` exactly —
  non-null only when the wrong answer matched a predicted common
  mistake with a real pre-written comment, null otherwise. Never the
  screen's own generic "Not quite — here's the correct answer." display
  fallback, and never an invented explanation from an extra LLM call
  made just to fill the field. `errorType` falls back to the
  question's `topicId`, since Daily Test has no finer per-mistake
  classification the way Topic Practice's LLM scoring produces one —
  the coarsest true category available, not a fabricated finer one.
  Tests: a wrong Daily Test answer is written and tagged
  `ErrorSource.dailyTest`; a skipped one is not; a match with a real
  comment keeps it; a match with none stays null (and is asserted to
  not contain the UI's own fallback text); reopening a completed set
  writes nothing a second time; both sources aggregate into the same
  `WeakSpot` when topic and error type match.
- **[Product]** `flutter analyze` and the full test suite (154
  passing, 1 deliberately skipped) clean after every commit in this
  batch.

## 2026-09-05 (Home's Premium row: readable contrast + benefit line)

- **[Engineering]** Fixed: Home's Premium row was near-invisible —
  pale gray text on the orange page background, the same contrast
  defect `docs/design-audit.md` already flagged elsewhere. Root cause:
  the row uses `colorScheme.onSurfaceVariant`, a muted gray meant for
  text on a neutral surface (a Card), but this row deliberately has no
  Card of its own and sits directly on the scaffold — which in light
  mode is the vivid orange `primary` (see `theme.dart`'s role
  mapping). That pairing measures ~3.6:1, failing AA for body text.
  Fixed by switching to `theme.appBarTheme.foregroundColor` — the
  color the app bar already uses for content on this same background
  (`onPrimary` in light mode, contrast-checked in `theme.dart`;
  `onSurface` in dark mode, where the scaffold isn't orange) — rather
  than inventing a third color role.
  Also now states what Premium actually offers ("Unlock targeted
  practice on your weak spots") instead of just the word "Premium",
  matching `PremiumScreen`'s own pitch-copy tone. Still a plain row —
  no Card, no fill, no elevation — so it stays quieter than the Today
  card above it. This is a readability fix only; the row gets a fuller
  visual-polish pass later.
- **[Product]** `flutter analyze` and the full test suite (156
  passing, 1 deliberately skipped) clean after this commit.

## 2026-09-05 (B-structure batch: nav bar clipping, duplicate weak-spot
label, wrong-field card title, Skip demotion)

Four items from `docs/design-audit.md`'s B-structure list
(`docs/roadmap.md` §2), one shared mechanism/widget per item rather than
per-screen patches, each landed as its own commit.

- **[Engineering] Nav bar overlapping scrollable content (S4).** Every
  tab screen (Home, Review, Settings) padded its scroll view by a fixed
  guessed constant (`navBarClearance = 110`,
  `lib/utils/layout_constants.dart`) meant to clear the floating nav
  bar. The guess didn't actually match the bar's real footprint — its
  own visual chrome plus the device's bottom safe-area inset, which
  varies by device — closely enough, so on some devices content stayed
  clipped behind the bar even scrolled all the way to the end: Home's
  Premium row's bottom half, Settings' Save button and "Data" heading.
  Fixed with one mechanism instead of three guesses: extracted the
  floating nav bar (previously built inline in `app.dart`) into
  `FloatingNavShell` (`lib/widgets/floating_nav_shell.dart`), which
  measures the bar's actual laid-out height via a `GlobalKey` after
  every frame that could change it and publishes that number through a
  `NavBarClearance` `InheritedWidget`. The three tab screens now read
  `NavBarClearance.of(context)` instead of the old constant, which is
  removed along with `layout_constants.dart`. Tests scroll a tab's
  content to its absolute end on a simulated device with a real
  safe-area inset and assert nothing is left behind the bar — the exact
  case the old fixed guess got wrong.

- **[Engineering] Duplicated topic label and wrong-field card title on
  weak spots.** Reported before changing anything, per the task:
  `home_screen.dart`'s `_WeakSpotRow` and `review_screen.dart`'s inline
  card were two separate, already-drifted copies of the same layout,
  both building the subtitle as `'${topic.title} ·
  ${humanizeSlug(spot.errorType)}'`. For a Daily Test-sourced weak spot,
  `spot.errorType` *is* `topic.id.name` (Daily Test has no finer
  per-mistake classification than its topic — see `ErrorSource`'s doc
  comment, 2026-09-05 batch above), and `humanizeSlug` is specifically
  built (its "vs" → "vs." rule) to turn that id back into the exact same
  string as `topic.title` — so for such a record the two halves of that
  label were never two different facts; printing both printed the same
  fact twice ("Gerund vs. Infinitive · Gerund vs. Infinitive"). The
  card's title had a related bug: `spot.latestExplanation ??
  humanizeSlug(spot.errorType)` meant a Topic Practice record (real
  explanation) showed a truncated mid-sentence fragment of that
  explanation as its title, while a Daily Test record showed the
  topic/error-type name only because that branch happened to be the
  fallback, not by design.
  Fixed both by extracting the shared `WeakSpotCard`
  (`lib/widgets/weak_spot_card.dart`) — the duplication is exactly how
  the two copies drifted in the first place — and changing what each
  part shows: title is always `humanizeSlug(spot.errorType)`, which is
  never less specific than the topic (Topic Practice's errorType is a
  finer classification under it; Daily Test's errorType is the topic id
  itself), with the explanation moved to its own line in the body,
  never standing in for the title. The topic-name subtitle renders only
  when it differs from the title, so a Daily Test record's card shows
  the topic name once, not twice. Tested with a record shaped like each
  source.

- **[Product] Skip demoted from primary on question screens (D3).** On
  both `DailyTestScreen` and `PracticeScreen`, the single primary
  `FilledButton` doubled as "Skip" whenever the answer field was empty —
  the biggest, most filled control on the screen invited abandoning the
  question (`docs/design-audit.md`: two consecutive audit runs on Daily
  Test finished 0/5 correct, 5 skipped). Fixed with one shared widget,
  `PracticeStepFooter` (`lib/widgets/practice_step_footer.dart`, the
  bottom-button row was previously identical inline code in both
  screens): the primary button is always Submit/Next/Finish, never
  "Skip", and disabled while the field is empty — including on the last
  question, which previously stayed a big enabled Submit/Finish even
  unanswered. Skip is its own quiet `TextButton` below the primary row,
  always present rather than conditionally shown, reachable but not
  inviting. The disabled primary button uses an explicit
  `surfaceContainerHighest`/`onSurfaceVariant` pairing (the same one
  `_PracticeModeCard`'s locked state already uses) instead of Material's
  default translucent disabled treatment, which — composited over this
  app's orange scaffold — is exactly what made onboarding's disabled
  "Continue" nearly invisible; an unstyled Skip `TextButton` would have
  repeated the Restore Purchases orange-on-orange bug the same way, so
  both are explicit. Confirmed the same bug pattern existed verbatim on
  Topic Practice's question screen (identical `_primaryLabel`/
  `_currentHasAnswer`/`_advance` shape) and applied the same fix there,
  per the task's own instruction to check before assuming Daily Test was
  the only place it applied.

- **[Product]** `flutter analyze` and the full test suite (176 passing,
  1 deliberately skipped) clean after every commit in this batch.

## 2026-09-06 (Anthropic API key moved behind a Cloudflare Workers proxy)

Closes the "API key safety" pre-launch blocker (`docs/roadmap.md`,
decision taken 2026-09-05): the key compiled into the shipped binary via
`--dart-define` is extractable from any built app. Cloudflare account
created, `wrangler login` done, this batch builds and deploys the proxy
and rewires the client to it.

- **[Product] Why operation-based, not a forwarding proxy — the actual
  design decision here.** A forwarding proxy (client sends the same
  Anthropic-shaped request, proxy just reattaches the key) would have
  been far less code, but it wouldn't have closed the blocker it exists
  to close: the request today (model, system prompt, JSON schema,
  `max_tokens`) is built entirely client-side, so a forwarding proxy
  still lets anything holding the app token send an arbitrary system
  prompt and arbitrary `max_tokens` through a real API key — the key
  would be safe from static extraction but not from a client that's been
  decompiled or simply reverse-engineered by watching its traffic. It
  also can't validate anything meaningful (a "request" is just an opaque
  blob to forward) and can't reason about cost per operation, since it
  has no concept of what operation is even happening.
  Operation-based means the client sends a named operation
  (`generate_practice_set` / `generate_daily_test` / `score_answers`)
  and a small structured payload — a topic id, a count, a device id, a
  list of weak-spot `{topicId, frequency}` pairs, or already-extracted
  item `{id, type, prompt, userAnswer}` fields — and the proxy itself
  owns the model, every system prompt, every JSON schema, and
  `max_tokens`, all ported as-is from `ClaudeService` (scanned the
  actual call sites first, per the task's own instruction — these three
  are the complete list; all three went through one `_post` method).
  This is what actually makes the rest of the design possible: strict
  per-operation field validation (unexpected fields rejected, not
  ignored), a fixed known topic-id list so the client can never inject
  its own title/description text into a prompt, and a quota that means
  something (bounding real operations, not opaque bytes). A forwarding
  proxy could do none of that.

- **[Engineering] The proxy itself** (`proxy/`, its own `wrangler.jsonc`/
  `package.json`, not part of the Flutter build):
  - `src/auth.ts`: a build-time app token in an `x-grammarlens-token`
    header, constant-time compared. Known extractable from a shipped
    binary like any client-side value — filters casual/automated
    scanning, explicitly not the sole defense.
  - `src/validation.ts`: strict allowlist per operation, string/array
    size caps, topic ids checked against `src/topics.ts` (mirrors
    `lib/data/topics.dart` — duplicated on purpose, not shared, since
    this is a separate deployable with no access to the Dart source).
  - `src/quota.ts`: per-device and global daily caps in Workers KV,
    reserved *before* the Anthropic call (counts the attempt, not just
    a success — that's what actually bounds spend). Documented
    non-atomic tradeoff (`proxy/README.md`): two near-simultaneous
    requests can both read the same pre-increment count. Accepted at
    this project's traffic scale, not a Durable Object problem yet.
  - `src/anthropic.ts`: never forwards Anthropic's raw error body to the
    client — every failure maps to a generic `upstream_error`, with
    detail logged server-side only (`wrangler tail`).
  - Tested with `@cloudflare/vitest-pool-workers` (real Workers runtime
    via Miniflare, not a Node approximation): auth, per-operation
    validation, quota (device cap, global cap, UTC-day reset), and the
    full fetch handler with Anthropic's own call mocked — including a
    test asserting the client's `deviceId` and app token never leak
    into the request Anthropic actually receives. 39 tests, `tsc
    --noEmit` clean.

- **[Engineering] The Flutter side.** `AppConfig` no longer holds an API
  key at all — just `proxyBaseUrl`/`appToken`. `ClaudeService` is now a
  thin client: build the small payload, POST to the proxy, parse the
  same `{items}`/`{questions}`/`{feedback}` shape Anthropic always
  returned (the proxy forwards that shape verbatim on success, so this
  parsing code didn't need to change at all). `ClaudeApiException`
  gained a `kind` (`ClaudeApiErrorKind`) so a screen can special-case
  what it needs without knowing the proxy's error-code strings;
  `DailyTestScreen`'s error state now shows accurate copy for
  quota-exceeded specifically (no "check your connection" — nothing is
  wrong with the connection and retrying can't succeed until tomorrow;
  no "Try again" CTA for the same reason). Added
  `StorageService.getOrCreateDeviceId` (schema v13): a random,
  app-generated id, never a real device attribute — anonymous by
  construction, not just by policy — deliberately *not* dropped on a
  future schema bump the way every other table here is, since losing it
  on an unrelated change would reset a real install's quota identity
  more often than intended.

- **[Engineering] Dev workflow.** No second Anthropic key went back into
  the app for local development. `scripts/dev.sh` now starts the proxy
  locally too (`wrangler dev`, backgrounded, skipped if something's
  already listening on its port) before running `flutter run` — one
  command for both halves. A developer's own Anthropic key now only
  ever needs to exist in one place on a dev machine:
  `proxy/.dev.vars`. `scripts/preflight.sh` gained the requested check:
  a release build's `config/prod.json` must exist with a non-empty
  `PROXY_BASE_URL` and `APP_TOKEN`, same "missing this silently breaks
  every API call in the shipped build" reasoning the existing AppLinks
  check already used.

- **[Product] Deployed and verified end-to-end on-device**, with one
  environment-specific wrinkle worth recording honestly: this sandbox's
  network egress blocks Cloudflare's Workers anycast IP range outright
  (confirmed by DNS resolving `grammarlens-proxy.aetayfur78.workers.dev`
  correctly but a raw TCP connect to the resolved IP on 443 timing out,
  from both `curl` in this shell and the iOS Simulator itself — not a
  DNS or app-level problem, a network-level one specific to this
  sandbox). Cloudflare's own control-plane API (a different host) was
  reachable throughout, so `wrangler secret put`
  `ANTHROPIC_API_KEY`/`APP_TOKEN`, `wrangler deploy`, and `wrangler
  deployments list` all completed and confirm the Worker is live.
  For the actual on-device round trip, verified instead against
  `wrangler dev` running locally with the real Anthropic key (same
  source `wrangler deploy` just shipped, exercised on localhost instead
  of the blocked `workers.dev` hostname) from the real iOS Simulator
  app, via a temporary hook in `main()` calling the three real
  `ClaudeService` methods directly with real `StorageService`/
  `AppConfig` — deliberately not a fake harness screen, the actual
  production call sites, removed after this verification (no diff left
  in `lib/main.dart`). Confirmed on-device: `generatePracticeSet`,
  `scoreAnswers`, and `generateDailyTestQuestions` all round-tripped
  successfully; then, with `DEVICE_DAILY_LIMIT` temporarily overridden
  to 2 (via `wrangler dev --var`, never touching the committed
  `wrangler.jsonc`) and that device's count already past it from the
  successful run above, the next call correctly threw
  `ClaudeApiException` with `kind: ClaudeApiErrorKind.quotaExceeded` and
  the clean "You've reached today's practice limit..." message — proving
  the real device → real Worker → real KV quota path end-to-end. The
  corresponding UI (`DailyTestScreen`'s quota-specific empty state) is
  covered by its own widget tests rather than an interactive screenshot
  here, since this environment has no tap-automation path into a real
  running simulator (the same constraint noted in earlier "temporary
  debug harness" entries above).

- **[Product]** `flutter analyze` and the full test suite (191 passing,
  1 deliberately skipped) clean; proxy `npm test` (39 passing) and `npm
  run typecheck` clean.

## 2026-09-07 (proxy on a permanent custom domain; AppLinks filled in; legal
links actually open)

Ahmet bought `ahmettayfur.com` through Cloudflare Registrar (same
Cloudflare account, same DNS zone) specifically so the proxy could sit on
a permanent hostname instead of the `workers.dev` subdomain the previous
batch shipped with. The Cloudflare dashboard couldn't attach the domain
yet (zone too new for the UI to find it), so this was done via
`wrangler` directly, per explicit instruction not to attempt any
workaround (a manual DNS record, a different hostname) if that hit the
same "zone not found" wall — it didn't.

- **[Engineering] `api.ahmettayfur.com` is now the proxy's permanent
  address.** `proxy/wrangler.jsonc` gained a `routes` entry
  (`{ "pattern": "api.ahmettayfur.com", "custom_domain": true }`) —
  `custom_domain: true` is what makes Cloudflare provision the DNS
  record and SSL cert itself on deploy, rather than a plain route
  pattern that expects the record to already exist. `wrangler deploy`
  completed with no zone error and the domain confirmed live
  (`curl https://api.ahmettayfur.com/health` → `ok`). Deliberately
  scoped to only the `api` subdomain, never the apex or `www` — both
  independently re-confirmed still serving Ahmet's existing site
  (200/301) after the deploy, untouched.
- **[Engineering] A side effect the deploy itself surfaced, not
  something planned going in:** adding a `routes` entry makes Wrangler
  default `workers_dev` to disabled unless explicitly set to `true` —
  so the previous `grammarlens-proxy.aetayfur78.workers.dev` address
  (confirmed dead by a timed-out `curl` right after) stopped working
  the moment the custom domain went live. `config/prod.json` was still
  pointing at that address, so it — and its template
  `config/prod.example.json` — were updated to `api.ahmettayfur.com`
  too, even though the task only named the dev configs: leaving prod
  on a dead route was a real regression, not a scope judgment call.
- **[Product/Engineering] `config/dev.json`, `config/dev.example.json`,
  and README's "Local setup" now point at the live proxy by default**,
  not `wrangler dev` on localhost — the permanent domain makes that the
  simpler default, and this task's own verification step asked for
  exactly that ("test against the live address, not `wrangler dev`").
  Consequence traced through and fixed rather than left half-done:
  `config/dev.json`'s `APP_TOKEN` had to become the real deployed
  secret (confirmed working with a manual `curl` — wrong token → 401,
  real token → a normal validation `400`, never 401) since "any string"
  only ever worked against a locally-configured `wrangler dev`.
  `scripts/dev.sh` no longer unconditionally starts a local proxy: it
  reads `PROXY_BASE_URL` out of `config/dev.json` first and only spins
  up `wrangler dev` when that's still a `localhost` address, so pointing
  `dev.json` back at `localhost:8787` (fully offline proxy development,
  still supported) keeps behaving exactly as before.
- **[Product] `AppLinks` filled in** (`lib/utils/app_links.dart`):
  `privacyPolicyUrl`, `termsUrl`, and a new `supportUrl` (not consumed by
  any screen yet — reserved the same way `PremiumScreen.sourceContext`
  was added ahead of its first caller) now point at
  `ahmettayfur.com/products/grammarlens/{privacy,terms,support}/`. The
  URLs are permanent; the pages themselves currently carry placeholder
  copy being written separately — confirmed by actually opening the
  live Privacy Policy page (below), which visibly still reads as a
  drafting template. `test/app_links_test.dart` lost its `skip:` and is
  now a real, permanent assertion instead of a loud reminder;
  `scripts/preflight.sh`'s `check_app_link` was fixed alongside it — its
  single-line grep pattern stopped matching once `dart format` wrapped
  the now-long `static const String ... = '...'` declarations across
  two lines, so it was rewritten to join the declaration line with the
  one after it before extracting the value. Re-ran preflight after: both
  checks now pass for real, not just by coincidence of short URLs.
- **[Engineering] The Premium screen's Privacy Policy/Terms buttons
  actually open something now.** They previously carried a `// TODO:
  launch url once AppLinks has a real value` and an empty `() {}`
  `onPressed` — correct at the time (no `url_launcher` dependency, no
  real URL to launch to), but exactly the gap this batch's own
  verification step was asked to close. Added `url_launcher`
  (`pubspec.yaml`), wired `_LegalLink._open` to
  `launchUrl(uri, mode: LaunchMode.externalApplication)` with an
  `AppMessenger.show` fallback if the platform can't open it.
  `premium_screen_test.dart`'s legal-links regression test was flipped
  from asserting `onPressed` is null (true while `AppLinks` was empty)
  to asserting it's non-null now that the URLs are real — kept as a
  permanent regression test either way, per its own original comment's
  intent.
- **[Product] Verified on the real iOS Simulator against the live
  `api.ahmettayfur.com` proxy** (not `wrangler dev`): the full Day-0
  flow — Welcome → onboarding → a real `generate-daily-test` call
  against the live proxy → 5 real questions rendered and answered →
  real deterministic grading ("1/5 correct · 1 skipped", individual
  correct/needs-work/skipped cards) → the paywall pitch → Premium
  screen. Screenshotted at each step. Tapping **Privacy Policy** on the
  Premium screen genuinely opened Safari to the real, live
  `ahmettayfur.com/products/grammarlens/privacy/` page (confirmed by
  screenshot — visibly placeholder/drafting-note content, as expected).
  One incidental content-quality observation from a live-generated Daily
  Test question, noted here but **not investigated or fixed** (out of
  this batch's scope — a possible LLM content-generation issue, not
  confirmed as a client/proxy bug): a fill-in-the-blank item's "YOU
  WROTE" and "CORRECTED" fields both read `cooking` yet were marked
  "Needs work."
  - **Correction to the 2026-09-06 entry above**, found while doing
    this: that entry states "this environment has no tap-automation
    path into a real running simulator." This session found one that
    worked for a good stretch — `osascript`'s `System Events "click at
    {x,y}"`, invoked from a script **file** rather than an inline `-e`
    string (the inline form errored where the file form didn't, cause
    not fully understood), plus `cliclick`-driven drags for scrolling.
    One real mistake made getting there: a `cliclick` drag issued
    without first explicitly reactivating the Simulator app moved the
    whole Simulator *window* across the screen instead of scrolling its
    content — corrected by always sending `tell application "Simulator"
    to activate` immediately before any click or drag, after which
    scrolling worked correctly and repeatably. This let onboarding, the
    Daily Test question flow, and Premium-screen navigation all be
    driven by genuine synthesized taps rather than a debug harness.
    It stopped being reliable partway through this same session,
    though: `System Events` began refusing every further click with
    "osascript için yardımcı erişime izin verilmiyor" (-25211,
    accessibility access denied) and didn't recover on retry or after
    explicitly re-activating Simulator — cause also not fully
    understood (a permission that silently lapsed mid-session, not one
    that was ever explicitly revoked). So: a real, better-than-previously-
    documented mechanism exists, but it is not yet a *reliable* one —
    worth a future session re-establishing rather than assuming either
    "impossible" (the old entry) or "solved" (what this entry might
    otherwise imply) going in.
  - **Topic Practice's real generation + scoring were verified**, but
    not by tapping through the UI, since the above permission failure
    happened before reaching that screen: a temporary test file
    (`test/_tmp_live_e2e_verification_test.dart`, same technique as the
    2026-09-06 entry's temporary `main()` hook — real production
    `ClaudeService` methods, deleted after use, never committed) called
    `generatePracticeSet` then `scoreAnswers` against the live proxy
    directly. Both round-tripped successfully: 3 real generated items
    for the Articles topic, 3 real scored feedback entries back.
    Terms of Service specifically (as opposed to Privacy Policy) was not
    independently re-tapped after the permission failure — the identical
    `_LegalLink` code path makes a different result very unlikely, but
    it genuinely wasn't re-confirmed, so this is recorded as not done
    rather than assumed.
- **[Product]** `flutter analyze` and the full test suite (192 passing,
  0 skipped — `app_links_test.dart` losing its `skip:` moved the count
  from 191+1 to a plain 192) clean; proxy `npm test` (39 passing) and
  `npm run typecheck` clean; `scripts/preflight.sh` passes.

## 2026-09-07 (dev config reverted to local-by-default; Turkish-keyboard
letter variants no longer scored as grammar mistakes)

Two unrelated fixes, both surfaced by using the previous batch's live-proxy
work: the dev config default it left in place was actively costing real
money on every local run, and the live verification itself typed a Turkish-
keyboard character into a Daily Test answer and got marked wrong for it.

- **[Product] Dev config default reverted to local `wrangler dev`.**
  Pointing `config/dev.json` at the live proxy by default was correct for
  that batch's one-off verification step but was never meant to be the
  ongoing default — left as-is, every local `./scripts/dev.sh` run spends
  a real Anthropic request and eats into production's shared daily quota.
  `config/dev.json` and `config/dev.example.json` are back to
  `http://localhost:8787` / a local dev token; `config/prod.json` and
  `config/prod.example.json` are untouched (still the permanent
  `api.ahmettayfur.com`, correctly). `scripts/dev.sh` itself needed no
  logic change — it already only skips starting a local proxy when
  `dev.json` points somewhere other than localhost, so reverting the
  config alone restored its original "start `wrangler dev` for me"
  behavior; only its own header comment (which had started describing the
  live URL as the default) was corrected back. README's "Local setup"
  reverted to leading with local dev, with one added paragraph — not a
  mechanism — on temporarily pointing `dev.json` at the live proxy for a
  one-off test, explicit that both values must be reverted afterward and
  why (real spend, real quota).
- **[Product] Typos-vs-grammar-errors reopened** (`docs/roadmap.md`
  "Carried over", already updated separately): the 2026-08-24 check found
  no issue, but never tested the actual failure mode — a Turkish keyboard.
  Confirmed live during the previous batch's own on-device verification:
  "cookıng" (dotless ı) against expected "cooking" was marked "Needs
  work" with no explanation, and — since Daily Test now feeds the error
  profile (2026-09-05) — would have written a gerund/infinitive weak spot
  the user doesn't actually have. Scoring was working exactly as
  designed; the gap was that "same word, different keyboard" was never a
  case the design considered.
- **[Engineering] Why a fixed letter-substitution table, and specifically
  not a general fuzzy-match/edit-distance rule** — the actual design
  decision here, spelled out because the tempting simpler fix is the
  wrong one. "Allow answers within one edit of the correct answer" would
  also catch this case, with far less code. It was rejected: GrammarLens's
  entire question mix is built around production tasks where a single
  character *is* the grammar point being tested — "stay" vs. "stays"
  (agreement), "go" vs. "went" is two characters but "hope" vs. "hoped"
  is one, "a" vs. "an" is one. A generic small-edit-distance tolerance
  would silently mark those correct too, forgiving the exact mistake the
  question exists to catch. The fix instead folds a closed, named set of
  seven Latin-letter pairs — ı/i, İ/I, ş/s, ğ/g, ç/c, ö/o, ü/u — that are
  never a grammatical distinction in English under any circumstance, so
  folding them can never rescue a real grammar error; it can only equate
  two spellings of the same word. Locked down with an explicit regression
  test (`stay` vs. `stays` still scores wrong) sitting right next to the
  keyboard-variant tests, specifically so a future "just use Levenshtein
  distance" refactor has to look at it and fails loudly if it would
  change that result.
- **[Engineering] Client-side (Daily Test's deterministic grading).**
  `lib/utils/answer_matching.dart`: new `foldKeyboardVariants` (the
  six-letter fold table above — case is already handled by
  `normalizeAnswer`'s own `toLowerCase()`, which was verified to already
  collapse İ/I to plain `i` in Dart specifically, so the table only needs
  the lowercase Turkish letters that survive that step) and a new
  `AnswerMatchKind.keyboardVariant`, checked in `checkDailyTestAnswer`
  against the correct answer specifically — before the predicted
  common-wrong-answer loop, so a fold-match against the *correct* answer
  always wins over incidentally resembling a wrong prediction.
  `AnswerMatchResult.comment` carries a short note naming the specific
  differing letter(s) (built from a genuine character-by-character diff,
  not a canned string, so "değişik" typed as "degisik" names both ğ/g and
  ş/s). `computeDailyTestScore` (Home's aggregate summary) counts this
  kind as correct, matching the per-item screen.
  `DailyTestResultScreen`: `_QuestionResult.isCorrect` now includes
  `keyboardVariant` — this alone makes it count toward the score, never
  show "Needs work", and never reach `_saveErrors`' error-profile write
  (which filters on `!isCorrect`) — no separate exclusion list to keep in
  sync. The one behavior that needed its own branch: a keyboard-variant
  match is correct but must still show its note (per the task: "doğru
  sayılsın ama sessizce geçilmesin"), so `_QuestionResultCard`'s
  explanation logic checks for it before falling back to "no commentary
  on a correct answer."
- **[Engineering] LLM-side (Topic Practice's free-sentence scoring).**
  Checked first, per the task's own instruction, before assuming the
  client-side function applied: confirmed by reading the code path, not
  guessed. Topic Practice has no local deterministic comparison at all —
  `ResultsScreen` sends the raw answer straight to
  `ClaudeService.scoreAnswers`, which is a real Claude call
  (`proxy/src/anthropic.ts`'s `SCORING_SYSTEM_PROMPT`) that judges
  correctness itself; `answer_matching.dart` is Daily-Test-only code and
  was never on this path. So the fix here is a prompt change, not a
  shared function: `SCORING_SYSTEM_PROMPT` gained an explicit paragraph
  naming the same seven-letter set and the same two rules the client
  enforces — mark `isCorrect: true` for a letter-substitution-only
  difference, mention it briefly in the explanation rather than staying
  silent, and (mirroring the "stay" vs. "stays" carve-out) explicitly
  telling the model this does not excuse a real one-character grammar
  difference. A new proxy test
  (`test/index.test.ts`, "instructs the model not to score Turkish-
  keyboard letter variants as grammar mistakes") asserts the actual
  request body sent to Anthropic contains both the letter-set instruction
  and the real-mistake carve-out — the only thing verifiable without a
  live model call, but enough to catch the prompt text being silently
  edited away later.
- **[Product] Tests**: `answer_matching_test.dart` — identical answer
  (plain correct, not a variant), the exact reported ı/i case, a
  case-only difference (still plain `correct`, confirming the two paths
  don't overlap), leading/trailing whitespace around a variant answer,
  a genuinely wrong answer, a skipped answer, the "stay"/"stays"
  real-mistake carve-out, and a multi-letter-difference case naming both
  pairs. `daily_test_result_screen_test.dart` — a keyboard-variant answer
  writes nothing to the error profile, and renders as "Correct" (never
  "Needs work") with its note visible. Proxy: the system-prompt content
  assertion above. `flutter analyze` and the full test suite (204
  passing, 0 skipped) clean; proxy `npm test` (40 passing) and `npm run
  typecheck` clean.

## 2026-09-08 (visual polish tour: brand mark, session-length picker,
Premium comparison table + reorder + pricing states, question-screen
buttons)

Start of the B-polish work `docs/roadmap.md` §2 scoped after B-structure
(above). Several independent decisions, each recorded here because none of
them were written down anywhere before this entry.

- **[Product] Brand mark: sparkle → hand-drawn loupe.** The generic
  `Icons.auto_awesome_rounded` sparkle used as a placeholder identity mark
  since early on is replaced by `BrandMark` (`lib/widgets/brand_mark.dart`),
  a hand-drawn magnifying glass painted with `CustomPainter` in a fixed
  100x100 space and scaled to any requested size — no new dependency, no
  image asset. Deliberately meant to become the single source app-icon
  generation draws from later, not just a Welcome-screen decoration. Rim
  color follows `colorScheme.secondary` (the D2 single-blue role below); the
  glass fill/glint are fixed brand-identity colors, not theme roles, defined
  as named constants in `theme.dart`. Checked before writing this: the old
  sparkle icon closed `docs/design-audit.md`'s "brand mark reused as a
  feature icon" complaint by disappearing outright — `Icons.auto_awesome`
  no longer appears anywhere in `lib/`.
- **[Product] Session-length dialog → draggable bottom sheet.** Closes
  `docs/design-audit.md`'s "muddy scrim" finding, but the actual redesign
  reason is interaction, not color: three tappable cards in an `AlertDialog`
  became a single 3-stop `Slider` in a modal bottom sheet, because a
  selection you can't clearly see how to make counts as not being there —
  the stock `Slider` thumb (a plain filled circle) doesn't read as
  draggable on its own, which matters specifically here since dragging is
  the screen's entire interaction. Replaced with a custom thumb (a filled
  circle with two small chevron strokes pointing left/right) that visibly
  signals "drag me." Dragging live-previews the choice in a big selection
  card; a full-width "Start N questions" button confirms it. Scrim tinted
  off `colorScheme.onSurface` at 42% instead of black, fixing the "muddy
  brown over orange" complaint as a side effect of the redesign, not the
  goal of it. `PracticeLength` itself and the picker's public contract
  (`Future<PracticeLength?>`, null on cancel) are unchanged.
- **[Product] Selection card's number → fill-ratio dial.** The card's big
  number became an 84px ring whose filled fraction is
  `questionCount / (the largest questionCount across PracticeLength.values)`
  — derived from the enum, never a hardcoded ratio per option (unit-tested
  directly via the extracted `practiceLengthDialRatio()`). Two decisions
  made alongside it, neither written down before now:
  - **Rejected: coloring the card itself per option** (e.g. green for the
    shortest/3-question option, red for the longest/10-question option).
    Green and red already carry a fixed meaning throughout this app —
    correct and incorrect (`SemanticColors`, used on every results screen).
    Reusing them here to mean "short" and "long" would contradict that
    meaning the first time a user reaches a results screen after picking
    the "red" session length. The card's background stays
    `secondaryContainer` regardless of which option is selected.
  - **The dial shows no duration.** Nothing in this product measures how
    long a 3/5/10-question session actually takes (no per-session timing is
    recorded anywhere in `StorageService`), so a minutes label on the dial
    would be invented, not measured. The ring encodes question count only —
    stated directly in the widget's own doc comment so a future change
    doesn't add a duration guess without noticing this was deliberate.
- **[Product] Premium's benefit list → a Free/Premium comparison table.**
  Closes `docs/design-audit.md` S3 (the same component — icon circles —
  carrying two different color languages across screens): the two-tile
  "Everything in Free, plus" icon-circle list is replaced by a table
  reading the same five real features PRD v2 §13.4 already allows, nothing
  invented. Purely a layout change — purchase logic, price/product
  sourcing, the disclosure block, and the restore flow are all untouched,
  same classes and code paths.
- **[Product] Premium reordered so price is reachable without scrolling —
  diagnosis before the change, not after.** Measured against the layout
  this replaced, at a 390x844 viewport (the size this app already tests
  against elsewhere): reaching "Start free trial" required scrolling
  **1357px past an 844px viewport** — more than the entire viewport height
  again, after two long description cards and the comparison table above
  them. That number is the actual reason for the reorder below, not an
  aesthetic call. Three hypotheses were tested for why the price section
  was unreachable: (H1) the expected two-card plan picker didn't exist yet
  (it was a `SegmentedButton`) — confirmed; (H2) an empty product list was
  silently hiding the section — not the cause, the section still rendered,
  just poorly; (H3) the section existed but sat far below the fold with no
  scroll affordance — confirmed as the dominant cause by the 1357px figure
  above. Fix: reordered to title → headline → comparison table → two
  side-by-side plan cards (Annual preselected, a computed "Save N%" badge,
  never hardcoded) → a compact one-sentence trial/renewal disclosure →
  "Start free trial" → "Maybe later" → legal links, with the two long
  description cards removed entirely (the table already carries the
  free/premium difference). At 390x844 with pricing loaded, everything
  from the title bar through the primary button now fits without
  scrolling.
- **[Product] The three pricing-area states, closing a real launch
  blocker, not just a nicety.** Reachable via H2 above: a paywall that
  can't fetch its products and silently shows nothing is a real App Review
  rejection reason, not a hypothetical one. The price-card slot now has
  three explicit states — loading (a static skeleton shaped like the two
  cards, not an unrelated spinner), loaded (the real cards), and
  unavailable (a compact one-row message with an inline "Try again" that
  re-triggers the fetch) — replacing a slot that previously either showed
  a generic spinner or nothing distinguishable from "loaded with zero
  options."
- **[Product] Question screens: Back/Close moved to the app bar; Skip
  demoted beside Next, not below it.** On both `DailyTestScreen` and
  `PracticeScreen`: Back moves from the bottom footer to the app bar's
  top-left as a 40x40 bordered circle icon button in the on-band
  foreground color; Close takes the equivalent top-right slot. The
  progress bar now shares a row with the "N / M" counter instead of
  stacking separately. Skip moves from a quiet text link below the primary
  button to an `OutlinedButton` beside it, at a fixed width clearly
  narrower than the primary `FilledButton` (52 tall, 12px gap) — still
  demoted per D3 (docs/design-audit.md), just no longer text-only, since a
  bare text link was reading as too easy to miss entirely on real devices.
  The one structural requirement this needed solving: on question 1, where
  there is no valid Back destination, the button's 40x40 footprint is
  preserved as an invisible placeholder (`HeaderCircleIconButton`'s
  `visible` flag) rather than the button being omitted — omitting it would
  shrink the app bar's leading slot and shift the centered title sideways
  the moment Back appears on question 2. Verified directly: a widget test
  asserts the title's on-screen center x is identical on question 1 (Back
  hidden) and question 2 (Back visible).
- **[Engineering]** `lib/spacing.dart` (a named 4/8/12/16/24/32/48 scale)
  landed alongside the D2 color fix, but this is a foundation only —
  adopted in the screens touched this round (Welcome, the length picker,
  the debug-only Theme Preview screen) and not migrated across the rest of
  the app. Recorded as open in `docs/roadmap.md`'s B-polish list, not as
  done.
- **[Engineering] Known debts surfaced this round, left open rather than
  quietly fixed or silently ignored:**
  - **The FittedBox(scaleDown) fix on the comparison table's "PREMIUM"/
    "FREE" headers works against Dynamic Type.** It was added to solve a
    real overflow (the label wrapped to two lines at the specified
    12px/w700/tracked size in a 56px column on-device) by treating that
    size as a maximum rather than a fixed value — correct for the overflow
    case, but the same mechanism silently shrinks the label back down
    whenever a user's own larger accessibility text size would otherwise
    make it grow, defeating that preference specifically on this label.
    Not fixed here — needs a real column-width fix, not another scale-down
    layer.
  - **Light theme's disabled `FilledButton` is still hard to read on the
    orange scaffold.** `theme.dart`'s `filledButtonTheme` sets explicit
    enabled colors but no explicit disabled ones, so a disabled
    `FilledButton` without its own override (onboarding's "Continue" is the
    concrete case — confirmed unfixed by reading `onboarding_screen.dart`)
    still falls back to Material's default translucent-disabled treatment,
    which reads as dark-orange-on-orange. This is expected to be resolved
    by D1 (orange stops being the page background almost everywhere), not
    patched button-by-button ahead of it.
  - **The widget-test suite's animated screens are only ever exercised with
    reduced motion, never their real animation path.** Not because it's set
    globally and never cleared — checked directly: every file that sets
    `accessibilityFeaturesTestValue` (`widget_test.dart`,
    `first_launch_flow_test.dart`, `practice_length_picker_test.dart`)
    already clears it via `tearDown`/`addTearDown`, correctly scoped to
    that file. The real gap is narrower: any test that reaches Welcome or
    the length picker *has* to force reduced motion first, or
    `pumpAndSettle()` hangs against their infinite ambient animations — so
    the suite has no test anywhere that runs those two screens' real,
    non-reduced animation code path (the breathing mark, the sonar rings,
    the dial's 200ms tween) at all.
  - **flutter analyze and the full test suite (227 passing) are clean as
    of this entry** (verified directly, not carried over from a commit
    message) — this covers the state of the repo as of this documentation
    pass, not a claim about every individual commit above having been
    re-verified.

## 2026-09-09 (D1 Batch 3: question screens, Onboarding, Loading)

- **[Engineering] `BrandScaffold` gained a fully custom `appBar` slot.**
  The question screens' `QuestionAppBar` (Back/Close/progress row) has
  nothing in common with a plain title bar, so forcing it through
  `title`/`leading`/`actions` wasn't an option — `appBar` replaces the
  whole built-in `AppBar` when set, mutually exclusive with `title` and
  enforced by the same kind of constructor assertion as `children`/`body`
  (passing both, or neither, fails immediately rather than picking one
  silently). `QuestionAppBar` sets its own `scrolledUnderElevation: 0` to
  match the same call `BrandScaffold`'s own app bar makes, since it's now
  building its `AppBar` independently.
- **[Product] Keyboard-open layout verified on-device, in both themes, for
  both question screens — this batch's actual risk, not assumed.**
  `docs/design-audit.md` §4 recorded this as an explicit gap ("the
  question screen wasn't captured with the keyboard open; the keyboard-
  aware layout has a history of issues there"), and `BrandScaffold` is now
  the single owner of padding/scroll for every migrated screen — exactly
  where a regression would land if one existed. Confirmed by screenshot in
  all four combinations (DailyTestScreen/PracticeScreen × light/dark) with
  the keyboard genuinely open (not simulated): the band stays pinned, the
  answer field sits directly above the keyboard, Skip/Next stay reachable,
  and the layout correctly returns to its resting state once the keyboard
  closes. Verifying this needed two unrelated workarounds, recorded here
  since they're likely to recur: (1) cliclick-driven taps on the simulator
  were unreliable again this session (a calibration tap on a large,
  unambiguous target — Skip — produced no state change at all after
  several coordinate-mapping attempts), so focus was driven
  programmatically instead (`FocusScope.of(context).nextFocus()`, traced
  via debug prints first to find the right call count rather than
  guessed — PracticeScreen's app bar Close button takes the first call and
  the answer field's `EditableText` the second; DailyTestScreen's pushed
  route absorbs one additional call into its own modal focus scope first,
  so it takes three); (2) genuinely focusing the field didn't show a
  software keyboard at all until "Connect Hardware Keyboard" was found
  checked in the Simulator's own I/O ▸ Keyboard menu (a `defaults write`
  toggle plus an app restart did not clear this — only unchecking the menu
  item directly did) — reverted back to its original state afterward,
  since it's a machine-level preference outside the repo, not something
  this batch should leave changed.
- **[Product] Onboarding's disabled "Continue" button — the audit's worst-
  rated contrast finding — closed, measured rather than assumed fixed.**
  Migrating onto `BrandScaffold` put the button on the neutral body
  instead of the vivid orange page, with no button-level change at all
  (`onboarding_screen.dart`'s `FilledButton` is untouched). Pixel-sampled
  the actual rendered label/background colors on-device rather than
  trusting the theory: light mode's disabled fill/label render as
  `#DFD9D3`/`#94918F` (~2.24:1), dark mode's as `#343337`/`#77767A`
  (~2.78:1). Both sit below WCAG's 4.5:1 normal-text threshold, but WCAG
  1.4.3 explicitly exempts inactive/disabled controls from contrast
  requirements, and this is Material 3's own standard disabled-button
  convention (`onSurface` at reduced opacity over the surface it sits on),
  not a residual defect introduced or left by this batch. The actual
  complaint — a button that read as blank because its label and
  background shared the same hue — is gone; no follow-up patch is needed
  for this specific button.
- **[Engineering] `LoadingView` no longer paints its own background.**
  Previously `ColoredBox(color: theme.scaffoldBackgroundColor)` — always
  redundant (every `Scaffold` it sits in already paints that color behind
  `body` on its own) and actively wrong the moment a host `Scaffold`'s
  background diverges from the ambient theme default, which
  `BrandScaffold` does deliberately (neutral body vs. the old band color).
  Left inside a `BrandScaffold` body unchanged, it would have silently
  repainted the pre-D1 band color under itself, erasing the neutral look
  specifically during loading. Fixed by removing the `ColoredBox` and
  trusting the host's own fill — correct in both the migrated and
  not-yet-migrated case, no special-casing. Scope was deliberately not
  extended past this: the audit's separate "no real progress signal"
  finding for Loading stays out of scope, exactly as asked — this batch
  only moves the widget, it doesn't add one.
- **[Engineering]** `test/practice_screen_keyboard_test.dart`'s "tapping
  outside the text field dismisses the keyboard" test tapped the question
  header's `Card` as a stand-in for "somewhere away from the field" —
  that `Card` is gone (this batch's kart kuralı removal, see the D1 status
  entry in `docs/roadmap.md`), so the test now taps the instruction text
  instead; the same ancestor `GestureDetector` still owns the dismiss.
- **[Product]** `flutter analyze` and the full test suite (227 passing)
  clean.

## 2026-09-09 (D1 Batch 4: results screens, Premium, cardTheme retirement — D1 closed)

- **[Product] Daily Test Results, Topic Practice Results, and Premium
  migrated onto `BrandScaffold`** — the last three screens D1's rollout
  needed. Welcome remains the one deliberate exception.
- **[Engineering] New `ResultScoreBand` (`lib/widgets/result_score_band.dart`)
  is the first real use of `BrandScaffold`'s `bandBottom` slot**, reserved
  for exactly this since Batch 1. Both result screens now show their score
  the same way — in the band, not the body — because they share one widget,
  not because two screens independently chose to agree. Verified on-device,
  both screens, both themes: the band carries "N/M correct" (plus "· K
  skipped" when applicable) in identical position and type style on Daily
  Test Results and Topic Practice Results alike.
- **[Engineering] `BrandScaffold` gained `automaticallyImplyLeading`**, a
  plain pass-through to the built-in `AppBar`'s own field — Premium needs
  it `false` to suppress the automatic back chevron a pushed route would
  otherwise get, since its own Close action already covers dismissal.
- **[Product] Scope held exactly where asked** — none of the following were
  touched this batch, all recorded as separate future work: the skipped-
  answer "CORRECTED" box's green tint (a candidate for the same
  neutral-conversion D1 gave other components), Premium's
  `FittedBox(scaleDown)` header's Dynamic Type debt, a second exit path
  from Topic Practice Results.

### Scoped `cardTheme` override retired — D1's exit plan, executed

This was committed to in Batch 1/2 (`docs/roadmap.md`) as D1's mandatory
last step, precisely because leaving it undone would let
`docs/design-audit.md` S3's "the same component carries two color
languages" pattern reappear permanently for cards: a `BrandScaffold` card
using `surfaceContainerHigh` via a local `Theme` override while any
not-yet-migrated screen's card still read `cardTheme`'s app-wide
`surfaceContainerLow` default. Once Batch 4 left every screen except
Welcome on `BrandScaffold`, that split had nothing left to be scoped
against.

- **[Engineering] `lib/theme.dart`'s app-wide `cardTheme` now carries the
  values directly** — `color: colorScheme.surfaceContainerHigh`,
  `elevation: 1`, `shape: RoundedRectangleBorder(... side:
  BorderSide(color: colorScheme.outline))` — the same three values
  `BrandScaffold`'s local override used, with their measured reasoning
  moved into this file's own comments rather than left in a widget that no
  longer needs to state them: the previous `elevation: 6` reasoning was
  written for the pre-D1 all-orange scaffold and is now stale (superseded
  by the border as the primary signal, per the `elevation: 1` decision
  earlier this round); the `outline` vs. `outlineVariant` measurement
  (~3.11:1/~2.72:1 light, ~5.05:1/~4.20:1 dark vs. ~1.34:1) is repeated
  here since this is now the values' permanent home.
- **[Engineering] `lib/widgets/brand_scaffold.dart`'s local `Theme(data:
  theme.copyWith(cardTheme: ...))` wrapper is deleted outright**, not left
  as a no-op — `body` now renders directly under the ambient theme. Four
  stale doc comments referencing the removed override or the "migrates one
  batch at a time" framing were also updated (class-level, the
  `backgroundColor` inline comment, and the `body`/`appBar` field docs).
- **[Product] Every card-bearing screen from all four batches re-verified
  on-device, both themes, against the app-wide default — not sampled.**
  Home, Topic list, Review, Weak-spot detail, Settings, Daily Test Results,
  Topic Practice Results: 14 screenshots (7 screens × 2 themes) via a
  temporary `SCREEN=`-switched debug harness, deleted before committing.
  All fourteen show the same border+reduced-elevation card treatment as
  before the retirement, now sourced from the shared default instead of
  the widget-local one — no regression on any screen.
- **[Product]** `flutter analyze` and the full test suite (227 passing)
  clean after the retirement. Committed separately from the screen
  migration, per plan (`db6e039`), since the two are independently
  revertible changes.

### D1 closed

Four batches, `docs/design-audit.md` §5 and `docs/roadmap.md` both updated
to reflect it. One item D1's own work surfaced is deliberately left open
rather than folded into this closure: Onboarding's disabled "Continue"
button's label readability. D1 fixed the bug the audit actually described
(label and background sharing one hue, reading as blank) but the resulting
~2.24:1/~2.78:1 contrast, while a real improvement and within Material 3's
disabled-control convention, is still under WCAG AA's normal-text
threshold — whether that's worth addressing further is a separate,
still-open design question, recorded as such in both docs rather than
silently marked done alongside D1.

## 2026-09-10 (App icon; Batch 0 — contrast/states + consistency; D1's test gap)

Three independent commits, each verified on-device in both themes via a
temporary, untracked debug harness (`lib/main_debug_harness.dart`, a
separate entry point — never touches `main.dart`/`app.dart`), deleted before
committing. `flutter analyze` and the full test suite clean throughout.

### App icon

- **[Engineering] `flutter_launcher_icons` generates every iOS icon size
  from one source (`assets/icon/app_icon.png`).** A real 1024px icon (a
  loupe/magnifying glass on navy, matching `BrandMark`'s identity) had been
  dropped into `ios/Runner/Assets.xcassets/AppIcon.appiconset/` but
  `Contents.json` still referenced Flutter's default placeholder filenames —
  the new icon was never actually wired up. Two options were on the table:
  hand-convert `Contents.json` to a single-size (1024-only, Xcode
  auto-generates the rest) format, or use `flutter_launcher_icons` to
  generate every explicit size. Chose the generator: this app's
  `IPHONEOS_DEPLOYMENT_TARGET` is 13.0, and the single-size format's actual
  minimum-OS requirements weren't worth the risk of getting wrong on a
  pre-launch app with a real (if old) deployment floor. *(Superseded
  2026-09-16 — the floor is 15.0 now, forced by the Xcode toolchain no
  longer supporting a simulator build below it. See that date's own
  entry.)* `ios: true,
  android: false` — no Android release track exists, so `android/`'s icon
  is deliberately untouched. `remove_alpha_ios: true` matches the source,
  which already has no alpha channel (confirmed: `file` reports "8-bit/color
  RGB", not RGBA) and no baked-in corner rounding — both are App Store
  requirements, Apple applies its own mask.
- **[Engineering] Reverted one unintended side effect of running the
  generator.** `flutter_launcher_icons`' icon-name patcher
  (`ios.dart:changeIosLauncherIcon`) matches any Xcode build setting whose
  name contains `ASSETCATALOG`, not just the one it means to set
  (`ASSETCATALOG_COMPILER_APPICON_NAME`) — it also clobbered
  `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` from `YES`
  to `AppIcon` in two of the three build configurations. Caught by diffing
  `project.pbxproj` after running the tool rather than assuming a clean
  generator run; reverted that one setting back to `YES`, unrelated to app
  icon naming. `ASSETCATALOG_COMPILER_APPICON_NAME` itself was already
  correctly `AppIcon` before and after — confirmed the final diff against
  `project.pbxproj` is empty.
- **[Product] Verified with a clean build, not assumed.** `flutter clean`
  (which also surfaced and required fixing an unrelated stale Swift Package
  Manager artifact-cache reference — a known issue after `flutter clean` on
  a project with Firebase's SPM-based pods; resolved by letting Xcode
  re-resolve packages with network access rather than reusing a now-missing
  local cache path) then a real run on the iOS simulator: returned to the
  home screen and screenshotted it — the actual generated icon (not the
  Flutter default) is what's installed.
- Deleted the now-orphaned original `AppIcon-1024.png` from inside the
  appiconset folder (not referenced by the regenerated `Contents.json`,
  redundant with the new canonical `assets/icon/app_icon.png` source).

### Batch 0 — contrast/states + consistency (`docs/design-audit.md` D5)

Nine decisions, four with a correction applied before implementing — full
review and reasoning in `docs/design-audit.md`'s own per-finding status
notes and D5 summary; `docs/roadmap.md`'s B-polish checklist has the
consolidated list. Implementation detail not already covered there:

- **[Product] `MistakeBreakdown`'s skipped-answer fix derives skippedness,
  never takes it as a parameter.** The correction to this item's original
  proposal: passing `isSkipped` as a bool would require both result screens
  (Topic Practice's `ResultsScreen`, `DailyTestResultScreen`) to pass the
  right value every time, and one forgetting would silently reintroduce the
  exact bug being fixed. Checked whether the fact is already derivable
  before accepting the correction: `ClaudeService.scoreAnswers` computes
  `ItemFeedback.isSkipped` from the same "is the trimmed answer empty" check
  `DailyTestResultScreen`'s own `_QuestionResult.from` uses, and that's
  exactly the condition `MistakeBreakdown`'s existing `hasAnswer` local
  already computed for a different reason (whether to show the "YOU WROTE"
  box at all) — so `isSkipped = hasCorrection && !hasAnswer` is the same
  fact, not a new one, and can't drift from what each screen actually did.
  Weak-spot detail's call is provably unaffected: every `ErrorEntry` it
  reads is filtered to `!isSkipped` before being written by both screens'
  own `_saveErrors`, so `hasAnswer` is always true there.
- **[Product] Avatar palette redesigned as a named exception, not derived
  from `ColorScheme`.** The correction: avatar colors reading as semantic
  (a green avatar next to this app's actual green "correct" color) would be
  worse than the original problem. Eight hues spaced roughly evenly (35°,
  70°, 105°, 145°, 185°, 240°, 280°, 310° — computed to keep pairwise
  separation ≥30° and stay ≥18° clear of this app's correct-green (~123°)
  and error-red (~0°) hues) at one fixed saturation/lightness (60%/56%),
  replacing a set where fox/lion shared one hue and panda/koala shared
  another. Named constants in `theme.dart` (`avatarFoxBackground` etc.),
  same pattern as the existing `brandMarkGlass`/`brandMarkGlint` precedent,
  referenced from `avatar_tile.dart` rather than inlined as raw hex there.
  Verified on-device in both themes, at the actual 22-radius tile size used
  by both Settings' picker grid and Home's greeting tile, glyph contrast
  included (each avatar's emoji renders in its own colors regardless of
  tile background, so the actual risk was tile-vs-tile distinctness and
  tile-vs-surface visibility, not glyph legibility).
- **[Product] `LockedPremiumPill` replaces a 16px lock glyph, in the same
  trailing slot both `_PracticeModeCard` and `WeakSpotCard` already used for
  a plain chevron.** The correction: before removing the chevron, checked
  what tapping a locked card actually does today — the whole `Card` is
  already one `InkWell` opening `PremiumScreen`, on both card types, so the
  chevron was the only visible "this goes somewhere" signal for an
  already-real conversion path. The pill keeps that signal built into
  itself (a chevron drawn inside the pill, after the "Premium" label)
  rather than requiring a second icon alongside it, so dropping the old
  standalone chevron doesn't remove what it was for.
- **[Product] Back button: direction chosen after review, not decided
  unilaterally.** Built both candidate directions as real, on-device
  mockups — Direction A (spread `HeaderCircleIconButton`'s bordered circle
  to every screen's back button) and Direction B (drop it, plain chevron
  everywhere) — each showing a question screen and a normal screen
  (Results), in both themes, and sent all four screenshots before
  implementing either. Direction B chosen. `HeaderCircleIconButton` renamed
  to `HeaderIconButton` (the old name would be actively misleading now) with
  the `CircleBorder`/border-color styling dropped; the footprint-reservation
  behavior it exists for (a constant 40x40 box whether or not Back is
  usable, so question 1→ question 2's title never shifts) is unchanged and
  still covered by its existing regression test. `DailyTestScreen`'s
  pre-load Close button (shown before a question set exists, styled to
  match `QuestionAppBar`'s own Close per that call site's own doc comment)
  updated to match.
- **[Product] Daily Test's progress bar removed from `QuestionAppBar`
  (shared by both question screens).** Kept the "N / total" counter, which
  told the same story more precisely for this app's small fixed session
  lengths (3/5/10). `_bottomHeight` reduced 40→28 to match the now-simpler
  single-line content, closing the audit's "header stacks three signals"
  complaint as a side effect of removing one of the three.
- **[Engineering] Settings' Profile/Data `Card` wrap removed**, matching
  Appearance's already-cardless layout — flagged but deliberately left open
  in the 2026-09-09 D1 Batch 4 entry above ("a third, not-yet-named
  justification... revisit once every screen has migrated"); revisited now
  since D1 finished migrating every screen. Surfaced a real, unrelated test-
  layout bug while verifying: four `settings_screen_test.dart` cases scrolled
  with a fixed pixel `drag()` amount calibrated against the old, taller,
  card-wrapped layout. `ListView`'s `Sliver` machinery estimates the extent
  of not-yet-built off-screen children and corrects that estimate (grows it)
  once more items get built during a scroll; the shorter post-fix layout
  changed where that correction landed relative to a fixed drag amount,
  leaving the target below the fold. Diagnosed with a throwaway probe test
  printing `ScrollPosition.maxScrollExtent`/`pixels` before and after the
  drag (deleted once understood, never committed) rather than guessing at
  a new magic number. Fixed by switching to `tester.dragUntilVisible`, which
  is robust to this regardless of exact content height.
- **[Product] Topic list's three-line cards top-align the leading icon**
  against the title (`CrossAxisAlignment.start` on the card's `Row`,
  previously the default `center`) instead of centering it against the
  whole title/description/stats block, where it read as sitting low. The
  trailing chevron is wrapped in its own 44-tall `SizedBox`+`Center` so it
  stays centered within the icon's own height band rather than inheriting
  the same low-against-three-lines problem the fix addresses.

### D1's test gap (`docs/roadmap.md`'s B-polish checklist)

- **[Engineering] `test/brand_scaffold_test.dart` (new).** Both
  constructor asserts (`body`/`children`, `title`/`appBar` — exactly one of
  each required) verified to actually throw, both violation directions each
  (both provided, neither provided). `isTabRoot: true` reads
  `NavBarClearance.of(context)`'s real value; `isTabRoot: false` (the
  default) uses `MediaQuery.paddingOf(context).bottom + 16` and ignores an
  ancestor `NavBarClearance` even when one happens to be present — both
  verified by inspecting the built `ListView`'s own `padding.bottom`.
- **[Engineering] `test/results_screen_test.dart` (new).** Topic Practice's
  own `ResultsScreen` had no test file at all before this. Added narrowly
  for this batch's actual ask — confirming it renders its score through the
  shared `ResultScoreBand`, the same widget `DailyTestResultScreen` uses —
  rather than building out a full test suite for the screen, which is a
  separate, larger gap not in this round's scope. Fixture deliberately has
  zero non-skipped-incorrect items, so `_saveErrors` returns before calling
  `StorageService.insertErrors`, letting the test use a real (non-fake)
  `StorageService`/`AnalyticsService` — both already fail safe with no
  platform channel under test.
- **[Engineering] `daily_test_result_screen_test.dart` gained the
  equivalent `ResultScoreBand` check**, reusing its existing four-outcome
  fixture (one correct, one wrong-matching-a-prediction, one wrong-matching-
  nothing, one skipped) rather than adding a new one.
- **[Engineering] `test/mistake_breakdown_test.dart` (new).** Direct
  regression coverage for the skipped-answer fix above: a skipped item's
  correction renders in the neutral box labeled "CORRECT ANSWER" (not the
  green "CORRECTED" a real mistake still gets), checked both by the
  rendered text and by reading back the actual `Container`'s `BoxDecoration`
  color against `colorScheme.surface`/`SemanticColors.correctBackground`.
- **[Product]** 237 tests passing (up from 227 throughout D1), `flutter
  analyze` clean.

## 2026-09-14

- **[Engineering]** First install and run on a physical iPhone — every prior
  verification in this log was simulator-only. Device: iPhone 14 Plus, iOS
  26.6.2, UDID `00008110-00064D5801B9401E`, signed with the paid team
  `37U9L67C2J`. Command: `flutter run
  --dart-define-from-file=config/prod.json -d <UDID>`.
- **[Product]** `scripts/dev.sh` doesn't work on a physical device: it points
  at `config/dev.json`, which targets `localhost` — on the phone, `localhost`
  means the phone itself, so every proxy call fails. Real-device testing has
  to go through `config/prod.json` (the live Cloudflare Worker), which spends
  a real `DEVICE_DAILY_LIMIT` unit against the real quota, unlike simulator
  runs against a dev config. Worth deciding later whether README's "Local
  setup" section should call this out explicitly — not done as part of this
  entry, flagged for a separate decision.
- **[Engineering]** Two misleading Xcode 26 errors hit during signing/first
  launch, both with a root cause other than what the error text suggests:
  1. Signing panel: "Communication with Apple failed" / "your team has no
     devices". Not an account problem — the run destination was still set to
     "Any iOS Device (arm64)". Switching the destination to the actual
     connected iPhone let Xcode generate a real provisioning profile.
  2. After a successful build: "Timed out waiting for
     CONFIGURATION_BUILD_DIR to update". The app had already installed; iOS
     was refusing to launch it until the device verified the signing
     certificate online. Resolved by giving the phone internet access and
     opening the app once by hand.
- **[Engineering]** No extra setup needed for wireless debugging: Xcode 26
  has dropped the "Connect via network" checkbox, and an iOS 17+ device
  connects automatically over Wi-Fi once paired — `flutter devices` lists it
  as `(wireless)` on the same network with no prior pairing step in this
  session.
- **[Product]** This was a `flutter run` install, not a TestFlight build —
  `docs/prd-v2.md` §10.1's real-device/TestFlight verification is still
  open, nothing has been uploaded to TestFlight yet.

## 2026-09-15 (free-tier "Practice this" leak — diagnosis + fix)

- **[Product]** A device-verified bug reported: a free user completes
  onboarding's Daily Test, sees the paywall, taps "Maybe later" — and Home
  correctly locks Topic Practice behind it. But Review's weak-spot →
  `WeakSpotDetailScreen` → "Practice this" button had no entitlement or
  quota check at all, so a free user could trigger real, billed Topic
  Practice-grade generation from there indefinitely (bounded only by the
  generic `dailySessionLimit` cost cap shared by everyone, 10/day). This
  wasn't a fresh regression — it was noted and explicitly deferred in this
  file's 2026-09-05 entry ("Home rebuilt as a 'today' screen": *"Review's
  own weak-spot → 'Practice this' flow has no entitlement check at all ...
  Home's new weak-spot row is correctly gated per this batch's spec;
  Review's equivalent path predates it and isn't touched here"*). This
  batch closes it.
- **[Engineering] Root cause, diagnosed before any code changed.**
  `launchPracticeSet` (`lib/screens/practice_launch.dart`) is the single
  function every real practice-set generation goes through — its own doc
  comment already called it the shared choke point. It checked exactly one
  thing: the blanket `dailySessionLimit` cap, applied regardless of
  entitlement. Entitlement (`SubscriptionService.hasFullAccess`) was only
  ever checked inside `HomeScreen`'s own tap handlers, as a *navigation
  guard* ("should I let you open this screen"), never inside the function
  that actually starts generation ("should I let this generation happen").
  `ReviewScreen._openWeakSpot` pushes `WeakSpotDetailScreen` unconditionally
  — no `SubscriptionService` even in scope there before this batch — so its
  "Practice this" button inherited zero protection. Confirmed by grep: only
  two call sites of `launchPracticeSet` exist in the whole codebase
  (`TopicPracticeScreen`, `WeakSpotDetailScreen`); Daily Test's own
  generation is a separate, already-correctly-capped path
  (`DailyTestService.getTodaysSet` caches by local calendar day, confirmed
  a failed attempt is never cached); no other entry point (a results
  screen "try again", a deep link) exists to audit. Also confirmed: no test
  file existed for either `review_screen.dart` or
  `weak_spot_detail_screen.dart` at all — the only reason this shipped
  unnoticed for as long as it did.
- **[Product] Fix policy, decided ahead of writing code:**
  - The check moves *into* `launchPracticeSet` itself as required, shared
    logic — a new required `subscriptionService` parameter, not a boolean
    either caller could pass to skip it. Both real callers now go through
    the identical check.
  - `hasFullAccess == true`: unchanged, only `dailySessionLimit` applies —
    no new limit for premium.
  - `hasFullAccess == false`: checked against a new, named constant,
    `StorageService.freeDailyPracticeLimit = 1` — the free tier's one real
    "Practice this" session per day. Limit reached routes to the same
    `PremiumScreen` Home's locked card already opens (no separate "limit
    reached" dialog invented for this — the ask was explicitly for the same
    feel as Home's existing lock).
  - Free session length: no picker, generates `PracticeLength.quick`
    (3 questions) directly. Before this fix a free session reaching this
    path could pick the most expensive length (10 questions) for free —
    closed alongside the entitlement gate itself, not left for later.
  - Storage: a new, independent `free_practice_usage(day, session_count)`
    table — deliberately not sharing `daily_session_usage` (the blanket
    cost cap) or `daily_test_sets` (Daily Test's own cache), matching PRD
    v2 §12.2's three structurally separate tiers. Same local-calendar-day
    reset convention as both of those (`StorageService._todayKey()`).
  - Quota is spent on generation *success*, at the exact moment
    `recordSessionStarted()` already fires — a failed generation (network,
    parse error) never burns the day's one free session.
  - Onboarding's Day-0 Daily Test never touches this counter — confirmed by
    a new test asserting the fake storage's `getFreePracticeCountForToday`/
    `recordFreePracticeStarted` are never called during that flow, not just
    assumed from reading the code.
  - Review's weak-spot list itself stays visually unlocked
    (`WeakSpotCard(locked: ...)` still defaults to `false` there) —
    reading your own past mistakes is genuinely free; only the practice
    action on the detail screen is gated. Home's own list is unaffected.
  - **Copy check, done before writing new copy:** grepped `lib/` and
    `PremiumScreen`/the old paywall specifically for any existing
    "unlimited" claim — found none. New copy for this batch (the caption
    naming the remaining free count, and the exhausted-state subtitle)
    also avoids the word deliberately: premium is bounded by
    `dailySessionLimit` (10/day), so "unlimited" would be a false
    subscription claim (both a "no fake it" violation and a real App
    Review risk).
- **[Engineering] Implementation, one small piece at a time:**
  1. `StorageService`: `freeDailyPracticeLimit` constant,
     `free_practice_usage` table (schema v13 → v14, same drop/recreate
     convention as `daily_session_usage`/`daily_test_sets`),
     `getFreePracticeCountForToday`/`recordFreePracticeStarted` mirroring
     the existing session-cap methods exactly. Also added
     `StorageService.clockForTesting` (`@visibleForTesting`, same seam
     pattern as `SubscriptionService.debugModeForTesting`) — `_todayKey()`
     now reads through it, letting a test prove a day-keyed counter
     actually resets on a new calendar day without waiting for one; no
     existing day-keyed counter had a test for this before.
  2. `AnalyticsService`: two new events, `free_practice_used` and
     `free_practice_quota_exhausted` — without them there's no way to tell
     after launch whether `freeDailyPracticeLimit = 1` is the right number,
     or whether the quota is actually converting anyone.
  3. `launchPracticeSet`: the entitlement + quota gate, ordered before the
     existing `dailySessionLimit` check (the free quota is the smaller,
     more specific boundary); the length-picker branch now depends on
     `hasFullAccess`. `TopicPracticeScreen` and `WeakSpotDetailScreen` both
     gained a required `subscriptionService` field, threaded from
     `HomeScreen`/`ReviewScreen`. `app.dart` now holds one shared
     `SubscriptionService` instance passed to both `HomeScreen` and
     `ReviewScreen`, instead of `ReviewScreen` having none at all and
     `HomeScreen` defaulting to its own.
  4. `WeakSpotDetailScreen`'s bottom action gained two states: unchanged
     enabled button plus a caption naming the remaining free count when
     quota is available (nothing shown for a premium user — no quota to
     name); a locked row when exhausted, in the *exact* visual language
     `HomeScreen`'s locked Topic Practice card already uses — same muted
     icon-avatar treatment, and the existing `LockedPremiumPill` widget
     reused verbatim, not reimplemented. Tapping it opens `PremiumScreen`
     with `sourceContext` naming the weak spot, the same mechanism
     `HomeScreen._openWeakSpot` already uses.
- **[Product] Tests: 14 new, 251 passing overall (up from 237),
  `flutter analyze` clean.** New coverage: the choke point proven through
  *both* real callers with identical fakes (quota available → generates
  the shortest set directly, skips the picker; quota exhausted →
  generation is never called, routes to Premium instead) —
  `TopicPracticeScreen`'s case proves `launchPracticeSet`'s own internal
  gate fires even without a screen-level lock UI in front of it (defense in
  depth, the actual point of moving the check into the shared function);
  premium unaffected even with the free counter already over its limit (a
  new-check-is-a-no-op-for-premium test); the free-practice table's own
  day rollover via the new clock seam, real ffi-backed
  (`storage_service_free_practice_test.dart`); the onboarding-independence
  invariant above; and `WeakSpotDetailScreen`'s own visual states (enabled
  button + caption, locked row + `LockedPremiumPill`, premium shows no
  caption, "unlimited" never appears in any of it).
- **[Product] Not done in this batch, recorded as an open decision:**
  found while tracing proxy quota math for the free tier (1 Daily Test +
  1 free practice session = 3 proxy units/day, comfortably under
  `DEVICE_DAILY_LIMIT`'s 15) that a *premium* user's existing
  `dailySessionLimit` (10 sessions/day × 2 proxy units each = up to 20) can
  already exceed that same 15-unit device limit — independent of anything
  in this batch, not fixed here. Recorded in `docs/roadmap.md`'s pre-launch
  checklist as an open pre-launch decision (raise `DEVICE_DAILY_LIMIT` to
  ~25, or lower `dailySessionLimit` to 7).

## 2026-09-15 (avatar picker: layout-bug diagnosis, carousel replacement,
illustrated avatar set)

- **[Product] Bug report, device-verified:** picking the last avatar in
  the first row of Settings' avatar grid made the grid itself visibly
  reflow — everything below it jumped down. Diagnosis done and confirmed
  before any code changed, one paragraph, per the task's own request:
  `AvatarTile` (`lib/widgets/avatar_tile.dart`) rendered a fixed
  `side × side` box for the unselected state, but wrapped that same box
  in an *additional* `Container` with `padding: EdgeInsets.all(2.5)` and
  a 2.5px `border` whenever `selected == true` — and since that outer
  `Container` had no explicit `width`/`height` of its own, it sized
  itself to "child + padding," making the selected tile's footprint
  `side + 5` logical pixels in both dimensions instead of `side`. The
  picker laid these out in a `Wrap` (not a `GridView`), which greedily
  fills each row up to the available width and only breaks to a new line
  once a tile no longer fits; growing one tile by 5px exactly at a row
  boundary was enough to push it (and everything after it) over that
  width threshold, so tapping the last tile in a row made the `Wrap`
  recompute where lines break and visibly reflow everything below it.
  Confirmed exactly as hypothesized — no surprises once traced.
- **[Product] The fix is structural, decided before writing the
  replacement:** selection state must never change a widget's own layout
  footprint — a ring/scale/pop is drawn *inside* a slot whose outer size
  is already fixed regardless of selection, never added around it via
  border+padding. Closing this the "same shape as the bug" way (a
  smaller border, a max-width clamp) would have just made the threshold
  harder to hit, not removed it — the actual fix is architectural: no
  code that draws a selection state may report a different size for the
  same content.
- **[Engineering] Picker replaced with a carousel, not just patched.**
  `AvatarCarousel` (`lib/widgets/avatar_carousel.dart`): a `PageView`
  (`viewportFraction: 0.45`) where the centered avatar *is* the selection
  — no separate confirm button. Neighbors continuously track drag
  position (scale ~0.8, opacity ~0.5 at one page away, computed from
  `pageController.page`, not a binary snapped state) so dragging feels
  smooth. Settling (via `NotificationListener<ScrollEndNotification>`,
  not `onPageChanged`, which fires mid-drag) fires
  `HapticFeedback.selectionClick()`, a one-shot ~180ms pop
  (`TweenSequence<double>` 1.0→1.06→1.0) on the settled tile, and
  `onSettled(avatar)`. Selection itself is a *separate* ring layer — one
  `AnimatedContainer` behind the `PageView` in a `Stack`, fixed
  width/height, recolored (never resized) whenever the settled avatar
  changes. This is the actual fix, not a different picker shape wearing
  the same bug: nothing about selecting an avatar here can change any
  widget's own size, because the thing that changes (the ring's fill
  color) lives in a box whose size was never a function of selection to
  begin with.
  - `AvatarTile` lost its `selected` parameter entirely instead of
    keeping a fixed-but-dead knob that already caused one real bug —
    after the ring moved into the carousel's own layer, nothing
    anywhere in the app still needed `AvatarTile` to draw a selection
    state itself. Confirmed by grep before removing it.
  - Reduced-motion (`MediaQuery.disableAnimationsOf`) zeroes both the
    pop's and the ring's animation duration, same pattern
    `practice_length_picker.dart` already established — not a new
    convention.
  - Reused, both inline: `OnboardingScreen` embeds `AvatarCarousel`
    directly above the name field ("face + name" as one identity screen,
    no new onboarding step — a random avatar is selected on mount, per
    the existing "no empty state" rule this app already applies
    elsewhere); `AvatarPickerScreen` (`lib/screens/avatar_picker_screen.dart`)
    pushes it from Settings, autosaving on settle (debounced 500ms so a
    fast multi-swipe writes once, not once per settle along the way; a
    pending debounce is flushed on `dispose()` so leaving mid-window
    doesn't lose the change) and `Hero`-flying the centered tile back to
    Settings' own preview row on pop. The carousel widget itself stays
    `Hero`-agnostic — an optional `centerTileBuilder` hook lets
    `AvatarPickerScreen` wrap just the settled tile in a `Hero`, without
    `OnboardingScreen` (which has no push/pop boundary to animate across)
    needing to know `Hero` exists at all.
- **[Product] The avatar set itself is illustrated now, not emoji.**
  Twelve pre-existing assets (`assets/avatars/avatar_01.webp`–
  `avatar_12.webp`, already in the repo, 508×508, transparent, ~360KB
  total — not created or renamed this batch), registered in `pubspec.yaml`
  as a folder (`assets/avatars/`), not listed file-by-file. `Avatar`
  (`lib/models/avatar.dart`) is rewritten as a plain class generated from
  one `count` constant (12) rather than the previous 8-case `enum` —
  `values` holds `count` singleton instances built once, so every
  accessor (`random`, `fromJson`, iterating `values` itself) returns an
  existing instance and `==` is plain reference equality, the same
  guarantee an enum gives for free. Adding avatar_13 later is "drop the
  file, add its character label, bump `count`" — no new switch case
  anywhere. Character labels (Koala, Snail, Elephant, Bee, Frog, Chick,
  Dinosaur, Cat, Turtle, Penguin, Giraffe, Hedgehog) were hand-matched to
  each asset (the task's own instruction — images aren't visible to the
  model building this) and read aloud via `Semantics` for VoiceOver/
  TalkBack, since the English-only UI convention already established
  elsewhere in this app (`docs/roadmap.md`'s backlog) means an English
  label, not a literal transliteration of "Kirpi."
- **[Product] Migration: an old id falls back silently, confirmed on a
  real device, not just in a unit test.** `Avatar.fromJson` returns
  `null` for anything that doesn't parse as `avatar_NN` with `NN` in
  range — including every id from the previous emoji-based set ('fox',
  'owl', 'lion', ...). Running the actual app against its own real,
  pre-existing sqlite profile (which still carried an old-scheme avatar
  id) showed Home's greeting fall back to the generic person-glyph
  placeholder exactly as designed — no crash, confirmed by screenshot,
  not assumed from reading the code.
- **[Product] The ring-color palette (docs/design-audit.md's "named
  exception") carried forward, renamed and expanded to ten — see that
  file's own updated status note under the Settings section for the
  full reasoning, including why the eight original hex values are
  unchanged and only two new ones were added.** `avatarRingColor(Avatar)`
  cycles the ten colors by index (`(avatar.index - 1) % 10`) rather than
  a hand-written 12-entry table — checked, not assumed, that this
  cycling doesn't accidentally land a green-ish ring on Frog (05),
  Dinosaur (07), or Turtle (09): it doesn't, and
  `avatar_ring_color_test.dart` pins that down as a regression test
  rather than trusting the coincidence as the set grows.
- **[Engineering] `UserProfile.copyWith` lost its `clearAvatar` flag** —
  dead after this batch (the carousel has no "clear back to nothing"
  gesture the way the old grid's tap-to-deselect did), confirmed by grep
  before removing it rather than left as an unused, previously-buggy knob
  sitting next to `clearAge`/`clearOccupation`, which stay legitimately
  used.
- **[Engineering] A test-only clock/seam and a real flake, both worth
  recording:**
  - `StorageService.clockForTesting` already existed from the previous
    batch; this one needed no equivalent for the carousel itself — the
    settle detection is driven by real scroll notifications, not a wall
    clock.
  - `tester.fling` on the carousel's `PageView` turned out genuinely
    flaky in this suite (velocity-based physics occasionally settling on
    a different page — or not moving at all — than intended); switched
    every carousel-driving test to `tester.drag` + `pumpAndSettle`, the
    more deterministic pattern for this kind of gesture. A second, real
    flake survived that switch: `OnboardingScreen`'s carousel starts on a
    genuinely random avatar with no injectable seam, so a test asserting
    "swiping changes the selection" could occasionally start already at
    the end of the list, where a forward drag has nowhere to go
    (`PageView` clamps, it doesn't wrap) and settles right back where it
    started. Fixed in the test, not the app: retry the opposite drag
    direction when the first one didn't move anything, rather than
    forcing a deterministic seed into `OnboardingScreen` just to make one
    test convenient.
- **[Product] Verified on-device in both themes** (Settings' preview row,
  the picker's carousel — including the Frog/cyan-ring case specifically,
  to see the green-avoidance rule with real eyes, not just the regression
  test — and onboarding's embedded carousel) via a temporary, untracked
  debug harness (`main.dart` swapped to directly render one target
  screen at a time, forcing `themeMode` explicitly rather than relying on
  the simulator's own appearance toggle — same technique and same
  reason earlier batches recorded this doesn't reliably propagate),
  deleted before commit; confirmed identical to the last-committed
  `main.dart` by `git diff` after reverting. `flutter analyze` and the
  full test suite (277 tests, up from 251) are clean.

## 2026-09-15 (Home: time-of-day greeting, bigger avatar, one leftover
check from the previous batch)

- **[Product] Fixed "Welcome back" copy, checked what it combined with
  before changing anything:** `HomeScreen`'s greeting was a fixed string,
  `'Welcome back, ${widget.userName}'` — `userName` is a required, non-
  nullable `String`, so there was never actually an empty-name case in
  practice (onboarding requires non-empty text), but nothing in the type
  system prevents one either. Replaced with `timeOfDayGreeting`
  (`lib/utils/greeting.dart`), a pure function over a `DateTime` returning
  exactly three words — "Good morning" (05:00–11:59), "Good afternoon"
  (12:00–17:59), "Good evening" (18:00–04:59, wrapping past midnight) —
  deliberately no fourth "night" slice and never "Good night": that
  phrase is an English farewell, not a greeting, and this app teaches
  English, so getting it backwards would be a real, visible mistake on
  the app's own home screen, not a style nit. The "$word, $name" shape is
  the same interpolation the old copy always used, generalized rather
  than reinvented; the one new case ("yoksa sadece") — an empty name
  rendering the greeting word alone, no dangling comma — was added
  because the task asked for it, not because a real profile can produce
  one today.
- **[Engineering] Clock seam, not `DateTime.now()` inline:** `HomeScreen`
  gained an injectable `clock` field (`DateTime Function()`, defaulting to
  `DateTime.now`), matching the class of seam
  `StorageService.clockForTesting` already established in this codebase
  (2026-09-15) — a boundary test constructing an exact `04:59`/`05:00`
  instant needs to control the clock directly, not depend on when the
  suite happens to run. `timeOfDayGreeting` itself doesn't need its own
  clock at all: it's a pure function over a concrete `DateTime`, which is
  what actually makes the four required boundary pairs
  (04:59/05:00, 11:59/12:00, 17:59/18:00, 23:59/00:00) trivial to assert
  directly, no fake clock required for that half of the tests.
- **[Product] Refresh-on-resume: checked before building anything, per
  the task's own instruction not to invent a second mechanism.** Grepped
  the app for `AppLifecycleState`/`WidgetsBindingObserver` — neither
  exists anywhere in this codebase. Per instruction, that means no new
  lifecycle hook and no polling `Timer` for the greeting alone; it
  recomputes on whatever rebuilds Home already does for other reasons
  (Daily Test/weak-spot loads, entitlement changes) and is accepted as
  not refreshing purely from time passing with nothing else happening.
  **The more important finding this surfaced:** `HomeScreen._loadTodaysDailyTest`
  has the identical gap for Daily Test's own day-rollover — it only runs
  from `initState`, so a device left open across local midnight won't
  show a new day's test as available until the next full rebuild either.
  Not fixed in this batch (out of scope, and a real `WidgetsBindingObserver`
  is the right fix, not something to bolt on as a side effect of a copy
  change) — recorded as an open bug in `docs/roadmap.md`'s pre-launch
  checklist instead.
- **[Product] Avatar enlarged, measured first:** the greeting-row avatar
  was `radius: 22` (a 44pt tile — exactly, not approximately, today's
  `≥44pt` touch-target minimum), confirmed by reading the code before
  changing it. Grown to `radius: 30` (60pt). Checked, not assumed, before
  touching it: `BrandScaffold` (`lib/widgets/brand_scaffold.dart`) builds
  its "band" as a plain `AppBar` from `title`/`appBar`; Home's greeting
  row is the first item of `children` (the scrollable body `ListView`),
  not part of the band at all — so growing the avatar has no effect on
  band height, nothing to report there. Also checked: Settings' own
  avatar row (the one wearing the `Hero` to `AvatarPickerScreen`,
  2026-09-15's avatar-carousel batch) is an independent call site of the
  same `AvatarTile` widget
  at its own `radius: 26` — untouched by this change, so that `Hero`
  pairing is unaffected. Verified on-device at 2.2× text scale with a
  deliberately long name: the row's existing `Flexible` +
  `maxLines: 1` + `TextOverflow.ellipsis` treatment (already there before
  this batch, for the old fixed copy) still does its job unmodified —
  text ellipsizes, the avatar keeps its own fixed size, nothing overflows
  or clips vertically.
- **[Product] Leftover check from the previous batch, confirmed
  intentional, left unchanged:** `avatarRingColor` cycles 10 named ring
  colors across 12 avatars (`(avatar.index - 1) % 10`), so avatar 11
  (Giraffe) and avatar 1 (Koala) share a ring color, and avatar 12
  (Hedgehog) and avatar 2 (Snail) share another. This is not a bug or an
  oversight — the previous batch's own instruction was explicitly to
  expand the palette "to 10" colors, not to 12, and the cycling formula
  was written and documented with that constraint in mind (see
  `theme.dart`'s own comment on `avatarRingColor`, 2026-09-15's
  avatar-carousel batch). Per this batch's own instruction to leave an
  intentional decision as-is, no code changed here.
- **[Engineering] A real test flake found and fixed while verifying this
  batch, in a test this batch didn't otherwise touch:**
  `settings_screen_test.dart`'s avatar-autosave test used the plain
  `profile` const (no avatar set), so the picker it opens falls back to
  `Avatar.random()` — the exact same unseeded-random class of flake
  already found and fixed in `onboarding_screen_test.dart` the previous
  batch, just not caught there because that fix didn't audit every other
  call site for the same pattern. Fixed the same way: started the test
  from an explicit `Avatar.values[3]`, safely clear of either end of the
  list, instead of a value that occasionally lands at the boundary a
  fixed-direction drag can't move past. Confirmed by five consecutive
  clean full-suite runs after the fix (it had failed roughly one run in
  nine before).
- **[Product] Verified on-device in both themes** (morning/dark,
  evening/light, plus a 2.2× text-scale + long-name stress check) via a
  temporary, untracked debug harness, deleted before commit; confirmed
  identical to the last-committed `main.dart` by `git diff` after
  reverting. `flutter analyze` and the full test suite (285 tests, up
  from 277) are clean.

## 2026-09-15 (Avatar picker screen: Done button, warmer copy, bigger
avatars — scoped to Settings' full-screen picker only)

- **[Product] Scope boundary honored, checked by inspection before and
  after:** the task named exactly what must stay untouched — transition
  animations, pop, haptic, ring-color transition, `Hero`, `PageView`
  physics, and `OnboardingScreen`'s embedded carousel — and all of it
  lives in the one shared `AvatarCarousel` widget both screens use.
  Rather than fork the widget or special-case Settings inside it, the
  two geometry values that needed to change (center radius,
  `viewportFraction`) became optional constructor parameters defaulting
  to the exact values already shipped, so `OnboardingScreen`'s call site
  (which doesn't pass either) is provably unaffected — not just
  unmodified source, confirmed by re-screenshotting onboarding
  side-by-side with before and finding it pixel-identical.
- **[Engineering] A "Done" button, and specifically *not* a second save
  path.** `AvatarPickerScreen` previously had no completion affordance at
  all — the app bar's back chevron was the only way out. Added a
  `FilledButton` reading "Done", pinned at the bottom via the same
  `SafeArea(top: false) + Padding` pattern `OnboardingScreen`'s own
  "Continue" button already uses — no new button style, and the app's
  `filledButtonTheme` already sets `minimumSize: Size.fromHeight(52)`,
  so the ≥44pt touch-target requirement is met by construction, not by
  anything added here.

  The explicit instruction was to *not* remove the existing autosave and
  *not* make Done into a second, competing save action — the worry named
  outright was a user who picks an avatar, leaves via the back button
  instead of Done, and loses the choice because it was never persisted.
  Traced the existing code before writing anything: `AvatarPickerScreen`
  already autosaves on every settle (debounced 500ms) and its `dispose()`
  already flushes any pending debounced write before the widget goes
  away, specifically so a fast "swipe then immediately leave" doesn't
  lose the change — this was built for the back button in the previous
  batch (2026-09-15's avatar-carousel batch) but is exit-path-agnostic by
  construction: it fires
  on `dispose()`, which *any* pop reaches, Done's included. So Done's
  entire handler is `Navigator.of(context).pop()` — nothing else. Back
  and Done are equivalent exit paths not because they were special-cased
  to agree, but because they both funnel through the one flush that
  already existed. Confirmed with a dedicated test that tapping Done
  immediately after a swipe (still inside the debounce window) still
  saves exactly once, a second test that Done after the autosave already
  fired does *not* write again, and a third that both exit paths land on
  the identical saved avatar.
- **[Product] Copy and typography, checked before touching either.** The
  task's own card rule (docs/design-audit.md, 2026-09-10: a container is
  only justified around a single tap target or something carrying
  semantic color, never just "for readability") turned out not to apply
  here at all — read the actual widget tree first rather than assuming:
  "Swipe to choose your avatar" was already plain `Text`, no
  card/box/frame around it to remove. The real complaint was the
  typography (`bodyMedium`, a caption-weight role) reading as an
  afterthought instead of the screen's actual instruction. Changed the
  copy to "Pick your study buddy" and the style to
  `textTheme.titleMedium` at `FontWeight.w700` — the same role/weight
  pair `OnboardingScreen`'s own "What should we call you?" /
  "Why are you learning English?" prompts already use, so this screen's
  one line of instructional text now reads with the same voice the rest
  of the app already established, not a new one. No new color or font
  defined; both come straight off `Theme.of(context).textTheme`.
- **[Product] Avatar enlarged, measured first, and *reduced* from a first
  attempt once the actual constraint was checked numerically instead of
  by eye.** Current radius (56) and `viewportFraction` (0.45) confirmed
  by reading `avatar_carousel.dart` before changing anything. A first
  pass grew both together to 80/0.6, on the assumption that a bigger
  avatar needs a wider page slot — screenshotted on the 375pt iPhone SE
  simulator and found the neighbor avatars reduced to a barely-visible
  sliver of color at the screen edge, nowhere near "still recognizably an
  avatar," which is the task's own named critical constraint (swiping is
  the *only* selection method, so losing the "there's something to swipe
  to" signal is a real regression, not a nicety). Worked the geometry out
  numerically instead of guessing again: a wider `viewportFraction`
  shrinks how much of the *next* page's own width is exposed at the
  screen edge, which is what actually controls neighbor visibility —
  growing it alongside the radius was working against the goal, not
  toward it. Grid-searched center radius against `viewportFraction` for
  the largest radius that keeps a neighbor's own avatar at least
  half-visible at both 375pt and 320pt width while its ring stays
  strictly narrower than its own page (no overflow) at either size;
  landed on radius 64 / `viewportFraction` 0.5 — a real but modest
  enlargement (+14% over 56), deliberately smaller than the first
  attempt once neighbor visibility was treated as the binding constraint
  rather than "as big as possible."

  320pt verification is calculation-only, not on-device: tried creating a
  1st-generation iPhone SE (320pt) simulator against the currently
  installed iOS 26.5 runtime and Xcode refused it outright
  ("Incompatible device") — that hardware profile is no longer
  supported at all on current tooling, not something this session could
  work around.
- **[Product] Verified on-device in both themes, two widths:** the 375pt
  iPhone SE simulator (light and dark) and the larger iPhone 17 simulator
  (light), via a temporary, untracked debug harness rendering
  `AvatarPickerScreen` directly, deleted before commit; a separate pass
  of the same technique re-confirmed `OnboardingScreen`'s own screen is
  unchanged. `flutter analyze` and the full test suite (289 tests, up
  from 285) are clean, including three consecutive clean full-suite runs
  to rule out the gesture-based flakiness this exact test file has hit
  before (2026-09-15's Home greeting/avatar batch).

## 2026-09-15 (Avatar asset fix: the vertical-line bug, Dinosaur → Crab)

- **[Product] Diagnosed a vertical-line bug reported inside the
  onboarding carousel's selection ring, on the Dinosaur avatar
  specifically — root cause confirmed by inspecting real pixel data, not
  guessed from the widget tree.** Decoded all twelve bundled `.webp`
  files directly and found the defect in exactly one: `avatar_07.webp`'s
  columns x=1–3 carried a translucent light-gray stripe (alpha ~11–45%
  of full) running the asset's entire 508px height, while every other
  avatar's edge columns/rows were fully transparent (alpha 0). Two
  competing hypotheses were checked and ruled out rather than assumed
  away:
  - **Render-time filter bleed at scale-up** — ruled out because the
    stripe already exists at that opacity across 508 continuous rows in
    the *raw decoded pixels*, before `Image.asset`'s default filtering
    ever touches it. Filtering could soften it by a fraction of a pixel;
    it can't manufacture 508 rows of correlated alpha out of clean data.
  - **`PageView` neighbor-page bleed at the carousel's center slot** —
    ruled out on two grounds: `_CarouselPage`'s `Transform.scale` never
    scales the settled/center page past 1.0× its own slot (only a brief
    1.06× "pop"), so nothing has room to bleed in from an adjacent page;
    and, decisively, the line only ever appeared on Dinosaur, never on
    whichever avatar happened to be centered — a layout-level seam would
    show on any avatar sitting in that position, not one specific
    illustration.
  - Also confirmed, not assumed: the colored selection ring
    (`avatarRingColor`) was never the cause and removing it would not
    have fixed this on its own. `AvatarTile` (Home's greeting, Settings'
    preview row) already renders with **no background at all**, and the
    defect is in the asset's own pixels — it shows there too, just
    against whatever sits behind it instead of a ring.
  - No source PNG/PSD exists in the repo to compare against (only the
    final `.webp`s are ever committed), so which pipeline step
    introduced the defect is unknown — moot, since the fix is to the
    shipped file regardless of when it was introduced.
- **[Product] Dinosaur retired; a new Crab illustration takes the
  avatar_07 slot** — a manual asset replacement made outside this
  session, verified clean on-device beforehand. `Avatar`'s numbering is
  by asset slot (`avatar_07.webp`), not creature identity, so this needed
  no `count`/index change, only the semantic label
  (`_semanticLabels[6]`) VoiceOver/TalkBack reads aloud.
- **[Engineering] Closed out the manual swap properly instead of trusting
  it at face value.** The replacement file was a genuine WebP with a real
  alpha channel (confirmed by decoding it, not by trusting the `.webp`
  extension) — but 1024×1024 against every sibling avatar's 508×508, and
  121KB against the set's normal 25–43KB range. Resized to 508×508 and
  re-encoded lossy quality 90: read each sibling file's own RIFF/VP8
  header first to confirm the set's actual convention (lossy `VP8 ` +
  a separate `ALPH` alpha chunk, not lossless `VP8L`) rather than
  guessing at a format to match. Landed at 33KB, back in the normal
  range. The source file's own edges had a clean 10px fully-transparent
  margin before downscaling, checked explicitly so the resize filter had
  no hard alpha edge to ring against.
- **[Engineering] Writing the promised regression test surfaced two more,
  much smaller, unrelated pre-existing defects — fixed, not carved out as
  exceptions.** Running the same edge-alpha sweep across all twelve
  assets (not just avatar_07) found `avatar_01.webp` carrying 22 isolated
  pixels at alpha=1/255 on its top row and `avatar_03.webp` carrying 2 at
  alpha=1/255 on its bottom row — WebP lossy-compression noise at the
  boundary of an already-transparent region, invisible at that opacity
  and scattered rather than a contiguous line, so a materially different
  (and far less severe) defect than Dinosaur's.
  **Corrected after review, in a follow-up commit:** the first pass
  zeroed both rows and re-saved through the same lossy quality-90 path
  used for avatar_07, which re-compresses every pixel in the image, not
  just the ~1px sliver actually being fixed — the wrong tool for a
  targeted correction, even at a quality setting high enough that no
  difference was visible. Redone from each file's own pre-fix original
  (`git show` against the commit before this fix): decoded to raw RGBA,
  zeroed only the exact pixels found nonzero (confirmed programmatically
  — 22 on avatar_01, 2 on avatar_03, matching the counts above exactly),
  and re-saved as **lossless** WebP (`lossless=True, exact=True`) so
  every other pixel in each file is bit-for-bit identical to the
  original — verified directly, not assumed, by diffing the decoded
  arrays. This makes both files noticeably larger than the lossy set's
  normal 25–43KB range (avatar_01: 31.5KB → 84.1KB; avatar_03: 42.7KB →
  84.9KB) — an accepted, deliberate tradeoff: pixel-exact correctness on
  two files the pipeline otherwise wouldn't touch again, not a size
  target.
- **[Engineering] New `avatar_asset_edges_test.dart` decodes real asset
  bytes — the only path that could have caught the original bug.** Loads
  each of the twelve bundled `.webp` files via `rootBundle.load` (real
  bytes, not a mock or a widget-level check), decodes with `dart:ui`'s
  `instantiateImageCodec`, and asserts alpha is 0 on every pixel of the
  outermost edge on all four sides. A widget test on `AvatarTile`/
  `AvatarCarousel` could never have caught this class of bug — those
  widgets render whatever bytes the asset file contains, correctly; the
  defect was in the bytes themselves.
- **[Product] Textual "Dinosaur" references updated where they describe
  current behavior — `avatar_ring_color_test.dart`'s expectations and
  comments now read "Crab" for avatar_07, with a note that it stays in
  that test's coverage for the index/ring-color pairing, not because a
  crab is green.** Deliberately left alone: `docs/build-log.md`'s own
  2026-09-15 "avatar picker: layout-bug diagnosis, carousel replacement"
  entry and `docs/roadmap.md`'s matching passage, both of
  which correctly describe the app as it was named at the time — the
  same don't-rewrite-history call already made for the "AI Voice
  Practice" → "AI Practice Partner" rename (2026-09-05, this file).
- **[Product]** `flutter analyze` and the full test suite (290 tests, up
  from 289) clean.

## 2026-09-15 (Avatar presentation: dropped the colored ring, transparent
background + ground shadow)

- **[Product] Inventory before touching anything, per this batch's own
  request: where is the colored circle actually drawn?** Grepped every
  avatar render site (`avatar_tile.dart`, `avatar_carousel.dart`,
  `avatar_picker_screen.dart`, `settings_screen.dart`, `home_screen.dart`,
  `onboarding_screen.dart`) for `BoxShape.circle`/`CircleBorder`/
  `BoxDecoration`. Confirmed exactly the expected single location:
  `AvatarCarousel`'s own `AnimatedContainer` selection-ring layer, behind
  its `PageView`. `AvatarTile` itself — used bare on Home's greeting and
  Settings' preview row — already had no background circle at all (only
  its null-avatar placeholder branch draws a filled box, for an entirely
  different reason: a generic person-icon tile, not a per-avatar color).
  So "remove the ring" was scoped to one widget, confirmed rather than
  assumed before writing any code.
- **[Engineering] The ring layer and its color palette are deleted, not
  replaced by another named exception.** `AvatarCarousel`'s
  `AnimatedContainer`/`Key('avatarSelectionRing')` is gone; the carousel's
  outer `SizedBox` height is now `centerRadius * 2 * 1.12` (just enough
  slack for the settle "pop" animation's 1.06× scale and the new ground
  shadow's blur to paint without clipping), replacing the old
  `centerRadius * 2 + ringPadding * 2` ring-diameter formula.
  `avatarRingColor1`–`avatarRingColor10`, `_avatarRingColors`, and
  `avatarRingColor()` are deleted from `theme.dart`; `avatar_ring_color_
  test.dart` is deleted outright, not left disabled. `docs/design-audit.md`'s
  avatar named-exception section gets a new status block recording the
  removal and why nothing replaces it as a named exception (a ground
  shadow isn't a per-avatar identity color).
- **[Product] Selection indicator: unchanged mechanism, now doing the
  whole job on its own.** `_CarouselPage` already scaled the settled page
  to full size/opacity against neighbors at ~0.8 scale/~0.5 opacity,
  continuously interpolated by drag position (`Transform.scale`/`Opacity`
  reading `pageController.page`) — this was already implemented, just
  previously upstaged by the ring as the more obvious cue. No change to
  `radius`/`viewportFraction` on either call site (onboarding's embedded
  carousel or `AvatarPickerScreen`), so the existing "neighbor stays
  ≥50% visible at 375pt/320pt" geometry from the previous batch is
  untouched — confirmed by diff, not re-measured.
- **[Product] Semantics: `selected` added explicitly, not assumed to
  already exist.** Checked first: the carousel's `Semantics` wrapper on
  each page had no `selected` flag before this batch — nothing marked
  the centered avatar as selected for a screen reader beyond it being
  the widget currently in view. Added `selected: index == settledIndex`
  so a screen reader announces the change explicitly, independent of any
  visual cue (the ring no longer exists to lean on even implicitly). New
  test in `avatar_carousel_test.dart` drags the carousel and asserts the
  `SemanticsFlags.isSelected` tristate flips off the original avatar and
  onto whichever one actually settled.
- **[Engineering] Ground shadow: soft ellipse behind the illustration,
  inside `AvatarTile` itself so every render site gets it automatically.**
  A `Stack` inside `AvatarTile`'s existing `SizedBox` — the illustration
  on top, a blurred elliptical mark (`_AvatarGroundShadow`) positioned
  near the bottom, both scaled by `radius` so Home's 30, Settings' 26,
  and the carousel's 56/64 all get a proportionally sized mark with one
  formula, not four hand-tuned constants: ellipse width `radius * 1.3`,
  height `radius * 0.32`, blur sigma `radius * 0.16`, anchored `radius *
  0.12` above the tile's own bottom edge. Positioned by a fixed fraction
  of tile height rather than measured per illustration — the twelve
  assets share a consistent centered-character-with-headroom composition,
  so one general-purpose placement reads correctly across the set without
  tuning each individually. The null-avatar placeholder is deliberately
  excluded: it already reads as a filled UI element (a bordered icon
  tile), not a floating illustration, so grounding it the same way would
  be redundant, not consistent.
- **[Product] Theme-aware color, measured rather than guessed — one
  black shadow does not work in both themes.** `BrandScaffold`'s own body
  color is `colorScheme.surfaceContainerLow`: `#FAF3EC` (light) and
  `#1C1B1F` (dark, matching the task's own reference value). Computed
  WCAG contrast of a black shadow blended into each: light hits a good
  ~1.6–1.8 contrast at 20–25% alpha, but dark tops out at only ~1.16
  contrast even at 65% alpha — a black shadow is nearly invisible on a
  body that's already near-black. Landed on `avatarGroundShadowColor`/
  `avatarGroundShadowOpacity` (`theme.dart`): black at 20% alpha in
  light, **white** at 11% alpha in dark — matching Material 3's own
  dark-theme convention that grounded/elevated surfaces read lighter, not
  darker, against a near-black background. Both land at a comparable
  ~1.4–1.6 contrast against their own body.
- **[Engineering] A real bug found while adding the shadow's `Stack`,
  not by inspection — an image collapsing to zero size in a way that
  only a widget test surfaced.** Wrapping `Image.asset` in a `Stack`
  alongside the new shadow layer (previously it was the tile's sole,
  tightly-constrained `SizedBox` child) changed it from tightly
  constrained to loosely constrained: `Stack` gives a non-`Positioned`
  child loose constraints, and `RenderImage` with no explicit
  width/height falls back to `Size.zero` for any frame before the asset
  has actually decoded — a case the old tight `SizedBox` constraint never
  exposed, since tight constraints force a size regardless of decode
  state. Surfaced as a `tester.tap` hit-test warning in
  `settings_screen_test.dart` (only at that test's own custom 390pt
  viewport, which is what made it visible at all) — diagnosed by
  measuring the actual `Image` rect directly rather than guessing from
  the warning text, which showed a genuine `Rect.fromLTRB(43.5, 278.0,
  43.5, 278.0)`, i.e. a real zero-size collapse, not test flakiness.
  Fixed with explicit `width`/`height` on the `Image.asset` matching the
  tile's own side length — removes the ambiguity outright rather than
  working around Stack's sizing behavior. New regression test in
  `avatar_tile_test.dart` asserts the illustration's own rendered rect is
  exactly `radius * 2` on both axes, not just the outer tile's.
- **[Product] Legacy/unknown avatar ids:** unaffected by this batch,
  confirmed rather than assumed — `Avatar.fromJson`'s existing null
  fallback and `AvatarTile`'s existing null-avatar placeholder branch
  were not touched, and the full existing `avatar_test.dart` suite
  (including the previous-emoji-set-id fallback case) still passes
  unchanged.
- **[Product]** `flutter analyze` and the full test suite (291 tests, up
  from 290) clean.

## 2026-09-15 (Settings' avatar picker: bigger center avatar, second look
after the ring's removal)

- **[Product] Measured the actual "empty space" before touching anything,
  per this batch's own instruction — it isn't a layout gap.** The tile's
  own box is a square (`side × side`) and every avatar asset is a square
  508×508 canvas, so `BoxFit.contain` already fills the box edge to edge
  with no letterboxing — there's no slack in the *layout* to reclaim.
  What reads as empty space is padding baked into each illustration's own
  canvas, and it varies far more than expected across the set: computed
  each avatar's non-transparent bounding box directly. Fill ratio ranges
  from 63% width (Giraffe, avatar_11) to 99% height (Snail, avatar_03) —
  Snail in particular has almost zero margin (0.2–0.4% top/bottom).
  **Conclusion: a uniform crop/zoom into the illustrations themselves
  isn't safe** — any zoom factor large enough to meaningfully shrink the
  padding on the roomier avatars would clip Snail's already-tight
  canvas. Confirms this batch's own step 2 (grow the slot, not the
  image) is the right lever, not a fallback.
- **[Engineering] The previous batch's "64/0.5 is the largest radius that
  keeps the neighbor half-visible" belief doesn't survive being measured
  directly — corrected, not just accepted at face value.** Built a widget
  test that renders the real `AvatarCarousel` at a grid of `centerRadius`
  (56 through 88) and `viewportFraction` (0.4/0.45/0.5/0.55) values, at
  both 320pt and 375pt, and reads the neighbor avatar's own rendered rect
  to compute its actually-visible fraction (rather than trusting hand
  algebra, which this session also derived and cross-checked against the
  measurement — they agree). Result: **the visible fraction depends only
  on `viewportFraction`, not on `centerRadius` at all** — exactly 50% at
  vf 0.5 for every radius tested, at both widths. The previous batch's
  own reasoning had silently conflated two different constraints: peek
  visibility (radius-independent) and the *ring's* own diameter needing
  to stay narrower than its page (very much radius-dependent, and — with
  the ring now deleted — no longer a constraint that exists at all).
- **[Product] New binding constraint, found the same way: the settled
  tile's own diameter fitting inside its own page slot at the narrowest
  supported width.** `2 * centerRadius <= viewportFraction * screenWidth`
  at the tightest case (320pt, `viewportFraction` fixed at 0.5, the
  largest value that still keeps peek visibility at exactly half) gives
  `centerRadius <= 80`. Picked exactly 80: the settled tile fills its own
  page slot with zero overflow at 320pt, and has slack to spare at 375pt.
  `viewportFraction` itself is unchanged at 0.5 — the actual lever this
  batch pulls is `centerRadius` alone.
  - **Before → after:** center avatar diameter 128pt → 160pt (+25%,
    every avatar scales uniformly, so a 63%-fill avatar like Giraffe
    still shows proportionally the same character size increase as a
    99%-fill one like Snail). Neighbor's own rendered tile: 102.4pt →
    128pt diameter; visible peek width **51.2pt → 64pt, identical at
    320pt and 375pt** (the neighbor's own size depends only on `radius`
    and the fixed `neighborScale`, never on screen width — confirmed by
    the same measurement, and worth recording since the previous batch
    treated 320pt/375pt as needing separately-recomputed numbers, which
    they no longer do without the ring's width-vs-page constraint).
  - `AvatarCarousel`'s own `_neighborScale` (0.8) is untouched — reducing
    it further (offered as a fallback lever in this batch's own brief)
    turned out unnecessary once the actual binding constraint was
    corrected; the radius increase alone is a full, geometry-justified
    +25%.
- **[Product] Scoped to exactly the Settings full-screen picker, verified
  by diff, not just intent.** Only `avatar_picker_screen.dart`'s own
  `_centerRadius` constant changed; `AvatarCarousel`'s defaults (56/0.45,
  what `OnboardingScreen`'s embedded carousel still gets) are untouched,
  and `git status` after this batch shows exactly two files touched (the
  screen and its test) — nothing in `avatar_carousel.dart` itself needed
  to change, since `centerRadius`/`viewportFraction` were already
  per-instance constructor parameters from the previous enlargement
  batch (2026-09-18 originally, corrected to 2026-09-15 above).
- **[Engineering] New regression test group in
  `avatar_picker_screen_test.dart`** asserts the neighbor stays ≥50%
  visible at both 375pt and 320pt against the *real* `AvatarPickerScreen`
  (not a bare `AvatarCarousel` with hand-picked parameters) — written to
  hold regardless of whatever `centerRadius` is currently set to (it
  re-measures the actual rendered geometry each time), so a future change
  to either constant gets caught here rather than only on a real device.
- **[Product]** `flutter analyze` and the full test suite (293 tests, up
  from 291) clean.

## 2026-09-15 (Home avatar → Settings' avatar picker: a real transition,
after checking what "transition" could even mean here)

- **[Product] Checked the actual navigation mechanism before assuming a
  Hero flight was possible at all.** Home's avatar tap goes through
  `app.dart`'s `_switchTab(2)` — an `IndexedStack` index swap, not a
  `Navigator` route change. `Hero` only animates across a route push/pop
  transition; there is no such transition for a tab swap to hang one off
  of. Settings' own avatar preview row already wraps its `AvatarTile` in
  `Hero(tag: avatarHeroTag, ...)`, for the *existing* Settings → picker →
  back flight — a separate, already-working case.
- **[Product] Stopped and presented options rather than picking one**,
  per this batch's own instruction once the tab-switch finding came back.
  Landed on a third option beyond the two originally offered: keep the
  tab model itself untouched everywhere else, but change Home's avatar
  specifically to push the *existing* `AvatarPickerScreen` route directly
  (the same screen Settings' "Change avatar" already opens) instead of
  switching tabs — giving Home's avatar a real Hero flight to the
  carousel's centered avatar, without turning Settings into a differently
  -reached screen for every other path into it.
- **[Engineering] `AvatarPickerScreen` gained a required `heroTag`
  parameter** — `avatarHeroTag` (Settings' own, unchanged) and a new
  `homeAvatarHeroTag`, both defined in `avatar_picker_screen.dart`.
  Deliberately *not* the same tag reused for both entry points: Home and
  Settings are both permanently mounted inside `app.dart`'s
  `IndexedStack` (every tab stays alive, not just the visible one), so if
  Home's avatar and Settings' preview row shared one Hero tag, both would
  be mounted simultaneously the instant either one pushed this screen —
  Flutter throws on exactly that ("multiple heroes that share the same
  tag"). One tag per *entry point* avoids this by construction rather
  than by convention. `AvatarCarousel`'s own existing architecture already
  guarantees the tag lives on exactly one page at a time (`centerTileBuilder`
  only ever wraps the *settled* index, never a page mid-drag) — verified
  directly with a new test that checks the tagged-Hero count stays at
  exactly 1 through a drag, not just at rest.
- **[Product] `HomeScreen`'s own avatar wrapped in
  `Hero(tag: homeAvatarHeroTag, ...)`**; `app.dart`'s `onAvatarTap` now
  calls a new `_openAvatarPickerFromHome(context)` instead of
  `_switchTab(2)`, pushing `AvatarPickerScreen` with that tag and a
  `_changeAvatar` callback that mirrors `SettingsScreen._changeAvatar`
  (save via `StorageService`, update `_profile` via `setState`) — written
  again rather than shared, since the two call sites read from different
  state shapes and sharing would cost more indirection than the ~5 lines
  saved. A `late final Avatar _fallbackAvatarForPicker` mirrors
  `SettingsScreen`'s own fallback for the same edge case: a legacy
  profile with no avatar yet, computed once so it doesn't re-roll on
  every open.
- **[Engineering] A real, if subtle, flicker risk found and fixed while
  making sure the flight would actually look right, not assumed away.**
  `AvatarPickerScreen`'s pending-debounced-change flush used to live only
  in `dispose()` — fine for a plain pop, but `dispose()` doesn't run
  until *after* a pop's transition animation finishes, which is too late
  for a Hero flight: the destination avatar (Home's or Settings') needs
  to already show the new avatar *before* the flight starts, or it
  visibly arrives showing the old one and only then jumps to the new one.
  Fixed by wrapping the screen in `PopScope(canPop: false,
  onPopInvokedWithResult: ...)`, routing every exit path — Done, the
  AppBar back chevron, a system back gesture — through one `_popNow`
  that flushes synchronously *before* calling `Navigator.pop()` itself.
  This is a change to the *shared* `AvatarPickerScreen` widget, so it
  also fixes the same latent risk for Settings' existing flow, not just
  Home's new one — Settings' own entry point and destination are
  otherwise completely unchanged, confirmed by diff. New regression test
  pumps a single frame right after tapping Done (mid-transition, well
  before `dispose()` would ever run) and asserts the change has already
  been reported.
- **[Product] The ground shadow needed no special handling at all for the
  flight, checked rather than assumed.** It's painted inside `AvatarTile`
  itself, which is what `Hero` wraps on both ends — Flutter's default
  Hero shuttle flies one captured widget subtree (image + shadow
  together) and scales the whole thing between the two endpoint rects, so
  the shadow scales in lock-step with the illustration throughout, with
  no separate logic needed to keep it from breaking or duplicating.
- **[Product] `MediaQuery.disableAnimationsOf` branches the push itself**:
  a zero-`transitionDuration`/`reverseTransitionDuration` `PageRouteBuilder`
  when true, the normal `MaterialPageRoute` otherwise — the same
  manual-gating pattern this app already uses everywhere else motion
  appears, since Flutter route transitions don't automatically respect
  this setting on their own.
- **[Engineering] Tests, in `home_screen_test.dart` and
  `avatar_picker_screen_test.dart`**: tapping Home's avatar opens
  `AvatarPickerScreen` via a real push (Home itself is covered, not just
  hidden — confirming this isn't the old tab switch in disguise); Done
  pops back to `HomeScreen`; the pushed route's own `transitionDuration`
  is zero under `disableAnimations` and non-zero otherwise (checking the
  route's configuration directly, this suite's own established idiom,
  rather than racing partial animation frames); the mid-debounce flush
  timing fix above, and the exactly-one-tagged-Hero invariant through a
  drag. Reused the "minimal harness reproducing the real wiring" testing
  approach this file and `avatar_picker_screen_test.dart` already used
  (rather than driving the full `GrammarLensApp` through onboarding just
  to reach Home) — consistent with, not a new pattern for, this suite.
- **[Product]** `flutter analyze` and the full test suite (299 tests, up
  from 293) clean.

## 2026-09-15 (Premium screen redesign, Batch 0 — diagnosis, no code)

- **[Product]** A diagnosis-only batch, per its own instruction ("Kod yok.
  Ölçüm iste, izlenim değil"): every claim below is checked against real
  code or measured numerically, not eyeballed. Full report given to Ahmet
  in-conversation; recorded here so the reasoning survives past that
  message.
- **Comparison table had a real factual error**, not just stale copy:
  "Targeted weak-spot practice" showed free = "—", but
  `StorageService.freeDailyPracticeLimit = 1` and `launchPracticeSet`
  (lines 64–84) genuinely grant a free user one such session per day.
  "Questions from your own mistakes" turned out to be either describing
  the same capability redundantly, or Daily Test's own free error-profile
  personalization mislabeled as premium-only — either reading makes it
  wrong or redundant. Recommended merging both into one row, "Practice
  your weak spots", Free = "1 a day" (read from the constant, never
  retyped), Premium = ✓.
- **Premium strip color measured, not assumed.** D1's own rule (orange
  never becomes a surface in dark mode) rules out `primary`; the existing
  `secondaryContainer`/`onSecondaryContainer` pair (already used by the
  selected plan card) is the compliant choice. Contrast:
  `onSecondaryContainer` on `secondaryContainer` — **9.79:1 light, 7.13:1
  dark**, both comfortably clearing 4.5:1 (text) and 3:1 (icon). Checked
  what the *current* code actually uses for premium checkmarks
  (`colorScheme.secondary`) against that same background and found a real
  problem hiding there: **2.53:1 in dark mode — fails the 3:1 icon
  minimum outright.** Must switch to `onSecondaryContainer`, not just add
  a colored strip and leave the icon color alone.
- **FittedBox(scaleDown) on "PREMIUM"**: caused by a fixed 56px column
  plus letter-spacing pushing the word past it. Fix falls out of the
  redesign (the column becomes a real proportional width once it's a
  highlighted strip) plus dropping the tracking; needs a widget-test check
  at large `TextScaler` once built, since 12px literal font size still
  scales with the ambient text scaler by default.
- **Debug fixture pricing is concretely feasible, checked against the
  actual SDK source**, not assumed: `purchases_flutter`'s `Offering`/
  `Package`/`StoreProduct`/`IntroductoryPrice` all have public `const`
  constructors — a realistic fixture is buildable in pure Dart, no
  platform channel involved. Recommended mirroring
  `debugAccessOverride`'s exact release-safety shape (`kDebugMode`-gated,
  tree-shaken out of a release build) rather than inventing a new
  mechanism.
- **A real structural gap found for "sticky CTA"**: `PremiumScreen`
  currently uses `BrandScaffold`'s `children:` (an implicit `ListView`),
  so the CTA is *not* pinned today — it scrolls with everything else.
  Achieving a fixed footer needs the `body:` + manual
  `Column(Expanded scrollable + fixed footer)` shape
  `AvatarPickerScreen` already uses. Not cosmetic — a real layout change.
- **Analytics surface checked, found smaller than expected**: neither
  `PremiumScreen` nor `SubscriptionService` fire any event internally
  today (no `paywall_viewed`/`trial_started` instrumentation exists at
  all) — the only two events anywhere near this screen
  (`modeSelected(modePremium)`, `freePracticeQuotaExhausted()`) fire
  *before* `PremiumScreen` is even pushed, from Home and the weak-spot
  quota path respectively, and are untouched by an internal redesign.
- **Hero avatar data source**: `PremiumScreen` doesn't receive
  `avatar`/`UserProfile` today. All four push call sites
  (`HomeScreen`, `FirstLaunchFlow`, `practice_launch.dart`,
  `WeakSpotDetailScreen`) already hold a `StorageService` instance,
  confirmed by grep — recommended `PremiumScreen` take
  `required StorageService storageService` and read the profile itself
  in `initState`, rather than threading `Avatar?` through four
  inconsistent call sites (two of which are plain functions, not widgets
  with profile state already in scope).
- **X + "Maybe later"**: recommended keeping both, but moving "Maybe
  later" into the new fixed footer — today it can scroll out of view
  entirely on a long page, an existing latent gap the restructure
  incidentally closes.
- No code changed this batch.

## 2026-09-15 (Premium screen redesign, Batch 1 — debug-only pricing
fixture)

- **[Engineering] `SubscriptionService.getOfferings()` checks a new
  debug-only fixture first**, mirroring `debugAccessOverride`'s exact
  shape: `debugFixtureOffering` (getter, `debugModeForTesting`-gated) and
  `setDebugFixtureOffering({required bool enabled})` (setter, same gate).
  Release-safety is the same proven mechanism, not a new one —
  `kDebugMode` folds to `false` at compile time and the Dart compiler
  tree-shakes everything behind it out of a release binary; a new test
  file (`subscription_service_debug_fixture_offering_test.dart`) proves
  this the same way `subscription_service_debug_override_test.dart`
  already does for the entitlement override (simulate release via
  `debugModeForTesting = false`, assert the fixture is unreachable even
  if one was set beforehand).
- **`buildDebugFixtureOffering()` (public, top-level)** builds the
  fixture from PRD v2 §13.2's stated prices — $5.99/month, $49.99/year,
  a 7-day free trial on both — using `purchases_flutter`'s own `const`
  constructors (`Offering`/`Package`/`StoreProduct`/`IntroductoryPrice`),
  confirmed available by reading the installed package source directly
  rather than assuming. **Only the raw numbers are fixed**: the annual
  plan's per-month equivalent (`pricePerMonth`/`pricePerMonthString`) is
  computed here as `49.99 / 12`, a real division in code, not a
  separately typed-out literal that could silently drift from it — so
  `PremiumScreen._planPricing`'s existing "Save %" computation runs
  against this fixture for real, exercising the same math path a real
  product would, rather than being bypassed by a fixture that already
  did the work. Public specifically so a test can check the fixture's
  own numbers independent of the `kDebugMode` gate around it.
- **Settings > Developer gained "Preview paywall pricing"** — a plain
  `SwitchListTile`, not the `SegmentedButton` the entitlement override
  uses, since this is a single boolean, not a three-way choice.
  **Session-only by design, per this batch's own instruction**: reads
  its initial value from `subscriptionService.debugFixtureOffering`
  directly (never a separate stored preference, so it can't disagree
  with what `PremiumScreen` would actually see), and its setter
  (`_setPreviewPaywallPricing`) never touches `StorageService` at all —
  unlike the entitlement override right above it in the same section,
  which does persist. New tests confirm both the initial-value-reflects-
  reality behavior and that toggling it never writes to storage.
- **[Product]** `flutter analyze` and the full test suite (312 tests, up
  from 299) clean.

## 2026-09-15 (Premium screen redesign, Batch 2 — structure, comparison
rows, the Premium strip)

- **[Engineering] Structure: `BrandScaffold`'s `children:` (implicit
  `ListView`) replaced with `body:` + a manual `Column` — a scrollable
  `Expanded` middle plus a genuinely fixed footer**, the same shape
  `AvatarPickerScreen` already uses. This is the actual fix for Batch 0's
  finding that the CTA was never really pinned before — it just happened
  to be reachable without scrolling at one common screen size.
- **Footer content, by state** (`_PremiumFooter`, `Key('premiumFooter')`
  for tests): **loading** — a disabled `FilledButton` with an inline
  spinner (no disclosure, nothing to disclose yet) plus "Maybe later".
  **loaded** — the purchase status banner (idle/purchasing show nothing,
  already covered by the button itself), the CTA, the disclosure line,
  "Maybe later" (hidden once a trial has actually started — the CTA
  becomes "Continue" then, a second identical exit would be redundant).
  **pricing-unavailable** — *only* "Maybe later", no CTA, no disclosure;
  the retry card stays in the scrollable body, not duplicated into the
  footer. **purchase error** — unchanged from before: the same CTA allows
  retrying directly, no separate "Retry" button. Restore Purchases and
  the legal links moved to the end of the scrollable body, per this
  batch's own instruction.
- **Footer height measured at all four required combinations** (`Size ×
  textScale`, fake offering loaded so the disclosure line is present —
  the tallest realistic footer state):

  | Size | textScale | Footer height | % of viewport |
  |---|---|---|---|
  | 320×568 | 1.0 | 160.0pt | 28.2% |
  | 320×568 | 1.3 | 174.0pt | 30.6% |
  | 375×667 | 1.0 | 160.0pt | 24.0% |
  | 375×667 | 1.3 | 170.0pt | 25.5% |

  All four comfortably clear of the 40%-of-viewport stop-and-report
  threshold (worst case 30.6%, at 320×568 @1.3×) — no stop needed, but
  recorded here as the actual measurement this batch's brief asked for,
  not an assumption.
- **Comparison table merged from five rows to four**, per Batch 0's own
  finding: "Questions from your own mistakes" and "Targeted weak-spot
  practice" both claimed free = "—", which was wrong — `launchPracticeSet`
  genuinely grants `StorageService.freeDailyPracticeLimit` (1) such
  sessions/day. Merged into "Practice your weak spots", Free shown as
  **"${StorageService.freeDailyPracticeLimit} a day"** (read from the
  constant via string interpolation, never retyped as a literal "1") —
  `_ComparisonRow` gained an optional `freeLabel` field specifically for
  this, since the other three rows still use a plain checkmark/dash.
  Grepped the whole screen for "unlimited"/"Unlimited": zero hits, by
  design.
- **The Premium column reads as one continuous, rounded, highlighted
  strip** — built as N adjacent same-fill cells (one per row, zero gap
  between them, only the very first/last corners rounded) rather than a
  single overlay spanning the table, specifically so a row's own height
  (which can now vary — see below) is a non-issue: each cell simply
  fills whatever height its own row needs. Fill color is
  `colorScheme.secondaryContainer` / `colorScheme.onSecondaryContainer`
  for both the header text and the checkmark icon — **not**
  `colorScheme.secondary`, which the previous per-cell-icon design used
  and which Batch 0 measured at only 2.53:1 against this background in
  dark mode (fails the 3:1 non-text minimum). The new pairing measures
  9.79:1 light / 7.13:1 dark, both comfortably clearing 4.5:1 (text) and
  3:1 (icon).
- **The selected plan card still reads as selected next to the strip**,
  checked directly rather than assumed: it shares the exact same fill
  color (`secondaryContainer`) as the highlighted column now, but keeps
  its own 2px `colorScheme.secondary` border (1px when unselected) —
  verified via a new test asserting the border width switches between
  cards on selection, not just eyeballed. The two elements are also
  spatially separate (a whole card vs. a thin table column) and visually
  distinct in shape, so the shared hue doesn't collapse them into one
  reading.
- **`FittedBox(scaleDown)` removed from "PREMIUM"** — the column is now
  sized by actually measuring "PREMIUM" at the *current* text scale via
  `TextPainter` (`_ComparisonTable._premiumColumnWidth`), not a fixed
  56px constant, so there's no scale-down safety net needed at any
  Dynamic Type setting.
- **A real bug found and fixed while verifying the above at large text
  scale, not assumed away: `IntrinsicHeight` does not combine reliably
  with an `Expanded` child.** The first version of each comparison row
  used `IntrinsicHeight` + `CrossAxisAlignment.stretch` to make the
  Premium strip cell match its row's own (possibly wrapped) label
  height — this under-measured badly at 2.0x text scale (one row's
  reported height came back as 735 logical pixels, absorbing the rest of
  the table's own space and causing a real overflow elsewhere). Replaced
  with a height *measured up front* via `TextPainter` (one line for the
  header, two for data rows) and a plain `SizedBox(height: ...)` —
  `IntrinsicHeight` removed entirely from this file. Labels are capped
  at two lines with an ellipsis to match the two-line budget, and the
  merged row's own free-column text (`Flexible`, not a bare `Text`) can
  wrap to two short lines too, since the Premium strip's own measured
  width leaves little room beside it at 2.0x scale — found via the same
  overflow, fixed the same way, rather than shrinking the strip and
  reintroducing the original "PREMIUM" clipping bug.
- **[Engineering] Test suite substantially extended**
  (`test/premium_screen_test.dart`, 25 → 35 tests): the four-row table
  content and semantics counts updated for the merge; a new footer group
  covering all three content states, the four height measurements above,
  no-overflow at 320pt/375pt and at 1.3×/2.0× text scale specifically for
  the "PREMIUM" header, and the selected-card-border check. One existing
  test's assumption ("no spinner anywhere while loading") was corrected,
  not just patched, to scope specifically to the body's plan-card area —
  the footer legitimately has its own spinner now, by this batch's own
  design.
- **[Product]** `flutter analyze` and the full test suite (322 tests, up
  from 312) clean.

## 2026-09-15 (Premium screen redesign, Batch 3 — hero avatar group and
sub-headline)

- **[Engineering] `PremiumScreen` gained a required `StorageService`**,
  read once in `initState` (`_loadAvatar`) to get the real user's avatar
  for the hero, rather than threading `Avatar?` through its four call
  sites by hand — two of them (`practice_launch.dart`,
  `weak_spot_detail_screen.dart`'s own function-shaped caller) don't hold
  profile state today, and all four already hold a `StorageService`
  instance for other reasons (checked by reading each one, not assumed,
  in Batch 0). Updated all four: `home_screen.dart`,
  `weak_spot_detail_screen.dart`, `practice_launch.dart`, and
  `first_launch_flow.dart`'s `_DayZeroPaywallCta` (which didn't carry a
  `StorageService` at all before this — added).
- **Checked, not assumed: by the time the Day-0 flow's own `PremiumScreen`
  push happens, the profile is already saved.** `_DayZeroPaywallCta` only
  renders once `FirstLaunchFlow` has reached its `dailyTestResult` step,
  which only happens after `_completeOnboarding` has already awaited
  `storageService.saveUserProfile(profile)` successfully — so
  `getUserProfile()` inside `PremiumScreen._loadAvatar` reliably finds a
  real, already-random-assigned avatar on this path, not a legacy-null
  edge case.
- **A fallback avatar is picked immediately, not left null** —
  `late Avatar _userAvatar = _fallbackAvatar` (`_fallbackAvatar` itself a
  `late final Avatar.random()`, the same "computed once per visit, not
  re-rolled" pattern `SettingsScreen`'s own fallback already uses) — so
  the hero always has a real avatar to render from the very first frame,
  overwritten by the real one once the storage read resolves (or left as
  the fallback if the profile has none / an unrecognized legacy id). Per
  this batch's own instruction, the hero never shows the generic
  placeholder at all, confirmed by a new test asserting every `AvatarTile`
  in the hero always has a non-null `avatar`.
- **The four other avatars are picked deterministically** —
  `_otherAvatarsFor` offsets the center avatar's own index by 2/4/6/8
  positions around the 12-avatar cycle, not `Avatar.random()` — the same
  visitor sees the same group every time, verified by a test that pumps
  the screen twice and checks the same five avatars come back both times.
- **`_AvatarHero`: the user's own avatar front-and-center (radius 48),
  four others layered behind it (radius 32 inner pair, 26 outer pair,
  horizontal offsets ±58/±90, slight vertical stagger) at 60% opacity**,
  built from the existing `AvatarTile` (transparent background + ground
  shadow already baked in since the ring-removal batch) with **no `Hero`
  wrapper at all** — this screen has no push/pop partner to fly to, and
  wrapping these would risk colliding with Home's or Settings' own
  avatar Hero tags, both of which stay mounted simultaneously with this
  screen. A new test confirms zero `Hero` widgets anywhere on this
  screen, not just that the *right* tag is used.
- **[Engineering] A real accessibility gap found and fixed while writing
  the widget, not just while testing it: a bare `AvatarTile` carries no
  semantic label of its own** — `AvatarCarousel` adds one per page
  itself; this hero, built directly from `AvatarTile`, initially had
  none at all. Rather than replicate the carousel's per-tile
  `Semantics` (five separate nodes for what's actually one decorative
  group — the four "other" avatars aren't individually meaningful),
  wrapped the whole hero in one `Semantics(label: "Your avatar:
  $name")` over an `ExcludeSemantics`'d `Stack` — a screen reader hears
  one clear sentence instead of noise. Tests that need to know *which*
  avatars are actually rendered now read `AvatarTile.avatar` directly at
  the widget level instead of scanning semantics labels, since the
  labels are deliberately excluded now.
- **Sub-headline added below the existing (unchanged) contextual
  headline/fallback**: "Practice the mistakes you actually make." Both
  the headline and this line are now center-aligned, matching the
  centered hero visual above them — a small, deliberate visual-coherence
  call, not requested verbatim but consistent with the hero's own
  centered composition.
- **[Product]** `flutter analyze` and the full test suite (327 tests, up
  from 322) clean.

## 2026-09-15 (Premium screen redesign, Batch 4 — paywall analytics)

- **[Engineering] Four new PII-free events on `AnalyticsService`**,
  matching its existing pattern exactly (a plain `Future<void>` method
  per event, named string constants for every enum-shaped parameter,
  routed through the same private `_logEvent`): `paywallViewed(source)`,
  `paywallDismissed({source, method})`, `purchaseStarted(plan)`,
  `purchaseResult({plan, outcome})`. `source` is one of four constants
  (`paywallSourceHome`/`WeakSpotQuota`/`PracticeLaunch`/`Onboarding`) —
  one per real `PremiumScreen` push call site, confirmed by reading each
  one in Batch 0, not guessed. `method` is `close_button`/`maybe_later`/
  `system_back`. `plan` is `monthly`/`annual`. `outcome` is `success`/
  `cancelled`/`error` (the last one renamed from `PurchaseOutcome`'s own
  `failure` to match the word already used everywhere this outcome is
  shown to a user). `AnalyticsService.modeSelected` and
  `freePracticeQuotaExhausted` are completely untouched — confirmed by
  diff, not just by not having edited them.
- **`PremiumScreen` gained `required AnalyticsService analyticsService` and
  `required String analyticsSource`** — the latter deliberately required,
  not defaulted, since Batch 0 already established there are exactly four
  real entry points and no "unknown" case worth a silent fallback.
  `paywallViewed` fires once in `initState`.
- **`purchaseStarted`/`purchaseResult` wired into `_startTrial`** — the
  plan id is read from `_selectedPeriod` (whichever card is actually
  selected when the button is tapped, not always the preselected annual
  one), and `purchaseResult` always fires after the real
  `subscriptionService.purchasePackage` call resolves, mapping
  `PurchaseOutcome` to the three outcome strings.
- **`paywallDismissed` needed real design work, not just a call at each
  button** — three genuinely different trigger shapes exist: the X
  button and "Maybe later" each have their own `onPressed` (trivial to
  tag directly), but a system back gesture/hardware back button reaches
  a pop without going through either. Solved by wrapping the screen in
  `PopScope` (`canPop: true` — purely observing, not blocking, unlike
  `AvatarPickerScreen`'s own `PopScope` which has a real before-the-pop
  timing requirement this screen doesn't) plus a new `_exitHandled` flag:
  `_dismiss()` (shared by X, "Maybe later," and the post-success
  "Continue") sets it *before* triggering the pop, so `PopScope`'s own
  observer can tell "already logged by a specific button" apart from "a
  system back that reached a pop with none of this screen's own code
  involved" — logging `system_back` only in the latter case, and never
  double-logging when `_dismiss()`'s own `Navigator.pop()` call is what
  triggers the observer. The post-success "Continue" path calls
  `_dismiss()` with no dismiss method at all — a completed purchase
  isn't an abandonment, and it's already covered by `purchaseResult`.
- **[Engineering] New `_FakeAnalyticsService`** (`premium_screen_test.dart`)
  records every call (name + parameters) instead of hitting Firebase,
  the same "fake the platform-channel-backed service" approach this
  suite already uses for `SubscriptionService`. Eight new tests cover:
  `paywall_viewed` firing once with the right source; `paywall_dismissed`
  for all three methods (the `system_back` one driven by
  `tester.binding.handlePopRoute()` — the standard way to simulate a
  real system back gesture in a widget test, not a button tap); the
  purchase-flow pair firing in order with the correct plan id for both
  the preselected annual and a switched-to monthly selection, across all
  three outcomes; and that a successful purchase's "Continue" logs no
  `paywall_dismissed`. `analytics_service_test.dart` gained six more
  "does not throw without a Firebase project" tests for the new methods
  (plus the two from the free-practice-quota batch, which turned out to
  have been added to the service without ever getting one here).
- **[Product]** `flutter analyze` and the full test suite (340 tests, up
  from 327) clean.

## 2026-09-16 (iOS minimum deployment target: 13.0 → 15.0)

- **[Engineering] Reason.** The installed Xcode toolchain rejects a
  simulator build below iOS 15.0 outright: "The iOS Simulator deployment
  target IPHONEOS_DEPLOYMENT_TARGET is set to 13.0, but the range of
  supported deployment target versions is 15.0 to 27.0.x." Confirmed via
  `xcodebuild -showBuildSettings` against a concrete simulator
  destination — `DEPLOYMENT_TARGET_SUGGESTED_VALUES` for this SDK starts
  at 15.0, matching the error's own stated floor exactly.
- **[Product] Decision: minimum iOS 15.** iOS 13-14 devices are no longer
  supported. Not a meaningful reach reduction pre-launch — Apple's own
  adoption data has iOS 13/14 at a small single-digit share by this point
  — and the alternative (patching a global Xcode/Flutter toolchain
  mismatch some other way) isn't a real option.
- **[Engineering] No `ios/Podfile` in this project** — confirmed via
  `.flutter-plugins-dependencies`' `swift_package_manager_enabled: true`
  and the absence of `ios/Pods/`/`Podfile.lock`: this app uses Flutter's
  Swift Package Manager integration, not CocoaPods. So the fix is a
  single-file change: all three `IPHONEOS_DEPLOYMENT_TARGET = 13.0`
  occurrences in `Runner.xcodeproj/project.pbxproj` (the project-level
  Debug/Release/Profile configurations — `RunnerTests` has no override of
  its own, it inherits these) bumped to `15.0`. Nothing to add to a
  post-install hook that doesn't exist.
- **[Engineering] Pod versions unaffected, by construction.** There are
  no pods to change — `pubspec.lock` is unchanged (confirmed by diff)
  after `flutter clean` + `flutter pub get`, so no package version moved
  either.
- **[Engineering] Checked every native iOS dependency's own minimum
  before raising the floor.** Each SPM plugin's generated `Package.swift`
  (`ios/Flutter/ephemeral/Packages/.packages/<name>/Package.swift`)
  declares its own platform minimum: `firebase_analytics`,
  `firebase_core`, `firebase_crashlytics`, and `url_launcher_ios` at
  `.iOS("13.0")`, `purchases_flutter` at `.iOS(.v13)`, `sqflite_darwin`
  at `.iOS("12.0")`. None asks for higher than 15.0, so raising the app's
  own floor doesn't get blocked by a dependency.
- **[Engineering] Build verification blocked by an unrelated,
  pre-existing toolchain bug — not a regression from this change.**
  `flutter build ios --simulator --debug` fails on this machine with
  "Binary ... does not contain architectures 'arm64 x86_64'" even though
  `lipo -info` shows both are genuinely present in the framework binary.
  Root-caused: this Xcode's `lipo -verify_arch` now rejects being passed
  more than one architecture at once (`lipo: -verify_arch requires
  exactly one input file`, reproduced directly), which breaks Flutter
  3.44.6's own `thinFramework` step
  (`flutter_tools/lib/src/build_system/targets/darwin.dart`) — a Flutter/
  Xcode version mismatch, unrelated to this project. Confirmed the
  deployment-target change isn't the cause: reproduced the identical
  failure by stashing this commit and rebuilding against the original
  13.0 setting from a fully cleared `DerivedData`. `flutter analyze` and
  the full test suite (355 tests) are unaffected and clean, since neither
  touches native iOS compilation.

## 2026-09-16 (Two checks, and recent history cross-checked against git log)

Read-only session: two specific checks, then this file and
`docs/roadmap.md` brought in line with what's actually committed. No code
changed.

- **[Product] Check 1 — Settings > Change avatar's avatar-enlargement work
  is committed.** `70903e8` ("Settings avatar picker: bigger center
  avatar (128pt -> 160pt)", 2026-09-15): `AvatarPickerScreen`'s own
  `_centerRadius` constant, 64 → 80 (diameter 128pt → 160pt, +25%),
  `viewportFraction` unchanged at 0.5. Scoped to that one screen's
  constant — `AvatarCarousel`'s own defaults (what onboarding's embedded
  carousel uses) are untouched. This is the second of two enlargements on
  this same screen; the first (`eecbdba`, radius 56 → 64) landed the
  batch before it. Both are already documented in this file's own
  2026-09-15 "Avatar picker screen" and "Settings' avatar picker: bigger
  center avatar" entries — verified against `git show 70903e8`, not just
  recalled.
- **[Product] Check 2 — when `FirstLaunchFlow` opens the Premium screen
  from the Day-0 paywall pitch, the real profile (with its chosen avatar)
  is already saved, so the hero shows it — not the fallback.** Traced the
  actual call order in `lib/screens/first_launch_flow.dart` and
  `lib/screens/onboarding_screen.dart`: `OnboardingScreen._continue()`
  always includes a real `avatar` in the `UserProfile` it hands to
  `onComplete` (`_selectedAvatar` starts as `Avatar.random()` on mount
  and is never null, `docs/design-audit.md`'s avatar section already
  documents the "no empty state" rule this satisfies); `FirstLaunchFlow.
  _completeOnboarding` `await`s `storageService.saveUserProfile(profile)`
  *before* advancing `_step` to `dailyTest`, and only `dailyTest` →
  `dailyTestResult` → the paywall CTA's `PremiumScreen` push follows
  after that. So by the time a user can even reach "Start free trial" on
  the Day-0 result screen, the profile is already persisted.
  `PremiumScreen._loadAvatar()` still reads it asynchronously
  (`storageService.getUserProfile()`), so the hero briefly shows its own
  `_fallbackAvatar` for one frame while that read is in flight — a normal
  loading flash, not a wrong-data bug: the data being read is the real
  saved avatar, not a placeholder standing in for a missing profile.
- **[Product] Recent history cross-checked against git log — hashes and
  dates below verified directly (`git log`/`git show`), not recalled.
  Every item is already documented in full elsewhere in this file; this
  is a verification pass, not a rewrite.**
  - **Avatar asset fix — a defect fix, not a design choice.**
    `avatar_07.webp`'s own pixels carried a corrupted translucent stripe;
    Dinosaur was retired for Crab in that slot *because of that defect*,
    confirmed by decoding the shipped bytes, not a stylistic swap. New
    edge-alpha regression test; two unrelated pre-existing 1-pixel
    defects on `avatar_01`/`avatar_03` fixed losslessly in a follow-up
    (`eebecba`, `1be458d`). Date correction: `3def6f9`. See this file's
    own 2026-09-15 "Avatar asset fix" entry.
  - **Transparent avatar background + ground shadow — a design choice,
    not a response to a user-reported finding.** Made as part of this
    round's own avatar-presentation redesign (dropping the colored
    selection ring in favor of the carousel's existing scale/opacity
    cue), not because anyone flagged the ring as broken; the ring's own
    color palette was deleted outright, not carried forward again
    (`af078c4`). See this file's own 2026-09-15 "Avatar presentation"
    entry and `docs/design-audit.md`'s avatar named-exception section.
  - **Home avatar tap opens the avatar picker directly, with a real Hero
    flight — not a switch to the Settings tab (`0e8160a`).** Reasoning
    verified against the commit: keeps the tab model untouched everywhere
    else while still giving Home's avatar a genuine push/pop transition
    to fly across (a tab swap has none); a user tapping their own avatar
    is reaching for "change my avatar," which is exactly where this
    lands them, one screen closer than Settings would.
  - **Premium redesign, four batches (`eee79c2`, `29b08bc`, `7286b36`,
    `1a1291e`).** Debug-only pricing fixture; a genuinely fixed footer;
    a comparison-table correctness fix (free users get 1 targeted
    weak-spot practice/day, the table previously said "—"); the Premium
    column as one highlighted strip; the hero avatar group; four paywall
    analytics events.
  - **Premium visual fix, on-device review, two commits (`dc5a955`,
    `7e54966`).** The four-batch redesign was checked on-device and not
    accepted as-is: overlap and density problems the batches' own tests
    didn't catch. Root cause of the overlap: ordinary overflow tests only
    catch a *horizontal* `RenderFlex` overflow, never a vertical one —
    new geometry tests (checking rendered rects, not just the absence of
    an exception) now guard it. The fallback headline ("Personalized
    feedback, not a feature list") traced to no spec doc — `git log -S`
    shows it was written directly as ad copy in `4d327b7`, despite that
    commit's own message citing `docs/prd.md` — removed. Dark-mode
    Premium strip fill changed to `surfaceContainerHighest` (9.34:1
    contrast for the existing text, up from 7.13:1). Known debt, left
    open: at 375×667 the plan cards still extend below the fixed
    footer's own top edge. See this file's own 2026-09-16 entries and
    `docs/roadmap.md`'s matching "on-device review fixes" entry.
  - **iOS minimum deployment target, 13.0 → 15.0 (`9ac79d9`, `9f04956`).**
    Already logged in full in this file's own entry immediately above —
    not duplicated here.

## 2026-09-16 (pre-v3 repo snapshot: docs synced to code, v2/v3 boundary defined)

- **[Product]** Read-only audit first, no code changes: confirmed 15
  unpushed commits on `main` (all authored by Ahmet Tayfur,
  `Co-Authored-By: Claude Sonnet 5`, no other author on any commit, no
  other branch/stash/worktree), `flutter analyze` clean, `flutter test`
  355/355 passing.
- **[Product]** Checked, against the task's own premise, whether Weekly
  Climb gamification had actually been built by a separate Codex session:
  **it had not.** `grep -ril "Climb|Mountain|trailhead|badge"` across
  `lib/` and `test/` returns zero matches, and the only gamification-
  related commit in the entire git history is `2c70dbb`, which added
  `docs/prd-gamification.md` (status Taslak/draft) and nothing else. The
  two untracked files present at audit time —
  [`docs/gamification-handoff.md`](gamification-handoff.md) (dated
  2026-09-16, addressed to "the external AI tool that will build Weekly
  Climb's visuals and code" — a briefing for work not yet started, not a
  record of work done) and [`docs/AGENTS.md`](AGENTS.md) (an unrelated
  imported project-instructions file) — confirm this rather than
  contradict it. Both stay untracked; neither is committed here.
- **[Product]** v2/v3 boundary, decided: **v2 is the current build,
  frozen as-is** — the monetization pivot (free/trial/paid split, Daily
  Test, the merged Premium screen), the B-structure/B-polish visual pass,
  the free-tier practice quota, avatars, and the time-of-day greeting.
  Screenshots for `screenshots/v2/` are captured from this build.
  **v3 is next and not yet built:** a gamification layer (direction has
  moved from a weekly cycle, `docs/prd-gamification.md`'s "Weekly Climb"
  draft, to a monthly one, "Monthly Climb" — that redesign is happening
  outside this repo) plus a Home screen redesign. Freezing v2 now, before
  either lands, is deliberate: it gives the project a real before/after
  to show, rather than screenshotting a build that's already mid-change
  underneath the next iteration.
- **[Engineering]** Docs brought in line with the above and with what the
  audit actually found in code (not rewritten wholesale — targeted
  fixes):
  - `README.md`: trial length corrected 3→7 days (matches
    `SubscriptionService.trialLengthDays`) and the "payment method
    required up front / auto-renews unless cancelled" mechanics spelled
    out; the free tier's one-practice-session-per-day allowance
    (`StorageService.freeDailyPracticeLimit`) added, previously
    undocumented; Firebase Analytics + Crashlytics added to the Stack
    section (connected since 2026-09-13, previously missing from this
    list entirely); the contradictory `[x]` next to "User testing (in
    progress)" fixed to state the actual closed, 3-participant (T1–T3)
    result; the top status blockquote rewritten to state plainly that
    the app is pre-launch (not on the App Store, no TestFlight build,
    no subscription products in App Store Connect yet); the v1
    screenshot table moved into a collapsed `<details>` block and an
    empty "Screenshots (v2)" heading added as a placeholder for the next
    batch; the "Scope Decisions" (No gamification, streaks, levels)
    section labeled explicitly as v1/MVP-only scope, since it reads
    differently now that v3 has a name.
  - `docs/prd-gamification.md`: a status note added at the top only
    (body untouched) stating this is the superseded weekly-cycle draft,
    direction has moved to monthly, and nothing in it is implemented.
  - `docs/roadmap.md`: a stale "Paid Apps stays Pending User Info" line
    in the "Pre-launch checklist" narrative — left behind when "Current
    wiring" was updated to record Paid Apps going Active on 2026-09-15 —
    given its own update note rather than being silently left to
    contradict the newer section above it; the 2026-09-02 "heads-up, not
    yet decided" gamification note under "Later phases" replaced with a
    dated entry reflecting the actual current state (no code, draft PRD,
    direction changed).
- **[Product]** `flutter analyze` and `flutter test` (355 tests) clean;
  no code changed in this batch, docs only.

## 2026-09-16 (EU DSA: rejection diagnosed, corrected, resubmitted)

- **[Product]** EU DSA trader verification (Apple case 102955281512),
  previously In Review, came back rejected. Apple's notice was generic
  ("We weren't able to verify your trader contact information") and
  pointed at a resubmission flow rather than naming a cause, so the cause
  had to be diagnosed rather than assumed. Two candidates going in: the
  declared trader address itself, and the translation — the original DSA
  submission used a self-certified translation, and a separate case
  Apple had opened on the developer-account membership address (filed
  earlier, to correct that same address) demanded a solicitor-certified
  one instead, which looked like it might be a stricter, shared
  requirement rather than a case-specific one.
- **[Engineering]** Diagnosed, not guessed: opening the actual resubmit
  flow (Business → Agreements → Compliance → Digital Services Act →
  Complete Compliance Requirements) showed the previously submitted
  trader address had been filled in carelessly — a misspelled city, a
  placeholder-looking second address line, no street, no building or
  apartment number. No proof document could ever have matched an address
  that incomplete, regardless of translation. The translation was not
  the cause.
- **[Product]** The resubmit dialog also settled a question that had
  been open since the membership address-change case appeared: it
  states outright that the DSA trader information "won't impact the
  contact details for your Apple accounts or memberships" — the DSA
  trader address and the developer-account membership address are
  independent fields, not the same value shown twice. The membership
  case is therefore not a prerequisite for DSA.
- **[Product]** Corrected trader information — matching the same signed
  invoice PDF already on file (English translation included) exactly —
  was submitted through the DSA dialog itself, and the case is back to
  In Review as of 2026-09-16.
- **[Product]** The membership address-change case was dropped
  deliberately, not left to lapse: it's independent of DSA, that address
  isn't published anywhere public, and pursuing it would need a fresh
  certified translation for no real benefit. The developer-account
  address stays incomplete on purpose until Apple ever re-verifies
  account identity for an unrelated reason — do not reopen this case
  without one.
- **[Product]** Lesson for next time: the first submission failed
  because of what was actually typed into the form, not because of the
  document behind it. Check what was declared before assuming the
  evidence is at fault — the diagnosis here took longer than it needed
  to because the translation was checked first, not the form itself.
- **[Product]** Not on the launch critical path: EU DSA gates EU
  availability only; Türkiye, the primary market, is not in the EU.
- **[Product]** No phone number, street address, or Apple staff name is
  recorded in this repo for either case, since this repo is public —
  `docs/roadmap.md`'s "Current wiring" entry says only "the corrected
  address."

## 2026-09-17 (Per-plan trial length: monthly 3 days, annual 7 days)

- **[Product]** App Store Connect now configures a different introductory
  offer per plan: monthly (`grammarlens_premium_monthly`) is a plain 3-day
  free trial, annual (`grammarlens_premium_annual`) is 7 days — configured
  as a "1 Week" duration, not "7 Days" (StoreKit/RevenueCat report that
  back as `periodUnit` WEEK, `periodNumberOfUnits` 1). Rationale: steer
  users toward annual by putting the longer trial on the plan worth more
  to us — a bet, not a user finding, same status as the pricing bet
  already on record. Supersedes PRD v2 §13.2's "7 days on both plans" and
  the "the 7-day trial still applies to both" clause in §13.3 — both
  sections got dated superseded notes, original text kept per this
  document's own rule. Known side effect: introductory offers are one per
  subscription group, so a user who already used the monthly 3-day trial
  gets no annual 7-day trial on switching plans.
- **[Engineering]** Batch 0 (read-only diagnosis, no code) found every
  place a trial length reaches the UI: `SubscriptionService.trialLengthDays`
  (the marketing-copy constant, then hardcoded at 7), consumed by Home's
  locked Topic Practice card and the Day-0 result screen's paywall pitch
  (`_DayZeroPaywallCta`) — both plan-agnostic, shown before any plan is
  picked. `PremiumScreen`'s own purchase-point disclosure (`_disclosureText`)
  was already correct: it reads `_selectedPackage.storeProduct
  .introductoryPrice` live, never the constant. One inaccuracy found in the
  same pass: the constant's own doc comment claimed the free/trial/paid
  comparison table used it too — it never did; that table has no trial
  number in it at all.
- **[Engineering]** The same diagnosis pass caught a real bug in
  `buildDebugFixtureOffering()`: it built one `IntroductoryPrice` object
  and reused it for both the monthly and annual fixture products, so the
  debug/preview fixture and its own tests always saw two identical 7-day
  trials — never the asymmetric case that's now real, and never a
  week-unit trial at all. Fixed as part of this batch, not filed for
  later, since implementing the asymmetric trial without fixing the one
  thing meant to preview it would have shipped code nothing actually
  exercised.
- **[Engineering]** Implementation, three commits: (1) copy — Home's
  locked card and the Day-0 pitch both drop the hand-written number
  entirely ("Try it free, then continue with a subscription." /
  "...and you can try it free.") rather than trying to state a number that
  now differs by plan; `trialLengthDays` deleted along with its stale doc
  comment, since nothing plan-agnostic states a number anymore and the
  purchase point never read it. (2) `PremiumScreen._disclosureText` gained
  `_trialDurationInDays`, converting a week-unit introductory offer to
  days before formatting (`_hyphenatedDuration`) so the disclosure line
  reads "7-day free trial" for annual and "3-day free trial" for monthly —
  comparable units when the user toggles plans. Deliberately scoped to
  only the trial part: `_formatSubscriptionPeriod` (the separate renewal-
  period text) parses the product's own ISO subscription period, an
  entirely different input, so this conversion cannot leak into it — 
  confirmed by reading both functions, not assumed. (3) the debug fixture
  split into two distinct `IntroductoryPrice` objects mirroring what
  StoreKit actually returns (monthly `P3D`/day/3, annual `P1W`/week/1).
- **[Engineering]** Tests: `subscription_service_debug_fixture_offering
  _test.dart` now asserts `periodUnit` alongside the count for both plans,
  catching the week-vs-day distinction the old pair of near-identical
  assertions couldn't. `premium_screen_test.dart`'s fakes are rebuilt the
  same way (annual as a week-unit offer, monthly as 3 days); its
  assertions cover the annual disclosure line reading "7-day" (proving the
  conversion, not just passing because the fixture happened to already say
  "day") and the monthly one reading "3-day" after switching plans. No
  test asserted the old plan-agnostic copy strings verbatim, so Home's and
  the Day-0 flow's own test files needed no changes. `flutter analyze` and
  the full suite (355 tests, same count — existing assertions extended in
  place rather than new cases added) clean before and after every commit.
- **[Product]** Not in this batch's approved scope, flagged rather than
  silently touched: `README.md`'s "Free to try for 7 days" line (added in
  the 2026-09-16 docs-sync batch above, when the trial was still 7 days on
  both plans) is now inaccurate for the monthly plan. `docs/roadmap.md`
  was explicitly excluded from this batch too, per instruction — it still
  says "7-day introductory offer on both" in its "Current wiring" block
  and needs its own update once the full App Store/RevenueCat chain is
  verified on device.

## 2026-09-17 (Savings-badge fix, and the store/billing chain completed)

- **[Product]** The subscription products, previously blocked only on Paid
  Apps Agreement going Active, are created in App Store Connect: subscription
  group "GrammarLens Premium" holding `grammarlens_premium_annual` (level 1,
  $49.99/year, 1-week free intro offer) and `grammarlens_premium_monthly`
  (level 2, $5.99/month, 3-day free intro offer) — status Ready to Submit,
  not yet submitted for review (first subscriptions go out with a new app
  version, not standalone). Two findings from actually going through App
  Store Connect, not assumed from the plan alone:
  - **The products already existed with no introductory offers configured
    at all** — a leftover from an earlier, incomplete pass at product
    creation. Adding the 3-day/1-week offers (§13.2) was the missing step,
    not a from-scratch creation.
  - **The subscription group's description said "Unlimited topic
    practice…"**, which has been false since the free-tier practice quota
    batch (2026-09-15, this file) capped premium at `dailySessionLimit`
    (10 sessions/day) — corrected to "Daily topic practice with
    personalized feedback" before anything gets submitted for review, not
    left for App Review to catch.
  - **RevenueCat only had Test Store products attached**, which is the
    actual reason every real-device paywall check up to this point showed
    the "pricing unavailable" state — not a RevenueCat misconfiguration
    unrelated to the missing App Store Connect API key, as previously
    suspected. Adding that key and creating/attaching the real App Store
    products (kept alongside the existing Test Store ones, not replacing
    them) is what made the dashboard show live product status and, in
    turn, made a real device finally load real prices — see the on-device
    verification (2026-09-17, `config/prod.json`) below.
  - **Review assets are still placeholders**: both products' App Review
    screenshot is a simulator capture of the debug fixture offering, and
    the review notes state US prices — flagged in `docs/roadmap.md`'s
    Pre-launch checklist (§1) as a to-do, not marked done here.
  - **Not yet done**, recorded rather than assumed: a sandbox purchase, a
    restore, and a cancellation haven't been exercised end-to-end; nor has
    a non-USD storefront (e.g. Türkiye / TRY) been checked for correct
    prices and a correct savings badge.
  - **Decided against** Apple's "Monthly with a 12-Month Commitment"
    billing option — outside the pricing decision (§13.3) and
    `PremiumScreen`'s disclosure block has no way to state a commitment
    term. Left as a post-launch idea only.
  Full detail: `docs/roadmap.md`'s "Current wiring" block and its
  Pre-launch checklist (§1), both updated the same day.
- **[Engineering]** With real prices finally loading on a physical iPhone,
  the savings badge read "Save 31%" against a true 30.44% saving — filed
  as a bug, diagnosed before any fix: `_planPricing` computed the
  percentage from `StoreProduct.pricePerMonth`, which StoreKit truncates
  to 2 decimals for display (49.99 / 12 = 4.1658... → "4.16", not rounded
  to "4.17"), then rounded the result — (5.99 - 4.16) / 5.99 × 100 =
  30.55% → `round()` = 31. The truncated intermediate value plus
  round-half-up compounded into an overstated discount. Fixed by computing
  the percentage from the two products' own raw `price` values directly
  (annual vs. 12 × monthly, full precision, no intermediate rounding) and
  flooring it, so display rounding can never overstate a discount again:
  1 − 49.99 / (12 × 5.99) = 30.44% → floor = 30.
  `buildDebugFixtureOffering()`'s annual `pricePerMonth` is now hardcoded
  to 4.16 (mirroring StoreKit's own truncation) instead of derived as
  `annualPrice / 12`, which formatted to "4.17" and silently disagreed
  with the real product — the fixture would never have caught this bug
  before the fix, only masked it. A new regression test uses the real
  $5.99/$49.99 prices and asserts "Save 30%"/not "31%"; confirmed it fails
  against the pre-fix computation before restoring the fix, not just
  assumed to. `docs/prd-v2.md` §13.3 gained a dated note: its own
  2026-09-07 entry had already written "$4.17/month" and "Save 30%" as
  the intended figures, so this correction is the code catching up to
  what the doc always specified, not a new decision. Full suite: 357
  tests (up from 355 — two new cases, the fixture's own truncation
  assertion and the on-screen regression test), `flutter analyze` clean.
- **[Product]** Sandbox purchase completed, same device, same day: a
  sandbox tester bought the annual plan's free trial, the `premium`
  entitlement was granted, and Home's locked cards unlocked. Deleting and
  reinstalling the app afterward (wiping local data, restarting
  onboarding) brought premium back without tapping Restore Purchases —
  StoreKit syncs transactions on launch, so entitlement reads from
  RevenueCat/StoreKit rather than anything reconstructed from local
  state, confirmed rather than assumed. Still not done: an *explicit*
  Restore Purchases tap in a scenario that actually needs it (second
  device, or a signed-out/re-signed-in sandbox account) — the reinstall
  test above didn't require it, so it doesn't stand in for it; added to
  the TestFlight pre-submission pass in `docs/roadmap.md`. Expiry/
  cancellation behavior and a non-USD storefront (e.g. Türkiye / TRY)
  price/savings-badge check remain open too. No code changed — docs only.

## 2026-09-17 (History rewrite: personal data removed from `main` and `v2-snapshot`)

- **[Product]** `main` and the `v2-snapshot` tag were rewritten with
  `git-filter-repo` to remove personal data that had been committed
  (docs/roadmap.md, since 2026-09-15): the trader street address line and
  a bank-account fragment. Both were already condensed out of the
  *current* file content earlier the same day; this rewrite is what
  removes them from *history* — every commit that ever carried either
  string, not just the tip. Only the two exact literal phrases were
  targeted, never a regex on short fragments of either one — a pickaxe
  survey confirmed a short-fragment regex would have clobbered unrelated
  content, since `web/sqflite_sw.js`'s generated `case 5007:` switch
  statement alone accounts for ~198 unrelated commits matching the bare
  numeric fragment of the account number. Verified zero hits afterward
  against a local, un-committed pattern file (see the note at the end of
  this entry on where that file lives and why it isn't in the repo).
- **[Engineering]** Full mirror backup taken first
  (`../GrammarLens-backup.git`), confirmed before any rewrite. The rewrite
  itself ran in a throwaway clone made with `git clone --no-local
  --mirror`, not in this working copy — `--no-local` specifically to
  avoid the hardlinked-object sharing a same-filesystem local clone would
  otherwise use, so nothing about the rewrite could touch this repo's own
  object store while it ran. `--refs main refs/tags/v2-snapshot` scoped
  the rewrite to exactly those two refs.
- **[Product]** `codex/monthly-climb` was deliberately excluded from this
  rewrite and left untouched — it was checked out with real uncommitted
  work in a separate Codex worktree
  (`/Users/ahmet/.codex/worktrees/575a/GrammarLens`) at the time, and
  `git worktree list` was checked before doing anything, per plan.
  **codex/monthly-climb was deliberately left out of the 2026-09-17
  history rewrite (it had uncommitted work in a Codex worktree). It is
  based on pre-rewrite commit 84deb91, whose history still contains
  personal data. NEVER merge or push this branch as-is. Before merging,
  rebase its new commits onto the rewritten equivalent of 84deb91
  (`ff52197`) with `git rebase --onto ff52197 84deb91
  codex/monthly-climb`, then confirm `git log -p main..codex/monthly-climb
  | grep -i -F -f ~/.config/grammarlens/pii-patterns.txt` returns
  nothing. Its worktree copy of docs/roadmap.md still contains the
  address line — resolve any conflict in favour of the redacted text.**
  See the matching note in `docs/roadmap.md`'s Monthly Climb item.
- **[Product]** Local `main` and `v2-snapshot` were updated to the
  rewritten history (old tips `f170af0`/`d86e31c` → new `647ecb9`/
  `aa2e0e5`); a separate commit ("docs: update commit references after
  history rewrite") remapped every short commit hash cited in `docs/` and
  `README.md` via `git-filter-repo`'s own commit-map, so `git show
  <hash>` citations in these docs still resolve. `flutter analyze` and
  the full test suite (357 tests) pass against the rewritten `main`.
  Force-pushed: `git push --force-with-lease origin main` and
  `git push --force origin v2-snapshot`. `v1-mvp` was untouched (predates
  the personal data) and was not pushed.
- **[Product]** The exact patterns this cleanup searches for and removes
  are deliberately not written out in this repo, in any commit, anywhere
  — quoting them here would just re-commit fragments of what was just
  redacted. They live in a local, un-committed file,
  `~/.config/grammarlens/pii-patterns.txt` (one pattern per line, for
  `grep -F -i -f`), and every verification/guard command in this file and
  in `docs/roadmap.md` reads from that file rather than spelling anything
  out inline.

## 2026-09-17 (Two pre-launch data-integrity fixes: destructive migration, non-atomic Daily Test completion)

A read-only verification pass against a separate branch's two claims about
`main` (both confirmed true, quoted with file:line, before any code
changed) turned into two approved fixes, landed as separate commits.
Neither problem had a regression test before this batch — both are called
out explicitly below, since that's exactly what let each one ship
unnoticed.

- **[Engineering] Commit 1 — incremental migration.**
  `StorageService.onUpgrade` (`lib/services/storage_service.dart`) used to
  drop and recreate every table but `device_identity` on *any* version
  transition, regardless of what that bump actually changed — a real
  schema bump today (`_dbVersion = 14`) would silently wipe every user's
  error history, Daily Test sets, profile (incl. avatar), and per-topic
  stats on the next release, not just ones that touch those tables.
  Replaced with per-version incremental steps (`if (oldVersion < N)`),
  each one replaying exactly what that historical bump actually added —
  reconstructed from `git log -p` on the file, not just the file's own
  comments, since the comments alone don't say which columns v1→v2 or
  v11→v12 touched. Every step is idempotent: `CREATE TABLE IF NOT EXISTS`
  for new tables, a `PRAGMA table_info` check
  (`StorageService._hasColumn`/`_addColumnIfMissing`) before any `ALTER
  TABLE ADD COLUMN` — required, not defensive polish, because sqflite
  silently lowers the on-disk schema version on a downgrade (installing an
  older build after a newer one) without touching the actual table shape,
  so a later upgrade back to the current version can re-run a step whose
  table/column already exists. `device_identity`'s own unconditional
  `CREATE TABLE IF NOT EXISTS` (every upgrade, not gated on a version
  check) is unchanged, including its existing doc comment on why it's
  never dropped.
  New `test/storage_service_migration_test.dart` (3 tests): a real
  `error_entries` row survives the full v1 → v14 upgrade with every later
  table created and usable; real rows across every v13 table (error
  entries with `source`, a profile with an avatar, a completed Daily Test
  set with `answers_json`, topic stats, review/theme/practice settings, a
  session-usage row, a debug override, and `device_identity`'s id) survive
  v13 → v14, including `device_identity` returning its *existing* id
  rather than regenerating one; running `onUpgrade` a second time over an
  already-fully-migrated schema (reproducing the downgrade-then-upgrade
  landmine above by forcing the stored version back down without touching
  the schema) doesn't throw and doesn't duplicate the seeded row. Confirmed
  by temporarily reverting to the old drop/recreate implementation: all
  three new tests fail against it (the seeded rows come back empty), so
  they genuinely exercise what broke.
- **[Engineering] Commit 2 — atomic Daily Test completion.**
  `DailyTestResultScreen.initState` used to fire `_saveErrors()` (writes
  wrong answers via `insertErrors`) and `_markCompleted()` (writes
  `completed_at`/`answers_json` via `markDailyTestCompleted`) as two
  independent, un-awaited calls, each swallowing its own exception. If the
  app was killed between them, or either write failed on its own, a retake
  of a still-not-completed set would re-log the same mistakes a second
  time, or a day that did get marked completed would permanently lose that
  session's mistakes with no error ever shown — and neither failure mode
  needed a crash to reach, since each write already caught and discarded
  its own exception independently. Replaced both with one
  `StorageService.completeDailyTest(answers, errorEntries)`, wrapping the
  `daily_test_sets` update and the `error_entries` batch insert in a single
  `db.transaction`: either both land or neither does. The old
  `StorageService.markDailyTestCompleted` and the
  `DailyTestService.markCompleted`/`recordErrors` pair are gone entirely
  rather than left as an unused parallel path — `completeDailyTest` is now
  the only way to complete a Daily Test set, at both the storage and
  service layers. `DailyTestResultScreen` calls it once from
  `_completeDailyTest`; a thrown exception is surfaced via the same
  `AppMessenger.show` toast this screen already used for a save failure
  (`_saveErrors`' old catch block) — checked first, and confirmed: this
  screen (like Topic Practice's `ResultsScreen`) has no dedicated
  saving/retry UI at all, so the fix reuses the existing failure-surfacing
  mechanism rather than inventing one.
  Tests: `test/daily_test_service_test.dart` gained two new cases proving
  rollback (a `PRIMARY KEY` conflict on the error-entries insert leaves
  `completed_at` unset and no error rows written) and clean retry-after-
  failure (a failed attempt followed by a successful retake leaves exactly
  one error row, never zero or two); `test/daily_test_result_screen_test.dart`
  gained a case proving a completion failure now reaches the screen's
  existing AppMessenger toast instead of failing silently.
  `test/storage_service_daily_test_set_test.dart` and
  `test/first_launch_flow_test.dart` updated to the new single method
  (renamed calls only, no behavior change to what they test).
- **[Engineering]** Both commits: `flutter analyze` clean, full test suite
  green (363 tests, up from 357 before this batch — 3 new migration tests
  in Commit 1, plus Commit 2's net +3: two new atomicity tests and one new
  failure-surfacing test, minus the one `markCompleted`-specific test that
  no longer applies once `markCompleted` itself is gone).

## 2026-09-18 (Monthly Climb Stage 3: first Home integration slice)

- **[Product]** User approved connecting persisted monthly progress to Home
  after verifying `monthly-climb-v2` at `0cf7eaa`, with only the two existing
  untracked docs. This is post-launch work; no main merge or PR. Updated the
  preview instructions to the current checkout `/Users/ahmet/GrammarLens`.
- **[Engineering]** Home reads `getClimbProgress` for the current calendar
  month and renders the existing `MonthlyMountain` with the selected avatar.
  Added loading, empty, summit and read-error/retry states. Concurrent reads
  cannot overwrite newer results; a month key recreates the mountain at
  rollover, including transitions between equally long months. Resume and
  Daily Test/result return refresh local data without generating questions.
- **[Engineering]** Home uses DailyTestScreen's existing `onFinished` hook
  to own the result route and await its return. Added an optional result-screen
  callback after successful persistence so leaving during a pending write
  still refreshes Home after commit. No storage, migration, answer-matching or
  completion transaction implementation was changed. Day-0's existing hooks
  and navigation remain. Existing Topic Practice/weak-spot paywall gates and
  avatar Hero remain. At large text sizes, Home's locked Topic Practice card
  uses a labelled lock icon in place of the wide Premium pill; the new 320px,
  2× text tests exposed the pill's horizontal overflow.
- **[Validation]** `flutter analyze --no-pub`: no issues. Full
  `flutter test --no-pub`: **389 passed**. New Home coverage includes selected
  avatar/month length, same-length month rollover, stale reads, error/retry,
  delayed save after leaving results, all-skipped/answered completion, replay
  without another completion write or generation call, and small-screen large
  text/reduced motion in light/dark. Existing database atomicity/migration,
  Daily Test, onboarding and avatar tests passed unchanged.
- **[Visual/build]** Production entry point built and launched on the dedicated
  Monthly Climb simulator (iPhone 17 / iOS 26.5). Its data was at onboarding;
  no on-device Home/completion acceptance is claimed. Production Home widget
  renders with controlled 8/30 progress were inspected in light/dark; temporary
  render harness removed, images retained at `/tmp/climb-home-light.png` and
  `/tmp/climb-home-dark.png`. These omit the app's bottom-nav shell and are
  layout checks, not screenshots of the complete running app.
- **[Remaining]** Device Home/completion review, remaining Home redesign and
  error-preview access decision, medals/Profile and release measurements.
  Stage 3 is not marked fully accepted. No commit, push, merge or PR in this
  batch. Existing untracked docs were left untouched.

## 2026-09-18 (Device feedback package 1: result CTA and visible climb movement)

- **[Product]** User approved the first revision package after sharing
  `IMG_6217.PNG`, which showed the result list ending without a next action.
  No new paywall redirection in this package. Other planned revisions remain
  separate; see `monthly-climb-revision-plan.md`.
- **[Engineering]** Default Daily Test results now end with `See your climb`
  after a saved answered test, or `Back to Home` for all-skipped/replayed
  results. While saving, the footer action is disabled and says
  `Saving your results…`; a failure shows a footer retry and blocks a success
  CTA. Existing top error/retry and Day-0's custom `bottomBuilder` remain.
- **[Engineering]** Fixed the animation cause rather than only adding a button:
  the prior save callback updated Home while the result route still covered it.
  Home now defers climb presentation during the Daily Test/result flow, waits
  for the result route's reverse transition to complete, reveals the mountain,
  then applies the persisted target to its existing animation. The short Home
  content is kept in one mounted column so scrolling does not discard the
  mountain's previous position. A pending completion day handles late writes;
  `HomeScreen.active` is wired from the app's IndexedStack selection so a save
  finishing on another tab waits for Home. Month keys still reset presentation
  at rollover. Storage, migration, matching, service and atomic completion
  implementations were not changed.
- **[Validation]** `flutter analyze --no-pub`: clean. Targeted Home/result/
  first-launch tests: **61 passed**; full suite: **397 passed**. New tests
  compare the pawn's actual initial/intermediate/final positions for both
  CTA and back navigation, with/without reduced motion. They assert that
  persistence has completed while the covered Home still shows the old step,
  that the mountain is onscreen when movement starts, and that replay does
  not award or move again. Also covered delayed save on an inactive Home tab,
  busy/error/retry footer states at 320px with 2× text in light/dark, and
  all-skipped footer copy. Existing migration/transaction and Day-0 tests pass.
- **[Visual]** Inspected production result-widget renders with five fixture
  questions at 390×844 in light/dark. Output: `/tmp/climb-result-light.png`
  and `/tmp/climb-result-dark.png`; the temporary rendering test was removed.
  These are controlled widget renders, not physical-device screenshots.
  The user's physical-device acceptance is the next check.
- **[Delivery]** Changes remain on `monthly-climb-v2`, uncommitted. No push,
  merge or PR. No new application run/install on the user's phone in this batch.

## 2026-09-18 (Device feedback package 2: Home scrolling and compact progress)

- **[Product]** User confirmed package 1 works correctly on their phone and
  approved moving to package 2. No weekly participation strip or new mountain
  detail route was added; the compact monthly counter is retained.
- **[Engineering]** `MonthlyMountain.allowUserScroll` defaults to true for the
  standalone preview. Home sets it to false: the inner viewport uses
  `NeverScrollableScrollPhysics`, and its scrollbar does not respond to
  notifications or input. Vertical gestures over the mountain now reach the
  Home page. Programmatic scrolling still follows the pawn during the existing
  step animation. The long caption below the scene was removed; a wrapping
  heading holds the month and progress counter, with a live semantic label
  including the summit state.
- **[Validation]** Static analysis clean; full Flutter suite **399 passed**.
  New light/dark tests drag from inside the mountain at 320×568, assert outer
  page movement with unchanged inner trail position, reach Topic Practice,
  and verify counter placement and its actual semantic-node label. Existing
  small-screen/large-text, preview scrolling and package-1 initial/intermediate/
  final animation-frame tests pass. No physical-device install or check in
  this batch; package 2 awaits the user's device review.
- **[Delivery]** `monthly-climb-v2`; no storage/migration/completion changes,
  commit, push, merge or PR. Other revision packages remain pending.

## 2026-09-18 (Premium 4a: equal Annual/Monthly plan cards)

- **[Product]** User confirmed Home scrolling works and authorized proceeding
  within the remaining usage window. Scoped this batch to 4a ahead of font
  selection; the content-driven sizing also accommodates later typography.
  The final test rerun was interrupted by an automatic approval-review usage
  limit, then resumed after the user reported that usage had renewed.
- **[Engineering]** An `IntrinsicHeight` around the two-card horizontal Row
  stretches both frames to the taller natural content, including Annual's
  savings badge. This row has no vertical flex or LayoutBuilder children.
  Compensated card padding for 1px/2px border thickness so selection changes
  do not shift content width or change height. No fixed height, pricing,
  discount, purchase or analytics changes.
- **[Validation]** Static analysis clean. All **67 Premium tests passed**.
  New tests check equal width/height, aligned tops and stable sizes after
  selecting Monthly, at 320px/1× and 375px/2× in actual light/dark app themes.
  The full app suite was not rerun in this isolated pricing-layout batch.
- **[Open finding]** Testing 320px/2× exposed horizontal overflow in the
  separate comparison-table header/rows; left for the broader Premium layout
  pass rather than expanding 4a. Device acceptance of 4a is pending.
- **[Delivery]** Changes remain uncommitted on `monthly-climb-v2`; no push,
  main merge or PR. No device installation in this batch.

## 2026-09-18 (Premium 4b: contextual entry without a longer headline)

- **[Product]** User confirmed 4a on their phone and authorized the next item.
  Kept scope to weak-spot entry layout; avatar composition and typography remain
  separate. The prior 320px/2× comparison-table overflow remains open.
- **[Engineering]** Fixed `Unlock personalized feedback` as the shared heading.
  `sourceContext` now replaces the supporting sentence with `Practice <topic>.`;
  whitespace-only/absent context keeps the existing generic copy. No additional
  content block, line clamp, font shrinking, pricing or navigation change.
- **[Validation]** Static analysis clean; all **70 Premium tests passed**.
  Actual light/dark themes at 393×852 compare normal entry with Modal past
  forms, definite articles and blank context: body height, plan-card position,
  footer position and scroll extent match. A long topic at 375×667 and 2× text
  remains untruncated with the fixed footer accessible. This proves no extra
  scroll for the reported examples, not zero scroll on every device. The full
  app suite was not rerun for this local text/layout change.
- **[Delivery]** User device acceptance pending. No device install, commit,
  push, main merge or PR; work remains on `monthly-climb-v2`.

## 2026-09-18 (Premium 4c: opaque, non-overlapping avatar group)

- **[Product]** User confirmed 4b on device and authorized 4c.
- **[Engineering]** Replaced faded, translated overlapping avatars with a
  centered row: selected avatar larger, companions smaller and fully opaque,
  8pt gaps. Available width selects three or five avatars. Hero stays 90pt tall;
  deterministic identity, fallback and single semantic node remain unchanged.
  No pricing, storage, migration or completion changes.
- **[Validation]** Static analysis clean; all 74 Premium tests passed. Added
  light/dark checks at 320/390pt for count, centered selection, bounds, gaps,
  relative size and absence of opacity ancestors. Full suite not rerun for
  this isolated UI change. Physical-device visual acceptance remains pending.
- **[Delivery]** No install, commit, push, main merge or PR.
- **[Device acceptance]** User confirmed the 4c layout on their phone.

## 2026-09-18 (app typography: bundled Nunito Sans)

- **[Product]** User approved Nunito Sans after comparing the friendly rounded
  direction with a more neutral Manrope alternative.
- **[Engineering]** Added the Google Fonts variable TTF and OFL license to the
  repository and registered `NunitoSans` in `pubspec.yaml`. The shared theme
  sets it at the base, covering text themes, app bars and themed controls in
  light/dark without runtime downloads. Asset size is 571,240 bytes.
- **[Validation]** Static analysis clean. New tests assert the family across
  representative theme styles and render Turkish characters. All 120 focused
  theme/Home/Premium tests and the full **412-test** suite passed. Device review
  is still required for visual weight and line breaks on Home, Daily Results
  and the three Premium entry paths.
- **[Delivery]** No device install, commit, push, main merge or PR.

## 2026-09-18 (Profile tab + persisted text sizing)

- **[Product]** User accepted Nunito Sans but found its initial size small.
  Preserved that exact size as Small; Medium (1.10×) is the default and Large
  is 1.20×. Renamed the user-facing Settings tab/page to Profile with person
  icon while keeping all existing profile, appearance, data and debug tools.
- **[Storage]** Schema v16 adds only `text_size_settings` (`id=0`, `size`),
  layered after main's v15 climb ledger. Missing/unknown values safely resolve
  to Medium. No existing table, migration or atomic completion logic changed.
- **[Engineering]** The shared Material type scale applies the chosen factor
  before system MediaQuery accessibility scaling. Profile's Appearance section
  exposes a three-way segmented choice and persists changes immediately.
- **[Validation]** Static analysis clean; all **416 tests passed**. Coverage
  includes ordered scales, Profile labels/callback, preference round trips,
  oldest-schema migration, existing climb migration/data survival and the full
  Home/Premium/Daily Test suite. Physical-device acceptance remains pending.
- **[Delivery]** No device install, commit, push, main merge or PR.

## 2026-09-18 (Profile monthly-medal empty collection)

- **[Product]** User accepted Profile and text sizing on device, then authorized
  the next medal step. Kept scoring, thresholds, minimum participation and
  partial-month behavior open exactly as the PRD requires.
- **[Engineering]** Added a reusable `MonthlyMedalCollection` and `MedalTier`
  boundary. Profile renders Bronze/Silver/Gold specimens with subdued tier
  color, mountain mark, lock badge, `Not earned` copy and one semantic label
  per medal. Production passes no earned tiers; no award storage/migration or
  score inference was introduced.
- **[Validation]** Static analysis clean; all **424 tests passed**. Dedicated
  coverage checks 320pt light/dark at Small/Medium/Large, no overflow, explicit
  empty state and locked/earned semantics. Device visual acceptance pending.
- **[Delivery]** No device install, commit, push, main merge or PR.
- **[Device acceptance]** User confirmed the locked medal collection on phone.

## 2026-09-18 (monthly medal rule v1 + frozen history)

- **[Product]** User approved correct +2, wrong +1, skipped +0 and ceil
  25/50/75% Bronze/Silver/Gold thresholds against the full month's maximum.
  No separate minimum-day gate, partial-month proration or catch-up.
- **[Storage]** Additive schema v17 creates `monthly_medal_results`; main's v15
  climb ledger, v16 text preference and atomic Daily Test transaction remain
  unchanged. Past months with ledger activity finalize once, including a null
  tier below Bronze. Empty months are omitted because profile creation time is
  not stored. INSERT OR IGNORE plus rule version 1 prevents recalculation.
- **[Engineering]** Added pure `MonthlyMedalRules`, progress/result models and
  Profile loading on mount and tab re-entry. Current month remains `In progress`;
  history shows month, final tier or `No medal`, and frozen score/max.
- **[Validation]** Static analysis clean; all **436 tests passed**. Tests cover
  28–31-day ceiling thresholds, exact boundaries, current-month exclusion,
  below-Bronze persistence, frozen history, migration/data survival, semantics,
  and populated 320pt light/dark layouts at all three app text sizes.
- **[Delivery]** No device install, commit, push, main merge or PR.

## 2026-09-21 (launch checklist: code items)

- **[Product]** Session cap 10 → 5, a margin decision: at an estimated
  ~$0.034/session, 10 sessions/day is ~$10.20/month against ~$3.54/month of
  net annual-plan revenue. 5 sessions = 10 proxy units + 1 Daily Test unit,
  inside `DEVICE_DAILY_LIMIT` = 15, so the proxy limit stays and the
  2026-09-15 headroom question is closed. Premium's "3, 5 or 10" is question
  counts, not the quota; nothing in `lib/` says "unlimited". PRD v2 §13.8.
- **[Engineering]** The brief said no `AppLifecycleState` hook existed. It does:
  `HomeScreen` (Daily Test day, greeting, climb month, weak spots) and
  `GrammarLensApp` (analytics, medal finalization) each observe resume, with
  disjoint jobs. No third hook was added; a test-only `GrammarLensApp.clock`
  and `test/app_resume_test.dart` prove the overnight scenario end to end and
  that one resume runs each job once (launch itself finalizes twice, from the
  app and from Profile's mount; idempotent). The roadmap's stale open bug was
  closed with that explanation.
- **[Engineering]** Premium comparison table: reproduced the overflow (the
  header/data `Row` overflowed by 52 px at 320 wide @2x text, 126 px at 393
  @3x). Fix: when the label column would fall under 96 pt even with "1/day",
  rows stack (label, then Free/Premium chips), no scrolling, nothing removed.
  The pricing-unavailable card overflowed too and now drops its retry below the
  sentence. Table width measurement now uses the drawn font (it used the
  platform default, a mismatch since the Nunito change); row-height measurement
  was left alone because changing it moved normal layouts. Tests load the real
  font, since `flutter test` otherwise measures ~2x too wide. Open: at 320
  @1x and 393 @1.3x the existing table already ellipsizes a label to two lines;
  left as is on the "normal screens unchanged" rule.
- **[Product]** Onboarding privacy note rewritten to match the code and the
  privacy policy (name/goal stay on device; answers go to the AI provider;
  usage and crash data is collected). PRD v2 §13.9.
- **[Product]** Trial wording: annual = 7 days, monthly = 3 days, read from
  RevenueCat, never written into app copy. README and current-state doc text
  fixed; dated historical entries kept.
- **[Engineering]** Proxy token logging (`proxy/src/usage_log.ts`): one
  `console.log` line per successful Anthropic call with kind, operation,
  question count and input/output tokens; nothing user-related, tested with
  planted secrets. Not deployed. Storage options in PRD v2 §13.10, none built.
- **[Product]** Shared Daily Test recorded as a post-launch item in the
  roadmap's Launch scope, with trade-offs and why it waits.
- **[Delivery]** Automated tests only for all of the above; no device
  confirmation, no deploy, no main merge or PR.

## 2026-09-21 (launch checklist: debug tools out of release)

- **[Engineering]** Scanned the app for developer tooling. Found: Settings'
  "Developer" section (entitlement override, first-launch reset, pricing
  fixture, theme preview), raw error text on Daily Test's failure screen, the
  launch-time override load, and two `lib/preview` entry points. All UI was
  already behind `kDebugMode`, and the previews are imported by nothing.
  Gaps: `SubscriptionService`'s gate was a mutable static, and
  `resetOnboarding()` (deletes the profile) and the override read/write were
  unguarded methods. Added `DebugTools.enabledForTesting` and gated every site
  with `kDebugMode && DebugTools.enabledForTesting`; `SubscriptionService.debugModeForTesting`
  now drives the same switch. Text size untouched.
- **[Validation]** New release-simulation tests (Settings, Daily Test error,
  storage, app launch, subscription service) plus source-structure checks; a
  mutation that removed the Settings gate turned two of them red. A release
  web build was identical before and after and contains none of the tool
  strings. The iOS release build could not be run here (Xcode 27 `lipo`
  issue), so the AOT binary was not inspected. Debug builds unchanged.

## 2026-09-21 (launch checklist: Premium table never clips)

- **[Product]** Owner decision reversing the earlier "normal screens must not
  change" constraint: a sales table must not cut a label off with an ellipsis.
- **[Engineering]** The comparison table now also falls back to the stacked
  layout when any label does not fit in two lines, measured with the same
  style, text scale and label-cell width it is drawn with; the existing 96 pt
  minimum still applies. Old and new logic were compared over widths 320-430
  and text scales 1-3: every size that changed had a clipped label under the
  old table, and every unclipped size kept its table. Tests now assert that
  grid, plus that no label is clipped in either layout. Tests that expect the
  table load the real Nunito Sans and use the app theme (under the default
  test font almost every size would stack).

## 2026-09-21 (launch checklist: proxy failure logs without content)

- **[Engineering]** The proxy logged Anthropic's raw error body on a non-200
  and the JSON parse exception on unusable content; either can quote request
  or model text. Both, and the two other Anthropic-path error logs, now go
  through `logUpstreamFailure`: operation, kind, failure category, HTTP status
  and a whitelisted Anthropic error type; no body and no exception message.
  A 200 whose body is not JSON used to throw into the catch-all and is now
  handled and categorized. Tests cover each failure with planted secrets.
  Not deployed. The catch-all `Unhandled error` log in `index.ts` is unchanged.

## 2026-09-21 (Profile: age and occupation removed)

- **[Engineering]** Scanned all uses first: the two optional Profile fields
  appeared only in the Profile form, `UserProfile` and the `user_profile`
  table. Nothing in prompt generation, no proxy request body (the proxy
  rejects unknown fields), no analytics event, Home or Premium read them, so
  the removal loses no personalization.
- **[Engineering]** Removed from UI, model, storage and tests. Schema v19
  rebuilds `user_profile` (create new, copy id/name/goal/avatar, drop, rename)
  instead of `DROP COLUMN`, which needs SQLite 3.35+; guarded by a column check
  so the downgrade-then-upgrade replay is a no-op. Tests cover a seeded v18
  database with real values, no avatar, no profile row, saving afterwards, the
  replay and a fresh install. Docs and comments that described the fields were
  updated; dated history was kept with pointers.

## 2026-09-21 (proxy: catch-all error log narrowed)

- **[Engineering]** The catch-all `Unhandled error` log in `proxy/src/index.ts`
  wrote the whole exception. It now logs `unhandled_error` with the operation,
  its kind and an error category only (a built-in error name, `other_error`,
  or `non_error`); no message, stack or cause, and a custom error name is never
  echoed. Tested by forcing an unexpected error outside every handled path
  with secrets planted in the message, the request and a thrown string.
  Trade-off: real bugs now appear as a category and need a reproduction to
  diagnose. Not deployed.

## 2026-09-21 (Profile layout rework, Data screen, avatar credits)

- **[Product]** Order decided: Avatar, Name (+ Save), Monthly medals,
  Appearance, Data, Credits, Developer (debug only, last). The "Change avatar"
  row stays a row that opens the picker screen; an inline carousel was
  considered and rejected (a horizontal `PageView` inside the page's vertical
  list, and the picker's autosave, slot geometry and `Hero` all live in the
  pushed screen).
- **[Product]** "Reset progress data" moved off Profile onto a Data screen so
  the destructive option is not visible on the page itself; the existing
  confirmation dialog is the second layer. Text, buttons and messages moved
  verbatim.
- **[Product]** Attribution is required by the avatar set's CC BY 4.0 licence.
  Credits is a screen, not a dialog (long text, two URLs, must fit at large
  text sizes). The sentence is plain text, with two link buttons under it
  instead of inline tappable spans (larger touch targets, same pattern as the
  Premium legal links).
- **[Engineering]** Three commits: layout plus a private `_NavRow` (the avatar
  row's markup, reused by Data and Credits); `DataScreen`; `LegalLink` extracted
  from Premium plus `CreditsScreen`. Premium tests passed unchanged.
  Tests that tapped Appearance controls now scroll to them first (Appearance is
  below the medals), and the "release" tests anchor on the Data row instead of
  the reset button. The section-order test compares vertical positions on a
  tall surface; it fails on the old order (checked by reverting the layout).
  Link taps are not tested: no `url_launcher` fake and no new dependency.
- **[Idea, not planned]** Theme choice as one toggle button; recorded in the
  roadmap's out-of-scope table only.

## 2026-09-21 (destructive action colors)

- **[Problem]** Found on device: the Reset progress dialog had an orange
  Cancel and a Reset in `error`, which is dark red in light mode and pale pink
  (`#FFB4AB`) in dark mode. Emphasis on the wrong button, and a weak fill for
  an irreversible action.
- **[Engineering]** Measured before choosing (WCAG luminance, real theme
  values): the M3 `errorContainer` pair suggested for dark fails as a fill
  (`#93000A` is 1.52:1 against the dark dialog surface, `#FFDAD6` text is
  fine), and in light `errorContainer` is 1.03:1 against the dialog. A search
  over reds found one hex that passes in both themes: `#DC3232` with white
  text, 4.62:1 text, 3.67:1 (light) and 3.08:1 (dark) against the dialog
  surface, 4.20:1 / 3.71:1 against the page body. The margin is narrow both
  ways, so the constant's comment says to re-measure if it changes.
- **[Engineering]** `DestructiveColors` on `ColorScheme` (`destructive`,
  `onDestructive`), the same two constants in both themes, next to
  `BandColors`; swatches added to the debug theme preview. `error` stays the
  meaning-of-failure color (Premium and Review error text and icons) and
  `SemanticColors` is untouched.
- **[Product]** Used by every destructive confirm: Reset progress (dialog and
  the Data screen button, now filled instead of outlined, since a red outlined
  label cannot pass 4.5:1 on the dark body with this same hex), "Leave
  practice?" and "Leave Daily Test?" (Leave used to be the default blue).
  Cancel is a neutral `onSurface` text button in all three (11.06:1 dark,
  13.64:1 light on the dialog). A shared `DestructiveDialogActions` keeps the
  stacked order and the 52 pt full-width layout. Untouched by decision: the
  "That's all for today" dialog and the length-picker bottom sheet.
- **[Engineering]** Tests use `buildAppTheme` in both themes and check the
  role on each button, that Cancel is not `primary`, and the layout order. The
  `BandColors` doc comment that described orange dialog Cancel buttons was
  updated.

- **[Engineering]** Cancel in `DestructiveDialogActions` is now an outlined button (`onSurface` label, `onSurfaceVariant` border: 7.42:1 light / 8.39:1 dark against the dialog surface; `outline` was rejected at 2.72:1 in light) because the borderless text button did not read as a button beside the filled red one; size, order and behavior are unchanged.

## 2026-09-21 (launch checklist: Day-0 climb animation)

- **[Problem]** Found on device: after a normal Daily Test the pawn climbs on
  Home, but after the first-launch Daily Test (Welcome → Onboarding → Daily
  Test → Home) Home opened with the pawn already advanced.
- **[Engineering]** Root cause, from reading the code (three independent
  facts): `MonthlyMountain` animates only when `completedDays` changes on an
  already-mounted widget; Home animates only when it has a pending day, an
  earlier position (`_climbSteps != null`) and a larger saved value; and the
  pending day was set only by `HomeScreen._openDailyTest`'s result route. The
  Day-0 flow ends before any Home exists, never bound `onCompletionSaved`, and
  a fresh Home has no earlier position, so the mountain mounted straight at
  the new value. Rival explanations checked and rejected: reduce motion or a
  disabled ticker (the normal flow animates on the same device), a route
  transition hiding the animation (Home is built as Premium pops, and the
  existing visibility wait already covers that), and a `ValueKey` reset.
  One real second bug was found on the way: the Day-0 CTA buttons were
  enabled while the result was still being saved, so a fast tap could build
  Home before the write and leave it stale until the next resume.
- **[Engineering]** Fix: `FirstLaunchFlow` binds `onCompletionSaved` and
  passes `onComplete(profile, pendingClimb: (day, step))` (only when the save
  earned a step; the step comes from `DailyTestCompletion.step`, the rule the
  ledger write used). `app.dart` holds it as `initialPendingClimb` for the Home
  it swaps in and clears it as soon as Home has taken it, so it can only
  animate once. Home derives the mount position as `progress.steps - step`
  (not a constant 0: the debug onboarding reset deletes the profile but not the
  ledger), mounts the mountain there, then the existing pending-step path scrolls
  it into view and animates. Both Day-0 buttons ("Start free trial", "Maybe
  later") are disabled until the save lands; a set that was already completed
  (debug reset) is never saved again, so it does not wait.
- **[Engineering]** `GrammarLensApp` gained a `claudeService` seam, like its
  storage, analytics and clock seams, so the whole flow can be driven through
  the real app.
- **[Validation]** New `test/first_launch_climb_test.dart` runs the real app:
  Maybe later, Start free trial then Premium's Maybe later, reduce motion, all
  questions skipped, a slow save (buttons disabled, then Home shows the saved
  step) and leaving the first Daily Test. Each records the step counts the
  mountain was given and the pawn heights it was drawn at frame by frame
  (`pumpAndSettle` would hide a consumed animation). With the baseline mount
  disabled, four of the six fail (the two "nothing to animate" cases still
  pass, as they should). `first_launch_flow_test.dart` also asserts the
  `pendingClimb` handed over (answered / all skipped / abandoned). The existing
  Home return tests pass unchanged.

## 2026-09-21 (Daily Test: weak spots no longer sent)

- **[Product]** `generate_daily_test` stops sending `weakSpots`. Reasons: after
  launch the Daily Test moves to one shared set, personalization is reserved
  for Premium, and with this change the Daily Test sends no user data to
  Anthropic. Only Topic Practice answers leave the device (permission comes in
  a later batch).
- **[Engineering]** Client: `ClaudeService.generateDailyTestQuestions` takes
  only `deviceId` and `count`; `DailyTestService.getTodaysSet` no longer reads
  the error profile. Proxy: `validateGenerateDailyTest` accepts only `deviceId`
  and `count`, `WeakSpotInput` and the prompt's bias branch are gone, and the
  prompt is one fixed sentence (a varied general mix across all topics). The
  old "This user has no practice history yet" wording, which is false as a
  general statement, is replaced. The field is removed, not accepted and
  ignored: the proxy's existing unknown-field rejection now enforces it, and
  the app has never shipped, so no older client needs it.
- **[Validation]** Client tests: the request body is exactly
  `{deviceId, count}`, and generation never reads the error profile (a counting
  store proves it). Proxy tests: `weakSpots` (empty or not) and any other extra
  field give a 400 and never reach Anthropic, and two different devices produce
  byte-identical Anthropic bodies with no device id in them. `first_launch_*`,
  `home_screen_*` and `daily_test_*` fakes were updated for the new signature.
  Proxy not deployed: it and the app must ship together, since an app that
  still sent `weakSpots` would now get a 400.

## 2026-09-22 (AI permission before Topic Practice, part 1: storage, screen, gate)

- **[Problem]** App Review guideline 5.1.2(i) requires clear disclosure and
  explicit permission before personal data is shared with a third-party AI.
  Topic Practice sends the user's typed answers and the question text to
  Anthropic (Claude) through the proxy, with no permission step.
- **[Engineering]** What leaves the device, checked in code: only
  `score_answers` carries user text (`items[].prompt` and `userAnswer`);
  `generate_practice_set` sends a topic id and a count; the proxy never
  forwards the anonymous device id to Anthropic; the Daily Test sends nothing
  about the user (previous entry) and is graded on the device. `PracticeScreen`
  is constructed only inside `launchPracticeSet`, so that function is the one
  place a session, and therefore any answer, can begin.
- **[Product]** The check lives inside `launchPracticeSet`, after the
  entitlement, free-quota and session-cap checks and before the length picker
  (a user who says no is not first asked to choose a length). It reads the
  stored decision itself; there is no parameter a caller can pass to skip it,
  the same rule as the free-tier gate. Declining generates nothing, records no
  session and spends none of the free tier's daily practice. The screen returns
  on the next attempt; the Daily Test never asks.
- **[Engineering]** Schema v20: single-row `ai_consent` table (`granted`,
  `decided_at`, `consent_version`), created by the migration with no row (an
  existing user was never asked). `AiConsent.currentVersion` is 1; a grant given
  for a lower version does not allow sending, so a later change of provider or
  data re-asks. "Reset progress" does not touch it (permission is a setting,
  not progress; a test pins this). The read fails closed (an unreadable decision
  means asking again), unlike the quota checks around it, which fail open. If
  saving a yes fails, that launch proceeds (the user did agree) and the next
  one asks again. A second tap while a check is in progress is ignored
  (`ensureAiConsent`'s guard), so two screens, or two launches, cannot stack.
- **[Product]** `AiConsentScreen`: full screen, text scrolls, "Agree and
  continue" and "Not now" pinned in a footer; back arrow or system back counts as
  a decline. Wording is the approved draft. It says nothing about how the
  provider stores or uses data, on purpose (a test scans the screen for such
  claims); that belongs to the provider and the privacy policy.
- **[Validation]** `practice_launch_consent_test.dart` drives both real callers
  (`TopicPracticeScreen`, `WeakSpotDetailScreen`): first ask, agree, not now
  (nothing generated or counted, asked again), back arrow, existing grant, stale
  version, unreadable decision, failed save, permission before the length
  picker, and the double tap. Mutation checks: ignoring the gate's result, removing the
  guard and failing open each turn tests red. `ai_consent_screen_test.dart`
  pins the wording and the layout at 375x667 and 320x568, Large text, system
  scale up to 2x, both themes. The two existing launch tests grant permission in
  their fakes, since they are about the quota gates; the Day-0 test asserts the
  Daily Test never reads it. Migration tests cover v19 to v20 and a replay.

## 2026-09-22 (AI permission before Topic Practice, part 2: Data switch, onboarding wording, analytics)

- **[Product]** Profile → Data gets an "AI feedback" section above Reset: a
  switch, "Send my practice answers to Anthropic (Claude)", with one sentence
  saying what it controls and that the Daily Test is not involved. Switching on
  never flips silently: it opens the same permission screen (`requestAiConsent`),
  so the wording is always seen; Not now leaves it off. Switching off is
  immediate, with "Topic Practice will ask again." An unreadable decision shows
  off (fails closed); a failed save on switch-off keeps it on and says so. Reset
  progress leaves it alone.
- **[Product]** The onboarding privacy note now names the provider and says it
  asks: "Your name and goal stay on this device. If you use Topic Practice, your
  answers are sent to Anthropic (Claude) to give you feedback, and we ask first.
  Usage and crash data is collected." Every sentence checked against the code;
  "we ask first" is true because of part 1.
- **[Engineering]** `ai_consent_result` (docs/analytics-plan.md E7): `outcome`
  (granted / declined / revoked), `source` (practice_launch / data_settings) and
  `consent_version`, from closed enums, so nothing written by the user can reach
  it. Fired when the user decides, not when a stored grant lets a launch through.
  `outcome` and `source` reuse the paywall events' parameter names; the analytics
  plan tells the owner to slice them by event name and adds `consent_version` to
  the custom dimensions to register. `DataScreen` takes the analytics service
  (default like the other screens).
- **[Validation]** `data_screen_test.dart` covers the switch states, on via the
  screen (Agree and Not now), off, failed save, unreadable decision, Reset
  leaving it alone, the analytics parameters, and the smallest screen at 2x text.
  `practice_launch_consent_test.dart` asserts the launch-side events, and that an
  existing grant reports nothing. The onboarding test pins the exact sentence.
