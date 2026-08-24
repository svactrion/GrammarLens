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
