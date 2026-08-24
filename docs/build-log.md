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
