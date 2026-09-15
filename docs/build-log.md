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
  migration, per plan (`2db4519`), since the two are independently
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
  pre-launch app with a real (if old) deployment floor. `ios: true,
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

## 2026-09-16 (avatar picker: layout-bug diagnosis, carousel replacement,
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

## 2026-09-17 (Home: time-of-day greeting, bigger avatar, one leftover
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
  2026-09-16) is an independent call site of the same `AvatarTile` widget
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
  `theme.dart`'s own comment on `avatarRingColor`, 2026-09-16). Per this
  batch's own instruction to leave an intentional decision as-is, no
  code changed here.
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

## 2026-09-18 (Avatar picker screen: Done button, warmer copy, bigger
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
  batch (2026-09-16) but is exit-path-agnostic by construction: it fires
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
  before (2026-09-17).

## 2026-09-19 (Avatar asset fix: the vertical-line bug, Dinosaur → Crab)

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
  (and far less severe) defect than Dinosaur's. Zeroed both rows outright
  — safe, since the only nonzero pixels on either row were these already-
  imperceptible stragglers — rather than shipping a "checks all twelve"
  regression test that actually carried a two-file asterisk.
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
  2026-09-16 entry and `docs/roadmap.md`'s matching passage, both of
  which correctly describe the app as it was named at the time — the
  same don't-rewrite-history call already made for the "AI Voice
  Practice" → "AI Practice Partner" rename (2026-09-05, this file).
- **[Product]** `flutter analyze` and the full test suite (290 tests, up
  from 289) clean.
